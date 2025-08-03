local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local Camera = require("src.config.camera")

local PlayerHPBar = require("src.ui.components.PlayerHPBar")
local ProgressLevelBar = require("src.ui.components.ProgressLevelBar")

local ManagerRegistry = require("src.managers.manager_registry")

---@class HUDGameplayManager
---@field context GameplaySceneContext
---@field baseBarsWidth number
---@field playerHPBar PlayerHPBar
---@field progressLevelBar ProgressLevelBar
---@field basePlayerHPBarWidth number
--- Event Listeners
---@field playerXPGainedListener EventListenerIdentifier
---@field playerLeveledUpListener EventListenerIdentifier
---@field playerHealthChangedListener EventListenerIdentifier
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

    instance.playerXPGainedListener = nil
    instance.playerLeveledUpListener = nil
    instance.playerHealthChangedListener = nil

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
    self.progressLevelBar = self:_initProgressLevelBar()

    self:_positionElements()
    self:_subscribeToEvents()
end

--- Atualiza todos os elementos da UI gerenciados.
---@param dt number Delta time.
function HUDGameplayManager:update(dt)
    self.progressLevelBar:update(dt)
    self.playerHPBar:update(dt)
end

--- Desenha todos os elementos da UI gerenciados.
---@param isPaused boolean Se o jogo está pausado.
function HUDGameplayManager:draw(isPaused)
    local playerManager = self.context.registry:getPlayerManager()
    local playerScreenPosition = playerManager:getPosition()

    self.playerHPBar:draw()
    self.progressLevelBar:draw()

    -- Desenha as informações de debug
    self:_drawEnemyDebugInfo()

    Camera:attach()
    self.playerHPBar:drawOnPlayer(playerScreenPosition.x, playerScreenPosition.y, isPaused)
    Camera:detach()
end

---@private É chamado quando o jogador ganha experiência.
---@param data table O payload do evento.
function HUDGameplayManager:_onExperienceGained(data)
    assert(data.amount, "[HUDGameplayManager:_onExperienceGained] missing a data.amount on event")
    self.progressLevelBar:addXP(data.amount)
end

---@private É chamado quando o jogador sobe de nível.
---@param data table O payload do evento.
function HUDGameplayManager:_onPlayerLeveledUp(data)
    assert(data.newLevel, "[HUDGameplayManager:_onPlayerLeveledUp] missing a data.newLevel on event")
    assert(data.levelsGained, "[HUDGameplayManager:_onPlayerLeveledUp] missing a data.levelsGained on event")
    assert(data.currentExperience, "[HUDGameplayManager:_onPlayerLeveledUp] missing a data.currentExperience on event")

    -- Força a sincronização para garantir que a barra está no estado correto.
    self.progressLevelBar:setLevel(data.newLevel, data.currentExperience)
end

---@private É chamado quando a vida do jogador muda.
---@param data PlayerHealthUpdatedEventData O payload do evento.
function HUDGameplayManager:_onPlayerHealthChanged(data)
    assert(data.current, "[HUDGameplayManager:_onPlayerHealthChanged] missing a data.current on event")
    assert(data.max, "[HUDGameplayManager:_onPlayerHealthChanged] missing a data.max on event")

    local currentHP = data.current
    local maxHP = data.max

    if maxHP ~= self.playerHPBar.maxHP then
        local targetWidth = self.basePlayerHPBarWidth * (maxHP / self.basePlayerMaxHPForWidth)
        targetWidth = math.max(targetWidth, self.basePlayerHPBarWidth * 0.5)
        self.playerHPBar:setWidth(targetWidth)
    end

    self.playerHPBar:setCurrentHP(currentHP)
    self.playerHPBar:setMaxHP(maxHP)
end

---@private Inscreve o manager nos eventos relevantes.
function HUDGameplayManager:_subscribeToEvents()
    local eventService = self.context.serviceLocator:getEventService()

    self.playerXPGainedListener = eventService:on(
        eventService.EVENTS.PLAYER_XP_GAINED,
        self._onExperienceGained,
        self
    )
    self.playerLeveledUpListener = eventService:on(
        eventService.EVENTS.PLAYER_LEVELED_UP,
        self._onPlayerLeveledUp,
        self
    )
    self.playerHealthChangedListener = eventService:on(
        eventService.EVENTS.PLAYER_HEALTH_UPDATED,
        self._onPlayerHealthChanged,
        self
    )
end

---@private Cancela a inscrição dos eventos.
function HUDGameplayManager:_unsubscribeFromEvents()
    local eventService = self.context.serviceLocator:getEventService()
    eventService:off(self.playerXPGainedListener)
    eventService:off(self.playerLeveledUpListener)
    eventService:off(self.playerHealthChangedListener)
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

---@private Inicializa a barra de HP do jogador.
---@param hunterName string Nome do caçador.
---@param hunterRank string Rank do caçador.
---@return PlayerHPBar
function HUDGameplayManager:_initPlayerHPBar(hunterName, hunterRank)
    assert(hunterName, "[HUDGameplayManager:_initPlayerHPBar] missing a hunterName")
    assert(hunterRank, "[HUDGameplayManager:_initPlayerHPBar] missing a hunterRank")

    local playerManager = self.context.registry:getPlayerManager()
    local maxHealth = playerManager.stateController:getStat("maxHealth")
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
            rank = colors.gray,
            hpValues = colors.white,
            hpBarBase = colors.hpBarBase,
            hpBarFill = colors.hpBarFill,
            hpBarDamageTrail = colors.hpBarTrail,
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

---@private Inicializa a barra de experiência do jogador.
function HUDGameplayManager:_initProgressLevelBar()
    local playerManager = self.context.registry:getPlayerManager()
    local experienceController = playerManager.experienceController
    local initialExperience = experienceController:getCurrentExperience()
    local initialLevel = experienceController:getLevel()
    local adaptiveFont = fonts.getAdaptive()

    local experienceBarParams = {
        x = 0,
        y = 0,
        w = self.baseBarsWidth,
        initialXP = initialExperience,
        initialLevel = initialLevel,
        xpForNextLevel = function(level_from_bar)
            return experienceController:getExperienceRequiredForLevel(level_from_bar)
        end,
        fontMain = adaptiveFont.main,
        fontLevelNumber = adaptiveFont.main_bold,
        fontXpGain = adaptiveFont.main_bold,
        fontLevelUp = adaptiveFont.main_bold,
        colors = {
            levelText = colors.xpText,
            levelNumber = colors.xplevelNumber,
            xpText = colors.xpText,
            progressBarBase = colors.xpBarBase,
            progressBarFill = colors.xpBarFill,
            xpGainText = colors.xpGainText,
            trailBar = colors.xpBarTrail,
        }
    }

    local experienceBar = ProgressLevelBar:new(experienceBarParams)

    return experienceBar
end

---@private Posiciona os elemetos de UI do HUDGameplayManager.
function HUDGameplayManager:_positionElements()
    local screenWidth = ResolutionUtils.getGameWidth()
    local screenHeight = ResolutionUtils.getGameHeight()

    self.playerHPBar:setPosition(
        self.PADDING_FROM_SCREEN_EDGE_X,
        screenHeight - self.PADDING_FROM_SCREEN_EDGE_BOTTOM - self.playerHPBar.height
    )

    self.progressLevelBar:setPosition(
        self.PADDING_FROM_SCREEN_EDGE_X,
        self.playerHPBar.y - self.SPACING_BETWEEN_BARS - self.progressLevelBar.height
    )
end

function HUDGameplayManager:destroy()
    Logger.info("hud_gameplay_manager.destroy", "[HUDGameplayManager:destroy] Destroying...")
    self:_unsubscribeFromEvents()
end

return HUDGameplayManager
