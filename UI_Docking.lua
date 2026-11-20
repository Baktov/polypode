-- Polypode: UI_Docking — fenêtres des modules en tiroir, aimantées ou en fenêtre unique

local P = Polypode
local L = P.L

-- Une fenêtre de module s'inscrit par P.RegisterModuleWindow(fenêtre, clé). Selon
-- P.db.windowPlacement (tout le compte, appliqué à la prochaine ouverture) :
-- - "tiroir" (défaut) : à chaque ouverture, la fenêtre s'accole au bord droit de la fenêtre
--   Polypode, haut contre haut, et la suit ; un seul tiroir ouvert par côté : côté droit, sinon
--   gauche s'il est libre ou s'il n'y a pas la place à droite (DrawerSide) ;
--   glissée loin, elle se détache jusqu'à sa prochaine ouverture, glissée contre un bord elle s'y
--   raccroche ; fenêtre Polypode fermée : les tiroirs se ferment ;
-- - "aimant" : glissée à moins de SNAP pixels d'un bord (droit, gauche, bas) de la fenêtre Polypode,
--   elle s'y accroche (trait doré pendant le glisser) et la suit ; accroche gardée par module dans
--   P.db.docking[clé] = { side, offset } et reprise à chaque ouverture ; fenêtre Polypode fermée :
--   la fenêtre reste où elle est ;
-- - "unique" : fenêtre unique ; les modules s'ouvrent l'un à la place de l'autre (un seul ouvert),
--   tous au même endroit (P.db.windowUnique = { x, y } : coin haut-gauche, pixels d'écran, gardé
--   quand on glisse la fenêtre ; d'abord la place du premier module ouvert), avec la colonne des
--   boutons de modules (ceux de la barre de titre de la fenêtre Polypode) collée à son bord gauche
--   (droit s'il n'y a pas la place) ; indépendant de la fenêtre Polypode ;
-- - "libre" : aucune accroche.
-- Fenêtre Polypode fermée à l'ouverture d'un module : il s'ouvre à sa place habituelle. Fenêtre
-- protégée (boutons sécurisés) : jamais déplacée en combat.

local GAP = -1 -- bordures superposées d'un pixel
local SNAP = 20 -- pixels d'écran

P.WINDOW_PLACEMENT_CHOICES = {
	{ "tiroir", L["Tiroir"] },
	{ "aimant", L["Libre, avec aimant"] },
	{ "unique", L["Fenêtre unique"] },
	{ "libre", L["Libre"] },
}

local windows = setmetatable({}, { __mode = "k" }) -- [fenêtre] = { key, side, offset }

local function Placement()
	local value = P.db and P.db.windowPlacement
	if value == "aimant" or value == "libre" or value == "unique" then
		return value
	end
	return "tiroir"
end

local function Main()
	return P.ui and P.ui.frame
end

local function CanMove(frame)
	return not (InCombatLockdown() and frame:IsProtected())
end

-- Rectangle en pixels d'écran : gauche, droite, haut, bas.
local function Rect(frame)
	local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not (left and right and top and bottom) then
		return
	end
	local scale = frame:GetEffectiveScale()
	return left * scale, right * scale, top * scale, bottom * scale
end

-- Colonne des boutons de modules (plus bas) : dimensions, et celle de la fenêtre Polypode.
local STRIP_BUTTON_WIDTH, STRIP_BUTTON_HEIGHT, STRIP_PAD = 36, 20, 4
local STRIP_WIDTH = STRIP_BUTTON_WIDTH + 2 * STRIP_PAD
-- Colonne descendue sous le coin de la fenêtre (ornement en losange du style Chronique, qui
-- dépasse de 7 pixels).
local STRIP_TOP = -10
local mainColumn

-- Largeur (unités de la fenêtre Polypode) que sa colonne ajoute de ce côté : les fenêtres
-- accrochées de ce côté se placent contre la colonne.
local function ColumnExtra(side)
	if mainColumn and mainColumn:IsShown() and mainColumn.side == side then
		return STRIP_WIDTH + GAP
	end
	return 0
end

-- Rectangle de la fenêtre Polypode, colonne comprise.
local function MainRect(main)
	local left, right, top, bottom = Rect(main)
	if not left then
		return
	end
	local scale = main:GetEffectiveScale()
	return left - ColumnExtra("LEFT") * scale, right + ColumnExtra("RIGHT") * scale, top, bottom
end

local function Anchor(frame, main, side, offset)
	frame:ClearAllPoints()
	if side == "RIGHT" then
		frame:SetPoint("TOPLEFT", main, "TOPRIGHT", GAP + ColumnExtra("RIGHT"), offset)
	elseif side == "LEFT" then
		frame:SetPoint("TOPRIGHT", main, "TOPLEFT", -GAP - ColumnExtra("LEFT"), offset)
	else
		frame:SetPoint("TOPLEFT", main, "BOTTOMLEFT", offset, -GAP)
	end
end

-- Vrai si un autre tiroir ouvert occupe ce côté.
local function SideTaken(frame, side)
	for other, data in pairs(windows) do
		if other ~= frame and data.side == side and other:IsShown() then
			return true
		end
	end
	return false
end

-- Côté du tiroir : un côté libre où il y a la place jusqu'au bord de l'écran (droite d'abord),
-- sinon un côté où il y a la place (le tiroir qui l'occupe se refermera), sinon droite.
local function DrawerSide(frame, main)
	local left, right = MainRect(main)
	if not left then
		return "RIGHT"
	end
	local width = frame:GetWidth() * frame:GetEffectiveScale()
	local screen = UIParent:GetRight() * UIParent:GetEffectiveScale()
	local roomRight, roomLeft = right + width <= screen, left - width >= 0
	if roomRight and not SideTaken(frame, "RIGHT") then
		return "RIGHT"
	elseif roomLeft and not SideTaken(frame, "LEFT") then
		return "LEFT"
	elseif roomRight or not roomLeft then
		return "RIGHT"
	end
	return "LEFT"
end

-- Accroche possible d'une fenêtre lâchée près de la fenêtre Polypode : côté et décalage (unités de
-- la fenêtre), haut ou gauche alignés s'ils sont proches ; sinon nil.
local function Snap(frame, main)
	local fl, fr, ft, fb = Rect(frame)
	local ml, mr, mt, mb = MainRect(main)
	if not (fl and ml) then
		return
	end
	local scale = frame:GetEffectiveScale()
	local vOverlap = ft > mb - SNAP and fb < mt + SNAP
	local hOverlap = fl < mr + SNAP and fr > ml - SNAP
	local side
	if vOverlap and math.abs(fl - mr) <= SNAP then
		side = "RIGHT"
	elseif vOverlap and math.abs(fr - ml) <= SNAP then
		side = "LEFT"
	elseif hOverlap and math.abs(ft - mb) <= SNAP then
		side = "BOTTOM"
	end
	if not side then
		return
	end
	if side == "BOTTOM" then
		return side, math.abs(fl - ml) <= SNAP and 0 or (fl - ml) / scale
	end
	return side, math.abs(ft - mt) <= SNAP and 0 or (ft - mt) / scale
end

-- Trait doré montrant l'accroche pendant le glisser.
local guide = CreateFrame("Frame", nil, UIParent)
guide:SetFrameStrata("FULLSCREEN_DIALOG")
guide:Hide()
guide.line = guide:CreateTexture(nil, "OVERLAY")
guide.line:SetAllPoints()

local function ShowGuide(frame, main, side)
	local fl, fr, ft, fb = Rect(frame)
	local ml, mr, mt, mb = MainRect(main)
	local scale = UIParent:GetEffectiveScale()
	guide:ClearAllPoints()
	if side == "BOTTOM" then
		local left, right = math.min(fl, ml), math.max(fr, mr)
		guide:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left / scale, mb / scale - 1)
		guide:SetSize((right - left) / scale, 2)
	else
		local x = side == "RIGHT" and mr or ml
		local top, bottom = math.max(ft, mt), math.min(fb, mb)
		guide:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale - 1, bottom / scale)
		guide:SetSize(2, (top - bottom) / scale)
	end
	local r, g, b = 1, 0.82, 0.2
	if P.IsPolypodeTheme and P.IsPolypodeTheme() then
		r, g, b = P.GetThemeColor("accent")
	end
	guide.line:SetColorTexture(r, g, b, 0.9)
	guide:Show()
end

local watcher = CreateFrame("Frame")
watcher:Hide()
watcher:SetScript("OnUpdate", function(self)
	local frame, main = self.frame, Main()
	if not frame or not main or not main:IsShown() then
		guide:Hide()
		return
	end
	local side = Snap(frame, main)
	if side then
		ShowGuide(frame, main, side)
	else
		guide:Hide()
	end
end)

local function StopWatching()
	watcher.frame = nil
	watcher:Hide()
	guide:Hide()
end

-- COLONNE DES BOUTONS DE MODULES : enfant de la fenêtre qui la porte (elle bouge, se fond et se
-- masque avec elle). Deux colonnes : celle de la fenêtre unique (déplacée de module en module) et
-- celle de la fenêtre Polypode (option « boutons en colonne », P.IsWindowButtonColumn).
local strips = {} -- colonnes créées (repeintes au changement de style)
local uniqueStrip
local uniqueFrame -- fenêtre de module ouverte en mode « unique »

-- Trois premiers caractères (UTF-8 entiers), comme la colonne de la barre d'équipe.
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

local function AccentColor()
	if P.IsPolypodeTheme and P.IsPolypodeTheme() then
		return P.GetThemeColor("accent")
	end
	return 1, 0.82, 0.2
end

local function PaintStrips()
	local bg, border = { 0.05, 0.05, 0.06, 0.92 }, { 0.3, 0.3, 0.3, 1 }
	if P.IsPolypodeTheme and P.IsPolypodeTheme() then
		bg = { P.GetThemeColor("bg") }
		border = { P.GetThemeColor("border") }
	end
	local r, g, b = AccentColor()
	for _, strip in ipairs(strips) do
		strip:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 0.92)
		strip:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
		for _, button in ipairs(strip.buttons) do
			button.mark:SetColorTexture(r, g, b, 1)
		end
	end
end

local function NewStrip(parent)
	local strip = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	strip:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1 })
	strip.buttons = {}
	if #strips == 0 and P.OnThemeChanged then
		P.OnThemeChanged(PaintStrips)
	end
	strips[#strips + 1] = strip
	return strip
end

local function StripButton(strip, index)
	local button = strip.buttons[index]
	if button then
		return button
	end
	button = CreateFrame("Button", nil, strip, "UIPanelButtonTemplate")
	button:SetSize(STRIP_BUTTON_WIDTH, STRIP_BUTTON_HEIGHT)
	button:SetNormalFontObject("GameFontNormalSmall")
	button:SetHighlightFontObject("GameFontHighlightSmall")
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetScript("OnClick", function(self, mouseButton)
		local spec = self.spec
		if spec and spec.onClick and (mouseButton ~= "RightButton" or spec.rightClick) then
			spec.onClick(self, mouseButton)
		end
	end)
	button:SetScript("OnEnter", function(self)
		if not self.spec or not self.spec.tooltip or not P.TitleButtonTooltip then
			return
		end
		GameTooltip:SetOwner(self, strip.side == "LEFT" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
		for i, line in ipairs(P.TitleButtonTooltip(self.spec)) do
			if i == 1 then
				GameTooltip:AddLine(line)
			else
				GameTooltip:AddLine(line, 1, 1, 1, true)
			end
		end
		P.ShowTooltip()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	-- Module affiché : trait d'accent sur le bord de la colonne côté fenêtre.
	button.mark = button:CreateTexture(nil, "OVERLAY")
	button.mark:SetSize(2, STRIP_BUTTON_HEIGHT - 4)
	if P.SkinButton then
		P.SkinButton(button)
	end
	strip.buttons[index] = button
	return button
end

-- Boutons des modules affichés dans la barre de titre de la fenêtre Polypode, dans son ordre.
local function StripSpecs()
	local specs = {}
	if not (P.OrderedButtonSpecs and P.GetWindowButtonOrder) then
		return specs
	end
	for _, spec in ipairs(P.OrderedButtonSpecs(P.GetWindowButtonOrder())) do
		if not P.IsWindowButtonShown or P.IsWindowButtonShown(spec) then
			specs[#specs + 1] = spec
		end
	end
	return specs
end

-- Place la colonne strip contre la fenêtre frame : à gauche, à droite s'il n'y a pas la place
-- jusqu'au bord de l'écran ; trait d'accent sur le bouton du module key (nil : aucun).
local function LayoutStrip(strip, frame, key)
	strip:SetParent(frame)
	strip:SetFrameLevel(frame:GetFrameLevel() + 20)
	local specs = StripSpecs()
	local left = Rect(frame)
	strip.side = (left and left < STRIP_WIDTH * frame:GetEffectiveScale()) and "RIGHT" or "LEFT"
	strip:ClearAllPoints()
	if strip.side == "LEFT" then
		strip:SetPoint("TOPRIGHT", frame, "TOPLEFT", -GAP, STRIP_TOP)
	else
		strip:SetPoint("TOPLEFT", frame, "TOPRIGHT", GAP, STRIP_TOP)
	end
	strip:SetSize(STRIP_WIDTH, math.max(1, #specs) * (STRIP_BUTTON_HEIGHT + STRIP_PAD) + STRIP_PAD)
	for index, spec in ipairs(specs) do
		local button = StripButton(strip, index)
		button.spec = spec
		button:SetText(ShortLabel(spec.text))
		button:ClearAllPoints()
		button:SetPoint("TOP", strip, "TOP", 0, -STRIP_PAD - (index - 1) * (STRIP_BUTTON_HEIGHT + STRIP_PAD))
		button.mark:ClearAllPoints()
		if strip.side == "LEFT" then
			button.mark:SetPoint("LEFT", button, "RIGHT", 2, 0)
		else
			button.mark:SetPoint("RIGHT", button, "LEFT", -2, 0)
		end
		button.mark:SetShown(key ~= nil and spec.moduleKey == key)
		button:Show()
	end
	for index = #specs + 1, #strip.buttons do
		strip.buttons[index]:Hide()
		strip.buttons[index].spec = nil
	end
	PaintStrips()
	strip:Show()
end

local function ShowStrip(frame, key)
	if InCombatLockdown() and frame:IsProtected() then
		return
	end
	uniqueStrip = uniqueStrip or NewStrip(frame)
	LayoutStrip(uniqueStrip, frame, key)
end

-- Vrai si les boutons des modules de la fenêtre Polypode sont en colonne sur son côté plutôt que
-- dans sa barre de titre (P.db.windowButtonColumn, tout le compte, comme la taille de la fenêtre).
function P.IsWindowButtonColumn()
	return P.db and P.db.windowButtonColumn == true
end

-- Affiche, replace ou masque la colonne de la fenêtre Polypode (appelée par UI_Main.lua quand les
-- boutons changent, et à la fin d'un déplacement de la fenêtre) ; les fenêtres accrochées suivent.
function P.RefreshMainColumn()
	local main = Main()
	if not main then
		return
	end
	if not P.IsWindowButtonColumn() then
		if mainColumn then
			mainColumn:Hide()
		end
	else
		if not mainColumn then
			mainColumn = NewStrip(main)
			main:HookScript("OnDragStop", P.RefreshMainColumn)
		end
		LayoutStrip(mainColumn, main, nil)
	end
	for frame in pairs(windows) do
		if frame:IsShown() then
			P.RefreshDocking(frame)
		end
	end
end

-- Garde la place commune de la fenêtre unique (coin haut-gauche, pixels d'écran).
local function SaveUniquePlace(frame)
	local left, _, top = Rect(frame)
	if left then
		P.db.windowUnique = { x = left, y = top }
	end
end

local function AnchorUnique(frame)
	local place = P.db.windowUnique
	if not place then
		SaveUniquePlace(frame)
		return
	end
	local scale = frame:GetEffectiveScale()
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", place.x / scale, place.y / scale)
end

local function OnDragStart(frame)
	local data = windows[frame]
	if data then
		data.dragging = true
	end
	local main = Main()
	if Placement() == "libre" or Placement() == "unique" or not main or not main:IsShown() or frame == main then
		return
	end
	watcher.frame = frame
	watcher:Show()
end

local function OnDragStop(frame)
	StopWatching()
	local data = windows[frame]
	if data then
		data.dragging = nil
	end
	if data and Placement() == "unique" then
		if frame == uniqueFrame then
			SaveUniquePlace(frame)
		end
		return
	end
	local main = Main()
	if not data or Placement() == "libre" or not main or not main:IsShown() or not CanMove(frame) then
		return
	end
	local side, offset = Snap(frame, main)
	data.side, data.offset = side, offset
	if side then
		Anchor(frame, main, side, offset)
	end
	if Placement() == "aimant" then
		P.db.docking[data.key] = side and { side = side, offset = offset } or nil
	end
end

-- Fenêtre Polypode fermée : tiroirs fermés, fenêtres aimantées laissées où elles sont.
local function OnMainHide(main)
	if main:IsShown() then
		return -- seulement son parent masqué (interface cachée) : rien à faire
	end
	for frame, data in pairs(windows) do
		if data.side and frame:IsShown() and CanMove(frame) then
			if Placement() == "tiroir" then
				frame:Hide()
			else
				local left, top = frame:GetLeft(), frame:GetTop()
				if left and top then
					frame:ClearAllPoints()
					frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
				end
			end
		end
		data.side = nil
	end
end

local mainHooked
local function HookMain()
	local main = Main()
	if main and not mainHooked then
		mainHooked = true
		main:HookScript("OnHide", OnMainHide)
	end
	return main
end

-- Inscrit la fenêtre d'un module (après P.SkinFrame) : tiroir ou aimant selon le placement choisi.
function P.RegisterModuleWindow(frame, moduleKey)
	if windows[frame] or frame == Main() then
		return
	end
	windows[frame] = { key = moduleKey or (frame.GetName and frame:GetName()) or tostring(frame) }
	frame:HookScript("OnDragStart", OnDragStart)
	frame:HookScript("OnDragStop", OnDragStop)
	frame:HookScript("OnHide", function(self)
		if self == uniqueFrame then
			uniqueFrame = nil
		end
	end)
	-- Fin d'un redimensionnement par la poignée (frame:StopMovingOrSizing(), qui laisse la fenêtre
	-- ancrée à l'écran) : rattachée à la fenêtre Polypode. Le glisser (OnDragStop) a sa propre accroche.
	if type(frame.StopMovingOrSizing) == "function" then
		hooksecurefunc(frame, "StopMovingOrSizing", function(self)
			local data = windows[self]
			if data and not data.dragging then
				P.RefreshDocking(self)
			end
		end)
	end
end

-- Accroche une fenêtre inscrite à son ouverture (appelée par UI_Animation.lua avant l'animation) :
-- renvoie le côté ("RIGHT", "LEFT", "BOTTOM") ou nil.
function P.ApplyDocking(frame)
	local data = windows[frame]
	if not data then
		return
	end
	data.side, data.offset = nil, nil
	local main = HookMain()
	local placement = Placement()
	if placement == "unique" then
		-- Fenêtre unique : indépendante de la fenêtre Polypode.
		if not CanMove(frame) then
			return
		end
		-- Un seul module ouvert : les autres se referment, celui-ci prend la place commune.
		for other in pairs(windows) do
			if other ~= frame and other:IsShown() and CanMove(other) then
				other:Hide()
			end
		end
		AnchorUnique(frame)
		uniqueFrame = frame
		ShowStrip(frame, data.key)
		return
	end
	if uniqueStrip and uniqueStrip:GetParent() == frame then
		uniqueStrip:Hide()
	end
	if not main or not main:IsShown() or not CanMove(frame) then
		return
	end
	local side, offset
	if placement == "tiroir" then
		side, offset = DrawerSide(frame, main), 0
	elseif placement == "aimant" then
		local saved = P.db.docking[data.key]
		if saved then
			side, offset = saved.side, saved.offset or 0
		end
	end
	if not side then
		return
	end
	Anchor(frame, main, side, offset)
	data.side, data.offset = side, offset
	if placement == "tiroir" then
		-- Un seul tiroir ouvert par côté : l'autre se referme.
		for other, otherData in pairs(windows) do
			if other ~= frame and otherData.side == side and other:IsShown() and CanMove(other) then
				other:Hide()
				otherData.side = nil
			end
		end
	end
	return side
end

-- Côté du tiroir d'une fenêtre ouverte en mode tiroir (animation de glissement), sinon nil.
function P.GetDrawerSide(frame)
	local data = windows[frame]
	return data and Placement() == "tiroir" and data.side or nil
end

-- Rattache une fenêtre accrochée après un changement de taille par sa poignée (qui l'a ancrée à
-- l'écran pendant le redimensionnement).
function P.RefreshDocking(frame)
	local data = windows[frame]
	local main = Main()
	if data and data.side and main and main:IsShown() and CanMove(frame) then
		Anchor(frame, main, data.side, data.offset or 0)
	end
end

function P.SetWindowPlacement(value)
	P.db.windowPlacement = (value == "aimant" or value == "libre" or value == "unique") and value or "tiroir"
	if uniqueStrip and value ~= "unique" then
		uniqueStrip:Hide()
	end
end
