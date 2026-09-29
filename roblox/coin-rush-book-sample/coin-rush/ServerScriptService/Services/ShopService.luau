--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Upgrades = require(ReplicatedStorage.Shared.UpgradeDefinitions)
local RateLimiter = require(script.Parent.Parent.Infrastructure.RateLimiter)

local ShopService = {}
local limiter = RateLimiter.new(0.25)

local function priceFor(definition, level)
    return math.floor(definition.basePrice * (definition.growth ^ level))
end

local function applyUpgradeEffects(player, stateService)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    local speedDefinition = Upgrades.speed
    local speedLevel = stateService.GetUpgradeLevel(player, "speed") or 0
    humanoid.WalkSpeed = speedDefinition.baseWalkSpeed
        + speedDefinition.walkSpeedPerLevel * speedLevel
end

function ShopService.ApplyOwnedEffects(player, stateService)
    applyUpgradeEffects(player, stateService)
end

function ShopService.HandlePurchase(player, upgradeId, stateService, analyticsAdapter)
    if not limiter:Allow(player.UserId) then
        return false, "rate_limited"
    end
    if type(upgradeId) ~= "string" then
        return false, "invalid_type"
    end

    local definition = Upgrades[upgradeId]
    if not definition then
        return false, "unknown_upgrade"
    end

    local currentLevel = stateService.GetUpgradeLevel(player, upgradeId)
    if currentLevel == nil then
        return false, "not_loaded"
    end
    if currentLevel >= definition.maxLevel then
        return false, "max_level"
    end

    local price = priceFor(definition, currentLevel)
    local ok, result = stateService.TryPurchaseUpgrade(player, upgradeId, currentLevel, price)
    if not ok then
        return false, result
    end

    applyUpgradeEffects(player, stateService)
    analyticsAdapter.Custom(
        player,
        "upgrade_purchased",
        price,
        "upgrade=" .. upgradeId,
        "level=" .. tostring(result.level)
    )
    analyticsAdapter.Economy(
        player,
        Enum.AnalyticsEconomyFlowType.Sink,
        price,
        result.coins,
        Enum.AnalyticsEconomyTransactionType.Shop.Name,
        "upgrade:" .. upgradeId,
        "level=" .. tostring(result.level)
    )
    analyticsAdapter.OnboardingStep(player, 3, "First Upgrade")

    return true, result
end

function ShopService.ForgetPlayer(player)
    limiter:Forget(player.UserId)
end

return ShopService
