--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local Upgrades = require(ReplicatedStorage.Shared.UpgradeDefinitions)
local Zones = require(ReplicatedStorage.Shared.ZoneDefinitions)
local Products = require(ReplicatedStorage.Shared.ProductDefinitions)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local purchaseUpgrade = remotes:WaitForChild("PurchaseUpgrade")
local unlockZone = remotes:WaitForChild("UnlockZone")
local operationResult = remotes:WaitForChild("OperationResult")
local stateSnapshot = remotes:WaitForChild("StateSnapshot")
local requestState = remotes:WaitForChild("RequestState")

local gui = Instance.new("ScreenGui")
gui.Name = "CoinRushUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("ScrollingFrame")
panel.Name = "Panel"
panel.Size = UDim2.new(0.88, 0, 0.78, 0)
panel.Position = UDim2.fromOffset(12, 12)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
panel.CanvasSize = UDim2.new()
panel.ScrollBarThickness = 6
panel.Parent = gui

local panelConstraint = Instance.new("UISizeConstraint")
panelConstraint.MinSize = Vector2.new(240, 260)
panelConstraint.MaxSize = Vector2.new(360, 520)
panelConstraint.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = panel

local function makeLabel(text, height)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, height or 34)
    label.BackgroundTransparency = 1
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Text = text
    label.Parent = panel
    return label
end

local function makeButton(text)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 44)
    button.TextWrapped = true
    button.Text = text
    button.Parent = panel
    return button
end

local coinsLabel = makeLabel("Coins: ...", 42)
local statusLabel = makeLabel("Loading profile...", 48)
local speedButton = makeButton("Upgrade Move Speed")
local magnetButton = makeButton("Upgrade Magnet")
local zone2Button = makeButton("Unlock Zone 2")
local zone3Button = makeButton("Unlock Zone 3")
local productButton = makeButton("Buy Coin Pack")
local passButton = makeButton("Buy Supporter Pass")

local latestState = nil
local pendingUpgrade = false
local pendingZone = false
local supporterBaseText = "Buy Supporter Pass"

local function priceFor(definition, level)
    return math.floor(definition.basePrice * (definition.growth ^ level))
end

local function redraw()
    if not latestState then
        return
    end

    coinsLabel.Text = string.format("Coins: %d", latestState.coins or 0)
    local speedLevel = latestState.upgrades.speed or 0
    local magnetLevel = latestState.upgrades.magnet or 0
    speedButton.Text = string.format(
        "Move Speed Lv.%d → %d Coins",
        speedLevel,
        priceFor(Upgrades.speed, speedLevel)
    )
    magnetButton.Text = string.format(
        "Magnet Lv.%d → %d Coins",
        magnetLevel,
        priceFor(Upgrades.magnet, magnetLevel)
    )

    zone2Button.Visible = latestState.unlockedZones.Zone2 ~= true
    zone3Button.Visible = latestState.unlockedZones.Zone3 ~= true
    passButton.Text = if latestState.supporterPass then "Supporter Pass: owned" else supporterBaseText
    passButton.Active = latestState.supporterPass ~= true
end

local function requestUpgrade(upgradeId)
    if pendingUpgrade then
        return
    end
    pendingUpgrade = true
    purchaseUpgrade:FireServer(upgradeId)
end

speedButton.Activated:Connect(function()
    requestUpgrade("speed")
end)
magnetButton.Activated:Connect(function()
    requestUpgrade("magnet")
end)

zone2Button.Activated:Connect(function()
    if not pendingZone then
        pendingZone = true
        unlockZone:FireServer("Zone2")
    end
end)
zone3Button.Activated:Connect(function()
    if not pendingZone then
        pendingZone = true
        unlockZone:FireServer("Zone3")
    end
end)

local product = Products.developerProducts.coinPackSmall
if product and product.productId ~= 0 then
    task.spawn(function()
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfoAsync(product.productId, Enum.InfoType.Product)
        end)
        if ok and info.PriceInRobux then
            productButton.Text = string.format("%s — %d R$", product.displayName, info.PriceInRobux)
        else
            productButton.Text = product.displayName
        end
    end)
    productButton.Activated:Connect(function()
        MarketplaceService:PromptProductPurchase(player, product.productId)
    end)
else
    productButton.Visible = false
end

local supporter = Products.passes.supporter
if supporter and supporter.passId ~= 0 then
    task.spawn(function()
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfoAsync(supporter.passId, Enum.InfoType.GamePass)
        end)
        if ok and info.PriceInRobux then
            supporterBaseText = string.format("%s — %d R$", supporter.displayName, info.PriceInRobux)
        else
            supporterBaseText = supporter.displayName
        end
        redraw()
    end)
    passButton.Activated:Connect(function()
        if latestState and latestState.supporterPass then
            return
        end
        MarketplaceService:PromptGamePassPurchase(player, supporter.passId)
    end)
else
    passButton.Visible = false
end

stateSnapshot.OnClientEvent:Connect(function(snapshot)
    latestState = snapshot
    statusLabel.Text = "Ready"
    redraw()
end)

operationResult.OnClientEvent:Connect(function(kind, ok, reason)
    if kind == "upgrade" then
        pendingUpgrade = false
    elseif kind == "zone" then
        pendingZone = false
    end
    statusLabel.Text = if ok then "Success" else "Failed: " .. tostring(reason)
end)

requestState:FireServer()
