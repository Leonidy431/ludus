--!strict
--[[
	Config.luau — Single source of truth for tuning values.
	Deacon's Path: Issyk-Kul — Roblox GaaS
	Phase 1: Core Loop (Daily Ludus · Reports · Fate Roll · Async PvP)

	RULE: no magic numbers anywhere else in the codebase.
	RULE: any balance change ships as a Config change, never as a logic change.
]]

local Config = {}

Config.Version = "1.0.0"
Config.GameTitle = "Deacon's Path: Issyk-Kul"
Config.DailyLudusMinutes = 15

Config.Currency = {
	Soft     = "deniers",  -- earned from Reports, spent on Fate Rolls
	Hard     = "aspri",    -- Robux-purchased (Phase 2)
	Seasonal = "laurels",  -- LiveOps scoreboard currency (Phase 4)
}

Config.Ludus = {
	ResetHourUtc       = 0,
	MaxEnergy          = 120,
	RegenPerMinute     = 0.5,
	MissionEnergyCost  = 20,
	MissionsPerDaySoftCap = 12,
}

Config.Reports = {
	MaxHeld               = 60,
	BaseYield             = 3,
	YieldPerRelicPower    = 0.02,
	SubmitBonusMultiplier = 0.15,
	LaurelsPerFiveReports = 1,
	Regions = {
		"Karakol",
		"Cholpon-Ata",
		"Tamchy",
		"Barskoon",
		"Jeti-Oguz",
	},
}

Config.Gacha = {
	CostSingle = 25,
	CostTen    = 225,   -- 10% bundle discount, 1 guaranteed Rare+ inside applyPity
	Currency   = "deniers",

	Pity = {
		Soft = 40,   -- guarantee Epic-or-better at 40 rolls without Epic
		Hard = 80,   -- guarantee Legendary at 80 rolls without Legendary
	},

	RarityWeights = {   -- sums to 100
		Common    = 55.0,
		Uncommon  = 28.0,
		Rare      = 12.0,
		Epic      = 4.4,
		Legendary = 0.6,
	},

	DuplicateConversion = {  -- duplicates auto-convert to Soft currency
		Common    = 5,
		Uncommon  = 12,
		Rare      = 30,
		Epic      = 90,
		Legendary = 250,
	},
}

Config.Pvp = {
	DefenseSlots         = 5,
	RatingStart          = 1000,
	RatingK              = 32,
	RoundsPerMatch       = 5,
	DefenderAdvantage    = 1.05,
	MaxAttackTargets     = 8,
	MemoryStoreTtlSeconds = 3600,
	PendingQueueMax      = 20,
	HistoryMax           = 50,
	SnapshotSchemaVersion = 1,
}

Config.Limits = {
	MaxRollsPerMinute    = 20,
	MaxReportsPerMinute  = 30,
	MaxPvpPerMinute      = 10,
	MaxRemotePayloadBytes = 4096,
}

Config.Persistence = {
	StoreName          = "DeaconsPath_Profiles_v1",
	SchemaVersion      = 1,
	LockStaleSeconds   = 120,
	AutosaveInterval   = 90,
	LadderMapName      = "DeaconsPath_Ladder_S1",
	PendingMapName     = "DeaconsPath_PendingPvp_S1",
}

return Config
