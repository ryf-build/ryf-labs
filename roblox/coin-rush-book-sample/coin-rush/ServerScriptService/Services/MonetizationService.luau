--!strict

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Products = require(ReplicatedStorage.Shared.ProductDefinitions)

local MonetizationService = {}
local started = false

local function productById(productId)
    for key, definition in pairs(Products.developerProducts) do
        if definition.productId == productId and productId ~= 0 then
            return key, definition
        end
    end
    return nil, nil
end

local function refreshSupporterPass(player)
    local definition = Products.passes.supporter
    if not definition or definition.passId == 0 then
        player:SetAttribute("HasSupporterPass", false)
        return
    end

    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, definition.passId)
    end)
    if ok then
        player:SetAttribute("HasSupporterPass", owns == true)
    end
end

function MonetizationService.RefreshPasses(player)
    refreshSupporterPass(player)
end

function MonetizationService.Start(stateService, persistenceService, analyticsAdapter, onChanged)
    if started then
        return
    end
    started = true

    MarketplaceService.ProcessReceipt = function(receiptInfo)
        local productKey, definition = productById(receiptInfo.ProductId)
        if not definition then
            warn("UNKNOWN_DEVELOPER_PRODUCT", receiptInfo.ProductId, receiptInfo.PurchaseId)
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
        if not player or not stateService.IsLoaded(player) then
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        local applied, reason = stateService.ApplyDeveloperProduct(
            player,
            tostring(receiptInfo.PurchaseId),
            receiptInfo.ProductId,
            definition.grantType,
            definition.amount
        )
        if not applied then
            warn("RECEIPT_GRANT_REJECTED", receiptInfo.PurchaseId, reason)
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        local saved, saveError = persistenceService.Save(player, stateService, true)
        if not saved then
            warn("RECEIPT_SAVE_FAILED", receiptInfo.PurchaseId, saveError)
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        analyticsAdapter.Custom(
            player,
            "developer_product_granted",
            receiptInfo.CurrencySpent or 0,
            "product=" .. tostring(productKey),
            "purchase=" .. tostring(receiptInfo.PurchaseId)
        )
        if definition.grantType == "coins" then
            analyticsAdapter.Economy(
                player,
                Enum.AnalyticsEconomyFlowType.Source,
                definition.amount,
                stateService.GetCoins(player),
                Enum.AnalyticsEconomyTransactionType.IAP.Name,
                "product:" .. tostring(productKey)
            )
        end
        if onChanged then
            onChanged(player)
        end

        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, _wasPurchased)
        local supporter = Products.passes.supporter
        if supporter and supporter.passId ~= 0 and passId == supporter.passId then
            refreshSupporterPass(player)
            if onChanged then
                onChanged(player)
            end
        end
    end)
end

return MonetizationService
