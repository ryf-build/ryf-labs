--!strict

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(cooldownSeconds)
    assert(type(cooldownSeconds) == "number" and cooldownSeconds >= 0)
    return setmetatable({
        cooldownSeconds = cooldownSeconds,
        lastAt = {},
    }, RateLimiter)
end

function RateLimiter:Allow(userId)
    local now = os.clock()
    local last = self.lastAt[userId]

    if last and now - last < self.cooldownSeconds then
        return false
    end

    self.lastAt[userId] = now
    return true
end

function RateLimiter:Forget(userId)
    self.lastAt[userId] = nil
end

return RateLimiter
