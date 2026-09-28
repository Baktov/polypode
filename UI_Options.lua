-- Polypode: UI_Options — panneau de paramètres dans Options > AddOns (API Settings Blizzard)

local P = Polypode

-- Élément « Canal dédié » du panneau (modèle PolypodeChannelSettingTemplate, UI_Options.xml).
-- Mélangé au cadre par son OnLoad ; le panneau appelle Init à chaque affichage de l'élément.
P.ChannelSettingMixin = {}

function P.ChannelSettingMixin:OnLoad()
	P.SetupChannelInput(self.EditBox)
	self.ManageButton:SetScript("OnClick", function()
		P.ShowTokensWindow()
	end)
	self.ManageButton:SetScript("OnEnter", function(button)
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Gestion liste token")
		GameTooltip:AddLine("Ouvre la liste des autres comptes Battle.net autorisés sur le canal "
			.. "dédié, pour voir leurs personnages et révoquer une autorisation.", 1, 1, 1, true)
		GameTooltip:Show()
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
	local message = label == "" and "Compte WoW : non renseigné."
		or "Compte WoW de ce personnage : " .. label .. "."
	if not P.charDb.groupByAccount then
		message = message .. " Cochez « Personnages disponibles : regrouper par compte » pour voir les comptes."
	end
	UIErrorsFrame:AddMessage(message, 1, 0.82, 0)
	P.RefreshUI()
end

function P.AccountSettingMixin:OnLoad()
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
		GameTooltip:AddLine("Compte WoW de ce personnage")
		GameTooltip:AddLine("Nom du compte WoW sur lequel vous jouez ce personnage (ex. WoW1). WoW ne "
			.. "le donne pas aux addons : à saisir une fois par personnage. Sert au regroupement par "
			.. "compte des personnages disponibles ; partagé avec vos autres Polypode. Enregistré à "
			.. "Entrée ou en quittant le champ ; Échap annule ; vide = aucun compte. Même réglage que "
			.. "Alt + clic sur un personnage dans la fenêtre Polypode.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	editBox:SetScript("OnLeave", GameTooltip_Hide)
end

function P.AccountSettingMixin:Init()
	if not self.EditBox:HasFocus() then
		self.EditBox:SetText(P.GetCharacterAccount(P.GetCharKey()) or "")
	end
end

-- Enregistre la catégorie "Polypode" dans Options > AddOns. Appelé à PLAYER_LOGIN,
-- une fois P.db disponible.
function P.BuildOptions()
	if P.optionsCategory or not Settings then
		return
	end

	local category, layout = Settings.RegisterVerticalLayoutCategory("Polypode")

	-- Canal dédié : champ de texte (élément personnalisé, pas de contrôle Settings standard).
	layout:AddInitializer(Settings.CreateElementInitializer("PolypodeChannelSettingTemplate", {}))

	-- Proxy : la case lit/écrit P.db via nos fonctions, elle reste donc à jour
	-- quand l'affichage change par /poly minimap.
	local minimapSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_MINIMAP_ICON",
		Settings.VarType.Boolean,
		"Afficher l'icône de minimap",
		Settings.Default.True,
		function()
			return not P.db.minimap.hide
		end,
		function(value)
			P.SetMinimapButtonShown(value)
		end
	)
	Settings.CreateCheckbox(category, minimapSetting,
		"Affiche le bouton Polypode autour de la minimap (équivalent de /poly minimap).")

	-- Mode debug, par personnage (P.charDb.debug) ; même valeur que /poly debug.
	local debugSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_DEBUG",
		Settings.VarType.Boolean,
		"Mode debug",
		Settings.Default.False,
		function()
			return P.debugEnabled
		end,
		function(value)
			P.SetDebug(value)
		end
	)
	Settings.CreateCheckbox(category, debugSetting,
		"Affiche dans le chat les messages de diagnostic de Polypode (synchro, invitations...). "
		.. "Réglage propre à ce personnage (équivalent de /poly debug).")

	-- Raccourci « Assister le leader » : attaquer ou non la cible prise (par personnage).
	local startAttackSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_ASSIST_STARTATTACK",
		Settings.VarType.Boolean,
		"Attaquer après l'assistance",
		Settings.Default.True,
		function()
			return P.charDb.assistStartAttack
		end,
		function(value)
			P.charDb.assistStartAttack = value
			P.UpdateLeaderMacros() -- différé à la sortie du combat si besoin
		end
	)
	Settings.CreateCheckbox(category, startAttackSetting,
		"Le raccourci « Assister le leader » lance aussi l'attaque automatique (/startattack) sur "
		.. "la cible prise, si elle est hostile. Décoché : prend seulement la cible du leader. "
		.. "Réglage propre à ce personnage.")

	-- Acceptation automatique des quêtes du leader (par personnage, cf. Quests.lua).
	local questSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_AUTO_ACCEPT_QUEST",
		Settings.VarType.Boolean,
		"Accepter automatiquement les quêtes",
		Settings.Default.True,
		function()
			return P.charDb.autoAcceptQuest
		end,
		function(value)
			P.charDb.autoAcceptQuest = value
		end
	)
	Settings.CreateCheckbox(category, questSetting,
		"Quand le leader de l'équipe accepte une quête, ce personnage l'accepte aussi dès qu'elle "
		.. "lui est proposée (PNJ ouvert, jusqu'à 30 secondes après). Sur le leader, annonce ses "
		.. "quêtes acceptées au groupe. Réglage propre à ce personnage.")

	-- Validation automatique des quêtes du leader (par personnage, cf. Quests.lua).
	local validateSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_AUTO_VALIDATE_QUEST",
		Settings.VarType.Boolean,
		"Valider automatiquement les quêtes",
		Settings.Default.True,
		function()
			return P.charDb.autoValidateQuest
		end,
		function(value)
			P.charDb.autoValidateQuest = value
		end
	)
	Settings.CreateCheckbox(category, validateSetting,
		"Quand le leader de l'équipe rend une quête (« Continuer » puis « Terminer la quête »), "
		.. "ce personnage la rend aussi, avec le même choix de récompense, dès que le PNJ est ouvert "
		.. "(jusqu'à 60 secondes après). Sur le leader, annonce ses validations au groupe. "
		.. "Réglage propre à ce personnage.")

	-- Dialogues de PNJ du leader : quêtes, options, fermeture (par personnage, cf. Quests.lua).
	local gossipSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_AUTO_SELECT_GOSSIP",
		Settings.VarType.Boolean,
		"Suivre les dialogues de PNJ du leader",
		Settings.Default.True,
		function()
			return P.charDb.autoSelectGossip
		end,
		function(value)
			P.charDb.autoSelectGossip = value
		end
	)
	Settings.CreateCheckbox(category, gossipSetting,
		"Quand le leader de l'équipe choisit une quête (disponible ou à rendre) ou une option dans "
		.. "le dialogue d'un PNJ, ce personnage fait le même choix si son dialogue avec le PNJ est "
		.. "ouvert ; quand le leader ferme DialogueUI, il le ferme aussi. L'acceptation ou la "
		.. "validation automatique prend ensuite le relais. Sur le leader, annonce ses choix au "
		.. "groupe. Réglage propre à ce personnage.")

	-- Cinématiques passées par le leader (par personnage, cf. Cinematics.lua).
	local cinematicSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_AUTO_SKIP_CINEMATIC",
		Settings.VarType.Boolean,
		"Passer automatiquement les cinématiques",
		Settings.Default.True,
		function()
			return P.charDb.autoSkipCinematic
		end,
		function(value)
			P.charDb.autoSkipCinematic = value
		end
	)
	Settings.CreateCheckbox(category, cinematicSetting,
		"Quand le leader de l'équipe passe une cinématique ou une vidéo, ce personnage la passe "
		.. "aussi (dès qu'elle s'affiche, jusqu'à 15 secondes après). Sur le leader, annonce ses "
		.. "cinématiques passées au groupe. Réglage propre à ce personnage.")

	-- Vol pris par le leader chez un maître de vol (par personnage, cf. Taxi.lua).
	local taxiSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_AUTO_TAXI",
		Settings.VarType.Boolean,
		"Prendre automatiquement le vol du leader",
		Settings.Default.True,
		function()
			return P.charDb.autoTaxi
		end,
		function(value)
			P.charDb.autoTaxi = value
		end
	)
	Settings.CreateCheckbox(category, taxiSetting,
		"Quand le leader de l'équipe prend un vol chez un maître de vol, ce personnage prend le "
		.. "même vol si sa carte de vol est ouverte et qu'il connaît la destination. Sur le leader, "
		.. "annonce ses vols au groupe. Réglage propre à ce personnage.")

	-- Gouffres (entrée, sortie) et portails d'instance (par personnage, cf. Instances.lua).
	local instanceSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_AUTO_ENTER_INSTANCE",
		Settings.VarType.Boolean,
		"Entrer automatiquement en instance (gouffre, portail)",
		Settings.Default.True,
		function()
			return P.charDb.autoEnterInstance
		end,
		function(value)
			P.charDb.autoEnterInstance = value
		end
	)
	Settings.CreateCheckbox(category, instanceSetting,
		"Quand le leader de l'équipe choisit le palier d'un gouffre, ce personnage choisit le même "
		.. "si sa fenêtre de palier est ouverte ; quand le leader vote la sortie du gouffre, il vote "
		.. "« Oui » aussi (jusqu'à 30 secondes après) ; quand le leader confirme l'entrée par un "
		.. "portail d'instance, il confirme aussi. Sur le leader, annonce ces actions au groupe. "
		.. "Réglage propre à ce personnage.")

	-- Leader : volume envoyé à l'équipe par le raccourci « Envoyer le volume à l'équipe ».
	local volumeSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_SENT_VOLUME",
		Settings.VarType.Number,
		"Volume envoyé",
		50,
		function()
			return P.charDb.sentVolume
		end,
		function(value)
			P.charDb.sentVolume = math.floor(value + 0.5) -- entier, pour le message envoyé
		end
	)
	local volumeOptions = Settings.CreateSliderOptions(0, 100, 5)
	volumeOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
		return string.format("%d %%", value)
	end)
	Settings.CreateSlider(category, volumeSetting, volumeOptions,
		"Volume principal (en %) que le raccourci « Envoyer le volume à l'équipe » applique aux "
		.. "autres membres quand ce personnage est le leader. Réglage propre à ce personnage.")

	-- Membre : appliquer le volume et la coupure du son envoyés par le leader (cf. Sound.lua).
	local followSoundSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_FOLLOW_LEADER_SOUND",
		Settings.VarType.Boolean,
		"Suivre le son du leader",
		Settings.Default.True,
		function()
			return P.charDb.followLeaderSound
		end,
		function(value)
			P.charDb.followLeaderSound = value
		end
	)
	Settings.CreateCheckbox(category, followSoundSetting,
		"Applique à ce personnage le volume envoyé par le leader de l'équipe et la coupure ou le "
		.. "rétablissement du son (raccourcis du leader). Décoché : ce client garde son propre son. "
		.. "Réglage propre à ce personnage.")

	-- « Personnages disponibles » regroupés par compte (par personnage, cf. UI_Main.lua).
	local groupByAccountSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_GROUP_BY_ACCOUNT",
		Settings.VarType.Boolean,
		"Personnages disponibles : regrouper par compte",
		Settings.Default.False,
		function()
			return P.charDb.groupByAccount
		end,
		function(value)
			P.charDb.groupByAccount = value
			P.RefreshUI()
		end
	)
	Settings.CreateCheckbox(category, groupByAccountSetting,
		"Dans la fenêtre Polypode, range les personnages disponibles sous un en-tête par compte WoW, "
		.. "repliable d'un clic. WoW ne donne pas le nom du compte WoW aux addons : renseignez-le sur "
		.. "chaque personnage (champ ci-dessous, ou Alt + clic sur un personnage dans la fenêtre) ; "
		.. "les autres vont dans « Compte non renseigné ». Réglage propre à ce personnage.")
	-- Compte WoW du personnage connecté : champ de texte (élément personnalisé).
	layout:AddInitializer(Settings.CreateElementInitializer("PolypodeAccountSettingTemplate", {}))

	-- Groupage automatique de l'équipe à la connexion (par personnage, cf. AutoGroup.lua).
	local autoGroupSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_AUTO_GROUP",
		Settings.VarType.Boolean,
		"Groupage automatique de l'équipe",
		Settings.Default.True,
		function()
			return P.charDb.autoGroup
		end,
		function(value)
			P.charDb.autoGroup = value
		end
	)
	Settings.CreateCheckbox(category, autoGroupSetting,
		"Leader : invite automatiquement dans son groupe les membres de l'équipe qui se connectent "
		.. "(ou déjà connectés quand il se connecte). Membre : accepte automatiquement l'invitation "
		.. "de groupe du leader d'une de ses équipes. Réglage propre à ce personnage.")

	-- Alerte « ne suit plus » (par personnage, cf. Follow.lua).
	local followAlertSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_FOLLOW_ALERT",
		Settings.VarType.Boolean,
		"Alerte quand un membre ne suit plus",
		Settings.Default.True,
		function()
			return P.charDb.followAlert
		end,
		function(value)
			P.charDb.followAlert = value
		end
	)
	Settings.CreateCheckbox(category, followAlertSetting,
		"Membre : quand il arrête de suivre le leader de l'équipe (obstacle, saut, distance, "
		.. "mouvement manuel...), il le signale au leader. Leader : affiche « X ne vous suit plus. » "
		.. "à l'écran avec un son d'alerte. Réglage propre à ce personnage, à cocher sur le leader "
		.. "et les membres.")

	-- Détails des membres dans la barre flottante d'équipe (par personnage, UI_TeamBar.lua).
	local teamBarDetailsSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_TEAMBAR_DETAILS",
		Settings.VarType.Boolean,
		"Barre d'équipe : niveau, niveau d'objet et progression",
		Settings.Default.True,
		function()
			return P.charDb.teamBar.details
		end,
		function(value)
			P.charDb.teamBar.details = value
			P.RefreshTeamBar()
		end
	)
	Settings.CreateCheckbox(category, teamBarDetailsSetting,
		"Dans la liste de la barre flottante d'équipe, affiche à gauche de chaque personnage son "
		.. "niveau, le pourcentage d'avancement dans ce niveau (sauf au niveau maximum) et son "
		.. "niveau d'objet équipé. Infos envoyées par le Polypode de chaque personnage (« ? » tant "
		.. "qu'elles ne sont pas reçues). Réglage propre à ce personnage.")

	-- Barre de vie des membres dans la barre flottante d'équipe (par personnage, UI_TeamBar.lua).
	local teamBarHealthSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_TEAMBAR_HEALTH",
		Settings.VarType.Boolean,
		"Barre d'équipe : barre de vie des membres",
		Settings.Default.True,
		function()
			return P.charDb.teamBar.healthBar
		end,
		function(value)
			P.charDb.teamBar.healthBar = value
			P.RefreshTeamBar()
		end
	)
	Settings.CreateCheckbox(category, teamBarHealthSetting,
		"Dans la liste de la barre flottante d'équipe, souligne chaque membre groupé d'une fine "
		.. "barre de vie. Décochée : seul le libellé d'état (hors groupe, mort, loin...) reste. "
		.. "Réglage propre à ce personnage.")

	-- Clignotement des membres à durabilité faible dans la barre flottante (par personnage).
	local durabilityAlertSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_TEAMBAR_DURABILITY_ALERT",
		Settings.VarType.Boolean,
		"Barre d'équipe : clignoter si la durabilité est faible",
		Settings.Default.True,
		function()
			return P.charDb.teamBar.durabilityAlert
		end,
		function(value)
			P.charDb.teamBar.durabilityAlert = value
			P.RefreshTeamBar()
		end
	)
	Settings.CreateCheckbox(category, durabilityAlertSetting,
		"Dans la liste de la barre flottante d'équipe, fait clignoter en rouge un personnage dont "
		.. "la pièce d'équipement la plus usée est sous le seuil de durabilité ci-dessous. Durabilité "
		.. "envoyée par le Polypode de chaque personnage. Réglage propre à ce personnage.")

	local durabilityThresholdSetting = Settings.RegisterProxySetting(
		category,
		"POLYPODE_TEAMBAR_DURABILITY_THRESHOLD",
		Settings.VarType.Number,
		"Barre d'équipe : seuil de durabilité",
		25,
		function()
			return P.charDb.teamBar.durabilityThreshold
		end,
		function(value)
			P.charDb.teamBar.durabilityThreshold = math.floor(value + 0.5)
			P.RefreshTeamBar()
		end
	)
	local durabilityOptions = Settings.CreateSliderOptions(5, 95, 5)
	durabilityOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
		return string.format("%d %%", value)
	end)
	Settings.CreateSlider(category, durabilityThresholdSetting, durabilityOptions,
		"Un personnage clignote dans la barre flottante d'équipe quand la durabilité de sa pièce la "
		.. "plus usée est inférieure à ce pourcentage (de 5 à 95 %, par pas de 5). Réglage propre à "
		.. "ce personnage.")

	Settings.RegisterAddOnCategory(category)
	P.optionsCategory = category
end

function P.OpenOptions()
	if P.optionsCategory then
		Settings.OpenToCategory(P.optionsCategory:GetID())
	end
end
