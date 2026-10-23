-- Polypode: Commands — commandes slash /polypode et /poly, keybindings globaux

local P = Polypode
local L = P.L

-- Sous-commandes ajoutées par des addons compagnons (ex. Polypode Photo) :
-- [nom] = { handler = fn(args), help = texte }.
local extraCommands = {}

-- Alias anglais des sous-commandes françaises de Polypode.
local ALIASES = { accounts = "comptes", ["remove-account"] = "retirer-compte", language = "langue" }

-- Mots acceptés par /poly langue → préférence (P.LANGUAGES, Locale.lua).
local LANGUAGE_WORDS = {
	auto = "auto",
	fr = "frFR", frfr = "frFR", francais = "frFR", ["français"] = "frFR", french = "frFR",
	en = "enUS", enus = "enUS", anglais = "enUS", english = "enUS",
	de = "deDE", dede = "deDE", allemand = "deDE", deutsch = "deDE", german = "deDE",
	es = "esES", eses = "esES", espagnol = "esES", ["español"] = "esES", espanol = "esES", spanish = "esES",
}

-- Ajoute une sous-commande /poly <nom> ; handler reçoit les mots qui suivent ; help nil =
-- alias absent de l'aide. Point d'extension pour les addons qui dépendent de Polypode.
function P.RegisterSlashCommand(name, handler, help)
	extraCommands[name:lower()] = { handler = handler, help = help }
end

local function PrintHelp()
	print(L["|cff33ff99Polypode|r — commandes :"])
	print(L["  /poly list         — lister les personnages connus"])
	print(L["  /poly addme        — ajouter le personnage courant au roster"])
	print(L["  /poly remove <nom-royaume> — retirer un personnage du roster"])
	print(L["  /poly import       — importer une liste de personnages (copier/coller)"])
	print(L["  /poly ui           — ouvrir/fermer la fenêtre"])
	print(L["  /poly minimap      — afficher/masquer l'icône de minimap"])
	print(L["  /poly options      — ouvrir le panneau d'options"])
	print(L["  /poly comptes      — lister les autres comptes Battle.net autorisés"])
	print(L["  /poly retirer-compte <n°> — retirer l'autorisation d'un compte"])
	print(L["  /poly debug        — activer/désactiver le mode debug"])
	print("  /poly langue auto|fr|en|de|es — langue de Polypode / Polypode language (/reload)")
	for name, command in pairs(extraCommands) do
		if command.help then -- sans aide : alias (ex. « quêtes » pour « quetes »)
			print(string.format("  /poly %-12s — %s", name, command.help))
		end
	end
end

local function SlashHandler(msg)
	local args = {}
	for word in msg:gmatch("%S+") do
		table.insert(args, word)
	end
	local sub = (args[1] or ""):lower()
	sub = ALIASES[sub] or sub

	if sub == "list" then
		local roster = P.GetRoster()
		local count = 0
		for key, entry in pairs(roster) do
			count = count + 1
			print(L["  - %s (%s, niv. %s)"]:format(key, entry.class or "?", entry.level or "?"))
		end
		if count == 0 then
			print(L["  Aucun personnage enregistré. Utilisez /poly addme"])
		end
	elseif sub == "addme" then
		local key = P.AddCharacter()
		P.SayHello()
		print(L["Polypode : %s ajouté au roster."]:format(key))
	elseif sub == "remove" then
		local target = args[2]
		if target then
			if P.RemoveCharacter(target) then
				P.RefreshUI()
				print(L["Polypode : %s retiré du roster."]:format(target))
			else
				print(L["Polypode : %s absent du roster."]:format(target))
			end
		else
			print(L["Usage : /poly remove <nom-royaume>"])
		end
	elseif sub == "import" then
		P.ShowImportWindow()
	elseif sub == "ui" then
		P.ToggleUI()
	elseif sub == "minimap" then
		local show = P.db.minimap.hide
		P.SetMinimapButtonShown(show)
		print(show and L["Polypode : icône de minimap affichée."] or L["Polypode : icône de minimap masquée."])
	elseif sub == "options" then
		P.OpenOptions()
	elseif sub == "comptes" then
		local list = P.GetTrustedTokens()
		if #list == 0 then
			print(L["Polypode : aucun autre compte autorisé."])
		else
			print(L["Polypode : comptes autorisés (personnage vu à l'autorisation) :"])
			for i, account in ipairs(list) do
				print(string.format("  %d. %s", i, account.label))
			end
		end
	elseif sub == "retirer-compte" then
		local account = P.GetTrustedTokens()[tonumber(args[2] or "")]
		if account and P.UntrustToken(account.token) then
			print(L["Polypode : autorisation retirée pour le compte de %s."]:format(account.label))
		else
			print(L["Usage : /poly retirer-compte <n°> (numéro donné par /poly comptes)"])
		end
	elseif sub == "debug" then
		P.SetDebug(not P.debugEnabled)
		print(P.debugEnabled and L["Polypode : mode debug activé."] or L["Polypode : mode debug désactivé."])
	elseif sub == "langue" then
		-- Messages dans les deux langues : celui qui change de langue ne lit peut-être pas l'autre.
		local preference = LANGUAGE_WORDS[(args[2] or ""):lower()]
		if preference then
			P.SetLanguagePreference(preference)
		end
		print(string.format("Polypode : langue / language = %s (%s). /poly langue auto|fr|en|de|es, puis/then /reload",
			P.GetLanguagePreference(), P.GetLanguage()))
	elseif extraCommands[sub] then
		extraCommands[sub].handler({ select(2, unpack(args)) })
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
		ShowError(L["Polypode : aucune équipe sélectionnée."])
		return
	end
	local key = P.GetCharKey()
	P.AddTeamMember(team, key)
	P.SetTeamLeader(team, key)
	P.RefreshUI()
	ShowInfo(L["Vous êtes le leader de l'équipe « %s »."]:format(team))
end

-- Suivre / Assister / Barbare / Train : la touche est normalement redirigée vers un bouton sécurisé
-- (UI_Keybinds.lua) et ces fonctions ne sont pas appelées. Elles ne servent que si la
-- redirection n'est pas encore en place (ex. touche choisie pendant un combat).
function POLYPODE_FOLLOW()
	P.UpdateLeaderMacros()
	ShowError(L["Polypode : raccourci en cours d'activation, appuyez de nouveau (hors combat)."])
end

function POLYPODE_ASSIST()
	POLYPODE_FOLLOW()
end

function POLYPODE_BARBARE()
	POLYPODE_FOLLOW()
end

function POLYPODE_TRAIN()
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
