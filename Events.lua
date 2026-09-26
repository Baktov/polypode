-- Polypode: Events — handlers ADDON_LOADED, PLAYER_LOGIN, CHAT_MSG_ADDON, raccourcis

local P = Polypode
local frame = CreateFrame("Frame")
P.eventFrame = frame

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UPDATE_BINDINGS") -- touches modifiées dans le panneau Raccourcis
frame:RegisterEvent("PLAYER_REGEN_ENABLED") -- sortie de combat : mises à jour différées
-- Acceptation automatique des quêtes (Quests.lua)
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
frame:RegisterEvent("QUEST_FINISHED")

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
		P.BuildOptions()
		P.UpdateLeaderMacros()
		P.Debug("Personnage enregistré : " .. key)
	elseif event == "UPDATE_BINDINGS" then
		-- Reçu aussi avant PLAYER_LOGIN : la base doit être prête.
		if P.db then
			P.UpdateLeaderMacros()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		P.ApplyPendingKeybinds()
	elseif event == "QUEST_ACCEPTED" or event == "QUEST_DETAIL"
		or event == "QUEST_DATA_LOAD_RESULT" or event == "QUEST_FINISHED" then
		P.OnQuestEvent(event, ...)
	elseif event == "CHAT_MSG_ADDON" then
		local prefix, message, channel, sender = ...
		if prefix == P.SYNC_PREFIX then
			P.OnSyncMessage(message, channel, sender)
		end
	end
end)
