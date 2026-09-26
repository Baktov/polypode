-- Polypode: UI_Main — fenêtre principale : BuildUI, RefreshUI, ToggleUI

local P = Polypode
local ui = {}
P.ui = ui

local ROW_HEIGHT = 22

local function CreateRow(parent, index)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(260, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 14, -40 - (index - 1) * ROW_HEIGHT)

	row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.text:SetPoint("LEFT")
	row.text:SetJustifyH("LEFT")

	return row
end

function P.BuildUI()
	if ui.frame then
		return
	end

	local f = CreateFrame("Frame", "PolypodeMainFrame", UIParent, "BackdropTemplate")
	f:SetSize(300, 260)
	f:SetPoint("CENTER")
	f:SetMovable(true)
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

	local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -4, -4)

	ui.frame = f
	ui.rows = {}

	if P.SkinFrame then
		P.SkinFrame(f)
	end
end

function P.RefreshUI()
	if not ui.frame then
		return
	end

	for _, row in ipairs(ui.rows) do
		row:Hide()
	end

	local index = 0
	for key, entry in pairs(P.GetRoster()) do
		index = index + 1
		local row = ui.rows[index] or CreateRow(ui.frame, index)
		ui.rows[index] = row

		local label = key
		if entry.class then
			label = label .. " — " .. entry.class
		end
		if entry.level then
			label = label .. " (" .. entry.level .. ")"
		end
		if P.db.leader == key then
			label = label .. " |cffffd200[leader]|r"
		end

		row.text:SetText(label)
		row:Show()
	end
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
