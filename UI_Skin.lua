-- Polypode: UI_Skin — skinning conditionnel EllesmereUI / ElvUI (optionnels, jamais requis)

local P = Polypode

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

-- Toutes les fonctions suivantes : priorité à EllesmereUI (l'utilisateur a laissé le skin
-- activé), sinon ElvUI, sinon on garde l'apparence générique de UI_Main.lua.

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
function P.SkinFrame(frame)
	KeepOnTop(frame)
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
		return
	end

	local S = GetElvSkins()
	if S and S.HandleFrame then
		S:HandleFrame(frame)
	end
end

-- Skinne un bouton de fermeture (UIPanelCloseButton) hors fenêtre top-level, ex. la croix
-- de la barre flottante d'équipe. EllesmereUI : croix plate, sans changer taille ni ancrage.
function P.SkinCloseButton(button)
	local eui = GetEUISkin()
	if eui then
		eui.CloseButton(button)
		return
	end

	local S = GetElvSkins()
	if S and S.HandleCloseButton then
		S:HandleCloseButton(button)
	end
end

-- Skinne une barre de défilement MinimalScrollBar.
function P.SkinScrollBar(scrollBar)
	local eui = GetEUISkin()
	if eui then
		eui.ScrollBar(scrollBar)
		return
	end

	local S = GetElvSkins()
	if S and S.HandleTrimScrollBar then
		S:HandleTrimScrollBar(scrollBar)
	end
end

-- Skinne un cadre intérieur (sous-panneau d'une fenêtre).
function P.SkinPanel(panel)
	local eui = GetEUISkin()
	if eui then
		eui.Panel(panel, { inset = true })
		return
	end

	-- ElvUI ajoute SetTemplate à tous les frames une fois chargé.
	if ElvUI and panel.SetTemplate then
		panel:SetTemplate("Transparent")
	end
end

-- Skinne un champ de saisie (EditBox, ex. InputBoxInstructionsTemplate).
function P.SkinEditBox(editBox)
	local eui = GetEUISkin()
	if eui then
		eui.EditBox(editBox)
		return
	end

	local S = GetElvSkins()
	if S and S.HandleEditBox then
		S:HandleEditBox(editBox)
	end
end

-- Skinne une liste déroulante Blizzard (WowStyle1DropdownTemplate) : cadre plat et flèche du
-- skin. width : largeur imposée par ElvUI (défaut : largeur actuelle).
function P.SkinDropdown(dropdown, width)
	local eui = GetEUISkin()
	if eui then
		eui.Dropdown(dropdown)
		return
	end

	local S = GetElvSkins()
	if S and S.HandleDropDownBox then
		S:HandleDropDownBox(dropdown, width or dropdown:GetWidth())
	end
end

-- Skinne une case à cocher (ex. UICheckButtonTemplate) : case sombre et coche du skin.
function P.SkinCheckBox(check)
	local eui = GetEUISkin()
	if eui then
		eui.Checkbox(check)
		return
	end

	local S = GetElvSkins()
	if S and S.HandleCheckBox then
		S:HandleCheckBox(check)
	end
end

-- Skinne un bouton texte (ex. UIPanelButtonTemplate). Libellé blanc, gris si désactivé.
function P.SkinButton(button)
	local eui = GetEUISkin()
	if eui then
		eui.Button(button)
		eui.StateButtonLabel(button)
		return
	end

	local S = GetElvSkins()
	if S and S.HandleButton then
		S:HandleButton(button)
	end
end
