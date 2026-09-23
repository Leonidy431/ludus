--!strict
--[[
	Bootstrap.server.luau — server composition root.

	Owns exactly three things:
	  · Remote creation (Net.ensure) and handler binding.
	  · Player lifecycle (load → hydrate → drain pending → publish).
	  · Autosave + BindToClose.

	No game rules live here. If you are tempted to add one, it goes in a
	Service under Server/.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local Server = script.Parent:WaitForChild("Server")
local Guard = require(Server.Guard)
local ProfileStore = require(Server.ProfileStore)
local EconomyService = require(Server.EconomyService)
local DailyLudusService = require(Server.DailyLudusService)
local ReportService = require(Server.ReportService)
local GachaService = require(Server.GachaService)
local AsyncPvpService = require(Server.AsyncPvpService)

-- ── Remotes ───────────────────────────────────────────────────────────────
Net.ensure()

-- ── Helpers ───────────────────────────────────────────────────────────────
local function present(profile: Types.Profile): Types.ClientState
	local relicCount = 0
	for _ in pairs(profile.relics) do
		relicCount += 1
	end

	return {
		wallet = EconomyService.view(profile),
		energy = math.floor(profile.energy),
		maxEnergy = Config.Ludus.MaxEnergy,
		relicCount = relicCount,
		defenseTeam = table.clone(profile.defenseTeam),
		pity = table.clone(profile.pity),
		stats = table.clone(profile.stats),
		lastLudusDay = profile.lastLudusDay,
		dayIndex = DailyLudusService.dayIndex(os.time()),
	}
end

local function fail(message: string)
	return { ok = false, err = message }
end

local function okResult(profile: Types.Profile, payload: any?)
	return { ok = true, res = payload, state = present(profile) }
end

-- Hydrates time-based state and returns the profile, or nil if not loaded.
local function hydrate(player: Player): Types.Profile?
	local profile = ProfileStore.Loaded[player]
	if not profile then
		return nil
	end
	local now = os.time()
	DailyLudusService.refresh(profile, now)
	DailyLudusService.regenerate(profile, now)
	return profile
end

-- ── Remote handlers ───────────────────────────────────────────────────────
Net.fn("GetState").OnServerInvoke = function(player: Player)
	local profile = hydrate(player)
	if not profile then
		return fail("Profile not ready. Try again in a moment.")
	end
	return okResult(profile)
end

Net.fn("CollectReport").OnServerInvoke = function(player: Player, region: any)
	local profile = hydrate(player)
	if not profile then
		return fail("Profile not ready.")
	end

	local ok, res = ReportService.collect(player, profile, region)
	if not ok then
		return fail(res :: string)
	end
	return okResult(profile, res)
end

Net.fn("SubmitReports").OnServerInvoke = function(player: Player)
	local profile = hydrate(player)
	if not profile then
		return fail("Profile not ready.")
	end

	local ok, res = ReportService.submit(player, profile)
	if not ok then
		return fail(res :: string)
	end
	return okResult(profile, res)
end

Net.fn("RollFate").OnServerInvoke = function(player: Player, count: any)
	local profile = hydrate(player)
	if not profile then
		return fail("Profile not ready.")
	end

	local ok, res = GachaService.roll(player, profile, count)
	if not ok then
		return fail(res :: string)
	end
	return okResult(profile, res)
end

Net.fn("SetDefenseTeam").OnServerInvoke = function(player: Player, uids: any)
	local profile = hydrate(player)
	if not profile then
		return fail("Profile not ready.")
	end

	if type(uids) ~= "table" then
		return fail("Malformed defense payload.")
	end
	if #uids > Config.Pvp.DefenseSlots then
		return fail(("You may field at most %d defenders."):format(Config.Pvp.DefenseSlots))
	end

	local clean: { string } = {}
	local seen: { [string]: boolean } = {}

	for _, uid in ipairs(uids) do
		if not Guard.isStringId(uid, 64) then
			return fail("Malformed relic id.")
		end
		if seen[uid] then
			return fail("Duplicate defender.")
		end
		if profile.relics[uid] == nil then
			return fail("You do not own that relic.")
		end
		seen[uid] = true
		table.insert(clean, uid)
	end

	profile.defenseTeam = clean
	AsyncPvpService.publish(player, profile)

	return okResult(profile)
end

Net.fn("ListTargets").OnServerInvoke = function(player: Player)
	local profile = hydrate(player)
	if not profile then
		return fail("Profile not ready.")
	end
	if not Guard.consume(player, "pvp_list", Config.Limits.MaxPvpPerMinute) then
		return fail("Scouting too quickly.")
	end

	local targets = AsyncPvpService.listTargets(player)
	return okResult(profile, { targets = targets })
end

Net.fn("Attack").OnServerInvoke = function(player: Player, targetUserId: any)
	local profile = hydrate(player)
	if not profile then
		return fail("Profile not ready.")
	end

	local ok, res = AsyncPvpService.attack(player, profile, targetUserId)
	if not ok then
		return fail(res :: string)
	end

	if res.won then
		Net.fireClient(player, "Notify", {
			kind = "win",
			text = ("Victory against %s (+%d)"):format(res.opponent, res.attackerDelta),
		})
	else
		Net.fireClient(player, "Notify", {
			kind = "loss",
			text = ("Repelled by %s (%d)"):format(res.opponent, res.attackerDelta),
		})
	end

	return okResult(profile, res)
end

-- ── Player lifecycle ──────────────────────────────────────────────────────
local function onPlayerAdded(player: Player)
	local profile, reason = ProfileStore.loadAsync(player)
	if not profile then
		if reason == "locked" then
			player:Kick("Your ledger is open on another server. Rejoin shortly.")
		else
			player:Kick("Your caravan ledger could not be loaded. Please rejoin.")
		end
		return
	end

	local now = os.time()
	DailyLudusService.refresh(profile, now)
	DailyLudusService.regenerate(profile, now)

	-- Drain offline PvP results.
	local records = AsyncPvpService.drainPending(player.UserId)
	if #records > 0 then
		for _, record in ipairs(records) do
			if record.won then
				profile.stats.pvpWins += 1
			else
				profile.stats.pvpLosses += 1
			end
			profile.stats.pvpRating = math.max(0, profile.stats.pvpRating + record.ratingDelta)
			table.insert(profile.history, record)
		end
		while #profile.history > Config.Pvp.HistoryMax do
			table.remove(profile.history, 1)
		end
		Net.fireClient(player, "PvpResolved", { records = records })
	end

	-- Default defense team: fill empty slots with the highest-power relics.
	if #profile.defenseTeam == 0 then
		local owned = {}
		for uid, relic in pairs(profile.relics) do
			table.insert(owned, { uid = uid, power = relic.power })
		end
		table.sort(owned, function(a, b) return a.power > b.power end)
		for i = 1, math.min(Config.Pvp.DefenseSlots, #owned) do
			table.insert(profile.defenseTeam, owned[i].uid)
		end
	end

	AsyncPvpService.publish(player, profile)
	Net.fireClient(player, "StateSync", present(profile))
end

local function onPlayerRemoving(player: Player)
	local profile = ProfileStore.Loaded[player]
	if profile then
		AsyncPvpService.publish(player, profile)
	end
	ProfileStore.releaseAsync(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

ProfileStore.startAutosave()

game:BindToClose(function()
	local pending = {}
	for player in pairs(ProfileStore.Loaded) do
		table.insert(pending, task.spawn(ProfileStore.releaseAsync, player))
	end
	-- BindToClose has a hard 30s budget; give saves room but no more.
	local budget = os.clock() + 25
	while os.clock() < budget do
		local anyAlive = false
		for _, thread in ipairs(pending) do
			if coroutine.status(thread) ~= "dead" then
				anyAlive = true
				break
			end
		end
		if not anyAlive then
			break
		end
		task.wait(0.1)
	end
end)

print(("[Deacon's Path] server up — %s v%s"):format(Config.GameTitle, Config.Version))
