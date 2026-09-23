--!strict
--[[
	DailyLudusService.luau — the 15-minute day.

	Two responsibilities only:
	  1. Energy regeneration (fractional remainders preserved).
	  2. Daily reset at Config.Ludus.ResetHourUtc.

	Everything else about the "Daily Ludus" is emergent: energy caps how many
	reports you can collect, which caps how many Fate Rolls you can afford,
	which is the whole 15-minute session.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)

local DailyLudusService = {}

local DAY_SECONDS = 86400

function DailyLudusService.dayIndex(now: number): number
	local offset = Config.Ludus.ResetHourUtc * 3600
	return math.floor((now - offset) / DAY_SECONDS)
end

-- Adds regenerated energy, preserving the fractional remainder so that
-- repeated calls do not leak regen time.
function DailyLudusService.regenerate(profile: Types.Profile, now: number): number
	local elapsed = now - profile.lastEnergyAt
	if elapsed <= 0 then
		return 0
	end

	local rate = Config.Ludus.RegenPerMinute
	local gained = math.floor((elapsed / 60) * rate)

	if gained <= 0 then
		return 0
	end

	local before = profile.energy
	profile.energy = math.min(Config.Ludus.MaxEnergy, profile.energy + gained)

	-- Advance the timestamp only by the time actually consumed.
	local consumedSeconds = (gained / rate) * 60
	profile.lastEnergyAt += consumedSeconds

	if profile.energy >= Config.Ludus.MaxEnergy then
		profile.lastEnergyAt = now
	end

	return profile.energy - before
end

-- Returns true if a new Ludus day was rolled over.
function DailyLudusService.refresh(profile: Types.Profile, now: number): boolean
	local today = DailyLudusService.dayIndex(now)
	if today <= profile.lastLudusDay then
		return false
	end

	profile.lastLudusDay = today
	profile.energy = Config.Ludus.MaxEnergy
	profile.lastEnergyAt = now

	profile.seasonal["ludus_days"] = (profile.seasonal["ludus_days"] or 0) + 1

	return true
end

function DailyLudusService.remainingMissions(profile: Types.Profile): number
	return math.floor(profile.energy / Config.Ludus.MissionEnergyCost)
end

return DailyLudusService
