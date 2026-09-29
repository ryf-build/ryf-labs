--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local services = script.Parent.Services
local PlayerStateService = require(services.PlayerStateService)
local DataService = require(services.DataService)
local PersistenceService = require(services.PersistenceService)
local CoinService = require(services.CoinService)
local MagnetService = require(services.MagnetService)
local ShopService = require(services.ShopService)
local ZoneService = require(services.ZoneService)
local ZoneGateService = require(services.ZoneGateService)
local MonetizationService = require(services.MonetizationService)
local AnalyticsAdapter = require(services.AnalyticsAdapter)
local DemoWorldService = require(services.DemoWorldService)

DemoWorldService.Ensure()

local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function getOrCreateRemoteEvent(name)
    local existing = remotes:FindFirstChild(name)
    if existing and existing:IsA("RemoteEvent") then
        return existing
    end
    if existing then
        existing:Destroy()
    end
    local remote = Instance.new("RemoteEvent")
    remote.Name = name
    remote.Parent = remotes
    return remote
end

local purchaseUpgrade = getOrCreateRemoteEvent("PurchaseUpgrade")
local unlockZone = getOrCreateRemoteEvent("UnlockZone")
local operationResult = getOrCreateRemoteEvent("OperationResult")
local stateSnapshot = getOrCreateRemoteEvent("StateSnapshot")
local requestState = getOrCreateRemoteEvent("RequestState")

local function sendSnapshot(player)
    local snapshot = PlayerStateService.GetPublicSnapshot(player)
    if snapshot then
        stateSnapshot:FireClient(player, snapshot)
    end
end

local function autosavePlayer(player)
    if not PlayerStateService.IsLoaded(player) then
        return
    end

    local ok, err
    if PlayerStateService.IsDirty(player) then
        ok, err = PersistenceService.Save(player, PlayerStateService, false)
    else
        ok, err = PersistenceService.Renew(player, PlayerStateService)
    end

    if not ok and err ~= "closing" then
        warn("AUTOSAVE_OR_RENEW_FAILED", player.UserId, err)
    end
end

local function onPlayerAdded(player)
    PlayerStateService.Create(player)

    local status, data, err = DataService.Load(player)
    if status == "FOUND" or status == "MISSING" then
        PlayerStateService.Import(player, data)
        AnalyticsAdapter.Custom(player, "profile_loaded", 1, "status=" .. status)
        AnalyticsAdapter.OnboardingStep(player, 1, "Profile Loaded")
        MonetizationService.RefreshPasses(player)

        player.CharacterAdded:Connect(function()
            task.defer(ShopService.ApplyOwnedEffects, player, PlayerStateService)
        end)
        if player.Character then
            task.defer(ShopService.ApplyOwnedEffects, player, PlayerStateService)
        end

        task.defer(sendSnapshot, player)
        return
    end

    warn("LOAD_FAILED", player.UserId, status, err)
    if status == "SESSION_CONFLICT" then
        player:Kick("Your profile is still active on another server. Please retry shortly.")
    else
        player:Kick("Your data could not be loaded safely. Please rejoin shortly.")
    end
end

local function onPlayerRemoving(player)
    if PlayerStateService.IsLoaded(player) then
        local ok, err = PersistenceService.Close(player, PlayerStateService)
        if not ok then
            warn("FINAL_SAVE_FAILED", player.UserId, err)
        end
    end
    ShopService.ForgetPlayer(player)
    ZoneService.ForgetPlayer(player)
    PlayerStateService.Remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end

purchaseUpgrade.OnServerEvent:Connect(function(player, upgradeId)
    local ok, reason = ShopService.HandlePurchase(
        player,
        upgradeId,
        PlayerStateService,
        AnalyticsAdapter
    )
    operationResult:FireClient(player, "upgrade", ok, reason)
    if ok then
        sendSnapshot(player)
    end
end)

requestState.OnServerEvent:Connect(function(player)
    sendSnapshot(player)
end)

unlockZone.OnServerEvent:Connect(function(player, zoneId)
    local ok, reason = ZoneService.TryUnlock(
        player,
        zoneId,
        PlayerStateService,
        AnalyticsAdapter
    )
    operationResult:FireClient(player, "zone", ok, reason)
    if ok then
        sendSnapshot(player)
    end
end)

for _, coin in CollectionService:GetTagged("Coin") do
    CoinService.ConnectCoin(coin, PlayerStateService, AnalyticsAdapter, sendSnapshot)
end
CollectionService:GetInstanceAddedSignal("Coin"):Connect(function(coin)
    CoinService.ConnectCoin(coin, PlayerStateService, AnalyticsAdapter, sendSnapshot)
end)

MagnetService.Start(PlayerStateService, CoinService, AnalyticsAdapter, sendSnapshot)
ZoneGateService.Start(PlayerStateService)
MonetizationService.Start(PlayerStateService, PersistenceService, AnalyticsAdapter, sendSnapshot)

task.spawn(function()
    while true do
        task.wait(55 + math.random() * 10)
        for _, player in Players:GetPlayers() do
            task.spawn(autosavePlayer, player)
        end
    end
end)

game:BindToClose(function()
    local pending = 0
    local done = Instance.new("BindableEvent")

    for _, player in Players:GetPlayers() do
        pending += 1
        task.spawn(function()
            if PlayerStateService.IsLoaded(player) then
                local ok, err = PersistenceService.Close(player, PlayerStateService)
                if not ok then
                    warn("SHUTDOWN_SAVE_FAILED", player.UserId, err)
                end
            end
            pending -= 1
            if pending == 0 then
                done:Fire()
            end
        end)
    end

    if pending > 0 then
        local completed = false
        local connection
        connection = done.Event:Connect(function()
            completed = true
            connection:Disconnect()
        end)

        local started = os.clock()
        while not completed and os.clock() - started < 20 do
            task.wait(0.1)
        end
    end

    done:Destroy()
end)
