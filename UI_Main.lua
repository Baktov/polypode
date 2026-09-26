-- Polypode: UI_Main — fenêtre principale : BuildUI, RefreshUI, ToggleUI

local P = Polypode
local ui = {}
P.ui = ui

-- Nom de l'équipe sélectionnée dans le cadre « Équipes » (session uniquement).
local selectedTeam

-- Taille minimale volontairement petite : en dessous du confortable, le contenu est
-- simplement tronqué (textes coupés sur une ligne, listes réduites), pas réorganisé.
local MIN_WIDTH, MIN_HEIGHT = 200, 100
local PANEL_TOP = -36 -- sous la barre de titre
local PANEL_MARGIN = 12
local PANEL_GAP = 10
local HEADER_HEIGHT = 26
local ROW_HEIGHT = 20
local INPUT_HEIGHT = 28 -- ligne de saisie (champ + bouton) sous l'en-tête d'un cadre

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
-- top : décalage depuis le haut du cadre (défaut : juste sous l'en-tête).
-- opts (facultatif) : lignes cliquables avec opts.onClick(data) ; opts.isSelected(data)
-- met la ligne en surbrillance.
local function CreateScrollList(panel, formatFn, top, opts)
	top = top or HEADER_HEIGHT
	opts = opts or {}
	local scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", 10, -top)
	scrollBox:SetPoint("BOTTOMRIGHT", -22, 8)

	local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer(opts.onClick and "Button" or "Frame", function(row, data)
		if not row.text then
			row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			row.text:SetPoint("LEFT", 4, 0)
			row.text:SetPoint("RIGHT", -4, 0)
			row.text:SetJustifyH("LEFT")
			row.text:SetWordWrap(false)

			if opts.onClick then
				-- Fond doré de la ligne sélectionnée, voile clair au survol.
				row.selected = row:CreateTexture(nil, "BACKGROUND")
				row.selected:SetAllPoints()
				row.selected:SetColorTexture(1, 0.82, 0, 0.25)
				local highlight = row:CreateTexture(nil, "HIGHLIGHT")
				highlight:SetAllPoints()
				highlight:SetColorTexture(1, 1, 1, 0.08)
			end
		end
		row.text:SetText(formatFn(data))

		if opts.onClick then
			row.selected:SetShown(opts.isSelected and opts.isSelected(data) or false)
			-- Les lignes sont recyclées : le script est rebranché sur la donnée courante.
			row:SetScript("OnClick", function()
				opts.onClick(data)
			end)
		end
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	-- Texte affiché quand la liste est vide.
	panel.emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	panel.emptyText:SetPoint("TOPLEFT", 10, -top)
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

	-- Trois cadres côte à côte, chacun sur un tiers de la largeur : les deux premiers
	-- reçoivent leur largeur au redimensionnement, le dernier s'étire jusqu'au bord droit.
	-- 1. Personnages trouvés (roster alimenté par la sync).
	local charPanel = CreatePanel(f, "Personnages trouvés")
	charPanel:SetPoint("TOPLEFT", PANEL_MARGIN, PANEL_TOP)
	charPanel:SetPoint("BOTTOMLEFT", PANEL_MARGIN, PANEL_MARGIN)
	CreateScrollList(charPanel, FormatCharacter)
	charPanel.emptyText:SetText("Aucun personnage trouvé")

	-- 2. Équipes : saisie d'un nom + liste des équipes créées.
	local teamPanel = CreatePanel(f, "Équipes")
	teamPanel:SetPoint("TOPLEFT", charPanel, "TOPRIGHT", PANEL_GAP, 0)
	teamPanel:SetPoint("BOTTOMLEFT", charPanel, "BOTTOMRIGHT", PANEL_GAP, 0)

	local createBtn = CreateFrame("Button", nil, teamPanel, "UIPanelButtonTemplate")
	createBtn:SetSize(60, 22)
	createBtn:SetPoint("TOPRIGHT", -10, -HEADER_HEIGHT + 2)
	createBtn:SetText("Créer")

	local teamInput = CreateFrame("EditBox", nil, teamPanel, "InputBoxInstructionsTemplate")
	teamInput:SetHeight(20)
	teamInput:SetPoint("TOPLEFT", 16, -HEADER_HEIGHT + 1) -- 16 : l'art du template déborde à gauche
	teamInput:SetPoint("RIGHT", createBtn, "LEFT", -8, 0)
	teamInput:SetAutoFocus(false)
	teamInput:SetMaxLetters(32)
	if teamInput.Instructions then
		teamInput.Instructions:SetText("Nom de l'équipe")
	end

	-- Valide la saisie (Entrée ou bouton) : crée l'équipe, ou affiche l'erreur à l'écran.
	local function SubmitTeam()
		local ok, err = P.CreateTeam(teamInput:GetText())
		if ok then
			teamInput:SetText("")
			P.RefreshUI()
		else
			UIErrorsFrame:AddMessage(err, 1, 0.1, 0.1)
		end
	end
	teamInput:SetScript("OnEnterPressed", SubmitTeam)
	teamInput:SetScript("OnEscapePressed", teamInput.ClearFocus)
	createBtn:SetScript("OnClick", SubmitTeam)

	CreateScrollList(teamPanel, function(data)
		return data.name
	end, HEADER_HEIGHT + INPUT_HEIGHT, {
		onClick = function(data)
			selectedTeam = data.name
			P.RefreshUI()
		end,
		isSelected = function(data)
			return data.name == selectedTeam
		end,
	})
	teamPanel.emptyText:SetText("Aucune équipe")

	-- 3. Personnages (contenu à définir ; liste défilante prête, vide pour l'instant).
	local memberPanel = CreatePanel(f, "Personnages de l'équipe")
	memberPanel:SetPoint("TOPLEFT", teamPanel, "TOPRIGHT", PANEL_GAP, 0)
	memberPanel:SetPoint("BOTTOMRIGHT", -PANEL_MARGIN, PANEL_MARGIN)
	CreateScrollList(memberPanel, function(data)
		return data.name
	end)
	memberPanel.emptyText:SetText("")

	local function LayoutPanels()
		local width = (f:GetWidth() - 2 * PANEL_MARGIN - 2 * PANEL_GAP) / 3
		width = math.max(width, 1)
		charPanel:SetWidth(width)
		teamPanel:SetWidth(width)
	end
	f:SetScript("OnSizeChanged", LayoutPanels)
	LayoutPanels()

	ui.frame = f
	ui.title = title
	ui.closeButton = closeBtn
	ui.resizeGrip = grip
	ui.charPanel = charPanel
	ui.teamPanel = teamPanel
	ui.teamInput = teamInput
	ui.teamCreateButton = createBtn
	ui.memberPanel = memberPanel

	if P.SkinFrame then
		P.SkinFrame(f)
		P.SkinPanel(charPanel)
		P.SkinPanel(teamPanel)
		P.SkinPanel(memberPanel)
		P.SkinEditBox(teamInput)
		P.SkinButton(createBtn)
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

	local teams = {}
	for name in pairs(P.GetTeams()) do
		teams[#teams + 1] = { name = name }
	end
	table.sort(teams, function(a, b)
		return a.name < b.name
	end)
	-- Oublie une sélection devenue invalide (équipe absente de la liste).
	if selectedTeam and not P.GetTeams()[selectedTeam] then
		selectedTeam = nil
	end
	SetListData(ui.teamPanel, teams)

	SetListData(ui.memberPanel, {})
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
