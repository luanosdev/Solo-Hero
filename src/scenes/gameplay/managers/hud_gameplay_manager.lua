local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")

local PlayerHPBar = require("src.ui.components.PlayerHPBar")

local ManagerRegistry = require("src.managers.manager_registry")

---@class HUDGameplayManager
---@field context GameplaySceneContext
---@field baseBarsWidth number
---@field playerHPBar PlayerHPBar
---@field basePlayerHPBarWidth number
local HUDGameplayManager = {}
HUDGameplayManager.__index = HUDGameplayManager

HUDGameplayManager.SPACING_BETWEEN_BARS = 10
HUDGameplayManager.PADDING_FROM_SCREEN_EDGE_X = 10
HUDGameplayManager.PADDING_FROM_SCREEN_EDGE_BOTTOM = 20

---@param context GameplaySceneContext
---@return HUDGameplayManager
function HUDGameplayManager:new(context)
    assert(context, "[HUDGameplayManager] missing a GameplaySceneContext")

    local instance = setmetatable({}, HUDGameplayManager)
    instance.context = context

    local screenWidth = ResolutionUtils.getGameWidth()
    instance.baseBarsWidth = screenWidth * 0.25

    return instance
end

--- Configura o HUDGameplayManager para o gameplay com base nos dados de um caçador específico.
--- Chamado pela GameplayScene após a inicialização dos managers.
function HUDGameplayManager:init()
    local screenWidth = ResolutionUtils.getGameWidth()
    local screenHeight = ResolutionUtils.getGameHeight()

    --- TODO: Transformar hunterManager em um serviço
    ---@type HunterManager
    local hunterManager = ManagerRegistry:get("hunterManager")
    local hunterId = self.context.args.hunterId
    local hunterData = hunterManager:getHunterData(hunterId)

    self.playerHPBar = self:_initPlayerHPBar(
        hunterData.name,
        hunterData.finalRankId
    )

    self:_positionElements()
end

--- Atualiza todos os elementos da UI gerenciados.
---@param dt number Delta time.
function HUDGameplayManager:update(dt)
    local playerManager = self.context.registry:getPlayerManager()
    local maxHealth = playerManager.stateController:getStat("health")

    self:_updatePlayerHPBar(maxHealth)
end

--- Desenha o painel de debug com informações dos inimigos.
function HUDGameplayManager:_drawEnemyDebugInfo()
    local enemyManager = self.context.registry:getEnemyManager()

    local info = enemyManager:getDebugInfo()
    if not info then return end

    love.graphics.setFont(fonts.main)
    love.graphics.setColor(1, 1, 1)

    local x = 10
    local y = 10
    local lineHeight = fonts.main:getHeight()

    love.graphics.print("--- Enemy Culling Debug ---", x, y)
    y = y + lineHeight
    love.graphics.print(string.format("Total: %d", info.total), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("Active (Full Logic): %d", info.active), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("Slow (Anim Only): %d", info.slow), x, y)
end

--- Desenha todos os elementos da UI gerenciados.
---@param isPaused boolean Se o jogo está pausado.
function HUDGameplayManager:draw(isPaused)
    local playerManager = self.context.registry:getPlayerManager()
    local playerScreenPosition = playerManager:getPosition()

    self.playerHPBar:draw()
    self.playerHPBar:drawOnPlayer(playerScreenPosition.x, playerScreenPosition.y, isPaused)

    -- Desenha as informações de debug
    self:_drawEnemyDebugInfo()
end

---@private Inicializa a barra de HP do jogador.
---@param hunterName string Nome do caçador.
---@param hunterRank string Rank do caçador.
---@return PlayerHPBar
function HUDGameplayManager:_initPlayerHPBar(hunterName, hunterRank)
    assert(hunterName, "[HUDGameplayManager:_initPlayerHPBar] missing a hunterName")
    assert(hunterRank, "[HUDGameplayManager:_initPlayerHPBar] missing a hunterRank")

    local playerManager = self.context.registry:getPlayerManager()
    local maxHealth = playerManager.stateController:getStat("health")
    local adaptiveFont = fonts.getAdaptive()

    local playerHPBarParams = {
        x = 0,
        y = 0,
        w = self.baseBarsWidth,
        initialHP = maxHealth,
        initialMaxHP = maxHealth,
        hunterName = hunterName,
        hunterRank = hunterRank,
        fontName = adaptiveFont.main,
        fontRank = adaptiveFont.main_small,
        fontHPValues = adaptiveFont.resource_value,
        fontHPChange = adaptiveFont.main_small,
        colors = {
            name = colors.white,
            rank = colors.white,
            hpValues = colors.heal,
            hpBarBase = colors.hp_fill,
            hpBarFill = colors.hp_fill,
            hpBarDamageTrail = colors.hp_fill,
            segmentLine = colors.black
        },
        segmentHPInterval = 50,
        hpBarAnimationSpeed = 50
    }

    local playerHPBar = PlayerHPBar:new(playerHPBarParams)
    self.basePlayerHPBarWidth = playerHPBarParams.w
    self.basePlayerMaxHPForWidth = maxHealth > 0 and maxHealth or 100

    return playerHPBar
end

---@private Atualiza o playerHPBar.
---@param maxHealth number Vida máxima do jogador.
function HUDGameplayManager:_updatePlayerHPBar(maxHealth)
    if not self.playerHPBar then return end

    if maxHealth ~= self.playerHPBar.maxHP then
        local currentHPBarX = self.playerHPBar.x
        local targetWidth = self.basePlayerHPBarWidth * (maxHealth / self.basePlayerMaxHPForWidth)
        targetWidth = math.max(targetWidth, self.basePlayerHPBarWidth * 0.5)
        self.playerHPBar:setWidth(targetWidth)
    end
end

---@private Posiciona os elemetos de UI do HUDGameplayManager.
function HUDGameplayManager:_positionElements()
    local screenWidth = ResolutionUtils.getGameWidth()
    local screenHeight = ResolutionUtils.getGameHeight()

    self.playerHPBar:setPosition(
        self.PADDING_FROM_SCREEN_EDGE_X,
        screenHeight - self.PADDING_FROM_SCREEN_EDGE_BOTTOM - self.playerHPBar.height
    )
end

function HUDGameplayManager:destroy()
    Logger.info("hud_gameplay_manager.destroy", "[HUDGameplayManager:destroy] Destroying...")
end

return HUDGameplayManager
