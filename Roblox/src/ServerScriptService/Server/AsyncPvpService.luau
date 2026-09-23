--!strict
--[[
	AsyncPvpService.luau — Фаза 1, шаг 3: "Асинхронное PvP".

	Model:
	  · A player's defense is a snapshot of their defenseTeam, published to a
	    MemoryStoreService SortedMap keyed by rating.
	  · An attacker pulls a page of nearby snapshots, chooses one, and the
	    match resolves deterministically from a seed derived from both
	    user ids + ratings — so replays are auditable.
	  · Attacker rating updates immediately. Defender rating updates when
	    they next join, via a per-user pending queue in a MemoryStore HashMap.

	This is the piece that lets an offline player be attacked. It is the
	reason the game does not need to be online to be social.
]]

local MemoryStoreService = game:GetService("MemoryStoreService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)

local Server = script.Parent
local Guard = require(Server.Guard)

local AsyncPvpService = {}

local ladder  = MemoryStoreService:GetSortedMap(Config.Persistence.LadderMapName)
local pending = MemoryStoreService:GetHashMap(Config.Persistence.PendingMapName)

local function seedFor(a: number, b: number, ra: number, rb: number): number
	local h = (a * 2654435761 + b * 40503 + ra * 97 + rb) % 2147483647
	return h == 0 and 1 or h
end

local function defensePower(profile: Types.Profile): number
	local total = 0
	for _, uid in ipairs(profile.defenseTeam) do
		local relic = profile.relics[uid]
		if relic then
			total += relic.power
		end
	end
	return total
end

function AsyncPvpService.buildSnapshot(player: Player, profile: Types.Profile): Types.AttackSnapshot
	local snapshot: Types.AttackSnapshot = {
		schemaVersion = Config.Pvp.SnapshotSchemaVersion,
		userId = player.UserId,
		displayName = player.DisplayName,
		rating = profile.stats.pvpRating,
		takenAt = os.time(),
		power = defensePower(profile),
		relics = {},
	}

	for _, uid in ipairs(profile.defenseTeam) do
		local relic = profile.relics[uid]
		if relic then
			table.insert(snapshot.relics, {
				catalogId = relic.catalogId,
				rarity = relic.rarity,
				power = relic.power,
			})
		end
	end

	return snapshot
end

function AsyncPvpService.publish(player: Player, profile: Types.Profile)
	local snapshot = AsyncPvpService.buildSnapshot(player, profile)
	local ok, err = pcall(function()
		ladder:SetAsync(
			tostring(player.UserId),
			profile.stats.pvpRating,
			snapshot,
			Config.Pvp.MemoryStoreTtlSeconds
		)
	end)
	if not ok then
		warn(("[AsyncPvp] publish failed for %s: %s"):format(player.Name, tostring(err)))
	end
end

function AsyncPvpService.listTargets(player: Player): { any }
	local out: { any } = {}

	local ok, err = pcall(function()
		local entries = ladder:GetRangeAsync(Enum.SortDirection.Descending, Config.Pvp.MaxAttackTargets)
		for _, entry in ipairs(entries) do
			local snapshot = entry.value
			if type(snapshot) == "table" and snapshot.userId ~= player.UserId then
				table.insert(out, {
					userId = snapshot.userId,
					displayName = snapshot.displayName,
					rating = snapshot.rating,
					power = snapshot.power,
					relics = snapshot.relics,
				})
			end
		end
	end)

	if not ok then
		warn("[AsyncPvp] listTargets failed: " .. tostring(err))
	end

	return out
end

local function pushPending(userId: number, record: Types.PvpRecord, rating: number)
	local ok, err = pcall(function()
		pending:UpdateAsync(tostring(userId), function(old: any)
			local list = old
			if type(list) ~= "table" then
				list = { rating = rating, records = {} }
			end
			if type(list.records) ~= "table" then
				list.records = {}
			end
			list.rating = rating
			table.insert(list.records, record)
			while #list.records > Config.Pvp.PendingQueueMax do
				table.remove(list.records, 1)
			end
			return list
		end, Config.Pvp.MemoryStoreTtlSeconds)
	end)
	if not ok then
		warn("[AsyncPvp] pushPending failed: " .. tostring(err))
	end
end

-- Drains and clears the pending queue for a joining player.
function AsyncPvpService.drainPending(userId: number): { Types.PvpRecord }
	local out: { Types.PvpRecord } = {}

	local ok, err = pcall(function()
		pending:UpdateAsync(tostring(userId), function(old: any)
			if type(old) ~= "table" or type(old.records) ~= "table" then
				return nil
			end
			for _, record in ipairs(old.records) do
				table.insert(out, record)
			end
			return nil -- clear
		end, Config.Pvp.MemoryStoreTtlSeconds)
	end)

	if not ok then
		warn("[AsyncPvp] drainPending failed: " .. tostring(err))
	end

	return out
end

local function eloDelta(ratingA: number, ratingB: number, won: boolean): number
	local expected = 1 / (1 + 10 ^ ((ratingB - ratingA) / 400))
	local score = won and 1 or 0
	return math.floor(Config.Pvp.RatingK * (score - expected))
end

local function simulate(attacker: Types.AttackSnapshot, defender: Types.AttackSnapshot)
	local seed = seedFor(attacker.userId, defender.userId, attacker.rating, defender.rating)
	local rng = Random.new(seed)

	local attackerRounds = 0
	local defenderRounds = 0
	local rounds: { any } = {}

	for round = 1, Config.Pvp.RoundsPerMatch do
		local a = attacker.power * (0.90 + rng:NextNumber() * 0.20) + rng:NextInteger(0, 5)
		local d = defender.power * (Config.Pvp.DefenderAdvantage + rng:NextNumber() * 0.20) + rng:NextInteger(0, 5)
		local attackerWon = a > d

		if attackerWon then
			attackerRounds += 1
		else
			defenderRounds += 1
		end

		table.insert(rounds, {
			round = round,
			attacker = math.floor(a),
			defender = math.floor(d),
			attackerWon = attackerWon,
		})
	end

	return attackerRounds > defenderRounds, rounds
end

function AsyncPvpService.attack(player: Player, profile: Types.Profile, targetUserId: any)
	local targetId = Guard.expectInt(targetUserId)

	if targetId == player.UserId then
		return false, "You cannot raid your own caravanserai."
	end

	if not Guard.consume(player, "pvp", Config.Limits.MaxPvpPerMinute) then
		return false, "Steady your blade."
	end

	if #profile.defenseTeam == 0 then
		return false, "Set a defense team before you march."
	end

	local targetKey = tostring(targetId)
	local ok, snapshot = pcall(function()
		return ladder:GetAsync(targetKey)
	end)

	if not ok or type(snapshot) ~= "table" then
		return false, "That caravan has already moved on."
	end

	local attacker = AsyncPvpService.buildSnapshot(player, profile)
	local defender = snapshot :: Types.AttackSnapshot

	local won, rounds = simulate(attacker, defender)

	local attackerDelta = eloDelta(attacker.rating, defender.rating, won)
	local defenderDelta = eloDelta(defender.rating, attacker.rating, not won)

	local now = os.time()

	profile.stats.pvpRating = math.max(0, profile.stats.pvpRating + attackerDelta)
	if won then
		profile.stats.pvpWins += 1
		-- Winning raids pay in reports: the loop closes back on itself.
		local spoils = math.max(1, math.floor(defender.power * 0.05))
		profile.stats.reportsCollected += 0
		EconomyService_credit(player, profile, spoils)
	else
		profile.stats.pvpLosses += 1
	end

	table.insert(profile.history, {
		opponentUserId = targetId,
		opponentName = defender.displayName,
		won = won,
		ratingDelta = attackerDelta,
		at = now,
	})
	while #profile.history > Config.Pvp.HistoryMax do
		table.remove(profile.history, 1)
	end

	-- Republish our updated rating so the ladder stays honest.
	AsyncPvpService.publish(player, profile)

	-- Queue the defender's side of the match for their next login.
	pushPending(targetId, {
		opponentUserId = player.UserId,
		opponentName = player.DisplayName,
		won = not won,
		ratingDelta = defenderDelta,
		at = now,
	}, math.max(0, (defender.rating or 0) + defenderDelta))

	return true, {
		won = won,
		attackerDelta = attackerDelta,
		rounds = rounds,
		opponent = defender.displayName,
		rating = profile.stats.pvpRating,
	}
end

-- Small indirection so this module does not require EconomyService at load
-- time (avoids a require cycle if EconomyService ever wants PvP stats).
local EconomyService
function EconomyService_credit(player: Player, profile: Types.Profile, amount: number)
	if not EconomyService then
		EconomyService = require(Server.EconomyService)
	end
	EconomyService.credit(profile, Config.Currency.Soft, amount, "pvp_spoils", player.UserId)
end

return AsyncPvpService
