# Polypode

*Version française : [README.md](README.md)*

World of Warcraft addon to **easily manage several characters played in several WoW windows on
the same PC** (multiboxing).

Polypode is inspired by TeamManager, MAMA, EMA and DynamicBoxer (thanks to Moorea, EbonyFaye and
the MultiBox community), but first aims at simplicity: a roster of your characters, teams with
their leader, and basic automatic synchronization between your clients, with no complex setup.

Companion addons extended its features, also inspired by well-known addons but adapted to
multiboxing (MySlot, myAlts, SavedInstances, AlterEgo, Altoholic, CharacterInfo, Narcissus, etc.).

With these addons came the wish for a Solo mode (Monopode :D), which amounts to an equivalent of
the addons above (while keeping the Polypode philosophy): we have come full circle.

> **Languages**: French, English, German, Spanish, Italian and Brazilian Portuguese (see
> "Languages" below). The translations were made with the help of Claude, Anthropic's AI: feedback
> from native speakers is very welcome
> ([GitHub issue](https://github.com/Baktov/polypode/issues)).

---

## Installation

1. Download **`Polypode-<version>.zip`** from the [latest release](https://github.com/Baktov/polypode/releases/latest)
   (not "Source code", whose folder would have to be renamed) and unzip it into
   `World of Warcraft/_retail_/Interface/AddOns/`: it directly contains the `Polypode` folder.
   Companion addons, same procedure (each one requires Polypode):
   [Data](https://github.com/Baktov/polypode-data/releases/latest),
   [History](https://github.com/Baktov/polypode-histoire/releases/latest),
   [Map](https://github.com/Baktov/polypode-map/releases/latest),
   [Photo](https://github.com/Baktov/Polypode-Photo/releases/latest),
   [Profiles](https://github.com/Baktov/polypode-profil/releases/latest),
   [Tracker](https://github.com/Baktov/polypode-suivi/releases/latest).
2. Enable the addon on the character selection screen (AddOns).
3. Repeat on every WoW window/client you multibox with.

**WoW Forever** (`_forever_` folder) is supported too: this mode runs on the same engine as
Retail (12.1) with the original content. Copy (or link with a junction) the `Polypode` folder into
`World of Warcraft/_forever_/Interface/AddOns/`. Features tied to content missing from Forever
(delves, world quests, specializations...) turn themselves off there. Forever and Retail characters
do not see each other (separate games and servers): each mode has its own teams. On Forever,
characters have a first name and a last name: Polypode shows them as "First Last" (lists, floating
bar, tooltips, team quests, alerts, photo mode) as soon as the character's Polypode has announced
itself.

---

## How it works

- At login, Polypode automatically records your current character in a shared roster (saved at
  account level).
- If you are in a group, a raid or a guild shared with your other clients, Polypode announces your
  character (name, class, level) to your other clients, which answer by announcing themselves: each
  roster knows every character, whatever the login order. Polypode also announces itself to the
  group whenever it grows: grouping a character already logged in is enough for it to receive the
  teams.
- **Dedicated channel** (optional): the simplest is still to group your characters at first login
  (or to share a guild), with nothing to set. The dedicated channel is for the other cases: several
  WoW or Battle.net accounts, characters with no shared guild, not grouped yet. It is a channel name
  shared by your accounts, typed in the window ("Channel" field right of the Options button) or in
  the options panel. Each client joins it automatically (5 seconds after login, so as not to take the
  General channel's number) without showing it in the chat. It acts as a shared guild for login
  announcements: your Polypodes find each other even with no shared guild or group, and it takes
  priority over raid, group and guild. The choice is shared with your other logged-in Polypodes.
  Name: no space or ":", not starting with a digit, 31 characters at most; empty to disable.
- **Only your characters are recognized**: each announcement carries a team token derived from your
  BattleTag (hashed, never sent in clear). Other guild players using Polypode are ignored.
- **Other Battle.net accounts** (multiboxing with a second Battle.net account): when a character of
  an unknown account announces itself on the **dedicated channel**, a window asks for permission,
  showing the channel (name and number), the character, its class and its level. **Allow** adds
  this account to your allowed accounts: it then exchanges with you like your own accounts (roster,
  teams, grouping, leader actions); the other account gets the same request for you. **Deny** (or
  Escape): no more requests for this account until the next reload. Outside the dedicated channel
  (guild, group), unknown accounts stay ignored without a request. The list is shared between your
  own clients (not with allowed accounts: no cascading permission); `/poly accounts` shows it and
  `/poly remove-account <no.>` removes a permission. The **Manage token list** button (options
  panel, right of the dedicated channel) opens a window with the allowed accounts: on hover, a
  tooltip lists the known characters of each account; the **Revoke** button on the right removes
  the permission (synchronized with your other Polypodes). Escape closes the window.
- You gather your characters in **teams**, each with its **leader** (see Main window), the base
  for actions tied to the leader: follow, assist, etc.
- **Teams are synchronized automatically** between your logged-in Polypode clients: creation,
  adding/removing a member and leader changes are sent at once to the other clients, and two
  clients that discover each other (login, reload) exchange all their teams. When versions
  differ, **the most recent one wins**: a client started on an old save cannot overwrite a more
  recent change. This is essential if your accounts share the same save file (junctions of
  `SavedVariables` folders): each client rewrites that whole file at logout, so they must all have
  the same teams in memory. The "No player named ... is currently playing" messages caused by
  syncing to an offline character are hidden.
- **Quests and dialogs**: when the team leader picks a quest or an option in an NPC dialog,
  accepts or turns in a quest, or closes DialogueUI, the other characters of the group do the same
  as soon as the NPC offers them the same thing (options "Follow the leader's NPC dialogs",
  "Auto-accept quests" and "Auto-complete quests", see Options). Only the actions of the **leader of
  the selected team** are followed.
- **Automatic quest sharing**: when the leader accepts a quest that grouped team members did not
  take (NPC not opened on their side, quest started by an item...), they **share** it automatically
  a few seconds later, and the members accept it. A message shows on the leader's screen if the
  quest cannot be shared (to be taken from the NPC), or if members still do not have it 15 seconds
  later (out of range, full quest log, prerequisites, option unchecked or character without
  Polypode). World quests and bonus objectives, accepted by entering their area, are not affected.
- **Cinematics**: when the leader skips a cinematic or a movie, the other characters of the group
  skip it too (option "Auto-skip cinematics").
- **Flights**: when the leader takes a flight at a flight master, the other characters of the group
  whose flight map is open take the same one (option "Auto-take the leader's flight").
- **Delves and portals**: when the leader enters a delve (tier choice), votes to leave it or
  confirms entering through an instance portal, the other characters of the group do the same
  (option "Auto-enter instances (delve, portal)").
- **Team sound**: the leader sets the master volume of the other windows, or mutes / unmutes them,
  with a key binding (options "Sent volume" and "Follow the leader's sound"). Their own sound does
  not change.
- **Auto-grouping**: when a character member of a team logs in, if the team leader is already
  logged in, the leader invites them automatically and the character accepts (option "Auto-group
  the team"). Same thing when the leader logs in after the members. Both must see each other
  (dedicated channel, shared guild or group) and the leader must be able to invite (alone, or group
  leader, 5 at most outside a raid).
- **"No longer following" alert** (option): when a member stops following the team leader
  (`/follow` or "Follow the leader" binding interrupted by an obstacle, a jump, the distance, a
  manual move...), the leader sees "X is no longer following you." on screen with an alert sound.
  Using "Follow the leader" again on a member already following does not trigger an alert.
- **Characters added and removed by hand** ("Add target" button, `/poly remove`) are synchronized
  the same way, with the same version rule: a removed character does not come back through a client
  that still had it (it only comes back if it logs in itself with Polypode).

---

## Main window

Opened with `/poly ui`, the key binding or the minimap button. The **Options** button (top left of
the title bar) opens the Polypode options panel directly; **right-click**: the WoW key bindings,
opened on the expanded **Polypode** section. To its right, the **Channel** field then the **Solo**
box (in red, see "Solo mode" below). Three frames side by side:

- **Available characters**: all the characters of your team detected through the channels (group,
  raid, guild). **Logged-in** characters come first, then the logged-out ones, **slightly greyed**;
  alphabetical order in each group (ignoring accents and case). Logged in = you, a character whose
  Polypode announced itself during the session, or a logged-in member of your group (even without
  Polypode); the tooltip says so.
  **Group by WoW account** (option "Available characters: group by account"): one header per WoW
  account ("- Account name (logged in/total)"), collapsed or expanded with a click, then "Account
  not set" for characters without an account. A **Collapse all** button right of the "Available
  characters" title collapses every account (it becomes **Expand all** when everything is
  collapsed); it only shows with this option. The **In Game** button (to its left, or alone right of
  the title without grouping) only shows **logged-in** characters (a simple display filter; accounts
  with nobody logged in are hidden); when active, it turns blue. It is active by default in solo
  mode (Monopode) and inactive by default otherwise; the choice is remembered for each mode and each
  character. WoW does not give addons the WoW account name: it is set on each character, in the
  options (**WoW account of this character** field, once per character) or with **Alt + click** on
  a character in the window (menu: existing accounts, "New account...", "No account"). **Alt + click
  on an account header** **renames** it for all its characters (an existing name merges the two
  accounts; no effect on "Account not set"). This arrangement is shared with your other Polypodes
  (the most recent wins). Since your account files are shared (junctions), the name can only be
  stored per character. Name in class color, then class and level; `(you)` marks the current
  character.
  **Add target** button (top of the frame): adds the targeted player to the list, even without
  Polypode (e.g. a friend); they can then join a team and be invited with it. The addition is shared
  with your other logged-in Polypodes.
  When a team is selected: **right-click** on a character adds it to the team, **left-click**
  removes it, after confirmation; team members are highlighted in gold. A tooltip on hover gives the
  character's name, recalls these actions, then lists the teams it already belongs to (the selected
  team in green).
  **Shift + click** on a character **deletes** it from Polypode, after a confirmation listing what
  goes with it: its teams, its named WoW account and the data of the companion addons (Polypode Data
  and Polypode Tracker records, Polypode Profiles profiles stored under it). The deletion is shared
  with your other logged-in Polypodes. The current character cannot be deleted; a deleted character
  comes back if it logs in with Polypode.
  **With no team selected**, a **right-click** on a character creates a team named after it
  ("Arthas", or "Arthas_1", "Arthas_2"... if that name is taken), with it as member and **leader**,
  and selects it.
- **Teams**: type a name in the "Team name" field then confirm with **Enter** or the **Create**
  button: the team is created and added to the list (sorted by name, remembered for the account). An
  empty or already used name is refused with a red message on screen. **Escape** leaves the field.
  **Left-click** on a team selects it (gold highlight), **right-click** deselects it (no team
  selected any more, recalled by a tooltip on hover). A team's tooltip gives its **creation date**
  (unknown for teams created before version 0.50.0). The selection is **remembered for each
  character**: after a logout, a login or a reload, the same team is selected, whether this
  character is its leader or not (a team received through "Invite team" also becomes the remembered
  selection).
  **Shift + left-click** on a team **deletes** it (without confirmation), on your other logged-in
  Polypodes too; a deletion wins over older copies (clients started later, shared save file). A team
  with the same name can then be created again.
  A **double-click** on a team opens a window to **rename** it (Enter or "Rename" to confirm,
  Escape to cancel): members and leader are kept, the change is shared with your other Polypodes, and
  the characters that had selected the team find it under its new name (even those logging in
  later). An empty name, a name already taken or one containing ":" is refused.
  **Dragging** a team (left button held) out of the window selects it and drops it as a **floating
  bar** where you release it (see Floating team bar).
- **Team characters**: members of the selected team, the **leader always first** then the others
  sorted by name, same layout as the available characters.
  - **Left-click** on a member: it becomes **team leader** (gold highlight and `[leader]`). Each team
    has its own leader.
  - **Right-click**: removes the member from the team, after confirmation; if it was the leader, the
    team no longer has a leader (the confirmation says so).
  - The tooltip on hover recalls these actions and lists the character's teams, with `(leader)`
    where it is one.
  - **Invite team** button (top of the frame): invites into your group every member of the selected
    team, except the current character and those already grouped. **Only active on the team
    leader's client** (greyed otherwise; the tooltip says why: no team selected, no leader, another
    leader, or no other member). You must be alone or group leader (or assistant in a raid). A party
    (not a raid) is limited to 5: beyond that, the remaining invitations are reported; convert the
    group to a raid then click again. The summary shows in the middle of the screen. The same click
    also sends the team to each member's Polypode (on your other accounts), which **selects** it:
    its characters appear at once in "Team characters", even before the invited ones accept.

  Teams, their members and their leader are remembered for the account; a character removed from
  the roster (`/poly remove`) also leaves its teams.

The three lists scroll (mouse wheel or scroll bar), with no limit on their size; the scroll bar
only shows when the list overflows the frame.

The window is **resized** with the bottom-right corner grip; the three frames share the width
equally and the size is remembered for the account (720 × 320 by default). If the window is made
very small, the content is simply cut off.

---

## Importing characters

Polypode only knows a character after its first login with the addon. To build teams in advance,
you can **import the list of your characters**:

1. Outside the game, the [`tools/import_bnet.py`](tools/import_bnet.py) program fetches from
   Blizzard (Battle.net API) all the characters of the WoW accounts of your Battle.net account and
   writes `polypode_import.txt` (instructions, in French:
   [`tools/IMPORT_BNET.md`](tools/IMPORT_BNET.md)). It only outputs characters missing from the
   roster and can be run again at will.
2. In game, `/poly import` or the **Import characters** button of the options panel opens a window
   to paste these lines into (Ctrl+V), then **Import**. You can also type one line per character:
   `Name-Realm;CLASS;level;account` (only the name is required; without a realm, the logged-in
   character's; empty lines and lines starting with `#` are ignored).

Unknown characters are added to the roster and shared with your other Polypodes, filed under the
given WoW account. A character already known is not changed (it only gets the given account if it
has none), a removed character is not recreated: importing the same list twice creates no
duplicates. The report (added, already known, removed, unreadable lines) shows under the text box.
An imported character appears without being logged in; its first login fills in the rest.

## Solo mode

To play **a single character**: **Solo** box (in red, right of the Channel field of the main window)
or first option of the panel, **Solo mode** (in red). Per-character setting.

- The window only keeps **Available characters**, over its whole width; the "Teams" and "Team
  characters" frames are hidden, and the window is a bit narrower (620 pixels by default; its width
  in solo mode is kept apart from the normal width). The window title becomes **Monopode**. The
  **Add target** button is hidden (it is for building teams) and the list moves up in its place.
- Team clicks on characters do nothing; Alt + click (WoW account) and Shift + click (deletion)
  remain.
- **Dragging your character** (the "(you)" line) out of the list turns it into a **floating bar**,
  like a team: your name in class color, right-click to expand its line (level, item level, health,
  durability), same grip, padlock, close button and **column of module buttons**. No invitation or
  position sharing. Its display is remembered separately: the team bar comes back when leaving solo
  mode.
- Modules: **Tracker** always lists every character ("All characters" box checked and greyed);
  **Profiles**, **Photo** and **Data** remain available.

## Floating team bar

Small bar placed on the game screen, taken out of the main window by **dragging** a team from the
"Teams" frame. It shows the name of the **selected team** and its number of characters, and follows
the selection (click on another team, sync); "No team" if nothing is selected.

- **Polypode icon** (far left, the same as the minimap button): a click opens or closes the Polypode
  main window; a **right-click** opens a **small options window** next to the icon (boxes, sliders
  and lists of the options panel, same settings; movable, Escape or close button to close it; **All
  options** button for the full panel, with the dedicated channel and the WoW account). Likewise, a
  right-click on a module button opens the small window of its options, if it has any (Data, Photo,
  Tracker).
- **Left-click**: invites the team into your group, exactly like the **Invite team** button of the
  main window (reserved to the team leader; otherwise a red message explains why, recalled in the
  tooltip).
- **Member status**: right of each character, a label says whether they are **not grouped**,
  **offline**, **disconnected**, **dead** or **far** (out of range), and a thin green **health
  bar** underlines each grouped member (can be hidden with the option "Team bar: members' health
  bar"). The line of an offline or disconnected character is faded. Updated continuously while the
  list is expanded.
- **Module buttons** (option "Team bar: module buttons", checked by default): against the bar, a
  vertical column of small buttons repeats those of the installed companion addons (Data, Photo,
  Profiles, Tracker...). To stay discreet, only the **first three letters** of the name show, in a
  small font; the click and the tooltip are the same as in the Polypode window (Photo: right-click =
  options). Column **on the left** by default, **on the right**, or **horizontal** row above the bar
  (option "Team bar: button side").
- **Reduced bar** (option "Team bar: reduced to the icon"): only the **Polypode icon** remains, in a
  frame the size of a module button (name, character list, close button and grip hidden). The module
  buttons are then **below in a column** (left, right), or **right of the icon in a row**
  (horizontal). The icon keeps its actions: click = Polypode window, right-click = options, drag =
  move the bar, **Alt + click** = lock or unlock (in the normal bar too), **Shift + right-click** =
  hide the bar (there is no close button).
- **Low durability** (option "Team bar: flash when durability is low", checked by default): a
  character's line flashes red when their most worn piece of equipment goes below the **threshold**
  set by the "Team bar: durability threshold" slider (25% by default, from 5 to 95% in steps of 5).
  Durability is sent by each character's Polypode on every change; the tooltip of a member not
  grouped shows it too.
- **Details** (option "Team bar: level, item level and progress", checked by default): left of each
  character, their **level** (gold), the **% progress** in that level (grey, hidden at max level)
  and their equipped **item level** (blue), then their short name. This information comes from
  each character's Polypode (updated live: XP, equipment, level); "?" until received. Unchecked:
  layout of the main window (name-realm, class, level).
- **Right-click**: expands / collapses the list of the team's characters (same layout as in the
  window: the leader first, highlighted in gold and marked `[leader]`). When hovering a character
  **grouped with you**, the full WoW tooltip shows (the same as when hovering their party frame:
  level, class, specialization, guild, realm...). **Outside the group**, a friends-list-style
  tooltip: level, race, class and specialization, guild, zone, item level and presence (online, or
  offline with the age of the information), then their teams. This information is sent by the
  character's Polypode at each encounter and when it changes (zone, level, specialization,
  equipment, guild); without it (character not seen yet this session), the tooltip shows what the
  list knows (level, class, last login). Beyond 8 characters, the list scrolls. It opens below the
  bar, or above if the bar is too close to the bottom of the screen.
- **Drag**: moves the bar.
- **Shift + click**: sends the position and size of the bar (and whether it is expanded) to the
  other logged-in characters of the team. For those whose bar is **hidden**, it shows at the same
  place and size, in proportion to their screen size (windows of different sizes); a bar already
  shown keeps its place. The team is also selected for those who had none.
- **Corner grip** (bottom right of the bar, or of the expanded list): resizes the width of the bar
  and, with the list expanded, the height of the list (which scrolls beyond).
- **Alt + click**: **locks** the bar (position and size: no more moving, grip hidden, padlock shown)
  or unlocks it. Invitation (left-click), expanding (right-click) and the close button stay active. A
  locked bar does not move when you drag a team out of the window again.
- **Close button**: hides the bar; drag a team out of the window again to show it.

Display, expansion, position, size and lock are remembered **for each character** (each multibox
window has its own bar) and restored at login.

---

## Companion addons (separate)

Six features are separate addons, which depend on Polypode and are enabled or not in the AddOns
list; without them, Polypode works normally. Each adds its button to the title bar of the main
window (left of the close button) and its `/poly` command. **Polypode Quêtes** is **obsolete**: its
team quests are in the **Quests** panel of Polypode Tracker; it can be disabled (it only reminds you
of that).

- **Polypode Photo** (https://github.com/Baktov/Polypode-Photo): **Photo** button and
  `/poly photo`, group members full length, side by side, on a background of your choice.
- **Polypode Tracker** (Polypode Suivi, https://github.com/Baktov/polypode-suivi): **Tracker**
  button and `/poly suivi` (or `/poly tracker`), sortable table of the selected team: Great Vault,
  crests, catalyst, resources, renown, runes of power, weekly activities, mail, and **campaign**
  progress (chapters, per expansion, from Mists of Pandaria to Midnight); panels for the expansion's
  activities, all campaigns (who finished, started or did not do them) and the team's current
  **quests** (who completed them, has them in progress or still has to take them, `/poly quests`);
  on **WoW Forever**, tracking of the **Legacy** (points earned, spent per tree, to spend,
  challenges); **Grid** window (**Grid** button of the title bar, `/poly grid`) of every character
  by WoW account and team, and by race / class (information exchanged through Polypode, to install
  on each tracked character). Polypode exchanges the quest logs between your clients (at login and
  on each quest accepted, turned in or abandoned); automatic accepting, completing and sharing stay
  in Polypode.
- **Polypode Data** (https://github.com/Baktov/polypode-data): **Data** button and `/poly data`,
  sortable table of the lasting data of all your characters (level, item level, gold, professions
  and recipes, achievements, play time, equipment, bags and banks), with item and recipe search, play
  time by class or by race and by account (like AccountPlayed) and automatic bank sorting, in the spirit of DataStore / WoWthing (to install on each character).
- **Polypode History** (Polypode Histoire, https://github.com/Baktov/polypode-histoire): **History**
  button and `/poly histoire`, shared chronological journal of all your characters (logins, grouped
  team, delves, dungeons, M+ keys, raid bosses, achievements, levels, item level), by collapsible
  year, month and day or as a timeline (day, week, month), exchanged between your clients; export of
  old months to an archive (to install on each character, with Polypode Histoire Archive).
- **Polypode Profiles** (Polypode Profil, https://github.com/Baktov/polypode-profil): **Profiles**
  button and `/poly profil`, library of the export strings of Edit Mode, talents, transmog, titles,
  equipment sets, macros, action bars, WoW options, key bindings, chat windows, the addon list and
  addons (EllesmereUI, ElvUI, Baganator, MySlots, Simple Addon Manager...), shared by all your
  characters and exchanged between your logged-in clients.
- **Polypode Map** (https://github.com/Baktov/polypode-map): **Map** button and `/poly map`, small
  permanent zone map (resizable, zoomable, fadable) showing the characters of the selected team,
  even outside the group (positions exchanged between your clients), with quests, world quests,
  TomTom waypoints, HandyNotes and a ping on click; replaces EnhanceBattlefieldMinimap, with no
  library (to install on each character).

---

## Slash commands (`/poly` or `/polypode`)

| Command | Description |
|---|---|
| `/poly list` | List the known characters (roster) |
| `/poly addme` | Add/re-announce the current character |
| `/poly remove <name-realm>` | Remove a character from the roster |
| `/poly import` | Open the window to import a list of characters (see "Importing characters") |
| `/poly ui` | Open/close the main window |
| `/poly minimap` | Show/hide the minimap icon |
| `/poly options` | Open the options panel (Options > AddOns > Polypode) |
| `/poly quetes` (or `/poly quests`) | Leader's quests missing on the members: "Quests" panel of **Polypode Tracker**, if installed and enabled |
| `/poly suivi` (or `/poly tracker`) | Team tracker: vault, crests, resources, renown, runes (**Polypode Tracker** addon, if installed and enabled) |
| `/poly data` | Character data: level, gold, professions, equipment, bags, banks, item search (**Polypode Data** addon, if installed and enabled) |
| `/poly profil` | Profiles: export strings of Edit Mode, talents, transmog, titles, equipment sets, WoW options, key bindings, chat windows, the addon list and addons (**Polypode Profiles** addon, if installed and enabled) |
| `/poly photo` | Photo mode (**Polypode Photo** addon, if installed and enabled) |
| `/poly accounts` (or `/poly comptes`) | List the other allowed Battle.net accounts (numbered) |
| `/poly remove-account <no.>` (or `/poly retirer-compte <no.>`) | Remove an account's permission (number given by `/poly accounts`) |
| `/poly language auto\|fr\|en\|de\|es\|it\|pt` (or `/poly langue`) | Choose the language of Polypode and its modules (Auto = the game's), applied after `/reload`; with no argument, shows the current choice |
| `/poly debug` | Turn debug messages on/off (remembered for this character, like the box of the options panel) |
| `/poly` (no argument) | Show the help |

A character's name in the roster has the format `Name-Realm` (e.g. `Arthas-Hyjal`).

---

## Key bindings

Set in the WoW key bindings menu, **Polypode** category (direct access: **right-click** on the
**Options** button of the main window):

| Binding | Action |
|---|---|
| Open/Close the window | Toggle the main window |
| Become team leader | The current character becomes leader of the selected team (joining it if it is not a member); synchronized with your other Polypodes |
| Follow the leader | Follows (`/follow`) the leader of the selected team |
| Assist the leader | Assists (`/assist`) the leader of the selected team: takes their target, then attacks (`/startattack`) if the option "Attack after assisting" is checked |
| Barbarian: follow a random group player | Follows (`/follow`) another logged-in player of the group picked at random (other than the one already followed if there is a choice); a new player is picked after each press |
| Train: follow a group player nobody follows | Follows a group player that no other character follows yet and who does not follow you (no loop): preferably the tail of the line leading to the leader of the selected team, otherwise at random. Pressed on each character one after the other, it forms a line behind the leader |
| Invite team | Same action as the "Invite team" button (reserved to the leader) |
| Send volume to the team | Leader: sets the master volume of the other members to the "Sent volume" option |
| Mute/unmute the team | Leader: mutes all sound of the other members, then restores it on the next press |

All actions apply to **the team selected for this character** (remembered, see Main window).
"Follow" and "Assist" are actions protected by WoW: the key is given to a Blizzard secure button
that runs the macro, so they also work in combat. Only a change of leader, team or key during
combat is taken into account when combat ends. With no usable leader (no team, no leader, or you
are the leader), the key shows a message on screen.

"Barbarian" and "Train" apply to **the group** (not the team) and are secure buttons too: the
player to follow is chosen in advance, out of combat (in combat, the key follows the last one
chosen). For "Train", each Polypode client tells the group whom it follows (and when it stops):
only the follows of characters with Polypode are known, and a character joining the group learns
the current follows when the others see it arrive. With no possible player (alone in the group, or
all already followed), the key shows a message on screen.

---

## Minimap button

A **hand**-shaped button is placed around the minimap:

- **Left-click**: open/close the Polypode window.
- **Drag**: move the button around the minimap (position remembered for the account). Works with
  a round or square minimap (ElvUI).

With **EllesmereUI Minimap**, the button is automatically put in the EllesmereUI button drawer,
which then handles its position.

To hide or show the button again: `/poly minimap`, or the matching box in the options panel. The
choice is remembered for the account.

---

## Options

Panel in **Options > AddOns > Polypode** (or `/poly options`, or the **Options** button of the main
window):

| Option | Default | Effect |
|---|---|---|
| **Langue / Language** (at the top) | Auto | Language of Polypode and its modules: Auto (the game's), Français, English, Deutsch, Español, Italiano or Português (Brasil); applied after `/reload` (see "Languages"). For **all your characters** |
| **Solo mode** (in red) | No | A single character: window reduced to "Available characters", floating bar of the current character, Quests hidden, Tracker on every character (see "Solo mode"). Same box as **Solo** in the window. **Per-character** setting |
| Dedicated channel | empty | Optional: name of the chat channel shared by your accounts, useful with no group or shared guild (see How it works; the field's tooltip recalls it). Can also be changed in the main window. On the right, "Manage token list" button: list and revocation of the allowed accounts. For the whole account, synchronized between your clients |
| Show minimap icon | Yes | Shows the Polypode button around the minimap |
| Debug mode | No | Shows diagnostic messages in the chat (sync, invitations...). **Per-character** setting: it can be turned on in a single window |
| Attack after assisting | Yes | The "Assist the leader" binding also starts auto-attack (`/startattack`) on the target taken if it is hostile; unchecked, it only takes the target. **Per-character** setting (e.g. unchecked on a healer) |
| Auto-accept quests | Yes | When the team leader accepts a quest, this character accepts it too as soon as it is offered (NPC opened or shared quest, up to 30 s later). On the leader, also turns on automatic sharing to the members who lack the quest, with a message on screen when it fails. **Per-character** setting; must be checked on the leader (who announces and shares their quests) and on the members |
| Auto-complete quests | Yes | When the leader turns in a quest ("Continue" then "Complete Quest"), this character turns it in too with the **same reward index**, as soon as the NPC is opened (up to 60 s later). A choice reward that does not fit is left to pick by hand. **Per-character** setting, to check on the leader and the members |
| Follow the leader's NPC dialogs | Yes | When the leader picks a quest (available or to turn in) or a dialog option in an NPC dialog, this character makes the same choice if its dialog with the NPC is open; when the leader closes DialogueUI, it closes it too. Auto-accept or auto-complete follows. **Per-character** setting, to check on the leader and the members |
| Auto-skip cinematics | Yes | When the leader skips a cinematic (in-engine, scene) or a movie, this character skips it too, as soon as it shows (up to 15 s later). **Per-character** setting, to check on the leader and the members |
| Auto-take the leader's flight | Yes | When the leader takes a flight at a flight master, this character takes the same flight if its flight map is open and it knows the destination (found by its name). **Per-character** setting, to check on the leader and the members |
| Auto-enter instances (delve, portal) | Yes | When the leader picks a delve tier, this character picks the same if its tier window is open; when the leader votes to leave the delve, it votes "Yes" too (up to 30 s later); when the leader confirms entering through an instance portal, it confirms too. **Per-character** setting, to check on the leader and the members |
| Sent volume | 50% | Slider from 0 to 100% in steps of 5%. On the leader: master volume applied to the other members by the "Send volume to the team" binding. **Per-character** setting |
| Follow the leader's sound | Yes | Applies to this character the volume sent by the leader and the muting / unmuting. Unchecked: this client keeps its own sound. **Per-character** setting |
| Alert when a member stops following | Yes | Member: tells the leader their auto-follow ended. Leader: shows "X is no longer following you." on screen with an alert sound (at most once every 3 s per member). **Per-character** setting, to check on the leader and the members |
| Team bar: level, item level and progress | Yes | In the list of the floating team bar, shows left of each character their level, their % progress in that level (except at max level) and their equipped item level. **Per-character** setting |
| Team bar: members' health bar | Yes | Underlines each grouped member of the floating bar list with a thin health bar; unchecked, only the status label remains. **Per-character** setting |
| Team bar: flash when durability is low | Yes | Flashes red, in the floating bar list, a character whose most worn piece is below the threshold below. **Per-character** setting |
| Team bar: durability threshold | 25% | Slider from 5 to 95% in steps of 5: durability threshold under which a character flashes. **Per-character** setting |
| Team bar: module buttons | Yes | Column of small buttons (first three letters) repeating those of the companion addons against the floating bar: same click, same tooltip as in the window. **Per-character** setting |
| Team bar: button side | Left | List: column left or right of the floating bar, or horizontal row above. Reduced bar: column below the icon (left, right) or row on its right (horizontal). **Per-character** setting |
| Team bar: reduced to the icon | No | The floating bar only keeps the Polypode icon, in a frame the size of a module button; module buttons below (or on the right when horizontal). **Per-character** setting |
| Available characters: group by account | Yes (new characters) | Files the available characters under a collapsible header per WoW account (set by the field below or Alt + click on a character), then "Account not set". **Per-character** setting |
| WoW account of this character | empty | Text field: name of the WoW account you play this character on (saved with Enter or when leaving the field, Escape cancels; empty = no account). Visible in the list with the "group by account" option. Same setting as Alt + click in the window; shared with your other Polypodes |
| Import characters | — | Button: opens the window to import a list of characters, like `/poly import` (see "Importing characters") |
| Auto-group the team | Yes | Leader: automatically invites into their group the members of their selected team who log in, or are already logged in when they log in. Member: automatically accepts the group invitation of the leader of one of their teams. **Per-character** setting |

---

## Appearance

The window adapts automatically to your interface, with nothing to set:

| Interface detected | Look |
|---|---|
| **EllesmereUI** | EllesmereUI style (background, border, title bar with centered title, inner frames, close buttons, including the close button of the floating team bar) following your theme. Can be turned off in EllesmereUI > Blizz UI Enhanced > Blizzard Window Skins > Third-Party Addons (requires the EllesmereUI Blizzard Skin module). |
| **ElvUI** | ElvUI style (background, inner frames and close buttons). |
| None | Generic dark background. |

If EllesmereUI and ElvUI are both loaded, EllesmereUI takes priority (unless you turned off the
Polypode skin in its options).

---

## Ideas for later

To turn on only if the need is confirmed (simplicity rule):

- **Account order**: choose the order of the WoW accounts in "Available characters" grouped by
  account (drag and drop of an account header, or an Alt + click menu on the header). In the
  meantime, prefix the names with a number ("1 main", "2 wow1"...), sorting being alphabetical.
- Re-announcing on joining a group, for characters with no shared guild logged in before being
  grouped.
- **Teams**: automatic conversion to raid.
- **Dungeon entry through the Group Finder** when the leader does it: not taken over, since it
  relies on functions protected by WoW whose behavior has not been checked in game.
- Automatic group invitation from the roster.
- Skinning the window's texts (EllesmereUI font).

---

## Languages

Polypode follows the game language: **French**, **English**, **German**, **Spanish**, **Italian**
or **Brazilian Portuguese** (Latin American Spanish uses Spanish; any other language uses English
until it gets its own translation). You can also choose its language regardless of the game's
(e.g. game in English, Polypode in French): **Langue / Language** option at the top of the options
panel, or `/poly language fr` (`en`, `de`, `es`, `it`, `pt`, `auto`), then `/reload`. The choice
applies to all your characters and to the companion addons. Names given by the game (classes,
zones...) stay the client's. `/poly` commands keep their French names, with English aliases
(`/poly accounts`, `/poly remove-account`, `/poly language`); debug mode messages stay in French.

The translations were made with the help of Claude (Anthropic's AI). If you are a native speaker
and something reads oddly, please [open an issue](https://github.com/Baktov/polypode/issues):
corrections are very welcome.

---

## Versions

The full version history is in the [French README](README.md#version).
