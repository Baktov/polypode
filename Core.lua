-- Polypode: Core — table globale, SavedVariables, utilitaires, CRUD du roster

Polypode = Polypode or {}
local P = Polypode

P.SYNC_PREFIX = "POLYPODE"
P.debugEnabled = false

BINDING_HEADER_POLYPODE = "Polypode"
_G["BINDING_NAME_POLYPODE_TOGGLEUI"] = "Polypode: Ouvrir/Fermer l'interface"

P.defaults = {
	roster = {}, -- [nom-royaume] = { name, realm, class, level, lastSeen }
	leader = nil, -- clé (nom-royaume) du leader désigné
	minimap = {
		angle = 225, -- position du bouton autour de la minimap, en degrés (225 = bas gauche)
		hide = false, -- true : bouton masqué (/poly minimap ou panneau d'options)
	},
	mainFrame = {
		width = 720, -- taille de la fenêtre principale, mémorisée au redimensionnement
		height = 320,
	},
	teams = {}, -- [nom] = { name, members = { [nom-royaume] = true }, leader = nom-royaume|nil }
}

P.charDefaults = {
	role = "member", -- "leader" | "member"
}

function P.Debug(msg)
	if P.debugEnabled then
		print("|cff33ff99Polypode|r: " .. tostring(msg))
	end
end

local function CopyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = dst[k] or {}
			CopyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

function P.InitDB()
	PolypodeDB = CopyDefaults(P.defaults, PolypodeDB or {})
	PolypodeCharDB = CopyDefaults(P.charDefaults, PolypodeCharDB or {})
	P.db = PolypodeDB
	P.charDb = PolypodeCharDB
end

function P.GetCharKey(name, realm)
	name = name or UnitName("player")
	realm = realm or GetRealmName()
	return name .. "-" .. realm
end

-- Ajoute/actualise un personnage dans le roster. Sans argument, enregistre le
-- personnage courant. Avec class/level fournis, enregistre un personnage distant
-- (reçu via Sync.lua).
function P.AddCharacter(name, realm, class, level)
	name = name or UnitName("player")
	realm = realm or GetRealmName()
	local key = P.GetCharKey(name, realm)

	P.db.roster[key] = P.db.roster[key] or {}
	local entry = P.db.roster[key]
	entry.name = name
	entry.realm = realm

	if key == P.GetCharKey() then
		local _, playerClass = UnitClass("player")
		entry.class = playerClass
		entry.level = UnitLevel("player")
	elseif class then
		entry.class = class
		entry.level = level or entry.level
	end

	entry.lastSeen = time()
	return key, entry
end

function P.RemoveCharacter(key)
	P.db.roster[key] = nil
	if P.db.leader == key then
		P.db.leader = nil
	end
	-- Un personnage retiré du roster ne reste membre (ni leader) d'aucune équipe.
	for name in pairs(P.db.teams) do
		P.RemoveTeamMember(name, key)
	end
end

function P.SetLeader(key)
	if P.db.roster[key] then
		P.db.leader = key
	end
end

function P.GetRoster()
	return P.db.roster
end

-- Crée une équipe. Renvoie true, ou false et un message d'erreur à afficher.
function P.CreateTeam(name)
	name = strtrim(name or "")
	if name == "" then
		return false, "Nom d'équipe vide."
	end
	if P.db.teams[name] then
		return false, "L'équipe « " .. name .. " » existe déjà."
	end
	P.db.teams[name] = { name = name, members = {} }
	return true
end

function P.GetTeams()
	return P.db.teams
end

-- Membres d'une équipe : ensemble { [nom-royaume] = true }, ou nil si l'équipe n'existe pas.
-- Les équipes créées avant l'ajout des membres reçoivent un ensemble vide.
function P.GetTeamMembers(teamName)
	local team = teamName and P.db.teams[teamName]
	if not team then
		return nil
	end
	team.members = team.members or {}
	return team.members
end

function P.AddTeamMember(teamName, key)
	local members = P.GetTeamMembers(teamName)
	if members and P.db.roster[key] then
		members[key] = true
	end
end

-- Noms des équipes dont le personnage est membre, triés par ordre alphabétique.
function P.GetCharacterTeams(key)
	local names = {}
	for name, team in pairs(P.db.teams) do
		if team.members and team.members[key] then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

-- Retire un membre ; s'il était leader de l'équipe, l'équipe n'a plus de leader.
function P.RemoveTeamMember(teamName, key)
	local members = P.GetTeamMembers(teamName)
	if members then
		members[key] = nil
		local team = P.db.teams[teamName]
		if team.leader == key then
			team.leader = nil
		end
	end
end

-- Leader d'une équipe (clé nom-royaume), ou nil.
function P.GetTeamLeader(teamName)
	local team = teamName and P.db.teams[teamName]
	return team and team.leader
end

-- Désigne le leader d'une équipe ; il doit en être membre.
function P.SetTeamLeader(teamName, key)
	local members = P.GetTeamMembers(teamName)
	if members and members[key] then
		P.db.teams[teamName].leader = key
	end
end
