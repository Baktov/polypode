-- Polypode Modele: Modele — squelette d'addon compagnon de Polypode (exemple : zone de chaque personnage)

local _, ns = ...
local P = Polypode -- dépendance obligatoire (## Dependencies: Polypode), chargée avant nous

-- MODÈLE À COPIER (voir LISEZMOI.txt) : remplacer partout « Modele » / « modele » / « MODELE » par
-- le nom du module, puis remplacer l'exemple par la vraie fonction. Chaque branchement sur
-- Polypode est montré une fois et passe par son API publique, testée avant usage :
--   bouton « Modele » dans la barre de titre de Polypode (P.AddTitleButton) et /poly modele
--   (P.RegisterSlashCommand) ; fenêtre à liste défilante (P.CreatePanel, P.CreateScrollList,
--   P.SetListData) habillée par le skin (P.SkinFrame, P.SkinPanel) ; option dans Options → AddOns →
--   Polypode → Modele (sous-catégorie de P.optionsCategory) ; synchro entre clients : message
--   MODELE:token:nom-royaume:zone (P.RegisterMessageHandler, expéditeur vérifié par P.IsSender),
--   envoyé à chaque client qui s'annonce (P.RegisterPeerCallback) et à chaque changement de zone
--   (P.WhisperOnline) ; données sauvegardées par personnage dans PolypodeModeleData (fichier de
--   compte), oubliées quand le personnage est supprimé dans Polypode (P.RegisterCharacterData).
-- Exemple : la fenêtre liste les personnages du roster avec leur zone actuelle (GetRealZoneText).

local MESSAGE_TYPE = "MODELE" -- type de message propre au module (ne pas réutiliser celui d'un autre)
local SEND_DELAY = 2 -- secondes : regroupe les changements de zone rapprochés

-- Options par personnage (PolypodeModeleDB), complétées à ADDON_LOADED.
local DEFAULTS = {
	showRealm = false, -- royaume affiché à côté du nom
}

local data = {} -- [nom-royaume] = { zone = texte, at = heure serveur } ; = PolypodeModeleData
local frame, listPanel
local sendPending

local function ModeleSettings()
	return PolypodeModeleDB or DEFAULTS
end

-- LECTURE ET SYNCHRO ------------------------------------------------------------------------

local function OwnZone()
	return GetRealZoneText and GetRealZoneText() or ""
end

-- Enregistre la zone d'un personnage et rafraîchit la fenêtre.
local function StoreZone(key, zone)
	data[key] = { zone = zone, at = GetServerTime() }
	if P.RefreshModele then
		P.RefreshModele()
	end
end

-- Envoie la zone du personnage joué à target, sinon aux clients connectés. Le message ne doit pas
-- dépasser P.MAX_MESSAGE_LENGTH (fragmenter s'il peut grandir, comme Polypode Suivi).
local function SendOwn(target)
	local token = P.GetTeamToken and P.GetTeamToken()
	local zone = OwnZone()
	StoreZone(P.GetCharKey(), zone)
	if not token or not P.WhisperOnline then
		return
	end
	local message = string.format("%s:%s:%s:%s", MESSAGE_TYPE, token, P.GetCharKey(), zone)
	P.WhisperOnline(message:sub(1, P.MAX_MESSAGE_LENGTH or 255), target)
end

-- Message reçu (token déjà vérifié par Polypode) : rest = « nom-royaume:zone ».
local function OnMessage(rest, sender)
	local key, zone = strsplit(":", rest or "", 2)
	if key and P.IsSender and P.IsSender(sender, key) then
		StoreZone(key, zone or "")
	end
end

-- FENÊTRE -------------------------------------------------------------------------------------

local function BuildItems()
	local keys = {}
	for key, entry in pairs(P.db.roster or {}) do
		if not entry.removed then
			keys[key] = true
		end
	end
	return P.SortedKeyItems(keys, function(key)
		return key == P.GetCharKey() -- personnage joué en tête
	end)
end

local function FormatItem(item)
	local known = data[item.key]
	local name = P.GetDisplayName(item.key, ModeleSettings().showRealm)
	if not known then
		return name .. "  |cff999999pas d'infos|r"
	end
	return name .. "  |cffffd200" .. (known.zone ~= "" and known.zone or "?") .. "|r"
end

local function ItemTooltip(item)
	local known = data[item.key]
	local lines = { P.GetDisplayName(item.key, true) }
	lines[#lines + 1] = known and ("Zone : " .. known.zone) or "|cff999999Pas d'infos (module absent ou pas encore reçu).|r"
	if known and item.key ~= P.GetCharKey() then
		lines[#lines + 1] = "|cff999999Reçu le " .. date("%d/%m à %H:%M", known.at) .. "|r"
	end
	return lines
end

local function Build()
	frame = CreateFrame("Frame", "PolypodeModeleFrame", UIParent, "BackdropTemplate")
	frame:SetSize(420, 300)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
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
	tinsert(UISpecialFrames, "PolypodeModeleFrame") -- Échap ferme la fenêtre

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -14)
	title:SetText("Polypode Modele")
	frame.TitleText = title

	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -4, -4)
	frame.CloseButton = closeBtn

	listPanel = P.CreatePanel(frame, "Zone actuelle des personnages")
	listPanel:SetPoint("TOPLEFT", 12, -36)
	listPanel:SetPoint("BOTTOMRIGHT", -12, 12)
	P.CreateScrollList(listPanel, FormatItem, nil, { tooltip = ItemTooltip })

	P.ui.modeleFrame = frame
	P.ui.modelePanel = listPanel
	if P.SkinFrame then
		P.SkinFrame(frame)
	end
	if P.SkinPanel then
		P.SkinPanel(listPanel)
	end
end

-- Remplit la liste, si la fenêtre est ouverte.
function P.RefreshModele()
	if not frame or not frame:IsShown() then
		return
	end
	P.SetListData(listPanel, BuildItems())
end

-- Ouvre / ferme la fenêtre (bouton « Modele », /poly modele).
function P.ToggleModele()
	if not frame then
		Build()
	end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
		P.RefreshModele()
	end
end

-- OPTIONS : sous-catégorie « Modele » du panneau de Polypode (P.optionsCategory, créée à son
-- PLAYER_LOGIN), ou catégorie « Polypode Modele » à part si elle manque.
local function BuildSettingsPanel()
	if not (Settings and Settings.RegisterProxySetting) then
		return
	end
	local category
	if P.optionsCategory and Settings.RegisterVerticalLayoutSubcategory then
		category = Settings.RegisterVerticalLayoutSubcategory(P.optionsCategory, "Modele")
	else
		category = Settings.RegisterVerticalLayoutCategory("Polypode Modele")
	end
	local setting = Settings.RegisterProxySetting(category, "POLYPODE_MODELE_SHOW_REALM",
		Settings.VarType.Boolean, "Afficher le royaume", DEFAULTS.showRealm,
		function()
			return ModeleSettings().showRealm
		end,
		function(value)
			ModeleSettings().showRealm = value
			P.RefreshModele()
		end)
	Settings.CreateCheckbox(category, setting,
		"Affiche le royaume à côté du nom de chaque personnage. Réglage propre à ce personnage.")
	Settings.RegisterAddOnCategory(category)
end

-- INTÉGRATION À POLYPODE ------------------------------------------------------------------------

if P.AddTitleButton then
	P.AddTitleButton({
		text = "Modele",
		width = 70,
		onClick = function()
			P.ToggleModele()
		end,
		tooltip = { "Polypode Modele", "Zone actuelle de chaque personnage (exemple)." },
		onCreate = function(button)
			P.ui.modeleButton = button
		end,
		hideInSolo = false, -- true si le module n'a pas de sens en mode solo (Polypode 0.54.0)
	})
end

if P.RegisterSlashCommand then
	P.RegisterSlashCommand("modele", P.ToggleModele, "zone actuelle de chaque personnage (exemple)")
end

if P.RegisterMessageHandler then
	P.RegisterMessageHandler(MESSAGE_TYPE, OnMessage)
	P.RegisterPeerCallback(function(sender)
		SendOwn(sender) -- un client s'annonce : il reçoit nos données
	end)
end

-- Personnage supprimé dans Polypode (Maj + clic) : ses données sont oubliées ici aussi.
if P.RegisterCharacterData then
	P.RegisterCharacterData({
		name = "Polypode Modele",
		describe = function(key)
			if data[key] and key ~= P.GetCharKey() then
				return "zone relevée"
			end
		end,
		remove = function(key)
			if key ~= P.GetCharKey() then
				data[key] = nil
				P.RefreshModele()
			end
		end,
	})
end

-- Polypode rafraîchit sa fenêtre (équipe, roster) : la nôtre suit.
if P.RefreshUI then
	hooksecurefunc(P, "RefreshUI", function()
		P.RefreshModele()
	end)
end

-- ÉVÉNEMENTS ------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:SetScript("OnEvent", function(_, event, addonName)
	if event == "ADDON_LOADED" then
		if addonName == "Polypode_Modele" then
			PolypodeModeleData = PolypodeModeleData or {}
			data = PolypodeModeleData
			PolypodeModeleDB = PolypodeModeleDB or {}
			for key, value in pairs(DEFAULTS) do
				if PolypodeModeleDB[key] == nil then
					PolypodeModeleDB[key] = value
				end
			end
		end
	elseif event == "PLAYER_LOGIN" then
		C_Timer.After(0, BuildSettingsPanel) -- Polypode crée P.optionsCategory à son PLAYER_LOGIN
	elseif not sendPending then
		-- Changement de zone : envoi différé (regroupe les événements rapprochés).
		sendPending = true
		C_Timer.After(SEND_DELAY, function()
			sendPending = nil
			SendOwn()
		end)
	end
end)

ns.SendOwn = SendOwn -- exemple de partage entre fichiers du module (table d'addon ns)
