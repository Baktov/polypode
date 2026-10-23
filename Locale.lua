-- Polypode: Locale — langue d'affichage et tables de traductions (Polypode et ses modules)

Polypode = Polypode or {}
local P = Polypode

-- Langue du client (frFR, enUS, enGB, deDE...). Les textes sont écrits en français dans le code :
-- le texte français est la clé, L["Inviter l'équipe"] ; une table de traductions par langue
-- (Locales/enUS.lua...) associe chaque clé à son texte. Résolution à chaque lecture : langue
-- d'affichage, sinon langue voisine (esMX : esES), sinon anglais, sinon la clé (texte français).
P.LOCALE = GetLocale()

-- Langues proposées par le sélecteur (options, /poly langue) ; "auto" = langue du jeu. Libellés
-- dans leur propre langue, pour être reconnus quelle que soit la langue affichée.
P.LANGUAGES = {
	{ "auto", "Auto" },
	{ "frFR", "Français" },
	{ "enUS", "English" },
	{ "deDE", "Deutsch" },
	{ "esES", "Español" },
	{ "itIT", "Italiano" },
	{ "ptBR", "Português (Brasil)" },
}

-- Langue voisine essayée avant l'anglais (client espagnol d'Amérique latine).
local NEIGHBOUR = { esMX = "esES" }

-- Langue d'affichage : celle du jeu jusqu'à ce que P.ApplyLanguage applique la préférence
-- enregistrée, dès la fin de ce fichier (## LoadSavedVariablesFirst : PolypodeDB est déjà lu), ou
-- à défaut à l'ADDON_LOADED de Polypode (P.InitDB).
local language = P.LOCALE
local applied = false
local appliedCallbacks = {}
local translations = setmetatable({}, { __mode = "k" }) -- [table L] = { [langue] = textes }

function P.GetLanguage()
	return language
end

-- Applique la préférence ("auto", nil ou une langue de P.LANGUAGES) puis rappelle les fonctions
-- de P.OnLanguageApplied. Effet une seule fois par session (les appels suivants sont ignorés :
-- les rappels, dont des boutons de modules, ne doivent pas être rejoués) ; changer de langue
-- demande un /reload, les fenêtres déjà construites gardant leurs textes.
function P.ApplyLanguage(preference)
	if applied then
		return
	end
	language = (preference and preference ~= "auto") and preference or P.LOCALE
	applied = true
	for _, fn in ipairs(appliedCallbacks) do
		fn()
	end
end

-- Préférence enregistrée (P.db.language) : "auto" ou une langue de P.LANGUAGES.
function P.GetLanguagePreference()
	return P.db and P.db.language or "auto"
end

-- Enregistre la préférence (sélecteur des options, /poly langue) ; prise en compte au prochain
-- /reload (pas de ReloadUI depuis l'addon : bloqué sur WoW Forever). Message dans les deux
-- langues : celui qui change de langue ne lit peut-être pas la langue affichée.
function P.SetLanguagePreference(preference)
	if preference == P.GetLanguagePreference() then
		return
	end
	P.db.language = preference
	UIErrorsFrame:AddMessage("Polypode : tapez /reload pour changer de langue. / Type /reload to change the language.",
		1, 0.82, 0)
end

-- Textes rangés au chargement d'un fichier (BINDING_NAME_*, StaticPopupDialogs...) : à poser dans
-- fn, appelée quand la langue d'affichage est connue (tout de suite si elle l'est déjà).
function P.OnLanguageApplied(fn)
	appliedCallbacks[#appliedCallbacks + 1] = fn
	if applied then
		fn()
	end
end

-- Nouvelle table de textes d'un addon : L[texte français] → texte dans la langue d'affichage.
function P.NewLocale()
	local L = setmetatable({}, {
		__index = function(self, key)
			if language == "frFR" then
				return key
			end
			local byLanguage = translations[self]
			local text = byLanguage[language] and byLanguage[language][key]
			local neighbour = NEIGHBOUR[language]
			if text == nil and neighbour and byLanguage[neighbour] then
				text = byLanguage[neighbour][key]
			end
			if text == nil and byLanguage.enUS then
				text = byLanguage.enUS[key] -- repli des langues sans traduction
			end
			return text or key
		end,
	})
	translations[L] = {}
	return L
end

-- Ajoute à L les traductions d'une langue (toutes gardées : la langue d'affichage peut différer
-- de celle du jeu).
function P.AddTranslations(L, locale, strings)
	local byLanguage = translations[L]
	byLanguage[locale] = byLanguage[locale] or {}
	for key, text in pairs(strings) do
		byLanguage[locale][key] = text
	end
end

P.L = P.NewLocale()

-- Préférence appliquée dès le chargement (## LoadSavedVariablesFirst : PolypodeDB est lu avant les
-- fichiers) : tous les textes, y compris ceux que Polypode et ses modules rangent au chargement de
-- leurs fichiers, sont dans la langue choisie. Premier lancement (pas encore de PolypodeDB) : P.InitDB.
if type(PolypodeDB) == "table" then
	P.ApplyLanguage(PolypodeDB.language)
end
