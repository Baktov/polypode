-- Polypode: UI_Duplicates — fusion des fiches en double d'un même personnage

local P = Polypode
local L = P.L

-- À la connexion (P.CheckDuplicatesAtLogin, Events.lua) : chaque groupe de doublons probables
-- (P.GetDuplicateGroups, Core.lua) non refusé est proposé, l'un après l'autre, dans une fenêtre
-- Oui / Non, la fenêtre Polypode ouverte derrière. Oui : les autres fiches sont fusionnées dans la
-- fiche gardée (P.DefaultMergeKeep). Non : le groupe n'est plus proposé à la connexion
-- (P.IgnoreDuplicateGroup). Dans « Personnages disponibles », une icône devant chaque fiche d'un
-- groupe (refusé ou non) ouvre le menu de fusion manuelle (P.ShowMergeMenu), confirmé par la même
-- fenêtre, sans effet sur les refus.

local POPUP = "POLYPODE_MERGE_DUPLICATES"
local LOGIN_DELAY = 5 -- secondes après la connexion (le temps que tout se charge)
local queue = {} -- groupes restant à proposer à la connexion

-- Libellé d'une fiche : « Prénom Nom (royaume, compte X) ».
local function Label(key)
	local entry = P.db.roster[key] or {}
	local details = { entry.realm and entry.realm ~= "" and entry.realm or L["royaume vide"] }
	local account = P.GetCharacterAccount(key)
	if account then
		details[#details + 1] = L["compte %s"]:format(account)
	end
	return P.GetDisplayName(key, true) .. " (" .. table.concat(details, ", ") .. ")"
end
P.DuplicateLabel = Label

-- « A et B », « A, B et C ».
local function JoinLabels(keys)
	local labels = {}
	for i, key in ipairs(keys) do
		labels[i] = "|cffffd200" .. Label(key) .. "|r"
	end
	if #labels == 1 then
		return labels[1]
	end
	local last = table.remove(labels)
	return L["%s et %s"]:format(table.concat(labels, ", "), last)
end

local ShowNext

-- Fusionne toutes les fiches de keys dans keep, puis rafraîchit la fenêtre.
local function MergeAll(keys, keep)
	local merged, errors = P.MergeCharacterGroup(keep, keys)
	for _, err in ipairs(errors) do
		UIErrorsFrame:AddMessage(err, 1, 0.1, 0.1)
	end
	if merged > 0 then
		UIErrorsFrame:AddMessage(L["Fiches fusionnées dans %s. /poly annuler-fusion pour revenir en arrière."]
			:format(P.GetDisplayName(keep, true)), 1, 0.82, 0)
	end
	P.RefreshUI()
end

P.OnLanguageApplied(function()
	StaticPopupDialogs[POPUP] = {
		text = "%s",
		button1 = YES or L["Oui"],
		button2 = NO or L["Non"],
		OnAccept = function(_, data)
			MergeAll(data.keys, data.keep)
			if data.atLogin then
				C_Timer.After(0, ShowNext)
			end
		end,
		OnCancel = function(_, data, reason)
			-- Non à la connexion : plus proposé. Fenêtre fermée autrement (autre fenêtre) : reproposé.
			if data and data.atLogin and reason == "clicked" then
				P.IgnoreDuplicateGroup(data.keys)
				P.RefreshUI()
			end
			if data and data.atLogin then
				C_Timer.After(0, ShowNext)
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = false, -- Échap ne vaut pas « Non »
		preferredIndex = 3,
	}
end)

-- Propose la fusion du groupe keys dans keep (atLogin : réponse Non retenue).
local function Ask(keys, keep, atLogin)
	local others = {}
	for _, key in ipairs(keys) do
		if key ~= keep then
			others[#others + 1] = key
		end
	end
	local text = L["Problème de sauvegarde ou de mise à jour du jeu : les personnages %s semblent identiques."]
		:format(JoinLabels(keys))
		.. "|n|n" .. L["Voulez-vous les fusionner ?"]
		.. "|n|n" .. L["Fiche gardée : %s. Les équipes et le compte WoW des autres passent sur elle ; "
			.. "/poly annuler-fusion revient en arrière."]:format("|cffffd200" .. Label(keep) .. "|r")
	if atLogin then
		text = text .. "|n" .. L["Non : ne plus le proposer à la connexion (l'icône devant ces personnages, dans "
			.. "la fenêtre Polypode, permet de fusionner plus tard)."]
	end
	StaticPopup_Show(POPUP, text, nil, { keys = keys, keep = keep, atLogin = atLogin, others = others })
end

-- Groupe suivant de la file de connexion (refus déjà enregistrés et fiches déjà fusionnées sautés).
ShowNext = function()
	while #queue > 0 do
		local keys = table.remove(queue, 1)
		local current = P.GetDuplicatesOf(keys[1])
		if current and not P.IsDuplicateGroupIgnored(current) then
			Ask(current, P.DefaultMergeKeep(current), true)
			return
		end
	end
end

-- Contrôle de connexion : file des groupes non refusés, fenêtre Polypode ouverte derrière.
function P.CheckDuplicatesAtLogin()
	C_Timer.After(LOGIN_DELAY, function()
		if InCombatLockdown() then
			P.CheckDuplicatesAtLogin() -- en combat : plus tard
			return
		end
		wipe(queue)
		for _, keys in ipairs(P.GetDuplicateGroups()) do
			if not P.IsDuplicateGroupIgnored(keys) then
				queue[#queue + 1] = keys
			end
		end
		if #queue == 0 then
			return
		end
		if not (P.ui and P.ui.frame and P.ui.frame:IsShown()) then
			P.ToggleUI()
		end
		ShowNext()
	end)
end

-- Menu de fusion manuelle d'une fiche (icône de la liste) : garder celle-ci et fusionner une autre
-- fiche du groupe, ou toutes les autres. La fiche du personnage joué n'est jamais fusionnée dans
-- une autre : garder une autre fiche que la sienne n'est proposé que pour les fiches restantes.
function P.ShowMergeMenu(owner, key)
	local keys = P.GetDuplicatesOf(key)
	if not keys then
		return
	end
	local own = P.GetCharKey()
	local hasOwn = false
	for _, other in ipairs(keys) do
		hasOwn = hasOwn or other == own
	end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(L["Doublons possibles"])
		for _, other in ipairs(keys) do
			if other ~= key and other ~= own then
				root:CreateButton(L["Garder %s, fusionner %s"]:format(Label(key), Label(other)), function()
					Ask({ key, other }, key, false)
				end)
			end
		end
		if #keys > 2 and (key == own or not hasOwn) then
			root:CreateButton(L["Garder %s, fusionner les %d autres"]:format(Label(key), #keys - 1), function()
				Ask(keys, key, false)
			end)
		end
	end)
end

-- Infobulle de l'icône.
function P.MergeIconTooltip(owner, key)
	local keys = P.GetDuplicatesOf(key)
	if not keys then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:AddLine(L["Doublon possible"])
	local others = {}
	for _, other in ipairs(keys) do
		if other ~= key then
			others[#others + 1] = other
		end
	end
	GameTooltip:AddLine(L["Même personnage que %s ?"]:format(JoinLabels(others)), 1, 1, 1, true)
	if P.IsDuplicateGroupIgnored(keys) then
		GameTooltip:AddLine(L["Fusion refusée à la connexion."], 0.7, 0.7, 0.7, true)
	end
	GameTooltip:AddLine(L["Clic : fusionner ces fiches"], 1, 1, 1, true)
	P.ShowTooltip()
end
