local ProgressLevelBar = require("src.ui.components.ProgressLevelBar")
local PlayerHPBar = require("src.ui.components.PlayerHPBar")
local fonts = require("src.ui.fonts")
local ManagerRegistry = require("src.managers.manager_registry")
local Camera = require("src.config.camera")
local ActiveSkillsDisplay = require("src.ui.components.active_skills_display")
local BossHealthBarManager = require("src.managers.boss_health_bar_manager")
local OffscreenIndicator = require("src.ui.components.offscreen_indicator")
local ExtractionProgressBar = require("src.ui.components.extraction_progress_bar")
local DashCooldownIndicator = require("src.ui.components.dash_cooldown_indicator")
local PotionFlasksDisplay = require("src.ui.components.potion_flasks_display")

---@class HUDGameplayManager
---@field progressLevelBar ProgressLevelBar|nil Instância da barra de progresso de nível.
---@field playerHPBar PlayerHPBar|nil Instância da barra de HP do jogador.
---@field skillsDisplay ActiveSkillsDisplay|nil Instância do display de cooldowns.
---@field portalIndicators table Armazena os indicadores de portal.
---@field extractionProgressBar ExtractionProgressBar|nil Instância da barra de progresso de extração.
---@field dashIndicator DashCooldownIndicator|nil Instância do indicador de cooldown de dash.
---@field potionDisplay PotionFlasksDisplay|nil Instância do display de frascos de poção.
---@field lastPlayerLevel number Armazena o nível do jogador no frame anterior.
---@field lastPlayerXPInLevel number Armazena o XP do jogador DENTRO do nível no frame anterior.
---@field lastTotalPlayerXP number Armazena o XP TOTAL ACUMULADO do jogador no frame anterior.
---@field lastPlayerHP number Armazena o HP do jogador no frame anterior.
---@field lastPlayerMaxHP number Armazena o MaxHP do jogador no frame anterior.
---@field lastPlayerName string Armazena o nome do jogador no frame anterior.
---@field lastPlayerRank string Armazena o rank do jogador no frame anterior.
---@field basePlayerHPBarWidth number Largura base da barra de HP para cálculo de escalonamento.
---@field basePlayerMaxHPForWidth number MaxHP base para cálculo de escalonamento da largura da barra de HP.
local HUDGameplayManager = {
    progressLevelBar = nil,
    playerHPBar = nil,
    skillsDisplay = nil,
    portalIndicators = {},
    extractionProgressBar = nil,
    dashIndicator = nil,
    potionDisplay = nil,
    lastPlayerLevel = 0,
    lastPlayerXPInLevel = 0,
    lastTotalPlayerXP = 0,
    lastPlayerHP = 0,
    lastPlayerMaxHP = 0,
    lastPlayerName = "",
    lastPlayerRank = "",
    basePlayerHPBarWidth = 0,
    basePlayerMaxHPForWidth = 100
}

-- Função auxiliar para calcular o XP total acumulado
-- Requer uma função que possa fornecer o XP necessário para CADA nível anterior.
local function calculateTotalXPForState(level, currentLevelXP, getXPRequiredForLevelFunc)
    local totalXP = 0
    for l = 1, level - 1 do
        totalXP = totalXP + getXPRequiredForLevelFunc(l)
    end
    totalXP = totalXP + currentLevelXP
    return totalXP
end

--- Configura o HUDGameplayManager para o gameplay com base nos dados de um caçador específico.
--- Chamado pela GameplayScene após a inicialização dos managers.
function HUDGameplayManager:setupGameplay()
    local playerManager = ManagerRegistry:get("playerManager")
    local hunterManager = ManagerRegistry:get("hunterManager")
    local itemDataManager = ManagerRegistry:get("itemDataManager")

    BossHealthBarManager:init()

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local mainFont = fonts.main
    local levelNumFont = fonts.main_large
    local xpGainFont = fonts.main_small
    local hunterData = hunterManager:getHunterData(playerManager.currentHunterId)

    local initialPlayerState = playerManager.state
    local initialLevel = initialPlayerState.level
    local initialXP = initialPlayerState.experience
    local initialHP = initialPlayerState.currentHealth
    local initialMaxHP = initialPlayerState.maxHealth
    local initialName = hunterData.name
    local initialRank = hunterData.finalRankId

    -- Configuração da Barra de HP (PlayerHPBar)
    local hpBarConfig = {
        x = 0,                  -- X e Y serão definidos após a instanciação para obter a altura
        y = 0,
        w = screenWidth * 0.25, -- Um pouco maior que a de XP
        initialHP = initialHP,
        initialMaxHP = initialMaxHP,
        hunterName = initialName,
        hunterRank = initialRank,
        fontName = mainFont,
        fontRank = xpGainFont,
        fontHPValues = love.graphics.newFont(mainFont:getHeight() * 1.2),
        fontHPChange = mainFont,
        colors = {
            name = { 220, 220, 230, 255 },
            rank = { 180, 180, 190, 255 },
            hpValues = { 200, 200, 210, 255 },
            hpBarBase = { 200, 60, 60, 255 },
            hpBarFill = { 200, 60, 60, 255 },
            hpBarDamageTrail = { 200, 60, 60, 150 },
            segmentLine = { 10, 10, 10, 128 }
        },
        segmentHPInterval = 50,
        hpBarAnimationSpeed = 25
    }
    self.playerHPBar = PlayerHPBar:new(hpBarConfig)

    -- Armazena a largura e MaxHP base para escalonamento futuro
    self.basePlayerHPBarWidth = hpBarConfig.w
    -- Evita divisão por zero se MaxHP inicial for 0
    self.basePlayerMaxHPForWidth = initialMaxHP > 0 and initialMaxHP or 100

    -- Configuração da Barra de Nível/XP (ProgressLevelBar)
    local xpBarConfig = {
        x = 0, -- X e Y serão definidos após a instanciação da HPBar e desta
        y = 0,
        w = screenWidth * 0.25,
        fontMain = mainFont,
        fontLevelNumber = levelNumFont,
        fontXpGain = xpGainFont,
        initialLevel = initialLevel,
        initialXP = initialXP,
        xpForNextLevel = function(level_from_bar)
            return playerManager:getExperienceRequiredForLevel(level_from_bar)
        end,
        colors = {
            levelText = { 210, 210, 220, 255 },
            levelNumber = { 130, 90, 255, 255 },
            xpText = { 190, 190, 190, 255 },
            progressBarBase = { 110, 80, 220, 255 },
            progressBarFill = { 110, 80, 220, 255 },
            xpGainText = { 50, 205, 50, 255 },
            trailBar = { 110, 80, 220, 150 },
        }
    }
    self.progressLevelBar = ProgressLevelBar:new(xpBarConfig)

    -- Configuração do ActiveSkillsDisplay
    self.skillsDisplay = ActiveSkillsDisplay:new(playerManager, itemDataManager)

    -- Configuração da Barra de Extração
    self.extractionProgressBar = ExtractionProgressBar:new({ w = 400, h = 50 })

    -- ADICIONADO: Configuração do Indicador de Dash
    self.dashIndicator = DashCooldownIndicator:new()

    -- Configuração do Display de Poções
    self.potionDisplay = PotionFlasksDisplay:new({
        flaskWidth = 28,
        flaskHeight = 42,
        spacing = 6
    })

    -- Posicionamento dinâmico das barras
    local paddingFromScreenEdgeX = 30
    local paddingFromScreenEdgeBottom = 20
    local spacingBetweenBars = 8

    self.playerHPBar:setWidth(hpBarConfig.w)
    -- Posiciona o display de poções na parte inferior
    self.potionDisplay:setPosition(
        paddingFromScreenEdgeX + 10,
        screenHeight - paddingFromScreenEdgeBottom - self.potionDisplay.height
    )

    self.playerHPBar:setPosition(
        paddingFromScreenEdgeX,
        self.potionDisplay.y - spacingBetweenBars - self.playerHPBar.height
    )

    self.progressLevelBar:setWidth(xpBarConfig.w)
    self.progressLevelBar:setPosition(
        paddingFromScreenEdgeX,
        self.playerHPBar.y - spacingBetweenBars - self.progressLevelBar.height
    )

    -- Sincronização inicial dos valores rastreados para XP
    self.lastPlayerLevel = initialLevel
    self.lastPlayerXPInLevel = initialXP
    local xpFunc = function(lvl) return playerManager:getExperienceRequiredForLevel(lvl) end
    self.lastTotalPlayerXP = calculateTotalXPForState(initialLevel, initialXP, xpFunc)
    -- Garante que a barra reflita o estado
    self.progressLevelBar:setLevel(initialLevel, initialXP)

    -- Sincronização inicial dos valores rastreados para HP
    self.lastPlayerHP = initialHP
    self.lastPlayerMaxHP = initialMaxHP
    self.lastPlayerName = initialName
    self.lastPlayerRank = initialRank
    self.playerHPBar:updateBaseInfo(initialName, initialRank, initialMaxHP)
    self.playerHPBar:setCurrentHP(initialHP)
end

--- Inicia a barra de progresso de extração.
---@param duration number Duração em segundos.
---@param text string Texto a ser exibido na barra.
function HUDGameplayManager:startExtractionTimer(duration, text)
    self.extractionProgressBar:start(duration, text)
end

--- Para a barra de progresso de extração.
function HUDGameplayManager:stopExtractionTimer()
    self.extractionProgressBar:stop()
end

--- Verifica se a barra de progresso de extração concluiu.
---@return boolean
function HUDGameplayManager:isExtractionFinished()
    if self.extractionProgressBar then
        return self.extractionProgressBar:isFinished()
    end
    return false
end

--- Atualiza todos os elementos da UI gerenciados.
---@param dt number Delta time.
function HUDGameplayManager:update(dt)
    local playerManager = ManagerRegistry:get("playerManager")
    local hunterManager = ManagerRegistry:get("hunterManager")

    if not playerManager or not playerManager.state or not hunterManager then
        if self.progressLevelBar then self.progressLevelBar:update(dt) end
        if self.playerHPBar then self.playerHPBar:update(dt) end
        if self.skillsDisplay then self.skillsDisplay:update(dt) end
        if self.extractionProgressBar then self.extractionProgressBar:update(dt) end
        self.dashIndicator:update(0, 0, {})
        if self.potionDisplay then self.potionDisplay:update(dt, 0, 0, {}) end
        return
    end

    -- Update portal indicators
    local extractionPortalManager = ManagerRegistry:tryGet("extractionPortalManager")
    if extractionPortalManager and extractionPortalManager.portals then
        -- Otimização: Cria os indicadores apenas uma vez
        if #self.portalIndicators ~= #extractionPortalManager.portals then
            self.portalIndicators = {} -- Limpa para recriar
            for i, portal in ipairs(extractionPortalManager.portals) do
                self.portalIndicators[i] = OffscreenIndicator:new({ targetId = i })
            end
        end

        -- Atualiza os indicadores existentes
        for i, portal in ipairs(extractionPortalManager.portals) do
            if self.portalIndicators[i] then
                self.portalIndicators[i]:update(portal.position, playerManager.player.position)
            end
        end
    end

    local screenWidth = love.graphics.getWidth() -- Necessário para reposicionamento
    local screenHeight = love.graphics.getHeight()
    local paddingFromScreenEdgeBottom = 20       -- Usado no construtor, manter consistência
    local spacingBetweenBars = 8                 -- Usado no construtor, manter consistência

    -- Atualização da Barra de XP
    if playerManager.getExperienceRequiredForLevel then
        local currentLevel = playerManager.state.level or 1
        local currentXPInLevel = playerManager.state.experience or 0
        local currentTotalXP = calculateTotalXPForState(currentLevel, currentXPInLevel, function(lvl)
            return playerManager:getExperienceRequiredForLevel(lvl)
        end)
        local xpGainedSinceLastFrame = currentTotalXP - self.lastTotalPlayerXP

        if xpGainedSinceLastFrame > 0 then
            self.progressLevelBar:addXP(xpGainedSinceLastFrame)
        elseif currentLevel ~= self.lastPlayerLevel or currentXPInLevel ~= self.lastPlayerXPInLevel then
            self.progressLevelBar:setLevel(currentLevel, currentXPInLevel)
        end

        self.lastTotalPlayerXP = currentTotalXP
        self.lastPlayerLevel = currentLevel
        self.lastPlayerXPInLevel = currentXPInLevel
    end
    self.progressLevelBar:update(dt)

    -- Atualização da Barra de HP
    local pState = playerManager.state
    local currentHunterInfo = hunterManager:getHunterData(playerManager.currentHunterId)
    local finalStats = playerManager:getCurrentFinalStats()

    local newName = currentHunterInfo.name or self.lastPlayerName
    local newRank = currentHunterInfo.finalRankId or self.lastPlayerRank
    local newMaxHP = finalStats.health
    local newCurrentHP = pState.currentHealth or self.lastPlayerHP

    local needsHpBarReposition = false
    if newName ~= self.lastPlayerName or
        newRank ~= self.lastPlayerRank or
        newMaxHP ~= self.lastPlayerMaxHP then
        if newMaxHP ~= self.lastPlayerMaxHP and self.basePlayerMaxHPForWidth > 0 then
            local currentHPBarX = self.playerHPBar
                .x                                                               -- Salva X atual para não resetar se só largura muda
            local targetWidth = self.basePlayerHPBarWidth * (newMaxHP / self.basePlayerMaxHPForWidth)
            targetWidth = math.max(targetWidth, self.basePlayerHPBarWidth * 0.5) -- Garante uma largura mínima (ex: 50% da base)
            self.playerHPBar:setWidth(targetWidth)
            -- A altura da playerHPBar pode ter mudado após setWidth, então precisa ser reposicionada em Y.
            -- E a progressLevelBar precisará ser reposicionada em relação à playerHPBar.
            needsHpBarReposition = true
        end

        self.playerHPBar:updateBaseInfo(newName, newRank, newMaxHP)
        -- updateBaseInfo também pode mudar a altura se o texto do rank/nome mudar muito, etc.
        -- então, mesmo sem mudança de MaxHP, um reposicionamento pode ser bom se nome/rank mudar.
        if not needsHpBarReposition then needsHpBarReposition = true end
    end

    if needsHpBarReposition then
        -- Reposiciona HPBar acima do display de poções
        self.playerHPBar:setPosition(
            self.playerHPBar.x, -- Mantem X atual
            self.potionDisplay.y - spacingBetweenBars - self.playerHPBar.height
        )
        -- Então reposiciona a ProgressLevelBar acima da HPBar
        self.progressLevelBar:setPosition(
            self.progressLevelBar.x, -- Mantem X atual
            self.playerHPBar.y - spacingBetweenBars - self.progressLevelBar.height
        )
    end

    -- A PlayerHPBar:updateBaseInfo pode ter alterado o currentHP interno da barra.
    -- Agora, garantimos que o HP atual do jogador seja refletido.
    -- A barra decidirá se isso é dano/cura em relação ao seu estado interno.
    if newCurrentHP ~= self.playerHPBar.currentHP then -- Só chama se o HP do jogador for diferente do HP atual da barra
        self.playerHPBar:setCurrentHP(newCurrentHP)
    end

    self.lastPlayerHP = newCurrentHP
    self.lastPlayerMaxHP = newMaxHP
    self.lastPlayerName = newName
    self.lastPlayerRank = newRank

    self.playerHPBar:update(dt)
    self.skillsDisplay:update(dt)
    BossHealthBarManager:update(dt)

    -- Atualização do Indicador de Dash
    if self.dashIndicator and playerManager.dashController then
        local available, total, progress = playerManager.dashController:getDashStatus()
        self.dashIndicator:update(available, total, progress)
    end

    -- Atualização do Display de Poções
    if self.potionDisplay and playerManager.potionController then
        local readyFlasks, totalFlasks, flasksInfo = playerManager:getPotionStatus()
        self.potionDisplay:update(dt, readyFlasks, totalFlasks, flasksInfo)

        -- Reposiciona se necessário (quando barras mudam de tamanho/posição)
        if needsHpBarReposition then
            self.potionDisplay:setPosition(
                self.potionDisplay.x, -- Mantém X atual
                self.progressLevelBar.y - spacingBetweenBars - self.potionDisplay.height
            )
        end
    end

    if self.extractionProgressBar then
        self.extractionProgressBar:update(dt)
    end
end

--- Desenha todos os elementos da UI gerenciados.
---@param isPaused boolean Se o jogo está pausado.
function HUDGameplayManager:draw(isPaused)
    ---@type PlayerManager
    local playerManager = ManagerRegistry:get("playerManager")
    local playerScreenX, playerScreenY = Camera:worldToScreen(
        playerManager.player.position.x,
        playerManager.player.position.y
    )
    self.progressLevelBar:draw()
    self.playerHPBar:draw()
    self.playerHPBar:drawOnPlayer(playerScreenX, playerScreenY, isPaused)
    self.skillsDisplay:draw(isPaused)
    BossHealthBarManager:draw()

    -- Desenha o indicador de dash
    self.dashIndicator:draw(playerScreenX, playerScreenY, isPaused)

    -- Desenha o display de poções
    if self.potionDisplay and playerManager.potionController then
        local readyFlasks, totalFlasks, flasksInfo = playerManager:getPotionStatus()
        self.potionDisplay:draw(readyFlasks, totalFlasks, flasksInfo)
    end

    self.extractionProgressBar:draw()

    if self.portalIndicators then
        for _, indicator in ipairs(self.portalIndicators) do
            indicator:draw()
        end
    end
end

--- Reseta o estado do manager (se necessário).
function HUDGameplayManager:reset()
    local playerManager = ManagerRegistry:get("playerManager")
    local hunterManager = ManagerRegistry:get("hunterManager")

    if playerManager and playerManager.state and hunterManager then
        local pState = playerManager.state
        local hunterCurrentInfo = hunterManager:getHunterData(playerManager.currentHunterId)

        local playerLevel = pState.level or 1
        local playerXPInLevel = pState.experience or 0

        if self.progressLevelBar and playerManager.getExperienceRequiredForLevel then
            self.progressLevelBar:setLevel(playerLevel, playerXPInLevel)
            self.lastPlayerLevel = playerLevel
            self.lastPlayerXPInLevel = playerXPInLevel
            self.lastTotalPlayerXP = calculateTotalXPForState(playerLevel, playerXPInLevel, function(lvl)
                return playerManager:getExperienceRequiredForLevel(lvl)
            end)
        else
            if self.progressLevelBar then self.progressLevelBar:setLevel(1, 0) end
            self.lastPlayerLevel = 1; self.lastPlayerXPInLevel = 0; self.lastTotalPlayerXP = 0
        end

        local playerHP = pState.currentHealth or 100
        local playerMaxHP = pState.maxHealth or 100
        local playerName = hunterCurrentInfo.name or "Jogador"
        local playerRank = hunterCurrentInfo.finalRankId or "N/A"

        if self.playerHPBar then
            self.playerHPBar:updateBaseInfo(playerName, playerRank, playerMaxHP)
            self.playerHPBar:setCurrentHP(playerHP)
        end
        self.lastPlayerHP = playerHP
        self.lastPlayerMaxHP = playerMaxHP
        self.lastPlayerName = playerName
        self.lastPlayerRank = playerRank
    else
        -- Fallback se playerManager não estiver disponível
        if self.progressLevelBar then self.progressLevelBar:setLevel(1, 0) end
        self.lastPlayerLevel = 1; self.lastPlayerXPInLevel = 0; self.lastTotalPlayerXP = 0
        if self.playerHPBar then
            self.playerHPBar:updateBaseInfo("Jogador", "N/A", 100)
            self.playerHPBar:setCurrentHP(100)
        end
        self.lastPlayerHP = 100; self.lastPlayerMaxHP = 100; self.lastPlayerName = "Jogador"; self.lastPlayerRank = "N/A"
    end

    print("HUDGameplayManager: reset chamado")
end

function HUDGameplayManager:destroy()
    if BossHealthBarManager and BossHealthBarManager.destroy then
        BossHealthBarManager:destroy()
    end
end

return HUDGameplayManager
