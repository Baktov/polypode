-- Polypode: UI_TeamBar — barre flottante de l'équipe sélectionnée (sortie de la fenêtre par glisser)

local P = Polypode

-- Une équipe glissée hors du cadre « Équipes » de la fenêtre principale devient la sélection
-- et s'affiche dans une petite barre posée où on la lâche (P.StartTeamBarDrag). La barre
-- montre toujours l'équipe sélectionnée pour ce personnage : clic droit = déplier / replier
-- la liste défilante de ses membres, glisser = déplacer, croix = masquer. État par personnage
-- (chaque fenêtre de multibox a son écran) dans P.charDb.teamBar : shown, expanded, position.

local BAR_WIDTH, BAR_HEIGHT = 180, 24
local ROW_HEIGHT = 20 -- hauteur d'une ligne de P.CreateScrollList (UI_Main.lua)
local LIST_PADDING = 8 -- marge haute et basse de la liste dans son cadre
local MAX_VISIBLE_ROWS = 8 -- au-delà, la liste défile

local bar, listPanel, toggleIcon

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

-- Hauteur de la liste (MAX_VISIBLE_ROWS lignes au plus, puis défilement), dépliée sous la
-- barre, ou au-dessus si la barre est trop près du bas de l'écran.
local function LayoutList(count)
	local rows = math.min(math.max(count, 1), MAX_VISIBLE_ROWS)
	local height = rows * ROW_HEIGHT + 2 * LIST_PADDING
	listPanel:SetHeight(height)
	listPanel:ClearAllPoints()
	local bottom = bar:GetBottom()
	if bottom and bottom < height then
		listPanel:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 2)
		listPanel:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 2)
	else
		listPanel:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -2)
		listPanel:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -2)
	end
end

local function ShowBarTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:AddLine(P.GetSelectedTeam() or "Aucune équipe sélectionnée")
	GameTooltip:AddLine("Clic droit : déplier / replier la liste des personnages", 1, 1, 1)
	GameTooltip:AddLine("Glisser : déplacer la barre", 1, 1, 1)
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
	bar:SetScript("OnDragStart", bar.StartMoving)
	bar:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
		P.RefreshTeamBar() -- sens de dépliement selon la nouvelle position
	end)
	bar:SetScript("OnMouseUp", function(self, mouseButton)
		if mouseButton == "RightButton" then
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
	closeBtn:SetPoint("RIGHT", -2, 0)
	closeBtn:SetScript("OnClick", function()
		P.charDb.teamBar.shown = false
		P.RefreshTeamBar()
	end)

	-- Nom de l'équipe : l'en-tête du cadre, recentré sur la barre.
	bar.header:ClearAllPoints()
	bar.header:SetPoint("LEFT", toggleIcon, "RIGHT", 4, 0)
	bar.header:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)

	-- Membres de l'équipe, même présentation que dans la fenêtre ([leader] marqué).
	listPanel = P.CreatePanel(bar, "")
	P.CreateScrollList(listPanel, function(data)
		return P.FormatCharacter(data, P.GetSelectedTeam())
	end, LIST_PADDING) -- marge basse identique, fixée par P.CreateScrollList
	listPanel:Hide()

	P.ui.teamBar = bar
	P.ui.teamBarList = listPanel
	P.ui.teamBarClose = closeBtn

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
	P.SetListData(listPanel, items)
	LayoutList(#items)
	listPanel:SetShown(state.expanded)
	bar:Show()
end

-- Début du glisser d'une équipe hors du cadre « Équipes » : la barre apparaît sous le curseur
-- et le suit jusqu'au relâchement du bouton, où sa position est mémorisée. Le relâchement est
-- guetté par OnUpdate plutôt que par l'OnDragStop de la ligne d'origine, qui peut être
-- recyclée par le rafraîchissement de la liste pendant le glisser.
function P.StartTeamBarDrag()
	P.charDb.teamBar.shown = true
	P.RefreshTeamBar()

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
