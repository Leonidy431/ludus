--!strict
--[[
	RelicCatalog.luau — static relic definitions.

	Relics are the only "power" object in Phase 1. They feed:
	  · Report yield   (Config.Reports.YieldPerRelicPower)
	  · Async PvP defense power
	  · Future LiveOps quest requirements (Phase 4)
]]

local Types = require(script.Parent.Types)

export type RelicDef = {
	id: string,
	name: string,
	rarity: Types.Rarity,
	basePower: number,
	description: string,
}

local Catalog: { [string]: RelicDef } = {}
local ByRarity: { [string]: { string } } = {
	Common = {}, Uncommon = {}, Rare = {}, Epic = {}, Legendary = {},
}

local function define(def: RelicDef)
	assert(Catalog[def.id] == nil, "[RelicCatalog] duplicate id: " .. def.id)
	assert(ByRarity[def.rarity] ~= nil, "[RelicCatalog] bad rarity: " .. def.rarity)
	Catalog[def.id] = def
	table.insert(ByRarity[def.rarity], def.id)
end

-- ── Common ───────────────────────────────────────────────────────────────
define({ id = "tin_icon",       name = "Tin Icon",          rarity = "Common",    basePower = 5,   description = "A pressed-metal face of an unnamed saint." })
define({ id = "worn_psalter",   name = "Worn Psalter",      rarity = "Common",    basePower = 5,   description = "Water-damaged. Still legible at the margins." })
define({ id = "cracked_censer", name = "Cracked Censer",    rarity = "Common",    basePower = 6,   description = "Smells faintly of pine resin and ozone." })
define({ id = "wooden_cross",   name = "Steppe Cross",      rarity = "Common",    basePower = 5,   description = "Carved from a fencepost by a hurried hand." })
define({ id = "ledger_fragment",name = "Ledger Fragment",   rarity = "Common",    basePower = 7,   description = "Half a page. Three names remain." })

-- ── Uncommon ─────────────────────────────────────────────────────────────
define({ id = "iron_cross",     name = "Iron Cross",        rarity = "Uncommon",  basePower = 12,  description = "Cold to the touch even in sun." })
define({ id = "star_chart",     name = "Folded Star Chart", rarity = "Uncommon",  basePower = 13,  description = "Annotations in a script that is not local." })
define({ id = "salt_crystal",   name = "Lake Salt Crystal", rarity = "Uncommon",  basePower = 12,  description = "Issyk-Kul gives, Issyk-Kul keeps." })
define({ id = "silver_censer",  name = "Silver Censer",     rarity = "Uncommon",  basePower = 14,  description = "Rings a note that disrupts the hum." })
define({ id = "barskoon_map",   name = "Barskoon Waybook",  rarity = "Uncommon",  basePower = 12,  description = "Marks caravan stops the aliens have since erased." })

-- ── Rare ─────────────────────────────────────────────────────────────────
define({ id = "bronze_reliquary", name = "Bronze Reliquary", rarity = "Rare",     basePower = 30,  description = "Sealed. The contents answer to no one." })
define({ id = "steppe_katana",    name = "Steppe Katana",    rarity = "Rare",     basePower = 34,  description = "A blade that has never known a blacksmith's regret." })
define({ id = "emerald_amulet",   name = "Emerald Amulet",   rarity = "Rare",     basePower = 31,  description = "Pulses when the thermocline shifts." })
define({ id = "thermal_lance",    name = "Thermal Lance",    rarity = "Rare",     basePower = 33,  description = "Reads the deep water before you do." })
define({ id = "icon_of_lake",     name = "Icon of the Lake", rarity = "Rare",     basePower = 32,  description = "Painted on a boat's hull-plank. Survived the fire." })

-- ── Epic ─────────────────────────────────────────────────────────────────
define({ id = "relic_barsabas",   name = "Relic of St. Barsabas", rarity = "Epic", basePower = 80,  description = "The deacon who walked into the water and returned." })
define({ id = "ion_compass",      name = "Ion Compass",           rarity = "Epic", basePower = 84,  description = "Points not north, but *toward*." })
define({ id = "golden_paiza",     name = "Golden Paiza",          rarity = "Epic", basePower = 82,  description = "Safe-conduct of a khan who no longer exists." })
define({ id = "blade_cholpon",    name = "Blade of Cholpon",      rarity = "Epic", basePower = 86,  description = "Etched with stars that were not there before." })

-- ── Legendary ────────────────────────────────────────────────────────────
define({ id = "deacons_path",     name = "The Deacon's Path",     rarity = "Legendary", basePower = 220, description = "You are not the first to walk it. You are the first to survive." })
define({ id = "azure_monstrance", name = "Azure Monstrance",      rarity = "Legendary", basePower = 228, description = "Its rays bend around the thermocline." })
define({ id = "khans_truth",      name = "The Khan's Truth",      rarity = "Legendary", basePower = 224, description = "A document that rewrites itself when witnessed." })
define({ id = "chalice_issyk",    name = "Chalice of Issyk-Kul",  rarity = "Legendary", basePower = 235, description = "Filled with something warmer than water." })

local RelicCatalog = {}

RelicCatalog.Items    = Catalog
RelicCatalog.ByRarity = ByRarity

function RelicCatalog.get(id: string): RelicDef?
	return Catalog[id]
end

function RelicCatalog.pick(rarity: string, rng: Random): RelicDef
	local pool = ByRarity[rarity]
	assert(pool ~= nil and #pool > 0, "[RelicCatalog] empty rarity pool: " .. tostring(rarity))
	local idx = rng:NextInteger(1, #pool)
	return Catalog[pool[idx]]
end

return RelicCatalog
