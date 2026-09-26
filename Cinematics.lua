-- Polypode: Cinematics — cinématiques passées par le leader, passées aussi par les membres

local P = Polypode

-- Fonctionnement (repris de TeamManager), option P.charDb.autoSkipCinematic, par personnage,
-- des deux côtés. Message CINESKIP:token:kind, kind = "cinematic" ou "movie".
-- Deux sortes de cinématiques, chacune avec ses API Blizzard (cf. wow-ui-source,
-- CinematicFrame.lua et MovieFrame.lua ; CancelCinematic et StopMovie n'existent pas) :
--   * cinématique du moteur ou scène : Échap → CinematicFrame_CancelCinematic() →
--     StopCinematic() (vraie cinématique) ou CancelScene() (scène) ;
--   * vidéo pré-rendue : Échap → MovieFrame:FinishMovie().
-- Leader : hooks StopCinematic, CinematicFrame_CancelCinematic (scènes seulement : les vraies
-- cinématiques passent déjà par StopCinematic) et MovieFrame:FinishMovie.
-- Membre : passe sa cinématique si elle est affichée ; sinon (latence, chargement) le passage
-- reste en attente 15 s, avec quelques nouvelles tentatives rapides, et s'applique dès
-- CINEMATIC_START / PLAY_MOVIE. La fenêtre « Passer la cinématique ? » restée ouverte est
-- refermée. Sync.lua n'accepte CINESKIP que du leader de l'équipe sélectionnée.

local PENDING_TTL = 15 -- secondes d'attente d'une cinématique à passer (membre)
local RETRY_DELAYS = { 0.2, 0.5, 1.0, 2.0 } -- nouvelles tentatives après réception
local START_DELAYS = { 0.05, 0.3 } -- tentatives après le démarrage de la cinématique
local ANNOUNCE_DEDUP = 2 -- secondes entre deux annonces du même type

local pendingKind -- membre : type de cinématique à passer dès qu'elle s'affiche
local pendingExpires = 0

local function IsEnabled()
	return P.charDb and P.charDb.autoSkipCinematic
end

-- Leader : annonce le passage d'une cinématique.
local function Announce(kind, reason)
	if IsEnabled() then
		P.BroadcastLeaderAction("CINESKIP", kind, "CINESKIP" .. kind, ANNOUNCE_DEDUP, reason)
	end
end

-- Ferme la fenêtre de confirmation « Passer la cinématique ? » si elle traîne.
local function DismissConfirm()
	if StaticPopup_Hide then
		StaticPopup_Hide("CONFIRM_STOP_CINEMATIC")
	end
	if CinematicFrame and CinematicFrame.closeDialog and CinematicFrame.closeDialog:IsShown() then
		CinematicFrame.closeDialog:Hide()
	end
	if MovieFrame and MovieFrame.CloseDialog and MovieFrame.CloseDialog:IsShown() then
		MovieFrame.CloseDialog:Hide()
	end
end

-- Membre : passe la cinématique si elle est affichée. Sinon, si allowPending, la met en
-- attente. Renvoie true si elle a été passée.
local function ApplySkip(kind, allowPending)
	local done = false
	if kind == "movie" then
		if MovieFrame and MovieFrame:IsShown() and MovieFrame.FinishMovie then
			DismissConfirm()
			MovieFrame:FinishMovie()
			done = true
		end
	elseif CinematicFrame and CinematicFrame:IsShown() then
		-- Pas de DismissConfirm ici : l'arrêt masque déjà la confirmation (enfant du cadre).
		if CinematicFrame.isRealCinematic then
			StopCinematic()
		elseif IsInCinematicScene and IsInCinematicScene() then
			if CanCancelScene and CanCancelScene() then
				CancelScene()
			end
		else
			StopCinematic()
		end
		done = true
	end

	if done then
		pendingKind, pendingExpires = nil, 0
		P.Debug("Cinématique passée (" .. kind .. ")")
	elseif allowPending then
		pendingKind, pendingExpires = kind, GetTime() + PENDING_TTL
		P.Debug("Cinématique à passer en attente (" .. kind .. ")")
		for _, delay in ipairs(RETRY_DELAYS) do
			C_Timer.After(delay, function()
				if pendingKind and GetTime() < pendingExpires then
					ApplySkip(pendingKind, false)
				end
			end)
		end
	end
	return done
end

-- Réception de CINESKIP (Sync.lua).
function P.OnCinematicSkipMessage(kind, sender)
	if not IsEnabled() then
		return
	end
	P.Debug("Cinématique passée par " .. tostring(sender))
	ApplySkip(kind == "movie" and "movie" or "cinematic", true)
end

-- Événements de cinématique (Events.lua).
function P.OnCinematicEvent(event)
	if event == "CINEMATIC_STOP" or event == "STOP_MOVIE" then
		DismissConfirm()
		return
	end
	-- CINEMATIC_START / PLAY_MOVIE : applique un passage en attente.
	if not IsEnabled() or not pendingKind then
		return
	end
	if GetTime() > pendingExpires then
		pendingKind, pendingExpires = nil, 0
		return
	end
	-- Le type réel est donné par l'événement ; petit délai pour laisser le cadre s'afficher.
	local kind = event == "PLAY_MOVIE" and "movie" or "cinematic"
	for _, delay in ipairs(START_DELAYS) do
		C_Timer.After(delay, function()
			ApplySkip(kind, false)
		end)
	end
end

-- Hooks côté leader. Un membre qui passe sa cinématique déclenche aussi ces hooks, mais
-- n'annonce rien (P.BroadcastLeaderAction : leader seulement).
if StopCinematic then
	hooksecurefunc("StopCinematic", function()
		Announce("cinematic", "StopCinematic")
	end)
end
if CinematicFrame_CancelCinematic then
	hooksecurefunc("CinematicFrame_CancelCinematic", function()
		if not (CinematicFrame and CinematicFrame.isRealCinematic) then
			Announce("cinematic", "CinematicFrame_CancelCinematic (scène)")
		end
	end)
end
if MovieFrame and MovieFrame.FinishMovie then
	hooksecurefunc(MovieFrame, "FinishMovie", function()
		Announce("movie", "MovieFrame:FinishMovie")
	end)
end
