-- Polypode: Sync — broadcast et réception des messages addon (annonce du roster)

local P = Polypode

function P.RegisterComm()
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		C_ChatInfo.RegisterAddonMessagePrefix(P.SYNC_PREFIX)
	end
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

-- Annonce le personnage courant aux autres clients Polypode (groupe/guilde).
function P.SayHello()
	local _, class = UnitClass("player")
	local level = UnitLevel("player")
	P.Broadcast(string.format("HELLO:%s:%s:%s:%d", UnitName("player"), GetRealmName(), class, level))
end

function P.OnSyncMessage(message, channel, sender)
	local kind, name, realm, class, level = strsplit(":", message)
	if kind == "HELLO" and name and realm then
		P.AddCharacter(name, realm, class, tonumber(level))
		if P.RefreshUI then
			P.RefreshUI()
		end
		P.Debug("Roster mis à jour via sync : " .. name .. "-" .. realm .. " (de " .. sender .. ")")
	end
end
