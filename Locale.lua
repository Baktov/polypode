-- Polypode: Locale — langue du jeu et tables de traductions (Polypode et ses modules)

Polypode = Polypode or {}
local P = Polypode

-- Langue du client (frFR, enUS, enGB, deDE...). Les textes sont écrits en français dans le code :
-- le texte français est la clé, L["Inviter l'équipe"] ; une table de traductions par langue
-- (Locales/enUS.lua...) associe chaque clé à son texte. Résolution : langue du jeu, sinon anglais,
-- sinon la clé (texte français). En français, aucune table n'est chargée.
P.LOCALE = GetLocale()

-- Nouvelle table de textes d'un addon : L[texte français] → texte à afficher.
function P.NewLocale()
	return setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	})
end

-- Ajoute à L les traductions d'une langue : celles de la langue du jeu l'emportent, l'anglais
-- comble les clés restantes (repli des langues sans traduction). L'ordre de chargement des
-- fichiers de langue est donc indifférent.
function P.AddTranslations(L, locale, strings)
	if P.LOCALE == "frFR" then
		return
	end
	if locale == P.LOCALE then
		for key, text in pairs(strings) do
			L[key] = text
		end
	elseif locale == "enUS" then
		for key, text in pairs(strings) do
			if rawget(L, key) == nil then
				L[key] = text
			end
		end
	end
end

P.L = P.NewLocale()
