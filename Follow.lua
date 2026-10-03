-- Polypode: Follow — alerte du leader quand un membre ne le suit plus, qui suit qui dans le groupe
-- (raccourcis « Barbare » et « Train »)

local P = Polypode

-- Membre : le suivi automatique (/follow, raccourci « Suivre le leader ») commence avec
-- AUTOFOLLOW_BEGIN (nom suivi) et s'arrête avec AUTOFOLLOW_END (obstacle, saut, distance,
-- mouvement manuel...). S'il suivait le leader de son équipe sélectionnée et que le suivi n'a
-- pas repris 0,5 s après (relance de /follow pendant un suivi), il le lui dit :
--   FOLLOWEND:token:nom-royaume — chuchotement au leader.
-- Leader : affiche « X ne vous suit plus. » à l'écran avec un son d'alerte, si X est membre
-- de son équipe sélectionnée. Option P.charDb.followAlert (par personnage), à cocher sur le
-- leader et les membres.

local ALERT_DEDUP = 3 -- secondes entre deux alertes pour un même membre
local END_CONFIRM_DELAY = 0.5 -- secondes sans reprise du suivi avant de signaler son arrêt

local followedName -- membre : nom suivi (AUTOFOLLOW_BEGIN), jusqu'à AUTOFOLLOW_END
local lastAlert = {} -- leader : [clé] = GetTime() de la dernière alerte

local function IsEnabled()
	return P.charDb and P.charDb.followAlert
end

-- Entrée de roster du leader de l'équipe sélectionnée, s'il n'est pas soi-même.
local function LeaderEntry()
	local leader = P.GetTeamLeader(P.GetSelectedTeam())
	if leader and leader ~= P.GetCharKey() then
		return P.GetCharacter(leader)
	end
end

-- QUI SUIT QUI (raccourcis « Barbare » et « Train », UI_Keybinds.lua) ---------------------
-- Chaque client annonce au groupe/raid le joueur qu'il suit, et l'arrêt de son suivi :
--   FOLLOWING:token:nom-royaume:nom-royaumeSuivi — suivi vide = ne suit plus personne.
-- Gardé en mémoire (session) ; un client qui rejoint le groupe ne connaît que les suivis
-- annoncés depuis (chacun réannonce le sien quand le groupe s'agrandit).

local MAX_CHAIN = 40 -- longueur maximale d'une file de suivi parcourue (taille d'un raid)

local followState = {} -- [clé normalisée du suiveur] = clé normalisée du joueur suivi
local lastGroupSize = 0

-- Clé « Nom-Royaume » sans espaces ni tirets dans le royaume (le royaume de UnitName n'en a pas).
local function NormalizeKey(key)
	local name, realm = strsplit("-", key, 2)
	return name .. "-" .. ((realm or GetRealmName()):gsub("[%s%-]", ""))
end

local function OwnKey()
	return NormalizeKey(P.GetCharKey())
end

-- Autres joueurs connectés du groupe : liste de { unit, key, name }. Un nom rendu secret par
-- WoW (issecretvalue) est ignoré.
local function GroupMembers()
	local members = {}
	local prefix, count = "party", GetNumSubgroupMembers()
	if IsInRaid() then
		prefix, count = "raid", GetNumGroupMembers()
	end
	for i = 1, count do
		local unit = prefix .. i
		if not UnitIsUnit(unit, "player") and UnitIsConnected(unit) then
			local name, realm = P.UnitNameParts(unit)
			if name and not (issecretvalue and (issecretvalue(name) or issecretvalue(realm))) then
				members[#members + 1] = { unit = unit, name = name, key = NormalizeKey(realm and name .. "-" .. realm or name) }
			end
		end
	end
	return members
end

-- Clés des joueurs atteints en remontant la file de suivi depuis key (key compris).
local function Chain(key)
	local reached = {}
	for _ = 1, MAX_CHAIN do
		if not key or reached[key] then
			break
		end
		reached[key] = true
		key = followState[key]
	end
	return reached
end

-- Annonce au groupe le joueur suivi par ce personnage (nil = plus aucun).
local function SetOwnFollow(key)
	local own = OwnKey()
	if followState[own] == key then
		return
	end
	followState[own] = key
	local token = P.GetTeamToken()
	if token and IsInGroup() then
		P.Broadcast("FOLLOWING:" .. token .. ":" .. P.GetCharKey() .. ":" .. (key or ""), IsInRaid() and "RAID" or "PARTY")
	end
	P.UpdateLeaderMacros()
end

-- Réception de FOLLOWING (Sync.lua, expéditeur vérifié).
function P.OnFollowingMessage(followerKey, followedKey)
	followState[NormalizeKey(followerKey)] = followedKey and followedKey ~= "" and NormalizeKey(followedKey) or nil
	P.UpdateLeaderMacros()
end

-- Changement du groupe (Events.lua) : macros des raccourcis à recalculer ; si le groupe
-- s'agrandit, réannonce son propre suivi aux nouveaux venus.
function P.OnFollowRosterUpdate()
	local size = GetNumGroupMembers()
	local own = followState[OwnKey()]
	if size > lastGroupSize and own then
		local token = P.GetTeamToken()
		if token then
			P.Broadcast("FOLLOWING:" .. token .. ":" .. P.GetCharKey() .. ":" .. own, IsInRaid() and "RAID" or "PARTY")
		end
	end
	lastGroupSize = size
	P.UpdateLeaderMacros()
end

-- Barbare : unité d'un autre joueur du groupe tiré au hasard (autre que celui déjà suivi s'il y
-- a le choix). Renvoie unité, ou nil et le message d'erreur.
function P.GetBarbareFollowUnit()
	local members = GroupMembers()
	if #members == 0 then
		return nil, "Polypode : aucun autre joueur connecté dans le groupe."
	end
	local current = followState[OwnKey()]
	local choices = {}
	for _, member in ipairs(members) do
		if member.key ~= current then
			choices[#choices + 1] = member
		end
	end
	if #choices == 0 then
		choices = members
	end
	return choices[math.random(#choices)].unit
end

-- Train : unité d'un joueur du groupe que personne d'autre ne suit, et qui ne nous suit pas
-- (même indirectement : pas de boucle). De préférence la queue de la file du leader de
-- l'équipe sélectionnée, sinon au hasard. Renvoie unité, ou nil et le message d'erreur.
function P.GetTrainFollowUnit()
	local members = GroupMembers()
	if #members == 0 then
		return nil, "Polypode : aucun autre joueur connecté dans le groupe."
	end
	local own = OwnKey()
	local inGroup = { [own] = true }
	for _, member in ipairs(members) do
		inGroup[member.key] = true
	end
	local followed = {}
	for follower, target in pairs(followState) do
		if follower ~= own and inGroup[follower] then
			followed[target] = true
		end
	end
	local leader = P.GetTeamLeader(P.GetSelectedTeam())
	leader = leader and NormalizeKey(leader)
	local choices, preferred = {}, {}
	for _, member in ipairs(members) do
		local chain = Chain(member.key)
		if not followed[member.key] and not chain[own] then
			choices[#choices + 1] = member
			if leader and chain[leader] then
				preferred[#preferred + 1] = member
			end
		end
	end
	if #choices == 0 then
		return nil, "Polypode : tous les joueurs du groupe sont déjà suivis."
	end
	local pool = #preferred > 0 and preferred or choices
	return pool[math.random(#pool)].unit
end

-- Clé normalisée du joueur du groupe dont le nom (AUTOFOLLOW_BEGIN, avec ou sans royaume ni
-- nom de famille) a ce prénom.
local function GroupKeyByName(name)
	local first = name and name:match("^[^%s%-]+")
	for _, member in ipairs(GroupMembers()) do
		if member.name == first then
			return member.key
		end
	end
end

-- MEMBRE (Events.lua) -------------------------------------------------------------------

function P.OnFollowEvent(event, name)
	if event == "AUTOFOLLOW_BEGIN" then
		followedName = name
		SetOwnFollow(GroupKeyByName(name))
		return
	end
	-- AUTOFOLLOW_END : annoncé seulement si le suivi n'a pas repris (cf. plus bas).
	C_Timer.After(END_CONFIRM_DELAY, function()
		if not followedName then
			SetOwnFollow(nil)
		end
	end)
	local followed = followedName
	followedName = nil
	local entry = LeaderEntry()
	if not IsEnabled() or not followed or not entry or not entry.name then
		return
	end
	-- Nom suivi, avec ou sans royaume ni nom de famille (Forever) selon WoW : comparé sur le
	-- seul prénom.
	if followed:match("^[^%s%-]+") ~= entry.name then
		return
	end
	-- Relancer /follow alors qu'on suit déjà (raccourci « Suivre le leader ») produit
	-- AUTOFOLLOW_END suivi aussitôt d'AUTOFOLLOW_BEGIN : l'arrêt n'est signalé que si le suivi
	-- n'a pas repris après END_CONFIRM_DELAY.
	C_Timer.After(END_CONFIRM_DELAY, function()
		local token = P.GetTeamToken()
		if followedName or not token then
			return
		end
		P.Broadcast("FOLLOWEND:" .. token .. ":" .. P.GetCharKey(), "WHISPER", P.GetTargetName(entry))
		P.Debug("Fin du suivi de " .. entry.name .. " signalée au leader")
	end)
end

-- LEADER --------------------------------------------------------------------------------

-- Réception de FOLLOWEND (Sync.lua, expéditeur vérifié) : alerte si key est membre de
-- l'équipe dont on est le leader.
function P.OnFollowEndMessage(key)
	if not IsEnabled() or not P.IsTeamLeader() then
		return
	end
	local members = P.GetTeamMembers(P.GetSelectedTeam())
	local entry = P.GetCharacter(key)
	if not members or not members[key] or not entry then
		return
	end
	local now = GetTime()
	if lastAlert[key] and now - lastAlert[key] < ALERT_DEDUP then
		return
	end
	lastAlert[key] = now
	UIErrorsFrame:AddMessage(P.GetDisplayName(key) .. " ne vous suit plus.", 1, 0.5, 0)
	PlaySound(SOUNDKIT.RAID_WARNING)
end
