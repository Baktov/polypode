-- Polypode: Quests — acceptation et validation automatiques des quêtes du leader

local P = Polypode

-- Fonctionnement (repris de TeamManager). Le leader de l'équipe sélectionnée annonce ses
-- actions de quête au groupe/raid ; les membres les rejouent. Chaque message peut arriver
-- avant ou après que le panneau correspondant s'ouvre chez le membre : les deux ordres
-- sont couverts (attente limitée dans le temps).
--
-- ACCEPTATION (option P.charDb.autoAcceptQuest) — message QACCEPT:token:questID
--   Leader : QUEST_ACCEPTED, plus hooks AcceptQuest() et bouton « Accepter ».
--   Membre : quête proposée (QUEST_DETAIL) → RequestLoadQuestByID → QUEST_DATA_LOAD_RESULT
--   → AcceptQuest() ; sinon attente 30 s.
--
-- VALIDATION (option P.charDb.autoValidateQuest), en deux étapes :
--   1. QVALIDATE:token:questID — le leader clique « Continuer » (panneau de progression).
--      Leader : bouton « Continuer », hook CompleteQuest(), QUEST_COMPLETE, QUEST_TURNED_IN.
--      Membre : CompleteQuest() si la quête est complétable (panneau de progression ouvert,
--      vu il y a moins de 10 s, ou quête complétable côté serveur) ; sinon attente 60 s.
--   2. QREWARD:token:questID:choix — le leader termine la quête (récompense choisie).
--      Leader : bouton « Terminer la quête », hook GetQuestReward(), QUEST_TURNED_IN (choix 0).
--      Membre : GetQuestReward(choix) si les récompenses sont affichées ou l'ont été il y a
--      moins de 10 s ; sinon attente 60 s. Le choix est l'index de la récompense du leader
--      (0 = pas de choix) : une quête à récompense au choix obligatoire reste à terminer
--      à la main si l'index ne convient pas.
-- SÉLECTION DANS LES DIALOGUES DE PNJ (option P.charDb.autoSelectGossipQuest) :
--   GQAVAIL:token:questID — le leader choisit une quête disponible dans un dialogue de PNJ ;
--   GQACTIVE:token:questID — il choisit une quête active (à rendre).
--   Leader : hooks C_GossipInfo.SelectAvailableQuest / SelectActiveQuest (et équivalents
--   anciens par index). Membre : si un dialogue est ouvert (quête présente dans la liste) ou
--   l'a été il y a moins de 10 s, il choisit la même quête ; l'acceptation ou la validation
--   automatique prend ensuite le relais. Pas d'attente si aucun dialogue n'est ouvert.
-- Les délais de 10 s couvrent les addons de dialogue (DialogueUI, Immersion) qui ferment le
-- panneau Blizzard alors que le serveur accepte encore la validation.
-- Les trois options sont propres à chaque personnage, des deux côtés (leader et membres).

local ACCEPT_TIMEOUT = 30 -- secondes d'attente d'une quête à accepter (membre)
local VALIDATE_TIMEOUT = 60 -- secondes d'attente d'une quête à valider (membre)
local READY_WINDOW = 10 -- secondes pendant lesquelles un panneau vu reste utilisable
local BROADCAST_DEDUP = 5 -- secondes : une même annonce (type + quête) n'est envoyée qu'une fois

-- Membre : état des panneaux et actions en attente.
local detailQuestID -- quête proposée (QUEST_DETAIL), jusqu'à QUEST_FINISHED
local pendingAcceptID -- quête à accepter dès que possible (0 = la prochaine proposée)
local progressQuestID -- panneau de progression ouvert (QUEST_PROGRESS), jusqu'à QUEST_FINISHED
local progressReadyID, progressReadyAt -- dernier panneau de progression vu, et quand
local completeReadyID, completeReadyAt -- dernier panneau de récompenses vu, et quand
local pendingValidateID -- quête à « continuer » dès que possible
local pendingRewardID, pendingRewardChoice -- quête à terminer dès que possible, et choix
local gossipReadyAt -- dernier dialogue de PNJ ouvert (GOSSIP_SHOW)

-- Leader : [type .. questID] = GetTime() de la dernière annonce.
local lastBroadcast = {}

local function AcceptEnabled()
	return P.charDb and P.charDb.autoAcceptQuest
end

local function ValidateEnabled()
	return P.charDb and P.charDb.autoValidateQuest
end

local function GossipEnabled()
	return P.charDb and P.charDb.autoSelectGossipQuest
end

local function IsTeamLeader()
	local team = P.GetSelectedTeam()
	return team and P.GetTeamLeader(team) == P.GetCharKey()
end

local function CurrentQuestID()
	return GetQuestID and GetQuestID() or 0
end

local function IsRecent(at)
	return at and GetTime() - at < READY_WINDOW
end

-- Leader : annonce une action de quête au groupe (kind = QACCEPT, QVALIDATE ou QREWARD),
-- une seule fois quel que soit le nombre de déclencheurs. extra : champ supplémentaire.
local function Announce(kind, questID, extra, reason)
	if not IsTeamLeader() or not IsInGroup() or not questID or questID == 0 then
		return
	end
	local id = kind .. questID
	local now = GetTime()
	if lastBroadcast[id] and now - lastBroadcast[id] < BROADCAST_DEDUP then
		return
	end
	local token = P.GetTeamToken()
	if not token then
		return
	end
	lastBroadcast[id] = now
	local message = kind .. ":" .. token .. ":" .. questID .. (extra and (":" .. extra) or "")
	P.Broadcast(message, IsInRaid() and "RAID" or "PARTY")
	P.Debug(kind .. " quête " .. questID .. " annoncé au groupe (" .. reason .. ")")
end

local function AnnounceAccept(questID, reason)
	if AcceptEnabled() then
		Announce("QACCEPT", questID, nil, reason)
	end
end

local function AnnounceValidate(questID, reason)
	if ValidateEnabled() then
		Announce("QVALIDATE", questID, nil, reason)
	end
end

local function AnnounceReward(questID, choice, reason)
	if ValidateEnabled() then
		Announce("QREWARD", questID, choice or 0, reason)
	end
end

-- kind : "GQAVAIL" (quête disponible) ou "GQACTIVE" (quête active, à rendre).
local function AnnounceGossipQuest(kind, questID, reason)
	if GossipEnabled() then
		Announce(kind, questID, nil, reason)
	end
end

-- ACCEPTATION (membre) ---------------------------------------------------------------

-- Accepte la quête une fois ses données chargées (fiable même si le panneau de détail a
-- été fermé ou remplacé par un addon de dialogue).
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

local function ExpireAccept(questID)
	C_Timer.After(ACCEPT_TIMEOUT, function()
		if pendingAcceptID == questID then
			pendingAcceptID = nil
			P.Debug("Acceptation auto : délai dépassé pour la quête " .. questID)
		end
	end)
end

-- Réception de QACCEPT (Sync.lua).
function P.OnQuestAcceptMessage(questID, sender)
	if not AcceptEnabled() then
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
		ExpireAccept(pendingAcceptID)
	end
end

-- VALIDATION (membre) ----------------------------------------------------------------

-- « Continuer » : remet la quête si elle est complétable.
local function TryComplete(questID, reason)
	C_Timer.After(0, function()
		if IsQuestCompletable and IsQuestCompletable() then
			CompleteQuest()
			P.Debug("Quête " .. questID .. " continuée automatiquement (" .. reason .. ")")
		else
			P.Debug("Validation auto : quête " .. questID .. " non complétable")
		end
	end)
end

-- « Terminer la quête » avec le choix de récompense du leader.
local function TakeReward(questID, choice, reason)
	C_Timer.After(0, function()
		GetQuestReward(choice)
		P.Debug("Quête " .. questID .. " terminée automatiquement, récompense " .. choice
			.. " (" .. reason .. ")")
	end)
end

-- Réception de QVALIDATE (Sync.lua).
function P.OnQuestValidateMessage(questID, sender)
	if not ValidateEnabled() then
		return
	end
	questID = questID or 0
	P.Debug("Quête " .. questID .. " continuée par " .. tostring(sender))
	local localID = CurrentQuestID()
	if progressQuestID and (questID == 0 or progressQuestID == questID) then
		pendingValidateID = nil
		TryComplete(progressQuestID, "panneau ouvert")
	elseif IsRecent(progressReadyAt) and (questID == 0 or progressReadyID == questID) then
		TryComplete(progressReadyID, "panneau vu récemment")
	elseif IsQuestCompletable and IsQuestCompletable()
		and (questID == 0 or localID == questID or localID == 0) then
		TryComplete(questID, "complétable côté serveur")
	else
		pendingValidateID = questID
		P.Debug("Validation auto : en attente de la quête " .. questID)
		C_Timer.After(VALIDATE_TIMEOUT, function()
			if pendingValidateID == questID then
				pendingValidateID = nil
			end
		end)
	end
end

-- Réception de QREWARD (Sync.lua).
function P.OnQuestRewardMessage(questID, choice, sender)
	if not ValidateEnabled() then
		return
	end
	questID = questID or 0
	choice = choice or 0
	P.Debug("Quête " .. questID .. " terminée par " .. tostring(sender) .. ", récompense " .. choice)
	local localID = CurrentQuestID()
	local rewardsReady = (GetNumQuestChoices and GetNumQuestChoices() or 0) > 0
		or (GetNumQuestRewards and GetNumQuestRewards() or 0) > 0
		or (QuestFrameRewardPanel and QuestFrameRewardPanel:IsShown())
	if rewardsReady and (questID == 0 or localID == questID or localID == 0) then
		TakeReward(questID, choice, "récompenses affichées")
	elseif IsRecent(completeReadyAt) and (questID == 0 or completeReadyID == questID) then
		TakeReward(completeReadyID, choice, "récompenses vues récemment")
	else
		pendingRewardID, pendingRewardChoice = questID, choice
		P.Debug("Validation auto : récompense en attente pour la quête " .. questID)
		C_Timer.After(VALIDATE_TIMEOUT, function()
			if pendingRewardID == questID then
				pendingRewardID, pendingRewardChoice = nil, nil
			end
		end)
	end
end

-- SÉLECTION DANS LES DIALOGUES (membre) ----------------------------------------------

-- Par type d'annonce : liste des quêtes du dialogue, sélection par questID, et sélection
-- ancienne par index (si l'API existe).
local GOSSIP_QUEST_API = {
	GQAVAIL = {
		list = C_GossipInfo and C_GossipInfo.GetAvailableQuests,
		select = C_GossipInfo and C_GossipInfo.SelectAvailableQuest,
		legacy = SelectGossipAvailableQuest,
	},
	GQACTIVE = {
		list = C_GossipInfo and C_GossipInfo.GetActiveQuests,
		select = C_GossipInfo and C_GossipInfo.SelectActiveQuest,
		legacy = SelectGossipActiveQuest,
	},
}

-- Réception de GQAVAIL / GQACTIVE (Sync.lua) : choisit la même quête dans le dialogue ouvert.
function P.OnGossipQuestMessage(kind, questID, sender)
	local api = GOSSIP_QUEST_API[kind]
	if not GossipEnabled() or not api or not questID then
		return
	end
	local quests = api.list and api.list() or nil
	local hasQuests = quests and #quests > 0
	if not hasQuests and not IsRecent(gossipReadyAt) then
		P.Debug(kind .. " quête " .. questID .. " ignoré : aucun dialogue ouvert")
		return
	end
	local index
	for i, info in ipairs(quests or {}) do
		if info.questID == questID then
			index = i
			break
		end
	end
	-- Quête absente de la liste mais dialogue vu récemment (addon de dialogue) : on tente.
	if (index or not hasQuests) and api.select then
		api.select(questID)
		P.Debug("Quête " .. questID .. " choisie dans le dialogue (" .. kind .. ", de "
			.. tostring(sender) .. ")")
	elseif index and api.legacy then
		api.legacy(index)
		P.Debug("Quête " .. questID .. " choisie dans le dialogue (index " .. index .. ")")
	end
end

-- ÉVÉNEMENTS (Events.lua) ------------------------------------------------------------

function P.OnQuestEvent(event, arg1)
	if event == "QUEST_ACCEPTED" then
		AnnounceAccept(arg1, "QUEST_ACCEPTED")

	elseif event == "QUEST_DETAIL" then
		local questID = CurrentQuestID()
		if questID == 0 then
			return
		end
		detailQuestID = questID
		if pendingAcceptID and (pendingAcceptID == 0 or pendingAcceptID == questID) then
			if AcceptEnabled() then
				StartAccept(questID)
				if pendingAcceptID then
					ExpireAccept(pendingAcceptID)
				end
			else
				pendingAcceptID = nil
			end
		end

	elseif event == "QUEST_DATA_LOAD_RESULT" then
		if arg1 and arg1 == pendingAcceptID then
			pendingAcceptID = nil
			if AcceptEnabled() then
				AcceptQuest()
				if QuestFrame and QuestFrame:IsShown() then
					QuestFrame:Hide()
				end
				P.Debug("Quête " .. arg1 .. " acceptée automatiquement")
			end
		end

	elseif event == "QUEST_PROGRESS" then
		local questID = CurrentQuestID()
		if questID == 0 then
			return
		end
		progressQuestID = questID
		progressReadyID, progressReadyAt = questID, GetTime()
		if pendingValidateID and (pendingValidateID == 0 or pendingValidateID == questID) then
			pendingValidateID = nil
			if ValidateEnabled() then
				TryComplete(questID, "attente")
			end
		end

	elseif event == "QUEST_COMPLETE" then
		local questID = CurrentQuestID()
		if questID == 0 then
			return
		end
		completeReadyID, completeReadyAt = questID, GetTime()
		-- Leader : déclencheur fiable même quand un addon de dialogue contourne les hooks.
		AnnounceValidate(questID, "QUEST_COMPLETE")
		if pendingRewardID and (pendingRewardID == 0 or pendingRewardID == questID) then
			local choice = pendingRewardChoice or 0
			pendingRewardID, pendingRewardChoice = nil, nil
			if ValidateEnabled() then
				TakeReward(questID, choice, "attente")
			end
		end

	elseif event == "QUEST_TURNED_IN" then
		-- Leader : filet ultime, la quête est déjà remise (choix inconnu : 0).
		AnnounceValidate(arg1, "QUEST_TURNED_IN")
		AnnounceReward(arg1, 0, "QUEST_TURNED_IN")

	elseif event == "QUEST_FINISHED" then
		detailQuestID = nil
		progressQuestID = nil

	elseif event == "GOSSIP_SHOW" then
		-- Le serveur accepte une sélection pendant quelques secondes, même si un addon de
		-- dialogue a masqué la fenêtre Blizzard.
		gossipReadyAt = GetTime()
	end
end

-- Filets de sécurité côté leader (addons de dialogue qui détournent les événements).
if AcceptQuest then
	hooksecurefunc("AcceptQuest", function()
		AnnounceAccept(CurrentQuestID(), "AcceptQuest")
	end)
end
if QuestFrameAcceptButton then
	QuestFrameAcceptButton:HookScript("OnClick", function()
		AnnounceAccept(CurrentQuestID(), "bouton Accepter")
	end)
end
if CompleteQuest then
	hooksecurefunc("CompleteQuest", function()
		AnnounceValidate(CurrentQuestID(), "CompleteQuest")
	end)
end
if QuestFrameCompleteButton then
	QuestFrameCompleteButton:HookScript("OnClick", function()
		AnnounceValidate(CurrentQuestID(), "bouton Continuer")
	end)
end
if GetQuestReward then
	hooksecurefunc("GetQuestReward", function(choice)
		AnnounceReward(CurrentQuestID(), choice, "GetQuestReward")
	end)
end
if QuestFrameCompleteQuestButton then
	QuestFrameCompleteQuestButton:HookScript("OnClick", function()
		local choice = QuestInfoFrame and QuestInfoFrame.itemChoice or 0
		AnnounceReward(CurrentQuestID(), choice, "bouton Terminer")
	end)
end

-- Leader : choix d'une quête dans un dialogue de PNJ (clic sur l'icône de quête).
if C_GossipInfo and C_GossipInfo.SelectAvailableQuest then
	hooksecurefunc(C_GossipInfo, "SelectAvailableQuest", function(questID)
		AnnounceGossipQuest("GQAVAIL", questID, "SelectAvailableQuest")
	end)
end
if C_GossipInfo and C_GossipInfo.SelectActiveQuest then
	hooksecurefunc(C_GossipInfo, "SelectActiveQuest", function(questID)
		AnnounceGossipQuest("GQACTIVE", questID, "SelectActiveQuest")
	end)
end
-- Équivalents anciens (par index), s'ils existent : questID retrouvé dans la liste.
for kind, api in pairs(GOSSIP_QUEST_API) do
	local legacyName = kind == "GQAVAIL" and "SelectGossipAvailableQuest" or "SelectGossipActiveQuest"
	if api.legacy and api.list then
		hooksecurefunc(legacyName, function(index)
			local info = (api.list() or {})[index]
			if info and info.questID then
				AnnounceGossipQuest(kind, info.questID, legacyName)
			end
		end)
	end
end
