--!strict

local Players = game:GetService("Players")

local CoinService = {}
local coinStates = setmetatable({}, { __mode = "k" })

local function playerFromHit(hit)
    local character = hit:FindFirstAncestorOfClass("Model")
    if not character then
        return nil
    end
    return Players:GetPlayerFromCharacter(character)
end

local function hideCoin(coin, state)
    coin.Transparency = 1
    coin.CanTouch = false
    coin.CanCollide = false
    coin.CanQuery = false
    state.available = false
end

local function showCoin(coin, state)
    if not coin.Parent then
        return
    end
    coin.Transparency = state.transparency
    coin.CanTouch = state.canTouch
    coin.CanCollide = state.canCollide
    coin.CanQuery = state.canQuery
    state.available = true
end

function CoinService.TryCollect(coin, player, playerStateService, analyticsAdapter, maxDistance, onChanged)
    local state = coinStates[coin]
    if not state or not state.available then
        return false, "unavailable"
    end
    if not playerStateService.IsLoaded(player) then
        return false, "not_loaded"
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return false, "no_character"
    end

    local allowedDistance = math.max(4, tonumber(maxDistance) or 16)
    if (root.Position - coin.Position).Magnitude > allowedDistance then
        return false, "too_far"
    end

    local value = coin:GetAttribute("CoinValue") or 10
    if type(value) ~= "number" or value <= 0 or value > 1000 then
        warn("Invalid CoinValue", coin:GetFullName(), value)
        return false, "invalid_value"
    end

    state.available = false
    local ok, totalOrReason = playerStateService.AddCoins(player, math.floor(value))
    if not ok then
        state.available = true
        return false, totalOrReason
    end

    hideCoin(coin, state)
    local source = tostring(coin:GetAttribute("Source") or "world")
    analyticsAdapter.Custom(player, "coin_collected", value, "source=" .. source)
    analyticsAdapter.Economy(
        player,
        Enum.AnalyticsEconomyFlowType.Source,
        value,
        totalOrReason,
        Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
        "coin:" .. source
    )
    analyticsAdapter.OnboardingStep(player, 2, "First Coin")

    if onChanged then
        onChanged(player)
    end

    local respawnSeconds = tonumber(coin:GetAttribute("RespawnSeconds")) or 4
    task.delay(math.clamp(respawnSeconds, 0.25, 300), function()
        showCoin(coin, state)
    end)

    return true, totalOrReason
end

function CoinService.ConnectCoin(coin, playerStateService, analyticsAdapter, onChanged)
    if not coin:IsA("BasePart") or coinStates[coin] then
        return
    end

    local state = {
        available = true,
        transparency = coin.Transparency,
        canTouch = coin.CanTouch,
        canCollide = coin.CanCollide,
        canQuery = coin.CanQuery,
    }
    coinStates[coin] = state

    coin.Touched:Connect(function(hit)
        local player = playerFromHit(hit)
        if not player then
            return
        end
        CoinService.TryCollect(coin, player, playerStateService, analyticsAdapter, 16, onChanged)
    end)
end

function CoinService.IsAvailable(coin)
    local state = coinStates[coin]
    return state ~= nil and state.available == true
end

return CoinService
