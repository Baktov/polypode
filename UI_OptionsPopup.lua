-- Polypode: UI_OptionsPopup — petite fenêtre d'options (clic droit sur l'icône et les boutons des modules)

local P = Polypode

-- Rappel des options d'un panneau (Options → AddOns) dans une petite fenêtre près du bouton
-- cliqué, comme celle de Polypode Photo. Les réglages sont ceux du panneau
-- (Settings.RegisterProxySetting) : la fenêtre les lit (setting:GetValue) et les modifie
-- (setting:SetValue) par leurs propres fonctions, rien n'est dupliqué, et le panneau suit.
-- P.ToggleOptionsPopup(owner, popup), popup = { key, title, items, category } ; items = liste de
--   { kind = "check", setting, tooltip } ;
--   { kind = "slider", setting, min, max, step, format = fn(valeur) → texte, tooltip } ;
--   { kind = "dropdown", setting, values = { { valeur, libellé }, ... }, tooltip }.
-- Bouton « Toutes les options » : le panneau complet (champs de texte...). Contenu défilant
-- (P.CreateScrollList, lignes recyclées : tout se recalcule dans FillRow).

local WIDTH, MAX_HEIGHT, ROW_HEIGHT = 360, 440, 28
local CONTROL_WIDTH = 140 -- liste déroulante, à droite de la ligne
local SLIDER_WIDTH, SLIDER_LABEL = 110, 40 -- curseur, et place de sa valeur à droite
local popups = {} -- [key] = fenêtre

-- Infobulle d'une option : son nom, puis son explication.
local function ShowItemTooltip(owner, item)
	if not (item and item.tooltip) then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:AddLine(item.setting:GetName())
	GameTooltip:AddLine(item.tooltip, 1, 1, 1, true)
	GameTooltip:Show()
end

local function EnsureCheck(row)
	if not row.check then
		local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
		check:SetSize(24, 24)
		check:SetPoint("LEFT", 2, 0)
		check:SetScript("OnClick", function(self)
			if row.data and row.data.kind == "check" then
				row.data.setting:SetValue(self:GetChecked() and true or false)
				-- Relue : un réglage peut refuser le changement (ex. imposé en mode solo).
				self:SetChecked(row.data.setting:GetValue() and true or false)
			end
		end)
		check:SetScript("OnEnter", function(self)
			ShowItemTooltip(self, row.data)
		end)
		check:SetScript("OnLeave", GameTooltip_Hide)
		if P.SkinCheckBox then
			P.SkinCheckBox(check)
		end
		row.check = check
	end
	return row.check
end

local function EnsureSlider(row)
	if not row.slider then
		local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
		slider:SetSize(SLIDER_WIDTH, 20)
		slider:SetPoint("RIGHT", -SLIDER_LABEL, 0)
		-- Init du curseur (ligne recyclée) déclenche aussi ce rappel : ignoré pendant FillRow.
		slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
			if not row.filling and row.data and row.data.kind == "slider" then
				row.data.setting:SetValue(value)
			end
		end, row)
		row.slider = slider
	end
	return row.slider
end

local function EnsureDropdown(row)
	if not row.dropdown then
		local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
		dropdown:SetWidth(CONTROL_WIDTH)
		dropdown:SetPoint("RIGHT", -4, 0)
		dropdown:SetupMenu(function(_, root)
			local item = row.data
			if not (item and item.kind == "dropdown") then
				return
			end
			for _, value in ipairs(item.values) do
				root:CreateRadio(value[2], function(data)
					return item.setting:GetValue() == data
				end, function(data)
					item.setting:SetValue(data)
				end, value[1])
			end
		end)
		if P.SkinDropdown then
			P.SkinDropdown(dropdown, CONTROL_WIDTH)
		end
		row.dropdown = dropdown
	end
	return row.dropdown
end

-- Habille une ligne selon son option : case à gauche du libellé, curseur ou liste à droite.
local function FillRow(row, item)
	row.filling = true
	local kind = item.kind
	if row.check then
		row.check:SetShown(kind == "check")
	end
	if row.slider then
		row.slider:SetShown(kind == "slider")
	end
	if row.dropdown then
		row.dropdown:SetShown(kind == "dropdown")
	end
	row.text:ClearAllPoints()
	if kind == "check" then
		local check = EnsureCheck(row)
		check:SetChecked(item.setting:GetValue() and true or false)
		check:Show()
		row.text:SetPoint("LEFT", check, "RIGHT", 4, 0)
		row.text:SetPoint("RIGHT", -4, 0)
	elseif kind == "slider" then
		local slider = EnsureSlider(row)
		local formatters = item.format and {
			[MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
				MinimalSliderWithSteppersMixin.Label.Right, item.format),
		}
		slider:Init(item.setting:GetValue(), item.min, item.max, (item.max - item.min) / item.step, formatters)
		slider:Show()
		row.text:SetPoint("LEFT", 6, 0)
		row.text:SetPoint("RIGHT", slider, "LEFT", -6, 0)
	else
		local dropdown = EnsureDropdown(row)
		dropdown:GenerateMenu() -- texte du choix courant
		dropdown:Show()
		row.text:SetPoint("LEFT", 6, 0)
		row.text:SetPoint("RIGHT", dropdown, "LEFT", -6, 0)
	end
	row.filling = false
end

local function BuildPopup(popup)
	local frame = CreateFrame("Frame", "PolypodeOptionsPopup_" .. popup.key, UIParent, "BackdropTemplate")
	frame:SetWidth(WIDTH)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0, 0, 0, 0.92)
	frame:Hide()
	tinsert(UISpecialFrames, frame:GetName()) -- Échap ferme la fenêtre

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 12, -12)
	title:SetPoint("RIGHT", -30, 0)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	title:SetText(popup.title)
	frame.TitleText = title

	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -2, -2)
	frame.CloseButton = closeBtn

	-- « Toutes les options » : panneau complet (Options → AddOns), fenêtre fermée.
	local allBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	allBtn:SetSize(150, 22)
	allBtn:SetPoint("BOTTOM", 0, 10)
	allBtn:SetText("Toutes les options")
	allBtn:SetScript("OnClick", function()
		frame:Hide()
		if popup.category and Settings and Settings.OpenToCategory then
			Settings.OpenToCategory(popup.category:GetID())
		end
	end)
	if P.SkinButton then
		P.SkinButton(allBtn)
	end

	local panel = P.CreatePanel(frame, "")
	panel:SetPoint("TOPLEFT", 6, -32)
	panel:SetPoint("BOTTOMRIGHT", -6, 38)
	panel:SetBackdropColor(0, 0, 0, 0)
	panel:SetBackdropBorderColor(0, 0, 0, 0)
	P.CreateScrollList(panel, function(item)
		return item.setting:GetName()
	end, 4, {
		inset = 4,
		rowHeight = ROW_HEIGHT,
		tooltip = function(item)
			return item.tooltip and { item.setting:GetName(), item.tooltip } or nil
		end,
		decorate = FillRow,
	})
	frame.panel = panel
	P.SkinFrame(frame)
	return frame
end

-- Ouvre / ferme la petite fenêtre d'options popup sous le bouton owner (réglages relus à
-- l'ouverture : ils ont pu changer dans le panneau).
function P.ToggleOptionsPopup(owner, popup)
	if not (popup and popup.items) then
		return
	end
	local frame = popups[popup.key]
	if frame and frame:IsShown() then
		frame:Hide()
		return
	end
	frame = frame or BuildPopup(popup)
	popups[popup.key] = frame
	-- Curseurs seulement si le modèle de Blizzard existe.
	local items = {}
	for _, item in ipairs(popup.items) do
		if item.kind ~= "slider" or MinimalSliderWithSteppersMixin then
			items[#items + 1] = item
		end
	end
	frame:SetHeight(math.min(MAX_HEIGHT, 32 + #items * ROW_HEIGHT + 12 + 38))
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
	frame:Show()
	frame:Raise()
	P.SetListData(frame.panel, items)
end
