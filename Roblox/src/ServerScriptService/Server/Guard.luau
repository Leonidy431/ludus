--!strict
--[[
	Guard.luau — server-side input hardening.

	Every RemoteEvent / RemoteFunction argument passes through here.
	Never trust a client. Never assume a client is malicious *or* benign:
	assume it is a robot with a debugger.
]]

local Players = game:GetService("Players")

local Guard = {}

type Bucket = { count: number, resetAt: number }

local buckets: { [Player]: { [string]: Bucket } } = {}

local function bucketFor(player: Player, key: string): Bucket
	local byKey = buckets[player]
	if not byKey then
		byKey = {}
		buckets[player] = byKey
	end
	local b = byKey[key]
	if not b then
		b = { count = 0, resetAt = os.clock() + 60 }
		byKey[key] = b
	end
	return b
end

-- Returns true if the action is allowed, false if rate-limited.
function Guard.consume(player: Player, key: string, limitPerMinute: number): boolean
	local b = bucketFor(player, key)
	local now = os.clock()
	if now >= b.resetAt then
		b.count = 0
		b.resetAt = now + 60
	end
	if b.count >= limitPerMinute then
		warn(("[Guard] rate-limited %s on %s"):format(player.Name, key))
		return false
	end
	b.count += 1
	return true
end

function Guard.isFiniteNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function Guard.isInt(v: any): boolean
	return Guard.isFiniteNumber(v) and (v :: number) % 1 == 0
end

function Guard.isStringId(v: any, maxLen: number?): boolean
	local limit = maxLen or 64
	return type(v) == "string" and #v > 0 and #v <= limit
end

-- Asserting variants: use when an invalid value is a hard protocol violation.
function Guard.expectStringId(v: any, maxLen: number?): string
	assert(Guard.isStringId(v, maxLen), "[Guard] expected string id")
	return v :: string
end

function Guard.expectInt(v: any): number
	assert(Guard.isInt(v), "[Guard] expected integer")
	return v :: number
end

function Guard.release(player: Player)
	buckets[player] = nil
end

Players.PlayerRemoving:Connect(Guard.release)

return Guard
