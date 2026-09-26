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

-- Skinne un frame top-level. Priorité à EllesmereUI (l'utilisateur a laissé le skin
-- activé), sinon ElvUI, sinon on garde le backdrop générique de UI_Main.lua.
-- Le bouton de fermeture est attendu dans frame.CloseButton (convention ElvUI/Blizzard),
-- le titre dans frame.TitleText.
function P.SkinFrame(frame)
	if euiSkin and euiSkin.IsEnabled() then
		euiSkin.Shell(frame)
		if frame.CloseButton then
			euiSkin.CloseButton(frame.CloseButton)
		end
		-- Centre le titre verticalement dans la barre de titre du Shell.
		if frame.TitleText then
			frame.TitleText:ClearAllPoints()
			frame.TitleText:SetPoint("CENTER", frame, "TOP", 0, -EUI_TOP_BAR_HEIGHT / 2)
		end
		return
	end

	if not ElvUI then
		return
	end
	local E = unpack(ElvUI)
	local S = E:GetModule("Skins")
	if S and S.HandleFrame then
		S:HandleFrame(frame)
	end
end

-- Skinne un cadre intérieur (sous-panneau d'une fenêtre). Même priorité que P.SkinFrame.
function P.SkinPanel(panel)
	if euiSkin and euiSkin.IsEnabled() then
		euiSkin.Panel(panel, { inset = true })
		return
	end

	-- ElvUI ajoute SetTemplate à tous les frames une fois chargé.
	if ElvUI and panel.SetTemplate then
		panel:SetTemplate("Transparent")
	end
end
