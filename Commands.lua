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
		P.debugEnabled = not P.debugEnabled
		print("Polypode: debug " .. (P.debugEnabled and "activé" or "désactivé"))
	else
		PrintHelp()
	end
end

SLASH_POLYPODE1 = "/polypode"
SLASH_POLYPODE2 = "/poly"
SlashCmdList["POLYPODE"] = SlashHandler

function POLYPODE_TOGGLEUI()
	P.ToggleUI()
end
