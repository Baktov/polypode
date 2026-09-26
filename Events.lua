-- Polypode: Events — handlers ADDON_LOADED, PLAYER_LOGIN, CHAT_MSG_ADDON, raccourcis

local P = Polypode
local frame = CreateFrame("Frame")
P.eventFrame = frame

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UPDATE_BINDINGS") -- touches modifiées dans le panneau Raccourcis
frame:RegisterEvent("PLAYER_REGEN_ENABLED") -- sortie de combat : mises à jour différées
-- Acceptation, validation et sélection (dialogues de PNJ) automatiques des quêtes (Quests.lua)
local QUEST_EVENTS = {
	GOSSIP_SHOW = true,
	QUEST_ACCEPTED = true,
	QUEST_DETAIL = true,
	QUEST_DATA_LOAD_RESULT = true,
	QUEST_PROGRESS = true,
	QUEST_COMPLETE = true,
	QUEST_TURNED_IN = true,
	QUEST_FINISHED = true,
}
for questEvent in pairs(QUEST_EVENTS) do
	frame:RegisterEvent(questEvent)
end

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
	elseif QUEST_EVENTS[event] then
		P.OnQuestEvent(event, ...)
	elseif event == "CHAT_MSG_ADDON" then
		local prefix, message, channel, sender = ...
		if prefix == P.SYNC_PREFIX then
			P.OnSyncMessage(message, channel, sender)
		end
	end
end)
