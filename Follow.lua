-- Polypode: Follow — alerte du leader quand un membre ne le suit plus

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

-- MEMBRE (Events.lua) -------------------------------------------------------------------

function P.OnFollowEvent(event, name)
	if event == "AUTOFOLLOW_BEGIN" then
		followedName = name
		return
	end
	-- AUTOFOLLOW_END
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
