--!strict

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local DemoWorldService = {}

local function part(parent, name, size, position, color)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = size
    p.Position = position
    p.Color = color
    p.Parent = parent
    return p
end

function DemoWorldService.Ensure()
    if #CollectionService:GetTagged("Coin") > 0 then
        return false
    end

    local old = Workspace:FindFirstChild("CoinRushWorld")
    if old then
        old:Destroy()
    end

    local folder = Instance.new("Folder")
    folder.Name = "CoinRushWorld"
    folder.Parent = Workspace

    local floor = part(folder, "Floor", Vector3.new(180, 1, 44), Vector3.new(70, 0, 0), Color3.fromRGB(45, 52, 62))
    floor.Material = Enum.Material.Slate

    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "CoinRushSpawn"
    spawn.Size = Vector3.new(8, 1, 8)
    spawn.Position = Vector3.new(-10, 1, 0)
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.Parent = folder

    for index = 1, 24 do
        local x = (index - 1) * 6
        local z = if index % 2 == 0 then 7 else -7
        local coin = part(
            folder,
            string.format("Coin_%02d", index),
            Vector3.new(2, 2, 2),
            Vector3.new(x, 2, z),
            Color3.fromRGB(255, 209, 64)
        )
        coin.Shape = Enum.PartType.Ball
        coin.Material = Enum.Material.Neon
        coin.CanCollide = false
        coin:SetAttribute("CoinValue", if index > 16 then 25 elseif index > 8 then 15 else 10)
        coin:SetAttribute("RespawnSeconds", 4)
        coin:SetAttribute("Source", if index > 16 then "zone_03" elseif index > 8 then "zone_02" else "zone_01")
        CollectionService:AddTag(coin, "Coin")
    end

    local gate2 = part(folder, "Zone2Gate", Vector3.new(1, 12, 40), Vector3.new(45, 6, 0), Color3.fromRGB(255, 130, 80))
    gate2.Transparency = 0.35
    gate2.CanCollide = false
    gate2:SetAttribute("ZoneId", "Zone2")
    gate2:SetAttribute("ReturnPosition", Vector3.new(38, 4, 0))
    CollectionService:AddTag(gate2, "ZoneGate")

    local gate3 = part(folder, "Zone3Gate", Vector3.new(1, 12, 40), Vector3.new(95, 6, 0), Color3.fromRGB(220, 80, 255))
    gate3.Transparency = 0.35
    gate3.CanCollide = false
    gate3:SetAttribute("ZoneId", "Zone3")
    gate3:SetAttribute("ReturnPosition", Vector3.new(88, 4, 0))
    CollectionService:AddTag(gate3, "ZoneGate")

    warn("Coin Rush demo world was generated because no tagged Coin objects existed.")
    return true
end

return DemoWorldService
