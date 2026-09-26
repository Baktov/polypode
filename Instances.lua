-- Polypode: Instances — entrée en gouffre / par portail et sortie de gouffre suivies du leader

local P = Polypode

-- Fonctionnement (repris de TeamManager, parties vérifiées en jeu), option
-- P.charDb.autoEnterInstance, par personnage, des deux côtés. Sync.lua n'accepte ces messages
-- que du leader de l'équipe sélectionnée.
--   DELVEENTER:token:palier — le leader choisit le palier d'un gouffre
--     (hook C_DelvesUI.SelectDelveEntranceTier). Membre : si sa fenêtre de choix du palier
--     (DelvesDifficultyPickerFrame) est ouverte, choisit le même palier. Sinon rien.
--   DELVEEXIT:token — le leader vote « Oui » pour quitter le gouffre
--     (hook C_PartyInfo.SetInstanceAbandonVoteResponse). Membre : vote « Oui » si un vote est
--     en cours ou dès qu'il apparaît (vérification toutes les 0,5 s pendant 30 s).
--   INSTENTER:token:portal — le leader confirme l'entrée par un portail d'instance
--     (hooks ConfirmEnterInstance et clic sur une fenêtre de confirmation d'instance hors
--     instance). Membre : confirme (ConfirmEnterInstance).
-- Non repris : l'entrée en donjon par le Chercheur de groupe et la confirmation de rôle, qui
-- reposent sur des fonctions protégées (AcceptProposal, LFGTeleport, AcceptRoleCheck) dont le
-- fonctionnement n'a pas été constaté dans TeamManager.

local ANNOUNCE_DEDUP = 5 -- secondes entre deux annonces identiques
local EXIT_POLL_INTERVAL = 0.5 -- secondes entre deux vérifications du vote de sortie
local EXIT_POLL_DURATION = 30 -- secondes d'attente du vote de sortie (membre)

local exitPendingUntil = 0 -- membre : vote de sortie à donner jusqu'à cette heure (GetTime)

local function IsEnabled()
	return P.charDb and P.charDb.autoEnterInstance
end

local function Announce(kind, fields, reason)
	if IsEnabled() then
		P.BroadcastLeaderAction(kind, fields, kind .. fields, ANNOUNCE_DEDUP, reason)
	end
end

-- ENTRÉE EN GOUFFRE -------------------------------------------------------------------

-- Réception de DELVEENTER (Sync.lua).
function P.OnDelveEnterMessage(tier, sender)
	if not IsEnabled() then
		return
	end
	tier = tier or 1
	if C_DelvesUI and C_DelvesUI.SelectDelveEntranceTier
		and DelvesDifficultyPickerFrame and DelvesDifficultyPickerFrame:IsShown() then
		C_Timer.After(0, function()
			C_DelvesUI.SelectDelveEntranceTier(tier)
		end)
		P.Debug("Gouffre : palier " .. tier .. " choisi (leader " .. tostring(sender) .. ")")
	else
		P.Debug("Gouffre : palier " .. tier .. " ignoré, fenêtre de choix fermée")
	end
end

-- SORTIE DE GOUFFRE -------------------------------------------------------------------

-- Temps restant du vote de sortie en cours (0 si aucun).
local function AbandonVoteTimeLeft()
	if C_PartyInfo and C_PartyInfo.GetInstanceAbandonVoteTime then
		local _, timeLeft = C_PartyInfo.GetInstanceAbandonVoteTime()
		return timeLeft or 0
	end
	return 0
end

-- Vote « Oui » si un vote de sortie est en cours. Renvoie true si le vote a été donné.
local function TryVoteExit()
	local popup = InstanceAbandonPopup
	if AbandonVoteTimeLeft() > 0 or (popup and popup:IsShown()) then
		C_PartyInfo.SetInstanceAbandonVoteResponse(true)
		P.Debug("Gouffre : vote de sortie « Oui » donné")
		return true
	end
	return false
end

local function PollExitVote()
	if GetTime() > exitPendingUntil then
		return
	end
	if TryVoteExit() then
		exitPendingUntil = 0
		return
	end
	C_Timer.After(EXIT_POLL_INTERVAL, PollExitVote)
end

-- Réception de DELVEEXIT (Sync.lua).
function P.OnDelveExitMessage(sender)
	if not IsEnabled() or not (C_PartyInfo and C_PartyInfo.SetInstanceAbandonVoteResponse) then
		return
	end
	P.Debug("Gouffre : sortie votée par le leader " .. tostring(sender))
	if not TryVoteExit() then
		-- Le vote n'est pas encore arrivé chez ce membre : on l'attend.
		local polling = GetTime() <= exitPendingUntil
		exitPendingUntil = GetTime() + EXIT_POLL_DURATION
		if not polling then
			C_Timer.After(EXIT_POLL_INTERVAL, PollExitVote)
		end
	end
end

-- PORTAIL D'INSTANCE ------------------------------------------------------------------

-- Réception de INSTENTER (Sync.lua) : kind = "portal".
function P.OnInstanceEnterMessage(kind, sender)
	if not IsEnabled() or kind ~= "portal" or not ConfirmEnterInstance then
		return
	end
	-- Fenêtre de confirmation d'entrée ouverte ? Sinon, tentative directe (comme TeamManager).
	local popupName
	for i = 1, 10 do
		local popup = _G["StaticPopup" .. i]
		local which = popup and popup:IsShown() and popup.which or ""
		if which:find("INSTANCE") or which:find("ENTER") or which:find("LOCK") then
			popupName = which
			break
		end
	end
	pcall(ConfirmEnterInstance)
	P.Debug("Portail : entrée confirmée (" .. (popupName or "sans fenêtre") .. ", leader "
		.. tostring(sender) .. ")")
end

-- HOOKS CÔTÉ LEADER -------------------------------------------------------------------
-- Un membre qui rejoue l'action déclenche aussi ces hooks, mais n'annonce rien
-- (P.BroadcastLeaderAction : leader seulement).

if C_DelvesUI and C_DelvesUI.SelectDelveEntranceTier then
	hooksecurefunc(C_DelvesUI, "SelectDelveEntranceTier", function(tier)
		Announce("DELVEENTER", tostring(tier or 1), "SelectDelveEntranceTier")
	end)
end

if C_PartyInfo and C_PartyInfo.SetInstanceAbandonVoteResponse then
	hooksecurefunc(C_PartyInfo, "SetInstanceAbandonVoteResponse", function(response)
		if response == true then
			Announce("DELVEEXIT", "", "vote de sortie")
		end
	end)
end

if ConfirmEnterInstance then
	hooksecurefunc("ConfirmEnterInstance", function()
		Announce("INSTENTER", "portal", "ConfirmEnterInstance")
	end)
end

-- Clic « Accepter » sur une fenêtre de confirmation d'entrée d'instance, hors instance.
if StaticPopup_OnClick then
	hooksecurefunc("StaticPopup_OnClick", function(popup, button)
		if button ~= 1 or IsInInstance() then
			return
		end
		local which = popup and popup.which or ""
		if which:find("INSTANCE") or which:find("LOCK") then
			Announce("INSTENTER", "portal", "fenêtre " .. which)
		end
	end)
end
