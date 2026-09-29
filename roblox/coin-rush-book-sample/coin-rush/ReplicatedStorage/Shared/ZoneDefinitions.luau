--!strict

return {
    Zone1 = {
        unlockCost = 0,
        order = 1,
    },
    Zone2 = {
        unlockCost = 1000,
        order = 2,
        requires = "Zone1",
    },
    Zone3 = {
        unlockCost = 6000,
        order = 3,
        requires = "Zone2",
    },
}
