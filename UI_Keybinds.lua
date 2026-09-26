-- Polypode: UI_Keybinds — boutons sécurisés des raccourcis « Suivre / Assister le leader »

local P = Polypode

-- Suivre et assister sont des actions protégées : un addon ne peut pas les déclencher
-- lui-même. Chaque raccourci est donc redirigé (SetOverrideBindingClick) vers un bouton
-- sécurisé Blizzard qui exécute une macro (/follow, /assist) : la touche reste une vraie
-- frappe clavier, sans code addon dans la chaîne (pas de taint), y compris en combat.
-- Seule la mise à jour de ces boutons (macro, touches) est interdite en combat : elle est
-- alors différée à la sortie du combat (P.ApplyPendingKeybinds sur PLAYER_REGEN_ENABLED).

-- Bouton sécurisé exécutant une macro. Enregistré pour l'appui ET le relâchement : le
-- modèle Blizzard n'agit qu'au moment choisi par le réglage ActionButtonUseKeyDown.
local function CreateSecureMacroButton(name)
	local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
	button:SetAttribute("type", "macro")
	button:SetAttribute("macrotext", "")
	button:RegisterForClicks("AnyUp", "AnyDown")
	-- Après la macro (hors contexte sécurisé) : message si le raccourci est sans effet.
	button:SetScript("PostClick", function(self, _, down)
		if down and self.problem then
			UIErrorsFrame:AddMessage(self.problem, 1, 0.1, 0.1)
		end
	end)
	return button
end

-- Raccourci (nom du binding) -> bouton sécurisé et macro à partir du nom du leader.
local secureBindings = {
	POLYPODE_FOLLOW = {
		button = CreateSecureMacroButton("PolypodeFollowButton"),
		macro = function(leaderName)
			return "/follow " .. leaderName
		end,
	},
	POLYPODE_ASSIST = {
		button = CreateSecureMacroButton("PolypodeAssistButton"),
		macro = function(leaderName)
			-- /startattack : attaque automatique si la cible est hostile (option par personnage).
			if P.charDb.assistStartAttack then
				return "/assist " .. leaderName .. "\n/startattack"
			end
			return "/assist " .. leaderName
		end,
	},
}
P.ui.followButton = secureBindings.POLYPODE_FOLLOW.button
P.ui.assistButton = secureBindings.POLYPODE_ASSIST.button

local pendingUpdate = false -- mise à jour demandée pendant un combat

-- Redirige les touches choisies dans le panneau Raccourcis vers les boutons sécurisés.
-- Ne refait rien si les touches n'ont pas changé : poser une redirection peut déclencher
-- UPDATE_BINDINGS, qui rappelle cette fonction.
local function RefreshOverrideBindings()
	for action, binding in pairs(secureBindings) do
		local key1, key2 = GetBindingKey(action)
		local keys = (key1 or "") .. "|" .. (key2 or "")
		if keys ~= binding.keys then
			binding.keys = keys
			ClearOverrideBindings(binding.button)
			for _, key in ipairs({ key1, key2 }) do
				SetOverrideBindingClick(binding.button, true, key, binding.button:GetName())
			end
		end
	end
end

-- Met à jour les macros selon le leader de l'équipe sélectionnée pour ce personnage.
local function RefreshMacros()
	local team = P.GetSelectedTeam()
	local leader = team and P.GetTeamLeader(team)
	local problem, leaderName
	if not team then
		problem = "Polypode : aucune équipe sélectionnée."
	elseif not leader then
		problem = "Polypode : l'équipe « " .. team .. " » n'a pas de leader."
	elseif leader == P.GetCharKey() then
		problem = "Polypode : vous êtes le leader de l'équipe « " .. team .. " »."
	else
		local entry = P.GetCharacter(leader)
		if entry then
			leaderName = P.GetTargetName(entry)
		else
			local name, realm = strsplit("-", leader, 2)
			leaderName = P.GetTargetName({ name = name, realm = realm or "" })
		end
	end

	for _, binding in pairs(secureBindings) do
		binding.button:SetAttribute("macrotext", leaderName and binding.macro(leaderName) or "")
		binding.button.problem = problem
	end
end

-- Met à jour macros et touches des raccourcis Suivre/Assister (hors combat, sinon différé).
function P.UpdateLeaderMacros()
	if InCombatLockdown() then
		pendingUpdate = true
		return
	end
	pendingUpdate = false
	RefreshMacros()
	RefreshOverrideBindings()
end

-- Sortie de combat (Events.lua) : applique une mise à jour différée.
function P.ApplyPendingKeybinds()
	if pendingUpdate then
		P.UpdateLeaderMacros()
	end
end
