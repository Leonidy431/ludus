--!strict
--[[
	Net.luau — remote surface registry.

	Every RemoteEvent / RemoteFunction in the game is declared here once.
	The server calls Net.ensure() during Bootstrap; the client just waits.
	No module outside this file may call Instance.new("RemoteEvent").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type RemoteKind = "Event" | "Function"

local REMOTES: { [string]: RemoteKind } = {
	-- client -> server (RemoteFunction: request/response, state piggy-backed)
	GetState        = "Function",
	CollectReport   = "Function",
	SubmitReports   = "Function",
	RollFate        = "Function",
	SetDefenseTeam  = "Function",
	ListTargets     = "Function",
	Attack          = "Function",

	-- server -> client
	StateSync       = "Event",
	Notify          = "Event",
	PvpResolved     = "Event",
}

local FOLDER_NAME = "DeaconNet"
local folder: Folder? = nil

local Net = {}

function Net.folder(): Folder
	if folder and folder.Parent then
		return folder
	end

	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
		return existing
	end

	if RunService:IsServer() then
		local f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = ReplicatedStorage
		folder = f
		return f
	end

	local waited = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30)
	assert(waited and waited:IsA("Folder"), "[Net] DeaconNet folder never replicated")
	folder = waited
	return waited
end

function Net.ensure()
	assert(RunService:IsServer(), "Net.ensure() is server-only")
	local f = Net.folder()
	for name, kind in pairs(REMOTES) do
		if not f:FindFirstChild(name) then
			local inst: Instance
			if kind == "Event" then
				inst = Instance.new("RemoteEvent")
			else
				inst = Instance.new("RemoteFunction")
			end
			inst.Name = name
			inst.Parent = f
		end
	end
end

function Net.ref(name: string): Instance
	assert(REMOTES[name] ~= nil, "[Net] undeclared remote: " .. tostring(name))
	local inst = Net.folder():WaitForChild(name, 30)
	assert(inst ~= nil, "[Net] remote never appeared: " .. name)
	return inst
end

function Net.event(name: string): RemoteEvent
	assert(REMOTES[name] == "Event", "[Net] " .. name .. " is not an Event")
	return Net.ref(name) :: RemoteEvent
end

function Net.fn(name: string): RemoteFunction
	assert(REMOTES[name] == "Function", "[Net] " .. name .. " is not a Function")
	return Net.ref(name) :: RemoteFunction
end

function Net.fireClient(player: Player, name: string, payload: any)
	Net.event(name):FireClient(player, payload)
end

function Net.fireAll(name: string, payload: any)
	Net.event(name):FireAllClients(payload)
end

return Net
