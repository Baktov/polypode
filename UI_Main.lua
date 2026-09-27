-- Polypode: UI_Main — fenêtre principale : BuildUI, RefreshUI, ToggleUI

local P = Polypode
local ui = {}
P.ui = ui

-- Nom de l'équipe sélectionnée dans le cadre « Équipes » (session uniquement).
-- Recalculé par RefreshUI depuis le choix mémorisé pour ce personnage (P.charDb.selectedTeam),
-- nil tant que l'équipe mémorisée n'existe pas localement (ex. pas encore reçue par synchro).
local selectedTeam

-- Mémorise l'équipe choisie pour ce personnage (conservée au reload/reconnexion) et l'affiche.
local function ChooseTeam(teamName)
	P.charDb.selectedTeam = teamName
	P.RefreshUI()
end

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
-- opts.isSelected(data) met la ligne en surbrillance (aussi sans clic). opts.tooltip(data) renvoie les lignes
-- de l'infobulle affichée au survol (la première sert de titre) ; opts.tooltipUnit(data)
-- renvoie une unité (ex. "party2") dont l'infobulle WoW complète remplace alors ces lignes,
-- ou nil. opts.button : bouton à
-- droite de chaque ligne, { text, width, onClick = fn(data), tooltip = texte d'aide }.
-- opts.onDragStart(data) : appelé quand on commence à glisser une ligne (clic gauche maintenu).
-- opts.inset : marge gauche et droite de la liste dans le cadre (défaut 10). La barre de
-- défilement n'apparaît (et ne prend de place à droite) que si la liste déborde.
local function CreateScrollList(panel, formatFn, top, opts)
	top = top or HEADER_HEIGHT
	opts = opts or {}
	local inset = opts.inset or 10
	local scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", inset, -top) -- ancres initiales, ajustées ensuite selon la barre
	scrollBox:SetPoint("BOTTOMRIGHT", -inset, 8)

	local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)

	-- Infobulle de la ligne survolée, construite depuis la donnée courante de la ligne.
	local function ShowRowTooltip(row)
		GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
		local unit = opts.tooltipUnit and opts.tooltipUnit(row.data)
		if unit then
			GameTooltip:SetUnit(unit)
			return
		end
		local lines = opts.tooltip(row.data)
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

			-- Fond doré de la ligne sélectionnée.
			if opts.isSelected then
				row.selected = row:CreateTexture(nil, "BACKGROUND")
				row.selected:SetAllPoints()
				row.selected:SetColorTexture(1, 0.82, 0, 0.25)
			end

			if opts.onClick then
				row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
				-- Voile clair au survol.
				local highlight = row:CreateTexture(nil, "HIGHLIGHT")
				highlight:SetAllPoints()
				highlight:SetColorTexture(1, 1, 1, 0.08)
			end

			if opts.onDragStart then
				row:EnableMouse(true)
				row:RegisterForDrag("LeftButton")
			end

			if opts.tooltip then
				row:EnableMouse(true)
				row:SetScript("OnEnter", ShowRowTooltip)
				row:SetScript("OnLeave", GameTooltip_Hide)
			end

			if opts.button then
				row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
				row.button:SetSize(opts.button.width or 80, ROW_HEIGHT - 2)
				row.button:SetPoint("RIGHT", -2, 0)
				row.button:SetText(opts.button.text)
				row.text:SetPoint("RIGHT", row.button, "LEFT", -6, 0)
				if opts.button.tooltip then
					row.button:SetScript("OnEnter", function(self)
						GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
						GameTooltip:AddLine(opts.button.text)
						GameTooltip:AddLine(opts.button.tooltip, 1, 1, 1, true)
						GameTooltip:Show()
					end)
					row.button:SetScript("OnLeave", GameTooltip_Hide)
				end
				if P.SkinButton then
					P.SkinButton(row.button)
				end
			end
		end
		row.data = data
		row.text:SetText(formatFn(data))

		if opts.button then
			-- Lignes recyclées : le bouton agit sur la donnée courante de la ligne.
			row.button:SetScript("OnClick", function()
				opts.button.onClick(row.data)
			end)
		end

		-- Après un clic, la liste est reconstruite sous le curseur : l'infobulle ouverte
		-- sur cette ligne est rafraîchie pour refléter le nouvel état.
		if opts.tooltip and GameTooltip:IsOwned(row) then
			ShowRowTooltip(row)
		end

		if opts.onDragStart then
			row:SetScript("OnDragStart", function()
				opts.onDragStart(data)
			end)
		end

		if opts.isSelected then
			row.selected:SetShown(opts.isSelected(data) or false)
		end

		if opts.onClick then
			-- Les lignes sont recyclées : le script est rebranché sur la donnée courante.
			row:SetScript("OnClick", function(_, mouseButton)
				opts.onClick(data, mouseButton)
			end)
		end
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
	-- Place de la barre réservée à droite seulement quand elle est affichée.
	local topLeft = CreateAnchor("TOPLEFT", panel, "TOPLEFT", inset, -top)
	ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar,
		{ topLeft, CreateAnchor("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -22, 8) },
		{ topLeft, CreateAnchor("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -inset, 8) })

	-- Texte affiché quand la liste est vide.
	panel.emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	panel.emptyText:SetPoint("TOPLEFT", inset, -top)
	panel.emptyText:SetPoint("RIGHT", -inset, 0)
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

-- Partagés avec les autres fenêtres (UI_*.lua) : cadre à en-tête et liste défilante.
P.CreatePanel = CreatePanel
P.CreateScrollList = CreateScrollList
P.SetListData = SetListData

-- Lettres accentuées (UTF-8) ramenées à leur lettre de base minuscule pour le tri alphabétique.
local ACCENT_BASES = {
	a = "àáâãäåÀÁÂÃÄÅ", c = "çÇ", e = "èéêëÈÉÊË", i = "ìíîïÌÍÎÏ", n = "ñÑ",
	o = "òóôõöøÒÓÔÕÖØ", u = "ùúûüÙÚÛÜ", y = "ýÿÝ", ae = "æÆ", oe = "œŒ", ss = "ß",
}
local ACCENT_MAP = {}
for base, letters in pairs(ACCENT_BASES) do
	for letter in letters:gmatch("[\195\197][\128-\191]") do
		ACCENT_MAP[letter] = base
	end
end

-- Clé de tri alphabétique : sans accents ni distinction de casse (le tri brut des octets
-- placerait les minuscules et les initiales accentuées après Z).
local function AlphaKey(text)
	return (text:gsub("[\195\197][\128-\191]", ACCENT_MAP):lower())
end

-- Transforme un ensemble { [clé] = ... } en items { key = clé } triés par ordre alphabétique
-- (AlphaKey, puis clé brute en cas d'égalité), pour un ordre stable d'un affichage à l'autre.
local function SortedKeyItems(set)
	local keys, sortKeys = {}, {}
	for key in pairs(set) do
		keys[#keys + 1] = key
		sortKeys[key] = AlphaKey(key)
	end
	table.sort(keys, function(x, y)
		if sortKeys[x] ~= sortKeys[y] then
			return sortKeys[x] < sortKeys[y]
		end
		return x < y
	end)
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

-- Partagé avec la barre flottante d'équipe (UI_TeamBar.lua).
P.CharacterTooltip = CharacterTooltip

-- Raison pour laquelle le bouton « Inviter l'équipe » est inactif, ou nil s'il est actif
-- (règle commune avec le raccourci clavier, cf. P.GetInviteBlockedReason).
local function InviteBlockedReason()
	return P.GetInviteBlockedReason(selectedTeam)
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

-- Partagés avec la barre flottante d'équipe (UI_TeamBar.lua).
P.SortedKeyItems = SortedKeyItems
P.FormatCharacter = FormatCharacter

-- Champ de saisie du canal dédié (fenêtre principale et panneau d'options) : Entrée valide,
-- Échap annule, infobulle d'aide. Validation et synchro dans P.SetSyncChannel (Core.lua).
function P.SetupChannelInput(editBox)
	editBox:SetAutoFocus(false)
	editBox:SetMaxLetters(31)
	editBox:SetScript("OnEnterPressed", function(self)
		local ok, err = P.SetSyncChannel(self:GetText())
		if ok then
			local name = P.GetSyncChannelName()
			UIErrorsFrame:AddMessage(name == "" and "Canal dédié désactivé."
				or "Canal dédié : " .. name .. ".", 1, 0.82, 0)
			self:ClearFocus()
			P.RefreshUI()
		else
			UIErrorsFrame:AddMessage(err, 1, 0.1, 0.1)
		end
	end)
	editBox:SetScript("OnEscapePressed", function(self)
		self:SetText(P.GetSyncChannelName())
		self:ClearFocus()
	end)
	editBox:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Canal dédié (optionnel)")
		GameTooltip:AddLine("Le plus simple : grouper vos personnages à la première connexion. "
			.. "Vos Polypode se trouvent alors par le groupe (ou par une guilde commune), sans "
			.. "rien régler ici.", 1, 1, 1, true)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Le canal dédié sert dans les autres cas : plusieurs comptes WoW ou "
			.. "Battle.net, personnages sans guilde commune, pas encore groupés. C'est un canal de "
			.. "discussion commun à vos comptes, rejoint automatiquement et invisible dans le chat, "
			.. "où vos Polypode se trouvent dès la connexion.", 1, 1, 1, true)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Entrée pour valider, vide pour désactiver. Partagé avec vos autres "
			.. "Polypode connectés.", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	editBox:SetScript("OnLeave", GameTooltip_Hide)
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

	-- Canal dédié (barre de titre, à droite de Options) : validé par Entrée, Échap annule.
	local channelLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	channelLabel:SetPoint("LEFT", optionsBtn, "RIGHT", 10, 0)
	channelLabel:SetText("Canal :")

	local channelInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	channelInput:SetSize(110, 18)
	channelInput:SetPoint("LEFT", channelLabel, "RIGHT", 8, 0) -- 8 : l'art du template déborde à gauche
	P.SetupChannelInput(channelInput)

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
	-- 1. Personnages disponibles (roster alimenté par la sync).
	local charPanel = CreatePanel(f, "Personnages disponibles")
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
		GameTooltip:AddLine("Ajoute le joueur ciblé à la liste des personnages disponibles : il peut "
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
	charPanel.emptyText:SetText("Aucun personnage disponible")

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

	-- Clic gauche : sélectionne l'équipe ; clic droit : désélectionne (plus aucune équipe) ;
	-- Maj + clic gauche : supprime l'équipe (synchronisé).
	-- Glisser : sélectionne l'équipe et la sort en barre flottante (UI_TeamBar.lua).
	CreateScrollList(teamPanel, function(data)
		return data.name
	end, HEADER_HEIGHT + INPUT_HEIGHT, {
		onClick = function(data, mouseButton)
			if mouseButton == "LeftButton" and IsShiftKeyDown() then
				if P.DeleteTeam(data.name) then
					UIErrorsFrame:AddMessage("Équipe « " .. data.name .. " » supprimée.", 1, 0.82, 0)
					if P.charDb.selectedTeam == data.name then
						ChooseTeam(nil)
					else
						P.RefreshUI()
					end
				end
			elseif mouseButton == "RightButton" then
				ChooseTeam(nil)
			else
				ChooseTeam(data.name)
			end
		end,
		isSelected = function(data)
			return data.name == selectedTeam
		end,
		tooltip = function(data)
			return {
				data.name,
				"Clic gauche : sélectionner l'équipe",
				"Clic droit : désélectionner",
				"Maj + clic gauche : supprimer l'équipe",
				"Glisser : sélectionner et afficher en barre flottante",
			}
		end,
		onDragStart = function(data)
			ChooseTeam(data.name)
			P.StartTeamBarDrag()
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
		P.InviteSelectedTeam() -- même action que le raccourci clavier (Commands.lua)
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
	ui.channelLabel = channelLabel
	ui.channelInput = channelInput
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
		P.SkinEditBox(channelInput)
	end
end

function P.RefreshUI()
	-- Appelé après toute modification (sélection, équipes, synchro) : les macros des
	-- raccourcis Suivre/Assister suivent le leader, que la fenêtre soit construite ou non.
	if P.UpdateLeaderMacros then
		P.UpdateLeaderMacros()
	end
	-- Barre flottante de l'équipe sélectionnée (UI_TeamBar.lua), si elle est affichée.
	if P.RefreshTeamBar then
		P.RefreshTeamBar()
	end
	-- Fenêtre des comptes autorisés (UI_Tokens.lua), si elle est ouverte.
	if P.RefreshTokensWindow then
		P.RefreshTokensWindow()
	end

	if not ui.frame then
		return
	end

	-- Sélection = choix mémorisé, s'il existe localement. Le choix n'est jamais effacé ici :
	-- une équipe absente au login (synchro pas encore arrivée) sera sélectionnée à sa réception.
	selectedTeam = P.GetSelectedTeam()

	-- Canal dédié (peut changer par synchro) ; pas pendant une saisie.
	if not ui.channelInput:HasFocus() then
		ui.channelInput:SetText(P.GetSyncChannelName())
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
		ui.memberPanel.emptyText:SetText("Clic gauche sur un personnage disponible pour l'ajouter")
	end

	-- L'état du groupe, qui change sans rafraîchir la fenêtre, est vérifié au clic par P.InviteTeam.
	ui.inviteButton:SetEnabled(InviteBlockedReason() == nil)
end

-- Sélectionne une équipe (ex. reçue par synchro via « Inviter l'équipe ») : le choix est
-- mémorisé pour ce personnage comme un clic, et la fenêtre rafraîchie si elle existe.
function P.SelectTeam(teamName)
	ChooseTeam(teamName)
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
