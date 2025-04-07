---@diagnostic disable-next-line: undefined-global
local love = love

-- Import required modules
local Warrior = require("src.classes.player.warrior")
local Player = require("src.entities.player")
local HUD = require("src.ui.hud")
local Camera = require("src.config.camera")
local GameConfig = require("src.config.game")
local EnemyManager = require("src.managers.enemy_manager")
local FloatingTextManager = require("src.managers.floating_text_manager")
local PrismManager = require("src.managers.prism_manager")
local LevelUpModal = require("src.ui.level_up_modal")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")

--[[
    Game initialization
    Sets up game resolution and window
]]
function love.load()   
    -- Configura a janela para tela cheia
    love.window.setFullscreen(true, "desktop")
    
    -- Carrega fontes
    fonts.load()
    
    -- Carrega shader de glow
    local success, err = pcall(function()
        local glowShader = love.graphics.newShader("src/ui/shaders/simple_glow.fs")
        elements.setGlowShader(glowShader)
    end)
    if not success then
        print("Erro ao carregar shader glow:", err)
    end

    -- Inicializa player com Warrior class
    Player:init(Warrior)

    -- Inicializa camera
    camera = Camera:new()
    
    -- Inicializa managers
    EnemyManager:init()
    FloatingTextManager:init()
    PrismManager:init()
    
    -- Inicializa modal de level up
    LevelUpModal:init(Player)
end

--[[
    Game state update
    @param dt Delta time (time between frames)
    Handles player movement and speed calculations
]]
function love.update(dt)
    -- Verifica se o modal de level up está visível
    if LevelUpModal.visible then
        LevelUpModal:update(dt)
        return -- Pausa o jogo enquanto o modal estiver aberto
    end
    
    Player:update(dt)
    camera:follow(Player, dt)
    
    -- Update managers
    EnemyManager:update(dt, Player)
    FloatingTextManager:update(dt)
    PrismManager:update(dt, Player)
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
    PrismManager:draw()
    FloatingTextManager:draw()
    camera:detach()

    -- Draw HUD without camera transformation (fixed on screen)
    HUD:draw(Player)
    
    -- Draw level up modal if visible
    LevelUpModal:draw()
end

--[[
    Key press handler
    @param key Key that was pressed
    Manages specific key actions
]]
function love.keypressed(key)
    if key == "escape" then 
        love.event.quit() 
    elseif key == "f11" then
        -- Toggle fullscreen
        love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
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
    -- Se o modal de level up estiver visível, passa o evento para ele
    if LevelUpModal.visible then
        LevelUpModal:mousepressed(x, y, button)
        return
    end
    
    Player:mousepressed(x, y, button)
end