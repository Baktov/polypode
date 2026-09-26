-- Polypode: Sync — broadcast et réception des messages addon (annonce du roster)

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

function P.Broadcast(message, channel)
	channel = channel or GetBroadcastChannel()
	if not channel then
		return
	end
	if C_ChatInfo and C_ChatInfo.SendAddonMessage then
		C_ChatInfo.SendAddonMessage(P.SYNC_PREFIX, message, channel)
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

function P.OnSyncMessage(message, channel, sender)
	local kind, token, name, realm, class, level = strsplit(":", message)
	if (kind ~= "HELLO" and kind ~= "HI") or not name or not realm then
		return
	end

	-- Ignore les personnages hors équipe (ex. autres joueurs Polypode de la guilde).
	if not token or token ~= P.GetTeamToken() then
		P.Debug("Annonce ignorée (autre équipe) : " .. tostring(sender))
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
