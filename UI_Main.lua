-- Polypode: UI_Main — fenêtre principale : BuildUI, RefreshUI, ToggleUI

local P = Polypode
local ui = {}
P.ui = ui

-- Taille minimale volontairement petite : en dessous du confortable, le contenu est
-- simplement tronqué (textes coupés sur une ligne, listes réduites), pas réorganisé.
local MIN_WIDTH, MIN_HEIGHT = 200, 100
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
	panel.header:SetPoint("RIGHT", -10, 0)
	panel.header:SetJustifyH("LEFT")
	panel.header:SetWordWrap(false) -- tronqué si la fenêtre est trop étroite
	panel.header:SetText(title)

	return panel
end

-- Liste défilante sans limite de taille sous l'en-tête d'un cadre (ScrollBox Blizzard :
-- seules les lignes visibles existent, recyclées au défilement). formatFn(data) renvoie
-- le texte d'une ligne. Remplir avec SetListData(panel, items), items = liste de tables.
local function CreateScrollList(panel, formatFn)
	local scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", 10, -HEADER_HEIGHT)
	scrollBox:SetPoint("BOTTOMRIGHT", -22, 8)

	local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("Frame", function(row, data)
		if not row.text then
			row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			row.text:SetPoint("LEFT")
			row.text:SetPoint("RIGHT")
			row.text:SetJustifyH("LEFT")
			row.text:SetWordWrap(false)
		end
		row.text:SetText(formatFn(data))
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	-- Texte affiché quand la liste est vide.
	panel.emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	panel.emptyText:SetPoint("TOPLEFT", 10, -HEADER_HEIGHT)
	panel.emptyText:SetPoint("RIGHT", -10, 0)
	panel.emptyText:SetJustifyH("LEFT")
	panel.emptyText:SetWordWrap(false)

	panel.scrollBox = scrollBox
	panel.scrollBar = scrollBar
	if P.SkinScrollBar then
		P.SkinScrollBar(scrollBar)
	end
end

local function SetListData(panel, items)
	panel.scrollBox:SetDataProvider(CreateDataProvider(items), ScrollBoxConstants.RetainScrollPosition)
	panel.emptyText:SetShown(#items == 0)
end

-- "Nom-Royaume" coloré selon la classe, puis classe localisée et niveau en gris.
local function FormatCharacter(data)
	local key = data.key
	local entry = P.GetRoster()[key] or {}
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
	f:SetSize(P.db.mainFrame.width, P.db.mainFrame.height)
	f:SetPoint("CENTER")
	f:SetMovable(true)
	f:SetResizable(true)
	f:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT)
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

	-- Poignée de redimensionnement (coin bas-droit), au-dessus des cadres intérieurs.
	local grip = CreateFrame("Button", nil, f)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -2, 2)
	grip:SetFrameLevel(f:GetFrameLevel() + 10)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", function()
		f:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnMouseUp", function()
		f:StopMovingOrSizing()
		P.db.mainFrame.width, P.db.mainFrame.height = f:GetSize()
	end)

	-- Deux cadres côte à côte, chacun sur une moitié de la fenêtre (suivent le redimensionnement).
	-- Gauche : personnages trouvés (roster alimenté par la sync).
	local charPanel = CreatePanel(f, "Personnages trouvés")
	charPanel:SetPoint("TOPLEFT", PANEL_MARGIN, PANEL_TOP)
	charPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -PANEL_GAP / 2, PANEL_MARGIN)
	CreateScrollList(charPanel, FormatCharacter)
	charPanel.emptyText:SetText("Aucun personnage trouvé")

	-- Droite : équipes gérées (contenu à définir ; liste défilante prête, vide pour l'instant).
	local teamPanel = CreatePanel(f, "Équipes gérées")
	teamPanel:SetPoint("TOPLEFT", f, "TOP", PANEL_GAP / 2, PANEL_TOP)
	teamPanel:SetPoint("BOTTOMRIGHT", -PANEL_MARGIN, PANEL_MARGIN)
	CreateScrollList(teamPanel, function(data)
		return data.name
	end)
	teamPanel.emptyText:SetText("Aucune équipe (à définir)")

	ui.frame = f
	ui.title = title
	ui.closeButton = closeBtn
	ui.resizeGrip = grip
	ui.charPanel = charPanel
	ui.teamPanel = teamPanel

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

	-- Tri alphabétique pour un ordre stable d'un affichage à l'autre.
	local keys = {}
	for key in pairs(P.GetRoster()) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	local items = {}
	for i, key in ipairs(keys) do
		items[i] = { key = key }
	end
	SetListData(ui.charPanel, items)

	SetListData(ui.teamPanel, {})
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
