--!strict

-- Replace IDs with products/passes created for your own experience.
-- A value of 0 disables the corresponding purchase button in the sample UI.
return {
    developerProducts = {
        coinPackSmall = {
            displayName = "1,000 Coins",
            productId = 0,
            grantType = "coins",
            amount = 1000,
        },
    },
    passes = {
        supporter = {
            displayName = "Supporter Pass",
            passId = 0,
        },
    },
}
