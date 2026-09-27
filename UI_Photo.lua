-- Polypode: UI_Photo — mode photo : membres du groupe en pied côte à côte, options par clic droit

local P = Polypode

-- Bouton « Photo » de la fenêtre principale ou /poly photo (P.StartPhotoMode) : chaque membre
-- du groupe (soi compris) apparaît en pied, côte à côte. Options (clic droit sur le bouton,
-- P.TogglePhotoOptions ; P.charDb.photo, par personnage) :
--   hideUI — masquer l'interface (UIParent, comme Alt + Z) ;
--   background — fond : voile sombre en dégradé (""), un écran de chargement de WoW
--     (« ls:fichier » ; P.PHOTO_LOADING_SCREENS, UI_PhotoBackgrounds.lua : aucune API ne les
--     liste) ou l'illustration d'un donjon / raid du guide de l'aventurier (« lore:fichier » /
--     « bg:fichier », lu par EJ_GetInstanceByIndex pour chaque extension ; pas les gouffres,
--     absents du guide). Toute image est recadrée sur sa zone utile puis étendue à l'écran sans
--     déformation (CoverTexCoord) ;
--   showName — nom sous chaque personnage, en couleur de classe ;
--   showDetails — classe, spécialisation, niveau et niveau d'objet sous le nom (spé et niveau
--     d'objet des autres membres : état envoyé par leur Polypode, STATUS dans Sync.lua) ;
--   showPets — familiers (chasseur, démoniste, chevalier de la mort...) juste après leur maître
--     (unités pet / partypetN / raidpetN), « Familier de ... » en détails.
-- Molette sur un modèle : zoom avant / arrière ; glisser : le déplacer. Échap revient au jeu (P.StopPhotoMode) ; les
-- autres touches passent au jeu (Impr. écran pour la capture). Hors combat seulement : UIParent ne peut pas être masqué / réaffiché en
-- combat, le mode photo se ferme donc à l'entrée en combat (PLAYER_REGEN_DISABLED, avant le
-- verrouillage). Le cadre n'a pas de parent, pour rester visible quand UIParent est masqué.
-- WoW n'affiche le modèle d'un membre que s'il est visible (à proximité).

local MAX_MODELS = 10 -- au-delà (grand raid), seuls les premiers modèles sont affichés
local HINT_DURATION = 4 -- secondes d'affichage du rappel « Échap »
local ZOOM_STEP = 0.1 -- variation de la distance de caméra par cran de molette
local ZOOM_MIN, ZOOM_MAX = 0.3, 3 -- distance de caméra (1 = en pied)
-- Zone utile des illustrations du guide dans leur texture 512 × 512 (recadrages du guide,
-- Blizzard_EncounterJournal.xml) : { u0, u1, v0, v1, proportions largeur / hauteur }.
local JOURNAL_REGIONS = {
	lore = { 0, 0.76171875, 0, 0.65625, 390 / 336 }, -- loreBG (image de présentation)
	bg = { 0, 0.76953125, 0, 0.830078125, 394 / 425 }, -- dungeonBG (fond des boss)
}
local SCREEN_RATIO = 16 / 9 -- un écran de chargement s'affiche en 16:9, quelle que soit sa texture

local frame, hint, shade, background, optionsFrame
local models = {} -- modèles recyclés : { model, label, details }
local hidUI -- l'interface a été masquée par le mode photo (à réafficher en sortant)

local function PhotoSettings()
	return P.charDb.photo
end

-- Donjons et raids du guide de l'aventurier, par extension (la plus récente d'abord) :
-- { { name, dungeons = { { name, image } }, raids = { ... } } }. Construit une fois par
-- session ; l'extension affichée dans le guide est rétablie ensuite. Vide si le guide
-- n'existe pas (client sans EJ_*).
local journalTiers
local function JournalTiers()
	if journalTiers then
		return journalTiers
	end
	journalTiers = {}
	if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetTierInfo and EJ_GetInstanceByIndex) then
		return journalTiers
	end
	local previous = EJ_GetCurrentTier and EJ_GetCurrentTier()
	for tier = EJ_GetNumTiers(), 1, -1 do
		EJ_SelectTier(tier)
		local entry = { name = EJ_GetTierInfo(tier) or ("Extension " .. tier), dungeons = {}, raids = {} }
		for _, isRaid in ipairs({ false, true }) do
			local list = isRaid and entry.raids or entry.dungeons
			local index = 1
			while true do
				local instanceID, name, _, bgImage, _, loreImage = EJ_GetInstanceByIndex(index, isRaid)
				if not instanceID then
					break
				end
				-- Illustration de présentation (plus large, donc moins recadrée), sinon fond des
				-- boss ; valeur « type:fichier » (cf. JOURNAL_REGIONS).
				local image
				if loreImage and loreImage ~= 0 then
					image = "lore:" .. loreImage
				elseif bgImage and bgImage ~= 0 then
					image = "bg:" .. bgImage
				end
				if name and image then
					list[#list + 1] = { name = name, image = image }
				end
				index = index + 1
			end
		end
		if #entry.dungeons > 0 or #entry.raids > 0 then
			journalTiers[#journalTiers + 1] = entry
		end
	end
	if previous then
		EJ_SelectTier(previous)
	end
	return journalTiers
end

-- Unité du familier d'une unité de groupe (player → pet, partyN → partypetN, raidN → raidpetN).
local function PetUnit(unit)
	if unit == "player" then
		return "pet"
	end
	return (unit:gsub("^(%a+)(%d+)$", "%1pet%2"))
end

-- Unités à afficher dans l'ordre du groupe, soi en premier hors raid ; avec showPets, le
-- familier présent de chacun juste après lui. Renvoie la liste et { [familier] = maître }.
local function GroupUnits()
	local members = {}
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			members[#members + 1] = "raid" .. i
		end
	else
		members[1] = "player"
		for i = 1, GetNumSubgroupMembers() do
			members[#members + 1] = "party" .. i
		end
	end
	local units, owners = {}, {}
	for _, unit in ipairs(members) do
		units[#units + 1] = unit
		local pet = PetUnit(unit)
		if P.charDb.photo.showPets and UnitExists(pet) then
			units[#units + 1] = pet
			owners[pet] = unit
		end
	end
	while #units > MAX_MODELS do
		table.remove(units)
	end
	return units, owners
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
	hint:SetText("Mode photo — glisser un personnage pour le déplacer, molette pour zoomer, "
		.. "Échap pour revenir au jeu, Impr. écran pour une capture")

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
		-- Molette sur le modèle : zoom avant / arrière (distance de caméra), remis en pied à
		-- chaque ouverture du mode photo.
		model:EnableMouseWheel(true)
		model:SetScript("OnMouseWheel", function(self, delta)
			self.zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, (self.zoom or 1) - delta * ZOOM_STEP))
			self:SetCamDistanceScale(self.zoom)
		end)
		-- Clic gauche maintenu : déplace le modèle (son nom et ses détails le suivent) ; il
		-- garde sa place au relâchement, jusqu'à la prochaine ouverture du mode photo.
		model:EnableMouse(true)
		model:SetMovable(true)
		model:SetClampedToScreen(true)
		model:RegisterForDrag("LeftButton")
		model:SetScript("OnDragStart", model.StartMoving)
		model:SetScript("OnDragStop", model.StopMovingOrSizing)
		local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
		label:SetWordWrap(false)
		local details = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		details:SetWordWrap(false)
		models[i] = { model = model, label = label, details = details }
	end
	return models[i]
end

-- Écran de chargement « ls:fichier » : { u0, u1, v0, v1, proportions } de sa zone utile, ou nil.
local function LoadingScreenRegion(file)
	for _, group in ipairs(P.PHOTO_LOADING_SCREENS) do
		for _, item in ipairs(group.items) do
			if item[2] == file then
				local u0, u1, v0, v1 = item[3] or 0, item[4] or 1, item[5] or 0, item[6] or 1
				return { u0, u1, v0, v1, SCREEN_RATIO * (u1 - u0) / (v1 - v0) }
			end
		end
	end
end

-- Image de fond choisie : fichier et zone utile, ou nil (voile seul). Valeurs « ls:fichier »
-- (écran de chargement), « lore:fichier » / « bg:fichier » (guide ; un nombre seul : ancien
-- réglage, fond des boss). Les anciens noms d'écrans de chargement donnent nil.
local function BackgroundImage(value)
	if type(value) == "number" then
		return value, JOURNAL_REGIONS.bg
	end
	local kind, file = tostring(value):match("^(%a+):(%d+)$")
	file = tonumber(file)
	if kind == "ls" then
		local region = LoadingScreenRegion(file)
		if region then
			return file, region
		end
	elseif kind and JOURNAL_REGIONS[kind] then
		return file, JOURNAL_REGIONS[kind]
	end
end

-- Remplit l'écran avec la zone utile d'une image sans la déformer : agrandie jusqu'à couvrir
-- l'écran, le surplus (haut et bas, ou côtés) est coupé au centre.
local function CoverTexCoord(region)
	local u0, u1, v0, v1, imageRatio = unpack(region)
	local screenRatio = frame:GetWidth() / frame:GetHeight()
	if imageRatio < screenRatio then
		local keep = (v1 - v0) * imageRatio / screenRatio
		local middle = (v0 + v1) / 2
		v0, v1 = middle - keep / 2, middle + keep / 2
	else
		local keep = (u1 - u0) * screenRatio / imageRatio
		local middle = (u0 + u1) / 2
		u0, u1 = middle - keep / 2, middle + keep / 2
	end
	return u0, u1, v0, v1
end

local function ApplyBackground()
	local file, region = BackgroundImage(PhotoSettings().background)
	if file then
		background:SetTexture(file)
		background:SetTexCoord(CoverTexCoord(region))
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
	local units, owners = GroupUnits()
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
		model.zoom = 1
		model:SetCamDistanceScale(1)
		model:Show()

		local owner = owners[unit]
		local text
		if owner then
			-- Familier : son nom en blanc.
			text = UnitName(unit) or "?"
		else
			local firstName, _, surname = P.UnitNameParts(unit)
			local name = P.JoinSurname(firstName, surname)
			local _, class = UnitClass(unit)
			local color = class and C_ClassColor and C_ClassColor.GetClassColor(class)
			text = name or "?"
			if color and name then
				text = color:WrapTextInColorCode(name)
			end
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
		if owner then
			local ownerName, _, ownerSurname = P.UnitNameParts(owner)
			details:SetText("Familier de " .. (P.JoinSurname(ownerName, ownerSurname) or "?"))
		else
			details:SetText(DetailsText(unit))
		end
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
	optionsFrame:SetSize(280, 216)
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
	local petsCheck = CreateCheck(optionsFrame, "Afficher les familiers (chasseur, démoniste...)",
		"showPets", detailsCheck)

	-- Fond : voile sombre ou un écran de chargement (menu Blizzard, défilant).
	local bgLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	bgLabel:SetPoint("TOPLEFT", petsCheck, "BOTTOMLEFT", 4, -10)
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
	-- Sous-menus : écrans de chargement, puis donjons et raids du guide par extension.
	local function AddRadios(menu, items)
		menu:SetScrollMode(320)
		for _, item in ipairs(items) do
			menu:CreateRadio(item.name, IsSelected, SetSelected, item.image)
		end
	end
	dropdown:SetupMenu(function(_, root)
		root:SetScrollMode(360)
		root:CreateRadio("Voile sombre (sans image)", IsSelected, SetSelected, "")
		-- Écrans de chargement par extension ; sur WoW Forever, son groupe vient en premier.
		local loading = root:CreateButton("Écrans de chargement")
		local isForever = (select(4, GetBuildInfo()) or 0) >= 16000 and (select(4, GetBuildInfo()) or 0) < 20000
		local groups = {}
		for _, group in ipairs(P.PHOTO_LOADING_SCREENS) do
			if isForever and group.name == "WoW Forever" then
				table.insert(groups, 1, group)
			else
				groups[#groups + 1] = group
			end
		end
		for _, group in ipairs(groups) do
			local groupMenu = loading:CreateButton(group.name)
			groupMenu:SetScrollMode(320)
			for _, item in ipairs(group.items) do
				groupMenu:CreateRadio(item[1], IsSelected, SetSelected, "ls:" .. item[2])
			end
		end
		for _, tier in ipairs(JournalTiers()) do
			local tierMenu = root:CreateButton(tier.name)
			if #tier.dungeons > 0 then
				AddRadios(tierMenu:CreateButton("Donjons"), tier.dungeons)
			end
			if #tier.raids > 0 then
				AddRadios(tierMenu:CreateButton("Raids"), tier.raids)
			end
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
