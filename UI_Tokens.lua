-- Polypode: UI_Tokens — fenêtre des comptes Battle.net autorisés (liste, révocation)

local P = Polypode

-- Ouverte par le bouton « Gestion liste token » du panneau d'options (UI_Options.xml).
-- Liste défilante des comptes autorisés (P.GetTrustedTokens) : libellé (personnage vu à
-- l'autorisation), bouton « Révoquer » à droite (P.UntrustToken, synchronisé entre nos
-- clients) ; au survol, infobulle listant les personnages connus de ce compte (roster,
-- entry.token enregistré à chaque annonce). Échap ferme la fenêtre.

local FRAME_WIDTH, FRAME_HEIGHT = 380, 280

local frame, listPanel

local function FormatAccount(data)
	return data.label
end

-- Infobulle d'un compte : libellé, token abrégé, personnages connus, rappel du bouton.
local function AccountTooltip(data)
	local lines = { data.label, "|cff999999Token " .. data.token .. "|r", " " }
	local characters = P.GetTokenCharacters(data.token)
	if #characters == 0 then
		lines[#lines + 1] = "|cff999999Aucun personnage connu (il apparaîtra à sa prochaine connexion)|r"
	else
		lines[#lines + 1] = "|cffffd200Personnages :|r"
		for _, key in ipairs(characters) do
			lines[#lines + 1] = "  " .. key
		end
	end
	lines[#lines + 1] = " "
	lines[#lines + 1] = "Bouton « Révoquer » : retirer l'autorisation de ce compte"
	return lines
end

local function Build()
	frame = CreateFrame("Frame", "PolypodeTokensFrame", UIParent, "BackdropTemplate")
	frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG") -- au-dessus du panneau d'options
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0, 0, 0, 0.9)
	frame:Hide()
	tinsert(UISpecialFrames, "PolypodeTokensFrame") -- Échap ferme la fenêtre

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -14)
	title:SetText("Comptes autorisés")
	frame.TitleText = title

	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -4, -4)
	frame.CloseButton = closeBtn

	listPanel = P.CreatePanel(frame, "Autres comptes Battle.net")
	listPanel:SetPoint("TOPLEFT", 12, -36)
	listPanel:SetPoint("BOTTOMRIGHT", -12, 12)
	P.CreateScrollList(listPanel, FormatAccount, nil, {
		tooltip = AccountTooltip,
		button = {
			text = "Révoquer",
			width = 80,
			tooltip = "Retire l'autorisation de ce compte (aussi sur vos autres Polypode).",
			onClick = function(data)
				if P.UntrustToken(data.token) then
					UIErrorsFrame:AddMessage("Autorisation retirée : " .. data.label .. ".", 1, 0.82, 0)
					P.RefreshTokensWindow()
				end
			end,
		},
	})
	listPanel.emptyText:SetText("Aucun compte autorisé")

	P.ui.tokensFrame = frame
	P.ui.tokensPanel = listPanel

	P.SkinFrame(frame)
	P.SkinPanel(listPanel)
end

-- Remplit la liste, si la fenêtre est ouverte.
function P.RefreshTokensWindow()
	if frame and frame:IsShown() then
		P.SetListData(listPanel, P.GetTrustedTokens())
	end
end

-- Ouvre la fenêtre (bouton « Gestion liste token » du panneau d'options).
function P.ShowTokensWindow()
	if not frame then
		Build()
	end
	frame:Show()
	P.RefreshTokensWindow()
end
