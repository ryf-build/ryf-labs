--!strict

local DataService = require(script.Parent.DataService)

local PersistenceService = {}
local gates = {}

local function gateFor(player)
    local gate = gates[player.UserId]
    if not gate then
        gate = {
            busy = false,
            closing = false,
            closed = false,
            signal = Instance.new("BindableEvent"),
        }
        gates[player.UserId] = gate
    end
    return gate
end

local function acquire(gate)
    while gate.busy do
        gate.signal.Event:Wait()
    end
    gate.busy = true
end

local function release(gate)
    gate.busy = false
    gate.signal:Fire()
end

local function scheduleCleanup(player, gate)
    local userId = player.UserId
    task.delay(30, function()
        if gates[userId] == gate and gate.closed and not gate.busy then
            DataService.Forget(player)
            gate.signal:Destroy()
            gates[userId] = nil
        end
    end)
end

function PersistenceService.Save(player, stateService, force)
    local gate = gateFor(player)
    if gate.closed or gate.closing then
        return false, "closing"
    end
    if not force and not stateService.IsDirty(player) then
        return true, "clean"
    end

    acquire(gate)
    if gate.closed or gate.closing then
        release(gate)
        return false, "closing"
    end

    local snapshot = stateService.Export(player)
    if not snapshot then
        release(gate)
        return false, "not_loaded"
    end

    local ok, err = DataService.Save(player, snapshot, false)
    if ok then
        stateService.MarkSaved(player, snapshot.revision)
    end
    release(gate)
    return ok, err
end

function PersistenceService.Renew(player, stateService)
    local gate = gateFor(player)
    if gate.closed or gate.closing then
        return false, "closing"
    end

    acquire(gate)
    if gate.closed or gate.closing then
        release(gate)
        return false, "closing"
    end

    if stateService.IsDirty(player) then
        local snapshot = stateService.Export(player)
        if not snapshot then
            release(gate)
            return false, "not_loaded"
        end
        local ok, err = DataService.Save(player, snapshot, false)
        if ok then
            stateService.MarkSaved(player, snapshot.revision)
        end
        release(gate)
        return ok, err
    end

    local revision = stateService.GetRevision(player)
    if revision == nil then
        release(gate)
        return false, "not_loaded"
    end

    local ok, err = DataService.Renew(player, revision)
    release(gate)
    return ok, err
end

function PersistenceService.Close(player, stateService)
    stateService.Freeze(player)
    local gate = gateFor(player)
    gate.closing = true

    acquire(gate)
    if gate.closed then
        release(gate)
        return true, nil
    end

    local snapshot = stateService.Export(player)
    if not snapshot then
        gate.closed = true
        release(gate)
        scheduleCleanup(player, gate)
        return true, nil
    end

    local ok, err = DataService.Save(player, snapshot, true)
    if ok then
        stateService.MarkSaved(player, snapshot.revision)
        gate.closed = true
    end
    release(gate)

    if ok then
        scheduleCleanup(player, gate)
    end
    return ok, err
end

return PersistenceService
