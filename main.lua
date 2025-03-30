---@diagnostic disable-next-line: undefined-global
local love = love

-- Import required modules
shove = require("libs/shove")
local Warrior = require("src.classes.warrior")
local Player = require("src.entities.player")
local HUD = require("src.ui.hud")
local Camera = require("src.config.camera")
local GameConfig = require("src.config.game")
local EnemyManager = require("src.managers.enemy_manager")
local FloatingTextManager = require("src.managers.floating_text_manager")

--[[
    Game initialization
    Sets up game resolution and window
]]
function love.load()
    -- Initialize Shöve with fixed resolution and scaling options
    shove.setResolution(
        GameConfig.resolution.width,
        GameConfig.resolution.height,
        {fitMethod = GameConfig.resolution.fitMethod}
    )

    -- Set up a resizable window
    shove.setWindowMode(
        GameConfig.window.width,
        GameConfig.window.height,
        {resizable = GameConfig.window.resizable}
    )
    
    -- Initialize player with Warrior class
    Player:init(Warrior)

    -- Initialize camera
    camera = Camera:new()
    
    -- Initialize managers
    EnemyManager:init()
    FloatingTextManager:init()
end

--[[
    Game state update
    @param dt Delta time (time between frames)
    Handles player movement and speed calculations
]]
function love.update(dt)
    Player:update(dt)
    camera:follow(Player, dt)
    
    -- Update managers
    EnemyManager:update(dt, Player)
    FloatingTextManager:update(dt)
end

--[[
    Game rendering
    Draws all visual elements to the screen
]]
function love.draw()
    -- Clear screen with background color
    love.graphics.setColor(GameConfig.colors.background)
    love.graphics.clear()
    
    -- Draw game elements
    camera:attach()
    Player:draw()
    EnemyManager:draw()
    FloatingTextManager:draw()
    camera:detach()

    -- Draw HUD without camera transformation (fixed on screen)
    HUD:draw(Player)
end

--[[
    Key press handler
    @param key Key that was pressed
    Manages specific key actions
]]
function love.keypressed(key)
    if key == "escape" then 
        love.event.quit() 
    else
        Player:keypressed(key)
    end
end

--[[
    Mouse press handler
    @param x Mouse X position
    @param y Mouse Y position
    @param button Mouse button pressed
]]
function love.mousepressed(x, y, button)
    Player:mousepressed(x, y, button)
end