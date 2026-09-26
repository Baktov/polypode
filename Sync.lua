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
-- WoW d'un Battle.net ont le même BattleTag). Point d'extension prévu pour /poly team.
function P.GetTeamToken()
	if not teamToken and BNGetInfo then
		local _, battleTag = BNGetInfo()
		if battleTag and battleTag ~= "" then
			teamToken = Hash(battleTag)
		end
	end
	return teamToken
end

local function GetBroadcastChannel()
	if IsInRaid() then
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

-- Taille maximale d'un message addon (octets), imposée par le client WoW.
local MAX_MESSAGE_LENGTH = 255

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

	-- Destinataires (ensemble de noms complets, soi exclu).
	local targets = {}
	if target then
		targets[FullName(target)] = true
	else
		for name in pairs(onlineChars) do
			targets[name] = true
		end
		if select then
			for _, key in ipairs(keys) do
				local name, realm = strsplit("-", key, 2)
				targets[FullName(P.GetTargetName({ name = name, realm = realm or "" }))] = true
			end
		end
	end
	targets[FullName(P.GetTargetName({ name = UnitName("player"), realm = GetRealmName() }))] = nil

	for to in pairs(targets) do
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

function P.OnSyncMessage(message, channel, sender)
	local kind, token, rest = strsplit(":", message, 3)

	-- Ignore les messages hors équipe (ex. autres joueurs Polypode de la guilde).
	if not token or token ~= P.GetTeamToken() then
		P.Debug("Message ignoré (autre équipe) : " .. tostring(sender))
		return
	end

	if kind == "TEAM" then
		OnTeamMessage(rest, sender)
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

	P.AddCharacter(name, realm, class, tonumber(level))
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

	-- Échange des équipes dans les deux sens (HELLO puis HI) : chaque client récupère les
	-- versions plus récentes de l'autre, même s'il a démarré sur une sauvegarde ancienne.
	P.SyncAllTeams(sender)
end
