--!strict

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local DataService = {}

local STORE_NAME = "CoinRush_PlayerData"
local CURRENT_VERSION = 3
local MAX_RETRIES = 4
local LEASE_SECONDS = 180
local store = DataStoreService:GetDataStore(STORE_NAME)

local serverId = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)
local keyLocks = {}

local function keyFor(player)
    return "player_" .. tostring(player.UserId)
end

local function sessionFor(player)
    return serverId .. ":" .. tostring(player.UserId)
end

local function deepCopy(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = if type(value) == "table" then deepCopy(value) else value
    end
    return copy
end

local function newDefaultData()
    return {
        coins = 0,
        upgrades = {},
        unlockedZones = { Zone1 = true },
        processedPurchases = {},
        dataVersion = CURRENT_VERSION,
        revision = 0,
    }
end

local function migrate(raw)
    if type(raw) ~= "table" then
        return nil, nil, "invalid_root"
    end

    local data = deepCopy(raw)
    local meta = data._meta
    data._meta = nil

    local version = tonumber(data.dataVersion) or 1
    if version > CURRENT_VERSION then
        return nil, nil, "future_version"
    end

    if version == 1 then
        data.unlockedZones = data.unlockedZones or { Zone1 = true }
        data.dataVersion = 2
        version = 2
    end

    if version == 2 then
        local converted = {}
        if type(data.upgrades) == "table" then
            for upgradeId, value in pairs(data.upgrades) do
                if type(value) == "number" then
                    converted[upgradeId] = math.max(0, math.floor(value))
                elseif value == true then
                    converted[upgradeId] = 1
                end
            end
        end
        data.upgrades = converted
        data.dataVersion = 3
        version = 3
    end

    if version ~= CURRENT_VERSION then
        return nil, nil, "migration_incomplete"
    end
    if type(data.coins) ~= "number" or data.coins < 0 then
        return nil, nil, "invalid_coins"
    end
    if type(data.upgrades) ~= "table" then
        return nil, nil, "invalid_upgrades"
    end
    if type(data.unlockedZones) ~= "table" then
        return nil, nil, "invalid_zones"
    end

    data.coins = math.floor(data.coins)
    data.unlockedZones.Zone1 = true
    data.processedPurchases = if type(data.processedPurchases) == "table" then data.processedPurchases else {}
    data.revision = math.max(0, math.floor(tonumber(data.revision) or 0))
    return data, meta, nil
end

local function withRetry(operation)
    local lastError = nil
    for attempt = 1, MAX_RETRIES do
        local ok, result = pcall(operation)
        if ok then
            return true, result, nil
        end

        lastError = result
        if attempt < MAX_RETRIES then
            local backoff = (2 ^ (attempt - 1)) * 0.25
            local jitter = math.random() * 0.2
            task.wait(backoff + jitter)
        end
    end
    return false, nil, lastError
end

local function acquireKeyLock(key)
    local lock = keyLocks[key]
    if not lock then
        lock = {
            busy = false,
            signal = Instance.new("BindableEvent"),
        }
        keyLocks[key] = lock
    end

    while lock.busy do
        lock.signal.Event:Wait()
    end
    lock.busy = true

    return function()
        lock.busy = false
        lock.signal:Fire()
    end
end

local function withKeyLock(key, operation)
    local release = acquireKeyLock(key)
    local ok, packedOrError = pcall(function()
        return table.pack(operation())
    end)
    release()

    if not ok then
        error(packedOrError)
    end
    return table.unpack(packedOrError, 1, packedOrError.n)
end

local function makeRecord(data, sessionId, revision, releaseSession)
    local record = deepCopy(data)
    record._meta = {
        sessionId = if releaseSession then nil else sessionId,
        leaseExpiresAt = if releaseSession then 0 else os.time() + LEASE_SECONDS,
        revision = revision,
    }
    return record
end

function DataService.Load(player)
    local key = keyFor(player)
    local sessionId = sessionFor(player)

    return withKeyLock(key, function()
        local initiallyMissing = nil
        local transformError = nil

        local ok, record, err = withRetry(function()
            return store:UpdateAsync(key, function(current)
                initiallyMissing = current == nil

                local data
                local meta
                if current == nil then
                    data = newDefaultData()
                    meta = nil
                else
                    data, meta, transformError = migrate(current)
                    if not data then
                        return current
                    end
                end

                local now = os.time()
                meta = if type(meta) == "table" then meta else {}
                local owner = meta.sessionId
                local leaseExpiresAt = tonumber(meta.leaseExpiresAt) or 0

                if owner and owner ~= sessionId and leaseExpiresAt > now then
                    return current
                end

                return makeRecord(data, sessionId, data.revision, false)
            end)
        end)

        if not ok then
            return "RETRYABLE_ERROR", nil, err
        end
        if transformError then
            return "FATAL_ERROR", nil, transformError
        end
        if type(record) ~= "table" then
            return "FATAL_ERROR", nil, "invalid_record"
        end

        local meta = record._meta
        if type(meta) ~= "table" or meta.sessionId ~= sessionId then
            return "SESSION_CONFLICT", nil, "active_session_exists"
        end

        local data, _, migrationError = migrate(record)
        if not data then
            return "FATAL_ERROR", nil, migrationError
        end

        return if initiallyMissing then "MISSING" else "FOUND", data, nil
    end)
end

function DataService.Save(player, snapshot, releaseSession)
    if type(snapshot) ~= "table" or snapshot.dataVersion ~= CURRENT_VERSION then
        return false, "invalid_snapshot"
    end
    if type(snapshot.revision) ~= "number" then
        return false, "missing_revision"
    end

    local key = keyFor(player)
    local sessionId = sessionFor(player)

    return withKeyLock(key, function()
        local rejectReason = nil
        local ok, _, err = withRetry(function()
            return store:UpdateAsync(key, function(current)
                if type(current) ~= "table" then
                    rejectReason = "missing_current_record"
                    return current
                end

                local _, meta, migrationError = migrate(current)
                if migrationError then
                    rejectReason = migrationError
                    return current
                end
                meta = if type(meta) == "table" then meta else {}

                if meta.sessionId ~= sessionId then
                    rejectReason = "session_mismatch"
                    return current
                end

                local persistedRevision = tonumber(meta.revision) or 0
                if snapshot.revision < persistedRevision then
                    rejectReason = "stale_revision"
                    return current
                end

                rejectReason = nil
                return makeRecord(snapshot, sessionId, snapshot.revision, releaseSession == true)
            end)
        end)

        if not ok then
            return false, err
        end
        if rejectReason then
            return false, rejectReason
        end
        return true, nil
    end)
end

function DataService.Renew(player, currentRevision)
    local key = keyFor(player)
    local sessionId = sessionFor(player)

    return withKeyLock(key, function()
        local rejectReason = nil
        local ok, _, err = withRetry(function()
            return store:UpdateAsync(key, function(current)
                if type(current) ~= "table" or type(current._meta) ~= "table" then
                    rejectReason = "missing_session_metadata"
                    return current
                end
                if current._meta.sessionId ~= sessionId then
                    rejectReason = "session_mismatch"
                    return current
                end

                current._meta.leaseExpiresAt = os.time() + LEASE_SECONDS
                current._meta.revision = math.max(
                    tonumber(current._meta.revision) or 0,
                    tonumber(currentRevision) or 0
                )
                rejectReason = nil
                return current
            end)
        end)

        if not ok then
            return false, err
        end
        if rejectReason then
            return false, rejectReason
        end
        return true, nil
    end)
end

function DataService.Forget(player)
    local key = keyFor(player)
    local lock = keyLocks[key]
    if lock and not lock.busy then
        lock.signal:Destroy()
        keyLocks[key] = nil
        return true
    end
    return false
end

DataService.CURRENT_VERSION = CURRENT_VERSION
DataService.LEASE_SECONDS = LEASE_SECONDS
return DataService
