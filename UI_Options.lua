-- Polypode: UI_Options — panneau de paramètres dans Options > AddOns (API Settings Blizzard)

local P = Polypode

-- Enregistre la catégorie "Polypode" dans Options > AddOns. Appelé à PLAYER_LOGIN,
-- une fois P.db disponible.
function P.BuildOptions()
	if P.optionsCategory or not Settings then
		return
	end

	local category = Settings.RegisterVerticalLayoutCategory("Polypode")

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

	Settings.RegisterAddOnCategory(category)
	P.optionsCategory = category
end

function P.OpenOptions()
	if P.optionsCategory then
		Settings.OpenToCategory(P.optionsCategory:GetID())
	end
end
