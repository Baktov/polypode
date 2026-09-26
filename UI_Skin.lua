-- Polypode: UI_Skin — skinning ElvUI conditionnel (optionnel, jamais requis)

local P = Polypode

function P.SkinFrame(frame)
	if not ElvUI then
		return
	end
	local E = unpack(ElvUI)
	local S = E:GetModule("Skins")
	if S and S.HandleFrame then
		S:HandleFrame(frame)
	end
end
