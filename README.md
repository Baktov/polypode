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
- **Canal dédié** (optionnel) : le plus simple reste de grouper vos personnages à la première
  connexion (ou d'avoir une guilde commune), sans rien régler. Le canal dédié sert dans les autres
  cas : plusieurs comptes WoW ou Battle.net, personnages sans guilde commune, pas encore groupés.
  C'est un nom de canal commun à vos comptes, saisi dans la fenêtre
  (champ « Canal » à droite du bouton Options) ou dans le panneau d'options. Chaque client le
  rejoint automatiquement (5 secondes après la connexion, pour ne pas prendre le numéro du canal
  Général) sans l'afficher dans le chat. Il joue le rôle d'une guilde commune pour les annonces
  de connexion : vos Polypode se trouvent même sans guilde commune ni groupe, et il est
  prioritaire sur le raid, le groupe et la guilde. Le choix est partagé avec vos autres Polypode
  connectés. Nom : sans espace ni « : », ne commençant pas par un chiffre, 31 caractères au
  plus ; vide pour désactiver.
- **Seuls vos personnages sont reconnus** : chaque annonce porte un token d'équipe tiré
  de votre BattleTag (haché, jamais envoyé en clair). Les autres joueurs de la guilde
  qui utilisent Polypode sont ignorés.
- **Autres comptes Battle.net** (multibox avec un second compte Battle.net) : quand un
  personnage d'un compte inconnu s'annonce sur le **canal dédié**, une fenêtre demande
  l'autorisation en affichant le canal (nom et numéro), le personnage, sa classe et son niveau.
  **Autoriser** ajoute ce compte à vos comptes autorisés : il échange alors avec vous comme vos
  propres comptes (roster, équipes, groupage, actions du leader) ; l'autre compte reçoit la
  même demande pour vous. **Refuser** (ou Échap) : plus de demande pour ce compte jusqu'au
  prochain rechargement. Hors canal dédié (guilde, groupe), les comptes inconnus restent ignorés
  sans demande. La liste est partagée entre vos propres clients (pas avec les comptes
  autorisés : pas d'autorisation en cascade) ; `/poly comptes` la montre et
  `/poly retirer-compte <n°>` retire une autorisation. Le bouton **Gestion liste token** (panneau
  d'options, à droite du canal dédié) ouvre une fenêtre avec la liste des comptes autorisés : au
  survol, une infobulle liste les personnages connus de chaque compte ; le bouton **Révoquer** à
  droite retire l'autorisation (synchronisé avec vos autres Polypode). La fenêtre se ferme avec Échap.
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
- **Quêtes et dialogues** : quand le leader de l'équipe choisit une quête ou une option dans le
  dialogue d'un PNJ, accepte ou rend une quête, ou ferme DialogueUI, les autres personnages du
  groupe font de même dès que le PNJ leur propose la même chose (options « Suivre les dialogues
  de PNJ du leader », « Accepter automatiquement les quêtes » et « Valider automatiquement les
  quêtes », voir Options). Seules les actions du **leader de l'équipe sélectionnée** sont suivies.
- **Partage automatique des quêtes** : quand le leader accepte une quête que des membres groupés
  de l'équipe n'ont pas prise (PNJ non ouvert chez eux, quête déclenchée par un objet...), il la
  **partage** automatiquement quelques secondes après, et les membres l'acceptent. Un message
  s'affiche à l'écran du leader si la quête n'est pas partageable (à prendre au PNJ), ou si des
  membres ne l'ont toujours pas 15 secondes après (hors de portée, journal plein, prérequis,
  option décochée ou personnage sans Polypode). Les expéditions et objectifs bonus, acceptés
  en entrant dans leur zone, ne sont pas concernés.
- **Cinématiques** : quand le leader passe une cinématique ou une vidéo, les autres personnages
  du groupe la passent aussi (option « Passer automatiquement les cinématiques »).
- **Vols** : quand le leader prend un vol chez un maître de vol, les autres personnages du groupe
  qui ont la carte de vol ouverte prennent le même (option « Prendre automatiquement le vol du leader »).
- **Gouffres et portails** : quand le leader entre dans un gouffre (choix du palier), vote pour en
  sortir ou confirme l'entrée par un portail d'instance, les autres personnages du groupe font de
  même (option « Entrer automatiquement en instance (gouffre, portail) »).
- **Son de l'équipe** : le leader règle le volume principal des autres fenêtres ou coupe / rétablit
  leur son par raccourci clavier (options « Volume envoyé » et « Suivre le son du leader »). Son
  propre son ne change pas.
- **Groupage automatique** : à la connexion d'un personnage membre d'une équipe, si le leader de
  l'équipe est déjà connecté, il l'invite automatiquement et le personnage accepte (option
  « Groupage automatique de l'équipe »). Même chose quand le leader se connecte après ses membres.
  Il faut que les deux se voient (canal dédié, guilde commune ou groupe) et que le leader puisse inviter (seul
  ou chef du groupe, 5 au plus hors raid).
- Les **ajouts et retraits manuels de personnages** (bouton « Ajouter la cible »,
  `/poly remove`) sont synchronisés de la même façon, avec la même règle de version : un
  personnage retiré ne réapparaît pas via un client qui l'avait encore (il réapparaît
  seulement s'il se reconnecte lui-même avec Polypode).

---

## Fenêtre principale

Ouverte par `/poly ui`, le raccourci clavier ou le bouton de minimap. Le bouton **Options** (en haut
à gauche de la barre de titre) ouvre directement le panneau d'options de Polypode. Trois cadres
côte à côte :

- **Personnages disponibles** : tous les personnages de votre équipe détectés via les canaux
  (groupe, raid, guilde), triés par ordre alphabétique (sans tenir compte des accents ni des
  majuscules). Nom en couleur de classe, puis classe et niveau ;
  `(vous)` marque le personnage courant.
  Bouton **Ajouter la cible** (en haut du cadre) : ajoute le joueur ciblé à la liste, même
  s'il n'a pas Polypode (ex. un ami) ; il peut alors rejoindre une équipe et être invité
  avec elle. L'ajout est partagé avec vos autres Polypode connectés.
  Quand une équipe est sélectionnée : **clic gauche** sur un personnage l'ajoute à l'équipe,
  **clic droit** l'en retire ; les membres de l'équipe sont surlignés en doré. Une infobulle au survol donne le nom du personnage, rappelle ces actions, puis liste les équipes dont il fait déjà partie (l'équipe sélectionnée en vert).
- **Équipes** : saisir un nom dans le champ « Nom de l'équipe » puis valider avec
  **Entrée** ou le bouton **Créer** : l'équipe est créée et ajoutée à la liste (triée par
  nom, mémorisée pour le compte). Un nom vide ou déjà utilisé est refusé avec un message
  en rouge à l'écran. **Échap** quitte le champ. **Clic gauche** sur une équipe la sélectionne, **clic droit** la désélectionne (plus aucune équipe sélectionnée, rappelé par une infobulle au survol)
  (surbrillance dorée). La sélection est **mémorisée pour chaque personnage** : après une
  déconnexion, une reconnexion ou un reload, la même équipe est sélectionnée, que ce
  personnage en soit le leader ou non (une équipe reçue via « Inviter l'équipe » devient
  aussi la sélection mémorisée).
  **Maj + clic gauche** sur une équipe la **supprime** (sans confirmation), aussi sur vos autres
  Polypode connectés ; une suppression l'emporte sur les copies plus anciennes (clients démarrés
  plus tard, fichier de sauvegarde partagé). Une équipe du même nom peut ensuite être recréée.
  **Glisser** une équipe (clic gauche maintenu) hors de la fenêtre la sélectionne et la pose en
  **barre flottante** à l'endroit où vous la lâchez (voir Barre flottante d'équipe).
- **Personnages de l'équipe** : membres de l'équipe sélectionnée, triés par nom, même
  présentation que les personnages disponibles.
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

Les trois listes défilent (molette ou barre de défilement), sans limite de nombre ; la barre
de défilement n'apparaît que si la liste déborde du cadre.

La fenêtre se **redimensionne** par la poignée du coin bas-droit ; les trois cadres se
partagent la largeur à parts égales et la taille est mémorisée pour le compte (720 × 320
par défaut). Si la fenêtre est très réduite, le contenu est simplement tronqué.

---

## Barre flottante d'équipe

Petite barre posée sur l'écran de jeu, sortie de la fenêtre principale en **glissant** une équipe
du cadre « Équipes ». Elle affiche le nom de **l'équipe sélectionnée** et son nombre de
personnages, et suit la sélection (clic sur une autre équipe, synchro) ; « Aucune équipe » si
rien n'est sélectionné.

- **Clic gauche** : invite l'équipe dans votre groupe, exactement comme le bouton **Inviter
  l'équipe** de la fenêtre principale (réservé au leader de l'équipe ; sinon un message rouge
  explique pourquoi, rappelé dans l'infobulle).
- **Détails** (option « Barre d'équipe : niveau, niveau d'objet et progression », cochée par
  défaut) : à gauche de chaque personnage, son **niveau** (doré), le **% d'avancement** dans ce
  niveau (gris, masqué au niveau maximum) et son **niveau d'objet** équipé (bleu), puis son nom
  court. Ces infos viennent du Polypode de chaque personnage (mises à jour en direct : XP,
  équipement, niveau) ; « ? » tant qu'elles ne sont pas reçues. Décochée : présentation de la
  fenêtre principale (nom-royaume, classe, niveau).
- **Clic droit** : déplie / replie la liste des personnages de l'équipe (même présentation que
  dans la fenêtre : le leader est surligné en doré et marqué `[leader]`). Au survol d'un
  personnage **groupé avec vous**, l'infobulle complète de WoW s'affiche (la même qu'au survol
  de son cadre de groupe : niveau, classe, spécialisation, guilde, royaume...). **Hors du groupe**,
  une infobulle façon liste d'amis : niveau, race, classe et spécialisation, guilde, zone, niveau
  d'objet et présence (en ligne, ou hors ligne avec l'ancienneté des infos), puis ses équipes. Ces
  infos sont envoyées par le Polypode du personnage à chaque rencontre et quand elles changent
  (zone, niveau, spécialisation, équipement, guilde) ; sans elles (personnage pas encore vu
  cette session), l'infobulle montre ce que la liste sait (niveau, classe, dernière connexion). Au-delà de 8 personnages, la liste défile. Elle s'ouvre
  sous la barre, ou au-dessus si la barre est trop près du bas de l'écran.
- **Glisser** : déplace la barre.
- **Maj + clic** : envoie la position et la taille de la barre (et son pliage) aux autres
  personnages connectés de l'équipe. Chez ceux dont la barre est **masquée**, elle s'affiche au
  même endroit et à la même taille, proportionnellement à la taille de leur écran (fenêtres de
  tailles différentes) ; une barre déjà affichée garde sa place. L'équipe est aussi sélectionnée
  chez ceux qui n'en avaient pas.
- **Poignée du coin** (en bas à droite de la barre, ou de la liste dépliée) : redimensionne la
  barre en largeur et, liste dépliée, la hauteur de la liste (qui défile au-delà).
- **Alt + clic** : **fige** la barre (position et taille : plus de déplacement, poignée masquée,
  cadenas affiché) ou la libère. L'invitation (clic gauche), le pliage (clic droit) et la croix restent actifs. Une barre
  figée ne bouge pas quand on glisse à nouveau une équipe hors de la fenêtre.
- **Croix** : masque la barre ; glisser à nouveau une équipe hors de la fenêtre pour la réafficher.

Affichage, pliage, position, taille et verrouillage sont mémorisés **pour chaque personnage** (chaque fenêtre de
multibox a sa propre barre) et retrouvés à la connexion.

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
| `/poly comptes` | Lister les autres comptes Battle.net autorisés (numérotés) |
| `/poly retirer-compte <n°>` | Retirer l'autorisation d'un compte (numéro donné par `/poly comptes`) |
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
| Envoyer le volume à l'équipe | Leader : règle le volume principal des autres membres sur l'option « Volume envoyé » |
| Couper/rétablir le son de l'équipe | Leader : coupe tout le son des autres membres, puis le rétablit à l'appui suivant |

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
| Canal dédié | vide | Optionnel : nom du canal de discussion commun à vos comptes, utile sans groupe ni guilde commune (voir Fonctionnement ; l'infobulle du champ le rappelle). Aussi modifiable dans la fenêtre principale. À droite, bouton « Gestion liste token » : liste et révocation des comptes autorisés. Pour tout le compte, synchronisé entre vos clients |
| Afficher l'icône de minimap | Oui | Affiche le bouton Polypode autour de la minimap |
| Mode debug | Non | Affiche dans le chat les messages de diagnostic (synchro, invitations...). Réglage **par personnage** : on peut l'activer sur une seule fenêtre |
| Attaquer après l'assistance | Oui | Le raccourci « Assister le leader » lance aussi l'attaque automatique (`/startattack`) sur la cible prise si elle est hostile ; décoché, il prend seulement la cible. Réglage **par personnage** (ex. décoché sur un soigneur) |
| Accepter automatiquement les quêtes | Oui | Quand le leader de l'équipe accepte une quête, ce personnage l'accepte aussi dès qu'elle lui est proposée (PNJ ouvert ou quête partagée, jusqu'à 30 s après). Sur le leader, active aussi le partage automatique aux membres qui n'ont pas la quête, avec un message à l'écran en cas d'échec. Réglage **par personnage** ; doit être coché sur le leader (qui annonce et partage ses quêtes) et sur les membres |
| Valider automatiquement les quêtes | Oui | Quand le leader rend une quête (« Continuer » puis « Terminer la quête »), ce personnage la rend aussi avec le **même index de récompense**, dès que le PNJ est ouvert (jusqu'à 60 s après). Une récompense au choix qui ne convient pas reste à choisir à la main. Réglage **par personnage**, à cocher sur le leader et les membres |
| Suivre les dialogues de PNJ du leader | Oui | Quand le leader choisit dans le dialogue d'un PNJ une quête (disponible ou à rendre) ou une option de dialogue, ce personnage fait le même choix si son dialogue avec le PNJ est ouvert ; quand le leader ferme DialogueUI, il le ferme aussi. L'acceptation ou la validation automatique enchaîne. Réglage **par personnage**, à cocher sur le leader et les membres |
| Passer automatiquement les cinématiques | Oui | Quand le leader passe une cinématique (moteur, scène) ou une vidéo, ce personnage la passe aussi, dès qu'elle s'affiche (jusqu'à 15 s après). Réglage **par personnage**, à cocher sur le leader et les membres |
| Prendre automatiquement le vol du leader | Oui | Quand le leader prend un vol chez un maître de vol, ce personnage prend le même vol si sa carte de vol est ouverte et qu'il connaît la destination (retrouvée par son nom). Réglage **par personnage**, à cocher sur le leader et les membres |
| Entrer automatiquement en instance (gouffre, portail) | Oui | Quand le leader choisit le palier d'un gouffre, ce personnage choisit le même si sa fenêtre de palier est ouverte ; quand le leader vote la sortie du gouffre, il vote « Oui » aussi (jusqu'à 30 s après) ; quand le leader confirme l'entrée par un portail d'instance, il confirme aussi. Réglage **par personnage**, à cocher sur le leader et les membres |
| Volume envoyé | 50 % | Curseur de 0 à 100 % par pas de 5 %. Sur le leader : volume principal appliqué aux autres membres par le raccourci « Envoyer le volume à l'équipe ». Réglage **par personnage** |
| Suivre le son du leader | Oui | Applique à ce personnage le volume envoyé par le leader et la coupure / le rétablissement du son. Décoché : ce client garde son propre son. Réglage **par personnage** |
| Barre d'équipe : niveau, niveau d'objet et progression | Oui | Dans la liste de la barre flottante d'équipe, affiche à gauche de chaque personnage son niveau, son % d'avancement dans ce niveau (sauf au niveau maximum) et son niveau d'objet équipé. Réglage **par personnage** |
| Groupage automatique de l'équipe | Oui | Leader : invite automatiquement dans son groupe les membres de son équipe sélectionnée qui se connectent, ou déjà connectés quand il se connecte lui-même. Membre : accepte automatiquement l'invitation de groupe du leader d'une de ses équipes. Réglage **par personnage** |

---

## Apparence

La fenêtre s'adapte automatiquement à votre interface, sans configuration :

| Interface détectée | Rendu |
|---|---|
| **EllesmereUI** | Style EllesmereUI (fond, bordure, barre de titre avec titre centré, cadres intérieurs, boutons de fermeture — y compris la croix de la barre flottante d'équipe) selon votre thème. Désactivable dans EllesmereUI → Blizz UI Enhanced → Blizzard Window Skins → Third-Party Addons (nécessite le module EllesmereUI Blizzard Skin). |
| **ElvUI** | Style ElvUI (fond, cadres intérieurs et boutons de fermeture). |
| Aucune | Fond sombre générique. |

Si EllesmereUI et ElvUI sont tous deux chargés, EllesmereUI est prioritaire (sauf si
vous avez désactivé le skin de Polypode dans ses options).

---

## État du projet

Version `0.36.0` : roster, sync filtrée par token d'équipe (BattleTag) avec réponse
automatique aux annonces, fenêtre redimensionnable à trois listes défilantes (personnages
disponibles / équipes avec création par saisie, sélection et suppression / personnages de l'équipe, ajout
et retrait de membres au clic, leader par équipe, invitation de toute l'équipe, synchronisation automatique et versionnée des équipes, ajout du joueur ciblé, barre flottante de l'équipe sélectionnée)
skinnée (EllesmereUI/ElvUI), bouton de minimap (masquable), panneau d'options (accessible par un bouton de la fenêtre),
commandes, raccourcis clavier (interface, se nommer leader, suivre, assister, inviter), suivi des dialogues de PNJ (quêtes, options, fermeture de DialogueUI), acceptation, partage et validation automatiques des quêtes du leader, passage automatique des cinématiques, vol automatique chez le maître de vol, entrée et sortie de gouffre et entrée par portail automatiques, volume et coupure du son de l'équipe par le leader, groupage automatique de l'équipe à la connexion, canal dédié commun aux comptes, autorisation d'autres comptes Battle.net. Pistes envisagées pour la suite,
à activer seulement si le besoin se confirme (voir la règle de simplicité dans
`CLAUDE.md`) :

- Réannonce à l'entrée en groupe (`GROUP_ROSTER_UPDATE`) pour les personnages sans
  guilde commune connectés avant d'être groupés.
- **Équipes** : renommer une équipe ; usage des équipes (conversion en raid automatique, leader).
- **Entrée en donjon par le Chercheur de groupe** (accepter la proposition « Entrer », confirmer le
  rôle) quand le leader le fait, comme l'option « Entrée en donjon » de Team Manager : non reprise,
  car elle repose sur des fonctions protégées par WoW (`AcceptProposal`, `LFGTeleport`,
  `AcceptRoleCheck`) dont le fonctionnement n'a pas été constaté en jeu.
- Invitation automatique du groupe depuis le roster.
- Skin des textes de la fenêtre (police EllesmereUI via `S.Font`).

---

## Remerciements

Inspiré des addons multibox TeamManager, M.A.M.A. et DynamicBoxer (MooreaTV) et EMA
(Ebony/Blossom).
