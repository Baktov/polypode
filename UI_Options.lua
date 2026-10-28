-- Polypode: UI_Options — panneau de paramètres dans Options > AddOns (API Settings Blizzard)

local P = Polypode
local L = P.L

-- Élément « Canal dédié » du panneau (modèle PolypodeChannelSettingTemplate, UI_Options.xml).
-- Mélangé au cadre par son OnLoad ; le panneau appelle Init à chaque affichage de l'élément.
P.ChannelSettingMixin = {}

function P.ChannelSettingMixin:OnLoad()
	self.Text:SetText(L["Canal dédié"])
	self.ManageButton:SetText(L["Gestion liste token"])
	P.SetupChannelInput(self.EditBox)
	self.ManageButton:SetScript("OnClick", function()
		P.ShowTokensWindow()
	end)
	self.ManageButton:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Gestion liste token"])
		GameTooltip:AddLine(L["Ouvre la liste des autres comptes Battle.net autorisés sur le canal "
			.. "dédié, pour voir leurs personnages et révoquer une autorisation."], 1, 1, 1, true)
		P.ShowTooltip()
	end)
	self.ManageButton:SetScript("OnLeave", GameTooltip_Hide)
end

function P.ChannelSettingMixin:Init()
	self.EditBox:SetText(P.GetSyncChannelName())
end

-- Élément « Compte WoW de ce personnage » (modèle PolypodeAccountSettingTemplate) : range le
-- personnage connecté dans un compte WoW nommé (P.SetCharacterAccount, partagé et synchronisé,
-- comme Alt + clic dans la fenêtre). Par personnage : WoW ne donne pas le compte WoW aux addons,
-- et le fichier de compte est commun à tous les comptes (jonctions). Vide = aucun compte.
P.AccountSettingMixin = {}

-- Enregistre la saisie si elle a changé (Entrée, ou perte du focus : clic ailleurs, fermeture
-- des options — sans quoi une saisie non validée par Entrée serait perdue).
local function CommitAccountName(box)
	local label = strtrim(box:GetText() or "")
	if label == (P.GetCharacterAccount(P.GetCharKey()) or "") then
		return
	end
	P.SetCharacterAccount(P.GetCharKey(), label)
	local message = label == "" and L["Compte WoW : non renseigné."]
		or L["Compte WoW de ce personnage : %s."]:format(label)
	if not P.charDb.groupByAccount then
		message = message .. " " .. L["Cochez « Personnages disponibles : regrouper par compte » pour voir les comptes."]
	end
	UIErrorsFrame:AddMessage(message, 1, 0.82, 0)
	P.RefreshUI()
end

function P.AccountSettingMixin:OnLoad()
	self.Text:SetText(L["Compte WoW de ce personnage"])
	local editBox = self.EditBox
	editBox:SetAutoFocus(false)
	editBox:SetMaxLetters(32)
	editBox:SetScript("OnEnterPressed", function(box)
		CommitAccountName(box)
		box:ClearFocus()
	end)
	editBox:SetScript("OnEditFocusLost", CommitAccountName)
	editBox:SetScript("OnEscapePressed", function(box)
		-- Annule : la valeur enregistrée est remise avant la perte du focus (rien à enregistrer).
		box:SetText(P.GetCharacterAccount(P.GetCharKey()) or "")
		box:ClearFocus()
	end)
	editBox:SetScript("OnEnter", function(box)
		GameTooltip:SetOwner(box, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(L["Compte WoW de ce personnage"])
		GameTooltip:AddLine(L["Nom du compte WoW sur lequel vous jouez ce personnage (ex. WoW1). WoW ne "
			.. "le donne pas aux addons : à saisir une fois par personnage. Sert au regroupement par "
			.. "compte des personnages disponibles ; partagé avec vos autres Polypode. Enregistré à "
			.. "Entrée ou en quittant le champ ; Échap annule ; vide = aucun compte. Même réglage que "
			.. "Alt + clic sur un personnage dans la fenêtre Polypode."], 1, 1, 1, true)
		P.ShowTooltip()
	end)
	editBox:SetScript("OnLeave", GameTooltip_Hide)
end

function P.AccountSettingMixin:Init()
	if not self.EditBox:HasFocus() then
		self.EditBox:SetText(P.GetCharacterAccount(P.GetCharKey()) or "")
	end
end

-- Élément « liste des boutons des compagnons » (modèle PolypodeButtonListSettingTemplate) : une
-- ligne par bouton dans l'ordre choisi, avec sa case d'affichage, le côté du titre (fenêtre
-- seulement) et ▲ / ▼ pour le déplacer, puis « Tous » / « Aucun ». Données de l'initialiseur
-- (AddButtonChoices) : { title, settings = { [clé] = réglage d'affichage }, order = fn() → liste,
-- sides = vrai pour la fenêtre, refresh, tooltip (« %s » = bouton) }. Les cases passent par les
-- réglages (setting:SetValue), comme celles de la petite fenêtre du clic droit.
P.ButtonListSettingMixin = {}

local LIST_TITLE_HEIGHT, LIST_ROW_HEIGHT, LIST_FOOTER_HEIGHT = 26, 24, 32

-- Hauteur de l'élément pour count boutons.
local function ButtonListExtent(count)
	return LIST_TITLE_HEIGHT + count * LIST_ROW_HEIGHT + LIST_FOOTER_HEIGHT
end

local function ArrowButton(parent, direction)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(22, 22)
	local base = "Interface\\ChatFrame\\UI-ChatIcon-Scroll" .. direction
	button:SetNormalTexture(base .. "-Up")
	button:SetPushedTexture(base .. "-Down")
	button:SetDisabledTexture(base .. "-Disabled")
	button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	return button
end

local function ShowListTooltip(owner, title, text)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:AddLine(title)
	GameTooltip:AddLine(text, 1, 1, 1, true)
	P.ShowTooltip()
end

function P.ButtonListSettingMixin:OnLoad()
	self.rows = {}
	local all = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
	all:SetSize(90, 22)
	all:SetText(L["Tous"])
	local none = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
	none:SetSize(90, 22)
	none:SetText(L["Aucun"])
	none:SetPoint("LEFT", all, "RIGHT", 8, 0)
	all:SetScript("OnClick", function()
		self:SetAll(true)
	end)
	none:SetScript("OnClick", function()
		self:SetAll(false)
	end)
	self.AllButton, self.NoneButton = all, none
end

function P.ButtonListSettingMixin:SetAll(value)
	for _, setting in pairs(self.data.settings) do
		setting:SetValue(value)
	end
	self:Fill()
end

function P.ButtonListSettingMixin:Move(key, delta)
	P.MoveButtonInOrder(self.data.order(), key, delta)
	self.data.refresh()
	self:Fill()
end

local function CreateListRow(element)
	local row = CreateFrame("Frame", nil, element)
	row:SetHeight(LIST_ROW_HEIGHT)
	row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.Label:SetPoint("LEFT", 52, 0)
	row.Label:SetJustifyH("LEFT")
	row.Check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	row.Check:SetSize(24, 24)
	row.Check:SetPoint("LEFT", row, "CENTER", -80, 0)
	row.Check:SetScript("OnClick", function(check)
		local setting = element.data.settings[row.key]
		setting:SetValue(check:GetChecked() and true or false)
	end)
	row.Check:SetScript("OnEnter", function(check)
		ShowListTooltip(check, row.text, element.data.tooltip:format(row.text))
	end)
	row.Check:SetScript("OnLeave", GameTooltip_Hide)
	row.Side = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.Side:SetSize(84, 20)
	row.Side:SetPoint("LEFT", row.Check, "RIGHT", 8, 0)
	row.Side:SetScript("OnClick", function()
		P.SetWindowButtonSide(row.key, not row.left)
		element.data.refresh()
		element:Fill()
	end)
	row.Side:SetScript("OnEnter", function(button)
		ShowListTooltip(button, L["Côté du titre"], L["Place le bouton à gauche du titre de la fenêtre "
			.. "(après « Solo ») ou à droite (vers la croix). Clic pour changer."])
	end)
	row.Side:SetScript("OnLeave", GameTooltip_Hide)
	row.Up = ArrowButton(row, "Up")
	row.Down = ArrowButton(row, "Down")
	row.Up:SetScript("OnClick", function()
		element:Move(row.key, -1)
	end)
	row.Down:SetScript("OnClick", function()
		element:Move(row.key, 1)
	end)
	if P.SkinCheckBox then
		P.SkinCheckBox(row.Check)
	end
	return row
end

-- Remplit les lignes selon l'ordre et les réglages courants.
function P.ButtonListSettingMixin:Fill()
	local data = self.data
	local specs = P.OrderedButtonSpecs(data.order())
	for index, spec in ipairs(specs) do
		local row = self.rows[index] or CreateListRow(self)
		self.rows[index] = row
		row.key, row.text = spec.moduleKey, spec.text
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -(LIST_TITLE_HEIGHT + (index - 1) * LIST_ROW_HEIGHT))
		row:SetPoint("RIGHT")
		row.Label:SetText(spec.text)
		local setting = data.settings[spec.moduleKey]
		row.Check:SetChecked(setting and setting:GetValue() and true or false)
		row.Side:SetShown(data.sides == true)
		if data.sides then
			row.left = P.IsWindowButtonLeft(spec)
			row.Side:SetText(row.left and L["À gauche"] or L["À droite"])
		end
		local arrowAnchor = data.sides and row.Side or row.Check
		row.Up:ClearAllPoints()
		row.Up:SetPoint("LEFT", arrowAnchor, "RIGHT", 8, 0)
		row.Down:ClearAllPoints()
		row.Down:SetPoint("LEFT", row.Up, "RIGHT", 2, 0)
		row.Up:SetEnabled(index > 1)
		row.Down:SetEnabled(index < #specs)
		row:Show()
	end
	for index = #specs + 1, #self.rows do
		self.rows[index]:Hide()
	end
	self.AllButton:ClearAllPoints()
	self.AllButton:SetPoint("TOPLEFT", 52, -(LIST_TITLE_HEIGHT + #specs * LIST_ROW_HEIGHT + 4))
	self:SetHeight(ButtonListExtent(#specs))
end

function P.ButtonListSettingMixin:Init(initializer)
	self.data = initializer.GetData and initializer:GetData() or initializer.data
	self.Text:SetText(self.data.title)
	self:Fill()
end

-- Enregistre la catégorie "Polypode" dans Options > AddOns. Appelé à PLAYER_LOGIN,
-- une fois P.db disponible.
function P.BuildOptions()
	if P.optionsCategory or not Settings then
		return
	end

	local category, layout = Settings.RegisterVerticalLayoutCategory("Polypode")

	-- Chaque contrôle du panneau est aussi rappelé dans la petite fenêtre du clic droit sur l'icône
	-- de la barre flottante (P.optionsPopup, UI_OptionsPopup.lua), avec le même réglage.
	local popupItems = {}
	local function AddCheck(setting, tooltip)
		tooltip = P.ColorClicks(tooltip) -- clics en bleu, dans le panneau comme dans la petite fenêtre
		local initializer = Settings.CreateCheckbox(category, setting, tooltip)
		popupItems[#popupItems + 1] = { kind = "check", setting = setting, tooltip = tooltip }
		return initializer
	end
	-- Curseur en pourcentage, de min à max par step.
	local function PercentText(value)
		return string.format("%d %%", value)
	end
	local function AddSlider(setting, min, max, step, tooltip)
		tooltip = P.ColorClicks(tooltip)
		local options = Settings.CreateSliderOptions(min, max, step)
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, PercentText)
		Settings.CreateSlider(category, setting, options, tooltip)
		popupItems[#popupItems + 1] = { kind = "slider", setting = setting, min = min, max = max, step = step,
			format = PercentText, tooltip = tooltip }
	end
	-- values = { { valeur, libellé }, ... }
	local function AddDropdown(setting, values, tooltip)
		tooltip = P.ColorClicks(tooltip)
		Settings.CreateDropdown(category, setting, function()
			local container = Settings.CreateControlTextContainer()
			for _, value in ipairs(values) do
				container:Add(value[1], value[2])
			end
			return container:GetData()
		end, tooltip)
		popupItems[#popupItems + 1] = { kind = "dropdown", setting = setting, values = values, tooltip = tooltip }
	end
	-- Boutons des compagnons installés (P.AddTitleButton, demandés au chargement des addons, avant
	-- ce panneau) : un réglage d'affichage par bouton (aussi en case dans la petite fenêtre du clic
	-- droit), et dans le panneau un seul élément PolypodeButtonListSettingTemplate (cases, côté,
	-- ordre, « Tous » / « Aucun »). choice = { variable (préfixe du nom des réglages), title,
	-- hidden = fn() → [moduleKey] = true, order = fn() → liste des clés, sides, refresh,
	-- label et tooltip (« %s » = bouton) }.
	local function AddButtonChoices(choice)
		local settings = {}
		local specs = P.GetTitleButtonSpecs()
		for _, spec in ipairs(specs) do
			local key = spec.moduleKey
			local setting = Settings.RegisterProxySetting(
				category,
				choice.variable .. (key:upper():gsub("[^%w]", "_")),
				Settings.VarType.Boolean,
				choice.label:format(spec.text),
				Settings.Default.True,
				function()
					return not choice.hidden()[key]
				end,
				function(value)
					choice.hidden()[key] = not value or nil
					choice.refresh()
				end
			)
			popupItems[#popupItems + 1] = { kind = "check", setting = setting,
				tooltip = choice.tooltip:format(spec.text) }
			settings[key] = setting
		end
		if #specs == 0 or not layout then
			return
		end
		local initializer = Settings.CreateElementInitializer("PolypodeButtonListSettingTemplate", {
			title = choice.title,
			settings = settings,
			order = choice.order,
			sides = choice.sides,
			refresh = choice.refresh,
			tooltip = choice.tooltip,
		})
		initializer.GetExtent = function()
			return ButtonListExtent(#P.GetTitleButtonSpecs())
		end
		layout:AddInitializer(initializer)
	end

	-- Langue de Polypode et de ses modules (tous les personnages) : libellé dans les deux langues,
	-- pour être trouvé quelle que soit la langue affichée.
	local languageSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_LANGUAGE",
		Settings.VarType.String,
		"Langue / Language",
		"auto",
		P.GetLanguagePreference,
		P.SetLanguagePreference
	)
	AddDropdown(languageSetting, P.LANGUAGES,
		"Langue de Polypode et de ses modules (Auto : celle du jeu), pour tous vos personnages ; "
		.. "appliquée après /reload. / Language of Polypode and its modules (Auto: the game's), "
		.. "for all your characters; applied after /reload.")

	-- Mode solo, en tête et en rouge (par personnage) : même réglage que la case « Solo » de la
	-- fenêtre (P.SetSoloMode, UI_Main.lua).
	local soloSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_SOLO_MODE",
		Settings.VarType.Boolean,
		"|cffff4040" .. L["Mode solo"] .. "|r",
		Settings.Default.False,
		function()
			return P.IsSoloMode()
		end,
		function(value)
			P.SetSoloMode(value)
		end
	)
	AddCheck(soloSetting,
		L["Pour jouer un seul personnage : la fenêtre Polypode ne garde que « Personnages disponibles » "
		.. "(agrandi, fenêtre un peu plus étroite), sans les cadres d'équipe. Glissez votre personnage "
		.. "hors de la liste pour en faire une barre flottante, avec les boutons des modules (Suivi "
		.. "sur tous les personnages). Même case que « Solo » dans la fenêtre. Réglage "
		.. "propre à ce personnage."])

	-- Canal dédié : champ de texte (élément personnalisé, pas de contrôle Settings standard).
	layout:AddInitializer(Settings.CreateElementInitializer("PolypodeChannelSettingTemplate", {}))

	-- Proxy : la case lit/écrit P.db via nos fonctions, elle reste donc à jour
	-- quand l'affichage change par /poly minimap.
	local minimapSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_MINIMAP_ICON",
		Settings.VarType.Boolean,
		L["Afficher l'icône de minimap"],
		Settings.Default.True,
		function()
			return not P.db.minimap.hide
		end,
		function(value)
			P.SetMinimapButtonShown(value)
		end
	)
	AddCheck(minimapSetting,
		L["Affiche le bouton Polypode autour de la minimap (équivalent de /poly minimap)."])

	-- Mode debug, par personnage (P.charDb.debug) ; même valeur que /poly debug.
	local debugSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_DEBUG",
		Settings.VarType.Boolean,
		L["Mode debug"],
		Settings.Default.False,
		function()
			return P.debugEnabled
		end,
		function(value)
			P.SetDebug(value)
		end
	)
	AddCheck(debugSetting,
		L["Affiche dans le chat les messages de diagnostic de Polypode (synchro, invitations...). "
		.. "Réglage propre à ce personnage (équivalent de /poly debug)."])

	-- Raccourci « Assister le leader » : attaquer ou non la cible prise (par personnage).
	local startAttackSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_ASSIST_STARTATTACK",
		Settings.VarType.Boolean,
		L["Attaquer après l'assistance"],
		Settings.Default.True,
		function()
			return P.charDb.assistStartAttack
		end,
		function(value)
			P.charDb.assistStartAttack = value
			P.UpdateLeaderMacros() -- différé à la sortie du combat si besoin
		end
	)
	AddCheck(startAttackSetting,
		L["Le raccourci « Assister le leader » lance aussi l'attaque automatique (/startattack) sur "
		.. "la cible prise, si elle est hostile. Décoché : prend seulement la cible du leader. "
		.. "Réglage propre à ce personnage."])

	-- Acceptation automatique des quêtes du leader (par personnage, cf. Quests.lua).
	local questSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_AUTO_ACCEPT_QUEST",
		Settings.VarType.Boolean,
		L["Accepter automatiquement les quêtes"],
		Settings.Default.True,
		function()
			return P.charDb.autoAcceptQuest
		end,
		function(value)
			P.charDb.autoAcceptQuest = value
		end
	)
	AddCheck(questSetting,
		L["Quand le leader de l'équipe accepte une quête, ce personnage l'accepte aussi dès qu'elle "
		.. "lui est proposée (PNJ ouvert, jusqu'à 30 secondes après). Sur le leader, annonce ses "
		.. "quêtes acceptées au groupe. Réglage propre à ce personnage."])

	-- Validation automatique des quêtes du leader (par personnage, cf. Quests.lua).
	local validateSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_AUTO_VALIDATE_QUEST",
		Settings.VarType.Boolean,
		L["Valider automatiquement les quêtes"],
		Settings.Default.True,
		function()
			return P.charDb.autoValidateQuest
		end,
		function(value)
			P.charDb.autoValidateQuest = value
		end
	)
	AddCheck(validateSetting,
		L["Quand le leader de l'équipe rend une quête (« Continuer » puis « Terminer la quête »), "
		.. "ce personnage la rend aussi, avec le même choix de récompense, dès que le PNJ est ouvert "
		.. "(jusqu'à 60 secondes après). Sur le leader, annonce ses validations au groupe. "
		.. "Réglage propre à ce personnage."])

	-- Dialogues de PNJ du leader : quêtes, options, fermeture (par personnage, cf. Quests.lua).
	local gossipSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_AUTO_SELECT_GOSSIP",
		Settings.VarType.Boolean,
		L["Suivre les dialogues de PNJ du leader"],
		Settings.Default.True,
		function()
			return P.charDb.autoSelectGossip
		end,
		function(value)
			P.charDb.autoSelectGossip = value
		end
	)
	AddCheck(gossipSetting,
		L["Quand le leader de l'équipe choisit une quête (disponible ou à rendre) ou une option dans "
		.. "le dialogue d'un PNJ, ce personnage fait le même choix si son dialogue avec le PNJ est "
		.. "ouvert ; quand le leader ferme DialogueUI, il le ferme aussi. L'acceptation ou la "
		.. "validation automatique prend ensuite le relais. Sur le leader, annonce ses choix au "
		.. "groupe. Réglage propre à ce personnage."])

	-- Cinématiques passées par le leader (par personnage, cf. Cinematics.lua).
	local cinematicSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_AUTO_SKIP_CINEMATIC",
		Settings.VarType.Boolean,
		L["Passer automatiquement les cinématiques"],
		Settings.Default.True,
		function()
			return P.charDb.autoSkipCinematic
		end,
		function(value)
			P.charDb.autoSkipCinematic = value
		end
	)
	AddCheck(cinematicSetting,
		L["Quand le leader de l'équipe passe une cinématique ou une vidéo, ce personnage la passe "
		.. "aussi (dès qu'elle s'affiche, jusqu'à 15 secondes après). Sur le leader, annonce ses "
		.. "cinématiques passées au groupe. Réglage propre à ce personnage."])

	-- Vol pris par le leader chez un maître de vol (par personnage, cf. Taxi.lua).
	local taxiSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_AUTO_TAXI",
		Settings.VarType.Boolean,
		L["Prendre automatiquement le vol du leader"],
		Settings.Default.True,
		function()
			return P.charDb.autoTaxi
		end,
		function(value)
			P.charDb.autoTaxi = value
		end
	)
	AddCheck(taxiSetting,
		L["Quand le leader de l'équipe prend un vol chez un maître de vol, ce personnage prend le "
		.. "même vol si sa carte de vol est ouverte et qu'il connaît la destination. Sur le leader, "
		.. "annonce ses vols au groupe. Réglage propre à ce personnage."])

	-- Gouffres (entrée, sortie) et portails d'instance (par personnage, cf. Instances.lua).
	local instanceSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_AUTO_ENTER_INSTANCE",
		Settings.VarType.Boolean,
		L["Entrer automatiquement en instance (gouffre, portail)"],
		Settings.Default.True,
		function()
			return P.charDb.autoEnterInstance
		end,
		function(value)
			P.charDb.autoEnterInstance = value
		end
	)
	AddCheck(instanceSetting,
		L["Quand le leader de l'équipe choisit le palier d'un gouffre, ce personnage choisit le même "
		.. "si sa fenêtre de palier est ouverte ; quand le leader vote la sortie du gouffre, il vote "
		.. "« Oui » aussi (jusqu'à 30 secondes après) ; quand le leader confirme l'entrée par un "
		.. "portail d'instance, il confirme aussi. Sur le leader, annonce ces actions au groupe. "
		.. "Réglage propre à ce personnage."])

	-- Leader : volume envoyé à l'équipe par le raccourci « Envoyer le volume à l'équipe ».
	local volumeSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_SENT_VOLUME",
		Settings.VarType.Number,
		L["Volume envoyé"],
		50,
		function()
			return P.charDb.sentVolume
		end,
		function(value)
			P.charDb.sentVolume = math.floor(value + 0.5) -- entier, pour le message envoyé
		end
	)
	AddSlider(volumeSetting, 0, 100, 5,
		L["Volume principal (en %) que le raccourci « Envoyer le volume à l'équipe » applique aux "
		.. "autres membres quand ce personnage est le leader. Réglage propre à ce personnage."])

	-- Membre : appliquer le volume et la coupure du son envoyés par le leader (cf. Sound.lua).
	local followSoundSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_FOLLOW_LEADER_SOUND",
		Settings.VarType.Boolean,
		L["Suivre le son du leader"],
		Settings.Default.True,
		function()
			return P.charDb.followLeaderSound
		end,
		function(value)
			P.charDb.followLeaderSound = value
		end
	)
	AddCheck(followSoundSetting,
		L["Applique à ce personnage le volume envoyé par le leader de l'équipe et la coupure ou le "
		.. "rétablissement du son (raccourcis du leader). Décoché : ce client garde son propre son. "
		.. "Réglage propre à ce personnage."])

	-- « Personnages disponibles » regroupés par compte (par personnage, cf. UI_Main.lua).
	local groupByAccountSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_GROUP_BY_ACCOUNT",
		Settings.VarType.Boolean,
		L["Personnages disponibles : regrouper par compte"],
		Settings.Default.True,
		function()
			return P.charDb.groupByAccount
		end,
		function(value)
			P.charDb.groupByAccount = value
			P.RefreshUI()
		end
	)
	AddCheck(groupByAccountSetting,
		L["Dans la fenêtre Polypode, range les personnages disponibles sous un en-tête par compte WoW, "
		.. "repliable d'un clic. WoW ne donne pas le nom du compte WoW aux addons : renseignez-le sur "
		.. "chaque personnage (champ ci-dessous, ou Alt + clic sur un personnage dans la fenêtre) ; "
		.. "les autres vont dans « Compte non renseigné ». Réglage propre à ce personnage."])
	-- Compte WoW du personnage connecté : champ de texte (élément personnalisé).
	layout:AddInitializer(Settings.CreateElementInitializer("PolypodeAccountSettingTemplate", {}))

	-- Boutons des compagnons dans la barre de titre de la fenêtre Polypode (par personnage).
	AddButtonChoices({
		variable = "POLYPODE_WINDOW_BUTTON_",
		title = L["Fenêtre : boutons des modules (affichage, côté, ordre)"],
		label = L["Fenêtre : bouton %s"],
		hidden = P.GetHiddenWindowButtons,
		order = P.GetWindowButtonOrder,
		sides = true,
		refresh = P.LayoutTitleButtons,
		tooltip = L["Affiche le bouton « %s » dans la barre de titre de la fenêtre Polypode. Réglage "
			.. "propre à ce personnage."],
	})
	-- Import d'une liste de personnages (fenêtre UI_Import.lua, aussi par /poly import).
	if CreateSettingsButtonInitializer then
		layout:AddInitializer(CreateSettingsButtonInitializer(L["Importer des personnages"], L["Importer"],
			function()
				P.ShowImportWindow()
			end,
			L["Ouvre la fenêtre où coller la liste de vos personnages (produite par "
			.. "Polypode\\tools\\import_bnet.py, voir tools\\IMPORT_BNET.md) pour les ajouter au roster "
			.. "sans les connecter un par un. Aussi par la commande /poly import."], true))
	end

	-- Groupage automatique de l'équipe à la connexion (par personnage, cf. AutoGroup.lua).
	local autoGroupSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_AUTO_GROUP",
		Settings.VarType.Boolean,
		L["Groupage automatique de l'équipe"],
		Settings.Default.True,
		function()
			return P.charDb.autoGroup
		end,
		function(value)
			P.charDb.autoGroup = value
		end
	)
	AddCheck(autoGroupSetting,
		L["Leader : invite automatiquement dans son groupe les membres de l'équipe qui se connectent "
		.. "(ou déjà connectés quand il se connecte). Membre : accepte automatiquement l'invitation "
		.. "de groupe du leader d'une de ses équipes. Réglage propre à ce personnage."])

	-- Alerte « ne suit plus » (par personnage, cf. Follow.lua).
	local followAlertSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_FOLLOW_ALERT",
		Settings.VarType.Boolean,
		L["Alerte quand un membre ne suit plus"],
		Settings.Default.True,
		function()
			return P.charDb.followAlert
		end,
		function(value)
			P.charDb.followAlert = value
		end
	)
	AddCheck(followAlertSetting,
		L["Membre : quand il arrête de suivre le leader de l'équipe (obstacle, saut, distance, "
		.. "mouvement manuel...), il le signale au leader. Leader : affiche « X ne vous suit plus. » "
		.. "à l'écran avec un son d'alerte. Réglage propre à ce personnage, à cocher sur le leader "
		.. "et les membres."])

	-- Détails des membres dans la barre flottante d'équipe (par personnage, UI_TeamBar.lua).
	local teamBarDetailsSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_TEAMBAR_DETAILS",
		Settings.VarType.Boolean,
		L["Barre d'équipe : niveau, niveau d'objet et progression"],
		Settings.Default.True,
		function()
			return P.charDb.teamBar.details
		end,
		function(value)
			P.charDb.teamBar.details = value
			P.RefreshTeamBar()
		end
	)
	AddCheck(teamBarDetailsSetting,
		L["Dans la liste de la barre flottante d'équipe, affiche à gauche de chaque personnage son "
		.. "niveau, le pourcentage d'avancement dans ce niveau (sauf au niveau maximum) et son "
		.. "niveau d'objet équipé. Infos envoyées par le Polypode de chaque personnage (« ? » tant "
		.. "qu'elles ne sont pas reçues). Réglage propre à ce personnage."])

	-- Barre de vie des membres dans la barre flottante d'équipe (par personnage, UI_TeamBar.lua).
	local teamBarHealthSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_TEAMBAR_HEALTH",
		Settings.VarType.Boolean,
		L["Barre d'équipe : barre de vie des membres"],
		Settings.Default.True,
		function()
			return P.charDb.teamBar.healthBar
		end,
		function(value)
			P.charDb.teamBar.healthBar = value
			P.RefreshTeamBar()
		end
	)
	AddCheck(teamBarHealthSetting,
		L["Dans la liste de la barre flottante d'équipe, souligne chaque membre groupé d'une fine "
		.. "barre de vie. Décochée : seul le libellé d'état (hors groupe, mort, loin...) reste. "
		.. "Réglage propre à ce personnage."])

	-- Clignotement des membres à durabilité faible dans la barre flottante (par personnage).
	local durabilityAlertSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_TEAMBAR_DURABILITY_ALERT",
		Settings.VarType.Boolean,
		L["Barre d'équipe : clignoter si la durabilité est faible"],
		Settings.Default.True,
		function()
			return P.charDb.teamBar.durabilityAlert
		end,
		function(value)
			P.charDb.teamBar.durabilityAlert = value
			P.RefreshTeamBar()
		end
	)
	AddCheck(durabilityAlertSetting,
		L["Dans la liste de la barre flottante d'équipe, fait clignoter en rouge un personnage dont "
		.. "la pièce d'équipement la plus usée est sous le seuil de durabilité ci-dessous. Durabilité "
		.. "envoyée par le Polypode de chaque personnage. Réglage propre à ce personnage."])

	local durabilityThresholdSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_TEAMBAR_DURABILITY_THRESHOLD",
		Settings.VarType.Number,
		L["Barre d'équipe : seuil de durabilité"],
		25,
		function()
			return P.charDb.teamBar.durabilityThreshold
		end,
		function(value)
			P.charDb.teamBar.durabilityThreshold = math.floor(value + 0.5)
			P.RefreshTeamBar()
		end
	)
	AddSlider(durabilityThresholdSetting, 5, 95, 5,
		L["Un personnage clignote dans la barre flottante d'équipe quand la durabilité de sa pièce la "
		.. "plus usée est inférieure à ce pourcentage (de 5 à 95 %, par pas de 5). Réglage propre à "
		.. "ce personnage."])

	-- Boutons des addons compagnons en colonne contre la barre flottante (par personnage).
	local moduleButtonsSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_TEAMBAR_MODULE_BUTTONS",
		Settings.VarType.Boolean,
		L["Barre d'équipe : boutons des modules"],
		Settings.Default.True,
		function()
			return P.charDb.teamBar.moduleButtons
		end,
		function(value)
			P.charDb.teamBar.moduleButtons = value
			P.RefreshTeamBar()
		end
	)
	AddCheck(moduleButtonsSetting,
		L["Affiche contre la barre flottante d'équipe une colonne de petits boutons reprenant ceux des "
		.. "modules (Data, Photo, Profils, Suivi... selon les addons installés) : trois premières "
		.. "lettres, même clic et même infobulle que dans la fenêtre Polypode. Chaque bouton se choisit "
		.. "dans la liste dessous. Réglage propre à ce personnage."])

	AddButtonChoices({
		variable = "POLYPODE_TEAMBAR_MODULE_",
		title = L["Barre d'équipe : boutons des modules (affichage, ordre)"],
		label = L["Barre d'équipe : bouton %s"],
		hidden = P.GetHiddenModuleButtons,
		order = P.GetModuleButtonOrder,
		refresh = P.RefreshTeamBar,
		tooltip = L["Affiche le bouton « %s » dans la colonne des modules de la barre d'équipe. Réglage "
			.. "propre à ce personnage."],
	})

	local moduleSideSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_TEAMBAR_MODULE_SIDE",
		Settings.VarType.String,
		L["Barre d'équipe : côté des boutons"],
		"left",
		function()
			return P.charDb.teamBar.moduleSide
		end,
		function(value)
			P.charDb.teamBar.moduleSide = value
			P.RefreshTeamBar()
		end
	)
	AddDropdown(moduleSideSetting, { { "left", L["À gauche"] }, { "right", L["À droite"] }, { "horizontal", L["Horizontal"] } },
		L["Place des boutons des modules : colonne à gauche ou à droite de la barre flottante d'équipe, "
		.. "ou rangée horizontale au-dessus. Barre réduite : colonne sous l'icône (à gauche, à droite), "
		.. "ou rangée à sa droite (horizontal). Réglage propre à ce personnage."])

	-- Barre réduite à l'icône Polypode (par personnage, UI_TeamBar.lua).
	local compactSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_TEAMBAR_COMPACT",
		Settings.VarType.Boolean,
		L["Barre d'équipe : réduite à l'icône"],
		Settings.Default.False,
		function()
			return P.charDb.teamBar.compact
		end,
		function(value)
			P.charDb.teamBar.compact = value
			P.RefreshTeamBar()
		end
	)
	AddCheck(compactSetting,
		L["La barre flottante d'équipe ne garde que l'icône Polypode, dans un cadre de la taille d'un "
		.. "bouton de module (nom, liste des personnages et croix masqués) ; les boutons des modules "
		.. "sont dessous en colonne, ou à droite en rangée avec « Horizontal ». Icône : clic = fenêtre "
		.. "Polypode, clic droit = options, glisser = déplacer, Alt + clic = figer. Réglage propre à ce "
		.. "personnage."])

	Settings.RegisterAddOnCategory(category)
	P.optionsCategory = category
	P.optionsPopup = { key = "Polypode", title = L["Options de Polypode"], items = popupItems, category = category }
end

function P.OpenOptions()
	if P.optionsCategory then
		Settings.OpenToCategory(P.optionsCategory:GetID())
	end
end

-- Raccourcis clavier de WoW, ouverts sur la section « Polypode » dépliée (comme le bouton
-- « Raccourcis » du système de ping de Blizzard). La section porte le nom de la catégorie de
-- Bindings.xml, « Polypode », égal à BINDING_HEADER_POLYPODE.
function P.OpenKeybindings()
	local id = Settings.KEYBINDINGS_CATEGORY_ID
	if not id then
		return
	end
	local category = SettingsPanel and SettingsPanel:GetCategory(id)
	local layout = category and SettingsPanel:GetLayout(category)
	if layout then
		for _, initializer in layout:EnumerateInitializers() do
			if initializer:GetName() == BINDING_HEADER_POLYPODE then
				initializer.data.expanded = true
				break
			end
		end
	end
	Settings.OpenToCategory(id, BINDING_HEADER_POLYPODE)
end
