-- Polypode: UI_TeamQuests — fenêtre des quêtes du leader manquantes chez les membres

local P = Polypode

-- Bouton « Quêtes » de la fenêtre principale ou /poly quetes (P.ShowTeamQuests). Liste
-- défilante des quêtes du leader de l'équipe sélectionnée (soi-même si l'équipe n'a pas de
-- leader) ; pour chacune, les membres de l'équipe qui ne l'ont pas (en rouge), ou « toute
-- l'équipe ». Les journaux viennent du Polypode de chaque membre (QLOG, Sync.lua) : un membre
-- dont aucun journal n'a été reçu est « inconnu ». Les quêtes qui manquent au plus de
-- membres viennent en premier. Rafraîchie à chaque journal reçu ou modifié. Échap la ferme.

local FRAME_WIDTH, FRAME_HEIGHT = 440, 320

local frame, listPanel
local titleRequested = {} -- [questID] = true : chargement déjà demandé (une fois par session)

local function MemberName(key)
	local entry = P.db.roster[key]
	return entry and entry.name or key
end

-- Titre d'une quête ; inconnu (quête d'un autre personnage), il est demandé une seule fois
-- au serveur et la fenêtre se rafraîchit à son arrivée (QUEST_DATA_LOAD_RESULT, Quests.lua).
local function QuestTitle(questID)
	local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
	if not title and not titleRequested[questID] and C_QuestLog.RequestLoadQuestByID then
		titleRequested[questID] = true
		C_QuestLog.RequestLoadQuestByID(questID)
	end
	return title or ("Quête n° " .. questID)
end

-- Lignes de la liste, texte d'en-tête et texte de liste vide.
local function BuildItems()
	local team = P.GetSelectedTeam()
	if not team then
		return {}, "Quêtes de l'équipe", "Sélectionnez une équipe."
	end
	local reference = P.GetTeamLeader(team) or P.GetCharKey()
	local header = "Quêtes de " .. MemberName(reference) .. " (équipe « " .. team .. " »)"
	local quests = P.GetCharacterQuests(reference)
	if not quests then
		return {}, header, "Journal de quêtes du leader pas encore reçu."
	end

	local others = {}
	for key in pairs(P.GetTeamMembers(team) or {}) do
		if key ~= reference then
			others[#others + 1] = key
		end
	end
	table.sort(others)

	local items = {}
	for questID in pairs(quests) do
		local item = { questID = questID, title = QuestTitle(questID), missing = {}, having = {}, unknown = {} }
		for _, key in ipairs(others) do
			local memberQuests = P.GetCharacterQuests(key)
			local list = not memberQuests and item.unknown or memberQuests[questID] and item.having or item.missing
			list[#list + 1] = MemberName(key)
		end
		items[#items + 1] = item
	end
	table.sort(items, function(a, b)
		if #a.missing ~= #b.missing then
			return #a.missing > #b.missing
		end
		return a.title < b.title
	end)
	return items, header, "Aucune quête dans le journal du leader."
end

local function FormatQuest(item)
	local text = item.title .. "  "
	if #item.missing > 0 then
		text = text .. "|cffff5555manque : " .. table.concat(item.missing, ", ") .. "|r"
	elseif #item.unknown == 0 then
		text = text .. "|cff40ff40toute l'équipe|r"
	end
	if #item.unknown > 0 then
		text = text .. " |cff999999(inconnu : " .. table.concat(item.unknown, ", ") .. ")|r"
	end
	return text
end

local function QuestTooltip(item)
	local lines = { item.title, "|cff999999Quête n° " .. item.questID .. "|r" }
	local function Section(title, names)
		if #names > 0 then
			lines[#lines + 1] = " "
			lines[#lines + 1] = title
			for _, name in ipairs(names) do
				lines[#lines + 1] = "  " .. name
			end
		end
	end
	Section("|cffff5555Ne l'ont pas :|r", item.missing)
	Section("|cff40ff40L'ont :|r", item.having)
	Section("|cff999999Inconnu (journal pas reçu de leur Polypode) :|r", item.unknown)
	return lines
end

local function Build()
	frame = CreateFrame("Frame", "PolypodeTeamQuestsFrame", UIParent, "BackdropTemplate")
	frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0, 0, 0, 0.9)
	frame:Hide()
	tinsert(UISpecialFrames, "PolypodeTeamQuestsFrame") -- Échap ferme la fenêtre

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -14)
	title:SetText("Quêtes de l'équipe")
	frame.TitleText = title

	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -4, -4)
	frame.CloseButton = closeBtn

	listPanel = P.CreatePanel(frame, "")
	listPanel:SetPoint("TOPLEFT", 12, -36)
	listPanel:SetPoint("BOTTOMRIGHT", -12, 12)
	P.CreateScrollList(listPanel, FormatQuest, nil, { tooltip = QuestTooltip })

	P.ui.teamQuestsFrame = frame
	P.ui.teamQuestsPanel = listPanel

	P.SkinFrame(frame)
	P.SkinPanel(listPanel)
end

-- Remplit la liste, si la fenêtre est ouverte (appelé par P.RefreshUI et à chaque journal
-- de quêtes reçu ou modifié).
function P.RefreshTeamQuests()
	if not frame or not frame:IsShown() then
		return
	end
	local items, header, emptyText = BuildItems()
	listPanel.header:SetText(header)
	listPanel.emptyText:SetText(emptyText)
	P.SetListData(listPanel, items)
end

-- Ouvre / ferme la fenêtre (bouton « Quêtes », /poly quetes).
function P.ToggleTeamQuests()
	if not frame then
		Build()
	end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
		P.RefreshTeamQuests()
	end
end
