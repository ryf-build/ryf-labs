--!strict

local AnalyticsService = game:GetService("AnalyticsService")

local AnalyticsAdapter = {}

local function customFields(field1, field2, field3)
    local fields = {}

    if field1 then
        fields[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = tostring(field1)
    end
    if field2 then
        fields[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = tostring(field2)
    end
    if field3 then
        fields[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = tostring(field3)
    end

    return fields
end

function AnalyticsAdapter.Custom(player, eventName, value, field1, field2, field3)
    if type(eventName) ~= "string" or eventName == "" then
        return false
    end

    local ok = pcall(function()
        AnalyticsService:LogCustomEvent(
            player,
            eventName,
            value or 1,
            customFields(field1, field2, field3)
        )
    end)

    -- Analytics is observability. A temporary analytics failure must not make
    -- Coin pickup or progression fail.
    return ok
end

function AnalyticsAdapter.Economy(
    player,
    flowType,
    amount,
    endingBalance,
    transactionType,
    itemSku,
    field1,
    field2,
    field3
)
    if type(amount) ~= "number" or amount <= 0 then
        return false
    end
    if type(endingBalance) ~= "number" or endingBalance < 0 then
        return false
    end

    local ok = pcall(function()
        AnalyticsService:LogEconomyEvent(
            player,
            flowType,
            "Coins",
            amount,
            endingBalance,
            transactionType,
            itemSku or "",
            customFields(field1, field2, field3)
        )
    end)
    return ok
end

function AnalyticsAdapter.OnboardingStep(player, step, stepName, field1, field2, field3)
    if type(step) ~= "number" or step < 1 or step ~= math.floor(step) then
        return false
    end
    if type(stepName) ~= "string" or stepName == "" then
        return false
    end

    local ok = pcall(function()
        AnalyticsService:LogOnboardingFunnelStepEvent(
            player,
            step,
            stepName,
            customFields(field1, field2, field3)
        )
    end)
    return ok
end

return AnalyticsAdapter
