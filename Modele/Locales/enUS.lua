-- Polypode Modele: Locales/enUS — textes anglais (clé = texte français du code), repli de toute
-- langue sans traduction propre.
-- Voir Polypode/Locale.lua et MODULES.md (« Langues »).

local _, ns = ...
local P = Polypode
if not P.AddTranslations then
	return
end

P.AddTranslations(ns.L, "enUS", {
	-- Modele.lua
	["Polypode Modele"] = "Polypode Template",
	["Modele"] = "Template",
	["pas d'infos"] = "no info",
	["Zone : %s"] = "Zone: %s",
	["Pas d'infos (module absent ou pas encore reçu)."] = "No info (module missing or not received yet).",
	["Reçu le %s"] = "Received %s",
	["%d/%m à %H:%M"] = "%m/%d at %H:%M",
	["Zone actuelle des personnages"] = "Current zone of the characters",
	["Afficher le royaume"] = "Show the realm",
	["Affiche le royaume à côté du nom de chaque personnage. Réglage propre à ce personnage."] = "Shows the realm next to the name of each character. Setting specific to this character.",
	["Zone actuelle de chaque personnage (exemple)."] = "Current zone of each character (example).",
	["zone actuelle de chaque personnage (exemple)"] = "current zone of each character (example)",
	["zone relevée"] = "zone recorded",
})
