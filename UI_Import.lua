-- Polypode: UI_Import — fenêtre d'import d'une liste de personnages (/poly import)

local P = Polypode
local L = P.L

-- Ouverte par /poly import ou le bouton « Importer des personnages » du panneau d'options.
-- Zone de texte défilante où coller les lignes produites par tools/import_bnet.py, ou les
-- taper à la main, une par personnage :
--     Nom-Royaume;CLASSE;niveau;compte;BattleTag
-- Seul le nom est obligatoire (sans royaume : celui du personnage connecté) ; lignes vides et
-- lignes commençant par « # » ignorées. Chaque personnage inconnu est ajouté au roster
-- (P.ImportCharacter, partagé avec les autres Polypode) ; un personnage connu ou retiré n'est
-- pas touché, sauf pour lui donner le compte WoW indiqué s'il n'en a pas encore
-- (P.SetCharacterAccount). Compte rendu sous la zone de texte. Échap ferme la fenêtre.

local FRAME_WIDTH, FRAME_HEIGHT = 540, 420

local frame, editBox, statusText

-- Personnage décrit par une ligne, ou nil si la ligne n'est pas lisible.
local function ParseLine(line)
	local key, class, level, account, battleTag = strsplit(";", line)
	key = strtrim(key or "")
	local name, realm = key:match("^([^%-%s]+)%-(.+)$")
	if not name then
		name, realm = key:match("^([^%-%s]+)$"), GetRealmName()
	end
	if not name then
		return nil
	end
	class = strtrim(class or ""):upper()
	account = strtrim(account or "")
	return {
		name = name,
		realm = strtrim(realm),
		class = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] and class or nil,
		level = tonumber(strtrim(level or "")),
		account = account ~= "" and account or nil,
		token = P.TokenForBattleTag and P.TokenForBattleTag(strtrim(battleTag or "")) or nil,
	}
end

-- Importe le texte collé ; renvoie les compteurs et les numéros des lignes refusées.
local function ImportText(text)
	local result = { added = 0, known = 0, removed = 0, accounts = 0, refused = {} }
	local lineNumber = 0
	for raw in (text .. "\n"):gmatch("(.-)\r?\n") do
		lineNumber = lineNumber + 1
		local line = strtrim(raw)
		if line ~= "" and not line:find("^#") then
			local data = ParseLine(line)
			if data then
				local state, key = P.ImportCharacter(data.name, data.realm, data.class, data.level, data.token)
				result[state] = result[state] + 1
				if state ~= "removed" and data.account and not P.GetCharacterAccount(key) then
					P.SetCharacterAccount(key, data.account)
					result.accounts = result.accounts + 1
				end
			else
				result.refused[#result.refused + 1] = lineNumber
			end
		end
	end
	return result
end

-- Compte rendu affiché sous la zone de texte.
local function FormatResult(result)
	local parts = {
		"|cff33ff33" .. L["%d ajouté(s)"]:format(result.added) .. "|r",
		L["%d déjà connu(s)"]:format(result.known),
	}
	if result.removed > 0 then
		parts[#parts + 1] = L["%d retiré(s), ignoré(s)"]:format(result.removed)
	end
	if result.accounts > 0 then
		parts[#parts + 1] = L["%d rangé(s) dans un compte"]:format(result.accounts)
	end
	local text = table.concat(parts, ", ") .. "."
	if #result.refused > 0 then
		local shown = {}
		for i = 1, math.min(#result.refused, 10) do
			shown[i] = result.refused[i]
		end
		text = text .. "\n|cffff6060" .. L["Lignes illisibles : %s"]:format(table.concat(shown, ", "))
			.. (#result.refused > 10 and "..." or "") .. "|r"
	end
	return text
end

local function OnImport()
	local result = ImportText(editBox:GetText())
	statusText:SetText(FormatResult(result))
	if result.added > 0 or result.accounts > 0 then
		P.RefreshUI()
		UIErrorsFrame:AddMessage(L["Polypode : %d personnage(s) importé(s)."]:format(result.added), 1, 0.82, 0)
	end
end

local function AddButton(text, width, tooltipTitle, tooltipText, onClick)
	local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	button:SetSize(width, 24)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(tooltipTitle)
		GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
		P.ShowTooltip()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	P.SkinButton(button)
	return button
end

local function Build()
	frame = CreateFrame("Frame", "PolypodeImportFrame", UIParent, "BackdropTemplate")
	frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG") -- au-dessus du panneau d'options
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0, 0, 0, 0.9)
	frame:Hide()
	tinsert(UISpecialFrames, "PolypodeImportFrame") -- Échap ferme la fenêtre

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -14)
	title:SetText(L["Importer des personnages"])
	frame.TitleText = title

	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -4, -4)
	frame.CloseButton = closeBtn

	local help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	help:SetPoint("TOPLEFT", 16, -40)
	help:SetPoint("RIGHT", -16, 0)
	help:SetJustifyH("LEFT")
	help:SetText(L["Collez (Ctrl+V) les lignes du fichier polypode_import.txt produit par "
		.. "Polypode\\tools\\import_bnet.py, ou tapez une ligne par personnage : "
		.. "|cffffd200Nom-Royaume;CLASSE;niveau;compte|r (seul le nom est obligatoire). "
		.. "Les personnages déjà connus ne sont pas modifiés : importer deux fois la même liste "
		.. "ne crée aucun doublon."])

	local panel = P.CreatePanel(frame, L["Lignes à importer"])
	panel:SetPoint("TOPLEFT", 12, -100)
	panel:SetPoint("BOTTOMRIGHT", -12, 76)

	local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, -28)
	scroll:SetPoint("BOTTOMRIGHT", -30, 8)

	editBox = CreateFrame("EditBox", nil, scroll)
	editBox:SetMultiLine(true)
	editBox:SetAutoFocus(false)
	editBox:SetMaxLetters(0)
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetWidth(FRAME_WIDTH - 76)
	editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
	-- Le défilement suit le curseur (fonctions de Blizzard, InputBoxTemplates.lua).
	if ScrollingEdit_OnCursorChanged and ScrollingEdit_OnUpdate then
		editBox:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
		editBox:SetScript("OnUpdate", function(self, elapsed)
			ScrollingEdit_OnUpdate(self, elapsed, scroll)
		end)
	end
	scroll:SetScrollChild(editBox)
	scroll:SetScript("OnSizeChanged", function(self, width)
		editBox:SetWidth(width)
	end)
	-- Un clic n'importe où dans la zone donne la saisie au texte (même vide).
	scroll:EnableMouse(true)
	scroll:SetScript("OnMouseDown", function()
		editBox:SetFocus()
	end)

	statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	statusText:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 4, -8)
	statusText:SetPoint("RIGHT", -16, 0)
	statusText:SetJustifyH("LEFT")

	local importButton = AddButton(L["Importer"], 110, L["Importer"],
		L["Ajoute au roster les personnages inconnus de la liste et les partage avec vos autres "
		.. "Polypode ; un personnage déjà connu n'est pas modifié (il reçoit seulement le compte "
		.. "WoW indiqué s'il n'en a pas)."], OnImport)
	importButton:SetPoint("BOTTOMRIGHT", -14, 14)

	local clearButton = AddButton(L["Effacer"], 90, L["Effacer"], L["Vide la zone de texte."], function()
		editBox:SetText("")
		statusText:SetText("")
		editBox:SetFocus()
	end)
	clearButton:SetPoint("RIGHT", importButton, "LEFT", -8, 0)

	P.ui.importFrame = frame
	P.SkinFrame(frame)
	P.SkinPanel(panel)
end

-- Ouvre la fenêtre d'import (/poly import, bouton du panneau d'options), saisie prête à coller.
function P.ShowImportWindow()
	if not frame then
		Build()
	end
	frame:Show()
	frame:Raise()
	editBox:SetFocus()
end
