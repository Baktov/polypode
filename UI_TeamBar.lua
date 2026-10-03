-- Polypode: UI_TeamBar — barre flottante de l'équipe sélectionnée (sortie de la fenêtre par glisser)

local P = Polypode

-- Une équipe glissée hors du cadre « Équipes » de la fenêtre principale devient la sélection
-- et s'affiche dans une petite barre posée où on la lâche (P.StartTeamBarDrag). La barre
-- montre toujours l'équipe sélectionnée pour ce personnage : clic gauche = inviter l'équipe
-- (P.InviteSelectedTeam, comme le bouton de la fenêtre), clic droit = déplier / replier
-- la liste défilante de ses membres, glisser = déplacer, poignée = redimensionner (largeur,
-- et hauteur de la liste dépliée), Alt + clic = figer / libérer (position et taille),
-- croix = masquer. État par personnage (chaque fenêtre de multibox a son écran) dans
-- P.charDb.teamBar : shown, expanded, locked, position, width, listHeight.
--
-- BARRE RÉDUITE (option P.charDb.teamBar.compact) : seule reste l'icône Polypode, dans un cadre de
-- la taille d'un bouton de module ; nom, pliage, croix, cadenas, poignée et liste masqués. Les
-- boutons des modules sont alors dessous en colonne, ou à droite en rangée (moduleSide
-- "horizontal" ; barre normale : rangée au-dessus). Icône : clic = fenêtre, clic droit = options,
-- Alt + clic = figer / libérer, glisser = déplacer.
--
-- MODE SOLO (P.IsSoloMode, UI_Main.lua) : la même barre montre le personnage joué, sorti en
-- glissant sa ligne de « Personnages disponibles » ; affichage mémorisé à part (soloShown),
-- position, taille et options communes. Pas d'invitation ni de partage de disposition.

local BAR_WIDTH, BAR_HEIGHT = 180, 24
local MIN_WIDTH, MAX_WIDTH = 100, 600
local ROW_HEIGHT = 20 -- hauteur d'une ligne de P.CreateScrollList (UI_Main.lua)
local LIST_PADDING = 8 -- marge haute et basse de la liste dans son cadre
local MAX_VISIBLE_ROWS = 8 -- hauteur automatique : au-delà, la liste défile
local MIN_LIST_HEIGHT, MAX_LIST_HEIGHT = ROW_HEIGHT + 2 * LIST_PADDING, 600

local bar, listPanel, toggleIcon, lockIcon, grip, closeButton, iconButton
local listAbove -- liste dépliée au-dessus de la barre (trop près du bas de l'écran)

local function Clamp(value, low, high)
	return math.max(low, math.min(high, value))
end

-- Clé de P.charDb.teamBar qui mémorise l'affichage de la barre dans le mode courant.
local function ShownKey()
	return P.IsSoloMode() and "soloShown" or "shown"
end

-- Clé nom-royaume comparable : les royaumes renvoyés par UnitName n'ont pas d'espace
-- (« Chantséternels »), ceux de GetRealmName (clés du roster) en ont.
local function NormalizeKey(key)
	return (key:gsub("%s", ""))
end

-- Durée écoulée depuis un instant GetTime(), en clair.
local function FormatAgo(since)
	local minutes = math.floor((GetTime() - since) / 60)
	if minutes < 1 then
		return "à l'instant"
	elseif minutes < 60 then
		return "il y a " .. minutes .. " min"
	end
	return "il y a " .. math.floor(minutes / 60) .. " h"
end

-- Lignes d'infobulle d'un personnage non groupé, à la manière de la liste d'amis : niveau,
-- race, classe et spécialisation, guilde, zone, niveau d'objet, présence. Infos envoyées par
-- son Polypode (STATUS, Sync.lua) ; à défaut, ce que le roster en sait.
local function StatusLines(key)
	local entry = P.db.roster[key] or {}
	local status = P.GetCharacterStatus(key)
	local lines = {}

	local identity = {}
	local level = status and status.level or entry.level
	if level then
		identity[#identity + 1] = "Niveau " .. level
	end
	if status and status.race then
		identity[#identity + 1] = status.race
	end
	if entry.class then
		local className = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[entry.class] or entry.class
		local color = C_ClassColor and C_ClassColor.GetClassColor(entry.class)
		identity[#identity + 1] = color and color:WrapTextInColorCode(className) or className
	end
	if status and status.spec then
		identity[#identity + 1] = "(" .. status.spec .. ")"
	end
	if #identity > 0 then
		lines[#lines + 1] = table.concat(identity, " ")
	end

	if status then
		if status.guild then
			lines[#lines + 1] = "|cff40ff40<" .. status.guild .. ">|r"
		end
		if status.zone then
			lines[#lines + 1] = "Zone : " .. status.zone
		end
		if status.ilvl and status.ilvl > 0 then
			lines[#lines + 1] = "Niveau d'objet : " .. status.ilvl
		end
		if status.durability then
			local low = status.durability < P.charDb.teamBar.durabilityThreshold
			lines[#lines + 1] = "Durabilité : " .. (low and "|cffff4040" or "") .. status.durability .. " %"
				.. (low and "|r" or "")
		end
		if P.IsCharacterOnline(key) then
			lines[#lines + 1] = "|cff40ff40En ligne|r |cff999999(infos " .. FormatAgo(status.received) .. ")|r"
		else
			lines[#lines + 1] = "|cff999999Hors ligne (dernières infos " .. FormatAgo(status.received) .. ")|r"
		end
	else
		lines[#lines + 1] = "|cff999999Pas encore d'infos de son Polypode cette session|r"
		if entry.lastSeen then
			lines[#lines + 1] = "|cff999999Vu le " .. date("%d/%m à %H:%M", entry.lastSeen) .. "|r"
		end
	end

	lines[#lines + 1] = "|cff999999Infobulle complète une fois groupé|r"
	return lines
end

-- Ligne d'un membre avec détails (option P.charDb.teamBar.details) : niveau (doré), % d'XP du
-- niveau en cours (gris, absent au niveau maximum), niveau d'objet (bleu), puis le nom court
-- en couleur de classe (le royaume et la classe sont dans l'infobulle) et [leader].
-- Valeurs inconnues (pas encore d'état reçu du Polypode du personnage) : « ? ».
local function FormatDetailed(data)
	local key = data.key
	local entry = P.db.roster[key] or {}
	local status = P.GetCharacterStatus(key)

	local parts = { "|cffffd200" .. ((status and status.level) or entry.level or "?") .. "|r" }
	if status and status.xp then
		parts[#parts + 1] = "|cff999999" .. status.xp .. "%|r"
	end
	local ilvl = status and status.ilvl
	parts[#parts + 1] = "|cff66bbff" .. ((ilvl and ilvl > 0) and ilvl or "?") .. "|r"

	local name = P.GetDisplayName(key)
	local color = entry.class and C_ClassColor and C_ClassColor.GetClassColor(entry.class)
	parts[#parts + 1] = color and color:WrapTextInColorCode(name) or name
	if not P.IsSoloMode() and P.GetTeamLeader(P.GetSelectedTeam()) == key then
		parts[#parts + 1] = "|cffffd200[leader]|r"
	end
	return table.concat(parts, " ")
end

-- Unité du groupe (player, partyN, raidN) correspondant à un personnage du roster, ou nil
-- s'il n'est pas groupé avec nous. Un nom rendu secret par WoW (issecretvalue) est ignoré.
local function FindGroupUnit(key)
	local wanted = NormalizeKey(key)
	local units = { "player" }
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			units[#units + 1] = "raid" .. i
		end
	else
		for i = 1, GetNumSubgroupMembers() do
			units[#units + 1] = "party" .. i
		end
	end
	for _, unit in ipairs(units) do
		local name, realm = P.UnitNameParts(unit)
		if name and not (issecretvalue and (issecretvalue(name) or issecretvalue(realm))) then
			if NormalizeKey(name .. "-" .. (realm or GetRealmName())) == wanted then
				return unit
			end
		end
	end
end

-- Mémorise la position de la barre pour ce personnage.
local function SavePosition()
	local point, _, relativePoint, x, y = bar:GetPoint(1)
	local state = P.charDb.teamBar
	state.point, state.relativePoint, state.x, state.y = point, relativePoint, x, y
end

-- Replace la barre à sa position mémorisée (centre de l'écran par défaut).
local function RestorePosition()
	local state = P.charDb.teamBar
	bar:ClearAllPoints()
	if state.point then
		bar:SetPoint(state.point, UIParent, state.relativePoint, state.x, state.y)
	else
		bar:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
	end
end

-- Hauteur de la liste : celle choisie à la poignée, sinon MAX_VISIBLE_ROWS lignes au plus
-- (puis défilement). Dépliée sous la barre, ou au-dessus si la barre est trop près du bas de
-- l'écran.
local function LayoutList(count)
	local height = P.charDb.teamBar.listHeight
	if not height then
		local rows = math.min(math.max(count, 1), MAX_VISIBLE_ROWS)
		height = rows * ROW_HEIGHT + 2 * LIST_PADDING
	end
	listPanel:SetHeight(height)
	listPanel:ClearAllPoints()
	local bottom = bar:GetBottom()
	listAbove = bottom ~= nil and bottom < height
	if listAbove then
		listPanel:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 2)
		listPanel:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 2)
	else
		listPanel:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -2)
		listPanel:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -2)
	end
end

-- Poignée au coin extérieur : bas-droit de la barre (pliée), de la liste (dépliée dessous),
-- ou haut-droit de la liste (dépliée au-dessus). Masquée quand la barre est figée.
local function LayoutGrip()
	local state = P.charDb.teamBar
	grip:ClearAllPoints()
	if not state.expanded then
		grip:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 2)
	elseif listAbove then
		grip:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -2, -2)
	else
		grip:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -2, 2)
	end
	grip:SetShown(not state.locked)
end

-- Redimensionnement à la poignée, suivi du curseur image par image : la barre est d'abord
-- ancrée par son coin haut-gauche pour que la largeur croisse vers la droite ; la hauteur
-- de la liste suit le curseur vers l'extérieur (bas, ou haut si elle est au-dessus).
local function StartResize()
	local left, top = bar:GetLeft(), bar:GetTop()
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
	local scale = bar:GetEffectiveScale()
	local startX, startY = GetCursorPosition()
	local startWidth, startHeight = bar:GetWidth(), listPanel:GetHeight()
	local expanded, above = P.charDb.teamBar.expanded, listAbove
	grip:SetScript("OnUpdate", function()
		local x, y = GetCursorPosition()
		local dx, dy = (x - startX) / scale, (y - startY) / scale
		bar:SetWidth(Clamp(startWidth + dx, MIN_WIDTH, MAX_WIDTH))
		if expanded then
			listPanel:SetHeight(Clamp(startHeight + (above and dy or -dy), MIN_LIST_HEIGHT, MAX_LIST_HEIGHT))
		end
	end)
end

-- Fin du redimensionnement : taille et position mémorisées.
local function StopResize()
	if not grip:GetScript("OnUpdate") then
		return
	end
	grip:SetScript("OnUpdate", nil)
	local state = P.charDb.teamBar
	state.width = bar:GetWidth()
	if state.expanded then
		state.listHeight = listPanel:GetHeight()
	end
	SavePosition()
	P.RefreshTeamBar()
end

-- Alt + clic : fige (plus de déplacement ni de redimensionnement) ou libère la barre.
local function ToggleLocked()
	local state = P.charDb.teamBar
	state.locked = not state.locked
	UIErrorsFrame:AddMessage(state.locked and "Barre d'équipe figée." or "Barre d'équipe libérée.", 1, 0.82, 0)
	P.RefreshTeamBar()
end

-- ÉTAT DES MEMBRES : pour chaque ligne, un libellé à droite (hors groupe, hors ligne,
-- déconnecté, mort, loin) et, pour un membre groupé, une fine barre de vie au bas de la
-- ligne. Lu directement sur l'unité du groupe (FindGroupUnit), rafraîchi 3 fois par seconde
-- tant que la liste est dépliée. Depuis WoW 12, certaines valeurs (vie en combat...) peuvent
-- être secrètes : la vie ne passe que par la barre (SetValue les accepte), les booléens
-- secrets sont traités comme inconnus.
local STATE_REFRESH = 0.3 -- secondes entre deux rafraîchissements de l'état des lignes

-- Valeur utilisable par l'addon, ou nil si WoW l'a rendue secrète.
local function Known(value)
	if issecretvalue and issecretvalue(value) then
		return nil
	end
	return value
end

-- Libellé d'état (couleur incluse) et opacité de la ligne d'un membre ; unit : son unité de
-- groupe, ou nil s'il n'est pas groupé.
local function MemberState(key, unit)
	if not unit then
		if P.IsCharacterOnline(key) then
			return "|cff999999hors groupe|r", 1
		end
		return "|cff777777hors ligne|r", 0.5
	end
	if Known(UnitIsConnected(unit)) == false then
		return "|cff777777déconnecté|r", 0.5
	end
	if Known(UnitIsDeadOrGhost(unit)) then
		return "|cffff4040mort|r", 1
	end
	if unit ~= "player" then
		local inRange, checked = UnitInRange(unit)
		if Known(checked) and Known(inRange) == false then
			return "|cffff9900loin|r", 0.7
		end
	end
	return "", 1
end

-- Habillage d'une ligne (opts.decorate de P.CreateScrollList) : libellé d'état à droite du
-- nom, barre de vie en bas pour un membre groupé et connecté (option P.charDb.teamBar.healthBar).
local function DecorateRow(row, data)
	if not row.stateText then
		row.stateText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		row.stateText:SetPoint("RIGHT", -4, 0)
		row.stateText:SetJustifyH("RIGHT")
		row.text:SetPoint("RIGHT", row.stateText, "LEFT", -4, 0)

		row.health = CreateFrame("StatusBar", nil, row)
		row.health:SetPoint("BOTTOMLEFT", 4, 1)
		row.health:SetPoint("BOTTOMRIGHT", -4, 1)
		row.health:SetHeight(2)
		row.health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
		row.health:SetStatusBarColor(0.2, 0.9, 0.2)

		-- Voile rouge clignotant (durabilité faible), sous le texte.
		row.flash = row:CreateTexture(nil, "ARTWORK")
		row.flash:SetAllPoints()
		row.flash:SetColorTexture(1, 0.1, 0.1, 0.35)
		row.flash:Hide()
		row.flashAnim = row.flash:CreateAnimationGroup()
		row.flashAnim:SetLooping("BOUNCE")
		local fade = row.flashAnim:CreateAnimation("Alpha")
		fade:SetFromAlpha(1)
		fade:SetToAlpha(0.1)
		fade:SetDuration(0.6)
	end

	local unit = FindGroupUnit(data.key)
	local label, alpha = MemberState(data.key, unit)
	row.stateText:SetText(label)
	row:SetAlpha(alpha)

	if P.charDb.teamBar.healthBar and unit and Known(UnitIsConnected(unit)) ~= false then
		row.health:SetMinMaxValues(0, UnitHealthMax(unit))
		row.health:SetValue(UnitHealth(unit))
		row.health:Show()
	else
		row.health:Hide()
	end

	-- Durabilité sous le seuil (option) : la ligne clignote. Durabilité envoyée par le Polypode
	-- du personnage (STATUS), lue en direct pour le personnage joué.
	local settings = P.charDb.teamBar
	local status = P.GetCharacterStatus(data.key)
	if settings.durabilityAlert and status and status.durability
		and status.durability < settings.durabilityThreshold then
		row.flash:Show()
		if not row.flashAnim:IsPlaying() then
			row.flashAnim:Play()
		end
	else
		row.flashAnim:Stop()
		row.flash:Hide()
	end
end

-- Maj + clic : envoie la disposition de la barre (position, largeur, hauteur de la liste,
-- pliage) aux membres de l'équipe connectés, en % de la taille de l'écran pour s'adapter à
-- des fenêtres de tailles différentes (P.SyncTeamBarLayout, Sync.lua).
local function ShareLayout()
	local team = P.GetSelectedTeam()
	if not team then
		UIErrorsFrame:AddMessage("Sélectionnez d'abord une équipe.", 1, 0.1, 0.1)
		return
	end
	local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
	local state = P.charDb.teamBar
	local sent = P.SyncTeamBarLayout(team, {
		left = bar:GetLeft() / screenWidth * 100,
		top = bar:GetTop() / screenHeight * 100,
		width = bar:GetWidth() / screenWidth * 100,
		listHeight = state.listHeight and state.listHeight / screenHeight * 100,
		expanded = state.expanded,
	})
	if sent > 0 then
		UIErrorsFrame:AddMessage("Position de la barre envoyée à " .. sent .. " personnage(s) de l'équipe.", 1, 0.82, 0)
	else
		UIErrorsFrame:AddMessage("Aucun autre personnage de l'équipe connecté.", 1, 0.1, 0.1)
	end
end

local function ShowBarTooltip(self)
	if bar and bar.dragging then
		return -- pas d'infobulle pendant le déplacement de la barre
	end
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	local solo = P.IsSoloMode()
	if solo then
		GameTooltip:AddLine(P.GetDisplayName(P.GetCharKey()) .. " |cffff4040(mode solo)|r")
		GameTooltip:AddLine("Clic droit : déplier / replier la ligne du personnage", 1, 1, 1)
	else
		GameTooltip:AddLine(P.GetSelectedTeam() or "Aucune équipe sélectionnée")
		GameTooltip:AddLine("Clic gauche : inviter l'équipe (comme le bouton « Inviter l'équipe »)", 1, 1, 1)
		local reason = P.GetInviteBlockedReason(P.GetSelectedTeam())
		if reason then
			GameTooltip:AddLine(reason, 1, 0.1, 0.1, true)
		end
		GameTooltip:AddLine("Clic droit : déplier / replier la liste des personnages", 1, 1, 1)
	end
	if P.charDb.teamBar.locked then
		GameTooltip:AddLine("Barre figée (position et taille)", 1, 0.82, 0)
		GameTooltip:AddLine("Alt + clic : libérer", 1, 1, 1)
	else
		GameTooltip:AddLine("Glisser : déplacer la barre", 1, 1, 1)
		GameTooltip:AddLine("Poignée du coin : redimensionner", 1, 1, 1)
		GameTooltip:AddLine("Alt + clic : figer la position et la taille", 1, 1, 1)
	end
	if solo then
		GameTooltip:AddLine("Croix : masquer (glisser votre personnage hors de la fenêtre Polypode "
			.. "pour la réafficher)", 1, 1, 1, true)
	else
		GameTooltip:AddLine("Maj + clic : envoyer cette position et cette taille aux personnages de "
			.. "l'équipe dont la barre est masquée", 1, 1, 1, true)
		GameTooltip:AddLine("Croix : masquer (glisser une équipe hors de la fenêtre Polypode pour "
			.. "la réafficher)", 1, 1, 1, true)
	end
	P.ShowTooltip()
end

-- BOUTONS DES MODULES : les boutons des addons compagnons (P.AddTitleButton, UI_Main.lua) repris en
-- colonne contre la barre, à gauche (défaut) ou à droite (P.charDb.teamBar.moduleButtons /
-- moduleSide, panneau d'options). Discrets : trois premières lettres du libellé, petite police ;
-- même clic (le bouton de la colonne est passé à spec.onClick) et même infobulle que dans la
-- fenêtre. spec.onCreate n'est pas rappelé (il référence le bouton de la fenêtre).
local MODULE_WIDTH, MODULE_HEIGHT, MODULE_GAP = 34, 16, 2
local moduleColumn
local moduleButtons = {}
local moduleTooltipAnchor = "ANCHOR_LEFT" -- côté des infobulles, opposé à la barre (LayoutModuleButtons)

-- Trois premiers caractères (UTF-8 entiers : « Quê » pour « Quêtes »).
local function ShortLabel(text)
	local chars = {}
	for char in tostring(text or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		chars[#chars + 1] = char
		if #chars == 3 then
			break
		end
	end
	return table.concat(chars)
end

local function CreateModuleButton(spec)
	local button = CreateFrame("Button", nil, moduleColumn, "UIPanelButtonTemplate")
	button:SetSize(MODULE_WIDTH, MODULE_HEIGHT)
	button:SetNormalFontObject("GameFontNormalSmall")
	button:SetHighlightFontObject("GameFontHighlightSmall")
	button:SetDisabledFontObject("GameFontDisableSmall")
	button:SetText(ShortLabel(spec.text))
	if spec.rightClick then
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	end
	button:SetScript("OnClick", spec.onClick)
	if spec.tooltip then
		button:SetScript("OnEnter", function(self)
			-- Infobulle du côté opposé à la barre.
			GameTooltip:SetOwner(self, moduleTooltipAnchor)
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
	return button
end

-- Place (et crée au besoin) les boutons selon les options : colonne à gauche ou à droite de la
-- barre, rangée au-dessus (horizontal) ; barre réduite : colonne dessous, ou rangée à droite
-- (horizontal). La zone gardée à l'écran par SetClampedToScreen les inclut.
local function LayoutModuleButtons()
	local state = P.charDb.teamBar
	local specs = P.GetTitleButtonSpecs and P.GetTitleButtonSpecs() or {}
	for index = #moduleButtons + 1, #specs do
		moduleButtons[index] = CreateModuleButton(specs[index])
	end
	-- Boutons masqués dans le mode courant (spec.hideInSolo, P.IsTitleButtonShown) : retirés.
	local shown = {}
	for index, button in ipairs(moduleButtons) do
		local visible = P.IsTitleButtonShown(specs[index])
		button:SetShown(visible)
		if visible then
			shown[#shown + 1] = button
		end
	end
	if not state.moduleButtons or #shown == 0 then
		moduleColumn:Hide()
		bar:SetClampRectInsets(0, 0, 0, 0)
		return
	end
	local horizontal = state.moduleSide == "horizontal"
	local length = #shown * ((horizontal and MODULE_WIDTH or MODULE_HEIGHT) + MODULE_GAP) - MODULE_GAP
	moduleColumn:ClearAllPoints()
	if horizontal then
		moduleColumn:SetSize(length, MODULE_HEIGHT)
	else
		moduleColumn:SetSize(MODULE_WIDTH, length)
	end
	if state.compact and horizontal then
		moduleColumn:SetPoint("LEFT", bar, "RIGHT", 2, 0)
		bar:SetClampRectInsets(0, length + 2, 0, 0)
		moduleTooltipAnchor = "ANCHOR_BOTTOM"
	elseif state.compact then
		moduleColumn:SetPoint("TOP", bar, "BOTTOM", 0, -2)
		bar:SetClampRectInsets(0, 0, 0, -(length + 2))
		moduleTooltipAnchor = "ANCHOR_RIGHT"
	elseif horizontal then
		moduleColumn:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 2)
		bar:SetClampRectInsets(0, 0, MODULE_HEIGHT + 2, 0)
		moduleTooltipAnchor = "ANCHOR_TOP"
	elseif state.moduleSide == "right" then
		moduleColumn:SetPoint("TOPLEFT", bar, "TOPRIGHT", 2, 0)
		bar:SetClampRectInsets(0, MODULE_WIDTH + 2, 0, 0)
		moduleTooltipAnchor = "ANCHOR_RIGHT"
	else
		moduleColumn:SetPoint("TOPRIGHT", bar, "TOPLEFT", -2, 0)
		bar:SetClampRectInsets(-(MODULE_WIDTH + 2), 0, 0, 0)
		moduleTooltipAnchor = "ANCHOR_LEFT"
	end
	for index, button in ipairs(shown) do
		button:ClearAllPoints()
		local offset = (index - 1) * ((horizontal and MODULE_WIDTH or MODULE_HEIGHT) + MODULE_GAP)
		if horizontal then
			button:SetPoint("LEFT", moduleColumn, "LEFT", offset, 0)
		else
			button:SetPoint("TOP", moduleColumn, "TOP", 0, -offset)
		end
	end
	moduleColumn:Show()
end

local function Build()
	bar = P.CreatePanel(UIParent, "")
	bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
	bar:SetMovable(true)
	bar:SetClampedToScreen(true)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function(self)
		if not P.charDb.teamBar.locked then
			self.dragging = true
			GameTooltip:Hide() -- l'infobulle suivrait la barre et masquerait l'endroit visé
			self:StartMoving()
		end
	end)
	bar:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		-- Fin du glisser : l'indicateur est effacé à l'image suivante (OnMouseUp de la barre, qui
		-- le lit, passe avant ; un glisser depuis l'icône ne déclenche pas cet OnMouseUp, et
		-- l'indicateur resté levé masquait ensuite les infobulles de la barre et de l'icône).
		C_Timer.After(0, function()
			self.dragging = nil
		end)
		SavePosition()
		P.RefreshTeamBar() -- sens de dépliement selon la nouvelle position
	end)
	bar:SetScript("OnMouseUp", function(self, mouseButton)
		-- Le relâchement qui termine un déplacement n'est pas un clic.
		local dragged = self.dragging
		self.dragging = nil
		if P.charDb.teamBar.compact and not IsAltKeyDown() then
			return -- barre réduite : l'icône porte les actions (pas d'invitation ni de liste)
		end
		if mouseButton == "LeftButton" and not dragged then
			if IsAltKeyDown() then
				ToggleLocked()
			elseif P.IsSoloMode() then
				return -- pas d'équipe à inviter ni de disposition à partager
			elseif IsShiftKeyDown() then
				ShareLayout()
			else
				P.InviteSelectedTeam() -- même action que le bouton de la fenêtre (Commands.lua)
			end
		elseif mouseButton == "RightButton" then
			local state = P.charDb.teamBar
			state.expanded = not state.expanded
			P.RefreshTeamBar()
		end
	end)
	bar:SetScript("OnEnter", ShowBarTooltip)
	bar:SetScript("OnLeave", GameTooltip_Hide)
	bar:Hide()

	-- Icône Polypode (celle du bouton de minimap), tout à gauche : ouvre / ferme la fenêtre
	-- principale. Glisser depuis l'icône déplace la barre comme ailleurs.
	local iconBtn = CreateFrame("Button", nil, bar)
	iconBtn:SetSize(18, 18)
	iconBtn:SetPoint("LEFT", 4, 0)
	iconBtn:SetNormalTexture(P.ICON)
	iconBtn:GetNormalTexture():SetTexCoord(0.07, 0.93, 0.07, 0.93) -- rogne le liseré
	iconBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	iconBtn:RegisterForDrag("LeftButton")
	iconBtn:SetScript("OnDragStart", function()
		bar:GetScript("OnDragStart")(bar)
	end)
	iconBtn:SetScript("OnDragStop", function()
		bar:GetScript("OnDragStop")(bar)
	end)
	-- Clic gauche : fenêtre Polypode ; clic droit : petite fenêtre d'options (UI_OptionsPopup.lua),
	-- comme les boutons des modules.
	iconBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	iconBtn:SetScript("OnClick", function(self, mouseButton)
		if mouseButton == "LeftButton" and IsAltKeyDown() then
			ToggleLocked() -- comme sur la barre (seule l'icône reste en barre réduite)
		elseif mouseButton == "RightButton" then
			if P.optionsPopup then
				P.ToggleOptionsPopup(self, P.optionsPopup)
			else
				P.OpenOptions()
			end
		else
			P.ToggleUI()
		end
	end)
	iconBtn:SetScript("OnEnter", function(self)
		if bar.dragging then
			return -- pas d'infobulle pendant le déplacement de la barre
		end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Polypode")
		GameTooltip:AddLine("Clic : ouvrir / fermer la fenêtre Polypode", 1, 1, 1)
		GameTooltip:AddLine("Clic droit : options de Polypode", 1, 1, 1)
		if P.charDb.teamBar.compact then
			GameTooltip:AddLine(P.charDb.teamBar.locked and "Barre figée — Alt + clic : libérer"
				or "Glisser : déplacer la barre — Alt + clic : figer", 1, 1, 1)
		end
		P.ShowTooltip()
	end)
	iconBtn:SetScript("OnLeave", GameTooltip_Hide)

	-- Indicateur plié (+) / déplié (-), à gauche du nom.
	toggleIcon = bar:CreateTexture(nil, "OVERLAY")
	toggleIcon:SetSize(14, 14)
	toggleIcon:SetPoint("LEFT", iconBtn, "RIGHT", 4, 0)

	iconButton = iconBtn
	local closeBtn = CreateFrame("Button", nil, bar, "UIPanelCloseButton")
	closeBtn:SetSize(20, 20)
	closeBtn:SetPoint("RIGHT", -14, 0) -- laisse le coin bas-droit à la poignée (barre pliée)
	closeBtn:SetScript("OnClick", function()
		P.charDb.teamBar[ShownKey()] = false
		P.RefreshTeamBar()
	end)

	-- Cadenas affiché quand la barre est figée, à gauche de la croix.
	lockIcon = bar:CreateTexture(nil, "OVERLAY")
	lockIcon:SetSize(14, 14)
	lockIcon:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
	lockIcon:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
	closeButton = closeBtn

	-- Nom de l'équipe : l'en-tête du cadre, recentré sur la barre.
	bar.header:ClearAllPoints()
	bar.header:SetPoint("LEFT", toggleIcon, "RIGHT", 4, 0)
	bar.header:SetPoint("RIGHT", lockIcon, "LEFT", -2, 0)

	-- Membres de l'équipe, même présentation que dans la fenêtre : leader surligné en doré
	-- et marqué [leader].
	listPanel = P.CreatePanel(bar, "")
	P.CreateScrollList(listPanel, function(data)
		if P.charDb.teamBar.details then
			return FormatDetailed(data)
		end
		return P.FormatCharacter(data, not P.IsSoloMode() and P.GetSelectedTeam() or nil)
	end, LIST_PADDING, { -- marge basse identique, fixée par P.CreateScrollList
		inset = 4, -- quelques pixels seulement de chaque côté
		isSelected = function(data)
			return not P.IsSoloMode() and P.GetTeamLeader(P.GetSelectedTeam()) == data.key
		end,
		-- Personnage groupé : infobulle WoW complète (comme au survol d'un cadre de groupe) ;
		-- sinon, son état façon liste d'amis puis ses équipes comme dans la fenêtre principale.
		tooltipUnit = function(data)
			return FindGroupUnit(data.key)
		end,
		tooltip = function(data)
			return P.CharacterTooltip(data.key, StatusLines(data.key))
		end,
		decorate = DecorateRow,
	})
	listPanel:Hide()

	-- État des membres (vie, portée, mort...) rafraîchi tant que la liste est affichée
	-- (OnUpdate ne tourne que sur un cadre visible).
	local sinceRefresh = 0
	listPanel:SetScript("OnUpdate", function(_, elapsed)
		sinceRefresh = sinceRefresh + elapsed
		if sinceRefresh < STATE_REFRESH then
			return
		end
		sinceRefresh = 0
		listPanel.scrollBox:ForEachFrame(function(row)
			if row.data then
				DecorateRow(row, row.data)
			end
		end)
	end)

	-- Poignée de redimensionnement, au-dessus de la liste (placée par LayoutGrip).
	grip = CreateFrame("Button", nil, bar)
	grip:SetSize(12, 12)
	grip:SetFrameLevel(bar:GetFrameLevel() + 10)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", StartResize)
	grip:SetScript("OnMouseUp", StopResize)
	grip:SetScript("OnHide", StopResize)

	-- Colonne des boutons des modules (placée par LayoutModuleButtons).
	moduleColumn = CreateFrame("Frame", nil, bar)
	moduleColumn:Hide()

	P.ui.teamBar = bar
	P.ui.teamBarModules = moduleColumn
	P.ui.teamBarList = listPanel
	P.ui.teamBarClose = closeBtn
	P.ui.teamBarIcon = iconBtn
	P.ui.teamBarGrip = grip
	P.ui.teamBarLock = lockIcon

	P.SkinPanel(bar)
	P.SkinPanel(listPanel)
	P.SkinCloseButton(closeBtn)

	RestorePosition()
end

-- Met la barre à jour (équipe sélectionnée, membres, pliage) ; construite à la demande.
-- Appelé par P.RefreshUI et au login (barre laissée affichée à la déconnexion).
function P.RefreshTeamBar()
	local state = P.charDb and P.charDb.teamBar
	if not state or not state[ShownKey()] then
		if bar then
			bar:Hide()
		end
		return
	end
	if not bar then
		Build()
	end

	local team = P.GetSelectedTeam()
	local members = P.GetTeamMembers(team)
	-- Leader toujours en tête, puis les autres membres par ordre alphabétique.
	local leader = P.GetTeamLeader(team)
	local items = P.SortedKeyItems(members or {}, function(key)
		return key == leader
	end)
	if P.IsSoloMode() then
		-- Mode solo : le personnage joué seul, nom en couleur de classe.
		local key = P.GetCharKey()
		local entry = P.db.roster[key] or {}
		local color = entry.class and C_ClassColor and C_ClassColor.GetClassColor(entry.class)
		local name = P.GetDisplayName(key)
		items = { { key = key, first = true } }
		bar.header:SetText(color and color:WrapTextInColorCode(name) or name)
	elseif team then
		bar.header:SetText(team .. " |cff999999(" .. #items .. ")|r")
		listPanel.emptyText:SetText("Aucun personnage dans l'équipe")
	else
		bar.header:SetText("|cff999999Aucune équipe|r")
		listPanel.emptyText:SetText("Sélectionnez une équipe")
	end

	toggleIcon:SetTexture(state.expanded and "Interface\\Buttons\\UI-MinusButton-Up"
		or "Interface\\Buttons\\UI-PlusButton-Up")
	-- Barre réduite : un cadre de la taille d'un bouton de module, l'icône seule au centre.
	local compact = state.compact and true or false
	if compact then
		bar:SetSize(MODULE_WIDTH, MODULE_HEIGHT)
	else
		bar:SetSize(state.width or BAR_WIDTH, BAR_HEIGHT)
	end
	iconButton:ClearAllPoints()
	if compact then
		iconButton:SetSize(MODULE_HEIGHT - 2, MODULE_HEIGHT - 2)
		iconButton:SetPoint("CENTER")
	else
		iconButton:SetSize(18, 18)
		iconButton:SetPoint("LEFT", 4, 0)
	end
	bar.header:SetShown(not compact)
	toggleIcon:SetShown(not compact)
	closeButton:SetShown(not compact)
	lockIcon:SetShown(not compact and state.locked or false)
	P.SetListData(listPanel, items)
	LayoutList(#items)
	listPanel:SetShown(state.expanded and not compact)
	LayoutGrip()
	if compact then
		grip:Hide()
	end
	LayoutModuleButtons()
	bar:Show()
end

-- Disposition reçue d'un autre personnage de l'équipe (Sync.lua, message BARPOS), en % de
-- l'écran : appliquée seulement si la barre est masquée ici (une barre affichée garde sa
-- place). L'équipe envoyée est sélectionnée si aucune ne l'est.
function P.ApplyTeamBarLayout(teamName, layout)
	local state = P.charDb.teamBar
	if state.shown then
		P.Debug("Position de barre reçue ignorée : barre déjà affichée")
		return
	end
	local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
	state.point, state.relativePoint = "TOPLEFT", "BOTTOMLEFT"
	state.x = layout.left / 100 * screenWidth
	state.y = layout.top / 100 * screenHeight
	state.width = Clamp(layout.width / 100 * screenWidth, MIN_WIDTH, MAX_WIDTH)
	state.listHeight = layout.listHeight
		and Clamp(layout.listHeight / 100 * screenHeight, MIN_LIST_HEIGHT, MAX_LIST_HEIGHT) or nil
	state.expanded = layout.expanded
	state.shown = true
	if not P.GetSelectedTeam() and P.GetTeams()[teamName] then
		P.SelectTeam(teamName) -- rafraîchit aussi la barre (P.RefreshUI)
	end
	if not bar then
		Build() -- place la barre à la position mémorisée
	else
		RestorePosition()
	end
	P.RefreshTeamBar()
end

-- Début du glisser d'une équipe hors du cadre « Équipes » : la barre apparaît sous le curseur
-- et le suit jusqu'au relâchement du bouton, où sa position est mémorisée. Le relâchement est
-- guetté par OnUpdate plutôt que par l'OnDragStop de la ligne d'origine, qui peut être
-- recyclée par le rafraîchissement de la liste pendant le glisser. Barre figée : elle est
-- seulement (ré)affichée à sa place.
function P.StartTeamBarDrag()
	P.charDb.teamBar[ShownKey()] = true
	P.RefreshTeamBar()
	if P.charDb.teamBar.locked then
		return
	end

	local x, y = GetCursorPosition()
	local scale = bar:GetEffectiveScale()
	bar:ClearAllPoints()
	bar:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
	bar:StartMoving()
	bar:SetScript("OnUpdate", function(self)
		if not IsMouseButtonDown("LeftButton") then
			self:SetScript("OnUpdate", nil)
			self:StopMovingOrSizing()
			SavePosition()
			P.RefreshTeamBar()
		end
	end)
end
