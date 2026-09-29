--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Upgrades = require(ReplicatedStorage.Shared.UpgradeDefinitions)

local MagnetService = {}
local started = false

function MagnetService.Start(playerStateService, coinService, analyticsAdapter, onChanged)
    if started then
        return
    end
    started = true

    task.spawn(function()
        while true do
            task.wait(0.25)
            for _, player in Players:GetPlayers() do
                if not playerStateService.IsLoaded(player) then
                    continue
                end

                local level = playerStateService.GetUpgradeLevel(player, "magnet") or 0
                if level <= 0 then
                    continue
                end

                local definition = Upgrades.magnet
                local range = definition.baseRange + definition.rangePerLevel * level
                local character = player.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if not root then
                    continue
                end

                for _, coin in CollectionService:GetTagged("Coin") do
                    if coin:IsA("BasePart")
                        and coinService.IsAvailable(coin)
                        and (root.Position - coin.Position).Magnitude <= range
                    then
                        coinService.TryCollect(
                            coin,
                            player,
                            playerStateService,
                            analyticsAdapter,
                            range + 2,
                            onChanged
                        )
                    end
                end
            end
        end
    end)
end

return MagnetService
