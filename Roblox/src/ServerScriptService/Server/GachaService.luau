--!strict
--[[
	GachaService.luau — Фаза 1, шаг 2: "Гача-бросок судьбы".

	Rules enforced server-side:
	  · Roll count must be exactly 1 or 10.
	  · Cost is debited atomically *before* any relic is minted.
	  · Pity is burned on the same tick it is used, never twice.
	  · Duplicates convert to Soft currency instead of stacking (keeps the
	    relic dictionary a true collection and avoids inventory bloat).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local RelicCatalog = require(Shared.RelicCatalog)

local Server = script.Parent
local Guard = require(Server.Guard)
local EconomyService = require(Server.EconomyService)

local GachaService = {}

local rng = Random.new(os.clock() * 1_000_000)

local RARITY_ORDER: { Types.Rarity } = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

local RANK: { [string]: number } = {}
for i, rarity in ipairs(RARITY_ORDER) do
	RANK[rarity] = i
end

local function rollRarity(): Types.Rarity
	local total = 0
	for _, weight in pairs(Config.Gacha.RarityWeights) do
		total += weight
	end

	local roll = rng:NextNumber() * total
	local acc = 0
	for _, rarity in ipairs(RARITY_ORDER) do
		acc += Config.Gacha.RarityWeights[rarity]
		if roll <= acc then
			return rarity
		end
	end
	return "Common"
end

-- Applies pity counters and returns the rarity for this roll.
local function resolveRarity(profile: Types.Profile): Types.Rarity
	profile.pity.counter += 1
	profile.pity.sinceEpic += 1
	profile.pity.sinceLegendary += 1

	if profile.pity.sinceLegendary >= Config.Gacha.Pity.Hard then
		return "Legendary"
	end

	if profile.pity.sinceEpic >= Config.Gacha.Pity.Soft then
		local rolled = rollRarity()
		if RANK[rolled] < RANK["Epic"] then
			return "Epic"
		end
		return rolled
	end

	return rollRarity()
end

local function consumePity(profile: Types.Profile, rarity: Types.Rarity)
	if rarity == "Legendary" then
		profile.pity.sinceLegendary = 0
		profile.pity.sinceEpic = 0
		profile.pity.counter = 0
	elseif rarity == "Epic" then
		profile.pity.sinceEpic = 0
	end
end

local function grant(profile: Types.Profile, userId: number, rarity: Types.Rarity)
	local def = RelicCatalog.pick(rarity, rng)

	-- Duplicate detection by catalog id (collection semantics, not stack).
	for _, relic in pairs(profile.relics) do
		if relic.catalogId == def.id then
			local conversion = Config.Gacha.DuplicateConversion[rarity] or 5
			EconomyService.credit(profile, Config.Currency.Soft, conversion, "duplicate:" .. def.id, userId)
			return {
				duplicate = true,
				catalogId = def.id,
				name = def.name,
				rarity = rarity,
				converted = conversion,
			}
		end
	end

	local uid = ("rl_%d_%d"):format(os.time(), rng:NextInteger(1, 1_000_000_000))
	profile.relics[uid] = {
		uid = uid,
		catalogId = def.id,
		rarity = rarity,
		power = def.basePower,
		obtainedAt = os.time(),
		locked = false,
	}

	return {
		duplicate = false,
		uid = uid,
		catalogId = def.id,
		name = def.name,
		rarity = rarity,
		power = def.basePower,
	}
end

function GachaService.roll(player: Player, profile: Types.Profile, count: any)
	local n = Guard.expectInt(count)
	if n ~= 1 and n ~= 10 then
		return false, "The Reliquary accepts 1 or 10 rolls."
	end

	if not Guard.consume(player, "gacha", Config.Limits.MaxRollsPerMinute) then
		return false, "Slow down, pilgrim. The Path is not a race."
	end

	local cost = (n == 10) and Config.Gacha.CostTen or Config.Gacha.CostSingle
	if not EconomyService.debit(profile, Config.Currency.Soft, cost, "fate_roll", player.UserId) then
		return false, "Not enough deniers."
	end

	local results = {}
	local sawRarePlus = false

	for i = 1, n do
		local rarity = resolveRarity(profile)

		-- 10-roll guarantee: at least one Rare+ in the batch.
		if n == 10 and i == n and not sawRarePlus and RANK[rarity] < RANK["Rare"] then
			rarity = "Rare"
		end
		if RANK[rarity] >= RANK["Rare"] then
			sawRarePlus = true
		end

		consumePity(profile, rarity)
		table.insert(results, grant(profile, player.UserId, rarity))
		profile.stats.fateRolls += 1
	end

	return true, {
		cost = cost,
		results = results,
		pity = profile.pity,
	}
end

return GachaService
