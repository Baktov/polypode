# Polypode

Addon World of Warcraft pour **gérer simplement plusieurs personnages joués dans
plusieurs fenêtres WoW sur le même PC** (multiboxing).

Polypode s'inspire de TeamManager, MAMA, EMA et DynamicBoxer, mais vise volontairement
la simplicité : un roster de vos personnages, des équipes avec leur leader, et une synchronisation
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
- Vous regroupez vos personnages en **équipes**, chacune avec son **leader** (voir
  Fenêtre principale) — base pour de futures actions liées au leader : suivi, assist, etc.
- **Les équipes sont synchronisées automatiquement** entre vos clients Polypode connectés :
  création, ajout/retrait d'un membre et changement de leader sont envoyés aussitôt aux
  autres clients, et deux clients qui se découvrent (connexion, reload) échangent toutes
  leurs équipes. En cas de versions différentes, **la plus récente l'emporte** : un client
  démarré sur une sauvegarde ancienne ne peut pas écraser une modification plus récente.
  C'est indispensable si vos comptes partagent le même fichier de sauvegarde (jonctions
  de dossiers `SavedVariables`) : chaque client réécrit ce fichier en entier à la
  déconnexion, tous doivent donc avoir les mêmes équipes en mémoire.
  Les messages « Aucun joueur nommé … n'est connecté » provoqués par la synchro vers un
  personnage hors ligne sont masqués.
- **Quêtes** : quand le leader de l'équipe choisit une quête dans le dialogue d'un PNJ, l'accepte
  ou la rend, les autres personnages du groupe font de même dès que le PNJ leur propose la quête
  (options « Choisir automatiquement les quêtes dans les dialogues », « Accepter automatiquement
  les quêtes » et « Valider automatiquement les quêtes », voir Options).
- Les **ajouts et retraits manuels de personnages** (bouton « Ajouter la cible »,
  `/poly remove`) sont synchronisés de la même façon, avec la même règle de version : un
  personnage retiré ne réapparaît pas via un client qui l'avait encore (il réapparaît
  seulement s'il se reconnecte lui-même avec Polypode).

---

## Fenêtre principale

Ouverte par `/poly ui`, le raccourci clavier ou le bouton de minimap. Le bouton **Options** (en haut
à gauche de la barre de titre) ouvre directement le panneau d'options de Polypode. Trois cadres
côte à côte :

- **Personnages trouvés** : tous les personnages de votre équipe détectés via les canaux
  (groupe, raid, guilde), triés par nom. Nom en couleur de classe, puis classe et niveau ;
  `(vous)` marque le personnage courant.
  Bouton **Ajouter la cible** (en haut du cadre) : ajoute le joueur ciblé à la liste, même
  s'il n'a pas Polypode (ex. un ami) ; il peut alors rejoindre une équipe et être invité
  avec elle. L'ajout est partagé avec vos autres Polypode connectés.
  Quand une équipe est sélectionnée : **clic gauche** sur un personnage l'ajoute à l'équipe,
  **clic droit** l'en retire ; les membres de l'équipe sont surlignés en doré. Une infobulle au survol donne le nom du personnage, rappelle ces actions, puis liste les équipes dont il fait déjà partie (l'équipe sélectionnée en vert).
- **Équipes** : saisir un nom dans le champ « Nom de l'équipe » puis valider avec
  **Entrée** ou le bouton **Créer** : l'équipe est créée et ajoutée à la liste (triée par
  nom, mémorisée pour le compte). Un nom vide ou déjà utilisé est refusé avec un message
  en rouge à l'écran. **Échap** quitte le champ. **Cliquer** sur une équipe la sélectionne
  (surbrillance dorée). La sélection est **mémorisée pour chaque personnage** : après une
  déconnexion, une reconnexion ou un reload, la même équipe est sélectionnée, que ce
  personnage en soit le leader ou non (une équipe reçue via « Inviter l'équipe » devient
  aussi la sélection mémorisée).
- **Personnages de l'équipe** : membres de l'équipe sélectionnée, triés par nom, même
  présentation que les personnages trouvés.
  - **Clic gauche** sur un membre : il devient **leader de l'équipe** (surbrillance dorée et
    `[leader]`). Chaque équipe a son propre leader.
  - **Clic droit** : retire le membre de l'équipe ; si c'était le leader, l'équipe n'a plus
    de leader.
  - L'infobulle au survol rappelle ces actions et liste les équipes du personnage, avec
    `(leader)` là où il l'est.
  - Bouton **Inviter l'équipe** (en haut du cadre) : invite dans votre groupe tous les
    membres de l'équipe sélectionnée, sauf le personnage courant et ceux déjà groupés.
    **Actif uniquement sur le client du leader de l'équipe** (grisé sinon, l'infobulle
    indique pourquoi : pas d'équipe sélectionnée, pas de leader, autre leader, ou aucun
    autre membre).
    Il faut être seul ou chef du groupe (ou assistant en raid). Un groupe (hors raid) est
    limité à 5 : au-delà, les invitations restantes sont signalées ; convertissez le groupe
    en raid puis cliquez à nouveau. Le bilan s'affiche au centre de l'écran.
    Le même clic envoie aussi l'équipe au Polypode de chaque membre (sur vos autres
    comptes), qui la **sélectionne** : ses personnages apparaissent aussitôt dans
    « Personnages de l'équipe », même avant que les invités aient accepté.

  Les équipes, leurs membres et leur leader sont mémorisés pour le compte ; un personnage
  retiré du roster (`/poly remove`) quitte aussi ses équipes.

Les trois listes défilent (molette ou barre de défilement), sans limite de nombre.

La fenêtre se **redimensionne** par la poignée du coin bas-droit ; les trois cadres se
partagent la largeur à parts égales et la taille est mémorisée pour le compte (720 × 320
par défaut). Si la fenêtre est très réduite, le contenu est simplement tronqué.

---

## Commandes slash (`/poly` ou `/polypode`)

| Commande | Description |
|---|---|
| `/poly list` | Lister les personnages connus (roster) |
| `/poly addme` | Ajouter/réannoncer le personnage courant |
| `/poly remove <nom-royaume>` | Retirer un personnage du roster |
| `/poly ui` | Ouvrir/fermer la fenêtre principale |
| `/poly minimap` | Afficher/masquer l'icône de minimap |
| `/poly options` | Ouvrir le panneau d'options (Options → AddOns → Polypode) |
| `/poly debug` | Activer/désactiver les messages de debug (mémorisé pour ce personnage, comme la case du panneau d'options) |
| `/poly` (sans argument) | Afficher l'aide |

Le nom d'un personnage dans le roster est au format `Nom-Royaume` (ex. `Arthas-Hyjal`).

---

## Raccourcis clavier

Configurable dans le menu des raccourcis WoW, catégorie **Polypode** :

| Raccourci | Action |
|---|---|
| Ouvrir/Fermer l'interface | Basculer la fenêtre principale |
| Se nommer leader de l'équipe | Le personnage courant devient leader de l'équipe sélectionnée (il y entre s'il n'en est pas membre) ; synchronisé avec vos autres Polypode |
| Suivre le leader | Suit (`/follow`) le leader de l'équipe sélectionnée |
| Assister le leader | Assiste (`/assist`) le leader de l'équipe sélectionnée : prend sa cible, puis attaque (`/startattack`) si l'option « Attaquer après l'assistance » est cochée |
| Inviter l'équipe | Même action que le bouton « Inviter l'équipe » (réservée au leader) |

Toutes les actions portent sur **l'équipe sélectionnée pour ce personnage** (mémorisée, cf.
Fenêtre principale). « Suivre » et « Assister » sont des actions protégées par WoW : la touche
est confiée à un bouton sécurisé Blizzard qui exécute la macro, elles fonctionnent donc aussi
en combat. Seul le changement de leader, d'équipe ou de touche pendant un combat n'est pris
en compte qu'à la sortie du combat. Sans leader utilisable (pas d'équipe, pas de leader, ou
vous êtes le leader), la touche affiche un message à l'écran.

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

Panneau dans **Options → AddOns → Polypode** (ou `/poly options`, ou le bouton **Options** de la
fenêtre principale) :

| Option | Défaut | Effet |
|---|---|---|
| Afficher l'icône de minimap | Oui | Affiche le bouton Polypode autour de la minimap |
| Mode debug | Non | Affiche dans le chat les messages de diagnostic (synchro, invitations...). Réglage **par personnage** : on peut l'activer sur une seule fenêtre |
| Attaquer après l'assistance | Oui | Le raccourci « Assister le leader » lance aussi l'attaque automatique (`/startattack`) sur la cible prise si elle est hostile ; décoché, il prend seulement la cible. Réglage **par personnage** (ex. décoché sur un soigneur) |
| Accepter automatiquement les quêtes | Oui | Quand le leader de l'équipe accepte une quête, ce personnage l'accepte aussi dès qu'elle lui est proposée (PNJ ouvert, jusqu'à 30 s après). Réglage **par personnage** ; doit être coché sur le leader (qui annonce ses quêtes) et sur les membres |
| Valider automatiquement les quêtes | Oui | Quand le leader rend une quête (« Continuer » puis « Terminer la quête »), ce personnage la rend aussi avec le **même index de récompense**, dès que le PNJ est ouvert (jusqu'à 60 s après). Une récompense au choix qui ne convient pas reste à choisir à la main. Réglage **par personnage**, à cocher sur le leader et les membres |
| Choisir automatiquement les quêtes dans les dialogues | Oui | Quand le leader choisit une quête dans le dialogue d'un PNJ (disponible ou à rendre), ce personnage choisit la même si son dialogue avec le PNJ est ouvert ; l'acceptation ou la validation automatique enchaîne. Réglage **par personnage**, à cocher sur le leader et les membres |

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

Version `0.21.0` : roster, sync filtrée par token d'équipe (BattleTag) avec réponse
automatique aux annonces, fenêtre redimensionnable à trois listes défilantes (personnages
trouvés / équipes avec création par saisie et sélection / personnages de l'équipe, ajout
et retrait de membres au clic, leader par équipe, invitation de toute l'équipe, synchronisation automatique et versionnée des équipes, ajout du joueur ciblé)
skinnée (EllesmereUI/ElvUI), bouton de minimap (masquable), panneau d'options (accessible par un bouton de la fenêtre),
commandes, raccourcis clavier (interface, se nommer leader, suivre, assister, inviter), sélection (dialogues de PNJ), acceptation et validation automatiques des quêtes du leader. Pistes envisagées pour la suite,
à activer seulement si le besoin se confirme (voir la règle de simplicité dans
`CLAUDE.md`) :

- `/poly team <nom>` : nom d'équipe commun remplaçant le BattleTag dans le calcul du
  token, pour multiboxer avec **plusieurs comptes Battle.net** (point d'extension :
  `P.GetTeamToken()` dans `Sync.lua`).
- Réannonce à l'entrée en groupe (`GROUP_ROSTER_UPDATE`) pour les personnages sans
  guilde commune connectés avant d'être groupés.
- **Équipes** : renommer/supprimer une équipe ; usage des équipes (conversion en raid automatique, leader,
  synchronisation des suppressions d'équipe le jour où la suppression existera).
- Invitation automatique du groupe depuis le roster.
- Skin des textes de la fenêtre (police EllesmereUI via `S.Font`).

---

## Remerciements

Inspiré des addons multibox TeamManager, M.A.M.A. et DynamicBoxer (MooreaTV) et EMA
(Ebony/Blossom).
