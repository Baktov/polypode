# Polypode

Addon World of Warcraft pour **gérer simplement plusieurs personnages joués dans
plusieurs fenêtres WoW sur le même PC** (multiboxing).

Polypode s'inspire de TeamManager, MAMA, EMA et DynamicBoxer, mais vise volontairement
la simplicité : un roster de vos personnages, un leader désigné, et une synchronisation
automatique de base entre vos clients — sans configuration complexe.

---

## Installation

1. Le dossier `Polypode` doit se trouver dans :
   `World of Warcraft/_retail_/Interface/AddOns/Polypode`
2. Activer l'addon dans l'écran de sélection de personnage (AddOns).
3. Répéter sur chaque fenêtre/client WoW que vous utilisez pour multiboxer.

---

## Fonctionnement

- À la connexion, Polypode enregistre automatiquement votre personnage courant dans
  un roster partagé (sauvegardé au niveau du compte).
- Si vous êtes en groupe, en raid ou dans une guilde commune avec vos autres clients,
  Polypode annonce votre personnage (nom, classe, niveau) aux autres clients qui ont
  aussi Polypode chargé : leur roster se met à jour automatiquement.
- Vous pouvez désigner un **leader** parmi les personnages du roster — c'est pour
  l'instant une simple étiquette affichée dans la liste (base pour de futures actions
  liées au leader : suivi, assist, etc.).

---

## Commandes slash (`/poly` ou `/polypode`)

| Commande | Description |
|---|---|
| `/poly list` | Lister les personnages connus (roster) |
| `/poly addme` | Ajouter/réannoncer le personnage courant |
| `/poly remove <nom-royaume>` | Retirer un personnage du roster |
| `/poly leader <nom-royaume>` | Désigner le leader |
| `/poly ui` | Ouvrir/fermer la fenêtre principale |
| `/poly debug` | Activer/désactiver les messages de debug |
| `/poly` (sans argument) | Afficher l'aide |

Le nom d'un personnage dans le roster est au format `Nom-Royaume` (ex. `Arthas-Hyjal`).

---

## Raccourcis clavier

Configurable dans le menu des raccourcis WoW, catégorie **Polypode** :

| Raccourci | Action |
|---|---|
| Polypode: Ouvrir/Fermer l'interface | Basculer la fenêtre principale |

---

## État du projet

Version initiale (`0.1.0`) : structure de base fonctionnelle (roster, sync simple,
fenêtre de liste, commandes, raccourci clavier). Pistes envisagées pour la suite,
à activer seulement si le besoin se confirme (voir la règle de simplicité dans
`CLAUDE.md`) :

- Suivi automatique du leader (`follow`) et assist de cible.
- Bouton minimap.
- Invitation automatique du groupe depuis le roster.
- Compatibilité ElvUI plus poussée pour la fenêtre principale (le hook existe déjà
  dans `UI_Skin.lua`).

---

## Remerciements

Inspiré des addons multibox TeamManager, M.A.M.A. et DynamicBoxer (MooreaTV) et EMA
(Ebony/Blossom).
