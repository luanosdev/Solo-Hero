local ProgressLevelBar = require("src.ui.components.ProgressLevelBar")
local PlayerHPBar = require("src.ui.components.PlayerHPBar")
local fonts = require("src.ui.fonts")

---@class HUDGameplayManager
---@field managerRegistry ManagerRegistry Instância do registro de managers.
---@field playerManager PlayerManager Instância do PlayerManager.
---@field hunterManager HunterManager Instância do HunterManager.
---@field progressLevelBar ProgressLevelBar Instância da barra de progresso de nível.
---@field playerHPBar PlayerHPBar Instância da barra de HP do jogador.
---@field lastPlayerLevel number Armazena o nível do jogador no frame anterior.
---@field lastPlayerXPInLevel number Armazena o XP do jogador DENTRO do nível no frame anterior.
---@field lastTotalPlayerXP number Armazena o XP TOTAL ACUMULADO do jogador no frame anterior.
---@field lastPlayerHP number Armazena o HP do jogador no frame anterior.
---@field lastPlayerMaxHP number Armazena o MaxHP do jogador no frame anterior.
---@field lastPlayerName string Armazena o nome do jogador no frame anterior.
---@field lastPlayerRank string Armazena o rank do jogador no frame anterior.
---@field basePlayerHPBarWidth number Largura base da barra de HP para cálculo de escalonamento.
---@field basePlayerMaxHPForWidth number MaxHP base para cálculo de escalonamento da largura da barra de HP.
local HUDGameplayManager = {}
HUDGameplayManager.__index = HUDGameplayManager

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

---@param managerRegistry ManagerRegistry O registro de todos os managers.
---@return HUDGameplayManager instance
function HUDGameplayManager:new(managerRegistry)
    local instance = setmetatable({}, HUDGameplayManager)
    instance.managerRegistry = managerRegistry
    instance.playerManager = instance.managerRegistry:get("playerManager")
    instance.hunterManager = instance.managerRegistry:get("hunterManager")

    if not instance.playerManager or not instance.hunterManager then
        error("HUDGameplayManager: PlayerManager ou HunterManager não encontrado no ManagerRegistry!")
    end

    -- Garante que as fontes estejam carregadas
    if not fonts.main then fonts.load() end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local mainFont = fonts.main_normal or fonts.main or love.graphics.getFont()
    local levelNumFont = fonts.main_large or fonts.main or love.graphics.getFont()
    local xpGainFont = fonts.main_small or fonts.main or love.graphics.getFont()
    local hunterData = instance.hunterManager:getHunterData(instance.playerManager.currentHunterId)

    local initialPlayerState = instance.playerManager.state or {}
    local initialLevel = initialPlayerState.level
    local initialXP = initialPlayerState.experience
    local initialHP = initialPlayerState.currentHealth
    local initialMaxHP = initialPlayerState.maxHealth
    local initialName = hunterData.name or "Jogador"
    local initialRank = hunterData.finalRankId or "N/A"

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
        padding = { vertical = 6, horizontal = 10 },
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
        hpBarAnimationSpeed = initialMaxHP * 0.8 -- 80% do MaxHP por segundo
    }
    instance.playerHPBar = PlayerHPBar:new(hpBarConfig)

    -- Armazena a largura e MaxHP base para escalonamento futuro
    instance.basePlayerHPBarWidth = hpBarConfig.w
    instance.basePlayerMaxHPForWidth = initialMaxHP > 0 and initialMaxHP or
        100 -- Evita divisão por zero se MaxHP inicial for 0

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
            if instance.playerManager and instance.playerManager.getExperienceRequiredForLevel then
                return instance.playerManager:getExperienceRequiredForLevel(level_from_bar)
            else
                local lvl = level_from_bar or 1; if lvl <= 0 then lvl = 1 end
                return lvl * 100 + 50
            end
        end,
        padding = { vertical = 6, horizontal = 10 },
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
    instance.progressLevelBar = ProgressLevelBar:new(xpBarConfig)

    -- Posicionamento dinâmico das barras
    local paddingFromScreenEdgeX = 20
    local paddingFromScreenEdgeBottom = 20
    local spacingBetweenBars = 8

    instance.playerHPBar:setWidth(hpBarConfig.w) -- Garante que a largura seja aplicada antes de calcular altura
    instance.playerHPBar:setPosition(
        paddingFromScreenEdgeX,
        screenHeight - paddingFromScreenEdgeBottom - instance.playerHPBar.height
    )

    instance.progressLevelBar:setWidth(xpBarConfig.w)
    instance.progressLevelBar:setPosition(
        paddingFromScreenEdgeX,
        instance.playerHPBar.y - spacingBetweenBars - instance.progressLevelBar.height
    )

    -- Sincronização inicial dos valores rastreados para XP
    instance.lastPlayerLevel = initialLevel
    instance.lastPlayerXPInLevel = initialXP
    instance.lastTotalPlayerXP = calculateTotalXPForState(initialLevel, initialXP, function(lvl)
        return instance.playerManager:getExperienceRequiredForLevel(lvl)
    end)
    instance.progressLevelBar:setLevel(initialLevel, initialXP) -- Garante que a barra reflita o estado

    -- Sincronização inicial dos valores rastreados para HP
    instance.lastPlayerHP = initialHP
    instance.lastPlayerMaxHP = initialMaxHP
    instance.lastPlayerName = initialName
    instance.lastPlayerRank = initialRank
    instance.playerHPBar:updateBaseInfo(initialName, initialRank, initialMaxHP)
    instance.playerHPBar:setCurrentHP(initialHP)

    return instance
end

--- Atualiza todos os elementos da UI gerenciados.
---@param dt number Delta time.
function HUDGameplayManager:update(dt)
    if not self.playerManager or not self.playerManager.state or not self.hunterManager then
        if self.progressLevelBar then self.progressLevelBar:update(dt) end
        if self.playerHPBar then self.playerHPBar:update(dt) end
        return
    end

    local screenWidth = love.graphics.getWidth() -- Necessário para reposicionamento
    local screenHeight = love.graphics.getHeight()
    local paddingFromScreenEdgeBottom = 20       -- Usado no construtor, manter consistência
    local spacingBetweenBars = 8                 -- Usado no construtor, manter consistência

    -- Atualização da Barra de XP
    if self.playerManager.getExperienceRequiredForLevel then
        local currentLevel = self.playerManager.state.level or 1
        local currentXPInLevel = self.playerManager.state.experience or 0
        local currentTotalXP = calculateTotalXPForState(currentLevel, currentXPInLevel, function(lvl)
            return self.playerManager:getExperienceRequiredForLevel(lvl)
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
    local pState = self.playerManager.state
    local currentHunterInfo = self.hunterManager:getHunterData(self.playerManager.currentHunterId)
    local finalStats = self.playerManager:getCurrentFinalStats()

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
        -- Reposiciona HPBar primeiro para que sua altura seja finalizada
        self.playerHPBar:setPosition(
            self.playerHPBar.x, -- Mantem X atual
            screenHeight - paddingFromScreenEdgeBottom - self.playerHPBar.height
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
end

--- Desenha todos os elementos da UI gerenciados.
function HUDGameplayManager:draw()
    self.progressLevelBar:draw()
    self.playerHPBar:draw()
end

--- Reseta o estado do manager (se necessário).
function HUDGameplayManager:reset()
    if self.playerManager and self.playerManager.state and self.hunterManager then
        local pState = self.playerManager.state
        local hunterCurrentInfo = self.hunterManager:getHunterData(self.playerManager.currentHunterId)

        local playerLevel = pState.level or 1
        local playerXPInLevel = pState.experience or 0

        if self.progressLevelBar and self.playerManager.getExperienceRequiredForLevel then
            self.progressLevelBar:setLevel(playerLevel, playerXPInLevel)
            self.lastPlayerLevel = playerLevel
            self.lastPlayerXPInLevel = playerXPInLevel
            self.lastTotalPlayerXP = calculateTotalXPForState(playerLevel, playerXPInLevel, function(lvl)
                return self.playerManager:getExperienceRequiredForLevel(lvl)
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

return HUDGameplayManager
