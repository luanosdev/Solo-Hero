--[[
    Game configuration
    Contains all game settings and constants
]]

local GameConfig = {
    -- Window settings
    window = {
        width = 1280,    -- HD width
        height = 720,    -- HD height
        resizable = true
    },

    -- Game resolution
    resolution = {
        width = 640,     -- Half of HD width for pixel art scaling
        height = 360,    -- Half of HD height for pixel art scaling
        fitMethod = "aspect"
    },

    -- Colors
    colors = {
        background = {0.1, 0.1, 0.2},  -- Dark blue
        player = {0.918, 0.059, 0.573} -- Pink
    }
}

return GameConfig
