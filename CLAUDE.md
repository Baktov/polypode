# CLAUDE.md — Polypode (Addon WoW)

## Contexte du projet

Addon World of Warcraft Retail (Interface 120000) et **WoW Forever** (Interface 16001, type de jeu
« camelot », dossier `_classic_beta_` : moteur 12.1 de Retail avec le contenu Vanilla, même API)
dédié au **multiboxing**. Toute API liée à du contenu récent (gouffres, expéditions, spécialisations...)
reste testée avant usage (`if C_X and C_X.Fn then`) pour se désactiver sur Forever ; ne pas se fier à
`WOW_PROJECT_ID` (Forever est classé mainline). Pas de `ReloadUI()` depuis l'addon (bloqué sur Forever).
Sur Forever, `UnitName(unit)` renvoie **prénom, nom de famille** (Retail : nom, royaume) : ne jamais lire
son second résultat directement, passer par `P.UnitNameParts(unit)` (prénom, royaume, nom de famille).
La clé de roster reste « Prénom-Royaume », le nom de famille est dans `entry.surname` (reçu en fin de
HELLO/HI) ; tout affichage d'un personnage passe par `P.GetDisplayName(key [, withRealm])` (« Prénom Nom »
si connu). `P.HasSurnames()` = `RegionalUniqueNamesEnabled()`.
Objectif : gérer *simplement* plusieurs personnages joués simultanément dans plusieurs
fenêtres/clients WoW sur la même machine (roster des personnages, équipes avec un
leader par équipe — pas de leader global —, synchronisation d'infos de base entre clients). Même famille d'outils que
TeamManager, MAMA, EMA et DynamicBoxer, mais volontairement plus minimaliste : on
n'ajoute une fonctionnalité que si elle sert directement cet objectif.

- **Langue du code** : commentaires en français, code (variables/fonctions) en anglais.
- **Style** : minimaliste, lisible, pas de dépendance externe obligatoire.
- **Dépendances optionnelles** : EllesmereUI et ElvUI (skinning via `UI_Skin.lua`), jamais requises pour charger.
- **Addons compagnons** (dossiers voisins, dépôts séparés, `## Dependencies: Polypode`) : **Polypode Photo**
  (`../Polypode_Photo`, https://github.com/Baktov/Polypode-Photo : mode photo) et **Polypode Suivi** (`../Polypode_Suivi`,
  https://github.com/Baktov/polypode-suivi : suivi de l'équipe, campagnes, et panneau « Quêtes » de l'équipe — l'échange `QLOG`,
  `P.GetCharacterQuests` et Quests.lua restent dans Polypode, qui prévient par `P.RegisterQuestLogCallback(fn)` (Sync.lua, 0.58.0) à
  chaque journal reçu ou modifié —, message `SUIVI` à lui) et **Polypode Data**
  (`../Polypode_Data`, https://github.com/Baktov/polypode-data : données durables des personnages façon
  DataStore, messages `DATA` / `DATAV` / `DATAREQ` à lui) et **Polypode Profil** (`../Polypode_Profil`,
  https://github.com/Baktov/polypode-profil : chaînes d'export du mode Édition, des talents, de la transmogrification, des titres, des ensembles d'équipement, des options de WoW, des raccourcis, des fenêtres de discussion, de la liste des addons et des addons,
  messages `PROF` / `PROFV` / `PROFREQ` à lui). Polypode n'en sait
  rien : chacun ajoute son bouton de barre de titre par `P.AddTitleButton` (UI_Main.lua, empilés de droite à
  gauche depuis la croix) et sa commande par `P.RegisterSlashCommand` ; un compagnon échange ses propres
  messages par `P.RegisterMessageHandler(type, fn(reste, expéditeur))` (appelé par `P.OnSyncMessage` après
  la vérification du token), `P.RegisterPeerCallback(fn(expéditeur))` (appelé à chaque HELLO/HI reçu) et
  `P.WhisperOnline(message, cible)` (à cible, sinon aux clients connectés), et déclare les données qu'il garde d'un personnage par `P.RegisterCharacterData({ name, describe(clé) → texte|nil, remove(clé, fromSync) })` (Core.lua, 0.53.0 : appelé par `P.RemoveCharacter` — Maj + clic dans « Personnages disponibles », confirmation `POLYPODE_REMOVE_CHARACTER` listant `P.DescribeCharacterData(clé)` — et par `P.ApplyCharacterSync` à la réception d'une suppression, `fromSync` vrai), avec `P.IsSender` et
  `P.MAX_MESSAGE_LENGTH` (Sync.lua). API publique qu'ils utilisent (voir leur CLAUDE.md) : `P.AddTitleButton`,
  `P.RegisterSlashCommand`, `P.optionsCategory`, `P.CreatePanel`, `P.CreateScrollList` (`opts.rowHeight`, signalé par `P.LIST_ROW_HEIGHT` : 0.56.0, grille d'icônes de Data), `P.SetListData`,
  `P.SkinFrame`, `P.SkinPanel`, `P.SkinButton`, `P.SkinDropdown`, `P.SkinCheckBox`, `P.ToggleOptionsPopup` (0.57.0 : petite fenêtre d'options au clic droit), `P.UnitNameParts`, `P.JoinSurname`, `P.GetCharacterStatus`,
  `P.GetCharacterQuests`, `P.RegisterQuestLogCallback` (0.58.0), `P.GetSelectedTeam`, `P.GetTeamLeader`, `P.GetTeamMembers`, `P.GetCharKey`,
  `P.GetDisplayName`, `P.db.roster`, `P.SortedKeyItems`, `P.FormatCharacter`, `P.CharacterTooltip`,
  `P.IsCharacterConnected` (règle « connecté » de « Personnages disponibles », 0.51.2), `P.GetTeamToken`, `P.RefreshUI`, `P.IsSoloMode` (0.54.0 : Suivi impose « Tous les personnages » ; champ `hideInSolo` d'une spec de `P.AddTitleButton`), et les points
  d'extension de synchro ci-dessus : ne pas les renommer ni changer leur comportement sans adapter les
  compagnons.

---

## Architecture

| Fichier | Rôle |
|---|---|
| `Core.lua` | Table globale `Polypode` (alias local `P`), SavedVariables, comptes autorisés (`P.IsTokenTrusted`, `P.GetTrustedTokens`, `P.TrustToken`, `P.UntrustToken`, `P.ApplyTrustSync`), canal dédié (`P.GetSyncChannelName`, `P.CheckSyncChannelName`, `P.SetSyncChannel`, `P.ApplyChannelSettingSync`, `P.NextVersion`), roster versionné à pierres tombales, compte de chaque perso dans `entry.token` (`P.GetTokenCharacters`), comptes WoW nommés à la main (`P.db.accountLabels[clé] = { label, updated }`, versionné : `P.GetCharacterAccount`, `P.GetAccountLabels`, `P.SetCharacterAccount`, `P.ApplyAccountLabelSync` — WoW ne donne pas le nom du compte WoW aux addons), (`P.GetRoster`, `P.GetCharacter`, `P.AddCharacter`, `P.AddTargetCharacter`, `P.RemoveCharacter`, `P.ApplyCharacterSync`), équipes (`P.CreateTeam`, `P.CreateTeamWithLeader(key)` (équipe au nom du personnage, suffixe `_1`, `_2`... si pris, lui pour leader), `P.DeleteTeam` (pierre tombale `removed`, `P.IsTeamRemoved`), `P.RenameTeam` (nouvelle équipe + pierre tombale `renamedTo`, suivie par `P.GetSelectedTeam` ; noms sans « : »), `P.GetTeams` (équipes actives), `P.GetTeamMembers`, `P.AddTeamMember`, `P.RemoveTeamMember`, `P.GetCharacterTeams(key)`, `P.GetTeamLeader`, `P.IsTeamLeader` (équipe sélectionnée), `P.SetTeamLeader` (leader = membre, effacé à son retrait), `P.GetTargetName(entry)`, `P.GetTeamInvitees`, `P.InviteTeam`, `P.ApplyTeamSync`, `P.GetTeamUpdated` — toute modification passe par la locale `TeamChanged` (horodatage `updated` + synchro) — (invitation via `C_PartyInfo.InviteUnit`, nom court de royaume, limite de 5 hors raid) ; `P.db.teams[nom] = { name, members = { [nom-royaume] = true }, leader, created }` (`created` = heure serveur de création, conservée au renommage et aux nouvelles versions ; `P.GetTeamCreated`, `P.ApplyTeamCreated` — la plus ancienne l'emporte), `members` créé à la volée pour les anciennes équipes ; `P.RemoveCharacter` retire aussi le perso des équipes) |
| `Sync.lua` | Broadcast/réception de messages addon (`C_ChatInfo`), canal dédié (`P.ApplySyncChannel`, `P.JoinSyncChannelLater`, type `"CHANNEL"`, prioritaire pour HELLO/HI, réglage synchronisé `CHANSET`), token d'équipe (`P.GetTeamToken`, hash du BattleTag), annonce `HELLO` / réponse `HI`, actions du leader rejouées par les membres (`P.BroadcastLeaderAction`, filtre `LEADER_ONLY`), synchro d'équipe `TEAM` (`P.SyncTeam`, `P.SyncAllTeams`, roster manuel `CHAR` (`P.SyncCharacter`, `P.SyncAllCharacters`), comptes WoW nommés `ACCT` (`P.SyncAccountLabel`, `P.SyncAllAccountLabels`), journaux de quêtes `QLOG` (`P.SendQuestLog`, `P.ScheduleQuestLog`, `P.GetCharacterQuests`, en mémoire), état des personnages `STATUS` (`P.SendStatus`, `P.ScheduleStatus`, `P.GetCharacterStatus`, `P.IsCharacterOnline`, en mémoire), chuchotement, file d'envoi, filtre d'erreur hors ligne) |
| `Quests.lua` | Quêtes et dialogues de PNJ du leader rejoués par les membres (repris de TeamManager ; détail du flux en tête de fichier). Acceptation : le leader annonce `QACCEPT` au groupe (`QUEST_ACCEPTED` + hooks `AcceptQuest` / `QuestFrameAcceptButton`), les membres acceptent via `RequestLoadQuestByID` → `QUEST_DATA_LOAD_RESULT` → `AcceptQuest()` (attente 30 s si la quête n'est pas encore proposée). Partage : les membres répondent `QSTATE` (HAVE / NEED / OK) au leader, qui partage (`QuestLogPushQuest`) 4 s après si un membre groupé de l'équipe n'a pas la quête, et affiche un message si elle n'est pas partageable ou manque encore 15 s après (`P.OnQuestStateMessage` ; expéditions et objectifs bonus exclus). `P.OnQuestAcceptMessage`, `P.OnQuestEvent`, option `P.charDb.autoAcceptQuest`. Validation en deux étapes `QVALIDATE` (« Continuer » → `CompleteQuest()`) puis `QREWARD` (« Terminer » → `GetQuestReward(choix)`), fenêtre de 10 s pour les addons de dialogue, attente 60 s, option `P.charDb.autoValidateQuest`. Dialogues de PNJ (option `P.charDb.autoSelectGossip`) : quêtes `GQAVAIL` / `GQACTIVE`, options `GOSSIP` (orderIndex résolu en gossipOptionID), fermeture de DialogueUI `CLOSEUI` (cadre retrouvé par signature), rejoués si dialogue ouvert ou vu il y a < 10 s. Toutes les annonces passent par la locale `Announce` (dédoublonnage 5 s par type + quête) |
| `Cinematics.lua` | Cinématiques passées par le leader, passées aussi par les membres (repris de TeamManager ; détail en tête de fichier) : `CINESKIP` (hooks `StopCinematic`, `CinematicFrame_CancelCinematic` pour les scènes, `MovieFrame:FinishMovie`) ; membre : `StopCinematic()` / `CancelScene()` / `MovieFrame:FinishMovie()`, attente 15 s rejouée à `CINEMATIC_START` / `PLAY_MOVIE`. Option `P.charDb.autoSkipCinematic` |
| `Taxi.lua` | Vol pris par le leader chez un maître de vol, pris aussi par les membres (repris de TeamManager) : `TAXI` avec le **nom** de la destination (hook `TakeTaxiNode`) ; membre : si sa carte de vol est ouverte, retrouve l'index local par `TaxiNodeName` puis `TakeTaxiNode`. Option `P.charDb.autoTaxi` |
| `Instances.lua` | Gouffres et portails suivis du leader (repris de TeamManager, parties vérifiées en jeu ; détail en tête de fichier) : `DELVEENTER` (palier, hook `C_DelvesUI.SelectDelveEntranceTier`), `DELVEEXIT` (vote de sortie, hook `C_PartyInfo.SetInstanceAbandonVoteResponse`, membre : vote « Oui » immédiat ou attendu 30 s), `INSTENTER:portal` (hooks `ConfirmEnterInstance` et `StaticPopup_OnClick` hors instance). Option `P.charDb.autoEnterInstance`. **Entrée LFG et confirmation de rôle non reprises** (fonctions protégées non vérifiées) |
| `Sound.lua` | Son des membres piloté par le leader : `P.SendTeamVolume` (`VOLUME`, valeur `P.charDb.sentVolume`) et `P.ToggleTeamSound` (`SOUND`, alterne coupé / rétabli), appelés par les raccourcis ; membres (`P.charDb.followLeaderSound`) : `SetCVar("Sound_MasterVolume", %/100)` et `SetCVar("Sound_EnableAllSound", 0|1)`. Le son du leader n'est pas modifié |
| `AutoGroup.lua` | Groupage automatique à la connexion : leader → `P.OnTeamCharacterOnline(key)` (appelé par Sync.lua à chaque HELLO/HI) invite le membre de son équipe sélectionnée (délai 1 s, dédoublonné 10 s, mêmes règles que `P.InviteTeam`) ; membre → `PARTY_INVITE_REQUEST` du leader d'une de ses équipes : `AcceptGroup()`, fenêtre fermée au `GROUP_ROSTER_UPDATE`. Option `P.charDb.autoGroup` |
| `Follow.lua` | Qui suit qui dans le groupe (session) : `followState[suiveur] = suivi` (clés normalisées sans espaces ni tirets dans le royaume), son propre suivi annoncé au groupe/raid (`FOLLOWING`) à `AUTOFOLLOW_BEGIN` (nom résolu par prénom parmi les unités du groupe) et à `AUTOFOLLOW_END` non repris 0,5 s après, réannoncé quand le groupe s'agrandit (`P.OnFollowRosterUpdate`, sur `GROUP_ROSTER_UPDATE`) ; `P.OnFollowingMessage(suiveur, suivi)` ; choix de l'unité à suivre des raccourcis `P.GetBarbareFollowUnit` (autre joueur connecté au hasard, autre que celui suivi s'il y a le choix) et `P.GetTrainFollowUnit` (joueur que personne d'autre ne suit et dont la file ne mène pas à soi ; de préférence la queue de la file du leader de l'équipe sélectionnée), qui renvoient unité, ou nil et message ; noms secrets ignorés. Alerte « ne suit plus » : membre → `P.OnFollowEvent` (`AUTOFOLLOW_BEGIN` mémorise le nom suivi, `AUTOFOLLOW_END` envoie `FOLLOWEND` en WHISPER au leader de l'équipe sélectionnée s'il le suivait et que le suivi n'a pas repris 0,5 s après — relancer `/follow` pendant un suivi produit END puis BEGIN) ; leader → `P.OnFollowEndMessage(key)` : « X ne vous suit plus. » (`UIErrorsFrame`) + `SOUNDKIT.RAID_WARNING`, dédoublonné 3 s par membre. Option `P.charDb.followAlert` |
| `UI_Skin.lua` | Skinning conditionnel : EllesmereUI (`EllesmereUI.RegisterSkin`, prioritaire) puis ElvUI. `P.SkinFrame` (fenêtre top-level ; skin ou non, locale `KeepOnTop` : `SetToplevel(true)` + `Raise()` à chaque `OnShow`, sinon deux fenêtres de la même strate — `DIALOG` des compagnons — entrelacent leurs niveaux et le contenu de celle du dessous se dessine sur le fond de celle du dessus), `P.SkinPanel` (cadre intérieur), `P.SkinDropdown` (liste déroulante `WowStyle1DropdownTemplate` : `S.Dropdown` d'EllesmereUI, `S:HandleDropDownBox` d'ElvUI), `P.SkinCheckBox` (case à cocher : `S.Checkbox` d'EllesmereUI, `S:HandleCheckBox` d'ElvUI), `P.SkinScrollBar` (barre de défilement), `P.SkinEditBox` (champ de saisie), `P.SkinButton` (bouton texte), `P.SkinCloseButton` (croix hors fenêtre top-level) |
| `UI_Main.lua` | Fenêtre principale redimensionnable (strate `HIGH` + `SetToplevel` : devant les barres d'action, derrière les fenêtres des compagnons en `DIALOG` ; `P.ui.resizeGrip`, taille dans `P.db.mainFrame`), bouton `P.ui.optionsButton` (barre de titre, → `P.OpenOptions`), case `P.ui.soloCheck` « Solo » (rouge, à droite de `P.ui.channelInput`) → `P.SetSoloMode` : **mode solo** (`P.charDb.soloMode`, `P.IsSoloMode` dans Core.lua) — `ApplySoloLayout` masque `teamPanel` / `memberPanel` et `addTargetButton` (la liste remonte : `charPanel.SetListTop`), `LayoutPanels` donne toute la largeur à `charPanel`, largeur de fenêtre gardée par mode (`WidthKey` : `P.db.mainFrame.width` / `soloWidth`), clics d'équipe ignorés, glisser la ligne du personnage joué → `P.StartTeamBarDrag` —, point d'extension `P.AddTitleButton(spec)` (boutons des addons compagnons à gauche de la croix : `{ text, width, onClick, rightClick, tooltip, onCreate, hideInSolo }`, créés avec la fenêtre, placés sans trou par `LayoutTitleButtons` ; `P.IsTitleButtonShown(spec)` faux pour `hideInSolo` en mode solo), `P.GetTitleButtonSpecs()` (leurs specs, reprises par la colonne de la barre flottante ; un ajout après la construction de la barre la rafraîchit) : `BuildUI`, `RefreshUI`, `ToggleUI`. Trois cadres à liste défilante (`panel.scrollBox`, `panel.scrollBar`, `panel.emptyText`), un tiers de largeur chacun (`LayoutPanels` sur `OnSizeChanged`) : `P.ui.charPanel` (personnages disponibles = roster trié, connectés en tête — locale `IsConnected` : soi, `P.IsCharacterOnline`, membre connecté du groupe ; `SortedKeyItems(set, isFirst)` — et déconnectés estompés via `opts.decorate`, rafraîchi aussi sur `GROUP_ROSTER_UPDATE` fenêtre ouverte et à l'erreur « non connecté », regroupement optionnel par compte (`P.charDb.groupByAccount` : en-têtes `{ header, groupKey, label, items, online, collapsed }` repliables au clic, état dans `P.charDb.collapsedAccounts`, bouton `ui.collapseAccountsButton` « Tout replier / Tout déplier » à droite du titre, affiché seulement regroupé par compte — `accountGroupKeys` du dernier `RefreshUI`, `AllAccountsCollapsed` — ; locales `AccountGroup` — compte WoW nommé, sinon « Compte non renseigné » — et `GroupRank`), Alt + clic = menu `MenuUtil.CreateContextMenu` de rangement dans un compte nommé (locale `ShowAccountMenu`, StaticPopup `POLYPODE_NEW_ACCOUNT`), bouton `P.ui.addTargetButton` « Ajouter la cible » ; avec une équipe sélectionnée, clic droit = ajout, clic gauche = retrait, membres surlignés ; sans équipe, clic droit = `P.CreateTeamWithLeader` puis sélection), `P.ui.teamPanel` (équipes : `P.ui.teamInput` + `P.ui.teamCreateButton` → `P.CreateTeam`, liste triée, clic gauche = sélection, clic droit = désélection, Maj + clic gauche = suppression (`P.DeleteTeam`), double-clic gauche = renommage (`opts.onDoubleClick`, StaticPopup `POLYPODE_RENAME_TEAM` → `P.RenameTeam`), mémorisées par personnage dans `P.charDb.selectedTeam` (via la locale `ChooseTeam` ou `P.SelectTeam`), la locale `selectedTeam` en est recalculée par `RefreshUI` (nil si l'équipe manque encore, sans effacer le choix)), `P.ui.memberPanel` (« Personnages de l'équipe » : membres de l'équipe sélectionnée, leader en tête (comme dans la barre flottante), bouton `P.ui.inviteButton` « Inviter l'équipe » → `P.InviteTeam` + `P.SyncTeam`, actif seulement si le personnage courant est leader de l'équipe (locale `InviteBlockedReason`, aussi affichée dans l'infobulle), clic gauche = leader de l'équipe (surligné), clic droit = retrait) |
| `UI_TeamBar.lua` | Barre flottante de l'équipe sélectionnée (`P.ui.teamBar`, liste `P.ui.teamBarList`, croix `P.ui.teamBarClose`, icône `P.ui.teamBarIcon` = `P.ICON` de UI_Minimap.lua → `P.ToggleUI`, clic droit → `P.ToggleOptionsPopup(icône, P.optionsPopup)` (repli `P.OpenOptions`) ; clic droit sur un bouton de module = ses options, géré par le module dans `spec.onClick` avec `rightClick`) : sortie en glissant une ligne du cadre « Équipes » (`opts.onDragStart` → `P.StartTeamBarDrag`, relâchement guetté par `OnUpdate` + `IsMouseButtonDown`), `P.RefreshTeamBar` (appelé par `P.RefreshUI` et à `PLAYER_LOGIN`) ; clic gauche = inviter l'équipe (`P.InviteSelectedTeam`), Maj + clic = partager la disposition (`P.SyncTeamBarLayout` → `BARPOS` → `P.ApplyTeamBarLayout`, appliquée seulement si la barre est masquée) ; clic droit = déplier/replier les membres (état par ligne via `opts.decorate` : libellé hors groupe / hors ligne / déconnecté / mort / loin et barre de vie `StatusBar` (option `P.charDb.teamBar.healthBar`) — valeurs secrètes de WoW 12 jamais calculées, seulement passées à `SetValue` —, rafraîchi toutes les 0,3 s par l'`OnUpdate` de la liste ; leader surligné, infobulle WoW `SetUnit` si le personnage est groupé, sinon état façon liste d'amis (`P.GetCharacterStatus`, `P.IsCharacterOnline`) + `P.CharacterTooltip` ; `P.FormatCharacter`, `P.SortedKeyItems` (tri alphabétique sans accents ni casse) de UI_Main.lua), glisser = déplacer (infobulles de la barre et de son icône masquées pendant le déplacement, `bar.dragging`), poignée `P.ui.teamBarGrip` = redimensionner (suivi du curseur par `OnUpdate`, largeur + hauteur de la liste dépliée), Alt + clic = figer/libérer (cadenas `P.ui.teamBarLock`) ; mode solo : la barre montre le personnage joué (pas d'invitation, de partage ni de [leader]), affichage mémorisé dans `soloShown` (`ShownKey`), colonne des modules sans les specs `hideInSolo` ; état par personnage dans `P.charDb.teamBar` (`shown`, `soloShown`, `expanded`, `locked`, `details` — option « niveau, niveau d'objet et progression » à gauche des membres —, `healthBar` — option barre de vie —, `durabilityAlert` / `durabilityThreshold` — clignotement si durabilité < seuil, curseur 5-95 par 5 —, `moduleButtons` / `moduleSide` — colonne des boutons des addons compagnons (`LayoutModuleButtons`, `CreateModuleButton` : `P.GetTitleButtonSpecs`, `ShortLabel` = 3 premiers caractères UTF-8, `GameFontNormalSmall`, `spec.onClick(bouton de la colonne, mouseButton)`, infobulle `spec.tooltip`, `spec.onCreate` non rappelé ; `P.ui.teamBarModules`, zone gardée à l'écran étendue par `SetClampRectInsets`) à gauche (défaut) ou à droite —, `point`, `relativePoint`, `x`, `y`, `width`, `listHeight`) |
| `UI_Minimap.lua` | Bouton de minimap sans librairie (`P.BuildMinimapButton`, appelé à `PLAYER_LOGIN`), `P.SetMinimapButtonShown`, icône partagée `P.ICON`, état dans `P.db.minimap` (`angle`, `hide`) |
| `UI_Options.lua` | Panneau Options → AddOns via l'API `Settings` (`P.BuildOptions` à `PLAYER_LOGIN`, `P.OpenOptions`) : en tête « Mode solo » en rouge (`P.charDb.soloMode`, → `P.SetSoloMode`), puis cases « Afficher l'icône de minimap » (`P.db.minimap.hide`), « Mode debug » (`P.charDb.debug`) et « Attaquer après l'assistance » (`P.charDb.assistStartAttack`, relance `P.UpdateLeaderMacros`) et « Accepter automatiquement les quêtes » (`P.charDb.autoAcceptQuest`), « Valider automatiquement les quêtes » (`P.charDb.autoValidateQuest`), « Suivre les dialogues de PNJ du leader » (`P.charDb.autoSelectGossip`), « Passer automatiquement les cinématiques » (`P.charDb.autoSkipCinematic`), « Prendre automatiquement le vol du leader » (`P.charDb.autoTaxi`), « Entrer automatiquement en instance (gouffre, portail) » (`P.charDb.autoEnterInstance`), curseur « Volume envoyé » (`P.charDb.sentVolume`, `Settings.CreateSlider` 0-100 pas 5) , « Suivre le son du leader » (`P.charDb.followLeaderSound`), « Groupage automatique de l'équipe » (`P.charDb.autoGroup`), « Personnages disponibles : regrouper par compte » (`P.charDb.groupByAccount`), « Alerte quand un membre ne suit plus » (`P.charDb.followAlert`) « Barre d'équipe : niveau, niveau d'objet et progression » (`P.charDb.teamBar.details`) « Barre d'équipe : barre de vie des membres » (`P.charDb.teamBar.healthBar`), « Barre d'équipe : clignoter si la durabilité est faible » (`P.charDb.teamBar.durabilityAlert`) et le curseur « Barre d'équipe : seuil de durabilité » (`P.charDb.teamBar.durabilityThreshold`), « Barre d'équipe : boutons des modules » (`P.charDb.teamBar.moduleButtons`) et la liste « Barre d'équipe : côté des boutons des modules » (`P.charDb.teamBar.moduleSide`, `Settings.CreateDropdown` left / right), ces seize dernières par personnage |
| `UI_OptionsPopup.lua` | Petite fenêtre d'options (clic droit sur l'icône de la barre flottante et sur les boutons des modules), comme celle de Polypode Photo : `P.ToggleOptionsPopup(owner, popup)`, `popup = { key, title, items, category }`, items `{ kind = "check" | "slider" (min, max, step, format) | "dropdown" (values = { { valeur, libellé } }), setting, tooltip }` — `setting` = objet de `Settings.RegisterProxySetting`, lu par `GetValue`, modifié par `SetValue` (mêmes fonctions que le panneau, qui suit). Une fenêtre par `key` (`PolypodeOptionsPopup_<key>`, Échap, déplaçable, `P.SkinFrame`), liste `P.CreateScrollList` (`rowHeight` 28, `FillRow` : case `UICheckButtonTemplate`, curseur `MinimalSliderWithSteppersTemplate` — rappel ignoré pendant le remplissage, `row.filling` —, liste `WowStyle1DropdownTemplate`, créés à la demande sur la ligne recyclée), hauteur ≤ 440, bouton « Toutes les options » → `Settings.OpenToCategory(category)`. Polypode : `P.optionsPopup` rempli par `P.BuildOptions` (locales `AddCheck`, `AddSlider` — pourcentage —, `AddDropdown` : contrôle du panneau + élément de la fenêtre ; les champs de texte restent dans le panneau) |
| `UI_Options.xml` | Modèle `PolypodeAccountSettingTemplate` : champ « Compte WoW de ce personnage » (méthodes `P.AccountSettingMixin`, → `P.SetCharacterAccount(P.GetCharKey(), nom)` à Entrée et à la perte du focus (`OnEditFocusLost`, sinon une saisie non validée est perdue en fermant le panneau), placé après la case « regrouper par compte »). Modèle `PolypodeChannelSettingTemplate` : champ « Canal dédié » du panneau d'options (le panneau Settings n'a pas de champ texte), ajouté par `Settings.CreateElementInitializer` ; méthodes `P.ChannelSettingMixin` (UI_Options.lua), mélangées par `OnLoad` (pas de global) ; bouton `ManageButton` « Gestion liste token » → `P.ShowTokensWindow` |
| `UI_Trust.lua` | Fenêtre `POLYPODE_TRUST_ACCOUNT` (StaticPopup) : `P.PromptTrust` pour un HELLO/HI au token inconnu reçu sur le canal dédié (canal, n°, personnage, classe, niveau) ; Autoriser → `P.TrustToken` + traitement de l'annonce ; Refuser → plus de demande cette session ; demandes en file |
| `UI_Tokens.lua` | Fenêtre `PolypodeTokensFrame` « Comptes autorisés » (`P.ShowTokensWindow`, `P.RefreshTokensWindow` appelé par `P.RefreshUI`) : liste défilante des comptes autorisés, infobulle des personnages du compte (`P.GetTokenCharacters`, `entry.token` du roster), bouton « Révoquer » par ligne (`P.UntrustToken`) ; ouverte par le bouton « Gestion liste token » du panneau d'options |
| `UI_Keybinds.lua` | Boutons sécurisés `PolypodeFollowButton` / `PolypodeAssistButton` (macros `/follow`, `/assist` vers le leader de l'équipe sélectionnée), `PolypodeBarbareButton` / `PolypodeTrainButton` (`/follow unité`, unité choisie par le `pick` de l'entrée de `secureBindings` — Follow.lua —, nouveau tirage au relâchement de la touche par `PostClick` → `P.UpdateLeaderMacros`), touches redirigées par `SetOverrideBindingClick` ; `P.UpdateLeaderMacros` (appelé par `P.RefreshUI`, au login, sur `UPDATE_BINDINGS`), différé en combat (`P.ApplyPendingKeybinds` sur `PLAYER_REGEN_ENABLED`) |
| `Commands.lua` | Commande slash `/poly` (`/polypode`), fonctions globales de keybinding `POLYPODE_*` (toggle UI, se nommer leader, suivre/assister/barbare/train en secours, inviter, envoyer le volume, couper/rétablir le son), commandes `comptes` et `retirer-compte`, point d'extension `P.RegisterSlashCommand(nom, handler, aide)` (sous-commandes des addons compagnons ; aide nil = alias) et `P.InviteSelectedTeam` (commune au bouton, au raccourci et au clic gauche sur la barre flottante) |
| `Events.lua` | Handlers `ADDON_LOADED`, `PLAYER_LOGIN`, `CHAT_MSG_ADDON`, `UPDATE_BINDINGS`, `PLAYER_REGEN_ENABLED`, événements de quête, de cinématique, de suivi (`AUTOFOLLOW_BEGIN`/`END`), d'état du personnage (`STATUS_EVENTS` → `P.ScheduleStatus`) et de groupe (`PARTY_INVITE_REQUEST`, `GROUP_ROSTER_UPDATE`) |
| `Bindings.xml` | Déclaration XML des raccourcis clavier WoW |
| `Polypode.toc` | Manifeste — définit l'ordre de chargement des fichiers |
| `MODULES.md` | Conventions communes à tous les modules, liste des dépôts, procédure de documentation et création d'un module ; importé (`@`) par ce fichier, par le `CLAUDE.md` de chaque compagnon et par `Interface/AddOns/CLAUDE.md` |
| `Modele/` | Squelette d'addon compagnon à copier (non chargé par WoW : dossier imbriqué) : `Polypode_Modele.toc`, `Modele.lua` (exemple fonctionnel : zone de chaque personnage, avec chaque branchement sur l'API publique), `CLAUDE.modele.md`, `README.modele.md`, `LISEZMOI.txt` (renommage) |

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
5. **SavedVariables per-character** → `P.charDb` (= `PolypodeCharDB`). Ces fichiers ne sont **pas** partagés
   entre comptes : y mettre les réglages propres à une fenêtre (ex. `soloMode`, `debug` via `P.SetDebug`, `selectedTeam`, `assistStartAttack`, `autoAcceptQuest`, `autoValidateQuest`, `autoSelectGossip`, `autoSkipCinematic`, `autoTaxi`, `autoEnterInstance`, `sentVolume`, `followLeaderSound`, `autoGroup`, `groupByAccount`, `collapsedAccounts`, `followAlert`, `teamBar`).
6. **Pas de `print()`** en production — utiliser `P.Debug(msg)`, qui respecte `P.debugEnabled`.
7. **Messages de sync** : toujours via `P.SYNC_PREFIX`, jamais de préfixe en dur ailleurs.
8. **UI** : frames créées avec `CreateFrame`, toutes référencées dans `P.ui.*`.
9. **Ordre de chargement** respecte le `.toc` (`Core → Sync → Quests → Cinematics → Taxi → Instances → Sound → AutoGroup → Follow → UI_Skin → UI_Main → UI_TeamBar → UI_Minimap → UI_Options → UI_Options.xml → UI_OptionsPopup → UI_Trust → UI_Tokens → UI_Keybinds → Commands → Events → Bindings`).
   Ne jamais appeler au niveau fichier (hors fonction) une fonction définie dans un fichier chargé après.
   Les appels **à l'intérieur** d'une fonction peuvent référencer un fichier suivant (résolu à l'exécution).
10. **Pas de globals parasites** : toute variable de module doit être `local` ou sous `Polypode.`
    (exception : les fonctions de keybinding `POLYPODE_*` et les `BINDING_*`, imposées par l'API WoW).
11. **Conserver le bloc de commentaire en tête de chaque fichier** (`-- Polypode: NomFichier — rôle`).
12. **Prérequis de toute évolution UI : tout contenu de taille variable défile, sans limite.**
    Chaque nouveau panneau, liste ou fenêtre doit pouvoir défiler, même si peu d'éléments sont
    attendus aujourd'hui. Jamais de pile de lignes à hauteur fixe qui déborde du cadre. Pour une
    liste : `P.CreateScrollList(panel, formatFn [, top, opts])` + `P.SetListData(panel, items)` (`UI_Main.lua`, partagés avec les autres fenêtres, comme `P.CreatePanel`)
    (`opts.onClick(data, mouseButton)` rend les lignes cliquables, `opts.isSelected(data)` les surligne (aussi sans `onClick`), `opts.tooltip(data)` renvoie les lignes de l'infobulle au survol (nil ou vide = pas d'infobulle ; une ligne `{ gauche, droite }` s'affiche sur deux colonnes, `AddDoubleLine`, signalé par `P.LIST_TOOLTIP_COLUMNS`, 0.51.4) — toute action au clic doit y être rappelée —, `opts.tooltipUnit(data)` une unité dont l'infobulle WoW (`GameTooltip:SetUnit`) la remplace, `opts.button` ajoute un bouton à droite de chaque ligne, `opts.onDragStart(data)` réagit au glisser d'une ligne, `opts.onDoubleClick(data, mouseButton)` au double-clic (déclenché par WoW à la place du second clic), `opts.inset` fixe la marge latérale (défaut 10), `panel.SetListTop(top)` change après coup le décalage du haut de la liste (ancre commune déplacée, `behavior:EvaluateVisibility(true)` ; 0.58.1), `opts.rowHeight` la hauteur des lignes (défaut 20, ex. rangées d'icônes posées par `decorate` ; 0.56.0, signalé par `P.LIST_ROW_HEIGHT`), `opts.decorate(row, data)` habille une ligne à chaque affichage ; la barre de défilement n'apparaît et ne prend de place que si la liste déborde (`ScrollUtil.AddManagedScrollBarVisibilityBehavior`) ; les lignes
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
- Fonctionnalités essayées puis **retirées à la demande de l'utilisateur** (ne pas les reproposer) :
  bouton « Actualiser » et filtrage de « Personnages disponibles » sur les seuls personnages connectés
  (v0.16.0, retiré en v0.16.1) : la liste affiche tout le roster actif.

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
  (Procédure détaillée, commune à tous les modules : `MODULES.md`, section suivante.)

---

## Modules Polypode et documentation

Conventions communes à tous les modules, liste des dépôts et procédure de documentation
(avant / après chaque modification) : fichier partagé `MODULES.md`, importé ici et par le
`CLAUDE.md` de chaque compagnon. Le modifier là, pas ici.

@MODULES.md

---

## Patterns récurrents

### Ajouter un raccourci clavier
→ `<Binding name="POLYPODE_X">` dans `Bindings.xml`, libellé `BINDING_NAME_POLYPODE_X` dans `Core.lua`,
fonction globale `POLYPODE_X()` dans `Commands.lua`. Pour une **action protégée** (suivre, assister,
cibler, lancer un sort...) : pas d'appel direct ; ajouter une entrée à `secureBindings` dans
`UI_Keybinds.lua` (bouton `SecureActionButtonTemplate` de type `macro`, touche redirigée par
`SetOverrideBindingClick`). Le bouton doit être enregistré `RegisterForClicks("AnyUp", "AnyDown")` :
le modèle Blizzard agit à l'appui ou au relâchement selon le CVar `ActionButtonUseKeyDown` (actif par
défaut) ; avec seulement `LeftButtonUp`, la macro ne se déclencherait jamais. Aucun `SetAttribute`
ni `SetOverrideBinding*` en combat : différer (`pendingUpdate`).

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
`P.OnSyncMessage` lit `TYPE:token:reste` (`strsplit(":", message, 3)`) puis dispatche selon le type.
Messages existants :
- `HELLO` / `HI` : `TYPE:token:nom:royaume:classe:niveau:nomDeFamille` (canal groupe/raid/guilde ; nom de
  famille vide sur Retail, ajouté en dernier pour rester lisible par les versions précédentes).
- `TEAM` : `TEAM:token:flag:version:leader:membre1,membre2,...:nomÉquipe`, envoyé par
  `P.SyncTeam(teamName, target, select)` en **WHISPER**. `flag` = `N` (premier fragment), `S`
  (premier fragment + sélection chez le destinataire), `+` (suite) ou `D` (équipe supprimée : un seul
  message, membres vides, champ leader = nouveau nom si renommée) ; `version` = `team.updated`
  (heure serveur, strictement croissante par équipe) ; liste découpée pour tenir dans 255 octets ;
  nom d'équipe en dernier (peut contenir `:`). Réception : `P.ApplyTeamSync` n'applique un premier
  fragment que si sa version est **plus récente** que la locale, et un `+` que si la version locale
  est celle du premier fragment. Destinataires : `target`, sinon les clients connectés vus via
  HELLO/HI pendant la session (`onlineChars`), plus les membres si `select`.
- `TEAMINFO` : `TEAMINFO:token:date:nomÉquipe` (nom en dernier), date de création d'une équipe, envoyée par
  `P.SyncTeam` après les fragments `TEAM` (message à part : un champ de plus dans `TEAM` serait mal lu par
  les versions précédentes) ; reçue par `P.ApplyTeamCreated`.
- **Tokens acceptés** : le nôtre et ceux des comptes autorisés (`P.IsTokenTrusted`, `P.db.trustedTokens`). Token inconnu :
  HELLO/HI sur le canal dédié → `P.PromptTrust` (UI_Trust.lua), sinon ignoré. `OWN_ACCOUNT_ONLY` (`CHANSET`, `TRUST`) :
  acceptés seulement avec notre propre token (pas de changement de canal ni d'autorisation par un autre compte).
- `TRUST` : `TRUST:token:version:flag:tokenAutorisé:libellé` (flag `A`/`R`, libellé en dernier), autorisations
  versionnées (pierre tombale au retrait) envoyées en WHISPER à chaque changement et à chaque HELLO/HI
  (`P.SyncTrust`) ; reçues par `P.ApplyTrustSync`.
- `CHANSET` : `CHANSET:token:version:nom` (nom vide = désactivé), réglage du canal dédié (`P.db.syncChannel`,
  versionné) envoyé en WHISPER à chaque changement et à chaque HELLO/HI (`P.SyncChannelSetting`) ; reçu par
  `P.ApplyChannelSettingSync` (plus récent seulement), qui quitte l'ancien canal et rejoint le nouveau.
- Canal par défaut de `P.Broadcast` (annonces HELLO/HI) : canal dédié s'il est rejoint (`"CHANNEL"`, cible =
  son numéro via `GetChannelName`), sinon RAID, PARTY, GUILD. Les actions du leader restent en PARTY/RAID.
- `CHAR` : `CHAR:token:version:flag:classe:niveau:nom:royaume` (flag `A` actif / `R` retiré),
  envoyé par `P.SyncCharacter(key, target)` pour les entrées de roster **manuelles** (bouton
  « Ajouter la cible » → `P.AddTargetCharacter`, `/poly remove` → `P.RemoveCharacter`), qui passent
  par la locale `CharacterChanged` (version `entry.updated` + synchro). Réception :
  `P.ApplyCharacterSync` (version plus récente seulement, ne touche pas aux équipes).
  **Roster à pierres tombales** : une entrée retirée reste avec `removed = true` ; lire le roster via
  `P.GetRoster()` / `P.GetCharacter(key)` (entrées actives), jamais `P.db.roster` pour une décision
  (seulement pour l'affichage ou la synchro). Un HELLO d'un personnage retiré le réactive.
- `STATUS` : `STATUS:token:niveau:ilvl:race:spé:guilde:xp:durabilité:nom:royaume:zone` (zone en dernier ;
  xp = % du niveau en cours, vide au niveau maximum ; durabilité = % de la pièce équipée la plus usée), état du personnage façon liste d'amis, envoyé en WHISPER par `P.SendStatus(target)` à chaque HELLO/HI reçu et
  aux clients connectés quand il change (`P.ScheduleStatus`, 2 s après `ZONE_CHANGED_NEW_AREA`,
  `PLAYER_LEVEL_UP`, `PLAYER_XP_UPDATE`, `PLAYER_SPECIALIZATION_CHANGED`, `PLAYER_EQUIPMENT_CHANGED`, `PLAYER_GUILD_UPDATE`, `UPDATE_INVENTORY_DURABILITY`,
  envoyé seulement si différent du précédent). Gardé en mémoire (session), jamais sauvegardé ; `P.GetCharacterStatus` lit le personnage joué en direct. Réception et envoi rafraîchissent la barre flottante.
- `BARPOS` : `BARPOS:token:gauche:haut:largeur:hauteurListe:déplié:nomÉquipe` (valeurs en % de l'écran,
  hauteurListe vide = automatique, déplié 1/0, nom en dernier), disposition de la barre flottante envoyée
  en WHISPER aux membres connectés/groupés de l'équipe (`P.SyncTeamBarLayout`, Maj + clic) ; reçue par
  `P.ApplyTeamBarLayout` (UI_TeamBar.lua), ignorée si la barre est déjà affichée.
- `QLOG` : `QLOG:token:flag:envoi:nom-royaume:id1,id2,...` (flag `N` premier fragment qui remplace la liste,
  `+` suite ; envoi = compteur de l'expéditeur), journal de quêtes (`P.GetOwnQuestIDs`, Quests.lua : sans
  expéditions, objectifs bonus ni quêtes cachées) envoyé en WHISPER à chaque HELLO/HI reçu et aux clients
  connectés 2 s après `QUEST_ACCEPTED` / `QUEST_TURNED_IN` / `QUEST_REMOVED` ; accepté seulement si
  nom-royaume est l'expéditeur. En mémoire (session).
- `ACCT` : `ACCT:token:version:nom-royaume:nomDuCompte` (nom en dernier, vide = aucun compte),
  rangement d'un personnage dans un compte WoW nommé, envoyé en WHISPER aux clients connectés à chaque
  changement (`P.SetCharacterAccount`) et à chaque HELLO/HI reçu (`P.SyncAllAccountLabels`) ; reçu par
  `P.ApplyAccountLabelSync` (plus récent seulement).
- `FOLLOWEND` : `FOLLOWEND:token:nom-royaume`, envoyé en WHISPER par un membre au leader de son équipe
  sélectionnée quand son suivi automatique de ce leader s'arrête ; accepté seulement si nom-royaume est
  l'expéditeur, reçu par `P.OnFollowEndMessage` (Follow.lua). Pas dans `LEADER_ONLY` (envoyé par les membres).
- `FOLLOWING` : `FOLLOWING:token:nom-royaume:nom-royaumeSuivi` (suivi vide = plus aucun), joueur suivi par un
  client, envoyé au groupe/raid (PARTY/RAID) à chaque changement et quand le groupe s'agrandit ; accepté
  seulement si nom-royaume est l'expéditeur, reçu par `P.OnFollowingMessage` (Follow.lua, raccourci « Train »).
- `QACCEPT` : `QACCEPT:token:questID`, envoyé par le leader de l'équipe sélectionnée au groupe/raid
  (`PARTY`/`RAID`, pas de chuchotement) quand il accepte une quête ; reçu par `P.OnQuestAcceptMessage`.
- `QSTATE` : `QSTATE:token:questID:état:nom-royaume` (état `HAVE`, `NEED` ou `OK`), envoyé en **WHISPER** par
  un membre au leader qui a annoncé `QACCEPT` (1,5 s après, puis `OK` à l'acceptation) ; reçu par
  `P.OnQuestStateMessage` (leader, partage automatique). Pas dans `LEADER_ONLY` (envoyé par les membres).
- `QVALIDATE` : `QVALIDATE:token:questID` et `QREWARD` : `QREWARD:token:questID:choix`, mêmes canaux, envoyés
  par le leader quand il rend une quête ; reçus par `P.OnQuestValidateMessage` / `P.OnQuestRewardMessage`.
- `GQAVAIL` / `GQACTIVE` : `GQAVAIL:token:questID`, mêmes canaux, envoyés par le leader quand il choisit une
  quête disponible / active dans un dialogue de PNJ ; reçus par `P.OnGossipQuestMessage(kind, questID)`.
- `GOSSIP` : `GOSSIP:token:gossipOptionID:orderIndex` (orderIndex peut être vide), option de dialogue choisie
  par le leader ; reçu par `P.OnGossipOptionMessage`. `CLOSEUI` : `CLOSEUI:token`, fermeture de DialogueUI
  par le leader ; reçu par `P.OnDialogCloseMessage`.
- `CINESKIP` : `CINESKIP:token:kind` (`cinematic` ou `movie`), cinématique passée par le leader ; reçu par
  `P.OnCinematicSkipMessage`.
- `TAXI` : `TAXI:token:nomDestination` (nom en dernier, peut contenir `:`), vol pris par le leader ; reçu
  par `P.OnTaxiMessage`.
- `DELVEENTER:token:palier`, `DELVEEXIT:token`, `INSTENTER:token:portal` : gouffre (entrée, sortie) et portail
  d'instance ; reçus par `P.OnDelveEnterMessage`, `P.OnDelveExitMessage`, `P.OnInstanceEnterMessage`.
- `VOLUME:token:pourcentage` (0-100) et `SOUND:token:0|1` : son de l'équipe envoyé par le leader (raccourcis) ;
  reçus par `P.OnVolumeMessage`, `P.OnSoundMessage`.
- Envoi de ces actions : `P.BroadcastLeaderAction(kind, fields, dedupKey, window, reason)` (`Sync.lua`) —
  leader de l'équipe sélectionnée seulement (`P.IsTeamLeader`), groupe/raid, dédoublonné par clé.
- Messages de quête et de dialogue (`QACCEPT`, `QVALIDATE`, `QREWARD`, `GQAVAIL`, `GQACTIVE`, `GOSSIP`, `CINESKIP`, `TAXI`, `DELVEENTER`, `DELVEEXIT`, `INSTENTER`, `VOLUME`, `SOUND`,
  `CLOSEUI`) : table `LEADER_ONLY` de `Sync.lua`, acceptés **uniquement du leader de l'équipe sélectionnée
  et jamais de soi-même** (un message PARTY/RAID revient à l'expéditeur, qui rejouerait sa propre action).
  Tout nouveau message d'action rejouée par les membres doit y être ajouté.
- Déclencheurs : toute modification d'équipe dans `Core.lua` passe par `TeamChanged` (horodatage +
  `P.SyncTeam`) ; `P.ApplyTeamSync` n'appelle jamais `TeamChanged` (pas d'écho). À la réception d'un
  HELLO ou HI, `P.SyncAllCharacters(sender)` puis `P.SyncAllTeams(sender)` : échange complet dans les deux sens
  (pierres tombales d'équipes comprises).
  **Équipes à pierres tombales** : une équipe supprimée reste dans `P.db.teams` avec `removed = true` ; lire
  les équipes via `P.GetTeams()` / `P.GetTeamMembers` / `P.GetTeamLeader` (actives), jamais `P.db.teams`
  pour une décision (seulement pour la synchro).
- Tous les envois passent par une **file** (`P.Broadcast`) : un message à la fois, retenté si le
  client le rejette pour limite de débit. L'erreur système « joueur non connecté » consécutive à
  nos chuchotements est filtrée (`CHAT_MSG_SYSTEM`) et retire le personnage de `onlineChars`.

**Environnement de l'utilisateur** : les dossiers `WTF/Account/*/SavedVariables` de ses comptes
sont des **jonctions vers un seul dossier** (`BAKTOV`). Tous les clients lisent et réécrivent donc
le même `Polypode.lua` (réécriture complète à chaque déconnexion/reload : le dernier qui écrit
gagne). Toute donnée persistante modifiable depuis un client doit être synchronisée en mémoire
vers les autres clients connectés, avec une version pour ne jamais régresser.
Un message ciblant un joueur passe par `P.Broadcast(message, "WHISPER", P.GetTargetName(entry))`.

### Référencer l'API Blizzard pour une nouvelle fonctionnalité
→ Avant d'implémenter un appel à l'API WoW (frames, events, namespaces `C_*`), vérifier la
signature exacte plutôt que de deviner. Sources, par ordre de préférence :
1. **Serveurs MCP**, si leurs outils sont disponibles dans la session. Configurés en portée *user*
   (hors repo, actifs dans tous les projets d'addon ; Node 20+) :
   - `wow` ([hated-wow-mcp](https://github.com/RdyGaming/hated-wow-mcp)) — Retail et Forever
     (`flavor: "forever"`) : recherche d'API/events/types, source de l'UI Blizzard, CVars, atlas de
     textures. Ses outils de lint Lua et de validation TOC/XML servent aussi à vérifier une
     modification avant de la commiter.
     `claude mcp add --scope user wow -- cmd /c npx -y hated-wow-mcp`
   - `wow-addon-api` ([wow-addon-api-mcp](https://github.com/Koodattu/wow-addon-api-mcp)) — canaux
     `retail` et `forever` : historique et comparaison de l'API entre versions (`compare_api`,
     `diff_versions`, `get_api_history`), restrictions (`search_restrictions`). Sert à savoir si une
     API existe sur Forever, donc si elle doit être testée avant usage.
     `claude mcp add --scope user wow-addon-api -- cmd /c npx -y wow-addon-api-mcp@latest`
   - `wow-api` ([wow-api-mcp](https://github.com/spartanui-wow/wow-api-mcp)) — annotations de
     l'extension VS Code `ketho.wow-api` (requise) : fonctions dépréciées et leurs remplaçants
     (`list_deprecated`), méthodes de widgets, enums, charges utiles des events.
     `claude mcp add --scope user wow-api -- cmd /c npx -y wow-api-mcp`
2. **Local** : un clone de `wow-ui-source` placé à côté de `Polypode/` dans `AddOns/`, si présent.
3. **GitHub** : https://github.com/Gethe/wow-ui-source/

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
