# CLAUDE.md — Polypode (Addon WoW)

## Contexte du projet

Addon World of Warcraft Retail (Interface 120000) dédié au **multiboxing**.
Objectif : gérer *simplement* plusieurs personnages joués simultanément dans plusieurs
fenêtres/clients WoW sur la même machine (roster des personnages, désignation d'un
leader, synchronisation d'infos de base entre clients). Même famille d'outils que
TeamManager, MAMA, EMA et DynamicBoxer, mais volontairement plus minimaliste : on
n'ajoute une fonctionnalité que si elle sert directement cet objectif.

- **Langue du code** : commentaires en français, code (variables/fonctions) en anglais.
- **Style** : minimaliste, lisible, pas de dépendance externe obligatoire.
- **Dépendances optionnelles** : EllesmereUI et ElvUI (skinning via `UI_Skin.lua`), jamais requises pour charger.

---

## Architecture

| Fichier | Rôle |
|---|---|
| `Core.lua` | Table globale `Polypode` (alias local `P`), SavedVariables, CRUD du roster, équipes (`P.CreateTeam`, `P.GetTeams`, `P.GetTeamMembers`, `P.AddTeamMember`, `P.RemoveTeamMember` ; `P.db.teams[nom] = { name, members = { [nom-royaume] = true } }`, `members` créé à la volée pour les anciennes équipes ; `P.RemoveCharacter` retire aussi le perso des équipes) |
| `Sync.lua` | Broadcast/réception de messages addon (`C_ChatInfo`), token d'équipe (`P.GetTeamToken`, hash du BattleTag), annonce `HELLO` / réponse `HI` |
| `UI_Skin.lua` | Skinning conditionnel : EllesmereUI (`EllesmereUI.RegisterSkin`, prioritaire) puis ElvUI. `P.SkinFrame` (fenêtre top-level), `P.SkinPanel` (cadre intérieur), `P.SkinScrollBar` (barre de défilement), `P.SkinEditBox` (champ de saisie), `P.SkinButton` (bouton texte) |
| `UI_Main.lua` | Fenêtre principale redimensionnable (`P.ui.resizeGrip`, taille dans `P.db.mainFrame`) : `BuildUI`, `RefreshUI`, `ToggleUI`. Trois cadres à liste défilante (`panel.scrollBox`, `panel.scrollBar`, `panel.emptyText`), un tiers de largeur chacun (`LayoutPanels` sur `OnSizeChanged`) : `P.ui.charPanel` (personnages trouvés = roster trié ; avec une équipe sélectionnée, clic gauche = ajout, clic droit = retrait, membres surlignés), `P.ui.teamPanel` (équipes : `P.ui.teamInput` + `P.ui.teamCreateButton` → `P.CreateTeam`, liste triée, clic = sélection dans la locale `selectedTeam`, session uniquement), `P.ui.memberPanel` (« Personnages de l'équipe » : membres de l'équipe sélectionnée, clic droit = retrait) |
| `UI_Minimap.lua` | Bouton de minimap sans librairie (`P.BuildMinimapButton`, appelé à `PLAYER_LOGIN`), `P.SetMinimapButtonShown`, état dans `P.db.minimap` (`angle`, `hide`) |
| `UI_Options.lua` | Panneau Options → AddOns via l'API `Settings` (`P.BuildOptions` à `PLAYER_LOGIN`, `P.OpenOptions`) |
| `Commands.lua` | Commande slash `/poly` (`/polypode`) et fonctions globales de keybinding |
| `Events.lua` | Handlers `ADDON_LOADED`, `PLAYER_LOGIN`, `CHAT_MSG_ADDON` |
| `Bindings.xml` | Déclaration XML des raccourcis clavier WoW |
| `Polypode.toc` | Manifeste — définit l'ordre de chargement des fichiers |

**État partagé** : tout passe par la table globale `Polypode` (raccourci local `local P = Polypode`
en tête de chaque fichier). Ex. `P.db` (= `PolypodeDB`), `P.charDb` (= `PolypodeCharDB`), `P.ui`.

---

## Conventions de code (à respecter impérativement)

1. **Pas de librairie externe** sauf ElvUI et EllesmereUI (optionnels, toujours protégés par
   `if ElvUI then` / `if EllesmereUI and EllesmereUI.RegisterSkin then`).
2. **Toutes les fonctions publiques** sont attachées à `Polypode` : `function P.MaFonction() end`,
   avec `local P = Polypode` en haut du fichier.
3. **Les fonctions locales** restent locales à leur fichier (`local function ...`).
4. **SavedVariables account-wide** → `P.db` (= `PolypodeDB`).
5. **SavedVariables per-character** → `P.charDb` (= `PolypodeCharDB`).
6. **Pas de `print()`** en production — utiliser `P.Debug(msg)`, qui respecte `P.debugEnabled`.
7. **Messages de sync** : toujours via `P.SYNC_PREFIX`, jamais de préfixe en dur ailleurs.
8. **UI** : frames créées avec `CreateFrame`, toutes référencées dans `P.ui.*`.
9. **Ordre de chargement** respecte le `.toc` (`Core → Sync → UI_Skin → UI_Main → UI_Minimap → UI_Options → Commands → Events → Bindings`).
   Ne jamais appeler au niveau fichier (hors fonction) une fonction définie dans un fichier chargé après.
   Les appels **à l'intérieur** d'une fonction peuvent référencer un fichier suivant (résolu à l'exécution).
10. **Pas de globals parasites** : toute variable de module doit être `local` ou sous `Polypode.`
    (exception : les fonctions de keybinding `POLYPODE_*` et les `BINDING_*`, imposées par l'API WoW).
11. **Conserver le bloc de commentaire en tête de chaque fichier** (`-- Polypode: NomFichier — rôle`).
12. **Prérequis de toute évolution UI : tout contenu de taille variable défile, sans limite.**
    Chaque nouveau panneau, liste ou fenêtre doit pouvoir défiler, même si peu d'éléments sont
    attendus aujourd'hui. Jamais de pile de lignes à hauteur fixe qui déborde du cadre. Pour une
    liste : `CreateScrollList(panel, formatFn [, top, opts])` + `SetListData(panel, items)` dans `UI_Main.lua`
    (`opts.onClick(data, mouseButton)` rend les lignes cliquables, `opts.isSelected(data)` les surligne, `opts.tooltip(data)` renvoie les lignes de l'infobulle au survol — toute action au clic doit y être rappelée ; les lignes
    étant recyclées, tout état visuel se recalcule dans l'initializer, jamais stocké sur la ligne)
    (ScrollBox Blizzard virtualisée + `MinimalScrollBar`, skinnée via `P.SkinScrollBar`).
13. **Fenêtres redimensionnables** : la fenêtre principale se redimensionne (poignée bas-droite,
    `SetResizeBounds`, taille dans `P.db.mainFrame`). Tout contenu s'ancre en relatif aux bords
    (pas de largeur fixe calculée) ; trop petite, on tronque sans réorganiser : textes sur une
    ligne (`SetWordWrap(false)` + ancres gauche/droite). Pas de `SetClipsChildren` sur la fenêtre
    skinnée (risque de rogner la bordure du skin).

---

## Règle de simplicité (spécifique à Polypode)

Ce projet est né en réaction à des addons multibox devenus complexes (EMA, DynamicBoxer).
Avant d'ajouter une fonctionnalité :

- Vérifier qu'elle sert directement l'objectif "gérer simplement plusieurs personnages/fenêtres".
- Préférer étendre une fonction existante (`AddCharacter`, `Broadcast`, ...) plutôt que créer un
  nouveau sous-système.
- Ne jamais livrer de fonctionnalité à moitié implémentée : soit elle fonctionne réellement
  (testée mentalement contre le flux `.toc`), soit elle n'est pas incluse dans cette session
  et reste documentée comme piste dans le README.

---

## Règles pour les modifications demandées à l'IA

- **Toujours lire** le fichier cible avant de le modifier.
- **Ne jamais créer** de nouveaux globals non préfixés `Polypode.` (hors bindings, cf. règle 10).
- **Tester mentalement** l'ordre de chargement (`.toc`) avant d'ajouter un appel inter-fichiers.
- Si une modification touche la synchronisation, **mettre à jour `Sync.lua` ET le handler
  `CHAT_MSG_ADDON` dans `Events.lua`**.
- Si une modification touche l'UI, vérifier la compatibilité **ElvUI** dans `UI_Skin.lua`.
- Toujours proposer le diff **fichier par fichier**.
- Après **chaque** modification, sans attendre qu'on le demande :
  1. mettre à jour la section correspondante du `README.md` (commandes, raccourcis, fonctionnalités, apparence) ;
  2. mettre à jour ce `CLAUDE.md` si l'architecture, les conventions ou les dépendances changent ;
  3. commiter puis pousser (`git push`) sur `origin`.

---

## Patterns récurrents

### Ajouter une commande slash
→ Modifier uniquement `Commands.lua`, dans le bloc `elseif sub == "..."` de `SlashHandler`.

### Ajouter un événement WoW
→ Enregistrer via `frame:RegisterEvent(...)` et ajouter une branche `elseif event == "..."`
dans `Events.lua`.

### Ajouter un champ persistant au roster
→ Étendre `P.defaults.roster` (ou l'entrée d'un personnage) dans `Core.lua`, avec une valeur
par défaut explicite gérée par `CopyDefaults`.

### Ajouter un widget UI
→ Créer dans `UI_Main.lua`, référencer via `P.ui.monWidget`, appeler `P.SkinFrame(widget)`
si c'est un frame top-level. Exposer le titre en `frame.TitleText` et le bouton de fermeture
en `frame.CloseButton` : `P.SkinFrame` les retrouve sous ces noms (le skin EllesmereUI recentre
le titre dans sa barre de titre de 25 px, ElvUI skinne le `CloseButton`). Un cadre intérieur
(sous-panneau) se skinne avec `P.SkinPanel(panel)`.

### Ajouter une option au panneau (Options → AddOns → Polypode)
→ Dans `P.BuildOptions` (`UI_Options.lua`) : `Settings.RegisterProxySetting` avec getter/setter
qui lisent/écrivent `P.db` (valeur par défaut dans `P.defaults`, `Core.lua`), puis
`Settings.CreateCheckbox`. Le proxy garde la case synchronisée si une commande slash change
la même valeur. Si l'option pilote un frame, passer par une fonction `P.Set...` commune au
setter et à la commande slash (ex. `P.SetMinimapButtonShown`).

### Envoyer un message de synchronisation
→ Utiliser `P.Broadcast(message, channel)` défini dans `Sync.lua`. Format de message :
`"TYPE:token:champ1:champ2:..."` (voir `HELLO` comme exemple), parsé avec `strsplit(":", message)`.
Le 2e champ est **toujours** le token d'équipe (`P.GetTeamToken()`) : `P.OnSyncMessage` rejette
tout message dont le token diffère (autres joueurs Polypode de la guilde) et ignore nos propres
messages (renvoyés par le serveur à l'émetteur). Un message qui appelle une réponse doit avoir un
type de réponse distinct (`HELLO` → `HI`) pour ne jamais boucler.

### Référencer l'API Blizzard pour une nouvelle fonctionnalité
→ Avant d'implémenter un appel à l'API WoW (frames, events, namespaces `C_*`), vérifier la
signature exacte plutôt que de deviner. Deux sources, par ordre de préférence :
1. **Local** : un clone de `wow-ui-source` placé à côté de `Polypode/` dans `AddOns/`, si présent.
2. **GitHub** : https://github.com/Gethe/wow-ui-source/

---

## Anti-patterns à éviter

- ❌ `print()` sans passer par `P.Debug`.
- ❌ Variables globales hors `Polypode.*` (sauf bindings `POLYPODE_*`/`BINDING_*`).
- ❌ `C_ChatInfo.SendAddonMessage` appelé directement hors `Sync.lua`.
- ❌ Hard-coder le préfixe `"POLYPODE"` ailleurs que dans `P.SYNC_PREFIX`.
- ❌ Créer des frames hors de `UI_Main.lua` (ou d'un `UI_*.lua` dédié, ex. `UI_Minimap.lua`).
- ❌ Renommer `PolypodeMinimapButton` ou lui donner un nom finissant par un chiffre : les addons
  de minimap (EllesmereUIMinimap, WindTools) détectent les boutons par leur nom.
- ❌ Modifier `Polypode.toc` sans vérifier les dépendances inter-fichiers.
- ❌ Ajouter une fonctionnalité "juste au cas où" qui ne sert pas l'objectif du projet
  (cf. Règle de simplicité ci-dessus).
