-- Polypode: Commands — commandes slash /polypode et /poly, keybindings globaux

local P = Polypode

local function PrintHelp()
	print("|cff33ff99Polypode|r — commandes :")
	print("  /poly list         — lister les personnages connus")
	print("  /poly addme        — ajouter le personnage courant au roster")
	print("  /poly remove <nom-royaume> — retirer un personnage du roster")
	print("  /poly ui           — ouvrir/fermer la fenêtre")
	print("  /poly minimap      — afficher/masquer l'icône de minimap")
	print("  /poly options      — ouvrir le panneau d'options")
	print("  /poly debug        — activer/désactiver le mode debug")
end

local function SlashHandler(msg)
	local args = {}
	for word in msg:gmatch("%S+") do
		table.insert(args, word)
	end
	local sub = (args[1] or ""):lower()

	if sub == "list" then
		local roster = P.GetRoster()
		local count = 0
		for key, entry in pairs(roster) do
			count = count + 1
			print(string.format("  - %s (%s, niv. %s)", key, entry.class or "?", entry.level or "?"))
		end
		if count == 0 then
			print("  Aucun personnage enregistré. Utilisez /poly addme")
		end
	elseif sub == "addme" then
		local key = P.AddCharacter()
		P.SayHello()
		print("Polypode: " .. key .. " ajouté au roster.")
	elseif sub == "remove" then
		local target = args[2]
		if target then
			if P.RemoveCharacter(target) then
				P.RefreshUI()
				print("Polypode: " .. target .. " retiré du roster.")
			else
				print("Polypode: " .. target .. " absent du roster.")
			end
		else
			print("Usage: /poly remove <nom-royaume>")
		end
	elseif sub == "ui" then
		P.ToggleUI()
	elseif sub == "minimap" then
		local show = P.db.minimap.hide
		P.SetMinimapButtonShown(show)
		print("Polypode: icône de minimap " .. (show and "affichée" or "masquée"))
	elseif sub == "options" then
		P.OpenOptions()
	elseif sub == "debug" then
		P.SetDebug(not P.debugEnabled)
		print("Polypode: debug " .. (P.debugEnabled and "activé" or "désactivé"))
	else
		PrintHelp()
	end
end

SLASH_POLYPODE1 = "/polypode"
SLASH_POLYPODE2 = "/poly"
SlashCmdList["POLYPODE"] = SlashHandler

-- Messages à l'écran (centre) : erreur en rouge, information en jaune.
local function ShowError(message)
	UIErrorsFrame:AddMessage(message, 1, 0.1, 0.1)
end

local function ShowInfo(message)
	UIErrorsFrame:AddMessage(message, 1, 0.82, 0)
end

-- Invite l'équipe sélectionnée et la synchronise (sélection chez les autres Polypode).
-- Action commune au bouton « Inviter l'équipe » et au raccourci clavier.
function P.InviteSelectedTeam()
	local team = P.GetSelectedTeam()
	local reason = P.GetInviteBlockedReason(team)
	if reason then
		ShowError(reason)
		return
	end
	local ok, message = P.InviteTeam(team)
	if ok then
		ShowInfo(message)
	else
		ShowError(message)
	end
	-- Dans tous les cas, partage l'équipe avec les Polypode des membres (et des clients
	-- connectés), qui la sélectionnent.
	P.SyncTeam(team, nil, true)
end

-- Fonctions globales des raccourcis clavier (Bindings.xml), noms imposés par l'API WoW.

function POLYPODE_TOGGLEUI()
	P.ToggleUI()
end

-- Se nommer leader de l'équipe sélectionnée (en y entrant si besoin).
function POLYPODE_SETLEADER()
	local team = P.GetSelectedTeam()
	if not team then
		ShowError("Polypode : aucune équipe sélectionnée.")
		return
	end
	local key = P.GetCharKey()
	P.AddTeamMember(team, key)
	P.SetTeamLeader(team, key)
	P.RefreshUI()
	ShowInfo("Vous êtes le leader de l'équipe « " .. team .. " ».")
end

-- Suivre / Assister : la touche est normalement redirigée vers un bouton sécurisé
-- (UI_Keybinds.lua) et ces fonctions ne sont pas appelées. Elles ne servent que si la
-- redirection n'est pas encore en place (ex. touche choisie pendant un combat).
function POLYPODE_FOLLOW()
	P.UpdateLeaderMacros()
	ShowError("Polypode : raccourci en cours d'activation, appuyez de nouveau (hors combat).")
end

function POLYPODE_ASSIST()
	POLYPODE_FOLLOW()
end

function POLYPODE_INVITE()
	P.InviteSelectedTeam()
end

-- Son de l'équipe, piloté par le leader (Sound.lua).
function POLYPODE_SENDVOLUME()
	P.SendTeamVolume()
end

function POLYPODE_TOGGLESOUND()
	P.ToggleTeamSound()
end
