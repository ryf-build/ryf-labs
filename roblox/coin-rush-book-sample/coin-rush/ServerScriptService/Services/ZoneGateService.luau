--!strict

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local ZoneGateService = {}
local connected = setmetatable({}, { __mode = "k" })

local function connectGate(gate, stateService)
    if not gate:IsA("BasePart") or connected[gate] then
        return
    end
    connected[gate] = true

    gate.Touched:Connect(function(hit)
        local character = hit:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        if not player or not stateService.IsLoaded(player) then
            return
        end

        local zoneId = gate:GetAttribute("ZoneId")
        if type(zoneId) ~= "string" or stateService.HasZone(player, zoneId) then
            return
        end

        local root = character:FindFirstChild("HumanoidRootPart")
        if not root then
            return
        end

        local returnPosition = gate:GetAttribute("ReturnPosition")
        if typeof(returnPosition) == "Vector3" then
            root.CFrame = CFrame.new(returnPosition)
        else
            root.CFrame = root.CFrame - root.CFrame.LookVector * 8
        end
    end)
end

function ZoneGateService.Start(stateService)
    for _, gate in CollectionService:GetTagged("ZoneGate") do
        connectGate(gate, stateService)
    end
    CollectionService:GetInstanceAddedSignal("ZoneGate"):Connect(function(gate)
        connectGate(gate, stateService)
    end)
end

return ZoneGateService
