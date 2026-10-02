# Modules Polypode : conventions communes et documentation

Fichier partagé, **importé** (`@`) par le `CLAUDE.md` de Polypode, par celui de chaque compagnon
(`@../Polypode/MODULES.md`) et par `Interface/AddOns/CLAUDE.md` : il est donc chargé quel que soit
le dossier ouvert. À garder court ; le détail propre à un module va dans son `CLAUDE.md`.

## Les modules

Chaque module est un **dépôt git séparé** (dossier voisin dans `Interface/AddOns`) avec **son
propre `CLAUDE.md` et son `README.md`** :

| Dossier | Dépôt | Rôle |
|---|---|---|
| `Polypode` | <https://github.com/Baktov/polypode> | cœur : roster, équipes, synchro, fenêtre, API des compagnons |
| `Polypode_Data` | <https://github.com/Baktov/polypode-data> | données durables des personnages (bouton Data) |
| `Polypode_Photo` | <https://github.com/Baktov/Polypode-Photo> | mode photo (bouton Photo) |
| `Polypode_Profil` | <https://github.com/Baktov/polypode-profil> | bibliothèque de chaînes d'export (bouton Profils) |
| `Polypode_Quetes` | <https://github.com/Baktov/Polypode-quetes> | quêtes de l'équipe (bouton Quêtes) |
| `Polypode_Suivi` | <https://github.com/Baktov/polypode-suivi> | suivi de l'équipe et des campagnes (bouton Suivi) |

Les compagnons dépendent de Polypode (`## Dependencies: Polypode`) et n'utilisent que son API
publique `P.*`, listée dans la section « Dépendances vers Polypode » de leur `CLAUDE.md`.

## Conventions communes (tous les modules)

- Commentaires en **français**, code (variables, fonctions) en **anglais**.
- Pas de librairie externe (ElvUI / EllesmereUI : optionnels, toujours testés avant usage).
- **Pas de `print()`** : `P.Debug(msg)` (mode debug), ou `UIErrorsFrame:AddMessage` pour un message
  à l'écran.
- Bloc de commentaire en tête de chaque fichier : `-- Polypode X: Fichier — rôle`.
- Pas de global parasite : tout est `local`, dans la table d'addon (`ns`) ou sous `Polypode.`.
- Retail (Interface 120000) et **WoW Forever** (16001) : tester l'existence de toute API récente
  (`if C_X and C_X.Fn then`), lectures fragiles sous `pcall` ; ne pas se fier à `WOW_PROJECT_ID`.
- Tout contenu de taille variable **défile** (`P.CreateScrollList` / `P.SetListData`).
- **Simplicité** : n'ajouter une fonctionnalité que si elle sert directement le module ; jamais à
  moitié implémentée.
- Toujours **lire** le fichier cible avant de le modifier ; vérifier les API WoW avec les serveurs
  MCP `wow` / `wow-addon-api` / `wow-api` plutôt que de mémoire.

## Avant de toucher un module

Lire **son** `CLAUDE.md` (architecture, dépendances, procédures propres), en plus de ce fichier.

## Après chaque modification d'un module

Dans **son** dépôt, sans attendre qu'on le demande :

1. **Version** : incrémenter `## Version` du `.toc` (correctif : 3e chiffre ; fonctionnalité :
   2e chiffre) et l'indiquer entre parenthèses à la fin du message de commit, « Description (1.2.3) ».
   Un commit de documentation seule ne change pas de version.
2. **README.md** : ajouter en tête de la section « Version » la ligne `` `x.y.z` : description. ``
   (du plus récent au plus ancien), et mettre à jour les sections d'utilisation concernées
   (colonnes, boutons, infobulles, options, commandes, fonctionnement).
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

## Outillage (Windows)

Écrire les messages de commit et les scripts contenant des accents ou des échappements Lua
(`\195`, `\\`) dans un fichier (`git commit -F fichier`, script `.py` écrit tel quel), jamais par
un heredoc bash passé à Python, qui les déforme. La console Windows affiche mal les accents
(« � ») même quand les fichiers et les commits sont corrects en UTF-8.
