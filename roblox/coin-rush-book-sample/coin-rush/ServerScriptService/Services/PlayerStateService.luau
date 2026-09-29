--!strict

local PlayerStateService = {}
local states = {}

local function deepCopy(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = if type(value) == "table" then deepCopy(value) else value
    end
    return copy
end

local function newState()
    return {
        coins = 0,
        upgrades = {},
        unlockedZones = { Zone1 = true },
        processedPurchases = {},
        dataVersion = 3,
        revision = 0,
        lastSavedRevision = 0,
        loaded = false,
        frozen = false,
    }
end

local function touch(state)
    state.revision += 1
end

local function canMutate(state)
    return state ~= nil and state.loaded == true and state.frozen ~= true
end

function PlayerStateService.Create(player)
    local state = newState()
    states[player.UserId] = state
    return state
end

function PlayerStateService.Import(player, data)
    local state = newState()
    state.coins = data.coins
    state.upgrades = deepCopy(data.upgrades)
    state.unlockedZones = deepCopy(data.unlockedZones)
    state.processedPurchases = deepCopy(data.processedPurchases or {})
    state.dataVersion = data.dataVersion
    state.revision = tonumber(data.revision) or 0
    state.lastSavedRevision = state.revision
    state.loaded = true
    states[player.UserId] = state
    return state
end

function PlayerStateService.Get(player)
    return states[player.UserId]
end

function PlayerStateService.IsLoaded(player)
    local state = states[player.UserId]
    return state ~= nil and state.loaded == true
end

function PlayerStateService.GetRevision(player)
    local state = states[player.UserId]
    return state and state.revision or nil
end

function PlayerStateService.Export(player)
    local state = states[player.UserId]
    if not state or not state.loaded then
        return nil
    end

    return {
        coins = state.coins,
        upgrades = deepCopy(state.upgrades),
        unlockedZones = deepCopy(state.unlockedZones),
        processedPurchases = deepCopy(state.processedPurchases),
        dataVersion = state.dataVersion,
        revision = state.revision,
    }
end

function PlayerStateService.GetPublicSnapshot(player)
    local state = states[player.UserId]
    if not state or not state.loaded then
        return nil
    end

    return {
        coins = state.coins,
        upgrades = deepCopy(state.upgrades),
        unlockedZones = deepCopy(state.unlockedZones),
        supporterPass = player:GetAttribute("HasSupporterPass") == true,
    }
end

function PlayerStateService.Remove(player)
    states[player.UserId] = nil
end

function PlayerStateService.GetCoins(player)
    local state = states[player.UserId]
    return state and state.coins or 0
end

function PlayerStateService.AddCoins(player, amount)
    if type(amount) ~= "number" or amount <= 0 or amount ~= math.floor(amount) then
        return false, "invalid_amount"
    end

    local state = states[player.UserId]
    if not canMutate(state) then
        return false, if state and state.frozen then "frozen" else "not_loaded"
    end

    state.coins += amount
    touch(state)
    return true, state.coins
end

function PlayerStateService.TrySpendCoins(player, amount)
    if type(amount) ~= "number" or amount < 0 or amount ~= math.floor(amount) then
        return false, "invalid_amount"
    end

    local state = states[player.UserId]
    if not canMutate(state) then
        return false, if state and state.frozen then "frozen" else "not_loaded"
    end
    if state.coins < amount then
        return false, "insufficient_funds"
    end

    state.coins -= amount
    touch(state)
    return true, state.coins
end

function PlayerStateService.GetUpgradeLevel(player, upgradeId)
    local state = states[player.UserId]
    if not state or not state.loaded then
        return nil
    end
    return state.upgrades[upgradeId] or 0
end

function PlayerStateService.TryPurchaseUpgrade(player, upgradeId, expectedLevel, price)
    local state = states[player.UserId]
    if not canMutate(state) then
        return false, if state and state.frozen then "frozen" else "not_loaded"
    end

    local currentLevel = state.upgrades[upgradeId] or 0
    if currentLevel ~= expectedLevel then
        return false, "stale_level"
    end
    if state.coins < price then
        return false, "insufficient_funds"
    end

    state.coins -= price
    state.upgrades[upgradeId] = currentLevel + 1
    touch(state)

    return true, {
        level = currentLevel + 1,
        coins = state.coins,
    }
end

function PlayerStateService.HasZone(player, zoneId)
    local state = states[player.UserId]
    return state ~= nil and state.unlockedZones[zoneId] == true
end

function PlayerStateService.TryUnlockZone(player, zoneId, expectedCost)
    local state = states[player.UserId]
    if not canMutate(state) then
        return false, if state and state.frozen then "frozen" else "not_loaded"
    end
    if state.unlockedZones[zoneId] == true then
        return true, "already_unlocked"
    end
    if type(expectedCost) ~= "number" or expectedCost < 0 or expectedCost ~= math.floor(expectedCost) then
        return false, "invalid_cost"
    end
    if state.coins < expectedCost then
        return false, "insufficient_funds"
    end

    state.coins -= expectedCost
    state.unlockedZones[zoneId] = true
    touch(state)
    return true, "unlocked"
end

function PlayerStateService.ApplyDeveloperProduct(player, purchaseId, productId, grantType, amount)
    local state = states[player.UserId]
    if not canMutate(state) then
        return false, if state and state.frozen then "frozen" else "not_loaded", nil
    end
    if type(purchaseId) ~= "string" or purchaseId == "" then
        return false, "invalid_purchase_id", nil
    end

    local existing = state.processedPurchases[purchaseId]
    if existing then
        return true, "already_applied", state.revision
    end

    if grantType == "coins" then
        if type(amount) ~= "number" or amount <= 0 or amount ~= math.floor(amount) then
            return false, "invalid_grant", nil
        end
        state.coins += amount
    else
        return false, "unknown_grant_type", nil
    end

    state.processedPurchases[purchaseId] = {
        productId = productId,
        grantType = grantType,
        amount = amount,
        grantedAt = os.time(),
    }
    touch(state)
    return true, "applied", state.revision
end

function PlayerStateService.Freeze(player)
    local state = states[player.UserId]
    if state then
        state.frozen = true
    end
end

function PlayerStateService.MarkSaved(player, savedRevision)
    local state = states[player.UserId]
    if not state or type(savedRevision) ~= "number" then
        return
    end
    if savedRevision > state.lastSavedRevision then
        state.lastSavedRevision = math.min(savedRevision, state.revision)
    end
end

function PlayerStateService.IsDirty(player)
    local state = states[player.UserId]
    return state ~= nil and state.loaded == true and state.revision > state.lastSavedRevision
end

return PlayerStateService
