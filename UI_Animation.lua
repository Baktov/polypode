-- Polypode: UI_Animation — ouverture et fermeture animées des fenêtres (sortie du bouton, fondu, dépliage)

local P = Polypode
local L = P.L

-- Toute fenêtre skinnée par P.SkinFrame (Polypode et ses modules) s'anime, quel que soit le thème,
-- selon P.db.windowAnimation (tout le compte, appliqué tout de suite) :
-- - "bouton" (défaut) : la fenêtre grandit depuis le bouton cliqué pour l'ouvrir (élément sous la
--   souris à l'affichage, hors de la fenêtre) et y retourne à la fermeture ; ouverte autrement
--   (raccourci, commande) : fondu ;
-- - "fondu" : apparaît en descendant de 8 px, disparaît en fondu ;
-- - "depli" : se déplie vers le bas depuis son bord haut, se replie à la fermeture ;
-- - "aucune" : affichage et masquage immédiats.
-- Ouverture : accroche OnShow. Fermeture : méthode Hide de la fenêtre remplacée (Échap, croix,
-- boutons) ; masquée vraiment à la fin de l'animation, alpha rétabli. Show pendant la fermeture
-- l'annule. Fenêtre protégée (boutons sécurisés, ex. Téléports) : jamais animée.

local OPEN_TIME = { bouton = 0.18, fondu = 0.15, depli = 0.2 }
local CLOSE_TIME = 0.12
local SLIDE = 8 -- px, fondu

P.WINDOW_ANIMATION_CHOICES = {
	{ "bouton", L["Sortie du bouton"] },
	{ "fondu", L["Fondu et glissement"] },
	{ "depli", L["Dépliage"] },
	{ "aucune", L["Aucune"] },
}

-- Animation choisie, nil pour « aucune ».
local function Kind()
	local kind = P.db and P.db.windowAnimation or "bouton"
	if kind == "aucune" then
		return nil
	end
	return OPEN_TIME[kind] and kind or "bouton"
end

local function CanAnimate(frame)
	return not frame:IsProtected()
end

local function IsInside(region, frame)
	local current = region
	for _ = 1, 20 do
		if not current then
			return false
		end
		if current == frame then
			return true
		end
		current = current.GetParent and current:GetParent()
	end
	return false
end

-- Point de départ de « sortie du bouton » : curseur sur le bouton qui vient d'ouvrir la fenêtre
-- (décalage depuis le coin bas-gauche de la fenêtre), sinon nil.
local function OpenerOrigin(frame)
	local foci = GetMouseFoci and GetMouseFoci()
	local focus = foci and foci[1]
	if not focus or not focus.IsObjectType or not focus:IsObjectType("Button") or IsInside(focus, frame) then
		return
	end
	local left, bottom = frame:GetLeft(), frame:GetBottom()
	if not left or not bottom then
		return
	end
	local x, y = GetCursorPosition()
	local scale = frame:GetEffectiveScale()
	return x / scale - left, y / scale - bottom
end

-- Groupe d'animation d'une fenêtre, créé une fois par clé (genre et sens).
local function Group(frame, data, key, build)
	data.groups = data.groups or {}
	local group = data.groups[key]
	if not group then
		group = frame:CreateAnimationGroup()
		build(group)
		data.groups[key] = group
	end
	return group
end

local function AddAlpha(group, duration, smoothing)
	local alpha = group:CreateAnimation("Alpha")
	alpha:SetDuration(duration)
	alpha:SetSmoothing(smoothing)
	group.alpha = alpha
end

local function AddScale(group, duration, smoothing)
	local scale = group:CreateAnimation("Scale")
	scale:SetDuration(duration)
	scale:SetSmoothing(smoothing)
	group.scale = scale
end

local function OpenGroup(frame, data, kind)
	return Group(frame, data, kind .. ":open", function(group)
		if kind == "fondu" then
			-- Joué à l'envers : alpha 0 → courant, et position +8 px → 0 (descend en place).
			AddAlpha(group, OPEN_TIME.fondu, "IN")
			local move = group:CreateAnimation("Translation")
			move:SetOffset(0, SLIDE)
			move:SetDuration(OPEN_TIME.fondu)
			move:SetSmoothing("IN")
		else
			AddAlpha(group, 0.12, "OUT")
			AddScale(group, OPEN_TIME[kind], "OUT")
		end
	end)
end

local function CloseGroup(frame, data, kind)
	return Group(frame, data, kind .. ":close", function(group)
		group:SetToFinalAlpha(true) -- reste invisible jusqu'au vrai Hide (pas d'éclair)
		AddAlpha(group, CLOSE_TIME, "IN")
		if kind == "fondu" then
			local move = group:CreateAnimation("Translation")
			move:SetOffset(0, SLIDE / 2)
			move:SetDuration(CLOSE_TIME)
			move:SetSmoothing("IN")
		else
			AddScale(group, CLOSE_TIME, "IN")
		end
		group:SetScript("OnFinished", function()
			data.closing = nil
			data.realHide(frame)
			frame:SetAlpha(data.alpha or 1)
		end)
	end)
end

local function Open(frame, data)
	if data.closing then
		return
	end
	local kind = Kind()
	if not kind or not CanAnimate(frame) then
		return
	end
	local originX, originY
	if kind == "bouton" then
		originX, originY = OpenerOrigin(frame)
		if not originX then
			kind = "fondu"
		end
	end
	data.origin = originX and { originX, originY } or nil
	local alpha = frame:GetAlpha()
	local group = OpenGroup(frame, data, kind)
	if kind == "fondu" then
		group.alpha:SetFromAlpha(alpha)
		group.alpha:SetToAlpha(0)
	else
		group.alpha:SetFromAlpha(0)
		group.alpha:SetToAlpha(alpha)
		if kind == "bouton" then
			group.scale:SetScaleFrom(0.55, 0.55)
			group.scale:SetOrigin("BOTTOMLEFT", originX, originY)
		else
			group.scale:SetScaleFrom(1, 0.01)
			group.scale:SetOrigin("TOP", 0, 0)
		end
		group.scale:SetScaleTo(1, 1)
	end
	if data.opening then
		data.opening:Stop()
	end
	data.opening = group
	group:Play(kind == "fondu")
end

local function Close(frame, data)
	local kind = Kind()
	if kind == "bouton" and not data.origin then
		kind = "fondu"
	end
	if not kind then
		return data.realHide(frame)
	end
	if data.opening then
		data.opening:Stop()
		data.opening = nil
	end
	data.alpha = frame:GetAlpha()
	local group = CloseGroup(frame, data, kind)
	group.alpha:SetFromAlpha(data.alpha)
	group.alpha:SetToAlpha(0)
	if kind == "bouton" then
		group.scale:SetScaleTo(0.6, 0.6)
		group.scale:SetOrigin("BOTTOMLEFT", data.origin[1], data.origin[2])
	elseif kind == "depli" then
		group.scale:SetScaleTo(1, 0.01)
		group.scale:SetOrigin("TOP", 0, 0)
	end
	if group.scale then
		group.scale:SetScaleFrom(1, 1)
	end
	data.closing = group
	group:Play()
end

local animated = setmetatable({}, { __mode = "k" })

-- Branche l'animation sur une fenêtre (appelée par P.SkinFrame, une fois par fenêtre).
function P.SetupWindowAnimation(frame)
	if animated[frame] then
		return
	end
	local data = { realHide = frame.Hide }
	animated[frame] = data
	local realShow = frame.Show
	frame:HookScript("OnShow", function(self)
		Open(self, data)
	end)
	frame.Hide = function(self, ...)
		if data.closing then
			return
		end
		if not self:IsShown() or not CanAnimate(self) or not Kind() then
			return data.realHide(self, ...)
		end
		Close(self, data)
	end
	frame.Show = function(self, ...)
		if data.closing then
			-- Rouverte pendant sa fermeture : la fermeture s'arrête, la fenêtre reste affichée.
			data.closing:Stop()
			data.closing = nil
			self:SetAlpha(data.alpha or 1)
			Open(self, data)
			return
		end
		return realShow(self, ...)
	end
end

function P.SetWindowAnimation(kind)
	P.db.windowAnimation = (OPEN_TIME[kind] or kind == "aucune") and kind or "bouton"
end
