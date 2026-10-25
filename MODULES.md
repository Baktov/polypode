# Modules Polypode : conventions communes et documentation

Fichier partagé, **importé** (`@`) par le `CLAUDE.md` de Polypode, par celui de chaque compagnon
(`@../Polypode/MODULES.md`) et par le `CLAUDE.md` local du dossier des modules : il est donc chargé quel que soit
le dossier ouvert. À garder court ; le détail propre à un module va dans son `CLAUDE.md`.

## Les modules

Chaque module est un **dépôt git séparé** (dossiers voisins) avec **son propre `CLAUDE.md`, son
`README.md` (français) et son `README.en.md` (anglais)**. Sur le poste de développement, les modules sont dans `C:\PROJETS\CLAUDE\ADDONS_POLYPODE`
(hors du dossier du jeu, que les mises à jour de Battle.net ne doivent pas trouver verrouillé),
reliés à `Interface\AddOns` de Retail et de WoW Forever par des **jonctions** (`mklink /J`) ;
travailler dans `ADDONS_POLYPODE` (son `CLAUDE.md` local importe ce fichier) :

| Dossier | Dépôt | Rôle |
|---|---|---|
| `Polypode` | <https://github.com/Baktov/polypode> | cœur : roster, équipes, synchro, fenêtre, API des compagnons |
| `Polypode_Data` | <https://github.com/Baktov/polypode-data> | données durables des personnages (bouton Data) |
| `Polypode_Histoire` | <https://github.com/Baktov/polypode-histoire> | journal chronologique commun des personnages (bouton Histoire) ; sous-dossier `Polypode_Histoire_Archive` = addon chargé à la demande, relié au jeu par sa propre jonction |
| `Polypode_Map` | <https://github.com/Baktov/polypode-map> | petite carte de zone permanente avec les personnages de l'équipe, les quêtes, TomTom (bouton Map) |
| `Polypode_Photo` | <https://github.com/Baktov/Polypode-Photo> | mode photo (bouton Photo) |
| `Polypode_Profil` | <https://github.com/Baktov/polypode-profil> | bibliothèque de chaînes d'export (bouton Profils) |
| `Polypode_Quetes` | <https://github.com/Baktov/Polypode-quetes> | **obsolète** (1.3.0 : ne fait plus que le rappeler), dépôt **archivé** sur GitHub (lecture seule) : repris par le panneau « Quêtes » de Suivi |
| `Polypode_Suivi` | <https://github.com/Baktov/polypode-suivi> | suivi de l'équipe, des activités, des campagnes et des quêtes (bouton Suivi) |

Les compagnons dépendent de Polypode (`## Dependencies: Polypode`) et n'utilisent que son API
publique `P.*`, listée dans la section « Dépendances vers Polypode » de leur `CLAUDE.md`.

## Conventions communes (tous les modules)

- Commentaires en **français**, code (variables, fonctions) en **anglais**.
- Pas de librairie externe (ElvUI / EllesmereUI : optionnels, toujours testés avant usage).
- **Infobulles** : toute notion de souris (« Clic », « Clic droit », « Maj + clic », « cliquable »,
  « Glisser », « glisser/déposer »...) est en **bleu**
  (`P.CLICK_COLOR`) : afficher une infobulle par `P.ShowTooltip()`, jamais `GameTooltip:Show()`
  (repli local si la fonction manque) ; descriptions d'options passées par `P.ColorClicks(texte)`.
- **Langues** : tout texte affiché passe par la table de textes du module, `L["texte français"]`
  (section « Langues » ci-dessous) ; jamais de texte affiché écrit en dur.
- **Textes affichés en jeu** : caractères latins courants seulement (accents, « », ·, × : oui) ; pas de flèches ni de symboles (→, ⇒, ✓, …) : absents des polices du jeu, ils s'affichent en carré vide (vu le 2026-10-18 dans la frise d'Histoire).
- **Pas de `print()`** : `P.Debug(msg)` (mode debug), ou `UIErrorsFrame:AddMessage` pour un message
  à l'écran.
- Bloc de commentaire en tête de chaque fichier : `-- Polypode X: Fichier — rôle`.
- Pas de global parasite : tout est `local`, dans la table d'addon (`ns`) ou sous `Polypode.`.
- Retail (Interface 120000) et **WoW Forever** (16001) : tester l'existence de toute API récente
  (`if C_X and C_X.Fn then`), lectures fragiles sous `pcall` ; ne pas se fier à `WOW_PROJECT_ID`.
- Tout contenu de taille variable **défile** (`P.CreateScrollList` / `P.SetListData`).
- Toute fenêtre **redimensionnable** revient à sa taille par défaut par un **double-clic sur sa barre de
  titre** : `P.EnableTitleDoubleClick(fenêtre, remise)` (Polypode 2.12, testée avant usage), `remise` remet la
  taille par défaut et l'enregistre.
- **Simplicité** : n'ajouter une fonctionnalité que si elle sert directement le module ; jamais à
  moitié implémentée.
- Toujours **lire** le fichier cible avant de le modifier ; vérifier les API WoW avec les serveurs
  MCP `wow` / `wow-addon-api` / `wow-api` plutôt que de mémoire.

## Langues

Les modules s'affichent dans la langue choisie dans Polypode (option « Langue / Language »,
`/poly langue`, `P.db.language`, après `/reload`), par défaut celle du jeu ; anglais pour une langue
sans traduction. **Langues livrées** : français (référence), anglais, allemand, espagnol (le client
`esMX` prend l'espagnol), italien, portugais du Brésil ; chaque module fournit `Locales\enUS.lua`,
`deDE.lua`, `esES.lua`, `itIT.lua` et `ptBR.lua`. Pas de russe, coréen ni chinois (caractères absents
des polices des clients latins, règle des caractères latins).
Outils de Polypode (`Locale.lua`, 2.8.0 ; sélecteur 2.9.0 ; allemand et espagnol 2.10.0 ; italien et portugais 2.11.0) : `P.NewLocale()`,
`P.AddTranslations`, `P.GetLanguage()` (langue d'affichage), `P.OnLanguageApplied(fn)`, `P.LOCALE`
(langue du jeu, à ne pas utiliser pour choisir un texte).

- **Clé = texte français** : `L["Inviter l'équipe"]` ; en français la table est vide et renvoie la
  clé. Une phrase avec des valeurs est un **format**, `L["Équipe « %s » créée."]:format(nom)`, jamais
  des morceaux de phrase concaténés (l'ordre des mots change d'une langue à l'autre). Codes couleur
  (`|cff...|r`) laissés hors de la clé quand c'est simple ; `|n` (retour à la ligne) peut y rester.
- **Fichiers** : Polypode utilise `local L = P.L`. Un compagnon crée sa table dans un `Locale.lua`
  chargé en premier par son `.toc` (`L = P.NewLocale()`, rangée dans la table d'addon ; repli si
  Polypode est trop ancien : table dont `__index` renvoie la clé), puis `Locales\enUS.lua` :
  `P.AddTranslations(L, "enUS", { ["texte français"] = "English text", ... })`, groupé par fichier
  (`-- Fichier.lua`). Une autre langue : `Locales\deDE.lua`, même forme, ajouté au `.toc`.
- **Noms des modules traduits** (décision du 2026-10-23) : bouton de la barre de titre
  (`P.AddTitleButton`, `text = L["Suivi"]`), titre de sa fenêtre et textes qui le citent ; la
  colonne de la barre flottante en reprend les trois premières lettres (Dat, His, Map, Pho, Pro,
  Tra : toutes différentes). Titre dans la liste des addons : `## Title:` français (nom du dépôt et des versions
  publiées), `## Title-enUS:` / `-enGB:` anglais et une ligne par autre langue (`## Title-deDE:`...). Les commandes `/poly suivi`... gardent leur nom français, avec l'alias
  anglais (`/poly tracker`...). Noms (trois premières lettres toutes différentes dans chaque langue) :

  | Français | Anglais | Allemand | Espagnol | Italien | Portugais |
  |---|---|---|---|---|---|
  | Data | Data | Data | Data | Data | Data |
  | Histoire | History | Chronik | Historia | Storia | Histórico |
  | Map | Map | Karte | Mapa | Mappa | Mapa |
  | Photo | Photo | Foto | Foto | Foto | Foto |
  | Profils | Profiles | Profile | Perfiles | Profili | Perfis |
  | Suivi (Grille) | Tracker (Grid) | Tracker (Raster) | Seguimiento (Cuadrícula) | Monitoraggio (Griglia) | Acompanhamento (Grade) |

- **Hors table** : noms donnés par le jeu (classes par `LOCALIZED_CLASS_NAMES_MALE`, zones,
  royaumes, quêtes, renommées : déjà dans la langue du client), noms propres (Polypode, Monopode),
  messages `P.Debug` (restent en français), noms des commandes slash (français ; alias anglais
  enregistrés en plus, sans aide).
- **XML** : pas d'attribut `text=` ; le texte est posé dans l'`OnLoad` par `L[...]`. Textes rangés au
  chargement d'un fichier (`BINDING_NAME_*`, `StaticPopupDialogs`, tables de libellés, bouton de
  barre de titre) : `L[...]` y donne déjà la langue choisie, Polypode l'appliquant dès son
  `Locale.lua` (2.11.1, `## LoadSavedVariablesFirst: 1`) et les modules se chargeant après lui.
  `P.OnLanguageApplied` reste disponible (repli : `ADDON_LOADED` de Polypode au premier lancement).
- **`.toc`** : fichiers de langue avec des barres obliques (`Locales/enUS.lua`), l'antislash
  échoue sur macOS.
- **Guillemets** : « » en français, espagnol et italien, " " en anglais et en portugais, » « en allemand (les guillemets
  „ " ne sont pas sûrs dans les polices du jeu).
- **Mots de souris** reconnus par `P.ColorClicks` (liste `MOUSE_WORDS` de Core.lua), à employer
  tels quels : anglais « Click », « Left-click », « Right-click », « Double-click », « Drag »
  (« drag and drop ») ; allemand « Klick », « Linksklick », « Rechtsklick », « Doppelklick »,
  « Ziehen » ; espagnol « Clic », « Clic izquierdo », « Clic derecho », « Doble clic », « Arrastrar » ;
  italien « Clic », « Clic sinistro », « Clic destro », « Doppio clic », « Trascina » ; portugais
  « Clique », « Clique esquerdo », « Clique direito », « Clique duplo », « Arrastar » (« clique »
  reconnu seulement en portugais : `MOUSE_WORDS_BY_LANGUAGE`). Modificateurs : « Shift + » /
  « Umschalt + » / « Mayús + » / « Maiusc + », « Alt + », « Ctrl + » / « Strg + ».
- **`.toc`** : `## Notes:` en anglais, `## Notes-frFR:` en français.
- **README** : `README.md` en français, `README.en.md` en anglais (mêmes sections, sans
  l'historique des versions : renvoi vers la section « Version » du README français), liés l'un
  à l'autre en tête. Tous deux portent, après la présentation, l'encadré « Langues » : langues
  livrées, traductions faites avec l'aide de Claude (IA d'Anthropic), retours de locuteurs natifs
  bienvenus par une issue GitHub du dépôt (modèle : `Modele/README.modele.md`).
- **Contrôle** avant chaque commit qui touche des textes, depuis `ADDONS_POLYPODE` :
  `python Polypode\tools\check_locale.py <dossier du module>`. Il doit afficher 0 clé sans
  traduction anglaise et 0 format différent. Les textes français hors `L[...]` qu'il liste sont à
  relire.

## Avant de toucher un module

Lire **son** `CLAUDE.md` (architecture, dépendances, procédures propres), en plus de ce fichier.

## Après chaque modification d'un module

Dans **son** dépôt, sans attendre qu'on le demande :

1. **Version** : incrémenter `## Version` du `.toc` (correctif : 3e chiffre ; fonctionnalité :
   2e chiffre) et l'indiquer entre parenthèses à la fin du message de commit, « Description (1.2.3) ».
   Un commit de documentation seule ne change pas de version.
2. **README.md** : ajouter en tête de la section « Version » la ligne `` `x.y.z` : description. ``
   (du plus récent au plus ancien), et mettre à jour les sections d'utilisation concernées
   (colonnes, boutons, infobulles, options, commandes, fonctionnement), dans `README.md` et
   `README.en.md`.
3. **CLAUDE.md** du module : architecture (fichiers, fonctions, sections de données,
   SavedVariables, messages) et « Dépendances vers Polypode » si une nouvelle fonction `P.*` est
   utilisée.
4. Si le **périmètre** d'un compagnon change (fonction visible, message de synchro, API de Polypode
   utilisée) : mettre aussi à jour, dans `Polypode`, la section « Addons compagnons » du
   `README.md` et la liste des compagnons / API publique de son `CLAUDE.md`, et commiter ce
   dépôt-là aussi.
5. Commiter puis pousser (`git push`) chaque dépôt modifié sur `origin`.

**Vérification rapide** qu'une doc n'a pas décroché : chaque version des messages de commit
(`git log --format=%s`) a sa ligne dans la section « Version » du README, et chaque `P.X` utilisé
par un compagnon (hors fonctions qu'il définit) figure dans ses dépendances.

## Publier une version (release GitHub)

Seulement quand on le demande. Après commit et push du module :

```
python Polypode\tools\publier_version.py <dossier du module>           # depuis ADDONS_POLYPODE
python Polypode\tools\publier_version.py <dossier du module> --essai   # ZIP et notes, sans publier
```

Crée la version `v<## Version du .toc>` sur GitHub (étiquette sur HEAD) et y joint
**`<Module>-<version>.zip`**, qui contient directement le ou les dossiers d'addon à leur nom exact
(addon imbriqué, comme `Polypode_Histoire_Archive`, sorti au premier niveau), sans fichiers de
développement (`CLAUDE.md`, `MODULES.md`, `Modele/`, `tools/` de Photo, ce programme) : le joueur
décompresse dans `Interface\AddOns` sans rien renommer (le ZIP « Source code » de GitHub, lui,
contient `polypode-x-1.2.3` à renommer). Notes : installation (en français, puis une ligne en anglais), dépendances (`## Dependencies`),
lignes de la section « Version » du README depuis la version publiée précédente. Contrôles :
arbre propre, HEAD poussé, version pas encore publiée. Un nouveau fichier de développement à ne
pas livrer s'ajoute aux exclusions en tête du programme.

## Créer un nouveau module

Squelette prêt à copier : `Polypode/Modele/` (voir son `LISEZMOI.txt`). Démarche, pour un module
« Polypode X » :

1. **Cadrage** : le besoin passe la règle de simplicité (sert directement la gestion des
   personnages) ; noms : dossier `Polypode_X`, titre « Polypode X », dépôt `Baktov/polypode-x`,
   commande `/poly x`, type de message de synchro propre s'il en faut un (comme `SUIVI`, `DATA`).
2. **Dépôt** : créer le dépôt GitHub ; dans `AddOns/Polypode_X` : `git init`, `git remote add origin`.
3. **Fichiers** : copier `Polypode/Modele/` vers `AddOns/Polypode_X`, renommer (`Polypode_Modele.toc`
   → `Polypode_X.toc`, `Modele.lua` → `X.lua`, `CLAUDE.modele.md` → `CLAUDE.md`,
   `README.modele.md` → `README.md`, `README.en.modele.md` → `README.en.md`, supprimer
   `LISEZMOI.txt`) et remplacer partout `Modele` /
   `modele` par le nom (SavedVariables `PolypodeXDB`, fenêtre `PolypodeXFrame`, `P.ToggleX`...).
4. **Branchement** : uniquement par l'API publique de Polypode, chaque fonction testée avant usage
   (`P.AddTitleButton`, `P.RegisterSlashCommand`, sous-catégorie de `P.optionsCategory` — et ses
   réglages rappelés par `P.ToggleOptionsPopup` au clic droit sur le bouton du module —,
   `P.CreatePanel` / `P.CreateScrollList` / `P.SetListData`, `P.Skin*`, synchro
   `P.RegisterMessageHandler` / `P.RegisterPeerCallback` / `P.WhisperOnline` / `P.IsSender` /
   `P.MAX_MESSAGE_LENGTH`, `P.RegisterCharacterData` pour des données par personnage). Une fonction
   qui manque s'ajoute **d'abord dans Polypode** (nouvelle version), et le README du module indique
   « Nécessite Polypode x.y ».
5. **Documentation dès la 1.0.0** : `CLAUDE.md` (import `@../Polypode/MODULES.md`, architecture,
   « Dépendances vers Polypode », pistes), `README.md` (installation, utilisation, options,
   section « Version » avec `` `1.0.0` : première version… ``) et `README.en.md` ; textes
   traduits dans `Locales/` (section « Langues »).
6. **Déclarer le module dans Polypode** (commit dans ce dépôt) : ligne du tableau « Les modules »
   ci-dessus, section « Addons compagnons » du `README.md` de Polypode (et son nombre), liste des
   compagnons / API publique de son `CLAUDE.md` ; ajouter aussi le dossier dans le `CLAUDE.md`
   local de `ADDONS_POLYPODE`.
7. **Vérifier et publier** : `luac -p`, linter WoW (`wow_lua_lint`), test en jeu (`/reload`, et
   WoW Forever si pertinent) ; commit « Polypode X 1.0.0 : … » puis push ; le relier au jeu
   (`mklink /J "<jeu>\Interface\AddOns\Polypode_X" "C:\PROJETS\CLAUDE\ADDONS_POLYPODE\Polypode_X"`, Retail
   et Forever ; ailleurs : `git clone` dans `Interface\AddOns`) et l'activer sur les personnages concernés.

## Outillage (Windows)

Écrire les messages de commit et les scripts contenant des accents ou des échappements Lua
(`\195`, `\\`) dans un fichier (`git commit -F fichier`, script `.py` écrit tel quel), jamais par
un heredoc bash passé à Python, qui les déforme. La console Windows affiche mal les accents
(« � ») même quand les fichiers et les commits sont corrects en UTF-8.
