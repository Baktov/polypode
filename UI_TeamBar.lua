-- Polypode: UI_TeamBar — barre flottante de l'équipe sélectionnée (sortie de la fenêtre par glisser)

local P = Polypode

-- Une équipe glissée hors du cadre « Équipes » de la fenêtre principale devient la sélection
-- et s'affiche dans une petite barre posée où on la lâche (P.StartTeamBarDrag). La barre
-- montre toujours l'équipe sélectionnée pour ce personnage : clic droit = déplier / replier
-- la liste défilante de ses membres, glisser = déplacer, poignée = redimensionner (largeur,
-- et hauteur de la liste dépliée), Alt + clic = figer / libérer (position et taille),
-- croix = masquer. État par personnage (chaque fenêtre de multibox a son écran) dans
-- P.charDb.teamBar : shown, expanded, locked, position, width, listHeight.

local BAR_WIDTH, BAR_HEIGHT = 180, 24
local MIN_WIDTH, MAX_WIDTH = 100, 600
local ROW_HEIGHT = 20 -- hauteur d'une ligne de P.CreateScrollList (UI_Main.lua)
local LIST_PADDING = 8 -- marge haute et basse de la liste dans son cadre
local MAX_VISIBLE_ROWS = 8 -- hauteur automatique : au-delà, la liste défile
local MIN_LIST_HEIGHT, MAX_LIST_HEIGHT = ROW_HEIGHT + 2 * LIST_PADDING, 600

local bar, listPanel, toggleIcon, lockIcon, grip
local listAbove -- liste dépliée au-dessus de la barre (trop près du bas de l'écran)

local function Clamp(value, low, high)
	return math.max(low, math.min(high, value))
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

local function ShowBarTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:AddLine(P.GetSelectedTeam() or "Aucune équipe sélectionnée")
	GameTooltip:AddLine("Clic droit : déplier / replier la liste des personnages", 1, 1, 1)
	if P.charDb.teamBar.locked then
		GameTooltip:AddLine("Barre figée (position et taille)", 1, 0.82, 0)
		GameTooltip:AddLine("Alt + clic : libérer", 1, 1, 1)
	else
		GameTooltip:AddLine("Glisser : déplacer la barre", 1, 1, 1)
		GameTooltip:AddLine("Poignée du coin : redimensionner", 1, 1, 1)
		GameTooltip:AddLine("Alt + clic : figer la position et la taille", 1, 1, 1)
	end
	GameTooltip:AddLine("Croix : masquer (glisser une équipe hors de la fenêtre Polypode pour "
		.. "la réafficher)", 1, 1, 1, true)
	GameTooltip:Show()
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
			self:StartMoving()
		end
	end)
	bar:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
		P.RefreshTeamBar() -- sens de dépliement selon la nouvelle position
	end)
	bar:SetScript("OnMouseUp", function(self, mouseButton)
		-- Le relâchement qui termine un déplacement n'est pas un clic.
		local dragged = self.dragging
		self.dragging = nil
		if mouseButton == "LeftButton" and IsAltKeyDown() and not dragged then
			ToggleLocked()
		elseif mouseButton == "RightButton" then
			local state = P.charDb.teamBar
			state.expanded = not state.expanded
			P.RefreshTeamBar()
		end
	end)
	bar:SetScript("OnEnter", ShowBarTooltip)
	bar:SetScript("OnLeave", GameTooltip_Hide)
	bar:Hide()

	-- Indicateur plié (+) / déplié (-), à gauche du nom.
	toggleIcon = bar:CreateTexture(nil, "OVERLAY")
	toggleIcon:SetSize(14, 14)
	toggleIcon:SetPoint("LEFT", 6, 0)

	local closeBtn = CreateFrame("Button", nil, bar, "UIPanelCloseButton")
	closeBtn:SetSize(20, 20)
	closeBtn:SetPoint("RIGHT", -14, 0) -- laisse le coin bas-droit à la poignée (barre pliée)
	closeBtn:SetScript("OnClick", function()
		P.charDb.teamBar.shown = false
		P.RefreshTeamBar()
	end)

	-- Cadenas affiché quand la barre est figée, à gauche de la croix.
	lockIcon = bar:CreateTexture(nil, "OVERLAY")
	lockIcon:SetSize(14, 14)
	lockIcon:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
	lockIcon:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")

	-- Nom de l'équipe : l'en-tête du cadre, recentré sur la barre.
	bar.header:ClearAllPoints()
	bar.header:SetPoint("LEFT", toggleIcon, "RIGHT", 4, 0)
	bar.header:SetPoint("RIGHT", lockIcon, "LEFT", -2, 0)

	-- Membres de l'équipe, même présentation que dans la fenêtre : leader surligné en doré
	-- et marqué [leader].
	listPanel = P.CreatePanel(bar, "")
	P.CreateScrollList(listPanel, function(data)
		return P.FormatCharacter(data, P.GetSelectedTeam())
	end, LIST_PADDING, { -- marge basse identique, fixée par P.CreateScrollList
		isSelected = function(data)
			return P.GetTeamLeader(P.GetSelectedTeam()) == data.key
		end,
	})
	listPanel:Hide()

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

	P.ui.teamBar = bar
	P.ui.teamBarList = listPanel
	P.ui.teamBarClose = closeBtn
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
	if not state or not state.shown then
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
	local items = P.SortedKeyItems(members or {})
	if team then
		bar.header:SetText(team .. " |cff999999(" .. #items .. ")|r")
		listPanel.emptyText:SetText("Aucun personnage dans l'équipe")
	else
		bar.header:SetText("|cff999999Aucune équipe|r")
		listPanel.emptyText:SetText("Sélectionnez une équipe")
	end

	toggleIcon:SetTexture(state.expanded and "Interface\\Buttons\\UI-MinusButton-Up"
		or "Interface\\Buttons\\UI-PlusButton-Up")
	bar:SetWidth(state.width or BAR_WIDTH)
	lockIcon:SetShown(state.locked or false)
	P.SetListData(listPanel, items)
	LayoutList(#items)
	listPanel:SetShown(state.expanded)
	LayoutGrip()
	bar:Show()
end

-- Début du glisser d'une équipe hors du cadre « Équipes » : la barre apparaît sous le curseur
-- et le suit jusqu'au relâchement du bouton, où sa position est mémorisée. Le relâchement est
-- guetté par OnUpdate plutôt que par l'OnDragStop de la ligne d'origine, qui peut être
-- recyclée par le rafraîchissement de la liste pendant le glisser. Barre figée : elle est
-- seulement (ré)affichée à sa place.
function P.StartTeamBarDrag()
	P.charDb.teamBar.shown = true
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
