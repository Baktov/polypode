-- Polypode: AutoGroup — groupage automatique de l'équipe à la connexion de ses personnages

local P = Polypode

-- Option P.charDb.autoGroup, par personnage, des deux côtés.
-- Leader : quand un personnage s'annonce (HELLO à sa connexion, ou HI en réponse à la
--   connexion du leader, cf. Sync.lua), s'il est membre de l'équipe sélectionnée du leader et
--   pas encore dans son groupe, le leader l'invite (même règles que « Inviter l'équipe » :
--   seul ou chef du groupe / assistant en raid, 5 au plus hors raid).
-- Membre : une invitation de groupe venant du leader d'une équipe dont il est membre est
--   acceptée (AcceptGroup), puis la fenêtre d'invitation est fermée au GROUP_ROSTER_UPDATE
--   suivant (même méthode qu'EllesmereUIFriends).
-- Les annonces HELLO/HI passent par le canal dédié, sinon le groupe, le raid ou la guilde : un
-- personnage connecté hors de tous ces canaux n'est pas vu, donc pas invité.

local INVITE_DELAY = 1 -- secondes avant d'inviter (le client qui se connecte finit de charger)
local INVITE_DEDUP = 10 -- secondes : un même personnage n'est pas réinvité avant ce délai

local lastInvite = {} -- leader : [clé] = GetTime() de la dernière invitation automatique
local hideInvitePopup = false -- membre : fenêtre d'invitation à fermer après acceptation

local function IsEnabled()
	return P.charDb and P.charDb.autoGroup
end

-- Nom complet "Nom-Royaume" (royaume sous forme courte), pour comparer deux noms.
local function FullName(name)
	if not name:find("-", 1, true) then
		return name .. "-" .. (GetNormalizedRealmName() or "")
	end
	return name
end

-- Nom complet d'une clé de roster "Nom-Royaume".
local function FullNameOfKey(key)
	local name, realm = strsplit("-", key, 2)
	return FullName(P.GetTargetName({ name = name, realm = realm or "" }))
end

-- LEADER --------------------------------------------------------------------------------

-- Appelé par Sync.lua quand le personnage key s'annonce (HELLO ou HI).
function P.OnTeamCharacterOnline(key)
	if not IsEnabled() or not P.IsTeamLeader() then
		return
	end
	local team = P.GetSelectedTeam()
	local members = P.GetTeamMembers(team)
	local entry = P.GetCharacter(key)
	if not members or not members[key] or not entry or key == P.GetCharKey() then
		return
	end
	local now = GetTime()
	if lastInvite[key] and now - lastInvite[key] < INVITE_DEDUP then
		return
	end
	lastInvite[key] = now

	C_Timer.After(INVITE_DELAY, function()
		if P.IsEntryInGroup(entry) then
			return
		end
		local target = P.GetInviteName(entry)
		if IsInGroup() and not UnitIsGroupLeader("player")
			and not (IsInRaid() and UnitIsGroupAssistant("player")) then
			P.Debug("Groupage auto : " .. key .. " non invité, vous n'êtes pas chef du groupe")
			return
		end
		if not IsInRaid() and GetNumGroupMembers() >= 5 then
			P.Debug("Groupage auto : " .. key .. " non invité, groupe complet (convertir en raid)")
			return
		end
		C_PartyInfo.InviteUnit(target)
		P.Debug("Groupage auto : " .. key .. " invité dans l'équipe « " .. team .. " »")
	end)
end

-- MEMBRE --------------------------------------------------------------------------------

-- Vrai si inviterName désigne le personnage du roster key : « Nom-Royaume », ou sur WoW
-- Forever « Prénom Nom » (P.GetInviteName).
local function IsInviter(inviterName, key)
	local entry = P.GetCharacter(key)
	return FullNameOfKey(key) == FullName(inviterName)
		or (entry ~= nil and P.GetInviteName(entry) == inviterName)
end

-- Vrai si inviterName est le leader d'une équipe dont ce personnage est membre.
local function IsMyTeamLeader(inviterName)
	local me = P.GetCharKey()
	for teamName, team in pairs(P.GetTeams()) do
		local leader = team.leader
		if leader and leader ~= me and team.members and team.members[me]
			and IsInviter(inviterName, leader) then
			return true, teamName
		end
	end
	return false
end

-- Événements de groupe (Events.lua).
function P.OnGroupEvent(event, inviterName)
	if event == "PARTY_INVITE_REQUEST" then
		if not IsEnabled() or not inviterName or IsInGroup() then
			return
		end
		local isLeader, teamName = IsMyTeamLeader(inviterName)
		if isLeader then
			AcceptGroup()
			hideInvitePopup = true
			P.Debug("Groupage auto : invitation de " .. inviterName .. " acceptée (équipe « "
				.. teamName .. " »)")
		end
	elseif event == "GROUP_ROSTER_UPDATE" and hideInvitePopup then
		hideInvitePopup = false
		StaticPopup_Hide("PARTY_INVITE")
		if LFGInvitePopup then
			StaticPopupSpecial_Hide(LFGInvitePopup)
		end
	end
end
