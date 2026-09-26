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
-- opts (facultatif) : lignes cliquables (gauche et droit) avec opts.onClick(data, mouseButton) ;
-- opts.isSelected(data) met la ligne en surbrillance. opts.tooltip(data) renvoie les lignes
-- de l'infobulle affichée au survol (la première sert de titre).
local function CreateScrollList(panel, formatFn, top, opts)
	top = top or HEADER_HEIGHT
	opts = opts or {}
	local scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", 10, -top)
	scrollBox:SetPoint("BOTTOMRIGHT", -22, 8)

	local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)

	-- Infobulle de la ligne survolée, construite depuis la donnée courante de la ligne.
	local function ShowRowTooltip(row)
		local lines = opts.tooltip(row.data)
		GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
		for i, line in ipairs(lines) do
			if i == 1 then
				GameTooltip:AddLine(line)
			else
				GameTooltip:AddLine(line, 1, 1, 1)
			end
		end
		GameTooltip:Show()
	end

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
				row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
				-- Fond doré de la ligne sélectionnée, voile clair au survol.
				row.selected = row:CreateTexture(nil, "BACKGROUND")
				row.selected:SetAllPoints()
				row.selected:SetColorTexture(1, 0.82, 0, 0.25)
				local highlight = row:CreateTexture(nil, "HIGHLIGHT")
				highlight:SetAllPoints()
				highlight:SetColorTexture(1, 1, 1, 0.08)
			end

			if opts.tooltip then
				row:EnableMouse(true)
				row:SetScript("OnEnter", ShowRowTooltip)
				row:SetScript("OnLeave", GameTooltip_Hide)
			end
		end
		row.data = data
		row.text:SetText(formatFn(data))

		-- Après un clic, la liste est reconstruite sous le curseur : l'infobulle ouverte
		-- sur cette ligne est rafraîchie pour refléter le nouvel état.
		if opts.tooltip and GameTooltip:IsOwned(row) then
			ShowRowTooltip(row)
		end

		if opts.onClick then
			row.selected:SetShown(opts.isSelected and opts.isSelected(data) or false)
			-- Les lignes sont recyclées : le script est rebranché sur la donnée courante.
			row:SetScript("OnClick", function(_, mouseButton)
				opts.onClick(data, mouseButton)
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

-- Transforme un ensemble { [clé] = ... } en items { key = clé } triés par ordre alphabétique,
-- pour un ordre stable d'un affichage à l'autre.
local function SortedKeyItems(set)
	local keys = {}
	for key in pairs(set) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	local items = {}
	for i, key in ipairs(keys) do
		items[i] = { key = key }
	end
	return items
end

-- Lignes d'infobulle d'un personnage : nom, rappels des clics (hints), puis ses équipes
-- (l'équipe sélectionnée en vert, « (leader) » là où il est leader).
local function CharacterTooltip(key, hints)
	local lines = { key }
	for _, hint in ipairs(hints) do
		lines[#lines + 1] = hint
	end
	lines[#lines + 1] = " "

	local teams = P.GetCharacterTeams(key)
	if #teams == 0 then
		lines[#lines + 1] = "|cff999999Dans aucune équipe|r"
	else
		lines[#lines + 1] = "|cffffd200Équipes :|r"
		for _, name in ipairs(teams) do
			local line = name
			if name == selectedTeam then
				line = "|cff00ff00" .. name .. "|r"
			end
			if P.GetTeamLeader(name) == key then
				line = line .. " |cffffd200(leader)|r"
			end
			lines[#lines + 1] = "  " .. line
		end
	end
	return lines
end

-- Raison pour laquelle le bouton « Inviter l'équipe » est inactif, ou nil s'il est actif :
-- seul le leader de l'équipe sélectionnée invite, et il faut un autre membre que soi.
local function InviteBlockedReason()
	if not selectedTeam then
		return "Sélectionnez d'abord une équipe."
	end
	local leader = P.GetTeamLeader(selectedTeam)
	if not leader then
		return "L'équipe n'a pas de leader : clic gauche sur un de ses personnages pour le désigner."
	end
	if leader ~= P.GetCharKey() then
		return "Seul le leader de l'équipe (" .. leader .. ") peut inviter l'équipe."
	end
	for key in pairs(P.GetTeamMembers(selectedTeam) or {}) do
		if key ~= P.GetCharKey() then
			return nil
		end
	end
	return "L'équipe ne compte aucun autre membre que vous."
end

-- "Nom-Royaume" coloré selon la classe, puis classe localisée et niveau en gris.
-- teamName (facultatif) : affichage dans une équipe, [leader] marque le leader de cette équipe.
local function FormatCharacter(data, teamName)
	local key = data.key
	local entry = P.db.roster[key] or {}
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
	if teamName and P.GetTeamLeader(teamName) == key then
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

	-- Bouton Options (barre de titre, à gauche) : ouvre Options > AddOns > Polypode.
	local optionsBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	optionsBtn:SetSize(70, 20)
	optionsBtn:SetPoint("TOPLEFT", 6, -3)
	optionsBtn:SetText("Options")
	optionsBtn:SetScript("OnClick", function()
		P.OpenOptions()
	end)
	optionsBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Options")
		GameTooltip:AddLine("Ouvre les options de Polypode (Options > AddOns > Polypode).", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	optionsBtn:SetScript("OnLeave", GameTooltip_Hide)

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

	-- Bouton d'ajout du joueur ciblé (personnage sans Polypode, ex. un ami) au roster.
	local addTargetBtn = CreateFrame("Button", nil, charPanel, "UIPanelButtonTemplate")
	addTargetBtn:SetHeight(22)
	addTargetBtn:SetPoint("TOPLEFT", 10, -HEADER_HEIGHT + 2)
	addTargetBtn:SetPoint("RIGHT", -10, 0)
	addTargetBtn:SetText("Ajouter la cible")
	addTargetBtn:SetScript("OnClick", function()
		local ok, result = P.AddTargetCharacter()
		if ok then
			UIErrorsFrame:AddMessage(result .. " ajouté à la liste.", 1, 0.82, 0)
			P.RefreshUI()
		else
			UIErrorsFrame:AddMessage(result, 1, 0.1, 0.1)
		end
	end)
	addTargetBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Ajouter la cible")
		GameTooltip:AddLine("Ajoute le joueur ciblé à la liste des personnages trouvés : il peut "
			.. "ensuite rejoindre une équipe (clic gauche avec l'équipe sélectionnée) et être "
			.. "invité avec elle.", 1, 1, 1, true)
		GameTooltip:AddLine("Partagé avec vos autres Polypode connectés.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	addTargetBtn:SetScript("OnLeave", GameTooltip_Hide)

	-- Clic gauche : ajoute à l'équipe sélectionnée ; clic droit : l'en retire.
	-- Les membres de l'équipe sélectionnée sont surlignés.
	CreateScrollList(charPanel, FormatCharacter, HEADER_HEIGHT + INPUT_HEIGHT, {
		onClick = function(data, mouseButton)
			if not selectedTeam then
				UIErrorsFrame:AddMessage("Sélectionnez d'abord une équipe.", 1, 0.1, 0.1)
				return
			end
			if mouseButton == "RightButton" then
				P.RemoveTeamMember(selectedTeam, data.key)
			else
				P.AddTeamMember(selectedTeam, data.key)
			end
			P.RefreshUI()
		end,
		isSelected = function(data)
			local members = P.GetTeamMembers(selectedTeam)
			return members and members[data.key] or false
		end,
		tooltip = function(data)
			if not selectedTeam then
				return CharacterTooltip(data.key, { "Sélectionnez d'abord une équipe pour y ajouter ce personnage." })
			end
			return CharacterTooltip(data.key, {
				"Clic gauche : ajouter à l'équipe « " .. selectedTeam .. " »",
				"Clic droit : retirer de l'équipe « " .. selectedTeam .. " »",
			})
		end,
	})
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

	-- 3. Personnages de l'équipe sélectionnée (texte vide renseigné par RefreshUI).
	local memberPanel = CreatePanel(f, "Personnages de l'équipe")
	memberPanel:SetPoint("TOPLEFT", teamPanel, "TOPRIGHT", PANEL_GAP, 0)
	memberPanel:SetPoint("BOTTOMRIGHT", -PANEL_MARGIN, PANEL_MARGIN)

	-- Bouton d'invitation de toute l'équipe (état actif géré par RefreshUI).
	local inviteBtn = CreateFrame("Button", nil, memberPanel, "UIPanelButtonTemplate")
	inviteBtn:SetHeight(22)
	inviteBtn:SetPoint("TOPLEFT", 10, -HEADER_HEIGHT + 2)
	inviteBtn:SetPoint("RIGHT", -10, 0)
	inviteBtn:SetText("Inviter l'équipe")
	inviteBtn:SetMotionScriptsWhileDisabled(true) -- infobulle même désactivé
	inviteBtn:SetScript("OnClick", function()
		if not selectedTeam then
			return
		end
		local ok, message = P.InviteTeam(selectedTeam)
		if ok then
			UIErrorsFrame:AddMessage(message, 1, 0.82, 0)
		else
			UIErrorsFrame:AddMessage(message, 1, 0.1, 0.1)
		end
		-- Dans tous les cas, partage l'équipe avec les Polypode des membres (et des clients
		-- connectés), qui la sélectionnent.
		P.SyncTeam(selectedTeam, nil, true)
	end)
	inviteBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Inviter l'équipe")
		if selectedTeam then
			GameTooltip:AddLine("Invite dans votre groupe les membres de l'équipe « " .. selectedTeam
				.. " », sauf vous et ceux déjà groupés.", 1, 1, 1, true)
			GameTooltip:AddLine("L'équipe (nom, membres, leader) est aussi envoyée aux Polypode "
				.. "de ses membres.", 1, 1, 1, true)
		end
		local reason = InviteBlockedReason()
		if reason then
			GameTooltip:AddLine(reason, 1, 0.1, 0.1, true)
		end
		GameTooltip:Show()
	end)
	inviteBtn:SetScript("OnLeave", GameTooltip_Hide)

	-- Clic gauche : leader de l'équipe (surligné) ; clic droit : retire le personnage.
	CreateScrollList(memberPanel, function(data)
		return FormatCharacter(data, selectedTeam)
	end, HEADER_HEIGHT + INPUT_HEIGHT, {
		onClick = function(data, mouseButton)
			if not selectedTeam then
				return
			end
			if mouseButton == "RightButton" then
				P.RemoveTeamMember(selectedTeam, data.key)
			else
				P.SetTeamLeader(selectedTeam, data.key)
			end
			P.RefreshUI()
		end,
		isSelected = function(data)
			return P.GetTeamLeader(selectedTeam) == data.key
		end,
		tooltip = function(data)
			local team = selectedTeam or ""
			return CharacterTooltip(data.key, {
				"Clic gauche : définir comme leader de l'équipe « " .. team .. " »",
				"Clic droit : retirer de l'équipe « " .. team .. " »",
			})
		end,
	})

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
	ui.optionsButton = optionsBtn
	ui.resizeGrip = grip
	ui.charPanel = charPanel
	ui.teamPanel = teamPanel
	ui.teamInput = teamInput
	ui.teamCreateButton = createBtn
	ui.memberPanel = memberPanel
	ui.inviteButton = inviteBtn
	ui.addTargetButton = addTargetBtn

	if P.SkinFrame then
		P.SkinFrame(f)
		P.SkinPanel(charPanel)
		P.SkinPanel(teamPanel)
		P.SkinPanel(memberPanel)
		P.SkinEditBox(teamInput)
		P.SkinButton(createBtn)
		P.SkinButton(inviteBtn)
		P.SkinButton(addTargetBtn)
		P.SkinButton(optionsBtn)
	end
end

function P.RefreshUI()
	if not ui.frame then
		return
	end

	-- Oublie une sélection devenue invalide (équipe absente de la liste).
	if selectedTeam and not P.GetTeams()[selectedTeam] then
		selectedTeam = nil
	end

	SetListData(ui.charPanel, SortedKeyItems(P.GetRoster()))

	local teams = {}
	for name in pairs(P.GetTeams()) do
		teams[#teams + 1] = { name = name }
	end
	table.sort(teams, function(a, b)
		return a.name < b.name
	end)
	SetListData(ui.teamPanel, teams)

	local members = P.GetTeamMembers(selectedTeam)
	SetListData(ui.memberPanel, SortedKeyItems(members or {}))
	if not members then
		ui.memberPanel.emptyText:SetText("Sélectionnez une équipe")
	else
		ui.memberPanel.emptyText:SetText("Clic gauche sur un personnage trouvé pour l'ajouter")
	end

	-- L'état du groupe, qui change sans rafraîchir la fenêtre, est vérifié au clic par P.InviteTeam.
	ui.inviteButton:SetEnabled(InviteBlockedReason() == nil)
end

-- Sélectionne une équipe (ex. reçue par synchro) et rafraîchit la fenêtre si elle existe.
function P.SelectTeam(teamName)
	selectedTeam = teamName
	P.RefreshUI()
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
