local ProgressLevelBar = require("src.ui.components.ProgressLevelBar")
local fonts = require("src.ui.fonts")

---@class HUDGameplayManager
---@field managerRegistry ManagerRegistry Instância do registro de managers.
---@field playerManager PlayerManager Instância do PlayerManager.
---@field progressLevelBar ProgressLevelBar Instância da barra de progresso de nível.
---@field lastPlayerLevel number Armazena o nível do jogador no frame anterior.
---@field lastPlayerXPInLevel number Armazena o XP do jogador DENTRO do nível no frame anterior.
---@field lastTotalPlayerXP number Armazena o XP TOTAL ACUMULADO do jogador no frame anterior.

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

    if not instance.playerManager then
        error("HUDGameplayManager: PlayerManager não encontrado no ManagerRegistry!")
    end

    -- Garante que as fontes estejam carregadas
    if not fonts.main then fonts.load() end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local mainFont = fonts.main_normal or fonts.main or love.graphics.getFont()
    local levelNumFont = fonts.main_large or fonts.main or love.graphics.getFont()
    local xpGainFont = fonts.main_small or fonts.main or love.graphics.getFont()

    instance.progressLevelBar = ProgressLevelBar:new({
        x = 20,
        y = screenHeight - 100,
        w = screenWidth * 0.25,
        fontMain = mainFont,
        fontLevelNumber = levelNumFont,
        fontXpGain = xpGainFont, -- Será usado pelo ProgressLevelBar para o texto +XPa
        initialLevel = 1,
        initialXP = 0,
        xpForNextLevel = function(level_from_bar)
            if instance.playerManager and instance.playerManager.getExperienceRequiredForLevel then
                return instance.playerManager:getExperienceRequiredForLevel(level_from_bar)
            else
                local lvl = level_from_bar or 1
                if lvl <= 0 then lvl = 1 end
                return lvl * 100 + 50
            end
        end,
        padding = { vertical = 6, horizontal = 10 },
        colors = {
            levelText = { 210, 210, 220, 255 },
            levelNumber = { 255, 90, 90, 255 },
            xpText = { 190, 190, 190, 255 },
            progressBarBase = { 60, 60, 70, 255 },
            progressBarFill = { 230, 80, 80, 255 },
            xpGainText = { 50, 205, 50, 255 },
            trailBar = { 48, 48, 56, 255 },
        }
    })

    -- Sincronização inicial dos valores rastreados
    if instance.playerManager and instance.playerManager.state and instance.playerManager.getExperienceRequiredForLevel then
        local initialLevel = instance.playerManager.state.level or 1
        local initialXPInLevel = instance.playerManager.state.experience or 0

        instance.progressLevelBar:setLevel(initialLevel, initialXPInLevel) -- Sincroniza a barra visualmente

        instance.lastPlayerLevel = initialLevel
        instance.lastPlayerXPInLevel = initialXPInLevel
        instance.lastTotalPlayerXP = calculateTotalXPForState(initialLevel, initialXPInLevel, function(lvl)
            return instance.playerManager:getExperienceRequiredForLevel(lvl)
        end)
    else
        -- Fallback se o playerManager não estiver pronto no momento da criação do HUD
        instance.progressLevelBar:setLevel(1, 0)
        instance.lastPlayerLevel = 1
        instance.lastPlayerXPInLevel = 0
        instance.lastTotalPlayerXP = 0
        print("HUDGameplayManager:new - PlayerManager ou state não disponível para sincronização inicial completa.")
    end

    return instance
end

--- Atualiza todos os elementos da UI gerenciados.
---@param dt number Delta time.
function HUDGameplayManager:update(dt)
    if not self.playerManager or not self.playerManager.state or not self.playerManager.getExperienceRequiredForLevel then
        if self.progressLevelBar then self.progressLevelBar:update(dt) end
        return
    end

    local currentLevel = self.playerManager.state.level or 1
    local currentXPInLevel = self.playerManager.state.experience or 0

    -- Calcula o XP total acumulado atual
    local currentTotalXP = calculateTotalXPForState(currentLevel, currentXPInLevel, function(lvl)
        return self.playerManager:getExperienceRequiredForLevel(lvl)
    end)

    local xpGainedSinceLastFrame = currentTotalXP - self.lastTotalPlayerXP

    if xpGainedSinceLastFrame > 0 then
        self.progressLevelBar:addXP(xpGainedSinceLastFrame)
    elseif currentLevel ~= self.lastPlayerLevel or currentXPInLevel ~= self.lastPlayerXPInLevel then
        -- Se XP não aumentou, mas nível ou XP no nível mudou (ex: XP perdido, ou reset, ou primeira sincronização pós-load)
        -- Força uma sincronização visual direta sem a animação de "ganho".
        self.progressLevelBar:setLevel(currentLevel, currentXPInLevel)
    end

    -- Atualiza os valores rastreados para o próximo frame
    self.lastTotalPlayerXP = currentTotalXP
    self.lastPlayerLevel = currentLevel
    self.lastPlayerXPInLevel = currentXPInLevel

    self.progressLevelBar:update(dt) -- Atualiza animações internas da barra (como o texto de +XP desaparecendo)
end

--- Desenha todos os elementos da UI gerenciados.
function HUDGameplayManager:draw()
    self.progressLevelBar:draw()
end

--- Reseta o estado do manager (se necessário).
function HUDGameplayManager:reset()
    if self.progressLevelBar and self.playerManager and self.playerManager.state and self.playerManager.getExperienceRequiredForLevel then
        local playerLevel = self.playerManager.state.level or 1
        local playerXPInLevel = self.playerManager.state.experience or 0

        self.progressLevelBar:setLevel(playerLevel, playerXPInLevel)

        self.lastPlayerLevel = playerLevel
        self.lastPlayerXPInLevel = playerXPInLevel
        self.lastTotalPlayerXP = calculateTotalXPForState(playerLevel, playerXPInLevel, function(lvl)
            return self.playerManager:getExperienceRequiredForLevel(lvl)
        end)
    else
        if self.progressLevelBar then
            self.progressLevelBar:setLevel(1, 0)
        end
        self.lastPlayerLevel = 1
        self.lastPlayerXPInLevel = 0
        self.lastTotalPlayerXP = 0
    end
    print("HUDGameplayManager: reset chamado")
end

return HUDGameplayManager
