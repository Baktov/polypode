-- Polypode Modele: Locales/esES — textes en espagnol (clé = texte français du code ; le client esMX les prend aussi). Voir
-- Polypode/Locale.lua et MODULES.md (« Langues »).

local _, ns = ...
local P = Polypode
if not P.AddTranslations then
	return
end

P.AddTranslations(ns.L, "esES", {
	-- Modele.lua
	["Polypode Modele"] = "Polypode Plantilla",
	["Modele"] = "Plantilla",
	["pas d'infos"] = "sin datos",
	["Zone : %s"] = "Zona: %s",
	["Pas d'infos (module absent ou pas encore reçu)."] = "Sin datos (módulo ausente o aún no recibido).",
	["Reçu le %s"] = "Recibido el %s",
	["%d/%m à %H:%M"] = "%d/%m a las %H:%M",
	["Zone actuelle des personnages"] = "Zona actual de los personajes",
	["Afficher le royaume"] = "Mostrar el reino",
	["Affiche le royaume à côté du nom de chaque personnage. Réglage propre à ce personnage."] = "Muestra el reino junto al nombre de cada personaje. Ajuste propio de este personaje.",
	["Zone actuelle de chaque personnage (exemple)."] = "Zona actual de cada personaje (ejemplo).",
	["zone actuelle de chaque personnage (exemple)"] = "zona actual de cada personaje (ejemplo)",
	["zone relevée"] = "zona registrada",
})
