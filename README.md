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
  Polypode annonce votre personnage (nom, classe, niveau) à vos autres clients, qui
  répondent en s'annonçant à leur tour : chaque roster connaît tous les personnages,
  quel que soit l'ordre de connexion.
- **Seuls vos personnages sont reconnus** : chaque annonce porte un token d'équipe tiré
  de votre BattleTag (haché, jamais envoyé en clair). Les autres joueurs de la guilde
  qui utilisent Polypode sont ignorés. Tous vos comptes WoW doivent donc être rattachés
  au **même compte Battle.net**.
- Vous pouvez désigner un **leader** parmi les personnages du roster — c'est pour
  l'instant une simple étiquette affichée dans la liste (base pour de futures actions
  liées au leader : suivi, assist, etc.).

---

## Fenêtre principale

Ouverte par `/poly ui`, le raccourci clavier ou le bouton de minimap. Deux cadres côte à côte :

- **Personnages trouvés** : tous les personnages de votre équipe détectés via les canaux
  (groupe, raid, guilde), triés par nom. Nom en couleur de classe, puis classe et niveau ;
  `(vous)` marque le personnage courant, `[leader]` le leader désigné.
- **Équipes gérées** : emplacement réservé, contenu à définir dans une prochaine version.

---

## Commandes slash (`/poly` ou `/polypode`)

| Commande | Description |
|---|---|
| `/poly list` | Lister les personnages connus (roster) |
| `/poly addme` | Ajouter/réannoncer le personnage courant |
| `/poly remove <nom-royaume>` | Retirer un personnage du roster |
| `/poly leader <nom-royaume>` | Désigner le leader |
| `/poly ui` | Ouvrir/fermer la fenêtre principale |
| `/poly minimap` | Afficher/masquer l'icône de minimap |
| `/poly options` | Ouvrir le panneau d'options (Options → AddOns → Polypode) |
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

## Bouton de minimap

Un bouton en forme de **main** est placé autour de la minimap :

- **Clic gauche** : ouvrir/fermer la fenêtre Polypode.
- **Glisser** : déplacer le bouton autour de la minimap (position mémorisée pour le compte).
  Fonctionne avec une minimap ronde ou carrée (ElvUI).

Avec **EllesmereUI Minimap**, le bouton est rangé automatiquement dans le tiroir de
boutons d'EllesmereUI, qui gère alors sa position.

Pour masquer ou réafficher le bouton : `/poly minimap`, ou la case correspondante dans
le panneau d'options. Le choix est mémorisé pour le compte.

---

## Options

Panneau dans **Options → AddOns → Polypode** (ou `/poly options`) :

| Option | Défaut | Effet |
|---|---|---|
| Afficher l'icône de minimap | Oui | Affiche le bouton Polypode autour de la minimap |

---

## Apparence

La fenêtre s'adapte automatiquement à votre interface, sans configuration :

| Interface détectée | Rendu |
|---|---|
| **EllesmereUI** | Style EllesmereUI (fond, bordure, barre de titre avec titre centré, cadres intérieurs, bouton de fermeture) selon votre thème. Désactivable dans EllesmereUI → Blizz UI Enhanced → Blizzard Window Skins → Third-Party Addons (nécessite le module EllesmereUI Blizzard Skin). |
| **ElvUI** | Style ElvUI (fond, cadres intérieurs et bouton de fermeture). |
| Aucune | Fond sombre générique. |

Si EllesmereUI et ElvUI sont tous deux chargés, EllesmereUI est prioritaire (sauf si
vous avez désactivé le skin de Polypode dans ses options).

---

## État du projet

Version `0.5.0` : roster, sync filtrée par token d'équipe (BattleTag) avec réponse
automatique aux annonces, fenêtre à deux cadres (personnages trouvés / équipes gérées)
skinnée (EllesmereUI/ElvUI), bouton de minimap (masquable), panneau d'options,
commandes, raccourci clavier. Pistes envisagées pour la suite,
à activer seulement si le besoin se confirme (voir la règle de simplicité dans
`CLAUDE.md`) :

- `/poly team <nom>` : nom d'équipe commun remplaçant le BattleTag dans le calcul du
  token, pour multiboxer avec **plusieurs comptes Battle.net** (point d'extension :
  `P.GetTeamToken()` dans `Sync.lua`).
- Réannonce à l'entrée en groupe (`GROUP_ROSTER_UPDATE`) pour les personnages sans
  guilde commune connectés avant d'être groupés.
- **Équipes gérées** : définir ce qu'est une équipe et remplir le cadre de droite.
- Défilement de la liste des personnages trouvés au-delà d'une dizaine de personnages.
- Suivi automatique du leader (`follow`) et assist de cible.
- Invitation automatique du groupe depuis le roster.
- Skin des textes de la fenêtre (police EllesmereUI via `S.Font`).

---

## Remerciements

Inspiré des addons multibox TeamManager, M.A.M.A. et DynamicBoxer (MooreaTV) et EMA
(Ebony/Blossom).
