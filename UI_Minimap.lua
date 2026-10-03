-- Polypode: UI_Minimap — bouton autour de la minimap (clic : fenêtre, glisser : déplacer)

local P = Polypode

local ICON = "Interface\\Icons\\spell_holy_layonhands" -- une main (Imposition des mains)
P.ICON = ICON -- partagée avec la barre flottante d'équipe (UI_TeamBar.lua)
local EDGE_OFFSET = 5 -- distance du bouton au-delà du bord de la minimap

-- Place le bouton sur le pourtour de la minimap selon l'angle sauvegardé (en degrés).
-- Minimap ronde : cercle. Autre forme déclarée via GetMinimapShape (ElvUI : "SQUARE") :
-- projection sur le bord du carré (même calcul que LibDBIcon).
local function UpdatePosition(button)
	local angle = math.rad(P.db.minimap.angle)
	local x, y = math.cos(angle), math.sin(angle)
	local w = Minimap:GetWidth() / 2 + EDGE_OFFSET
	local h = Minimap:GetHeight() / 2 + EDGE_OFFSET
	local shape = GetMinimapShape and GetMinimapShape() or "ROUND"

	if shape == "ROUND" then
		x, y = x * w, y * h
	else
		local diagW = math.sqrt(2 * w * w) - 10
		local diagH = math.sqrt(2 * h * h) - 10
		x = math.max(-w, math.min(x * diagW, w))
		y = math.max(-h, math.min(y * diagH, h))
	end

	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Pendant le glisser : l'angle suit le curseur autour du centre de la minimap.
local function OnDragUpdate(button)
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	P.db.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx)) % 360
	UpdatePosition(button)
end

function P.BuildMinimapButton()
	if P.ui.minimapButton or not Minimap then
		return
	end

	-- Nommé et enfant de Minimap : les addons de minimap (EllesmereUI, WindTools...)
	-- le détectent et peuvent le ranger dans leur tiroir de boutons.
	local b = CreateFrame("Button", "PolypodeMinimapButton", Minimap)
	b:SetSize(31, 31)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:RegisterForClicks("LeftButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local background = b:CreateTexture(nil, "BACKGROUND")
	background:SetSize(24, 24)
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetPoint("CENTER")

	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetTexture(ICON)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- rogne le liseré de l'icône
	icon:SetPoint("CENTER")
	b.icon = icon

	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetSize(50, 50)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")

	b:SetScript("OnClick", function()
		P.ToggleUI()
	end)
	b:SetScript("OnDragStart", function(self)
		-- Rangé ailleurs par un addon de minimap : c'est lui qui gère la position.
		if self:GetParent() ~= Minimap then
			return
		end
		self:SetScript("OnUpdate", OnDragUpdate)
	end)
	b:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Polypode")
		GameTooltip:AddLine("Clic : ouvrir/fermer la fenêtre", 1, 1, 1)
		GameTooltip:AddLine("Glisser : déplacer le bouton", 1, 1, 1)
		P.ShowTooltip()
	end)
	b:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	UpdatePosition(b)
	P.ui.minimapButton = b
	if P.db.minimap.hide then
		b:Hide()
	end
end

-- Affiche/masque le bouton et mémorise le choix. Show()/Hide() explicites (et non
-- SetShown) : EllesmereUIMinimap les intercepte pour retirer le bouton de son tiroir.
function P.SetMinimapButtonShown(show)
	P.db.minimap.hide = not show
	local b = P.ui.minimapButton
	if not b then
		return
	end
	if show then
		b:Show()
	else
		b:Hide()
	end
end
