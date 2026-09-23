--!strict
--[[
	Client.client.luau — client API surface.

	The client holds NO authoritative state. It mirrors whatever the server
	sends back on each RemoteFunction response via `state`, and exposes a
	tiny promise-less API for the UI layer.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local player = Players.LocalPlayer

local Client = {}
Client.State = nil :: Types.ClientState?

type Listener = (Types.ClientState?) -> ()
local listeners: { Listener } = {}

local function emit()
	for _, fn in ipairs(listeners) do
		task.spawn(fn, Client.State)
	end
end

function Client.subscribe(fn: Listener)
	table.insert(listeners, fn)
	task.spawn(fn, Client.State)
	return function()
		local idx = table.find(listeners, fn)
		if idx then
			table.remove(listeners, idx)
		end
	end
end

local function absorb(response: any): any
	if type(response) == "table" and response.state then
		Client.State = response.state
		emit()
	end
	return response
end

local function invoke(name: string, ...: any): any
	local fn = Net.fn(name)
	local ok, result = pcall(function(...)
		return fn:InvokeServer(...)
	end, ...)

	if not ok then
		warn(("[Client] %s failed: %s"):format(name, tostring(result)))
		return { ok = false, err = "Network error." }
	end

	return absorb(result)
end

-- ── Public API ────────────────────────────────────────────────────────────
function Client.getState()          return invoke("GetState") end
function Client.collectReport(region: string) return invoke("CollectReport", region) end
function Client.submitReports()     return invoke("SubmitReports") end
function Client.rollFate(count: number)       return invoke("RollFate", count) end
function Client.setDefenseTeam(uids: { string }) return invoke("SetDefenseTeam", uids) end
function Client.listTargets()       return invoke("ListTargets") end
function Client.attack(userId: number)        return invoke("Attack", userId) end

Client.Config = Config

-- ── Server pushes ─────────────────────────────────────────────────────────
Net.event("StateSync").OnClientEvent:Connect(function(state)
	Client.State = state
	emit()
end)

Net.event("Notify").OnClientEvent:Connect(function(payload)
	Client.State = Client.State
	Client.OnNotify = nil
	if Client._notifyHandler then
		Client._notifyHandler(payload)
	end
end)

Net.event("PvpResolved").OnClientEvent:Connect(function(payload)
	if Client._pvpHandler then
		Client._pvpHandler(payload)
	end
end)

function Client.onNotify(fn) Client._notifyHandler = fn end
function Client.onPvpResolved(fn) Client._pvpHandler = fn end

-- ── Boot ──────────────────────────────────────────────────────────────────
local UI = require(script.Parent:WaitForChild("UI"))
UI.new(Client)

Client.getState()

return Client
