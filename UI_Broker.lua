-- Polypode: UI_Broker — sources LibDataBroker (équipe, modules, raccourci par module) pour les barres de données

local P = Polypode
local L = P.L

-- Sources LibDataBroker-1.1 lues par les barres de données (EllesmereUI DataBars « Broker
-- Plugin », ElvUI, Titan Panel, ChocolateBar, Bazooka...). Pas de librairie embarquée : la
-- bibliothèque est prise si un autre addon l'a chargée (LibStub), sinon rien n'est créé. Tout est
-- inscrit à PLAYER_LOGIN (tous les addons chargés), les modules ajoutés plus tard suivent.
--   « Polypode Team » : équipe sélectionnée, connectés / membres et leader (couronne) ; en mode
--     solo, le personnage joué (même source : la barre n'est pas à reconfigurer). Infobulle :
--     membres, état, niveau, zone. Clic gauche = inviter l'équipe (solo : fenêtre), clic droit =
--     fenêtre, Maj + clic = barre flottante.
--   « Polypode Modules » : nombre de modules ; clic = menu pour en ouvrir un, clic droit = menu
--     de leurs options (spec.rightClick).
--   « Polypode <module> » (launcher) : un par bouton de module (P.AddTitleButton), même clic.
-- Les noms des sources sont fixes (indépendants de la langue) : les barres les enregistrent.

local REFRESH_DELAY = 0.2 -- secondes : rafraîchissements regroupés
local HEARTBEAT = 5 -- secondes : connexions et zones des membres revues
local LEADER_ICON = "|A:groupfinder-icon-leader:12:12|a"

local LDB
local teamObject, modulesObject
local launchers = {} -- [spec] = objet

local function ClassColored(key, text)
	local entry = P.GetCharacter(key)
	local color = entry and entry.class and C_ClassColor and C_ClassColor.GetClassColor(entry.class)
	return color and color:WrapTextInColorCode(text) or text
end

local function IsGamepad()
	return P.IsGamepadUI and P.IsGamepadUI()
end

-- ÉQUIPE ---------------------------------------------------------------------------------------

local function TeamText()
	if P.IsSoloMode() then
		local key = P.GetCharKey()
		return ClassColored(key, P.GetDisplayName(key))
	end
	local team = P.GetSelectedTeam()
	if not team then
		return "|cff999999" .. L["Aucune équipe"] .. "|r"
	end
	local members = P.GetTeamMembers(team) or {}
	local total, online = 0, 0
	for key in pairs(members) do
		total = total + 1
		if P.IsCharacterConnected(key) then
			online = online + 1
		end
	end
	local text = string.format("%s %d/%d", team, online, total)
	local leader = P.GetTeamLeader(team)
	if leader then
		text = text .. "  " .. LEADER_ICON .. ClassColored(leader, P.GetDisplayName(leader))
	end
	return text
end

-- Ligne d'un personnage : nom (couronne du leader), puis niveau et zone, ou « hors ligne ».
local function AddMemberLine(tooltip, key, isLeader)
	local name = ClassColored(key, P.GetDisplayName(key))
	if isLeader then
		name = LEADER_ICON .. name
	end
	local right
	if P.IsCharacterConnected(key) then
		local status = P.GetCharacterStatus(key)
		local parts = {}
		if status and status.level then
			parts[#parts + 1] = L["Niveau %s"]:format(status.level)
		end
		if status and status.zone and status.zone ~= "" then
			parts[#parts + 1] = status.zone
		end
		right = table.concat(parts, " · ")
	else
		right = "|cff999999" .. L["hors ligne"] .. "|r"
	end
	tooltip:AddDoubleLine(name, right, 1, 1, 1, 1, 1, 1)
end

local function TeamTooltip(tooltip)
	local solo = P.IsSoloMode()
	if solo then
		tooltip:AddLine("Polypode |cffff4040" .. L["(mode solo)"] .. "|r")
		AddMemberLine(tooltip, P.GetCharKey(), false)
	else
		local team = P.GetSelectedTeam()
		tooltip:AddLine("Polypode : " .. (team or L["Aucune équipe"]))
		local members = team and P.GetTeamMembers(team) or {}
		local leader = team and P.GetTeamLeader(team)
		local items = P.SortedKeyItems(members, function(key)
			return key == leader
		end)
		if #items == 0 then
			tooltip:AddLine(L["Aucun personnage dans l'équipe"], 0.6, 0.6, 0.6)
		end
		for _, item in ipairs(items) do
			AddMemberLine(tooltip, item.key, item.key == leader)
		end
		local reason = team and P.GetInviteBlockedReason and P.GetInviteBlockedReason(team)
		if reason then
			tooltip:AddLine(reason, 1, 0.1, 0.1, true)
		end
	end
	tooltip:AddLine(" ")
	local lines = solo and { L["Clic : ouvrir / fermer la fenêtre Polypode"] }
		or { L["Clic gauche : inviter l'équipe (comme le bouton « Inviter l'équipe »)"],
			L["Clic droit : ouvrir / fermer la fenêtre Polypode"] }
	lines[#lines + 1] = L["Maj + clic : afficher / masquer la barre flottante"]
	for _, line in ipairs(lines) do
		tooltip:AddLine(P.ColorClicks(line), 1, 1, 1, true)
	end
end

local function TeamClick(_, mouseButton)
	if IsShiftKeyDown() then
		if P.IsTeamBarShown() then
			P.SetTeamBarShown(false)
		else
			P.SetTeamBarShown(true) -- refusé (message) si le personnage n'est pas dans l'équipe
		end
	elseif mouseButton == "RightButton" or P.IsSoloMode() then
		P.ToggleUI()
	else
		P.InviteSelectedTeam()
	end
end

-- MODULES --------------------------------------------------------------------------------------

local function ShownSpecs()
	local list = {}
	for _, spec in ipairs(P.OrderedButtonSpecs(P.GetWindowButtonOrder())) do
		if P.IsTitleButtonShown(spec) then
			list[#list + 1] = spec
		end
	end
	return list
end

-- Menu des modules : ouvrir (clic gauche) ou leurs options (clic droit, modules qui en ont).
local function ShowModulesMenu(owner, mouseButton)
	if not MenuUtil then
		return
	end
	local options = mouseButton == "RightButton"
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(options and L["Options d'un module"] or L["Ouvrir un module"])
		local any = false
		for _, spec in ipairs(ShownSpecs()) do
			if not options or spec.rightClick then
				root:CreateButton(spec.text, function()
					spec.onClick(owner, options and "RightButton" or "LeftButton")
				end)
				any = true
			end
		end
		if not any then
			root:CreateTitle(L["Aucun module installé"])
		end
	end)
end

local function ModulesTooltip(tooltip)
	tooltip:AddLine(L["Modules Polypode"])
	local specs = ShownSpecs()
	for _, spec in ipairs(specs) do
		tooltip:AddLine(spec.text, 1, 1, 1)
	end
	if #specs == 0 then
		tooltip:AddLine(L["Aucun module installé"], 0.6, 0.6, 0.6)
	end
	tooltip:AddLine(" ")
	tooltip:AddLine(P.ColorClicks(L["Clic : choisir un module à ouvrir"]), 1, 1, 1)
	tooltip:AddLine(P.ColorClicks(L["Clic droit : options d'un module"]), 1, 1, 1)
end

-- RACCOURCIS PAR MODULE ------------------------------------------------------------------------

-- Dossier de l'addon d'un bouton (clé « Polypode_Suivi2 » → « Polypode_Suivi »), pour son icône.
local function ModuleAddon(spec)
	return (spec.moduleKey or ""):gsub("%d+$", "")
end

local function ModuleIcon(spec)
	local addon = ModuleAddon(spec)
	local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
	local icon = getMetadata and addon ~= "" and getMetadata(addon, "IconTexture")
	return icon or P.ICON
end

local function AddLauncher(spec)
	if launchers[spec] or not (LDB and spec.moduleKey and spec.onClick) then
		return
	end
	local name = "Polypode " .. spec.moduleKey:gsub("^Polypode_", "")
	launchers[spec] = LDB:NewDataObject(name, {
		type = "launcher",
		label = "Polypode " .. (spec.text or spec.moduleKey),
		icon = ModuleIcon(spec),
		OnClick = function(frame, mouseButton)
			spec.onClick(frame, mouseButton)
		end,
		OnTooltipShow = function(tooltip)
			for index, line in ipairs(P.TitleButtonTooltip(spec)) do
				if type(line) == "table" then
					tooltip:AddDoubleLine(line[1], line[2], 1, 1, 1, 1, 1, 1)
				elseif index == 1 then
					tooltip:AddLine(line)
				else
					tooltip:AddLine(P.ColorClicks(line), 1, 1, 1, true)
				end
			end
		end,
	})
end

-- MISE À JOUR ----------------------------------------------------------------------------------

local function Refresh()
	if teamObject then
		teamObject.text = TeamText()
	end
	if modulesObject then
		modulesObject.text = L["Modules (%d)"]:format(#ShownSpecs())
	end
end

local refreshPending = false
local function RefreshSoon()
	if refreshPending or not teamObject then
		return
	end
	refreshPending = true
	C_Timer.After(REFRESH_DELAY, function()
		refreshPending = false
		Refresh()
	end)
end
P.RefreshBrokers = RefreshSoon

local function Register()
	LDB = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
	if not LDB or teamObject then
		return
	end
	teamObject = LDB:NewDataObject("Polypode Team", {
		type = "data source",
		label = L["Équipe Polypode"],
		icon = P.ICON,
		text = "",
		OnClick = TeamClick,
		OnTooltipShow = TeamTooltip,
	})
	modulesObject = LDB:NewDataObject("Polypode Modules", {
		type = "data source",
		label = L["Modules Polypode"],
		icon = P.ICON,
		text = "",
		OnClick = ShowModulesMenu,
		OnTooltipShow = ModulesTooltip,
	})
	for _, spec in ipairs(P.GetTitleButtonSpecs()) do
		AddLauncher(spec)
	end
	-- Module ajouté après coup : son raccourci, et le compte des modules.
	hooksecurefunc(P, "AddTitleButton", function(spec)
		AddLauncher(spec)
		RefreshSoon()
	end)
	hooksecurefunc(P, "RefreshUI", RefreshSoon) -- équipe, roster, mode solo
	if P.RefreshTeamBar then
		hooksecurefunc(P, "RefreshTeamBar", RefreshSoon) -- états reçus des membres
	end
	C_Timer.NewTicker(HEARTBEAT, Refresh)
	Refresh()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
	C_Timer.After(0, Register) -- après les PLAYER_LOGIN des modules et des barres
end)
