-- Polypode: UI_Trust — demande d'autorisation d'un autre compte Battle.net vu sur le canal dédié

local P = Polypode

-- Une annonce de connexion (HELLO/HI) reçue sur le canal dédié avec un token inconnu
-- (Sync.lua) ouvre une fenêtre : canal (nom, numéro), personnage, classe, niveau.
-- Autoriser : le token rejoint les comptes autorisés (Core.lua, synchronisé entre nos
-- clients) et l'annonce est traitée aussitôt. Refuser ou Échap : plus de demande pour ce
-- compte jusqu'au prochain rechargement. Une demande à la fois ; les suivantes attendent.

local POPUP = "POLYPODE_TRUST_ACCOUNT"

local queue = {} -- demandes en attente (après celle affichée)
local asked = {} -- [token] = true : déjà affiché ou en attente pendant cette session
local refused = {} -- [token] = true : refusé pendant cette session

local ShowNext

StaticPopupDialogs[POPUP] = {
	text = "%s",
	button1 = "Autoriser",
	button2 = "Refuser",
	OnAccept = function(_, request)
		P.TrustToken(request.token, request.label)
		P.Debug("Compte autorisé : " .. request.label)
		-- Traite l'annonce reçue (roster, synchro, réponse HI s'il s'agissait d'un HELLO).
		P.OnSyncMessage(request.message, request.channel, request.sender)
		if request.kind == "HI" then
			-- Il a répondu à notre annonce : on s'annonce de nouveau pour qu'il nous traite aussi.
			P.SayHello("HELLO", "CHANNEL")
		end
		if P.RefreshUI then
			P.RefreshUI()
		end
	end,
	OnCancel = function(_, request)
		refused[request.token] = true
		P.Debug("Compte refusé pour cette session : " .. request.label)
	end,
	OnHide = function()
		C_Timer.After(0, ShowNext)
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- Affiche la prochaine demande en attente, si aucune n'est affichée.
ShowNext = function()
	if StaticPopup_Visible(POPUP) then
		return
	end
	local request = table.remove(queue, 1)
	if request then
		StaticPopup_Show(POPUP, request.text, nil, request)
	end
end

-- Appelé par Sync.lua pour une annonce HELLO/HI au token inconnu reçue sur le canal dédié.
function P.PromptTrust(token, message, channel, sender)
	if asked[token] or refused[token] then
		return
	end
	local kind, _, rest = strsplit(":", message, 3)
	local name, realm, class, level = strsplit(":", rest or "")
	if not name or not realm then
		return
	end
	asked[token] = true

	local label = name .. "-" .. realm
	local className = class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class or "?"
	local channelName = P.GetSyncChannelName()
	local text = string.format(
		"Polypode : un personnage d'un autre compte Battle.net s'annonce sur le canal dédié.\n\n"
			.. "Canal : %s (n° %d)\nPersonnage : %s\nClasse : %s, niveau %s\n\n"
			.. "Autoriser ce compte à échanger avec Polypode (roster, équipes, groupage, "
			.. "actions du leader) ?",
		channelName, GetChannelName(channelName), label, className, level or "?")

	queue[#queue + 1] = {
		token = token,
		kind = kind,
		label = label,
		text = text,
		message = message,
		channel = channel,
		sender = sender,
	}
	ShowNext()
end
