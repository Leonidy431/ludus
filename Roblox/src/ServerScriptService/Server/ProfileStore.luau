--!strict
--[[
	ProfileStore.luau — session-locked, autosaving player profiles.

	Design notes (mirrors the reference-repo pattern of a locked, versioned
	DataStore wrapper without pulling in third-party SDKs):

	  · UpdateAsync transforms acquire a per-key session lock. A second server
	    attempting to load a live profile receives `nil` and is told to back off.
	  · Locks older than LockStaleSeconds are considered dead (server crash) and
	    are reclaimed.
	  · Autosave runs on a single coroutine; saves are serialised per player.
	  · On release we persist final state and clear the lock in one write.

	This module owns NO game rules. It only moves bytes to and from DataStore.
]]

local DataStoreService = game:GetService("DataStoreService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)

local P = Config.Persistence

local store = DataStoreService:GetDataStore(P.StoreName)

local ProfileStore = {}

ProfileStore.Loaded = {} :: { [Player]: Types.Profile }

local function jobId(): string
	local id = game.JobId
	if id == nil or id == "" then
		return "studio-" .. tostring(math.random(1, 1e9))
	end
	return id
end

local function keyFor(userId: number): string
	return ("player_%d"):format(userId)
end

local function defaultProfile(): Types.Profile
	local now = os.time()
	return {
		schemaVersion   = P.SchemaVersion,
		createdAt       = now,
		lastSeen        = now,
		lastEnergyAt    = now,
		lastLudusDay    = 0,

		wallet          = { deniers = 0, aspri = 0, laurels = 0 },
		energy          = Config.Ludus.MaxEnergy,

		relics          = {},
		defenseTeam     = {},
		reports         = {},

		pity            = { counter = 0, sinceEpic = 0, sinceLegendary = 0 },
		stats           = {
			reportsCollected = 0,
			fateRolls        = 0,
			pvpWins          = 0,
			pvpLosses        = 0,
			pvpRating        = Config.Pvp.RatingStart,
			season           = 1,
		},
		history         = {},
		seasonal        = {},
	}
end

-- Forward-compat migrations. Each migration bumps schemaVersion by 1.
local function migrate(profile: any): Types.Profile
	if type(profile) ~= "table" then
		return defaultProfile()
	end

	local fresh = defaultProfile()
	-- Shallow-merge onto defaults so newly added fields always exist.
	for k, v in pairs(profile) do
		fresh[k] = v
	end
	-- Deep-merge the known nested tables.
	for _, field in ipairs({ "wallet", "pity", "stats", "seasonal" }) do
		local base = (defaultProfile() :: any)[field]
		if type(profile[field]) == "table" then
			for k, v in pairs(profile[field]) do
				base[k] = v
			end
		end
		fresh[field] = base
	end

	fresh.schemaVersion = P.SchemaVersion
	return fresh :: Types.Profile
end

local function lockIsLive(lock: any, myJob: string): boolean
	if type(lock) ~= "table" then
		return false
	end
	if lock.jobId == myJob then
		return false -- our own lock; safe to re-enter
	end
	local age = os.time() - (lock.at or 0)
	return age < P.LockStaleSeconds
end

-- Returns the loaded profile, or nil + reason if the profile is locked elsewhere.
function ProfileStore.loadAsync(player: Player): (Types.Profile?, string?)
	local myJob = jobId()
	local key = keyFor(player.UserId)

	local acquired = false

	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old: any)
			local profile = migrate(old)

			if lockIsLive(profile.sessionLock, myJob) then
				return nil -- abort: live session on another server
			end

			local now = os.time()
			profile.sessionLock = { jobId = myJob, at = now }
			profile.lastSeen = now

			ProfileStore.Loaded[player] = profile
			acquired = true
			return profile
		end)
	end)

	if not ok then
		warn(("[ProfileStore] load failed for %s: %s"):format(player.Name, tostring(err)))
		return nil, "datastore_error"
	end
	if not acquired then
		return nil, "locked"
	end

	return ProfileStore.Loaded[player], nil
end

-- Persists the in-memory profile. Safe to call frequently; DataStore dedupes.
function ProfileStore.saveAsync(player: Player): boolean
	local profile = ProfileStore.Loaded[player]
	if not profile then
		return false
	end

	local myJob = jobId()
	local key = keyFor(player.UserId)
	profile.lastSeen = os.time()

	local released = false

	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old: any)
			local current = migrate(old)

			if lockIsLive(current.sessionLock, myJob) then
				released = true -- someone else took over; abandon our write
				return nil
			end

			profile.sessionLock = { jobId = myJob, at = os.time() }
			released = true
			return profile
		end)
	end)

	if not ok then
		warn(("[ProfileStore] save failed for %s: %s"):format(player.Name, tostring(err)))
		return false
	end
	if not released then
		return false
	end
	return true
end

-- Final write + lock release. Always call this from PlayerRemoving / BindToClose.
function ProfileStore.releaseAsync(player: Player): boolean
	local profile = ProfileStore.Loaded[player]
	if not profile then
		return true
	end

	local myJob = jobId()
	local key = keyFor(player.UserId)
	profile.lastSeen = os.time()
	profile.sessionLock = nil -- persist without a lock

	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old: any)
			local current = migrate(old)
			local lock = current.sessionLock
			if type(lock) == "table" and lock.jobId ~= myJob and (os.time() - (lock.at or 0)) < P.LockStaleSeconds then
				-- Another live server owns the profile; do not clobber.
				return current
			end
			return profile
		end)
	end)

	ProfileStore.Loaded[player] = nil

	if not ok then
		warn(("[ProfileStore] release failed for %s: %s"):format(player.Name, tostring(err)))
		return false
	end
	return true
end

function ProfileStore.markDirty(player: Player)
	-- Dirty tracking exists for Phase 4 analytics; autosave currently writes
	-- every loaded profile on the interval regardless.
	local _ = player
end

function ProfileStore.startAutosave()
	task.spawn(function()
		while true do
			task.wait(P.AutosaveInterval)
			for player in pairs(ProfileStore.Loaded) do
				task.spawn(function()
					ProfileStore.saveAsync(player)
				end)
			end
		end
	end)
end

return ProfileStore
