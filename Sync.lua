-- Polypode: Sync — broadcast et réception des messages addon (annonce du roster, équipes)

local P = Polypode

-- Token d'équipe, calculé une fois disponible (BNGetInfo peut renvoyer nil tant que
-- Battle.net n'est pas connecté).
local teamToken

function P.RegisterComm()
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		C_ChatInfo.RegisterAddonMessagePrefix(P.SYNC_PREFIX)
	end
end

-- Hash djb2 sur 32 bits, en hexadécimal. Sert à ne jamais diffuser le BattleTag en clair ;
-- ce n'est pas une protection cryptographique, juste une reconnaissance d'équipe.
local function Hash(str)
	local h = 5381
	for i = 1, #str do
		h = (h * 33 + str:byte(i)) % 4294967296
	end
	return string.format("%08x", h)
end

-- Token partagé par tous les personnages d'un même compte Battle.net (tous les comptes
-- WoW d'un Battle.net ont le même BattleTag). Autres comptes Battle.net : cf. comptes autorisés.
function P.GetTeamToken()
	if not teamToken and BNGetInfo then
		local _, battleTag = BNGetInfo()
		if battleTag and battleTag ~= "" then
			teamToken = Hash(battleTag)
		end
	end
	return teamToken
end

-- CANAL DÉDIÉ : canal de discussion personnalisé (P.db.syncChannel, Core.lua), rejoint par
-- chaque client et masqué des fenêtres de chat. Les messages addon y passent avec le type
-- "CHANNEL" et le numéro du canal. Commun aux comptes, il sert comme la guilde pour les
-- annonces de connexion (HELLO/HI), même hors groupe et hors guilde commune.

local CHANNEL_JOIN_DELAY = 5 -- secondes après la connexion : rejoindre plus tôt peut voler
-- le numéro 1 au canal Général
local CHANNEL_HELLO_DELAY = 1 -- secondes entre la demande d'adhésion et l'annonce sur le canal

-- Numéro du canal dédié s'il est rejoint, sinon nil.
local function SyncChannelIndex()
	local name = P.db and P.GetSyncChannelName()
	if not name or name == "" then
		return nil
	end
	local index = GetChannelName(name)
	return index and index > 0 and index or nil
end

-- Rejoint le canal dédié (et quitte l'ancien, previous) puis s'y annonce. Appelé à la
-- connexion (différé) et à chaque changement du réglage (Core.lua).
function P.ApplySyncChannel(previous)
	local name = P.GetSyncChannelName()
	if previous and previous ~= "" and previous ~= name and GetChannelName(previous) > 0 then
		LeaveChannelByName(previous)
		P.Debug("Canal dédié quitté : " .. previous)
	end
	if name == "" then
		return
	end
	if GetChannelName(name) == 0 then
		JoinChannelByName(name) -- sans fenêtre de chat : le canal reste invisible
		P.Debug("Canal dédié rejoint : " .. name)
	end
	C_Timer.After(CHANNEL_HELLO_DELAY, function()
		if SyncChannelIndex() then
			P.SayHello("HELLO", "CHANNEL")
		end
	end)
end

-- Connexion (Events.lua) : rejoint le canal dédié après le chargement des canaux du jeu.
function P.JoinSyncChannelLater()
	C_Timer.After(CHANNEL_JOIN_DELAY, function()
		P.ApplySyncChannel()
	end)
end

-- Canal par défaut des annonces (HELLO/HI) : le canal dédié s'il est rejoint (il réunit
-- tous les clients, groupés ou non), sinon raid, groupe, guilde.
local function GetBroadcastChannel()
	if SyncChannelIndex() then
		return "CHANNEL"
	elseif IsInRaid() then
		return "RAID"
	elseif IsInGroup() then
		return "PARTY"
	elseif IsInGuild() then
		return "GUILD"
	end
	return nil
end

-- File d'envoi : le client WoW limite le débit des messages addon et rejette (sans les
-- mettre en attente) ceux qui dépassent. Les messages partent donc un par un ; un message
-- rejeté pour limite de débit reste en tête de file et est retenté plus tard.
local SEND_INTERVAL = 0.1 -- secondes entre deux messages
local THROTTLE_RETRY = 1 -- secondes avant de retenter un message rejeté
local THROTTLED = {
	[Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.AddonMessageThrottle or 3] = true,
	[Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.ChannelThrottle or 8] = true,
}
local sendQueue = {}
local pumping = false

-- Personnages connectés, vus pendant la session via HELLO/HI : [Nom-Royaume] = true.
-- Cibles de la synchro automatique (chuchoter un personnage hors ligne provoque une erreur).
local onlineChars = {}

-- Chuchotements addon récents : [nom tel qu'affiché par l'erreur] = GetTime() de l'envoi.
local recentWhispers = {}
local WHISPER_ERROR_WINDOW = 10 -- secondes pendant lesquelles l'erreur « hors ligne » est masquée

-- Nom complet "Nom-Royaume" (royaume sous forme courte), forme unique pour comparer et cibler.
local function FullName(name)
	if not name:find("-", 1, true) then
		return name .. "-" .. (GetNormalizedRealmName() or "")
	end
	return name
end

-- Masque « Aucun joueur nommé X n'est connecté » provoqué par nos chuchotements addon à un
-- personnage déconnecté, et le retire des personnages connectés.
local PLAYER_NOT_FOUND = ERR_CHAT_PLAYER_NOT_FOUND_S
	and "^" .. ERR_CHAT_PLAYER_NOT_FOUND_S:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)") .. "$"
if PLAYER_NOT_FOUND and ChatFrame_AddMessageEventFilter then
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, text)
		local name = text and text:match(PLAYER_NOT_FOUND)
		local sentAt = name and recentWhispers[name]
		if sentAt and GetTime() - sentAt < WHISPER_ERROR_WINDOW then
			onlineChars[FullName(name)] = nil
			return true
		end
	end)
end

local function Pump()
	local item = sendQueue[1]
	if not item then
		pumping = false
		return
	end
	local result = C_ChatInfo.SendAddonMessage(P.SYNC_PREFIX, item.message, item.channel, item.target)
	if THROTTLED[result] then
		C_Timer.After(THROTTLE_RETRY, Pump)
		return
	end
	table.remove(sendQueue, 1)
	C_Timer.After(SEND_INTERVAL, Pump)
end

-- Envoie un message addon (via la file). Sans canal : groupe/raid/guilde selon la situation.
-- channel = "WHISPER" : target est le nom du destinataire (cf. P.GetTargetName).
function P.Broadcast(message, channel, target)
	channel = channel or GetBroadcastChannel()
	if channel == "CHANNEL" then
		-- Canal dédié : la cible est son numéro (canal quitté ou pas encore rejoint : rien).
		target = target or SyncChannelIndex()
		if not target then
			return
		end
		target = tostring(target)
	end
	if not channel or not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
		return
	end
	sendQueue[#sendQueue + 1] = { message = message, channel = channel, target = target }
	if channel == "WHISPER" and target then
		-- L'erreur « hors ligne » peut citer le nom complet ou le nom seul.
		recentWhispers[target] = GetTime()
		recentWhispers[(strsplit("-", target))] = GetTime()
	end
	if not pumping then
		pumping = true
		Pump()
	end
end

-- Annonce le personnage courant aux autres clients de l'équipe.
-- kind : "HELLO" (annonce spontanée, appelle une réponse) ou "HI" (réponse, sans suite).
-- Format : TYPE:token:nom:royaume:classe:niveau
function P.SayHello(kind, channel)
	local token = P.GetTeamToken()
	if not token then
		P.Debug("BattleTag indisponible, annonce non envoyée.")
		return
	end
	local _, class = UnitClass("player")
	local level = UnitLevel("player")
	P.Broadcast(string.format("%s:%s:%s:%s:%s:%d", kind or "HELLO", token,
		UnitName("player"), GetRealmName(), class, level), channel)
end

-- ACTIONS DU LEADER (Quests.lua, Cinematics.lua) : le leader de l'équipe sélectionnée
-- annonce au groupe/raid une action que les membres rejouent (cf. LEADER_ONLY).
-- Envoie « kind:token:fields » une seule fois par fenêtre de dédoublonnage (window secondes)
-- pour une même clé, quel que soit le nombre de déclencheurs (hooks, événements).
-- fields : champs après le token (peut être vide) ; reason : origine, pour le debug.
local lastLeaderAction = {} -- [dedupKey] = GetTime() du dernier envoi

function P.BroadcastLeaderAction(kind, fields, dedupKey, window, reason)
	if not P.IsTeamLeader() or not IsInGroup() then
		return
	end
	local now = GetTime()
	if lastLeaderAction[dedupKey] and now - lastLeaderAction[dedupKey] < window then
		return
	end
	local token = P.GetTeamToken()
	if not token then
		return
	end
	lastLeaderAction[dedupKey] = now
	local message = kind .. ":" .. token .. (fields ~= "" and (":" .. fields) or "")
	P.Broadcast(message, IsInRaid() and "RAID" or "PARTY")
	P.Debug(kind .. " " .. fields .. " annoncé au groupe (" .. reason .. ")")
end

-- Taille maximale d'un message addon (octets), imposée par le client WoW.
local MAX_MESSAGE_LENGTH = 255

-- Destinataires d'une synchro, en noms complets, soi exclu : target s'il est fourni, sinon
-- les clients connectés vus pendant la session (onlineChars) plus les clés extraKeys
-- (Nom-Royaume) éventuelles.
local function ResolveTargets(target, extraKeys)
	local targets = {}
	if target then
		targets[FullName(target)] = true
	else
		for name in pairs(onlineChars) do
			targets[name] = true
		end
		for _, key in ipairs(extraKeys or {}) do
			local name, realm = strsplit("-", key, 2)
			targets[FullName(P.GetTargetName({ name = name, realm = realm or "" }))] = true
		end
	end
	targets[FullName(P.GetTargetName({ name = UnitName("player"), realm = GetRealmName() }))] = nil
	return targets
end

-- Envoie une entrée de roster ajoutée ou retirée à la main (cible, /poly remove) : les
-- personnages sans Polypode ne s'annoncent jamais, les autres clients doivent la recevoir.
-- target : un destinataire précis, sinon les clients connectés.
-- Format : CHAR:token:version:flag:classe:niveau:nom:royaume
--   flag "A" = actif, "R" = retiré ; royaume en dernier (peut contenir des espaces).
function P.SyncCharacter(key, target)
	local token = P.GetTeamToken()
	local entry = P.db.roster[key]
	if not token or not entry or not entry.updated or not entry.name or not entry.realm then
		return
	end
	local message = string.format("CHAR:%s:%d:%s:%s:%s:%s:%s", token, entry.updated,
		entry.removed and "R" or "A", entry.class or "", entry.level or "", entry.name, entry.realm)
	for to in pairs(ResolveTargets(target)) do
		P.Broadcast(message, "WHISPER", to)
		P.Debug("Personnage " .. key .. " envoyé à " .. to)
	end
end

-- Messages acceptés seulement de nos propres clients (même token), pas des comptes autorisés.
local OWN_ACCOUNT_ONLY = {
	CHANSET = true,
	TRUST = true,
}

-- Envoie une autorisation de compte (versionnée) : token précis, ou toutes si nil ; à target,
-- sinon aux clients connectés. Les comptes autorisés la reçoivent aussi mais l'ignorent
-- (OWN_ACCOUNT_ONLY).
-- Format : TRUST:token:version:flag:tokenAutorisé:libellé (flag "A" autorisé, "R" retiré ;
-- libellé en dernier).
function P.SyncTrust(trusted, target)
	local token = P.GetTeamToken()
	if not token then
		return
	end
	for trustedToken, entry in pairs(P.db.trustedTokens) do
		if (not trusted or trustedToken == trusted) and entry.updated then
			local message = string.format("TRUST:%s:%d:%s:%s:%s", token, entry.updated,
				entry.removed and "R" or "A", trustedToken, entry.label or "")
			for to in pairs(ResolveTargets(target)) do
				P.Broadcast(message, "WHISPER", to)
			end
		end
	end
end

-- Réception de TRUST (de nos propres clients seulement).
local function OnTrustMessage(rest, sender)
	local version, flag, trustedToken, label = strsplit(":", rest or "", 4)
	local updated = tonumber(version)
	if not updated or not trustedToken or trustedToken == "" or (flag ~= "A" and flag ~= "R") then
		return
	end
	if P.ApplyTrustSync(trustedToken, updated, flag == "R", label) then
		P.Debug("Autorisation du compte « " .. tostring(label) .. " » reçue de " .. tostring(sender))
		if P.RefreshUI then
			P.RefreshUI()
		end
	end
end

-- Envoie le réglage du canal dédié (s'il a été choisi au moins une fois) par chuchotement :
-- à target, sinon aux clients connectés. Il passe par les canaux habituels, puisque le
-- destinataire n'a peut-être pas encore rejoint le nouveau canal.
-- Format : CHANSET:token:version:nom (nom vide = canal désactivé).
function P.SyncChannelSetting(target)
	local token = P.GetTeamToken()
	local setting = P.db.syncChannel
	if not token or (setting.updated or 0) == 0 then
		return
	end
	local message = string.format("CHANSET:%s:%d:%s", token, setting.updated, setting.name or "")
	for to in pairs(ResolveTargets(target)) do
		P.Broadcast(message, "WHISPER", to)
	end
end

-- Réception de CHANSET : adopte le canal s'il est plus récent, puis rafraîchit la fenêtre.
local function OnChannelSettingMessage(rest, sender)
	local version, name = strsplit(":", rest or "", 2)
	local updated = tonumber(version)
	if updated and P.ApplyChannelSettingSync(name or "", updated) then
		P.Debug("Canal dédié « " .. (name or "") .. " » reçu de " .. tostring(sender))
		if P.RefreshUI then
			P.RefreshUI()
		end
	end
end

-- Envoie toutes les entrées manuelles du roster (versionnées) à un destinataire.
function P.SyncAllCharacters(target)
	for key, entry in pairs(P.db.roster) do
		if entry.updated then
			P.SyncCharacter(key, target)
		end
	end
end

-- Réception d'une entrée CHAR (cf. P.SyncCharacter).
local function OnCharMessage(rest, sender)
	local version, flag, class, level, name, realm = strsplit(":", rest or "", 6)
	local updated = tonumber(version)
	if not updated or not name or name == "" or not realm or realm == ""
		or (flag ~= "A" and flag ~= "R") then
		return
	end
	local key = P.GetCharKey(name, realm)
	if P.ApplyCharacterSync(key, updated, flag == "R", name, realm,
		class ~= "" and class or nil, tonumber(level)) then
		P.Debug("Personnage " .. key .. " reçu de " .. tostring(sender))
		if P.RefreshUI then
			P.RefreshUI()
		end
	end
end

-- Envoie la définition d'une équipe (version, leader, membres, nom) par chuchotement addon :
-- fiable même hors groupe (ex. invités qui n'ont pas encore accepté).
-- target : un destinataire précis ; sinon les personnages connectés vus pendant la session
--   (onlineChars), plus, si select, les membres de l'équipe (clic « Inviter l'équipe » :
--   les invités ne se sont pas forcément annoncés).
-- select : le destinataire sélectionne l'équipe dans sa fenêtre.
-- Format : TEAM:token:flag:version:leader:membre1,membre2,...:nomÉquipe
--   flag "N" = premier fragment, "S" = premier fragment + sélection, "+" = suite ;
--   version = heure serveur de la dernière modification (la plus récente l'emporte) ;
--   le nom d'équipe est en dernier pour pouvoir contenir ":".
-- Les membres sont découpés en fragments pour respecter MAX_MESSAGE_LENGTH.
function P.SyncTeam(teamName, target, select)
	local token = P.GetTeamToken()
	local members = P.GetTeamMembers(teamName)
	if not token or not members then
		P.Debug("Synchro d'équipe impossible (BattleTag ou équipe indisponible).")
		return
	end

	local first = select and "S" or "N"
	local updated = P.GetTeamUpdated(teamName)
	local leader = P.GetTeamLeader(teamName) or ""
	local keys = {}
	for key in pairs(members) do
		keys[#keys + 1] = key
	end
	table.sort(keys)

	-- Découpe la liste en fragments tenant dans un message.
	local chunks, current = {}, {}
	-- Place restante pour la liste des membres, une fois l'en-tête et le nom comptés.
	local budget = MAX_MESSAGE_LENGTH
		- #string.format("TEAM:%s:%s:%d:%s::%s", token, first, updated, leader, teamName)
	local used = 0
	for _, key in ipairs(keys) do
		local cost = #key + (#current > 0 and 1 or 0)
		if #current > 0 and used + cost > budget then
			chunks[#chunks + 1] = current
			current, used = {}, 0
			cost = #key
		end
		current[#current + 1] = key
		used = used + cost
	end
	chunks[#chunks + 1] = current -- au moins un fragment, même vide (équipe sans membre)

	local messages = {}
	for i, chunk in ipairs(chunks) do
		messages[i] = string.format("TEAM:%s:%s:%d:%s:%s:%s", token, i == 1 and first or "+", updated,
			leader, table.concat(chunk, ","), teamName)
	end

	for to in pairs(ResolveTargets(target, select and keys or nil)) do
		for _, message in ipairs(messages) do
			P.Broadcast(message, "WHISPER", to)
		end
		P.Debug("Équipe « " .. teamName .. " » envoyée à " .. to)
	end
end

-- Envoie toutes les équipes à un destinataire (ex. client qui vient de se connecter).
function P.SyncAllTeams(target)
	for teamName in pairs(P.GetTeams()) do
		P.SyncTeam(teamName, target)
	end
end

-- Réception d'un fragment TEAM (cf. P.SyncTeam) : met à jour l'équipe locale si la version
-- reçue est plus récente, puis rafraîchit la fenêtre (et sélectionne l'équipe si demandé).
local function OnTeamMessage(rest, sender)
	local flag, version, leader, memberList, teamName = strsplit(":", rest, 5)
	local updated = tonumber(version)
	teamName = teamName and strtrim(teamName)
	-- 32 caractères au plus à la saisie, soit au plus 128 octets en UTF-8.
	if not teamName or teamName == "" or #teamName > 128 or not updated
		or (flag ~= "N" and flag ~= "S" and flag ~= "+") then
		return
	end

	local memberKeys = {}
	for key in (memberList or ""):gmatch("[^,]+") do
		memberKeys[#memberKeys + 1] = key
	end
	local applied = P.ApplyTeamSync(teamName, updated, flag ~= "+", leader ~= "" and leader or nil, memberKeys)
	if applied then
		P.Debug("Équipe « " .. teamName .. " » reçue de " .. tostring(sender))
	end

	-- La sélection est demandée même si la version locale était déjà à jour.
	if flag == "S" and P.GetTeams()[teamName] and P.SelectTeam then
		P.SelectTeam(teamName)
	elseif applied and P.RefreshUI then
		P.RefreshUI()
	end
end

-- Messages de quête et de dialogue (Quests.lua) : actions que les membres rejouent. Ils ne
-- sont acceptés que du leader de l'équipe sélectionnée, et jamais de soi-même (un message
-- de groupe/raid revient aussi à son expéditeur, qui rejouerait sa propre action).
local LEADER_ONLY = {
	QACCEPT = true,
	QVALIDATE = true,
	QREWARD = true,
	GQAVAIL = true,
	GQACTIVE = true,
	GOSSIP = true,
	CLOSEUI = true,
	CINESKIP = true,
	TAXI = true,
	DELVEENTER = true,
	DELVEEXIT = true,
	INSTENTER = true,
	VOLUME = true,
	SOUND = true,
}

-- Vrai si l'expéditeur (Nom-Royaume du message addon) est la clé de roster key.
local function IsSender(sender, key)
	local name, realm = strsplit("-", key, 2)
	return FullName(sender) == FullName(P.GetTargetName({ name = name, realm = realm or "" }))
end

function P.OnSyncMessage(message, channel, sender)
	local kind, token, rest = strsplit(":", message, 3)

	-- Token inconnu : sur le canal dédié, une annonce de connexion ouvre une demande
	-- d'autorisation (autre compte Battle.net de multibox) ; ailleurs (guilde, groupe),
	-- ignoré sans demande (autres joueurs Polypode de la guilde).
	if not P.IsTokenTrusted(token) then
		if channel == "CHANNEL" and (kind == "HELLO" or kind == "HI") and P.PromptTrust then
			P.PromptTrust(token, message, channel, sender)
		else
			P.Debug("Message ignoré (compte non autorisé) : " .. tostring(sender))
		end
		return
	end

	-- Réglages propres à ce compte : seulement de nos propres clients, jamais d'un compte
	-- autorisé (pas de changement de canal ni d'autorisation en cascade).
	if OWN_ACCOUNT_ONLY[kind] and token ~= P.GetTeamToken() then
		return
	end

	if LEADER_ONLY[kind] then
		local team = P.GetSelectedTeam()
		local leader = team and P.GetTeamLeader(team)
		if IsSender(sender, P.GetCharKey()) then
			return
		end
		if not leader or not IsSender(sender, leader) then
			P.Debug(kind .. " ignoré : " .. tostring(sender) .. " n'est pas le leader de l'équipe sélectionnée")
			return
		end
	end

	if kind == "TEAM" then
		OnTeamMessage(rest, sender)
		return
	elseif kind == "CHAR" then
		OnCharMessage(rest, sender)
		return
	elseif kind == "CHANSET" then
		OnChannelSettingMessage(rest, sender)
		return
	elseif kind == "TRUST" then
		OnTrustMessage(rest, sender)
		return
	elseif kind == "QACCEPT" then
		-- QACCEPT:token:questID — quête acceptée par le leader (Quests.lua).
		P.OnQuestAcceptMessage(tonumber(rest), sender)
		return
	elseif kind == "QVALIDATE" then
		-- QVALIDATE:token:questID — le leader a cliqué « Continuer » (Quests.lua).
		P.OnQuestValidateMessage(tonumber(rest), sender)
		return
	elseif kind == "QREWARD" then
		-- QREWARD:token:questID:choix — le leader a terminé la quête (Quests.lua).
		local questID, choice = strsplit(":", rest or "")
		P.OnQuestRewardMessage(tonumber(questID), tonumber(choice), sender)
		return
	elseif kind == "GQAVAIL" or kind == "GQACTIVE" then
		-- GQAVAIL / GQACTIVE:token:questID — quête choisie dans un dialogue de PNJ (Quests.lua).
		P.OnGossipQuestMessage(kind, tonumber(rest), sender)
		return
	elseif kind == "GOSSIP" then
		-- GOSSIP:token:gossipOptionID:orderIndex — option de dialogue choisie (Quests.lua).
		local gossipOptionID, orderIndex = strsplit(":", rest or "")
		P.OnGossipOptionMessage(tonumber(gossipOptionID), tonumber(orderIndex), sender)
		return
	elseif kind == "CLOSEUI" then
		-- CLOSEUI:token — le leader a fermé son DialogueUI (Quests.lua).
		P.OnDialogCloseMessage(sender)
		return
	elseif kind == "CINESKIP" then
		-- CINESKIP:token:kind — le leader a passé une cinématique (Cinematics.lua).
		P.OnCinematicSkipMessage(rest, sender)
		return
	elseif kind == "TAXI" then
		-- TAXI:token:nomDestination — le leader a pris un vol (Taxi.lua).
		P.OnTaxiMessage(rest, sender)
		return
	elseif kind == "DELVEENTER" then
		-- DELVEENTER:token:palier — le leader entre dans un gouffre (Instances.lua).
		P.OnDelveEnterMessage(tonumber(rest), sender)
		return
	elseif kind == "DELVEEXIT" then
		-- DELVEEXIT:token — le leader vote la sortie du gouffre (Instances.lua).
		P.OnDelveExitMessage(sender)
		return
	elseif kind == "INSTENTER" then
		-- INSTENTER:token:portal — le leader entre par un portail d'instance (Instances.lua).
		P.OnInstanceEnterMessage(rest, sender)
		return
	elseif kind == "VOLUME" then
		-- VOLUME:token:pourcentage — volume principal envoyé par le leader (Sound.lua).
		P.OnVolumeMessage(tonumber(rest), sender)
		return
	elseif kind == "SOUND" then
		-- SOUND:token:0|1 — son coupé / rétabli par le leader (Sound.lua).
		P.OnSoundMessage(rest, sender)
		return
	end

	if kind ~= "HELLO" and kind ~= "HI" then
		return
	end
	local name, realm, class, level = strsplit(":", rest or "")
	if not name or not realm then
		return
	end

	-- Nos propres messages nous reviennent : rien à faire.
	if P.GetCharKey(name, realm) == P.GetCharKey() then
		return
	end

	P.AddCharacter(name, realm, class, tonumber(level), token)
	if P.RefreshUI then
		P.RefreshUI()
	end
	P.Debug("Roster mis à jour via sync : " .. name .. "-" .. realm .. " (de " .. sender .. ")")

	-- Répond à une annonce spontanée pour que le nouvel arrivant nous connaisse aussi.
	if kind == "HELLO" then
		P.SayHello("HI", channel)
	end

	-- L'expéditeur est connecté : il recevra les synchros automatiques d'équipes.
	onlineChars[FullName(sender)] = true

	-- Échange du roster manuel puis des équipes dans les deux sens (HELLO puis HI) : chaque
	-- client récupère les versions plus récentes de l'autre, même s'il a démarré sur une
	-- sauvegarde ancienne. Le roster d'abord : les équipes peuvent y faire référence.
	P.SyncChannelSetting(sender)
	P.SyncTrust(nil, sender)
	P.SyncAllCharacters(sender)
	P.SyncAllTeams(sender)

	-- Leader : invite automatiquement ce personnage s'il est membre de l'équipe (AutoGroup.lua).
	P.OnTeamCharacterOnline(P.GetCharKey(name, realm))
end
