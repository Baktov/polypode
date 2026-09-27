-- Polypode: UI_Photo — mode photo : membres du groupe en pied côte à côte, options par clic droit

local P = Polypode

-- Bouton « Photo » de la fenêtre principale ou /poly photo (P.StartPhotoMode) : chaque membre
-- du groupe (soi compris) apparaît en pied, côte à côte. Options (clic droit sur le bouton,
-- P.TogglePhotoOptions ; P.charDb.photo, par personnage) :
--   hideUI — masquer l'interface (UIParent, comme Alt + Z) ;
--   background — fond : voile sombre en dégradé ("") ou un écran de chargement de WoW
--     (BACKGROUNDS : chemins et recadrages repris de l'addon Details!, aucune API ne les liste) ;
--   showName — nom sous chaque personnage, en couleur de classe ;
--   showDetails — classe, spécialisation, niveau et niveau d'objet sous le nom (spé et niveau
--     d'objet des autres membres : état envoyé par leur Polypode, STATUS dans Sync.lua).
-- Échap revient au jeu (P.StopPhotoMode) ; les autres touches passent au jeu (Impr. écran
-- pour la capture). Hors combat seulement : UIParent ne peut pas être masqué / réaffiché en
-- combat, le mode photo se ferme donc à l'entrée en combat (PLAYER_REGEN_DISABLED, avant le
-- verrouillage). Le cadre n'a pas de parent, pour rester visible quand UIParent est masqué.
-- WoW n'affiche le modèle d'un membre que s'il est visible (à proximité).

local MAX_MODELS = 10 -- au-delà (grand raid), seuls les premiers membres sont affichés
local HINT_DURATION = 4 -- secondes d'affichage du rappel « Échap »
local LOADING_SCREENS = "Interface\\Glues\\LoadingScreens\\"

-- Écrans de chargement proposés en fond : { libellé, fichier, recadrage (bandes retirées) }.
local BACKGROUNDS = {
	{ "Goulet des Chanteguerres", "LoadScreenWarsongGulch", { 0, 1, 121 / 512, 484 / 512 } },
	{ "Bassin Arathi", "LoadscreenArathiBasin", { 0, 1, 126 / 512, 430 / 512 } },
	{ "Vallée d'Alterac", "LoadScreenPvpBattleground", { 0, 1, 127 / 512, 500 / 512 } },
	{ "L'Œil du cyclone", "LoadScreenNetherBattlegrounds", { 0, 1, 142 / 512, 466 / 512 } },
	{ "Rivage des Anciens", "LoadScreenNorthrendBG", { 0, 1, 302 / 1024, 879 / 1024 } },
	{ "Île des Conquérants", "LOADSCREENISLEOFCONQUEST", { 0, 1, 297 / 1024, 878 / 1024 } },
	{ "Bataille de Gilnéas", "LoadScreenGilneasBG2", { 0, 1, 281 / 1024, 878 / 1024 } },
	{ "Pics-Jumeaux", "LoadScreenTwinPeaksBG", { 0, 1, 294 / 1024, 876 / 1024 } },
	{ "Mines d'Éclargent", "LoadScreenSilvershardMines", { 0, 1, 251 / 1024, 840 / 1024 } },
	{ "Temple de Kotmogu", "LoadScreenValleyofPower", { 0, 1, 257 / 1024, 839 / 1024 } },
	{ "Gorge du Vent-Profond", "LoadScreen_GoldRush", { 0, 1, 264 / 1024, 840 / 1024 } },
	{ "Arène des Tranchantes", "LoadScreenBladesEdgeArena", { 0, 1, 0.29296875, 0.9375 } },
	{ "Arène des égouts de Dalaran", "LoadScreenDalaranSewersArena", { 0, 1, 0.29296875, 0.857421875 } },
	{ "Cercle des Épreuves (Nagrand)", "LoadScreenNagrandArenaBattlegrounds", { 0, 1, 0.341796875, 1 } },
	{ "Ruines de Lordaeron", "LoadScreenRuinsofLordaeronBattlegrounds", { 0, 1, 0.341796875, 1 } },
	{ "Arène de Tol'vir", "LoadScreenTolvirArena", { 0, 1, 0.29296875, 0.857421875 } },
	{ "Pic du Tigre", "LoadingScreen_Shadowpan_bg", { 0, 1, 0.29296875, 0.857421875 } },
	{ "Chute de Crin-de-Frêne (Val'sharah)", "LoadingScreen_ArenaValSharah_wide", { 0, 1, 0.29296875, 0.857421875 } },
	{ "Bastion du Freux", "LoadingScreen_BlackrookHoldArena_wide", { 0, 1, 0.29296875, 0.857421875 } },
}

local frame, hint, shade, background, optionsFrame
local models = {} -- modèles recyclés : { model, label, details }
local hidUI -- l'interface a été masquée par le mode photo (à réafficher en sortant)

local function PhotoSettings()
	return P.charDb.photo
end

local function FindBackground(file)
	for _, bg in ipairs(BACKGROUNDS) do
		if bg[2] == file then
			return bg
		end
	end
end

-- Unités du groupe dans l'ordre du groupe, soi en premier hors raid.
local function GroupUnits()
	local units = {}
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			units[#units + 1] = "raid" .. i
		end
	else
		units[1] = "player"
		for i = 1, GetNumSubgroupMembers() do
			units[#units + 1] = "party" .. i
		end
	end
	while #units > MAX_MODELS do
		table.remove(units)
	end
	return units
end

-- Clé de roster d'une unité (royaumes comparés sans espaces : UnitName n'en a pas), ou nil.
local function KeyForUnit(unit)
	local name, realm = P.UnitNameParts(unit)
	if not name or (issecretvalue and issecretvalue(name)) then
		return nil
	end
	local wanted = (name .. "-" .. (realm or GetRealmName())):gsub("%s", "")
	for key in pairs(P.db.roster) do
		if key:gsub("%s", "") == wanted then
			return key
		end
	end
end

-- « Classe (Spé) · niv. N · ilvl N » d'une unité ; spé et niveau d'objet des autres membres
-- selon l'état reçu de leur Polypode (absents sinon).
local function DetailsText(unit)
	local parts = {}
	local className = UnitClass(unit)
	local key = KeyForUnit(unit)
	local status = key and P.GetCharacterStatus(key)
	local class = className or ""
	if status and status.spec then
		class = class .. " (" .. status.spec .. ")"
	end
	if class ~= "" then
		parts[#parts + 1] = class
	end
	local level = UnitLevel(unit)
	if level and level > 0 then
		parts[#parts + 1] = "niv. " .. level
	end
	if status and status.ilvl and status.ilvl > 0 then
		parts[#parts + 1] = "ilvl " .. status.ilvl
	end
	return table.concat(parts, " · ")
end

local function Build()
	frame = CreateFrame("Frame", nil, nil) -- sans parent : visible quand UIParent est masqué
	frame:SetAllPoints(WorldFrame)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:EnableKeyboard(true)
	frame:Hide()

	-- Fond : écran de chargement choisi (plein écran), masqué pour le voile seul.
	background = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
	background:SetAllPoints()

	-- Voile sombre en dégradé, plus dense en bas (sous les noms) ; plus léger sur un fond.
	shade = frame:CreateTexture(nil, "BACKGROUND")
	shade:SetAllPoints()
	shade:SetColorTexture(1, 1, 1, 1)

	hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	hint:SetPoint("TOP", 0, -30)
	hint:SetText("Mode photo — Échap pour revenir au jeu, Impr. écran pour une capture")

	-- Échap ferme le mode photo et n'atteint pas le jeu (pas de menu) ; les autres touches
	-- passent au jeu.
	frame:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			self:SetPropagateKeyboardInput(false)
			P.StopPhotoMode()
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)

	P.ui.photoFrame = frame
end

-- Modèle n° i (créé au premier besoin), avec son nom et sa ligne de détails.
local function GetModel(i)
	if not models[i] then
		local model = CreateFrame("PlayerModel", nil, frame)
		local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
		label:SetWordWrap(false)
		local details = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		details:SetWordWrap(false)
		models[i] = { model = model, label = label, details = details }
	end
	return models[i]
end

local function ApplyBackground()
	local bg = FindBackground(PhotoSettings().background)
	if bg then
		background:SetTexture(LOADING_SCREENS .. bg[2])
		background:SetTexCoord(unpack(bg[3]))
		background:Show()
		shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.6), CreateColor(0, 0, 0, 0))
	else
		background:Hide()
		shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.75), CreateColor(0, 0, 0, 0.25))
	end
end

-- Place un modèle par membre, sur toute la largeur de l'écran, avec nom et détails en dessous
-- selon les options.
local function LayoutModels()
	local settings = PhotoSettings()
	local units = GroupUnits()
	local width, height = frame:GetWidth(), frame:GetHeight()
	local slot = width / #units
	local bottom = height * ((settings.showName or settings.showDetails) and 0.14 or 0.05)
	for i, unit in ipairs(units) do
		local entry = GetModel(i)
		local model, label, details = entry.model, entry.label, entry.details
		model:ClearAllPoints()
		model:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (i - 1) * slot, bottom)
		model:SetSize(slot, height * 0.8)
		model:ClearModel()
		model:SetUnit(unit)
		model:SetPortraitZoom(0) -- en pied, pas en portrait
		model:SetCamDistanceScale(1)
		model:Show()

		local firstName, _, surname = P.UnitNameParts(unit)
		local name = P.JoinSurname(firstName, surname)
		local _, class = UnitClass(unit)
		local color = class and C_ClassColor and C_ClassColor.GetClassColor(class)
		local text = name or "?"
		if color and name then
			text = color:WrapTextInColorCode(name)
		end
		if not UnitIsVisible(unit) then
			text = text .. " |cff999999(hors de vue)|r"
		end
		label:ClearAllPoints()
		label:SetPoint("TOP", model, "BOTTOM", 0, -8)
		label:SetWidth(slot - 10)
		label:SetText(text)
		label:SetShown(settings.showName)

		details:ClearAllPoints()
		if settings.showName then
			details:SetPoint("TOP", label, "BOTTOM", 0, -4)
		else
			details:SetPoint("TOP", model, "BOTTOM", 0, -8)
		end
		details:SetWidth(slot - 10)
		details:SetText(DetailsText(unit))
		details:SetShown(settings.showDetails)
	end
	for i = #units + 1, #models do
		models[i].model:Hide()
		models[i].label:Hide()
		models[i].details:Hide()
	end
end

function P.StartPhotoMode()
	if InCombatLockdown() then
		UIErrorsFrame:AddMessage("Mode photo impossible en combat.", 1, 0.1, 0.1)
		return
	end
	if not frame then
		Build()
	end
	if frame:IsShown() then
		return
	end
	if optionsFrame then
		optionsFrame:Hide()
	end
	hidUI = PhotoSettings().hideUI and UIParent:IsShown()
	if hidUI then
		UIParent:Hide()
	end
	ApplyBackground()
	frame:Show()
	LayoutModels()
	hint:Show()
	C_Timer.After(HINT_DURATION, function()
		if hint then
			hint:Hide()
		end
	end)
end

-- Ferme le mode photo et réaffiche l'interface si elle a été masquée (Échap, entrée en combat).
function P.StopPhotoMode()
	if not frame or not frame:IsShown() then
		return
	end
	frame:Hide()
	for _, entry in ipairs(models) do
		entry.model:ClearModel()
	end
	if hidUI then
		UIParent:Show()
		hidUI = nil
	end
end

-- OPTIONS (clic droit sur le bouton « Photo ») -----------------------------------------

local function CreateCheck(parent, label, field, anchor)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	local text = check.Text or check.text
	if text then
		text:SetText(label)
		text:SetFontObject("GameFontHighlight")
	end
	check:SetChecked(PhotoSettings()[field])
	check:SetScript("OnClick", function(self)
		PhotoSettings()[field] = self:GetChecked() and true or false
	end)
	return check
end

local function BuildOptions()
	optionsFrame = CreateFrame("Frame", "PolypodePhotoOptions", UIParent, "BackdropTemplate")
	optionsFrame:SetSize(280, 190)
	optionsFrame:SetFrameStrata("DIALOG")
	optionsFrame:EnableMouse(true)
	optionsFrame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	optionsFrame:SetBackdropColor(0, 0, 0, 0.9)
	optionsFrame:Hide()
	tinsert(UISpecialFrames, "PolypodePhotoOptions") -- Échap ferme la fenêtre

	local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 12, -12)
	title:SetText("Options du mode photo")
	optionsFrame.TitleText = title

	local closeBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -2, -2)
	optionsFrame.CloseButton = closeBtn

	-- Ancrée au cadre, pas au titre : le skin EllesmereUI recentre le titre dans sa barre.
	local hideCheck = CreateCheck(optionsFrame, "Masquer l'interface", "hideUI", title)
	hideCheck:ClearAllPoints()
	hideCheck:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 10, -34)
	local nameCheck = CreateCheck(optionsFrame, "Afficher le nom des personnages", "showName", hideCheck)
	local detailsCheck = CreateCheck(optionsFrame, "Afficher classe, spé, niveau et niveau d'objet",
		"showDetails", nameCheck)

	-- Fond : voile sombre ou un écran de chargement (menu Blizzard, défilant).
	local bgLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	bgLabel:SetPoint("TOPLEFT", detailsCheck, "BOTTOMLEFT", 4, -10)
	bgLabel:SetText("Fond :")

	local dropdown = CreateFrame("DropdownButton", nil, optionsFrame, "WowStyle1DropdownTemplate")
	dropdown:SetPoint("LEFT", bgLabel, "RIGHT", 8, 0)
	dropdown:SetPoint("RIGHT", optionsFrame, "RIGHT", -12, 0)
	local function IsSelected(file)
		return PhotoSettings().background == file
	end
	local function SetSelected(file)
		PhotoSettings().background = file
	end
	dropdown:SetupMenu(function(_, root)
		root:SetScrollMode(320)
		root:CreateRadio("Voile sombre (sans image)", IsSelected, SetSelected, "")
		for _, bg in ipairs(BACKGROUNDS) do
			root:CreateRadio(bg[1], IsSelected, SetSelected, bg[2])
		end
	end)

	P.ui.photoOptions = optionsFrame
	P.SkinFrame(optionsFrame)
end

-- Ouvre / ferme la fenêtre d'options du mode photo, sous le bouton owner.
function P.TogglePhotoOptions(owner)
	if not optionsFrame then
		BuildOptions()
	end
	if optionsFrame:IsShown() then
		optionsFrame:Hide()
		return
	end
	optionsFrame:ClearAllPoints()
	optionsFrame:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -4)
	optionsFrame:Show()
end
