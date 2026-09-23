--!strict
--[[
	Types.luau — shared type surface for Roblox GaaS (Phase 1).
	Type-only module: returns an empty table so it can be `require`d
	alongside type exports (Luau pattern: `local T = require(..); local x: T.Profile`).
]]

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type RelicInstance = {
	uid: string,
	catalogId: string,
	rarity: Rarity,
	power: number,
	obtainedAt: number,
	locked: boolean,
}

export type Report = {
	uid: string,
	region: string,
	value: number,
	createdAt: number,
}

export type Wallet = {
	deniers: number,
	aspri: number,
	laurels: number,
}

export type PityState = {
	counter: number,
	sinceEpic: number,
	sinceLegendary: number,
}

export type Stats = {
	reportsCollected: number,
	fateRolls: number,
	pvpWins: number,
	pvpLosses: number,
	pvpRating: number,
	season: number,
}

export type PvpRecord = {
	opponentUserId: number,
	opponentName: string,
	won: boolean,          -- from the perspective of the record owner
	ratingDelta: number,
	at: number,
}

export type Profile = {
	schemaVersion: number,
	createdAt: number,
	lastSeen: number,
	lastEnergyAt: number,
	lastLudusDay: number,

	wallet: Wallet,
	energy: number,

	relics: { [string]: RelicInstance },
	defenseTeam: { string },
	reports: { Report },

	pity: PityState,
	stats: Stats,
	history: { PvpRecord },

	seasonal: { [string]: number },

	sessionLock: { jobId: string, at: number }?,
}

-- What the client receives. Deliberately a projection, never the raw profile.
export type ClientState = {
	wallet: Wallet,
	energy: number,
	maxEnergy: number,
	relicCount: number,
	defenseTeam: { string },
	pity: PityState,
	stats: Stats,
	lastLudusDay: number,
	dayIndex: number,
}

export type AttackSnapshot = {
	schemaVersion: number,
	userId: number,
	displayName: string,
	rating: number,
	takenAt: number,
	power: number,
	relics: { { catalogId: string, rarity: Rarity, power: number } },
}

return {}
