-- Polypode Modele: Locales/itIT — textes en italien (clé = texte français du code). Voir
-- Polypode/Locale.lua et MODULES.md (« Langues »).

local _, ns = ...
local P = Polypode
if not P.AddTranslations then
	return
end

P.AddTranslations(ns.L, "itIT", {
	-- Modele.lua
	["Polypode Modele"] = "Polypode Modello",
	["Modele"] = "Modello",
	["pas d'infos"] = "nessuna info",
	["Zone : %s"] = "Zona: %s",
	["Pas d'infos (module absent ou pas encore reçu)."] = "Nessuna info (modulo assente o non ancora ricevuto).",
	["Reçu le %s"] = "Ricevuto il %s",
	["%d/%m à %H:%M"] = "%d/%m alle %H:%M",
	["Zone actuelle des personnages"] = "Zona attuale dei personaggi",
	["Afficher le royaume"] = "Mostra il reame",
	["Affiche le royaume à côté du nom de chaque personnage. Réglage propre à ce personnage."] = "Mostra il reame accanto al nome di ogni personaggio. Impostazione propria di questo personaggio.",
	["Zone actuelle de chaque personnage (exemple)."] = "Zona attuale di ogni personaggio (esempio).",
	["zone actuelle de chaque personnage (exemple)"] = "zona attuale di ogni personaggio (esempio)",
	["zone relevée"] = "zona rilevata",
})
