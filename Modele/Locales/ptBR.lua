-- Polypode Modele: Locales/ptBR — textes en portugais du Brésil (clé = texte français du code). Voir
-- Polypode/Locale.lua et MODULES.md (« Langues »).

local _, ns = ...
local P = Polypode
if not P.AddTranslations then
	return
end

P.AddTranslations(ns.L, "ptBR", {
	-- Modele.lua
	["Polypode Modele"] = "Polypode Modelo",
	["Modele"] = "Modelo",
	["pas d'infos"] = "sem informações",
	["Zone : %s"] = "Zona: %s",
	["Pas d'infos (module absent ou pas encore reçu)."] = "Sem informações (módulo ausente ou ainda não recebido).",
	["Reçu le %s"] = "Recebido em %s",
	["%d/%m à %H:%M"] = "%d/%m às %H:%M",
	["Zone actuelle des personnages"] = "Zona atual dos personagens",
	["Afficher le royaume"] = "Mostrar o reino",
	["Affiche le royaume à côté du nom de chaque personnage. Réglage propre à ce personnage."] = "Mostra o reino ao lado do nome de cada personagem. Configuração própria deste personagem.",
	["Zone actuelle de chaque personnage (exemple)."] = "Zona atual de cada personagem (exemplo).",
	["zone actuelle de chaque personnage (exemple)"] = "zona atual de cada personagem (exemplo)",
	["zone relevée"] = "zona registrada",
})
