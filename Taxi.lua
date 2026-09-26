-- Polypode: Taxi — vol pris par le leader chez un maître de vol, pris aussi par les membres

local P = Polypode

-- Fonctionnement (repris de TeamManager), option P.charDb.autoTaxi, par personnage, des deux
-- côtés. Message TAXI:token:nomDestination (le nom en dernier : il peut contenir « : »).
-- Leader : hook TakeTaxiNode(index) ; annonce le NOM de la destination, car les index
-- diffèrent d'un personnage à l'autre selon les points de vol découverts.
-- Membre : si sa carte de vol est ouverte (TaxiFrame ou FlightMapFrame), retrouve l'index
-- local de la destination par son nom et prend le vol. Destination non découverte ou carte
-- fermée : rien (pas d'attente). Sync.lua n'accepte TAXI que du leader de l'équipe sélectionnée.

local ANNOUNCE_DEDUP = 2 -- secondes entre deux annonces de la même destination

local function IsEnabled()
	return P.charDb and P.charDb.autoTaxi
end

-- Réception de TAXI (Sync.lua).
function P.OnTaxiMessage(nodeName, sender)
	if not IsEnabled() or not nodeName or nodeName == "" then
		return
	end
	local mapOpen = (TaxiFrame and TaxiFrame:IsShown()) or (FlightMapFrame and FlightMapFrame:IsShown())
	if not mapOpen or not (NumTaxiNodes and TaxiNodeName and TakeTaxiNode) then
		P.Debug("Vol ignoré : aucune carte de vol ouverte (destination " .. nodeName .. ")")
		return
	end
	for index = 1, NumTaxiNodes() do
		if TaxiNodeName(index) == nodeName then
			TakeTaxiNode(index)
			P.Debug("Vol pris vers " .. nodeName .. " (leader " .. tostring(sender) .. ")")
			return
		end
	end
	P.Debug("Vol ignoré : destination non découverte (" .. nodeName .. ")")
end

-- Leader : annonce la destination choisie. Un membre qui prend le vol déclenche aussi ce
-- hook, mais n'annonce rien (P.BroadcastLeaderAction : leader seulement).
if TakeTaxiNode then
	hooksecurefunc("TakeTaxiNode", function(index)
		if not IsEnabled() then
			return
		end
		local nodeName = index and TaxiNodeName and TaxiNodeName(index) or ""
		if nodeName ~= "" then
			P.BroadcastLeaderAction("TAXI", nodeName, "TAXI" .. nodeName, ANNOUNCE_DEDUP, "TakeTaxiNode")
		end
	end)
end
