# CLAUDE.md — Polypode Modele (Addon WoW)

Conventions communes et procédure de documentation de tous les modules Polypode (chargées
automatiquement, quel que soit le dossier ouvert) :

@../Polypode/MODULES.md

Addon compagnon de **Polypode** (dossier voisin `../Polypode`, dépôt séparé) : (rôle du module en
une phrase). Rester **simple** : on n'ajoute une fonctionnalité que si elle sert directement ce rôle.

## Architecture

| Fichier | Rôle |
|---|---|
| `Polypode_Modele.toc` | `## Dependencies: Polypode`, SavedVariables de compte `PolypodeModeleData` (données de chaque personnage, `[nom-royaume] = { zone, at }`) et par personnage `PolypodeModeleDB` (options, `DEFAULTS` complétés à `ADDON_LOADED`) |
| `Modele.lua` | Lecture du personnage joué (`OwnZone`) ; synchro : message `MODELE:token:nom-royaume:zone` (`SendOwn` par `P.WhisperOnline`, à chaque HELLO/HI via `P.RegisterPeerCallback` et 2 s après `PLAYER_ENTERING_WORLD` / `ZONE_CHANGED_NEW_AREA` ; reçu par `P.RegisterMessageHandler("MODELE")` → `OnMessage`, expéditeur vérifié par `P.IsSender`) ; fenêtre `PolypodeModeleFrame` (`P.ToggleModele`, `P.RefreshModele`, `P.ui.modeleFrame` / `modelePanel`) : liste défilante du roster (`P.SortedKeyItems`, personnage joué en tête), infobulle `ItemTooltip` ; bouton `P.AddTitleButton` (`P.ui.modeleButton`), commande `/poly modele` ; option `showRealm` (sous-catégorie « Modele » de `P.optionsCategory`, `BuildSettingsPanel` à `PLAYER_LOGIN` + 1 image) ; `P.RegisterCharacterData` (personnage supprimé dans Polypode → données oubliées) ; suit `P.RefreshUI` (`hooksecurefunc`) |

## Dépendances vers Polypode (API publique utilisée)

`P.AddTitleButton`, `P.RegisterSlashCommand`, `P.RegisterMessageHandler`, `P.RegisterPeerCallback`,
`P.WhisperOnline`, `P.IsSender`, `P.MAX_MESSAGE_LENGTH`, `P.GetTeamToken`, `P.GetCharKey`,
`P.GetDisplayName`, `P.db.roster`, `P.SortedKeyItems`, `P.optionsCategory`, `P.CreatePanel`,
`P.CreateScrollList`, `P.SetListData`, `P.SkinFrame`, `P.SkinPanel`, `P.RegisterCharacterData`,
`P.RefreshUI` (accroche), `P.ui`. Toute évolution de ces fonctions dans Polypode doit rester
compatible, ou ce fichier doit suivre.

## Pistes

- (idées écartées ou à venir)

## Après chaque modification

Appliquer la procédure de `../Polypode/MODULES.md` (« Après chaque modification d'un module »),
sans attendre qu'on le demande : version du `.toc` et du commit, ligne en tête de la section
« Version » du `README.md` et sections d'utilisation, ce fichier (architecture, dépendances),
Polypode si le périmètre change, puis commit et push sur `origin` (https://github.com/Baktov/polypode-modele).
