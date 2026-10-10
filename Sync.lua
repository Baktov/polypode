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
			if P.RefreshUI then
				P.RefreshUI() -- « Personnages disponibles » : passe parmi les déconnectés
			end
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
-- Format : TYPE:token:nom:royaume:classe:niveau:nomDeFamille (nom de famille vide sur
-- Retail ; champ ajouté en dernier, ignoré par les versions qui ne le lisent pas).
function P.SayHello(kind, channel)
	local token = P.GetTeamToken()
	if not token then
		P.Debug("BattleTag indisponible, annonce non envoyée.")
		return
	end
	local _, class = UnitClass("player")
	local level = UnitLevel("player")
	local _, _, surname = P.UnitNameParts("player")
	P.Broadcast(string.format("%s:%s:%s:%s:%s:%d:%s", kind or "HELLO", token,
		UnitName("player"), GetRealmName(), class, level, surname or ""), channel)
end

-- Groupe qui s'agrandit : s'y annonce (HELLO), car un client rejoint sans canal dédié ni
-- guilde commune n'a jamais reçu notre annonce de connexion ; l'échange HELLO/HI qui suit
-- synchronise roster et équipes. Différé pour regrouper les GROUP_ROSTER_UPDATE en rafale.
local GROUP_HELLO_DELAY = 2 -- secondes
local lastHelloGroupSize = 0
local groupHelloPending = false

function P.OnGroupRosterHello()
	if groupHelloPending then
		return
	end
	groupHelloPending = true
	C_Timer.After(GROUP_HELLO_DELAY, function()
		groupHelloPending = false
		local size = IsInGroup() and GetNumGroupMembers() or 0
		if size > lastHelloGroupSize then
			P.SayHello("HELLO", IsInRaid() and "RAID" or "PARTY")
			P.Debug("Annonce au groupe (" .. size .. " membres)")
		end
		lastHelloGroupSize = size
	end)
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

-- POINTS D'EXTENSION DES ADDONS COMPAGNONS (ex. Polypode Suivi) : échanger leurs propres
-- messages sans que Polypode les connaisse. Le préfixe, le token et le filtrage des comptes
-- restent ceux de Polypode (P.OnSyncMessage).
P.MAX_MESSAGE_LENGTH = MAX_MESSAGE_LENGTH
local messageHandlers = {} -- [type] = handler(reste, expéditeur)
local peerCallbacks = {} -- fonctions(expéditeur) appelées à chaque HELLO/HI reçu

-- Reçoit les messages « type:token:reste » d'un type propre au compagnon (token déjà vérifié).
function P.RegisterMessageHandler(kind, handler)
	messageHandlers[kind] = handler
end

-- Appelle callback(expéditeur) à chaque client qui s'annonce (HELLO/HI), pour lui envoyer ses
-- données comme Polypode le fait (équipes, état, journal de quêtes).
function P.RegisterPeerCallback(callback)
	peerCallbacks[#peerCallbacks + 1] = callback
end

-- Envoie un message en chuchotement à target, sinon aux clients connectés vus pendant la session.
function P.WhisperOnline(message, target)
	for to in pairs(ResolveTargets(target)) do
		P.Broadcast(message, "WHISPER", to)
	end
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

-- ÉTAT DES PERSONNAGES : ce que la liste d'amis montrerait (race, spécialisation, niveau,
-- niveau d'objet, guilde, zone) plus la progression du niveau (% d'XP), pour les infobulles
-- et les détails de la barre flottante d'équipe (WoW ne donne ces infos que sur une unité
-- du groupe). Chaque client envoie le sien aux clients connectés à chaque rencontre
-- (HELLO/HI) et quand il change ; gardé en mémoire (session seulement).
-- Format : STATUS:token:niveau:ilvl:race:spé:guilde:xp:durabilité:nom:royaume:zone (zone en
-- dernier ; xp = % du niveau en cours, vide au niveau maximum ; durabilité = % de la pièce
-- équipée la plus usée, vide sans pièce à durabilité).
local characterStatus = {} -- [nom-royaume] = { level, ilvl, race, spec, guild, xp, durability, zone, received }
local lastStatusSent
local statusPending

-- % d'XP du niveau en cours (entier), ou nil au niveau maximum (ou XP désactivée).
local function ExperiencePercent()
	if (IsPlayerAtEffectiveMaxLevel and IsPlayerAtEffectiveMaxLevel())
		or (IsXPUserDisabled and IsXPUserDisabled()) then
		return nil
	end
	local max = UnitXPMax("player")
	if not max or max <= 0 then
		return nil
	end
	return math.floor(UnitXP("player") / max * 100)
end

-- % de durabilité de la pièce équipée la plus usée (comme l'alerte de durabilité de WoW),
-- ou nil si aucune pièce n'a de durabilité.
local function DurabilityPercent()
	local lowest
	for slot = 1, 18 do
		local current, maximum = GetInventoryItemDurability(slot)
		if current and maximum and maximum > 0 then
			local percent = current / maximum * 100
			if not lowest or percent < lowest then
				lowest = percent
			end
		end
	end
	return lowest and math.floor(lowest) or nil
end

-- État courant du personnage joué (même forme que les états reçus).
local function LocalStatus()
	local specIndex = GetSpecialization and GetSpecialization()
	local spec = specIndex and select(2, GetSpecializationInfo(specIndex))
	local _, ilvl = GetAverageItemLevel()
	return {
		level = UnitLevel("player"),
		ilvl = math.floor(ilvl or 0),
		race = UnitRace("player"),
		spec = spec,
		guild = GetGuildInfo("player"),
		xp = ExperiencePercent(),
		durability = DurabilityPercent(),
		zone = GetRealZoneText(),
		received = GetTime(),
	}
end

local function BuildStatusMessage(token)
	local s = LocalStatus()
	return string.format("STATUS:%s:%d:%d:%s:%s:%s:%s:%s:%s:%s:%s", token, s.level, s.ilvl,
		s.race or "", s.spec or "", s.guild or "", s.xp or "", s.durability or "", UnitName("player"),
		GetRealmName(), s.zone or "")
end

-- Envoie l'état du personnage : à target (rencontre), sinon aux clients connectés s'il a
-- changé depuis le dernier envoi.
function P.SendStatus(target)
	local token = P.GetTeamToken()
	if not token then
		return
	end
	local message = BuildStatusMessage(token)
	if not target then
		if message == lastStatusSent then
			return
		end
		lastStatusSent = message
	end
	for to in pairs(ResolveTargets(target)) do
		P.Broadcast(message, "WHISPER", to)
	end
end

-- Changement d'état (zone, niveau, XP, spécialisation, équipement, guilde ; Events.lua) :
-- envoi différé de 2 s, les événements arrivant souvent en rafale (équipement, XP), puis
-- mise à jour de la barre flottante (état du personnage joué).
function P.ScheduleStatus()
	if statusPending then
		return
	end
	statusPending = true
	C_Timer.After(2, function()
		statusPending = nil
		P.SendStatus()
		if P.RefreshTeamBar then
			P.RefreshTeamBar()
		end
	end)
end

local function OnStatusMessage(rest)
	local level, ilvl, race, spec, guild, xp, durability, name, realm, zone = strsplit(":", rest or "", 10)
	if not name or name == "" or not realm or realm == "" then
		return
	end
	characterStatus[P.GetCharKey(name, realm)] = {
		level = tonumber(level),
		ilvl = tonumber(ilvl),
		race = race ~= "" and race or nil,
		spec = spec ~= "" and spec or nil,
		guild = guild ~= "" and guild or nil,
		xp = tonumber(xp),
		durability = tonumber(durability),
		zone = zone ~= "" and zone or nil,
		received = GetTime(),
	}
	if P.RefreshTeamBar then
		P.RefreshTeamBar()
	end
end

-- État d'un personnage : le personnage joué est lu en direct, les autres sont le dernier état
-- reçu pendant la session (nil si aucun).
function P.GetCharacterStatus(key)
	if key == P.GetCharKey() then
		return LocalStatus()
	end
	return characterStatus[key]
end

-- Vrai si le personnage s'est annoncé pendant la session sans erreur « non connecté » depuis.
function P.IsCharacterOnline(key)
	local entry = P.db.roster[key]
	return entry ~= nil and entry.name ~= nil and entry.realm ~= nil
		and onlineChars[FullName(P.GetTargetName(entry))] == true
end

-- JOURNAUX DE QUÊTES (fenêtre « Quêtes de l'équipe », UI_TeamQuests.lua) : chaque client
-- envoie la liste de ses quêtes (identifiants, P.GetOwnQuestIDs) aux clients connectés à
-- chaque rencontre (HELLO/HI) et quand elle change ; gardée en mémoire (session).
-- Format : QLOG:token:flag:envoi:nom-royaume:id1,id2,... — flag N = premier fragment (remplace
-- la liste), + = suite ; envoi = numéro d'envoi de l'expéditeur, pour rattacher les fragments.
local questLogs = {} -- [nom-royaume] = { seq, ids = { [questID] = true } }
local questLogSeq = 0
local questLogPending
local lastQuestLogSent -- dernière liste envoyée aux clients connectés

-- Envoie le journal : à target (rencontre), sinon aux clients connectés s'il a changé depuis
-- le dernier envoi (une expédition acceptée en entrant dans sa zone ne le change pas).
function P.SendQuestLog(target)
	local token = P.GetTeamToken()
	if not token then
		return
	end
	local ids = {}
	for questID in pairs(P.GetOwnQuestIDs()) do
		ids[#ids + 1] = tostring(questID)
	end
	table.sort(ids)
	if not target then
		local list = table.concat(ids, ",")
		if list == lastQuestLogSent then
			return
		end
		lastQuestLogSent = list
	end
	questLogSeq = questLogSeq + 1

	local key = P.GetCharKey()
	local budget = MAX_MESSAGE_LENGTH - #string.format("QLOG:%s:N:%d:%s:", token, questLogSeq, key)
	local chunks, current, used = {}, {}, 0
	for _, id in ipairs(ids) do
		local cost = #id + (#current > 0 and 1 or 0)
		if #current > 0 and used + cost > budget then
			chunks[#chunks + 1] = current
			current, used, cost = {}, 0, #id
		end
		current[#current + 1] = id
		used = used + cost
	end
	chunks[#chunks + 1] = current -- au moins un fragment, même vide (journal vide)

	for to in pairs(ResolveTargets(target)) do
		for i, chunk in ipairs(chunks) do
			P.Broadcast(string.format("QLOG:%s:%s:%d:%s:%s", token, i == 1 and "N" or "+", questLogSeq,
				key, table.concat(chunk, ",")), "WHISPER", to)
		end
	end
end

-- Journal de quêtes reçu ou modifié : prévient les addons compagnons (panneau « Quêtes » de Polypode
-- Suivi) par P.RegisterQuestLogCallback(fn) (0.58.0) ; P.RefreshTeamQuests (ancien addon Polypode
-- Quêtes, obsolète) reste appelé s'il est défini.
local questLogCallbacks = {}

function P.RegisterQuestLogCallback(callback)
	questLogCallbacks[#questLogCallbacks + 1] = callback
end

local function NotifyQuestLog()
	if P.RefreshTeamQuests then
		P.RefreshTeamQuests()
	end
	for _, callback in ipairs(questLogCallbacks) do
		callback()
	end
end

-- Journal modifié (quête acceptée, rendue, abandonnée ; Quests.lua) : envoi différé de 2 s,
-- puis les addons compagnons sont prévenus (NotifyQuestLog).
function P.ScheduleQuestLog()
	if questLogPending then
		return
	end
	questLogPending = true
	C_Timer.After(2, function()
		questLogPending = nil
		P.SendQuestLog()
		NotifyQuestLog()
	end)
end

-- Réception d'un fragment QLOG (expéditeur déjà vérifié par P.OnSyncMessage).
local function OnQuestLogMessage(rest)
	local flag, seq, key, list = strsplit(":", rest or "", 4)
	seq = tonumber(seq)
	if not seq or not key or key == "" then
		return
	end
	local log = questLogs[key]
	if flag == "N" then
		log = { seq = seq, ids = {} }
		questLogs[key] = log
	elseif flag ~= "+" or not log or log.seq ~= seq then
		return
	end
	for id in (list or ""):gmatch("%d+") do
		log.ids[tonumber(id)] = true
	end
	NotifyQuestLog()
end

-- Quêtes d'un personnage : { [questID] = true }, lues en direct pour le personnage joué, sinon
-- dernier journal reçu pendant la session (nil si aucun).
function P.GetCharacterQuests(key)
	if key == P.GetCharKey() then
		return P.GetOwnQuestIDs()
	end
	return questLogs[key] and questLogs[key].ids
end

-- DISPOSITION DE LA BARRE FLOTTANTE (UI_TeamBar.lua, Maj + clic) : envoyée en WHISPER aux
-- membres connectés (ou groupés) de l'équipe, qui l'appliquent si leur barre est masquée.
-- Format : BARPOS:token:gauche:haut:largeur:hauteurListe:déplié:nomÉquipe — valeurs en % de
-- l'écran (hauteurListe vide = automatique, déplié 1/0), nom d'équipe en dernier.
-- Renvoie le nombre de destinataires.
function P.SyncTeamBarLayout(teamName, layout)
	local token = P.GetTeamToken()
	if not token then
		return 0
	end
	local message = string.format("BARPOS:%s:%.2f:%.2f:%.2f:%s:%d:%s", token, layout.left, layout.top,
		layout.width, layout.listHeight and string.format("%.2f", layout.listHeight) or "",
		layout.expanded and 1 or 0, teamName)
	local sent = 0
	for key in pairs(P.GetTeamMembers(teamName) or {}) do
		local entry = P.GetCharacter(key)
		if entry and entry.name and key ~= P.GetCharKey() then
			local name = P.GetTargetName(entry)
			if P.IsCharacterOnline(key) or UnitInParty(name) or UnitInRaid(name) then
				P.Broadcast(message, "WHISPER", name)
				sent = sent + 1
			end
		end
	end
	return sent
end

local function OnTeamBarLayoutMessage(rest)
	local left, top, width, listHeight, expanded, teamName = strsplit(":", rest or "", 6)
	left, top, width = tonumber(left), tonumber(top), tonumber(width)
	if not left or not top or not width or not teamName or teamName == "" or not P.ApplyTeamBarLayout then
		return
	end
	P.ApplyTeamBarLayout(teamName, {
		left = left,
		top = top,
		width = width,
		listHeight = tonumber(listHeight),
		expanded = expanded == "1",
	})
end

-- COMPTES WOW NOMMÉS (Core.lua) : rangement d'un personnage dans un compte WoW nommé à la
-- main, versionné. Envoyé en WHISPER aux clients connectés à chaque changement et à chaque
-- HELLO/HI reçu. Format : ACCT:token:version:nom-royaume:nomDuCompte (nom en dernier, vide =
-- aucun compte).
function P.SyncAccountLabel(key, target)
	local token = P.GetTeamToken()
	local entry = P.db.accountLabels[key]
	if not token or not entry or not entry.updated then
		return
	end
	local message = string.format("ACCT:%s:%d:%s:%s", token, entry.updated, key, entry.label or "")
	for to in pairs(ResolveTargets(target)) do
		P.Broadcast(message, "WHISPER", to)
	end
end

function P.SyncAllAccountLabels(target)
	for key in pairs(P.db.accountLabels) do
		P.SyncAccountLabel(key, target)
	end
end

local function OnAccountLabelMessage(rest)
	local version, key, label = strsplit(":", rest or "", 3)
	local updated = tonumber(version)
	if updated and key and key ~= "" and P.ApplyAccountLabelSync(key, updated, label or "") and P.RefreshUI then
		P.RefreshUI()
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
--   flag "N" = premier fragment, "S" = premier fragment + sélection, "+" = suite,
--   "D" = équipe supprimée (pierre tombale, un seul message sans membres ; le champ leader
--   porte le nouveau nom si elle a été renommée) ;
--   version = heure serveur de la dernière modification (la plus récente l'emporte) ;
--   le nom d'équipe est en dernier pour pouvoir contenir ":".
-- Les membres sont découpés en fragments pour respecter MAX_MESSAGE_LENGTH.
function P.SyncTeam(teamName, target, select)
	local token = P.GetTeamToken()
	if token and P.IsTeamRemoved(teamName) then
		local message = string.format("TEAM:%s:D:%d:%s::%s", token, P.GetTeamUpdated(teamName),
			P.db.teams[teamName].renamedTo or "", teamName)
		for to in pairs(ResolveTargets(target)) do
			P.Broadcast(message, "WHISPER", to)
		end
		P.Debug("Suppression de l'équipe « " .. teamName .. " » envoyée")
		return
	end
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

	-- Date de création, dans un message à part (TEAMINFO:token:date:nomÉquipe) : un champ de plus
	-- dans TEAM serait mal lu par les versions précédentes. Envoyé après les fragments (file).
	local created = P.GetTeamCreated(teamName)
	if created then
		messages[#messages + 1] = string.format("TEAMINFO:%s:%d:%s", token, created, teamName)
	end

	for to in pairs(ResolveTargets(target, select and keys or nil)) do
		for _, message in ipairs(messages) do
			P.Broadcast(message, "WHISPER", to)
		end
		P.Debug("Équipe « " .. teamName .. " » envoyée à " .. to)
	end
end

-- Envoie toutes les équipes, supprimées comprises, à un destinataire (ex. client qui vient
-- de se connecter) : une suppression l'emporte ainsi sur sa copie plus ancienne.
function P.SyncAllTeams(target)
	for teamName in pairs(P.db.teams) do
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
		or (flag ~= "N" and flag ~= "S" and flag ~= "+" and flag ~= "D") then
		return
	end

	local memberKeys = {}
	for key in (memberList or ""):gmatch("[^,]+") do
		memberKeys[#memberKeys + 1] = key
	end
	local applied = P.ApplyTeamSync(teamName, updated, flag ~= "+", leader ~= "" and leader or nil, memberKeys,
		flag == "D")
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
P.IsSender = IsSender -- pour les addons compagnons (expéditeur d'un message = personnage annoncé)

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

	-- Type propre à un addon compagnon (P.RegisterMessageHandler).
	if messageHandlers[kind] then
		messageHandlers[kind](rest, sender)
		return
	end

	if kind == "TEAM" then
		OnTeamMessage(rest, sender)
		return
	elseif kind == "CHAR" then
		OnCharMessage(rest, sender)
		return
	elseif kind == "STATUS" then
		OnStatusMessage(rest)
		return
	elseif kind == "BARPOS" then
		OnTeamBarLayoutMessage(rest)
		return
	elseif kind == "QLOG" then
		-- QLOG:token:flag:envoi:nom-royaume:ids — journal de quêtes ; le personnage annoncé doit
		-- être l'expéditeur.
		local _, _, key = strsplit(":", rest or "", 4)
		if key and IsSender(sender, key) then
			OnQuestLogMessage(rest)
		end
		return
	elseif kind == "TEAMINFO" then
		-- TEAMINFO:token:date:nomÉquipe — date de création d'une équipe (nom en dernier).
		local created, teamName = strsplit(":", rest or "", 2)
		created = tonumber(created)
		if created and teamName and P.ApplyTeamCreated(teamName, created) and P.RefreshUI then
			P.RefreshUI()
		end
		return
	elseif kind == "ACCT" then
		-- ACCT:token:version:nom-royaume:nomDuCompte — compte WoW nommé d'un personnage.
		OnAccountLabelMessage(rest)
		return
	elseif kind == "FOLLOWEND" then
		-- FOLLOWEND:token:nom-royaume — un membre ne suit plus le leader (Follow.lua) ; le
		-- personnage annoncé doit être l'expéditeur.
		if rest and IsSender(sender, rest) then
			P.OnFollowEndMessage(rest)
		end
		return
	elseif kind == "FOLLOWING" then
		-- FOLLOWING:token:nom-royaume:nom-royaumeSuivi — joueur suivi par un client du groupe
		-- (vide = plus aucun, Follow.lua) ; le suiveur annoncé doit être l'expéditeur.
		local follower, followed = strsplit(":", rest or "", 2)
		if follower and IsSender(sender, follower) then
			P.OnFollowingMessage(follower, followed)
		end
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
	elseif kind == "QSTATE" then
		-- QSTATE:token:questID:état:nom-royaume — un membre dit au leader s'il a la quête
		-- (HAVE, NEED, OK), pour le partage automatique (Quests.lua). Pas réservé au leader.
		local questID, state, key = strsplit(":", rest or "", 3)
		P.OnQuestStateMessage(tonumber(questID), state, key)
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
	local name, realm, class, level, surname = strsplit(":", rest or "")
	if not name or not realm then
		return
	end

	-- Nos propres messages nous reviennent : rien à faire.
	if P.GetCharKey(name, realm) == P.GetCharKey() then
		return
	end

	P.AddCharacter(name, realm, class, tonumber(level), token, surname)
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
	P.SyncAllAccountLabels(sender)
	P.SendStatus(sender)
	P.SendQuestLog(sender)
	for _, callback in ipairs(peerCallbacks) do
		callback(sender)
	end

	-- Leader : invite automatiquement ce personnage s'il est membre de l'équipe (AutoGroup.lua).
	P.OnTeamCharacterOnline(P.GetCharKey(name, realm))
end
