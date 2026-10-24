-- Polypode Modele: Locales/deDE — textes en allemand (clé = texte français du code). Voir
-- Polypode/Locale.lua et MODULES.md (« Langues »).

local _, ns = ...
local P = Polypode
if not P.AddTranslations then
	return
end

P.AddTranslations(ns.L, "deDE", {
	-- Modele.lua
	["Polypode Modele"] = "Polypode Vorlage",
	["Modele"] = "Vorlage",
	["pas d'infos"] = "keine Infos",
	["Zone : %s"] = "Zone: %s",
	["Pas d'infos (module absent ou pas encore reçu)."] = "Keine Infos (Modul fehlt oder noch nicht empfangen).",
	["Reçu le %s"] = "Empfangen am %s",
	["%d/%m à %H:%M"] = "%d.%m. um %H:%M",
	["Zone actuelle des personnages"] = "Aktuelle Zone der Charaktere",
	["Afficher le royaume"] = "Realm anzeigen",
	["Affiche le royaume à côté du nom de chaque personnage. Réglage propre à ce personnage."] = "Zeigt den Realm neben dem Namen jedes Charakters. Einstellung nur für diesen Charakter.",
	["Zone actuelle de chaque personnage (exemple)."] = "Aktuelle Zone jedes Charakters (Beispiel).",
	["zone actuelle de chaque personnage (exemple)"] = "aktuelle Zone jedes Charakters (Beispiel)",
	["zone relevée"] = "Zone erfasst",
})
