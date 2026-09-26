-- Polypode: Events — handlers ADDON_LOADED, PLAYER_LOGIN, CHAT_MSG_ADDON

local P = Polypode
local frame = CreateFrame("Frame")
P.eventFrame = frame

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local addonName = ...
		if addonName == "Polypode" then
			P.InitDB()
		end
	elseif event == "PLAYER_LOGIN" then
		local key = P.AddCharacter()
		P.RegisterComm()
		self:RegisterEvent("CHAT_MSG_ADDON")
		P.SayHello()
		P.BuildMinimapButton()
		P.Debug("Personnage enregistré : " .. key)
	elseif event == "CHAT_MSG_ADDON" then
		local prefix, message, channel, sender = ...
		if prefix == P.SYNC_PREFIX then
			P.OnSyncMessage(message, channel, sender)
		end
	end
end)
