--!strict
--[[
	EconomyService.luau — the only module allowed to mutate profile.wallet.

	Every mutation writes a ledger entry. The ring buffer is intentionally
	in-memory and bounded: it is a debugging + LiveOps signal, not a durable
	audit log. Durable analytics belong to Phase 4's event pipeline.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)

local EconomyService = {}

export type LedgerEntry = {
	userId: number,
	currency: string,
	delta: number,
	reason: string,
	balance: number,
	at: number,
}

local LEDGER_MAX = 500
local ledger: { LedgerEntry } = {}

local KEY_BY_CURRENCY: { [string]: string } = {
	[Config.Currency.Soft]     = "deniers",
	[Config.Currency.Hard]     = "aspri",
	[Config.Currency.Seasonal] = "laurels",
}

local function keyFor(currency: string): string
	local k = KEY_BY_CURRENCY[currency]
	assert(k ~= nil, "[EconomyService] unknown currency: " .. tostring(currency))
	return k
end

local function record(userId: number, currency: string, delta: number, reason: string, balance: number)
	table.insert(ledger, {
		userId = userId,
		currency = currency,
		delta = delta,
		reason = reason,
		balance = balance,
		at = os.time(),
	})
	while #ledger > LEDGER_MAX do
		table.remove(ledger, 1)
	end
end

function EconomyService.balance(profile: Types.Profile, currency: string): number
	return profile.wallet[keyFor(currency)]
end

function EconomyService.canAfford(profile: Types.Profile, currency: string, amount: number): boolean
	return profile.wallet[keyFor(currency)] >= amount
end

function EconomyService.credit(
	profile: Types.Profile,
	currency: string,
	amount: number,
	reason: string,
	userId: number?
): number
	assert(amount >= 0 and amount == amount, "[EconomyService] bad credit amount")
	local k = keyFor(currency)
	profile.wallet[k] += amount
	record(userId or 0, currency, amount, reason, profile.wallet[k])
	return profile.wallet[k]
end

function EconomyService.debit(
	profile: Types.Profile,
	currency: string,
	amount: number,
	reason: string,
	userId: number?
): boolean
	assert(amount >= 0 and amount == amount, "[EconomyService] bad debit amount")
	local k = keyFor(currency)
	if profile.wallet[k] < amount then
		return false
	end
	profile.wallet[k] -= amount
	record(userId or 0, currency, -amount, reason, profile.wallet[k])
	return true
end

function EconomyService.view(profile: Types.Profile): Types.Wallet
	return {
		deniers = profile.wallet.deniers,
		aspri   = profile.wallet.aspri,
		laurels = profile.wallet.laurels,
	}
end

function EconomyService.recent(userId: number, count: number?): { LedgerEntry }
	local limit = count or 20
	local out: { LedgerEntry } = {}
	for i = #ledger, 1, -1 do
		if ledger[i].userId == userId then
			table.insert(out, ledger[i])
			if #out >= limit then
				break
			end
		end
	end
	return out
end

return EconomyService
