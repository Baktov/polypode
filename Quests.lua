-- Polypode: Quests — quêtes et dialogues de PNJ du leader rejoués par les membres

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
-- DIALOGUES DE PNJ (option P.charDb.autoSelectGossip). Membre : n'agit que si un dialogue
-- est ouvert ou l'a été il y a moins de 10 s (GOSSIP_SHOW) ; pas d'attente sinon.
--   GQAVAIL:token:questID / GQACTIVE:token:questID — le leader choisit une quête disponible /
--   active (à rendre) dans le dialogue. Leader : hooks C_GossipInfo.SelectAvailableQuest /
--   SelectActiveQuest (et équivalents anciens par index). Membre : choisit la même quête ;
--   l'acceptation ou la validation automatique prend ensuite le relais.
--   GOSSIP:token:gossipOptionID:orderIndex — le leader choisit une option de dialogue.
--   Leader : hooks C_GossipInfo.SelectOptionByIndex (clic Blizzard et DialogueUI : l'argument
--   est l'orderIndex, résolu en gossipOptionID stable), SelectOption, SelectGossipOption.
--   Membre : SelectOption(gossipOptionID), sinon SelectOptionByIndex(orderIndex) (options
--   « indice » de DialogueUI sans gossipOptionID), sinon recherche par gossipOptionID, sinon
--   SelectGossipOption (ancienne API).
--   CLOSEUI:token — le leader ferme son DialogueUI (Échap, « Au revoir ») : aucun événement
--   serveur ne le signale et DialogueUI garde la dernière phrase affichée chez le membre.
--   Leader : OnHide du cadre DialogueUI (retrouvé par sa signature, cf. FindDialogueUIFrame).
--   Membre : ferme DialogueUI, le dialogue et la quête Blizzard.
-- Les délais de 10 s couvrent les addons de dialogue (DialogueUI, Immersion) qui ferment le
-- panneau Blizzard alors que le serveur accepte encore l'action.
-- Les options sont propres à chaque personnage, des deux côtés (leader et membres).
-- Sync.lua n'accepte ces messages que du leader de l'équipe sélectionnée, jamais de soi-même
-- (un message de groupe revient aussi à son expéditeur).

local ACCEPT_TIMEOUT = 30 -- secondes d'attente d'une quête à accepter (membre)
local VALIDATE_TIMEOUT = 60 -- secondes d'attente d'une quête à valider (membre)
local READY_WINDOW = 10 -- secondes pendant lesquelles un panneau vu reste utilisable
local BROADCAST_DEDUP = 5 -- secondes : une même annonce (type + quête) n'est envoyée qu'une fois
local GOSSIP_DEDUP = 0.5 -- secondes : une option de dialogue peut être rejouée rapidement
local CLOSE_DEDUP = 2 -- secondes entre deux annonces de fermeture

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
	return P.charDb and P.charDb.autoSelectGossip
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

-- Leader : envoie « kind:token:fields » au groupe/raid, une seule fois par fenêtre de
-- dédoublonnage (window secondes) pour une même clé, quel que soit le nombre de
-- déclencheurs. fields : champs après le token (peut être vide).
local function Send(kind, fields, dedupKey, window, reason)
	if not IsTeamLeader() or not IsInGroup() then
		return
	end
	local now = GetTime()
	if lastBroadcast[dedupKey] and now - lastBroadcast[dedupKey] < window then
		return
	end
	local token = P.GetTeamToken()
	if not token then
		return
	end
	lastBroadcast[dedupKey] = now
	local message = kind .. ":" .. token .. (fields ~= "" and (":" .. fields) or "")
	P.Broadcast(message, IsInRaid() and "RAID" or "PARTY")
	P.Debug(kind .. " " .. fields .. " annoncé au groupe (" .. reason .. ")")
end

-- Leader : annonce une action de quête (kind = QACCEPT, QVALIDATE, QREWARD, GQAVAIL,
-- GQACTIVE). extra : champ supplémentaire (choix de récompense).
local function Announce(kind, questID, extra, reason)
	if not questID or questID == 0 then
		return
	end
	Send(kind, questID .. (extra and (":" .. extra) or ""), kind .. questID, BROADCAST_DEDUP, reason)
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

-- OPTIONS DE DIALOGUE -----------------------------------------------------------------

-- Leader : résout l'argument de C_GossipInfo.SelectOptionByIndex en gossipOptionID stable.
-- Cet argument est l'orderIndex de l'option (clé de tri du serveur, pas une position) :
-- recherche par orderIndex, puis par position, puis par position après tri par orderIndex.
local function ResolveGossipOptionID(orderIndex)
	local options = orderIndex and C_GossipInfo and C_GossipInfo.GetOptions and C_GossipInfo.GetOptions()
	if not options then
		return nil
	end
	for _, info in ipairs(options) do
		if (info.orderIndex or -1) == orderIndex and info.gossipOptionID then
			return info.gossipOptionID
		end
	end
	if options[orderIndex] and options[orderIndex].gossipOptionID then
		return options[orderIndex].gossipOptionID
	end
	local sorted = {}
	for _, info in ipairs(options) do
		sorted[#sorted + 1] = info
	end
	table.sort(sorted, function(a, b)
		return (a.orderIndex or 0) < (b.orderIndex or 0)
	end)
	return sorted[orderIndex] and sorted[orderIndex].gossipOptionID
end

-- Leader : annonce l'option choisie (au moins l'un des deux identifiants).
local function AnnounceGossipOption(gossipOptionID, orderIndex, reason)
	if not GossipEnabled() then
		return
	end
	if (not gossipOptionID or gossipOptionID == 0) and not orderIndex then
		return
	end
	local fields = (gossipOptionID or 0) .. ":" .. (orderIndex or "")
	Send("GOSSIP", fields, "GOSSIP" .. fields, GOSSIP_DEDUP, reason)
end

-- Réception de GOSSIP (Sync.lua) : choisit la même option dans le dialogue ouvert.
function P.OnGossipOptionMessage(gossipOptionID, orderIndex, sender)
	if not GossipEnabled() or not C_GossipInfo then
		return
	end
	gossipOptionID = gossipOptionID or 0
	local options = C_GossipInfo.GetOptions and C_GossipInfo.GetOptions() or nil
	local hasOptions = options and #options > 0
	local frameShown = GossipFrame and GossipFrame:IsShown()
	if (gossipOptionID == 0 and not orderIndex)
		or not (hasOptions or IsRecent(gossipReadyAt) or frameShown) then
		P.Debug("Option de dialogue ignorée : aucun dialogue ouvert")
		return
	end

	-- 1. Chemin nominal : identifiant stable, si l'option est présente (ou liste inconnue).
	if gossipOptionID > 0 and C_GossipInfo.SelectOption then
		local exists = false
		for _, info in ipairs(options or {}) do
			if info.gossipOptionID == gossipOptionID then
				exists = true
				break
			end
		end
		if exists or not hasOptions then
			C_GossipInfo.SelectOption(gossipOptionID, "", false)
			P.Debug("Option de dialogue " .. gossipOptionID .. " choisie (de " .. tostring(sender) .. ")")
			return
		end
	end
	-- 2. Options « indice » de DialogueUI sans gossipOptionID : orderIndex, stable côté serveur.
	if orderIndex and C_GossipInfo.SelectOptionByIndex then
		C_GossipInfo.SelectOptionByIndex(orderIndex)
		P.Debug("Option de dialogue choisie par orderIndex " .. orderIndex)
		return
	end
	-- 3. Recherche de l'orderIndex local à partir du gossipOptionID.
	if gossipOptionID > 0 and hasOptions and C_GossipInfo.SelectOptionByIndex then
		for _, info in ipairs(options) do
			if info.gossipOptionID == gossipOptionID then
				C_GossipInfo.SelectOptionByIndex(info.orderIndex or 0)
				P.Debug("Option de dialogue choisie par orderIndex local " .. (info.orderIndex or 0))
				return
			end
		end
	end
	-- 4. Ancienne API par index.
	if SelectGossipOption then
		SelectGossipOption(orderIndex or gossipOptionID)
		P.Debug("Option de dialogue choisie (ancienne API)")
	end
end

-- FERMETURE DE DIALOGUEUI -------------------------------------------------------------

-- Cadre principal de DialogueUI (absent de _G) : reconnu par trois méthodes propres à son
-- mixin. Mis en cache, nil si DialogueUI n'est pas installé ou pas encore créé.
local dialogueUIFrame
local function FindDialogueUIFrame()
	if dialogueUIFrame then
		return dialogueUIFrame
	end
	if not EnumerateFrames then
		return nil
	end
	local frame = EnumerateFrames()
	while frame do
		if frame.HideUI and frame.AcquireAcceptButton and frame.SetSelectedGossipIndex then
			dialogueUIFrame = frame
			return frame
		end
		frame = EnumerateFrames(frame)
	end
end

-- Leader : annonce la fermeture de son DialogueUI (hook OnHide, posé une seule fois dès que
-- le cadre existe : DialogueUI le crée au premier dialogue).
local closeHookInstalled = false
local function TryHookDialogueUIClose()
	if closeHookInstalled then
		return
	end
	local frame = FindDialogueUIFrame()
	if not frame then
		return
	end
	frame:HookScript("OnHide", function()
		if GossipEnabled() then
			Send("CLOSEUI", "", "CLOSEUI", CLOSE_DEDUP, "fermeture de DialogueUI")
		end
	end)
	closeHookInstalled = true
	P.Debug("Fermeture de DialogueUI surveillée")
end
C_Timer.After(5, TryHookDialogueUIClose)

-- Réception de CLOSEUI (Sync.lua) : ferme DialogueUI et les panneaux Blizzard.
function P.OnDialogCloseMessage(sender)
	if not GossipEnabled() then
		return
	end
	local frame = FindDialogueUIFrame()
	if frame and frame:IsShown() then
		pcall(frame.HideUI or frame.Hide, frame)
	end
	if C_GossipInfo and C_GossipInfo.CloseGossip then
		C_GossipInfo.CloseGossip()
	end
	if CloseQuest then
		pcall(CloseQuest)
	end
	if GossipFrame and GossipFrame:IsShown() then
		HideUIPanel(GossipFrame)
	end
	if QuestFrame and QuestFrame:IsShown() then
		HideUIPanel(QuestFrame)
	end
	P.Debug("Dialogue fermé (fermeture du leader " .. tostring(sender) .. ")")
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

	-- DialogueUI crée son cadre au premier dialogue : tentative de hook à chaque ouverture.
	if (event == "GOSSIP_SHOW" or event == "QUEST_DETAIL") and not closeHookInstalled then
		C_Timer.After(0.1, TryHookDialogueUIClose)
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
-- Leader : choix d'une option de dialogue. Clic Blizzard et DialogueUI passent par
-- SelectOptionByIndex(orderIndex) ; SelectOption et SelectGossipOption pour les autres cas.
if C_GossipInfo and C_GossipInfo.SelectOptionByIndex then
	hooksecurefunc(C_GossipInfo, "SelectOptionByIndex", function(orderIndex)
		AnnounceGossipOption(ResolveGossipOptionID(orderIndex), orderIndex, "SelectOptionByIndex")
	end)
end
if C_GossipInfo and C_GossipInfo.SelectOption then
	hooksecurefunc(C_GossipInfo, "SelectOption", function(gossipOptionID)
		AnnounceGossipOption(gossipOptionID, nil, "SelectOption")
	end)
end
if SelectGossipOption then
	hooksecurefunc("SelectGossipOption", function(index)
		AnnounceGossipOption(ResolveGossipOptionID(index), index, "SelectGossipOption")
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
