-- Polypode: UI_Main — fenêtre principale : BuildUI, RefreshUI, ToggleUI

local P = Polypode
local ui = {}
P.ui = ui

local FRAME_WIDTH, FRAME_HEIGHT = 540, 320
local PANEL_TOP = -36 -- sous la barre de titre
local PANEL_MARGIN = 12
local PANEL_GAP = 10
local HEADER_HEIGHT = 26
local ROW_HEIGHT = 20

-- Cadre intérieur avec un en-tête, skinnable via P.SkinPanel.
local function CreatePanel(parent, title)
	local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	panel:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	panel:SetBackdropColor(0, 0, 0, 0.4)
	panel:SetBackdropBorderColor(0.4, 0.4, 0.4)

	panel.header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	panel.header:SetPoint("TOPLEFT", 10, -8)
	panel.header:SetText(title)

	return panel
end

local function CreateRow(parent, index)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 10, -HEADER_HEIGHT - (index - 1) * ROW_HEIGHT)
	row:SetPoint("RIGHT", -10, 0)

	row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.text:SetPoint("LEFT")
	row.text:SetPoint("RIGHT")
	row.text:SetJustifyH("LEFT")
	row.text:SetWordWrap(false)

	return row
end

-- "Nom-Royaume" coloré selon la classe, puis classe localisée et niveau en gris.
local function FormatCharacter(key, entry)
	local label = key
	local color = entry.class and C_ClassColor and C_ClassColor.GetClassColor(entry.class)
	if color then
		label = color:WrapTextInColorCode(label)
	end

	local details = {}
	if entry.class then
		details[#details + 1] = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[entry.class] or entry.class
	end
	if entry.level then
		details[#details + 1] = "niv. " .. entry.level
	end
	if #details > 0 then
		label = label .. " |cff999999" .. table.concat(details, " ") .. "|r"
	end

	if key == P.GetCharKey() then
		label = label .. " |cff999999(vous)|r"
	end
	if P.db.leader == key then
		label = label .. " |cffffd200[leader]|r"
	end
	return label
end

function P.BuildUI()
	if ui.frame then
		return
	end

	local f = CreateFrame("Frame", "PolypodeMainFrame", UIParent, "BackdropTemplate")
	f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	f:SetPoint("CENTER")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	f:SetBackdropColor(0, 0, 0, 0.85)
	f:Hide()

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -14)
	title:SetText("Polypode")
	f.TitleText = title -- repositionné par UI_Skin.lua selon le skin

	local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -4, -4)
	f.CloseButton = closeBtn -- nom attendu par les skins ElvUI/EllesmereUI

	-- Deux cadres côte à côte, de même largeur.
	local panelWidth = (FRAME_WIDTH - 2 * PANEL_MARGIN - PANEL_GAP) / 2

	-- Gauche : personnages trouvés (roster alimenté par la sync).
	local charPanel = CreatePanel(f, "Personnages trouvés")
	charPanel:SetPoint("TOPLEFT", PANEL_MARGIN, PANEL_TOP)
	charPanel:SetPoint("BOTTOMLEFT", PANEL_MARGIN, PANEL_MARGIN)
	charPanel:SetWidth(panelWidth)

	-- Droite : équipes gérées (contenu à définir).
	local teamPanel = CreatePanel(f, "Équipes gérées")
	teamPanel:SetPoint("TOPRIGHT", -PANEL_MARGIN, PANEL_TOP)
	teamPanel:SetPoint("BOTTOMRIGHT", -PANEL_MARGIN, PANEL_MARGIN)
	teamPanel:SetWidth(panelWidth)

	local teamEmpty = teamPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	teamEmpty:SetPoint("TOPLEFT", 10, -HEADER_HEIGHT)
	teamEmpty:SetText("Aucune équipe (à définir)")

	ui.frame = f
	ui.title = title
	ui.closeButton = closeBtn
	ui.charPanel = charPanel
	ui.teamPanel = teamPanel
	ui.teamEmptyText = teamEmpty
	ui.rows = {}

	if P.SkinFrame then
		P.SkinFrame(f)
		P.SkinPanel(charPanel)
		P.SkinPanel(teamPanel)
	end
end

function P.RefreshUI()
	if not ui.frame then
		return
	end

	for _, row in ipairs(ui.rows) do
		row:Hide()
	end

	-- Tri alphabétique pour un ordre stable d'un affichage à l'autre.
	local roster = P.GetRoster()
	local keys = {}
	for key in pairs(roster) do
		keys[#keys + 1] = key
	end
	table.sort(keys)

	for index, key in ipairs(keys) do
		local row = ui.rows[index] or CreateRow(ui.charPanel, index)
		ui.rows[index] = row
		row.text:SetText(FormatCharacter(key, roster[key]))
		row:Show()
	end
end

function P.ToggleUI()
	P.BuildUI()
	if ui.frame:IsShown() then
		ui.frame:Hide()
	else
		P.RefreshUI()
		ui.frame:Show()
	end
end
