--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.ZoneDefinitions)
local RateLimiter = require(script.Parent.Parent.Infrastructure.RateLimiter)

local ZoneService = {}
local limiter = RateLimiter.new(0.5)

function ZoneService.TryUnlock(player, zoneId, stateService, analyticsAdapter)
    if not limiter:Allow(player.UserId) then
        return false, "rate_limited"
    end
    if type(zoneId) ~= "string" then
        return false, "invalid_type"
    end

    local zone = Zones[zoneId]
    if not zone then
        return false, "unknown_zone"
    end
    if stateService.HasZone(player, zoneId) then
        return true, "already_unlocked"
    end
    if zone.requires and not stateService.HasZone(player, zone.requires) then
        return false, "prerequisite_missing"
    end

    local ok, reason = stateService.TryUnlockZone(player, zoneId, zone.unlockCost)
    if not ok then
        return false, reason
    end

    analyticsAdapter.Custom(player, "zone_unlocked", zone.order, "zone=" .. zoneId)
    if zone.unlockCost > 0 then
        analyticsAdapter.Economy(
            player,
            Enum.AnalyticsEconomyFlowType.Sink,
            zone.unlockCost,
            stateService.GetCoins(player),
            Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
            "zone:" .. zoneId
        )
    end
    if zoneId == "Zone2" then
        analyticsAdapter.OnboardingStep(player, 4, "Zone 2 Unlocked")
    end
    return true, reason
end

function ZoneService.ForgetPlayer(player)
    limiter:Forget(player.UserId)
end

return ZoneService
