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

	Settings.RegisterAddOnCategory(category)
	P.optionsCategory = category
end

function P.OpenOptions()
	if P.optionsCategory then
		Settings.OpenToCategory(P.optionsCategory:GetID())
	end
end
