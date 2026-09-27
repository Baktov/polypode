-- Polypode: UI_Photo — mode photo : interface masquée, membres du groupe en pied côte à côte

local P = Polypode

-- Bouton « Photo » de la fenêtre principale ou /poly photo (P.StartPhotoMode) : l'interface
-- est masquée (UIParent, comme Alt + Z) et chaque membre du groupe (soi compris) apparaît en
-- pied, côte à côte, avec son nom en couleur de classe, sur un voile sombre en dégradé.
-- Échap revient au jeu (P.StopPhotoMode) ; les autres touches passent au jeu (Impr. écran
-- pour la capture). Hors combat seulement : UIParent ne peut pas être masqué / réaffiché en
-- combat, le mode photo se ferme donc à l'entrée en combat (PLAYER_REGEN_DISABLED, avant le
-- verrouillage). Le cadre n'a pas de parent, pour rester visible quand UIParent est masqué.
-- WoW n'affiche le modèle d'un membre que s'il est visible (à proximité).

local MAX_MODELS = 10 -- au-delà (grand raid), seuls les premiers membres sont affichés
local HINT_DURATION = 4 -- secondes d'affichage du rappel « Échap »

local frame, hint
local models = {} -- modèles recyclés : { model, label }

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

local function Build()
	frame = CreateFrame("Frame", nil, nil) -- sans parent : visible quand UIParent est masqué
	frame:SetAllPoints(WorldFrame)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:EnableKeyboard(true)
	frame:Hide()

	-- Voile sombre en dégradé, plus dense en bas (sous les noms).
	local shade = frame:CreateTexture(nil, "BACKGROUND")
	shade:SetAllPoints()
	shade:SetColorTexture(1, 1, 1, 1)
	shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.75), CreateColor(0, 0, 0, 0.25))

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

-- Modèle n° i (créé au premier besoin).
local function GetModel(i)
	if not models[i] then
		local model = CreateFrame("PlayerModel", nil, frame)
		local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
		label:SetPoint("TOP", model, "BOTTOM", 0, -8)
		label:SetWordWrap(false)
		models[i] = { model = model, label = label }
	end
	return models[i]
end

-- Place un modèle par membre, sur toute la largeur de l'écran.
local function LayoutModels()
	local units = GroupUnits()
	local width, height = frame:GetWidth(), frame:GetHeight()
	local slot = width / #units
	for i, unit in ipairs(units) do
		local entry = GetModel(i)
		local model, label = entry.model, entry.label
		model:ClearAllPoints()
		model:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (i - 1) * slot, height * 0.12)
		model:SetSize(slot, height * 0.78)
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
		label:SetWidth(slot - 10)
		label:SetText(text)
		label:Show()
	end
	for i = #units + 1, #models do
		models[i].model:Hide()
		models[i].label:Hide()
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
	UIParent:Hide()
	frame:Show()
	LayoutModels()
	hint:Show()
	C_Timer.After(HINT_DURATION, function()
		if hint then
			hint:Hide()
		end
	end)
end

-- Ferme le mode photo et réaffiche l'interface (Échap, entrée en combat).
function P.StopPhotoMode()
	if not frame or not frame:IsShown() then
		return
	end
	frame:Hide()
	for _, entry in ipairs(models) do
		entry.model:ClearModel()
	end
	UIParent:Show()
end
