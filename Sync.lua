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

-- Envoie un message addon. Sans canal : groupe/raid/guilde selon la situation.
-- channel = "WHISPER" : target est le nom du destinataire (cf. P.GetTargetName).
function P.Broadcast(message, channel, target)
	channel = channel or GetBroadcastChannel()
	if not channel then
		return
	end
	if C_ChatInfo and C_ChatInfo.SendAddonMessage then
		C_ChatInfo.SendAddonMessage(P.SYNC_PREFIX, message, channel, target)
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

-- Envoie la définition d'une équipe (nom, leader, membres) à chacun de ses membres, par
-- chuchotement addon : fiable même avant que les invités aient rejoint le groupe.
-- Format : TEAM:token:flag:leader:membre1,membre2,...:nomÉquipe
--   flag "N" = premier fragment (le destinataire remplace les membres), "+" = suite ;
--   le nom d'équipe est en dernier pour pouvoir contenir ":".
-- Les membres sont découpés en fragments pour respecter MAX_MESSAGE_LENGTH.
function P.SyncTeam(teamName)
	local token = P.GetTeamToken()
	local members = P.GetTeamMembers(teamName)
	if not token or not members then
		P.Debug("Synchro d'équipe impossible (BattleTag ou équipe indisponible).")
		return
	end

	local leader = P.GetTeamLeader(teamName) or ""
	local keys = {}
	for key in pairs(members) do
		keys[#keys + 1] = key
	end
	table.sort(keys)

	-- Découpe la liste en fragments tenant dans un message.
	local chunks, current = {}, {}
	local function Budget(flag)
		return MAX_MESSAGE_LENGTH - #("TEAM:" .. token .. ":" .. flag .. ":" .. leader .. "::" .. teamName)
	end
	local used = 0
	for _, key in ipairs(keys) do
		local cost = #key + (#current > 0 and 1 or 0)
		if #current > 0 and used + cost > Budget(#chunks == 0 and "N" or "+") then
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
		messages[i] = string.format("TEAM:%s:%s:%s:%s:%s", token, i == 1 and "N" or "+", leader,
			table.concat(chunk, ","), teamName)
	end

	-- Destinataires : tous les membres sauf soi. Un nom de personnage ne contient pas de
	-- "-", d'où le découpage de la clé Nom-Royaume.
	for _, key in ipairs(keys) do
		if key ~= P.GetCharKey() then
			local name, realm = strsplit("-", key, 2)
			local target = P.GetTargetName({ name = name, realm = realm })
			for _, message in ipairs(messages) do
				P.Broadcast(message, "WHISPER", target)
			end
			P.Debug("Équipe « " .. teamName .. " » envoyée à " .. target)
		end
	end
end

-- Réception d'un fragment TEAM (cf. P.SyncTeam) : met à jour l'équipe locale et l'affiche.
local function OnTeamMessage(rest, sender)
	local flag, leader, memberList, teamName = strsplit(":", rest, 4)
	teamName = teamName and strtrim(teamName)
	-- 32 caractères au plus à la saisie, soit au plus 128 octets en UTF-8.
	if not teamName or teamName == "" or #teamName > 128 or (flag ~= "N" and flag ~= "+") then
		return
	end

	local memberKeys = {}
	for key in (memberList or ""):gmatch("[^,]+") do
		memberKeys[#memberKeys + 1] = key
	end
	P.ApplyTeamSync(teamName, flag == "N", leader ~= "" and leader or nil, memberKeys)

	if P.SelectTeam then
		P.SelectTeam(teamName)
	end
	P.Debug("Équipe « " .. teamName .. " » reçue de " .. tostring(sender))
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
end
