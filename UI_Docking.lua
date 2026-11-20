-- Polypode: UI_Docking — fenêtres des modules en tiroir ou aimantées contre la fenêtre Polypode

local P = Polypode
local L = P.L

-- Une fenêtre de module s'inscrit par P.RegisterModuleWindow(fenêtre, clé). Selon
-- P.db.windowPlacement (tout le compte, appliqué à la prochaine ouverture) :
-- - "tiroir" (défaut) : à chaque ouverture, la fenêtre s'accole au bord droit de la fenêtre
--   Polypode (gauche s'il n'y a pas la place), haut contre haut, et la suit ; un seul tiroir ouvert
--   par côté ; glissée loin, elle se détache jusqu'à sa prochaine ouverture, glissée contre un bord
--   elle s'y raccroche ; fenêtre Polypode fermée : les tiroirs se ferment ;
-- - "aimant" : glissée à moins de SNAP pixels d'un bord (droit, gauche, bas) de la fenêtre Polypode,
--   elle s'y accroche (trait doré pendant le glisser) et la suit ; accroche gardée par module dans
--   P.db.docking[clé] = { side, offset } et reprise à chaque ouverture ; fenêtre Polypode fermée :
--   la fenêtre reste où elle est ;
-- - "libre" : aucune accroche.
-- Fenêtre Polypode fermée à l'ouverture d'un module : il s'ouvre à sa place habituelle. Fenêtre
-- protégée (boutons sécurisés) : jamais déplacée en combat.

local GAP = -1 -- bordures superposées d'un pixel
local SNAP = 20 -- pixels d'écran

P.WINDOW_PLACEMENT_CHOICES = {
	{ "tiroir", L["Tiroir"] },
	{ "aimant", L["Libre, avec aimant"] },
	{ "libre", L["Libre"] },
}

local windows = setmetatable({}, { __mode = "k" }) -- [fenêtre] = { key, side, offset }

local function Placement()
	local value = P.db and P.db.windowPlacement
	if value == "aimant" or value == "libre" then
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

local function Anchor(frame, main, side, offset)
	frame:ClearAllPoints()
	if side == "RIGHT" then
		frame:SetPoint("TOPLEFT", main, "TOPRIGHT", GAP, offset)
	elseif side == "LEFT" then
		frame:SetPoint("TOPRIGHT", main, "TOPLEFT", -GAP, offset)
	else
		frame:SetPoint("TOPLEFT", main, "BOTTOMLEFT", offset, -GAP)
	end
end

-- Côté du tiroir : droite s'il y a la place jusqu'au bord de l'écran, sinon gauche, sinon droite.
local function DrawerSide(frame, main)
	local left, right = Rect(main)
	if not left then
		return "RIGHT"
	end
	local width = frame:GetWidth() * frame:GetEffectiveScale()
	local screen = UIParent:GetRight() * UIParent:GetEffectiveScale()
	if right + width <= screen or left - width < 0 then
		return "RIGHT"
	end
	return "LEFT"
end

-- Accroche possible d'une fenêtre lâchée près de la fenêtre Polypode : côté et décalage (unités de
-- la fenêtre), haut ou gauche alignés s'ils sont proches ; sinon nil.
local function Snap(frame, main)
	local fl, fr, ft, fb = Rect(frame)
	local ml, mr, mt, mb = Rect(main)
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
	local ml, mr, mt, mb = Rect(main)
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

local function OnDragStart(frame)
	local main = Main()
	if Placement() == "libre" or not main or not main:IsShown() or frame == main then
		return
	end
	watcher.frame = frame
	watcher:Show()
end

local function OnDragStop(frame)
	StopWatching()
	local data = windows[frame]
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
	if not main or not main:IsShown() or not CanMove(frame) then
		return
	end
	local placement = Placement()
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
			if other ~= frame and otherData.side == side and other:IsShown() then
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
	P.db.windowPlacement = (value == "aimant" or value == "libre") and value or "tiroir"
end
