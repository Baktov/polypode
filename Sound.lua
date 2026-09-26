-- Polypode: Sound — volume et activation du son des membres, pilotés par le leader

local P = Polypode

-- Le leader de l'équipe sélectionnée envoie au groupe/raid (raccourcis clavier) :
--   VOLUME:token:pourcentage — volume principal (0 à 100), réglé par l'option « Volume
--     envoyé » (P.charDb.sentVolume) ;
--   SOUND:token:0|1 — coupe (0) ou rétablit (1) tout le son ; alterne à chaque appui.
-- Membres (option P.charDb.followLeaderSound, par personnage) : appliquent les réglages
-- Blizzard Sound_MasterVolume (0.0 à 1.0) et Sound_EnableAllSound (0/1), ceux des curseurs
-- et de la case « Activer le son » d'Options > Son. Le son du leader n'est pas modifié.
-- Sync.lua n'accepte ces messages que du leader de l'équipe sélectionnée.

local SEND_DEDUP = 0.2 -- secondes : évite un double envoi sur un même appui de touche

local teamSoundOn = true -- leader : dernier état envoyé (true = son rétabli), pour alterner

local function ShowError(message)
	UIErrorsFrame:AddMessage(message, 1, 0.1, 0.1)
end

local function ShowInfo(message)
	UIErrorsFrame:AddMessage(message, 1, 0.82, 0)
end

-- Raison pour laquelle ce personnage ne peut pas piloter le son de l'équipe, ou nil.
local function SendBlockedReason()
	if not P.GetSelectedTeam() then
		return "Polypode : aucune équipe sélectionnée."
	end
	if not P.IsTeamLeader() then
		return "Polypode : seul le leader de l'équipe pilote le son de l'équipe."
	end
	if not IsInGroup() then
		return "Polypode : l'équipe doit être groupée pour recevoir le son."
	end
end

-- LEADER (raccourcis clavier) ---------------------------------------------------------

-- Envoie le volume de l'option « Volume envoyé » aux autres membres.
function P.SendTeamVolume()
	local reason = SendBlockedReason()
	if reason then
		ShowError(reason)
		return
	end
	local percent = P.charDb.sentVolume
	P.BroadcastLeaderAction("VOLUME", tostring(percent), "VOLUME" .. percent, SEND_DEDUP, "raccourci")
	ShowInfo("Volume de l'équipe réglé à " .. percent .. " %.")
end

-- Coupe ou rétablit le son des autres membres (alterne à chaque appel).
function P.ToggleTeamSound()
	local reason = SendBlockedReason()
	if reason then
		ShowError(reason)
		return
	end
	teamSoundOn = not teamSoundOn
	local flag = teamSoundOn and "1" or "0"
	P.BroadcastLeaderAction("SOUND", flag, "SOUND" .. flag, SEND_DEDUP, "raccourci")
	ShowInfo(teamSoundOn and "Son de l'équipe rétabli." or "Son de l'équipe coupé.")
end

-- MEMBRES (Sync.lua) ------------------------------------------------------------------

local function IsFollowing()
	return P.charDb and P.charDb.followLeaderSound
end

-- Réception de VOLUME : pourcentage 0 à 100.
function P.OnVolumeMessage(percent, sender)
	if not IsFollowing() or not percent then
		return
	end
	percent = math.max(0, math.min(100, percent))
	SetCVar("Sound_MasterVolume", percent / 100)
	P.Debug("Volume principal réglé à " .. percent .. " % (leader " .. tostring(sender) .. ")")
end

-- Réception de SOUND : "1" rétablit, "0" coupe tout le son.
function P.OnSoundMessage(flag, sender)
	if not IsFollowing() or (flag ~= "0" and flag ~= "1") then
		return
	end
	SetCVar("Sound_EnableAllSound", flag)
	P.Debug("Son " .. (flag == "1" and "rétabli" or "coupé") .. " (leader " .. tostring(sender) .. ")")
end
