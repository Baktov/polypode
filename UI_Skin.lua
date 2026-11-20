-- Polypode: UI_Skin — apparence des fenêtres : thème Polypode (styles au choix), EllesmereUI / ElvUI (optionnels) ou apparence native

local P = Polypode
local L = P.L

-- THÈMES (P.db.theme, choisi dans les options, appliqué après /reload) :
-- - "auto" (défaut, 2.33.0) : EllesmereUI ou ElvUI s'ils sont chargés sur ce personnage, sinon
--   "polypode" (style par défaut Chronique) ;
-- - "polypode" : apparence propre à Polypode, en trois styles (P.db.themeStyle :
--   Chronique, Plat, Fougère), changés à chaud ; style Plat : couleur d'accent par module
--   (P.db.themeModuleColor) ;
-- - "native" : apparence générique de WoW posée par chaque fenêtre (bordure d'infobulle) ;
-- - "ellesmere" / "elvui" : skin d'EllesmereUI ou d'ElvUI, s'ils sont chargés (sinon thème Polypode).
-- Le thème est figé pour la session (un skin EllesmereUI / ElvUI ne se défait pas) ; le style, lui,
-- se repeint partout par P.ApplyTheme : chaque élément skinné est gardé dans `skinned`.

-- Façade de skin fournie par EllesmereUI à PLAYER_LOGIN. Reste nil si EllesmereUI est
-- absent, si son module Blizzard Skin est désactivé, ou si l'utilisateur a désactivé
-- le skin de Polypode dans ses options (Third-Party Addons).
local euiSkin

-- Hauteur de la barre de titre sombre dessinée par S.Shell (constante du moteur de
-- fenêtres EllesmereUIBlizzardSkin, cf. WindowEngine.lua).
local EUI_TOP_BAR_HEIGHT = 25

-- Enregistrement au chargement du fichier : EllesmereUI est chargé avant nous grâce
-- à OptionalDeps dans le .toc. Le callback ne fait que mémoriser la façade, car la
-- fenêtre n'est construite qu'à la première ouverture (P.BuildUI).
if EllesmereUI and EllesmereUI.RegisterSkin then
	EllesmereUI.RegisterSkin("Polypode", function(S)
		euiSkin = S
	end)
end

-- Façade EllesmereUI si son skin est actif pour Polypode, sinon nil.
local function GetEUISkin()
	if euiSkin and euiSkin.IsEnabled() then
		return euiSkin
	end
end

-- Module Skins d'ElvUI s'il est chargé, sinon nil.
local function GetElvSkins()
	if not ElvUI then
		return
	end
	local E = unpack(ElvUI)
	return E:GetModule("Skins")
end

-- ---------------------------------------------------------------------------------------------
-- Thème Polypode : jetons des styles (mêmes valeurs que la planche de styles)
-- ---------------------------------------------------------------------------------------------

-- "rrggbb", alpha → { r, g, b, a }
local function C(hex, alpha)
	return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255, alpha or 1 }
end

-- bg fond de fenêtre, bar bandeau de titre, border bordure, inner liseré intérieur, title titres,
-- text texte, muted texte atténué, accent survol et repères, button / buttonHover fond des boutons,
-- buttonText / buttonHigh texte des boutons (normal, survol), panel fond des cadres intérieurs ;
-- innerLine liseré intérieur, corners losanges aux coins, accentLine trait d'accent en haut.
P.THEME_STYLES = {
	chronique = { -- bronze et or, comme le site Histoire v2
		bg = C("15110c", 0.94), bar = C("221a11", 0.96), border = C("8a6a3a"), inner = C("3b2d1b"),
		title = C("f0c860"), text = C("e8dcc4"), muted = C("9a8a70"), accent = C("d9a648"),
		button = C("2a2015"), buttonHover = C("3a2c1c"), buttonText = C("f0c860"), buttonHigh = C("fff0c0"),
		panel = C("0e0b07", 0.45), innerLine = true, corners = true,
	},
	plat = { -- ardoise mate, une couleur par module
		bg = C("14171c", 0.95), bar = C("1c2027", 0.98), border = C("2f353f"), inner = C("2f353f"),
		title = C("f2f4f7"), text = C("d9dde3"), muted = C("8a929e"), accent = C("d4a94e"),
		button = C("232931"), buttonHover = C("2b323c"), buttonText = C("d9dde3"), buttonHigh = C("ffffff"),
		panel = C("000000", 0.25), accentLine = true,
	},
	fougere = { -- vert mousse et or
		bg = C("0e1511", 0.94), bar = C("141f18", 0.97), border = C("44613f"), inner = C("1d2b1f"),
		title = C("d8b45a"), text = C("dfe6d6"), muted = C("8c9a84"), accent = C("9ccc65"),
		button = C("1a271d"), buttonHover = C("233426"), buttonText = C("dfe6d6"), buttonHigh = C("ffffff"),
		panel = C("050a07", 0.4), innerLine = true,
	},
}

-- Couleur d'accent de chaque module (style Plat, P.db.themeModuleColor), par le nom de sa fenêtre
-- (« PolypodeHistoireFrame » → Histoire) ou la clé passée à P.SkinFrame.
local MODULE_COLORS = {
	Histoire = C("c89b5a"), Data = C("4ea1ff"), Suivi = C("52c47a"), Teleport = C("a77bff"),
	Map = C("e07a4a"), Photo = C("e0c341"), Profil = C("4fc1c9"),
}

local WHITE = "Interface\\Buttons\\WHITE8X8"
local FLAT = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }
local TITLE_HEIGHT = 30 -- bandeau de titre par défaut (frame.polypodeTitleHeight pour un autre)

-- Thème de la session : lu une fois P.db chargé, puis figé (changement = /reload).
local activeTheme
local function ActiveTheme()
	if activeTheme then
		return activeTheme
	end
	local wanted = P.db and P.db.theme or "auto"
	if wanted == "auto" then
		if EllesmereUI and EllesmereUI.RegisterSkin then
			wanted = "ellesmere"
		elseif ElvUI then
			wanted = "elvui"
		else
			wanted = "polypode"
		end
	end
	if wanted == "ellesmere" and not (EllesmereUI and EllesmereUI.RegisterSkin) then
		wanted = "polypode"
	elseif wanted == "elvui" and not ElvUI then
		wanted = "polypode"
	end
	if P.db then
		activeTheme = wanted
	end
	return wanted
end

local function Style()
	return P.THEME_STYLES[P.db and P.db.themeStyle] or P.THEME_STYLES.chronique
end

local function Accent(moduleKey)
	local style = Style()
	if style == P.THEME_STYLES.plat and P.db and P.db.themeModuleColor and MODULE_COLORS[moduleKey] then
		return MODULE_COLORS[moduleKey]
	end
	return style.accent
end

local function ModuleFromName(frame)
	local name = frame.GetName and frame:GetName()
	return name and name:match("^Polypode(%u%l+)")
end

-- Éléments skinnés par le thème Polypode : [élément] = { kind, module, ... } (clés faibles).
local skinned = setmetatable({}, { __mode = "k" })
local themeCallbacks = {}

-- Module de la fenêtre qui contient un élément (accent du style Plat).
local function ModuleOf(widget)
	local current = widget
	for _ = 1, 12 do
		if not current then
			return
		end
		local data = skinned[current]
		if data and data.kind == "frame" then
			return data.module
		end
		current = current:GetParent()
	end
end

local function EnsureBackdrop(frame)
	if not frame.SetBackdrop then
		Mixin(frame, BackdropTemplateMixin)
		frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged)
	end
end

-- Masque les textures d'un modèle de Blizzard (alpha 0 : les changements d'atlas du jeu, au clic ou
-- à la désactivation, restent invisibles).
local function HideTextures(widget, keys, getters)
	for _, key in ipairs(keys or {}) do
		if widget[key] and widget[key].SetAlpha then
			widget[key]:SetAlpha(0)
		end
	end
	for _, getter in ipairs(getters or {}) do
		local texture = widget[getter] and widget[getter](widget)
		if texture then
			texture:SetAlpha(0)
		end
	end
end

local function Rotate(texture, degrees)
	if texture.SetRotation then
		texture:SetRotation(math.rad(degrees))
	end
end

-- Polices des boutons (normal, survol, désactivé), recolorées par le style.
local fonts
local function ThemeFonts()
	if not fonts then
		fonts = {
			normal = CreateFont("PolypodeThemeButtonFont"),
			high = CreateFont("PolypodeThemeButtonHighlightFont"),
			disabled = CreateFont("PolypodeThemeButtonDisabledFont"),
		}
		for _, font in pairs(fonts) do
			font:CopyFontObject(GameFontNormal)
		end
	end
	return fonts
end

local function UpdateFonts()
	if not fonts then
		return
	end
	local s = Style()
	fonts.normal:SetTextColor(unpack(s.buttonText))
	fonts.high:SetTextColor(unpack(s.buttonHigh))
	fonts.disabled:SetTextColor(unpack(s.muted))
end

local PAINT = {}

-- Fenêtre : fond et bordure plats, bandeau de titre (si frame.TitleText), liseré intérieur,
-- losanges aux coins (Chronique), trait d'accent en haut (Plat), titre et croix.
function PAINT.frame(frame, data)
	local s = Style()
	EnsureBackdrop(frame)
	frame:SetBackdrop(FLAT)
	frame:SetBackdropColor(unpack(s.bg))
	frame:SetBackdropBorderColor(unpack(s.border))
	local x = data.extras
	if not x then
		x = {}
		data.extras = x
		x.bar = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
		x.barLine = frame:CreateTexture(nil, "BORDER", nil, 2)
		x.accent = frame:CreateTexture(nil, "BORDER", nil, 3)
		x.accent:SetPoint("TOPLEFT", 1, -1)
		x.accent:SetPoint("TOPRIGHT", -1, -1)
		x.accent:SetHeight(2)
		-- Liseré et losanges sur un cadre enfant : au-dessus du fond, sous le contenu.
		x.inner = CreateFrame("Frame", nil, frame, "BackdropTemplate")
		x.inner:SetPoint("TOPLEFT", 2, -2)
		x.inner:SetPoint("BOTTOMRIGHT", -2, 2)
		x.inner:SetFrameLevel(frame:GetFrameLevel())
		x.inner:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
		x.corners = {}
		for _, point in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
			local outer = x.inner:CreateTexture(nil, "OVERLAY", nil, 6)
			outer:SetTexture(WHITE)
			outer:SetSize(9, 9)
			outer:SetPoint("CENTER", frame, point, 0, 0)
			Rotate(outer, 45)
			local core = x.inner:CreateTexture(nil, "OVERLAY", nil, 7)
			core:SetTexture(WHITE)
			core:SetSize(5, 5)
			core:SetPoint("CENTER", outer)
			Rotate(core, 45)
			x.corners[#x.corners + 1] = { outer, core }
		end
	end
	local height = frame.TitleText and (frame.polypodeTitleHeight or TITLE_HEIGHT)
	x.bar:SetShown(height and true or false)
	x.barLine:SetShown(height and true or false)
	if height then
		x.bar:ClearAllPoints()
		x.bar:SetPoint("TOPLEFT", 1, -1)
		x.bar:SetPoint("TOPRIGHT", -1, -1)
		x.bar:SetHeight(height - 1)
		x.bar:SetColorTexture(unpack(s.bar))
		x.barLine:ClearAllPoints()
		x.barLine:SetPoint("TOPLEFT", 1, -height)
		x.barLine:SetPoint("TOPRIGHT", -1, -height)
		x.barLine:SetHeight(1)
		x.barLine:SetColorTexture(unpack(s.innerLine and s.border or s.inner))
	end
	x.inner:SetBackdropBorderColor(s.inner[1], s.inner[2], s.inner[3], s.innerLine and 1 or 0)
	x.accent:SetShown(s.accentLine and true or false)
	x.accent:SetColorTexture(unpack(Accent(data.module)))
	for _, pair in ipairs(x.corners) do
		pair[1]:SetColorTexture(unpack(s.border))
		pair[2]:SetColorTexture(unpack(s.bar))
		pair[1]:SetShown(s.corners and true or false)
		pair[2]:SetShown(s.corners and true or false)
	end
	if frame.TitleText then
		frame.TitleText:SetTextColor(unpack(s.title))
	end
end

-- Cadre intérieur : fond léger et liseré ; un cadre rendu transparent par son module le reste.
function PAINT.panel(panel, data)
	local s = Style()
	if data.transparent == nil then
		local alpha = panel.GetBackdropColor and select(4, panel:GetBackdropColor())
		data.transparent = alpha ~= nil and alpha == 0
	end
	EnsureBackdrop(panel)
	panel:SetBackdrop(FLAT)
	if data.transparent then
		panel:SetBackdropColor(0, 0, 0, 0)
		panel:SetBackdropBorderColor(0, 0, 0, 0)
	else
		panel:SetBackdropColor(unpack(s.panel))
		panel:SetBackdropBorderColor(unpack(s.inner))
	end
	if panel.header then
		panel.header:SetTextColor(unpack(s.title))
	end
end

-- Bouton texte (UIPanelButtonTemplate) : plat, bordure d'accent au survol, plus sombre enfoncé.
function PAINT.button(button, data)
	local s = Style()
	if not data.ready then
		data.ready = true
		HideTextures(button, { "Left", "Middle", "Right", "LeftSeparator", "RightSeparator" },
			{ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" })
		EnsureBackdrop(button)
		button:SetBackdrop(FLAT)
		local f = ThemeFonts()
		UpdateFonts()
		button:SetNormalFontObject(f.normal)
		button:SetHighlightFontObject(f.high)
		button:SetDisabledFontObject(f.disabled)
		local function Repaint(self)
			if skinned[self] then
				PAINT.button(self, skinned[self])
			end
		end
		button:HookScript("OnEnter", function(self)
			self.polypodeHover = true
			Repaint(self)
		end)
		button:HookScript("OnLeave", function(self)
			self.polypodeHover = nil
			self.polypodeDown = nil
			Repaint(self)
		end)
		button:HookScript("OnMouseDown", function(self)
			self.polypodeDown = true
			Repaint(self)
		end)
		button:HookScript("OnMouseUp", function(self)
			self.polypodeDown = nil
			Repaint(self)
		end)
		button:HookScript("OnEnable", Repaint)
		button:HookScript("OnDisable", Repaint)
	end
	local enabled = button:IsEnabled()
	local background = (button.polypodeDown and enabled) and s.bg or ((button.polypodeHover and enabled) and s.buttonHover or s.button)
	button:SetBackdropColor(unpack(background))
	local border = (button.polypodeHover and enabled) and Accent(ModuleOf(button)) or s.border
	button:SetBackdropBorderColor(border[1], border[2], border[3], enabled and border[4] or 0.5)
end

-- Croix de fermeture (UIPanelCloseButton) : deux traits, sans changer taille ni ancrage.
function PAINT.close(button, data)
	local s = Style()
	if not data.ready then
		data.ready = true
		HideTextures(button, nil, { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" })
		data.lines = {}
		for _, angle in ipairs({ 45, -45 }) do
			local line = button:CreateTexture(nil, "OVERLAY")
			line:SetTexture(WHITE)
			line:SetSize(11, 1.5)
			line:SetPoint("CENTER")
			Rotate(line, angle)
			data.lines[#data.lines + 1] = line
		end
		local function Repaint(self)
			if skinned[self] then
				PAINT.close(self, skinned[self])
			end
		end
		button:HookScript("OnEnter", function(self)
			self.polypodeHover = true
			Repaint(self)
		end)
		button:HookScript("OnLeave", function(self)
			self.polypodeHover = nil
			Repaint(self)
		end)
	end
	local color = button.polypodeHover and s.title or s.muted
	for _, line in ipairs(data.lines) do
		line:SetColorTexture(unpack(color))
	end
end

-- Case à cocher (UICheckButtonTemplate) : petit carré bordé, coche pleine à la couleur d'accent.
function PAINT.check(check, data)
	local s = Style()
	if not data.ready then
		data.ready = true
		HideTextures(check, nil, { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" })
		local size = math.max(12, math.min(16, math.floor(math.min(check:GetWidth(), check:GetHeight()) * 0.5)))
		data.border = check:CreateTexture(nil, "BACKGROUND")
		data.border:SetSize(size, size)
		data.border:SetPoint("CENTER")
		data.fill = check:CreateTexture(nil, "BORDER")
		data.fill:SetSize(size - 2, size - 2)
		data.fill:SetPoint("CENTER")
		for _, getter in ipairs({ "GetCheckedTexture", "GetDisabledCheckedTexture" }) do
			local tick = check[getter] and check[getter](check)
			if tick then
				tick:SetTexture(WHITE)
				tick:ClearAllPoints()
				tick:SetPoint("CENTER")
				tick:SetSize(size - 6, size - 6)
			end
		end
	end
	data.border:SetColorTexture(unpack(s.border))
	data.fill:SetColorTexture(0, 0, 0, 0.55)
	local tick = check:GetCheckedTexture()
	if tick then
		tick:SetVertexColor(unpack(Accent(ModuleOf(check))))
	end
	local disabledTick = check.GetDisabledCheckedTexture and check:GetDisabledCheckedTexture()
	if disabledTick then
		disabledTick:SetVertexColor(unpack(s.muted))
	end
end

-- Champ de saisie (InputBoxTemplate) : fond sombre et bordure fine, sous le texte.
function PAINT.edit(editBox, data)
	local s = Style()
	if not data.ready then
		data.ready = true
		HideTextures(editBox, { "Left", "Middle", "Right" })
		data.back = CreateFrame("Frame", nil, editBox, "BackdropTemplate")
		data.back:SetPoint("TOPLEFT", -5, -1)
		data.back:SetPoint("BOTTOMRIGHT", 0, 1)
		data.back:SetFrameLevel(math.max(0, editBox:GetFrameLevel() - 1))
		data.back:SetBackdrop(FLAT)
	end
	data.back:SetBackdropColor(0, 0, 0, 0.45)
	data.back:SetBackdropBorderColor(unpack(s.border))
end

-- Menu ouvert d'une liste déroulante : fond plat et bordure du style sous le menu de Blizzard, dont
-- la texture de fond (atlas MENU_ATLAS) est rendue invisible le temps de l'ouverture puis rétablie
-- (les menus et leurs textures sont réutilisés par le jeu pour ses propres listes).
local MENU_ATLAS = "common-dropdown-bg"
local menuBack, menuHidden
local function RestoreMenu()
	if menuHidden then
		menuHidden:SetAlpha(menuHidden.polypodeAlpha or 1)
		menuHidden = nil
	end
	if menuBack then
		menuBack:Hide()
	end
end

local function SkinOpenMenu(dropdown)
	local menu = dropdown.menu
	if not menu or not skinned[dropdown] then
		return
	end
	if not menuHidden then
		for _, region in ipairs({ menu:GetRegions() }) do
			if region.GetAtlas and region:GetAtlas() == MENU_ATLAS then
				region.polypodeAlpha = region:GetAlpha()
				region:SetAlpha(0)
				menuHidden = region
				break
			end
		end
	end
	if not menuBack then
		menuBack = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
		menuBack:SetBackdrop(FLAT)
	end
	local s = Style()
	menuBack:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], 0.97)
	menuBack:SetBackdropBorderColor(unpack(s.border))
	menuBack:SetFrameStrata(menu:GetFrameStrata())
	menuBack:SetFrameLevel(math.max(0, menu:GetFrameLevel() - 1))
	menuBack:ClearAllPoints()
	menuBack:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, 0)
	menuBack:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -2, 6)
	menuBack:Show()
end

-- Liste déroulante (WowStyle1DropdownTemplate) : bouton plat comme les boutons texte, chevron à deux
-- traits, texte du style ; menu ouvert habillé par SkinOpenMenu.
function PAINT.dropdown(dropdown, data)
	local s = Style()
	if not data.ready then
		data.ready = true
		HideTextures(dropdown, { "Background", "Arrow" })
		EnsureBackdrop(dropdown)
		dropdown:SetBackdrop(FLAT)
		-- Chevron vers le bas : deux traits qui se rejoignent en bas.
		data.chevron = {}
		for index, angle in ipairs({ -45, 45 }) do
			local line = dropdown:CreateTexture(nil, "OVERLAY")
			line:SetTexture(WHITE)
			line:SetSize(6, 1.5)
			line:SetPoint("CENTER", dropdown, "RIGHT", -12 + (index == 1 and -1.6 or 1.6), 0)
			Rotate(line, angle)
			data.chevron[index] = line
		end
		local function Repaint(self)
			if skinned[self] then
				PAINT.dropdown(self, skinned[self])
			end
		end
		-- Le modèle recolore le texte et change la flèche à chaque état (survol, clic, désactivé).
		if type(dropdown.OnButtonStateChanged) == "function" then
			hooksecurefunc(dropdown, "OnButtonStateChanged", Repaint)
		end
		dropdown:HookScript("OnEnable", Repaint)
		dropdown:HookScript("OnDisable", Repaint)
		if dropdown.RegisterCallback and DropdownButtonMixin and DropdownButtonMixin.Event then
			dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuOpen, function(self)
				SkinOpenMenu(self)
				Repaint(self)
				-- Mise en page du menu parfois achevée à l'image suivante.
				C_Timer.After(0, function()
					SkinOpenMenu(self)
				end)
			end)
			dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuClose, function(self)
				RestoreMenu()
				Repaint(self)
			end)
		end
	end
	local enabled = dropdown:IsEnabled()
	local over = dropdown.IsOver and dropdown:IsOver()
	local open = dropdown.IsMenuOpen and dropdown:IsMenuOpen()
	local background = ((over or open) and enabled) and s.buttonHover or s.button
	dropdown:SetBackdropColor(unpack(background))
	local border = ((over or open) and enabled) and Accent(ModuleOf(dropdown)) or s.border
	dropdown:SetBackdropBorderColor(border[1], border[2], border[3], enabled and border[4] or 0.5)
	if dropdown.Text then
		dropdown.Text:SetTextColor(unpack(enabled and s.text or s.muted))
	end
	local chevron = enabled and ((over or open) and s.title or s.muted) or s.muted
	for _, line in ipairs(data.chevron) do
		line:SetColorTexture(chevron[1], chevron[2], chevron[3], enabled and 1 or 0.5)
	end
end

-- Barre de défilement (MinimalScrollBar) : curseur à la couleur d'accent, rail et flèches teintés.
function PAINT.scroll(scrollBar)
	local s = Style()
	local function Tint(texture, color)
		if texture and texture.SetVertexColor then
			texture:SetDesaturated(true)
			texture:SetVertexColor(color[1], color[2], color[3])
		end
	end
	local track = scrollBar.Track
	if track then
		for _, key in ipairs({ "Begin", "Middle", "End" }) do
			Tint(track[key], s.border)
			Tint(track.Thumb and track.Thumb[key], Accent(ModuleOf(scrollBar)))
		end
	end
	for _, key in ipairs({ "Back", "Forward" }) do
		local arrow = scrollBar[key]
		if arrow then
			Tint(arrow.Texture or (arrow.GetNormalTexture and arrow:GetNormalTexture()), s.muted)
		end
	end
end

-- Repeinte groupée (une image plus tard) : après la première peinture d'une fenêtre, ses boutons
-- déjà skinnés prennent l'accent de son module.
local applyPending
local function ScheduleApply()
	if applyPending then
		return
	end
	applyPending = true
	C_Timer.After(0, function()
		applyPending = nil
		P.ApplyTheme()
	end)
end

local function Skin(kind, widget, moduleKey)
	local data = skinned[widget]
	if not data then
		data = { kind = kind, module = moduleKey }
		skinned[widget] = data
		if kind == "frame" then
			ScheduleApply()
		end
	end
	PAINT[kind](widget, data)
end

-- ---------------------------------------------------------------------------------------------
-- API publique du thème
-- ---------------------------------------------------------------------------------------------

-- Thème Polypode actif pour cette session ?
function P.IsPolypodeTheme()
	return ActiveTheme() == "polypode"
end

-- Couleur d'un jeton du style courant (bg, bar, border, inner, title, text, muted, accent, button,
-- buttonHover, panel) : r, g, b, a. accent suit la couleur du module (style Plat) si moduleKey est donné.
function P.GetThemeColor(token, moduleKey)
	local color = token == "accent" and Accent(moduleKey) or Style()[token] or Style().text
	return color[1], color[2], color[3], color[4]
end

-- fn() appelée après chaque changement de style (thème Polypode), pour les éléments propres à un module.
function P.OnThemeChanged(fn)
	themeCallbacks[#themeCallbacks + 1] = fn
end

-- Repeint tous les éléments skinnés avec le style courant, puis prévient les modules.
function P.ApplyTheme()
	if ActiveTheme() ~= "polypode" then
		return
	end
	UpdateFonts()
	for widget, data in pairs(skinned) do
		PAINT[data.kind](widget, data)
	end
	for _, fn in ipairs(themeCallbacks) do
		securecallfunction(fn)
	end
end

-- Choix du panneau d'options : { valeur, libellé } (EllesmereUI et ElvUI seulement s'ils sont chargés).
function P.GetThemeChoices()
	local choices = { { "auto", L["Automatique"] }, { "polypode", "Polypode" }, { "native", L["Natif WoW"] } }
	if EllesmereUI and EllesmereUI.RegisterSkin then
		choices[#choices + 1] = { "ellesmere", "EllesmereUI" }
	end
	if ElvUI then
		choices[#choices + 1] = { "elvui", "ElvUI" }
	end
	return choices
end

P.THEME_STYLE_CHOICES = {
	{ "chronique", L["Chronique"] },
	{ "plat", L["Plat"] },
	{ "fougere", L["Fougère"] },
}

function P.SetThemePreference(theme)
	if P.db.theme == theme then
		return
	end
	P.db.theme = theme
	UIErrorsFrame:AddMessage(L["Polypode : tapez /reload pour changer de thème."], 1, 0.82, 0)
end

function P.SetThemeStyle(style)
	P.db.themeStyle = P.THEME_STYLES[style] and style or "chronique"
	P.ApplyTheme()
end

function P.SetThemeModuleColor(value)
	P.db.themeModuleColor = value and true or false
	P.ApplyTheme()
end

-- ---------------------------------------------------------------------------------------------
-- Fonctions de skin appelées par Polypode et ses modules : thème Polypode, sinon EllesmereUI,
-- sinon ElvUI (selon le thème choisi), sinon on garde l'apparence générique posée par la fenêtre.
-- ---------------------------------------------------------------------------------------------

-- Fenêtre au premier plan de sa strate, avec tout son contenu : sans cela, deux fenêtres de la
-- même strate (DIALOG pour les compagnons) gardent des niveaux voisins et les lignes, boutons et
-- textes de celle du dessous se dessinent par-dessus le fond de celle du dessus. SetToplevel la
-- remonte au clic, Raise à chaque affichage.
local function KeepOnTop(frame)
	frame:SetToplevel(true)
	frame:HookScript("OnShow", function(self)
		self:Raise()
	end)
	if frame:IsShown() then
		frame:Raise()
	end
end

-- Skinne un frame top-level (et le garde au premier plan, skin ou non). Le bouton de fermeture
-- est attendu dans frame.CloseButton (convention ElvUI/Blizzard), le titre dans frame.TitleText.
-- moduleKey (facultatif) : module de la fenêtre, pour sa couleur d'accent (sinon tiré de son nom).
function P.SkinFrame(frame, moduleKey)
	KeepOnTop(frame)
	P.SetupWindowAnimation(frame) -- UI_Animation.lua : ouverture et fermeture animées, tout thème
	local theme = ActiveTheme()
	if theme == "polypode" then
		Skin("frame", frame, moduleKey or ModuleFromName(frame))
		if frame.CloseButton then
			P.SkinCloseButton(frame.CloseButton)
		end
		return
	end

	if theme == "ellesmere" then
		local eui = GetEUISkin()
		if eui then
			eui.Shell(frame)
			if frame.CloseButton then
				P.SkinCloseButton(frame.CloseButton)
			end
			-- Centre le titre verticalement dans la barre de titre du Shell.
			if frame.TitleText then
				frame.TitleText:ClearAllPoints()
				frame.TitleText:SetPoint("CENTER", frame, "TOP", 0, -EUI_TOP_BAR_HEIGHT / 2)
			end
		end
		return
	end

	local S = theme == "elvui" and GetElvSkins()
	if S and S.HandleFrame then
		S:HandleFrame(frame)
	end
end

-- Skinne un bouton de fermeture (UIPanelCloseButton) hors fenêtre top-level, ex. la croix
-- de la barre flottante d'équipe. EllesmereUI : croix plate, sans changer taille ni ancrage.
function P.SkinCloseButton(button)
	local theme = ActiveTheme()
	if theme == "polypode" then
		Skin("close", button)
		return
	end

	local eui = theme == "ellesmere" and GetEUISkin()
	if eui then
		eui.CloseButton(button)
		return
	end

	local S = theme == "elvui" and GetElvSkins()
	if S and S.HandleCloseButton then
		S:HandleCloseButton(button)
	end
end

-- Skinne une barre de défilement MinimalScrollBar.
function P.SkinScrollBar(scrollBar)
	local theme = ActiveTheme()
	if theme == "polypode" then
		Skin("scroll", scrollBar)
		return
	end

	local eui = theme == "ellesmere" and GetEUISkin()
	if eui then
		eui.ScrollBar(scrollBar)
		return
	end

	local S = theme == "elvui" and GetElvSkins()
	if S and S.HandleTrimScrollBar then
		S:HandleTrimScrollBar(scrollBar)
	end
end

-- Skinne un cadre intérieur (sous-panneau d'une fenêtre).
function P.SkinPanel(panel)
	local theme = ActiveTheme()
	if theme == "polypode" then
		Skin("panel", panel)
		return
	end

	local eui = theme == "ellesmere" and GetEUISkin()
	if eui then
		eui.Panel(panel, { inset = true })
		return
	end

	-- ElvUI ajoute SetTemplate à tous les frames une fois chargé.
	if theme == "elvui" and panel.SetTemplate then
		panel:SetTemplate("Transparent")
	end
end

-- Skinne un champ de saisie (EditBox, ex. InputBoxInstructionsTemplate).
function P.SkinEditBox(editBox)
	local theme = ActiveTheme()
	if theme == "polypode" then
		Skin("edit", editBox)
		return
	end

	local eui = theme == "ellesmere" and GetEUISkin()
	if eui then
		eui.EditBox(editBox)
		return
	end

	local S = theme == "elvui" and GetElvSkins()
	if S and S.HandleEditBox then
		S:HandleEditBox(editBox)
	end
end

-- Skinne une liste déroulante Blizzard (WowStyle1DropdownTemplate) : cadre plat et flèche du
-- skin. width : largeur imposée par ElvUI (défaut : largeur actuelle). Thème Polypode : bouton plat
-- et menu ouvert aux couleurs du style (PAINT.dropdown).
function P.SkinDropdown(dropdown, width)
	local theme = ActiveTheme()
	if theme == "polypode" then
		Skin("dropdown", dropdown)
		return
	end
	local eui = theme == "ellesmere" and GetEUISkin()
	if eui then
		eui.Dropdown(dropdown)
		return
	end

	local S = theme == "elvui" and GetElvSkins()
	if S and S.HandleDropDownBox then
		S:HandleDropDownBox(dropdown, width or dropdown:GetWidth())
	end
end

-- Skinne une case à cocher (ex. UICheckButtonTemplate) : case sombre et coche du skin.
function P.SkinCheckBox(check)
	local theme = ActiveTheme()
	if theme == "polypode" then
		Skin("check", check)
		return
	end

	local eui = theme == "ellesmere" and GetEUISkin()
	if eui then
		eui.Checkbox(check)
		return
	end

	local S = theme == "elvui" and GetElvSkins()
	if S and S.HandleCheckBox then
		S:HandleCheckBox(check)
	end
end

-- Skinne un bouton texte (ex. UIPanelButtonTemplate). Libellé blanc, gris si désactivé.
function P.SkinButton(button)
	local theme = ActiveTheme()
	if theme == "polypode" then
		Skin("button", button)
		return
	end

	local eui = theme == "ellesmere" and GetEUISkin()
	if eui then
		eui.Button(button)
		eui.StateButtonLabel(button)
		return
	end

	local S = theme == "elvui" and GetElvSkins()
	if S and S.HandleButton then
		S:HandleButton(button)
	end
end
