-- Polypode: Quests — acceptation automatique des quêtes acceptées par le leader

local P = Polypode

-- Fonctionnement (repris de TeamManager) :
-- 1. Leader de l'équipe sélectionnée : quand il accepte une quête, il envoie QACCEPT au
--    groupe/raid (QUEST_ACCEPTED, plus un filet de sécurité sur AcceptQuest() et le bouton
--    « Accepter » pour les addons de dialogue qui détournent l'événement).
-- 2. Membre : le message peut arriver avant ou après que la quête lui soit proposée
--    (QUEST_DETAIL). Déjà proposée : il charge ses données (RequestLoadQuestByID) puis
--    l'accepte à QUEST_DATA_LOAD_RESULT. Pas encore : l'acceptation attend jusqu'à 30 s
--    qu'il ouvre la quête chez le PNJ.
-- L'option est propre à chaque personnage (P.charDb.autoAcceptQuest), des deux côtés.

local PENDING_TIMEOUT = 30 -- secondes d'attente de la quête côté membre
local BROADCAST_DEDUP = 2 -- secondes : une même quête n'est annoncée qu'une fois

local detailQuestID -- membre : quête actuellement proposée (QUEST_DETAIL)
local pendingAcceptID -- membre : quête à accepter dès que possible (0 = la prochaine proposée)
local lastBroadcast = {} -- leader : [questID] = GetTime() de la dernière annonce

local function IsEnabled()
	return P.charDb and P.charDb.autoAcceptQuest
end

local function IsTeamLeader()
	local team = P.GetSelectedTeam()
	return team and P.GetTeamLeader(team) == P.GetCharKey()
end

-- Leader : annonce la quête acceptée au groupe (une fois, quel que soit le déclencheur).
local function BroadcastAccept(questID, reason)
	if not IsEnabled() or not IsTeamLeader() or not IsInGroup() then
		return
	end
	if not questID or questID == 0 then
		return
	end
	local now = GetTime()
	if lastBroadcast[questID] and now - lastBroadcast[questID] < BROADCAST_DEDUP then
		return
	end
	local token = P.GetTeamToken()
	if not token then
		return
	end
	lastBroadcast[questID] = now
	P.Broadcast("QACCEPT:" .. token .. ":" .. questID, IsInRaid() and "RAID" or "PARTY")
	P.Debug("Quête " .. questID .. " acceptée, annoncée au groupe (" .. reason .. ")")
end

-- Membre : accepte la quête une fois ses données chargées (fiable même si le panneau de
-- détail a été fermé ou remplacé par un addon de dialogue).
local function StartAccept(questID)
	pendingAcceptID = questID
	if C_QuestLog and C_QuestLog.RequestLoadQuestByID then
		C_QuestLog.RequestLoadQuestByID(questID)
		P.Debug("Acceptation auto : chargement de la quête " .. questID)
	else
		pendingAcceptID = nil
		C_Timer.After(0, AcceptQuest)
	end
end

-- Membre : oublie une attente restée sans suite.
local function ExpirePending(questID)
	C_Timer.After(PENDING_TIMEOUT, function()
		if pendingAcceptID == questID then
			pendingAcceptID = nil
			P.Debug("Acceptation auto : délai dépassé pour la quête " .. questID)
		end
	end)
end

-- Réception de QACCEPT (Sync.lua) : questID accepté par le leader.
function P.OnQuestAcceptMessage(questID, sender)
	if not IsEnabled() then
		return
	end
	questID = questID or 0
	P.Debug("Quête " .. questID .. " acceptée par " .. tostring(sender))
	if detailQuestID and (questID == 0 or detailQuestID == questID) then
		StartAccept(detailQuestID)
	else
		pendingAcceptID = questID
		P.Debug("Acceptation auto : en attente de la quête " .. questID)
	end
	if pendingAcceptID then
		ExpirePending(pendingAcceptID)
	end
end

-- Événements de quête (Events.lua).
function P.OnQuestEvent(event, arg1)
	if event == "QUEST_ACCEPTED" then
		BroadcastAccept(arg1, "QUEST_ACCEPTED")
	elseif event == "QUEST_DETAIL" then
		local questID = GetQuestID and GetQuestID() or 0
		if questID == 0 then
			return
		end
		detailQuestID = questID
		if pendingAcceptID and (pendingAcceptID == 0 or pendingAcceptID == questID) then
			if IsEnabled() then
				StartAccept(questID)
				if pendingAcceptID then
					ExpirePending(pendingAcceptID)
				end
			else
				pendingAcceptID = nil
			end
		end
	elseif event == "QUEST_DATA_LOAD_RESULT" then
		if arg1 and arg1 == pendingAcceptID then
			pendingAcceptID = nil
			if IsEnabled() then
				AcceptQuest()
				if QuestFrame and QuestFrame:IsShown() then
					QuestFrame:Hide()
				end
				P.Debug("Quête " .. arg1 .. " acceptée automatiquement")
			end
		end
	elseif event == "QUEST_FINISHED" then
		detailQuestID = nil
	end
end

-- Filets de sécurité côté leader (addons de dialogue qui détournent QUEST_ACCEPTED).
if AcceptQuest then
	hooksecurefunc("AcceptQuest", function()
		BroadcastAccept(GetQuestID and GetQuestID() or 0, "AcceptQuest")
	end)
end
if QuestFrameAcceptButton then
	QuestFrameAcceptButton:HookScript("OnClick", function()
		BroadcastAccept(GetQuestID and GetQuestID() or 0, "bouton Accepter")
	end)
end
