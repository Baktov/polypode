-- Polypode: Core — table globale, SavedVariables, utilitaires, CRUD du roster

Polypode = Polypode or {}
local P = Polypode

P.SYNC_PREFIX = "POLYPODE"
P.debugEnabled = false

BINDING_HEADER_POLYPODE = "Polypode"
_G["BINDING_NAME_POLYPODE_TOGGLEUI"] = "Ouvrir/Fermer l'interface"
_G["BINDING_NAME_POLYPODE_SETLEADER"] = "Se nommer leader de l'équipe"
_G["BINDING_NAME_POLYPODE_FOLLOW"] = "Suivre le leader"
_G["BINDING_NAME_POLYPODE_ASSIST"] = "Assister le leader"
_G["BINDING_NAME_POLYPODE_INVITE"] = "Inviter l'équipe"
_G["BINDING_NAME_POLYPODE_SENDVOLUME"] = "Envoyer le volume à l'équipe"
_G["BINDING_NAME_POLYPODE_TOGGLESOUND"] = "Couper/rétablir le son de l'équipe"

P.defaults = {
	roster = {}, -- [nom-royaume] = { name, realm, class, level, lastSeen }
	minimap = {
		angle = 225, -- position du bouton autour de la minimap, en degrés (225 = bas gauche)
		hide = false, -- true : bouton masqué (/poly minimap ou panneau d'options)
	},
	mainFrame = {
		width = 720, -- taille de la fenêtre principale, mémorisée au redimensionnement
		height = 320,
	},
	-- [nom] = { name, members = { [nom-royaume] = true }, leader = nom-royaume|nil,
	--          updated = heure serveur de la dernière modification (synchro) }
	teams = {},
	-- Canal de discussion dédié aux messages Polypode entre clients (Sync.lua) ; name = ""
	-- désactivé. Versionné et synchronisé (fichier de compte partagé entre clients).
	syncChannel = {
		name = "",
		updated = 0,
	},
	-- Autres comptes Battle.net autorisés (multibox à plusieurs comptes Battle.net) :
	-- [token] = { label = personnage vu à l'autorisation, updated = version, removed = true|nil }.
	-- Versionné et synchronisé entre les clients de ce compte (pierre tombale au retrait).
	trustedTokens = {},
}

-- Par personnage : réglages propres à une fenêtre de multibox (et à l'abri du fichier de
-- compte partagé entre clients, cf. CLAUDE.md).
P.charDefaults = {
	debug = false, -- mode debug (/poly debug ou panneau d'options)
	assistStartAttack = true, -- raccourci « Assister le leader » : /startattack après /assist
	autoAcceptQuest = true, -- accepter les quêtes acceptées par le leader (Quests.lua)
	autoValidateQuest = true, -- valider (continuer + terminer) les quêtes validées par le leader
	autoSelectGossip = true, -- suivre les dialogues de PNJ du leader (quêtes, options, fermeture)
	autoSkipCinematic = true, -- passer les cinématiques passées par le leader (Cinematics.lua)
	autoTaxi = true, -- prendre le vol pris par le leader chez un maître de vol (Taxi.lua)
	autoEnterInstance = true, -- suivre le leader en gouffre (entrée, sortie) et par portail (Instances.lua)
	sentVolume = 50, -- leader : volume (%) envoyé à l'équipe par raccourci (Sound.lua)
	followLeaderSound = true, -- membre : appliquer le volume / la coupure du son du leader
	autoGroup = true, -- inviter (leader) / accepter (membre) l'équipe à la connexion (AutoGroup.lua)
	followAlert = true, -- alerte du leader quand un membre ne le suit plus (Follow.lua)
	-- Barre flottante de l'équipe sélectionnée (UI_TeamBar.lua) : affichée, liste dépliée,
	-- figée (Alt + clic) ; position (point, relativePoint, x, y), largeur (width) et hauteur
	-- de la liste (listHeight, sinon automatique) ajoutées au premier placement / redimensionnement.
	teamBar = {
		shown = false,
		expanded = false,
		locked = false,
		details = true, -- niveau, niveau d'objet et % d'XP à gauche des personnages
		healthBar = true, -- barre de vie sous les membres groupés
	},
	-- selectedTeam : nom de l'équipe sélectionnée dans la fenêtre (nil par défaut),
	-- conservé même si l'équipe manque momentanément (cf. UI_Main.lua).
}

function P.Debug(msg)
	if P.debugEnabled then
		print("|cff33ff99Polypode|r: " .. tostring(msg))
	end
end

-- Active/désactive le mode debug et mémorise le choix pour ce personnage.
-- P.debugEnabled reste la valeur lue par P.Debug (utilisable avant P.InitDB).
function P.SetDebug(enabled)
	P.debugEnabled = enabled and true or false
	P.charDb.debug = P.debugEnabled
end

local function CopyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = dst[k] or {}
			CopyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

function P.InitDB()
	PolypodeDB = CopyDefaults(P.defaults, PolypodeDB or {})
	PolypodeCharDB = CopyDefaults(P.charDefaults, PolypodeCharDB or {})
	P.db = PolypodeDB
	P.charDb = PolypodeCharDB

	-- Nettoyage : l'ancien leader global (remplacé par un leader par équipe) et le rôle
	-- par personnage associé ne sont plus utilisés.
	P.db.leader = nil
	P.charDb.role = nil

	-- Migration : l'option « quêtes dans les dialogues » (v0.21) couvre désormais tous les
	-- dialogues de PNJ sous un nouveau nom ; le choix déjà fait est conservé.
	if P.charDb.autoSelectGossipQuest ~= nil then
		P.charDb.autoSelectGossip = P.charDb.autoSelectGossipQuest
		P.charDb.autoSelectGossipQuest = nil
	end

	P.debugEnabled = P.charDb.debug
end

function P.GetCharKey(name, realm)
	name = name or UnitName("player")
	realm = realm or GetRealmName()
	return name .. "-" .. realm
end

-- NOMS DE FAMILLE (WoW Forever) : les personnages y ont un prénom et un nom de famille, et
-- UnitName renvoie le nom de famille en second résultat, là où Retail renvoie le royaume.
-- La clé de roster reste « Prénom-Royaume » ; le nom de famille est gardé à part
-- (entry.surname) pour l'affichage « Prénom Nom ». Sur Retail, rien ne change.

-- Vrai si les personnages ont un nom de famille (WoW Forever).
function P.HasSurnames()
	return RegionalUniqueNamesEnabled ~= nil and RegionalUniqueNamesEnabled() == true
end

local function SurnameSeparator()
	return Constants and Constants.CharacterNameSeparatorConsts
		and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " "
end

-- Prénom, royaume (nil = le nôtre) et nom de famille (nil sur Retail) d'une unité.
function P.UnitNameParts(unit)
	local name, second = UnitName(unit)
	second = second ~= "" and second or nil
	if P.HasSurnames() then
		return name, nil, second
	end
	return name, second, nil
end

-- « Prénom Nom » d'après UnitName, ou le prénom seul.
function P.JoinSurname(name, surname)
	if name and surname and surname ~= "" then
		return name .. SurnameSeparator() .. surname
	end
	return name
end

-- Nom affiché d'un personnage du roster : « Prénom Nom » si son nom de famille est connu
-- (Forever), sinon « Nom-Royaume » (withRealm) ou le nom seul.
function P.GetDisplayName(key, withRealm)
	local entry = P.db.roster[key]
	if not entry or not entry.name then
		return key
	end
	if entry.surname then
		return P.JoinSurname(entry.name, entry.surname)
	end
	return withRealm and key or entry.name
end

-- Version d'une donnée synchronisée : heure serveur (commune à tous les clients), strictement
-- croissante pour que deux modifications dans la même seconde restent ordonnées.
local function NextVersion(current)
	return math.max(GetServerTime(), (current or 0) + 1)
end
P.NextVersion = NextVersion

-- ROSTER. Une entrée retirée n'est pas effacée mais marquée removed = true et versionnée
-- (« pierre tombale ») : la suppression se propage aux autres clients et n'est pas annulée
-- par un client qui avait encore le personnage. P.GetRoster() ne renvoie que les actives.
-- updated : version des ajouts/retraits manuels (cible, /poly remove), synchronisés ; les
-- personnages Polypode s'annoncent eux-mêmes (HELLO) et n'en ont pas besoin.

-- Modification manuelle d'une entrée : nouvelle version puis envoi aux autres Polypode.
local function CharacterChanged(key)
	local entry = P.db.roster[key]
	entry.updated = NextVersion(entry.updated)
	if P.SyncCharacter then
		P.SyncCharacter(key)
	end
end

-- Ajoute/actualise un personnage dans le roster. Sans argument, enregistre le
-- personnage courant. Avec class/level fournis, enregistre un personnage distant
-- (reçu via Sync.lua) ; token : compte Battle.net de ce personnage (entry.token, sert à
-- lister les personnages d'un compte autorisé).
-- surname : nom de famille (WoW Forever), s'il est connu.
function P.AddCharacter(name, realm, class, level, token, surname)
	name = name or UnitName("player")
	realm = realm or GetRealmName()
	local key = P.GetCharKey(name, realm)

	P.db.roster[key] = P.db.roster[key] or {}
	local entry = P.db.roster[key]
	entry.name = name
	entry.realm = realm

	if key == P.GetCharKey() then
		local _, playerClass = UnitClass("player")
		entry.class = playerClass
		entry.level = UnitLevel("player")
		entry.token = P.GetTeamToken() or entry.token
		local _, _, mySurname = P.UnitNameParts("player")
		entry.surname = mySurname
	elseif class then
		entry.class = class
		entry.level = level or entry.level
	end

	-- Un personnage qui s'annonce est bien là : il n'est plus retiré, avec une version plus
	-- récente que la pierre tombale pour qu'elle ne revienne pas par synchro.
	if entry.removed then
		entry.removed = nil
		entry.updated = NextVersion(entry.updated)
	end

	if token then
		entry.token = token
	end
	if surname and surname ~= "" then
		entry.surname = surname
	end
	entry.lastSeen = time()
	return key, entry
end

-- Personnages connus (roster actif) d'un compte, par son token : liste de clés triée.
function P.GetTokenCharacters(token)
	local keys = {}
	for key, entry in pairs(P.GetRoster()) do
		if entry.token == token then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys)
	return keys
end

-- Ajoute le joueur ciblé au roster (ex. personnage d'un ami, sans Polypode) et le partage
-- avec les autres Polypode. Renvoie true et la clé, ou false et un message d'erreur.
function P.AddTargetCharacter()
	if not UnitExists("target") or not UnitIsPlayer("target") then
		return false, "Ciblez d'abord un joueur."
	end
	local name, realm, surname = P.UnitNameParts("target")
	realm = realm or GetRealmName()
	local key = P.GetCharKey(name, realm)
	if P.GetCharacter(key) then
		return false, key .. " est déjà dans la liste."
	end

	local entry = P.db.roster[key] or {}
	P.db.roster[key] = entry
	local _, class = UnitClass("target")
	local level = UnitLevel("target")
	entry.name = name
	entry.realm = realm
	entry.surname = surname or entry.surname
	entry.class = class
	entry.level = level and level > 0 and level or entry.level
	entry.removed = nil
	entry.lastSeen = time()
	CharacterChanged(key)
	return true, key
end

-- Retire un personnage du roster (pierre tombale synchronisée). Renvoie true si retiré.
function P.RemoveCharacter(key)
	local entry = P.GetCharacter(key)
	if not entry then
		return false
	end
	entry.removed = true
	CharacterChanged(key)
	-- Un personnage retiré du roster ne reste membre (ni leader) d'aucune équipe.
	for name in pairs(P.GetTeams()) do
		P.RemoveTeamMember(name, key)
	end
	return true
end

-- Entrée active du roster, ou nil (absente ou retirée).
function P.GetCharacter(key)
	local entry = key and P.db.roster[key]
	if entry and not entry.removed then
		return entry
	end
end

-- Roster actif : { [nom-royaume] = entrée }, sans les personnages retirés.
function P.GetRoster()
	local roster = {}
	for key, entry in pairs(P.db.roster) do
		if not entry.removed then
			roster[key] = entry
		end
	end
	return roster
end

-- Applique une entrée de roster reçue d'un autre client (Sync.lua), sans la renvoyer :
-- seulement si sa version est plus récente que la locale. Les équipes ne sont pas
-- touchées : le client d'origine synchronise lui-même ses équipes modifiées.
-- Renvoie true si appliqué.
function P.ApplyCharacterSync(key, updated, removed, name, realm, class, level)
	local entry = P.db.roster[key]
	if entry and (entry.updated or 0) >= updated then
		return false
	end
	entry = entry or {}
	P.db.roster[key] = entry
	entry.name = name
	entry.realm = realm
	entry.class = class or entry.class
	entry.level = level or entry.level
	entry.removed = removed or nil
	entry.updated = updated
	entry.lastSeen = entry.lastSeen or time()
	return true
end

-- Toute modification locale d'une équipe passe par ici : horodatage (heure serveur, commune
-- à tous les clients) puis envoi aux autres Polypode. Indispensable quand plusieurs clients
-- partagent le même fichier de sauvegarde (jonctions entre comptes) : chacun le réécrit en
-- entier à la déconnexion, il faut donc que tous aient la même version en mémoire.
local function TeamChanged(teamName)
	local team = P.db.teams[teamName]
	team.updated = NextVersion(team.updated)
	if P.SyncTeam then
		P.SyncTeam(teamName)
	end
end

-- Équipe active (ni absente ni supprimée), ou nil. Une équipe supprimée reste dans
-- P.db.teams comme pierre tombale versionnée (removed = true), pour que la suppression
-- l'emporte sur les copies plus anciennes des autres clients : toute décision passe par ici.
local function ActiveTeam(teamName)
	local team = teamName and P.db.teams[teamName]
	if team and not team.removed then
		return team
	end
end

-- Crée une équipe (ou recrée une équipe supprimée, avec une version plus récente que sa
-- pierre tombale). Renvoie true, ou false et un message d'erreur à afficher.
-- Vérifie un nom d'équipe saisi. Renvoie le nom nettoyé, ou nil et un message d'erreur.
-- « : » exclu : le nouveau nom d'une équipe renommée voyage dans un champ de message TEAM.
local function CheckTeamName(name)
	name = strtrim(name or "")
	if name == "" then
		return nil, "Nom d'équipe vide."
	end
	if name:find(":", 1, true) then
		return nil, "Nom d'équipe invalide : pas de « : »."
	end
	if ActiveTeam(name) then
		return nil, "L'équipe « " .. name .. " » existe déjà."
	end
	return name
end

function P.CreateTeam(name)
	local err
	name, err = CheckTeamName(name)
	if not name then
		return false, err
	end
	local old = P.db.teams[name]
	P.db.teams[name] = { name = name, members = {}, updated = old and old.updated }
	TeamChanged(name)
	return true
end

-- Supprime une équipe (pierre tombale synchronisée). Renvoie true si supprimée.
function P.DeleteTeam(teamName)
	if not ActiveTeam(teamName) then
		return false
	end
	local old = P.db.teams[teamName]
	P.db.teams[teamName] = { name = teamName, members = {}, removed = true, updated = old.updated }
	TeamChanged(teamName)
	return true
end

-- Renomme une équipe : recréée sous le nouveau nom (membres et leader conservés), l'ancien
-- nom devient une pierre tombale qui retient le nouveau (renamedTo) : les personnages qui
-- l'avaient sélectionnée suivent le renommage (P.GetSelectedTeam), même reçu plus tard par
-- synchro. Renvoie true et le nouveau nom, ou false et un message d'erreur.
function P.RenameTeam(oldName, newName)
	local team = ActiveTeam(oldName)
	if not team then
		return false, "Équipe introuvable."
	end
	if strtrim(newName or "") == oldName then
		return false, "Le nom n'a pas changé."
	end
	local err
	newName, err = CheckTeamName(newName)
	if not newName then
		return false, err
	end
	local previous = P.db.teams[newName] -- pierre tombale éventuelle : sa version est dépassée
	local members = {}
	for key in pairs(team.members or {}) do
		members[key] = true
	end
	P.db.teams[newName] = { name = newName, members = members, leader = team.leader,
		updated = previous and previous.updated }
	TeamChanged(newName)
	P.db.teams[oldName] = { name = oldName, members = {}, removed = true, renamedTo = newName,
		updated = team.updated }
	TeamChanged(oldName)
	return true, newName
end

-- Vrai si l'équipe est une pierre tombale (supprimée), pour la synchro.
function P.IsTeamRemoved(teamName)
	local team = teamName and P.db.teams[teamName]
	return team ~= nil and team.removed == true
end

-- Équipes actives : { [nom] = équipe }, sans les équipes supprimées.
function P.GetTeams()
	local teams = {}
	for name, team in pairs(P.db.teams) do
		if not team.removed then
			teams[name] = team
		end
	end
	return teams
end

-- Membres d'une équipe : ensemble { [nom-royaume] = true }, ou nil si l'équipe n'existe pas.
-- Les équipes créées avant l'ajout des membres reçoivent un ensemble vide.
function P.GetTeamMembers(teamName)
	local team = ActiveTeam(teamName)
	if not team then
		return nil
	end
	team.members = team.members or {}
	return team.members
end

function P.AddTeamMember(teamName, key)
	local members = P.GetTeamMembers(teamName)
	if members and P.GetCharacter(key) and not members[key] then
		members[key] = true
		TeamChanged(teamName)
	end
end

-- Noms des équipes dont le personnage est membre, triés par ordre alphabétique.
function P.GetCharacterTeams(key)
	local names = {}
	for name, team in pairs(P.GetTeams()) do
		if team.members and team.members[key] then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

-- Retire un membre ; s'il était leader de l'équipe, l'équipe n'a plus de leader.
function P.RemoveTeamMember(teamName, key)
	local members = P.GetTeamMembers(teamName)
	if members and members[key] then
		members[key] = nil
		local team = P.db.teams[teamName]
		if team.leader == key then
			team.leader = nil
		end
		TeamChanged(teamName)
	end
end

-- Leader d'une équipe (clé nom-royaume), ou nil.
function P.GetTeamLeader(teamName)
	local team = ActiveTeam(teamName)
	return team and team.leader
end

-- Horodatage de la dernière modification d'une équipe (0 si inconnu : équipe antérieure
-- à la synchro automatique). Aussi pour une pierre tombale.
function P.GetTeamUpdated(teamName)
	local team = teamName and P.db.teams[teamName]
	return team and team.updated or 0
end

-- Applique une définition d'équipe reçue d'un autre client (Sync.lua), sans la renvoyer.
-- reset = true : premier fragment d'une version ; appliqué seulement si cette version est
-- plus récente que la version locale (une copie ancienne n'écrase jamais une récente) : les
-- membres sont remplacés. reset = false : fragment suivant ; appliqué seulement si la
-- version locale est celle du premier fragment (les membres s'ajoutent).
-- Les membres sont pris tels quels, même absents du roster local. removed = true : pierre
-- tombale (équipe supprimée), en un seul fragment ; leader porte alors le nouveau nom si
-- l'équipe a été renommée (renamedTo). Renvoie true si appliqué.
function P.ApplyTeamSync(teamName, updated, reset, leader, memberKeys, removed)
	local team = P.db.teams[teamName]
	if reset then
		if team and P.GetTeamUpdated(teamName) >= updated then
			return false
		end
		team = { name = teamName, members = {}, updated = updated }
		if removed then
			team.removed, team.renamedTo = true, leader
		else
			team.leader = leader
		end
		P.db.teams[teamName] = team
	elseif not team or team.removed or team.updated ~= updated then
		return false
	end
	for _, key in ipairs(memberKeys) do
		team.members[key] = true
	end
	return true
end

-- Désigne le leader d'une équipe ; il doit en être membre.
function P.SetTeamLeader(teamName, key)
	local members = P.GetTeamMembers(teamName)
	if members and members[key] and P.db.teams[teamName].leader ~= key then
		P.db.teams[teamName].leader = key
		TeamChanged(teamName)
	end
end

-- Équipe sélectionnée pour ce personnage (P.charDb.selectedTeam), ou nil si aucune ou si
-- elle n'existe pas (encore) localement.
-- COMPTES AUTORISÉS ---------------------------------------------------------------------

-- Vrai si les messages portant ce token sont acceptés : le nôtre, ou un compte autorisé.
function P.IsTokenTrusted(token)
	if not token then
		return false
	end
	if token == P.GetTeamToken() then
		return true
	end
	local entry = P.db.trustedTokens[token]
	return entry ~= nil and not entry.removed
end

-- Comptes autorisés actifs, triés par libellé : liste de { token, label }.
function P.GetTrustedTokens()
	local list = {}
	for token, entry in pairs(P.db.trustedTokens) do
		if not entry.removed then
			list[#list + 1] = { token = token, label = entry.label or "?" }
		end
	end
	table.sort(list, function(a, b)
		return a.label < b.label
	end)
	return list
end

-- Modification locale d'une autorisation : nouvelle version puis envoi aux autres clients.
local function TrustChanged(token)
	local entry = P.db.trustedTokens[token]
	entry.updated = NextVersion(entry.updated)
	if P.SyncTrust then
		P.SyncTrust(token)
	end
end

-- Autorise un autre compte (token), label : personnage vu à ce moment.
function P.TrustToken(token, label)
	local entry = P.db.trustedTokens[token] or {}
	P.db.trustedTokens[token] = entry
	entry.label = label
	entry.removed = nil
	TrustChanged(token)
end

-- Retire l'autorisation d'un compte (pierre tombale synchronisée). Renvoie true si retiré.
function P.UntrustToken(token)
	local entry = P.db.trustedTokens[token]
	if not entry or entry.removed then
		return false
	end
	entry.removed = true
	TrustChanged(token)
	return true
end

-- Applique une autorisation reçue d'un autre client de ce compte, si plus récente.
function P.ApplyTrustSync(token, updated, removed, label)
	local entry = P.db.trustedTokens[token]
	if entry and (entry.updated or 0) >= updated then
		return false
	end
	entry = entry or {}
	P.db.trustedTokens[token] = entry
	entry.label = label
	entry.removed = removed or nil
	entry.updated = updated
	return true
end

-- CANAL DÉDIÉ ---------------------------------------------------------------------------

-- Nom du canal dédié ("" si désactivé).
function P.GetSyncChannelName()
	return P.db.syncChannel.name or ""
end

-- Vérifie un nom de canal saisi. Renvoie le nom nettoyé ("" = désactiver), ou nil et un
-- message d'erreur. Un canal personnalisé WoW : pas d'espace, ne commence pas par un
-- chiffre (sinon confondu avec un numéro de canal), 31 caractères au plus ; « : » exclu
-- (séparateur des messages Polypode).
function P.CheckSyncChannelName(name)
	name = strtrim(name or "")
	if name == "" then
		return ""
	end
	if name:find("[%s:]") then
		return nil, "Nom de canal invalide : pas d'espace ni de « : »."
	end
	if name:find("^%d") then
		return nil, "Nom de canal invalide : il ne doit pas commencer par un chiffre."
	end
	if #name > 31 then
		return nil, "Nom de canal trop long (31 caractères au plus)."
	end
	return name
end

-- Change le canal dédié (saisie locale) : nouvelle version, rejoint le canal et partage le
-- réglage avec les autres clients. Renvoie true, ou false et un message d'erreur.
function P.SetSyncChannel(name)
	local cleaned, err = P.CheckSyncChannelName(name)
	if not cleaned then
		return false, err
	end
	local setting = P.db.syncChannel
	if cleaned == setting.name then
		return true
	end
	local previous = setting.name
	setting.name = cleaned
	setting.updated = NextVersion(setting.updated)
	if P.ApplySyncChannel then
		P.ApplySyncChannel(previous)
	end
	if P.SyncChannelSetting then
		P.SyncChannelSetting()
	end
	return true
end

-- Applique un réglage de canal reçu d'un autre client, s'il est plus récent (sans le
-- renvoyer). Renvoie true si appliqué.
function P.ApplyChannelSettingSync(name, updated)
	local setting = P.db.syncChannel
	local cleaned = P.CheckSyncChannelName(name)
	if not cleaned or (setting.updated or 0) >= updated then
		return false
	end
	local previous = setting.name
	setting.name = cleaned
	setting.updated = updated
	if P.ApplySyncChannel then
		P.ApplySyncChannel(previous)
	end
	return true
end

-- Une équipe sélectionnée puis renommée (ici ou sur un autre client) est suivie sous son
-- nouveau nom, et le choix mémorisé mis à jour.
function P.GetSelectedTeam()
	local name = P.charDb and P.charDb.selectedTeam
	for _ = 1, 10 do -- chaîne de renommages, bornée
		local team = name and P.db.teams[name]
		if not team or not team.removed or not team.renamedTo then
			break
		end
		name = team.renamedTo
	end
	if ActiveTeam(name) then
		P.charDb.selectedTeam = name
		return name
	end
end

-- Vrai si ce personnage est le leader de son équipe sélectionnée.
function P.IsTeamLeader()
	local team = P.GetSelectedTeam()
	return team ~= nil and P.GetTeamLeader(team) == P.GetCharKey()
end

-- Raison pour laquelle ce personnage ne peut pas inviter l'équipe, ou nil s'il le peut :
-- seul le leader de l'équipe invite, et il faut un autre membre que soi. Règle commune au
-- bouton « Inviter l'équipe » et au raccourci clavier.
function P.GetInviteBlockedReason(teamName)
	if not teamName then
		return "Sélectionnez d'abord une équipe."
	end
	local leader = P.GetTeamLeader(teamName)
	if not leader then
		return "L'équipe n'a pas de leader : clic gauche sur un de ses personnages pour le désigner."
	end
	if leader ~= P.GetCharKey() then
		return "Seul le leader de l'équipe (" .. leader .. ") peut inviter l'équipe."
	end
	for key in pairs(P.GetTeamMembers(teamName) or {}) do
		if key ~= P.GetCharKey() then
			return nil
		end
	end
	return "L'équipe ne compte aucun autre membre que vous."
end

-- Nom à passer aux API qui ciblent un joueur (invitation, chuchotement addon) : "Nom" sur
-- notre royaume, sinon "Nom-Royaume" avec le royaume sous sa forme courte (sans espaces ni
-- tirets, ex. "ArgentDawn"). entry : entrée du roster.
function P.GetTargetName(entry)
	if entry.realm == GetRealmName() then
		return entry.name
	end
	return entry.name .. "-" .. (entry.realm:gsub("[%s%-]", ""))
end

-- Membres de l'équipe à inviter : ni le personnage courant, ni ceux déjà dans le groupe.
-- Renvoie une liste de noms d'invitation triée.
function P.GetTeamInvitees(teamName)
	local invitees = {}
	for key in pairs(P.GetTeamMembers(teamName) or {}) do
		local entry = P.GetCharacter(key)
		if entry and entry.name and key ~= P.GetCharKey() then
			local inviteName = P.GetTargetName(entry)
			if not UnitInParty(inviteName) and not UnitInRaid(inviteName) then
				invitees[#invitees + 1] = inviteName
			end
		end
	end
	table.sort(invitees)
	return invitees
end

-- Invite dans le groupe les membres de l'équipe (cf. P.GetTeamInvitees). En groupe (hors
-- raid), les invitations sont limitées aux places libres des 5.
-- Renvoie true et un message de bilan, ou false et un message d'erreur.
function P.InviteTeam(teamName)
	if IsInGroup() and not UnitIsGroupLeader("player")
		and not (IsInRaid() and UnitIsGroupAssistant("player")) then
		return false, "Seul le chef du groupe peut inviter."
	end

	local invitees = P.GetTeamInvitees(teamName)
	if #invitees == 0 then
		return false, "Aucun membre de l'équipe à inviter."
	end

	local slots = #invitees
	if not IsInRaid() then
		slots = math.min(slots, 5 - math.max(GetNumGroupMembers(), 1))
	end
	for i = 1, slots do
		C_PartyInfo.InviteUnit(invitees[i])
		P.Debug("Invitation : " .. invitees[i])
	end

	local message = slots .. " invitation(s) envoyée(s)."
	if slots < #invitees then
		message = message .. " Groupe complet : convertissez-le en raid puis réinvitez les "
			.. (#invitees - slots) .. " restant(s)."
	end
	return true, message
end
