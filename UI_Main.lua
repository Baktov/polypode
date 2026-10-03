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

-- Fenêtre de saisie du nouveau nom d'une équipe (double-clic dans « Équipes »).
-- data = ancien nom. Une erreur (nom vide, déjà pris...) garde la fenêtre ouverte.
local RENAME_POPUP = "POLYPODE_RENAME_TEAM"

local function PopupEditBox(popup)
	return popup.GetEditBox and popup:GetEditBox() or popup.editBox
end

local function SubmitRename(popup, oldName)
	local ok, result = P.RenameTeam(oldName, PopupEditBox(popup):GetText())
	if not ok then
		UIErrorsFrame:AddMessage(result, 1, 0.1, 0.1)
		return true -- reste ouverte
	end
	UIErrorsFrame:AddMessage("Équipe « " .. oldName .. " » renommée en « " .. result .. " ».", 1, 0.82, 0)
	P.RefreshUI()
end

StaticPopupDialogs[RENAME_POPUP] = {
	text = "Nouveau nom de l'équipe « %s » :",
	button1 = "Renommer",
	button2 = "Annuler",
	hasEditBox = true,
	maxLetters = 32,
	OnShow = function(self, oldName)
		local editBox = PopupEditBox(self)
		editBox:SetText(oldName or "")
		editBox:HighlightText()
		editBox:SetFocus()
	end,
	OnAccept = SubmitRename,
	EditBoxOnEnterPressed = function(editBox, oldName)
		local popup = editBox:GetParent()
		if not SubmitRename(popup, oldName) then
			popup:Hide()
		end
	end,
	EditBoxOnEscapePressed = function(editBox)
		editBox:GetParent():Hide()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- Fenêtre de saisie d'un nouveau compte WoW nommé (menu Alt + clic d'un personnage).
-- data = clé du personnage à y ranger.
local NEW_ACCOUNT_POPUP = "POLYPODE_NEW_ACCOUNT"

local function SubmitNewAccount(popup, key)
	local label = strtrim(PopupEditBox(popup):GetText() or "")
	if label == "" then
		UIErrorsFrame:AddMessage("Nom de compte vide.", 1, 0.1, 0.1)
		return true -- reste ouverte
	end
	P.SetCharacterAccount(key, label)
	P.RefreshUI()
end

StaticPopupDialogs[NEW_ACCOUNT_POPUP] = {
	text = "Nom du compte WoW de %s :",
	button1 = "Créer",
	button2 = "Annuler",
	hasEditBox = true,
	maxLetters = 32,
	OnShow = function(self)
		local editBox = PopupEditBox(self)
		editBox:SetText("")
		editBox:SetFocus()
	end,
	OnAccept = SubmitNewAccount,
	EditBoxOnEnterPressed = function(editBox, key)
		local popup = editBox:GetParent()
		if not SubmitNewAccount(popup, key) then
			popup:Hide()
		end
	end,
	EditBoxOnEscapePressed = function(editBox)
		editBox:GetParent():Hide()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- Menu Alt + clic d'un personnage : le ranger dans un compte WoW nommé, en créer un, ou le
-- retirer de tout compte. Partagé avec les autres Polypode.
-- SUPPRESSION D'UN PERSONNAGE (Maj + clic dans « Personnages disponibles ») : confirmation
-- qui liste ce qui part avec lui (équipes, compte WoW nommé, données des addons compagnons,
-- P.DescribeCharacterData), puis P.RemoveCharacter (synchronisé avec les autres clients).
local REMOVE_CHARACTER_POPUP = "POLYPODE_REMOVE_CHARACTER"

StaticPopupDialogs[REMOVE_CHARACTER_POPUP] = {
	text = "Supprimer %s de Polypode ?%s\n\n(sur tous vos clients connectés ; il reviendra s'il se reconnecte avec Polypode)",
	button1 = DELETE or "Supprimer",
	button2 = CANCEL,
	OnAccept = function(_, key)
		P.RemoveCharacter(key)
		P.RefreshUI()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local function ConfirmRemoveCharacter(key)
	if key == P.GetCharKey() then
		UIErrorsFrame:AddMessage("Le personnage joué ne peut pas être supprimé.", 1, 0.1, 0.1)
		return
	end
	local lines = P.DescribeCharacterData(key)
	local details = #lines > 0 and ("\n\nSeront aussi supprimés :\n" .. table.concat(lines, "\n")) or ""
	StaticPopup_Show(REMOVE_CHARACTER_POPUP, P.GetDisplayName(key, true), details, key)
end

local function ShowAccountMenu(owner, key)
	local function IsCurrent(label)
		return (P.GetCharacterAccount(key) or "") == label
	end
	local function Assign(label)
		P.SetCharacterAccount(key, label)
		P.RefreshUI()
	end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle("Compte WoW de " .. P.GetDisplayName(key))
		root:CreateRadio("Aucun compte", IsCurrent, Assign, "")
		for _, label in ipairs(P.GetAccountLabels()) do
			root:CreateRadio(label, IsCurrent, Assign, label)
		end
		root:CreateButton("Nouveau compte...", function()
			StaticPopup_Show(NEW_ACCOUNT_POPUP, P.GetDisplayName(key), nil, key)
		end)
	end)
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
-- opts.onDoubleClick(data, mouseButton) : double-clic sur une ligne cliquable (WoW le déclenche à
-- la place du second clic : le premier clic passe par opts.onClick).
-- opts.decorate(row, data) : habillage supplémentaire d'une ligne, appelé à chaque affichage
-- (lignes recyclées : tout se recalcule ici).
-- opts.rowHeight : hauteur des lignes (défaut 20), ex. une rangée d'icônes posées par decorate.
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
		if not lines or #lines == 0 then -- pas d'infobulle pour cette ligne
			GameTooltip:Hide()
			return
		end
		for i, line in ipairs(lines) do
			if type(line) == "table" then -- { gauche, droite } : deux colonnes (P.LIST_TOOLTIP_COLUMNS)
				GameTooltip:AddDoubleLine(line[1] or "", line[2] or "", 1, 1, 1, 1, 1, 1)
			elseif i == 1 then
				GameTooltip:AddLine(line)
			else
				GameTooltip:AddLine(line, 1, 1, 1)
			end
		end
		P.ShowTooltip()
	end

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(opts.rowHeight or ROW_HEIGHT)
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
						P.ShowTooltip()
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
		if opts.decorate then
			opts.decorate(row, data)
		end

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
			if opts.onDoubleClick then
				row:SetScript("OnDoubleClick", function(_, mouseButton)
					opts.onDoubleClick(data, mouseButton)
				end)
			end
		end
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
	-- Place de la barre réservée à droite seulement quand elle est affichée.
	local topLeft = CreateAnchor("TOPLEFT", panel, "TOPLEFT", inset, -top)
	local behavior = ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar,
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
	-- Décalage du haut de la liste changé après coup (ex. bouton masqué au-dessus en mode solo) :
	-- l'ancre commune aux deux dispositions (avec / sans barre) est déplacée puis réappliquée.
	function panel.SetListTop(newTop)
		topLeft:SetOffsets(inset, -newTop)
		panel.emptyText:SetPoint("TOPLEFT", inset, -newTop)
		behavior.appliedAnchors = nil
		behavior:EvaluateVisibility(true)
	end
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
P.LIST_TOOLTIP_COLUMNS = true -- opts.tooltip peut renvoyer des lignes { gauche, droite } (0.51.4)
P.LIST_ROW_HEIGHT = true -- opts.rowHeight : hauteur des lignes réglable (0.56.0)
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
-- isFirst(key) (facultatif) : les clés pour lesquelles il est vrai passent en tête (ordre
-- alphabétique conservé dans chaque groupe) ; sa valeur est gardée dans item.first.
local function SortedKeyItems(set, isFirst)
	local keys, sortKeys, first = {}, {}, {}
	for key in pairs(set) do
		keys[#keys + 1] = key
		sortKeys[key] = AlphaKey(key)
		first[key] = isFirst and isFirst(key) or false
	end
	table.sort(keys, function(x, y)
		if first[x] ~= first[y] then
			return first[x]
		end
		if sortKeys[x] ~= sortKeys[y] then
			return sortKeys[x] < sortKeys[y]
		end
		return x < y
	end)
	local items = {}
	for i, key in ipairs(keys) do
		items[i] = { key = key, first = first[key] }
	end
	return items
end

-- REGROUPEMENT PAR COMPTE WOW (option P.charDb.groupByAccount) : WoW ne donne pas le nom du
-- compte WoW aux addons ; chaque personnage est rangé à la main (champ des options ou Alt + clic,
-- P.SetCharacterAccount). Les personnages sans compte vont dans « Compte non renseigné ».
-- Renvoie la clé de groupe et son libellé.
local NO_ACCOUNT_GROUP = "~none"

local function AccountGroup(key)
	local label = P.GetCharacterAccount(key)
	if label then
		return "m:" .. label, label
	end
	return NO_ACCOUNT_GROUP, "Compte non renseigné"
end

-- Clés des comptes affichés au dernier RefreshUI (bouton « Tout replier / déplier »).
local accountGroupKeys = {}

-- Vrai si tous les comptes affichés sont repliés.
local function AllAccountsCollapsed()
	for _, groupKey in ipairs(accountGroupKeys) do
		if not P.charDb.collapsedAccounts[groupKey] then
			return false
		end
	end
	return true
end

-- Ordre des groupes : comptes nommés (alphabétique), puis « Compte non renseigné ».
local function GroupRank(groupKey)
	return groupKey == NO_ACCOUNT_GROUP and 2 or 1
end

-- Vrai si le personnage est connecté : soi-même, un Polypode annoncé pendant la session
-- (P.IsCharacterOnline), ou un membre connecté de notre groupe (même sans Polypode).
local function IsConnected(key)
	if key == P.GetCharKey() or P.IsCharacterOnline(key) then
		return true
	end
	local entry = P.GetCharacter(key)
	if entry and entry.name then
		local name = P.GetTargetName(entry)
		if UnitInParty(name) or UnitInRaid(name) then
			local connected = UnitIsConnected(name)
			return not (issecretvalue and issecretvalue(connected)) and connected == true
		end
	end
	return false
end

-- Lignes d'infobulle d'un personnage : nom, rappels des clics (hints), puis ses équipes
-- (l'équipe sélectionnée en vert, « (leader) » là où il est leader).
local function CharacterTooltip(key, hints)
	local lines = { P.GetDisplayName(key, true) }
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
	local label = P.GetDisplayName(key, true)
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
-- Même règle « connecté » que « Personnages disponibles », pour les addons compagnons (Polypode Profil).
P.IsCharacterConnected = IsConnected

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
		P.ShowTooltip()
	end)
	editBox:SetScript("OnLeave", GameTooltip_Hide)
end

-- BOUTONS DE LA BARRE DE TITRE DES ADDONS COMPAGNONS (Polypode Photo, Polypode Quêtes) :
-- empilés de droite à gauche depuis la croix, dans l'ordre de leurs demandes. Créés dès que la
-- fenêtre existe (P.BuildUI la construit à la première ouverture).
local titleButtonSpecs, titleButtons = {}, {}

-- Vrai si le bouton d'un compagnon est affiché : spec.hideInSolo le masque en mode solo
-- (Polypode Quêtes, sans objet sans équipe).
function P.IsTitleButtonShown(spec)
	return not (spec.hideInSolo and P.IsSoloMode())
end

-- Place les boutons affichés de droite à gauche depuis la croix, sans trou pour les masqués.
local function LayoutTitleButtons()
	local previous = ui.closeButton
	for index, button in ipairs(titleButtons) do
		local shown = P.IsTitleButtonShown(titleButtonSpecs[index])
		button:SetShown(shown)
		if shown then
			button:ClearAllPoints()
			button:SetPoint("RIGHT", previous, "LEFT", -4, 0)
			previous = button
		end
	end
end

local function CreateTitleButton(spec)
	local button = CreateFrame("Button", nil, ui.frame, "UIPanelButtonTemplate")
	button:SetSize(spec.width or 60, 20)
	button:SetText(spec.text)
	if spec.rightClick then
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	end
	button:SetScript("OnClick", spec.onClick)
	if spec.tooltip then
		button:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			for i, line in ipairs(spec.tooltip) do
				if i == 1 then
					GameTooltip:AddLine(line)
				else
					GameTooltip:AddLine(line, 1, 1, 1, true)
				end
			end
			P.ShowTooltip()
		end)
		button:SetScript("OnLeave", GameTooltip_Hide)
	end
	if P.SkinButton then
		P.SkinButton(button)
	end
	titleButtons[#titleButtons + 1] = button
	LayoutTitleButtons()
	if spec.onCreate then
		spec.onCreate(button)
	end
end

-- Ajoute un bouton à la barre de titre de la fenêtre principale (point d'extension des addons
-- compagnons). spec = { text, width, onClick = fn(bouton, mouseButton), rightClick = clic droit
-- aussi, tooltip = { titre, lignes... }, onCreate = fn(bouton), hideInSolo = masqué en mode solo }.
function P.AddTitleButton(spec)
	titleButtonSpecs[#titleButtonSpecs + 1] = spec
	if ui.frame then
		CreateTitleButton(spec)
	end
	if ui.teamBar and P.RefreshTeamBar then
		P.RefreshTeamBar() -- barre déjà construite : sa colonne des modules suit (UI_TeamBar.lua)
	end
end

-- Boutons des addons compagnons, dans l'ordre de leurs demandes (lecture seule) : repris par la
-- colonne des modules de la barre flottante d'équipe (UI_TeamBar.lua).
function P.GetTitleButtonSpecs()
	return titleButtonSpecs
end

-- MODE SOLO (P.charDb.soloMode, case « Solo » de la barre de titre et panneau d'options) : un
-- seul personnage joué. Les cadres « Équipes » et « Personnages de l'équipe » sont masqués,
-- « Personnages disponibles » prend toute la largeur de la fenêtre, un peu plus étroite (largeur
-- gardée à part, P.db.mainFrame.soloWidth). Le personnage joué se glisse hors de la liste pour
-- devenir la barre flottante (UI_TeamBar.lua), avec la colonne des modules.

-- Clé de P.db.mainFrame où se garde la largeur de la fenêtre dans le mode courant.
local function WidthKey()
	return P.IsSoloMode() and "soloWidth" or "width"
end

-- Largeur des cadres : un tiers chacun, ou toute la largeur pour le seul cadre du mode solo.
local function LayoutPanels()
	local f = ui.frame
	if P.IsSoloMode() then
		ui.charPanel:SetWidth(math.max(f:GetWidth() - 2 * PANEL_MARGIN, 1))
		return
	end
	local width = (f:GetWidth() - 2 * PANEL_MARGIN - 2 * PANEL_GAP) / 3
	width = math.max(width, 1)
	ui.charPanel:SetWidth(width)
	ui.teamPanel:SetWidth(width)
end

-- Applique le mode courant à la fenêtre : cadres d'équipe, largeur, boutons des compagnons.
local function ApplySoloLayout()
	local solo = P.IsSoloMode()
	ui.frame.TitleText:SetText(solo and "Monopode" or "Polypode") -- un seul personnage : « Monopode »
	ui.teamPanel:SetShown(not solo)
	ui.memberPanel:SetShown(not solo)
	-- « Ajouter la cible » sert à composer des équipes : masqué en mode solo, la liste remonte.
	ui.addTargetButton:SetShown(not solo)
	ui.charPanel.SetListTop(solo and HEADER_HEIGHT or HEADER_HEIGHT + INPUT_HEIGHT)
	ui.frame:SetWidth(math.max(P.db.mainFrame[WidthKey()] or P.db.mainFrame.width, MIN_WIDTH))
	LayoutPanels()
	LayoutTitleButtons()
end

-- Active / désactive le mode solo pour ce personnage (case de la fenêtre et panneau d'options).
function P.SetSoloMode(enabled)
	P.charDb.soloMode = enabled and true or false
	if ui.frame then
		ApplySoloLayout()
	end
	P.RefreshUI() -- barre flottante, compagnons (Suivi, Quêtes) et case « Solo »
end

function P.BuildUI()
	if ui.frame then
		return
	end

	local f = CreateFrame("Frame", "PolypodeMainFrame", UIParent, "BackdropTemplate")
	f:SetSize(P.db.mainFrame.width, P.db.mainFrame.height)
	f:SetPoint("CENTER")
	-- Devant les barres d'action et la plupart des informations (strate MEDIUM par défaut),
	-- derrière les fenêtres des addons compagnons (DIALOG), ouvertes depuis celle-ci.
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
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
		P.ShowTooltip()
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

	-- Mode solo (à droite du canal), même réglage que la première case du panneau d'options.
	local soloCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
	soloCheck:SetSize(22, 22)
	soloCheck:SetPoint("LEFT", channelInput, "RIGHT", 6, 0)
	local soloText = soloCheck.Text or soloCheck.text
	if soloText then
		soloText:SetFontObject("GameFontNormalSmall")
		soloText:SetText("|cffff4040Solo|r")
	end
	soloCheck:SetScript("OnClick", function(self)
		P.SetSoloMode(self:GetChecked())
	end)
	soloCheck:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Mode solo")
		GameTooltip:AddLine("Pour jouer un seul personnage : la fenêtre ne garde que « Personnages "
			.. "disponibles », sans les équipes. Glissez votre personnage hors de la liste pour en "
			.. "faire une barre flottante, avec les boutons des modules.", 1, 1, 1, true)
		GameTooltip:AddLine("Réglage propre à ce personnage (aussi dans les options).", 0.8, 0.8, 0.8, true)
		P.ShowTooltip()
	end)
	soloCheck:SetScript("OnLeave", GameTooltip_Hide)

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
		P.db.mainFrame[WidthKey()], P.db.mainFrame.height = f:GetSize()
	end)

	-- Trois cadres côte à côte, chacun sur un tiers de la largeur : les deux premiers
	-- reçoivent leur largeur au redimensionnement, le dernier s'étire jusqu'au bord droit.
	-- 1. Personnages disponibles (roster alimenté par la sync).
	local charPanel = CreatePanel(f, "Personnages disponibles")
	charPanel:SetPoint("TOPLEFT", PANEL_MARGIN, PANEL_TOP)
	charPanel:SetPoint("BOTTOMLEFT", PANEL_MARGIN, PANEL_MARGIN)

	-- « Tout replier » / « Tout déplier » les comptes, à droite du titre (affiché seulement avec
	-- l'option « regrouper par compte », cf. RefreshUI).
	local collapseAllBtn = CreateFrame("Button", nil, charPanel, "UIPanelButtonTemplate")
	collapseAllBtn:SetSize(90, 18)
	collapseAllBtn:SetPoint("TOPRIGHT", -6, -4)
	collapseAllBtn:SetText("Tout replier")
	collapseAllBtn:SetScript("OnClick", function()
		local collapsed = P.charDb.collapsedAccounts
		if AllAccountsCollapsed() then
			wipe(collapsed)
		else
			for _, groupKey in ipairs(accountGroupKeys) do
				collapsed[groupKey] = true
			end
		end
		P.RefreshUI()
	end)
	collapseAllBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Tout replier / déplier")
		GameTooltip:AddLine("Replie tous les comptes pour ne voir que leurs en-têtes, ou les déplie tous.",
			1, 1, 1, true)
		P.ShowTooltip()
	end)
	collapseAllBtn:SetScript("OnLeave", GameTooltip_Hide)
	collapseAllBtn:Hide()

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
			.. "ensuite rejoindre une équipe (clic droit avec l'équipe sélectionnée) et être "
			.. "invité avec elle.", 1, 1, 1, true)
		GameTooltip:AddLine("Partagé avec vos autres Polypode connectés.", 1, 1, 1, true)
		P.ShowTooltip()
	end)
	addTargetBtn:SetScript("OnLeave", GameTooltip_Hide)

	-- Clic gauche : ajoute à l'équipe sélectionnée ; clic droit : l'en retire.
	-- Les membres de l'équipe sélectionnée sont surlignés.
	CreateScrollList(charPanel, function(data)
		if data.header then
			-- En-tête de compte (option « regrouper par compte ») : pliage, nom, connectés / total.
			return string.format("|cffffd200%s %s|r |cff999999(%d/%d)|r", data.collapsed and "+" or "-",
				data.label, data.online, #data.items)
		end
		return FormatCharacter(data)
	end, HEADER_HEIGHT + INPUT_HEIGHT, {
		onClick = function(data, mouseButton)
			if data.header then
				P.charDb.collapsedAccounts[data.groupKey] = not data.collapsed or nil
				P.RefreshUI()
				return
			end
			if IsShiftKeyDown() then
				ConfirmRemoveCharacter(data.key)
				return
			end
			if IsAltKeyDown() then
				ShowAccountMenu(charPanel, data.key)
				return
			end
			if P.IsSoloMode() then
				return -- pas d'équipe en mode solo
			end
			if not selectedTeam then
				if mouseButton == "RightButton" then
					-- Sans équipe sélectionnée : nouvelle équipe à son nom, avec lui pour leader.
					local teamName, err = P.CreateTeamWithLeader(data.key)
					if teamName then
						UIErrorsFrame:AddMessage("Équipe « " .. teamName .. " » créée, leader : "
							.. P.GetDisplayName(data.key) .. ".", 1, 0.82, 0)
						ChooseTeam(teamName)
					else
						UIErrorsFrame:AddMessage(err, 1, 0.1, 0.1)
					end
				else
					UIErrorsFrame:AddMessage("Sélectionnez d'abord une équipe (ou clic droit pour en "
						.. "créer une avec ce personnage pour leader).", 1, 0.1, 0.1)
				end
				return
			end
			-- Clic droit = ajouter (comme la création d'équipe au clic droit), clic gauche = retirer.
			if mouseButton == "RightButton" then
				P.AddTeamMember(selectedTeam, data.key)
			else
				P.RemoveTeamMember(selectedTeam, data.key)
			end
			P.RefreshUI()
		end,
		isSelected = function(data)
			if data.header or P.IsSoloMode() then
				return false
			end
			local members = P.GetTeamMembers(selectedTeam)
			return members and members[data.key] or false
		end,
		tooltip = function(data)
			if data.header then
				return { data.label, data.online .. " connecté(s) sur " .. #data.items,
					"Clic : " .. (data.collapsed and "déplier" or "replier") }
			end
			local presence = data.first and "|cff40ff40Connecté|r" or "|cff999999Déconnecté (ou pas vu cette session)|r"
			local account = "Compte WoW : " .. (P.GetCharacterAccount(data.key) or "non renseigné")
			local hint = "Alt + clic : ranger dans un compte WoW|nMaj + clic : supprimer ce personnage et ses données"
			if P.IsSoloMode() then
				local lines = { P.GetDisplayName(data.key, true), presence, account }
				if data.key == P.GetCharKey() then
					lines[#lines + 1] = "Glisser : afficher en barre flottante"
				end
				lines[#lines + 1] = hint
				return lines
			end
			if not selectedTeam then
				return CharacterTooltip(data.key, { presence, account,
					"Sélectionnez d'abord une équipe pour y ajouter ce personnage.",
					"Clic droit : créer une équipe à son nom, avec lui pour leader", hint })
			end
			return CharacterTooltip(data.key, {
				presence,
				account,
				"Clic droit : ajouter à l'équipe « " .. selectedTeam .. " »",
				"Clic gauche : retirer de l'équipe « " .. selectedTeam .. " »",
				hint,
			})
		end,
		-- Personnages déconnectés légèrement grisés (connectés en tête, cf. RefreshUI).
		decorate = function(row, data)
			row:SetAlpha(data.first and 1 or 0.55)
		end,
		-- Mode solo : le personnage joué, glissé hors de la liste, devient la barre flottante.
		onDragStart = function(data)
			if P.IsSoloMode() and data.key == P.GetCharKey() then
				P.StartTeamBarDrag()
			end
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
	-- Maj + clic gauche : supprime l'équipe (synchronisé) ; double-clic gauche : la renomme.
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
			local created = P.GetTeamCreated(data.name)
			return {
				data.name,
				created and ("|cff999999Créée le " .. date("%d/%m/%Y à %H:%M", created) .. "|r")
					or "|cff999999Date de création inconnue (équipe plus ancienne)|r",
				"Clic gauche : sélectionner l'équipe",
				"Clic droit : désélectionner",
				"Double-clic : renommer l'équipe",
				"Maj + clic gauche : supprimer l'équipe",
				"Glisser : sélectionner et afficher en barre flottante",
			}
		end,
		-- Double-clic gauche : renommer (le premier clic a sélectionné l'équipe). Double-clic
		-- droit : second clic droit ordinaire (désélection).
		onDoubleClick = function(data, mouseButton)
			if mouseButton == "LeftButton" then
				StaticPopup_Show(RENAME_POPUP, data.name, nil, data.name)
			else
				ChooseTeam(nil)
			end
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
		P.ShowTooltip()
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

	ui.frame = f
	ui.title = title
	ui.closeButton = closeBtn
	ui.optionsButton = optionsBtn
	ui.channelLabel = channelLabel
	ui.channelInput = channelInput
	ui.soloCheck = soloCheck
	ui.resizeGrip = grip
	ui.charPanel = charPanel
	ui.collapseAccountsButton = collapseAllBtn
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
		P.SkinButton(collapseAllBtn)
		P.SkinButton(optionsBtn)
		P.SkinEditBox(channelInput)
		P.SkinCheckBox(soloCheck)
	end
	-- Libellé « Solo » écarté de la case (après le skin : EllesmereUI le collait à son cadre).
	local soloLabel = soloCheck.Text or soloCheck.text
	if soloLabel then
		soloLabel:ClearAllPoints()
		soloLabel:SetPoint("LEFT", soloCheck, "RIGHT", 5, 0)
	end

	-- Boutons des addons compagnons demandés avant la construction de la fenêtre.
	for _, spec in ipairs(titleButtonSpecs) do
		CreateTitleButton(spec)
	end

	f:SetScript("OnSizeChanged", LayoutPanels)
	ApplySoloLayout()
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
	-- Fenêtre des quêtes de l'équipe (addon compagnon Polypode Quêtes), si elle est ouverte.
	if P.RefreshTeamQuests then
		P.RefreshTeamQuests()
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
	ui.soloCheck:SetChecked(P.IsSoloMode()) -- peut avoir changé dans les options

	-- Connectés en tête, puis déconnectés ; ordre alphabétique dans chaque groupe. Avec
	-- l'option, un en-tête repliable par compte précède ses personnages.
	local characters = SortedKeyItems(P.GetRoster(), IsConnected)
	if P.charDb.groupByAccount then
		local groups, order = {}, {}
		for _, item in ipairs(characters) do
			local groupKey, label = AccountGroup(item.key)
			if not groups[groupKey] then
				groups[groupKey] = { header = true, groupKey = groupKey, label = label, items = {}, online = 0 }
				order[#order + 1] = groups[groupKey]
			end
			local group = groups[groupKey]
			group.items[#group.items + 1] = item
			group.online = group.online + (item.first and 1 or 0)
		end
		table.sort(order, function(a, b)
			local rankA, rankB = GroupRank(a.groupKey), GroupRank(b.groupKey)
			if rankA ~= rankB then
				return rankA < rankB
			end
			return a.label < b.label
		end)
		characters = {}
		wipe(accountGroupKeys)
		for _, group in ipairs(order) do
			accountGroupKeys[#accountGroupKeys + 1] = group.groupKey
			group.collapsed = P.charDb.collapsedAccounts[group.groupKey] or false
			group.first = true -- en-tête jamais estompé
			characters[#characters + 1] = group
			if not group.collapsed then
				for _, item in ipairs(group.items) do
					characters[#characters + 1] = item
				end
			end
		end
	end
	SetListData(ui.charPanel, characters)
	-- Bouton « Tout replier » : seulement regroupé par compte ; le titre lui laisse la place.
	local grouped = P.charDb.groupByAccount and #accountGroupKeys > 0
	ui.collapseAccountsButton:SetShown(grouped)
	ui.collapseAccountsButton:SetText(AllAccountsCollapsed() and "Tout déplier" or "Tout replier")
	ui.charPanel.header:SetPoint("RIGHT", grouped and ui.collapseAccountsButton or ui.charPanel,
		grouped and "LEFT" or "RIGHT", grouped and -6 or -10, 0)

	local teams = {}
	for name in pairs(P.GetTeams()) do
		teams[#teams + 1] = { name = name }
	end
	table.sort(teams, function(a, b)
		return a.name < b.name
	end)
	SetListData(ui.teamPanel, teams)

	local members = P.GetTeamMembers(selectedTeam)
	-- Leader toujours en tête, puis les autres membres par ordre alphabétique.
	local leader = P.GetTeamLeader(selectedTeam)
	SetListData(ui.memberPanel, SortedKeyItems(members or {}, function(key)
		return key == leader
	end))
	if not members then
		ui.memberPanel.emptyText:SetText("Sélectionnez une équipe")
	else
		ui.memberPanel.emptyText:SetText("Clic droit sur un personnage disponible pour l'ajouter")
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
