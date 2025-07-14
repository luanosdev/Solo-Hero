---------------------------------------------------------------------------------
-- BaseRune - Classe base para todas as runas do jogo
-- Centraliza funcionalidades comuns: upgrades, animações, dano, otimizações
-- Utiliza table_pool e combat_helpers para máxima performance
---------------------------------------------------------------------------------

local RenderPipeline = require("src.core.render_pipeline")
local TablePool = require("src.utils.table_pool")
local CombatHelpers = require("src.utils.combat_helpers")
local RuneUpgradesData = require("src.data.rune_upgrades_data")

---@class BaseRuneConfig
---@field damage number|nil Dano base da runa
---@field cooldown number|nil Cooldown entre ativações
---@field radius number|nil Raio de efeito
---@field range number|nil Alcance máximo
---@field duration number|nil Duração de efeitos

---@class BaseRuneAnimation
---@field frames love.Image[] Frames da animação
---@field frameCount number Número total de frames
---@field frameTime number Tempo por frame em segundos
---@field currentFrame number Frame atual (1-indexado)
---@field timer number Timer interno da animação
---@field scale number Escala da animação
---@field loaded boolean Se os frames foram carregados
---@field width number Largura do frame base
---@field height number Altura do frame base


---@class BaseRune
---@field identifier string Identificador da classe de runa
---@field defaultDepth number Profundidade padrão
---@field animationPath string|nil Caminho base para os frames de animação
---@field playerManager PlayerManager Gerenciador do jogador

---@class BaseRuneInstance : BaseRune
---@field identifier string Identificador único da runa (ex: "rune_aura")
---@field item RuneItemInstance Dados da instância do item da runa
---@field name string Nome da runa
---@field baseConfig BaseRuneConfig Configuração original (sem upgrades)
---@field currentConfig BaseRuneConfig Configuração atual (com upgrades aplicados)
---@field appliedUpgrades table<string, number> Upgrades aplicados e suas quantidades
---@field animation BaseRuneAnimation|nil Configuração da animação (se aplicável)
---@field currentCooldown number Cooldown atual restante
---@field defaultDepth number Profundidade padrão para renderização
local BaseRune = {}
BaseRune.__index = BaseRune

-- Configurações padrão
BaseRune.identifier = "base_rune"
BaseRune.defaultDepth = RenderPipeline.DEPTH_ENTITIES
BaseRune.animationPath = nil

--- Função utilitária para deep copy de tabelas
--- @param orig table Tabela original
--- @return table Cópia profunda da tabela
local function deepcopy(orig)
    if type(orig) ~= 'table' then return orig end

    local copy = TablePool.getGeneric()
    for orig_key, orig_value in pairs(orig) do
        copy[deepcopy(orig_key)] = deepcopy(orig_value)
    end
    return setmetatable(copy, deepcopy(getmetatable(orig)))
end

--- Carrega frames de animação para uma runa
--- @param animationPath string Caminho base dos frames (ex: "assets/abilities/aura/aura_")
--- @param frameCount number Número de frames a carregar
--- @param frameExtension string|nil Extensão dos arquivos (padrão: ".png")
--- @return love.Image[] frames Tabela com os frames carregados
--- @return boolean success True se todos os frames foram carregados
function BaseRune.loadAnimationFrames(animationPath, frameCount, frameExtension)
    local frames = TablePool.getArray()
    local extension = frameExtension or ".png"
    local success = true

    for i = 1, frameCount do
        local framePath = animationPath .. i .. extension
        local frameSuccess, frame = pcall(love.graphics.newImage, framePath)

        if frameSuccess then
            frames[i] = frame
            Logger.debug("base_rune.animation.load_frame",
                string.format("[BaseRune:loadAnimationFrames] Frame %d carregado: %s", i, framePath))
        else
            Logger.error("base_rune.animation.load_failed",
                string.format("[BaseRune:loadAnimationFrames] Erro ao carregar frame %d: %s", i, framePath))
            success = false
        end
    end

    return frames, success
end

--- Construtor da BaseRune
--- @param playerManager PlayerManager Instância do gerenciador do jogador
--- @param itemData RuneItemInstance Dados da instância do item da runa
--- @return BaseRuneInstance Instância da runa base
function BaseRune:new(playerManager, itemData)
    local instance = setmetatable(TablePool.getGeneric(), self)

    instance.playerManager = playerManager
    instance.item = itemData
    instance.identifier = self.identifier
    instance.defaultDepth = self.defaultDepth

    -- Obtém dados base da runa
    local runeBaseData = playerManager.itemDataManager:getBaseItemData(itemData.itemBaseId)

    instance.name = runeBaseData.name

    -- Inicializa configurações
    instance.baseConfig = instance:createBaseConfig(runeBaseData)
    instance.currentConfig = deepcopy(instance.baseConfig)
    instance.appliedUpgrades = TablePool.getGeneric()
    instance.currentCooldown = instance.currentConfig.cooldown or 0

    -- Inicializa animação se o caminho estiver definido
    if self.animationPath then
        instance.animation = instance:initializeAnimation()
    end

    Logger.info(
        "base_rune.create",
        string.format("[BaseRune:new] Runa criada: %s (ID: %s)", instance.name, instance.identifier)
    )

    return instance
end

--- Cria configuração base da runa (deve ser sobrescrita pelas classes filhas)
--- @param runeBaseData table Dados base da runa do ItemDataManager
--- @return BaseRuneConfig Configuração base da runa
function BaseRune:createBaseConfig(runeBaseData)
    return TablePool.getGeneric()
end

--- Inicializa sistema de animação da runa
--- @return BaseRuneAnimation|nil Configuração da animação ou nil se não aplicável
function BaseRune:initializeAnimation()
    if not self.animationPath then return nil end

    local animation = TablePool.getGeneric()
    animation.frameCount = self.animationFrameCount or 1
    animation.frameTime = self.animationFrameTime or 0.1
    animation.currentFrame = 1
    animation.timer = 0
    animation.scale = 1
    animation.loaded = false
    animation.width = self.animationWidth or 64
    animation.height = self.animationHeight or 64

    -- Carrega frames
    animation.frames, animation.loaded = BaseRune.loadAnimationFrames(
        self.animationPath,
        animation.frameCount
    )

    return animation
end

--- Aplica upgrades da runa baseado no sistema de melhorias
function BaseRune:applyUpgrades()
    if not self.playerManager or not self.playerManager.runeController then
        error("BaseRune:applyUpgrades - playerManager ou runeController não encontrado")
    end

    local runeController = self.playerManager.runeController
    local runeUpgrades = runeController:getRuneUpgrades(self.identifier)

    if not runeUpgrades then
        Logger.debug(
            "base_rune.upgrades.none",
            string.format("[BaseRune:applyUpgrades] Nenhum upgrade encontrado para %s", self.identifier)
        )
        return
    end

    -- Aplica cada upgrade
    for upgradeId, upgradeCount in pairs(runeUpgrades) do
        local upgradeData = RuneUpgradesData.GetUpgradesByRuneId(self.identifier)
        if upgradeData then
            for _, upgrade in ipairs(upgradeData) do
                if upgrade.id == upgradeId then
                    self:applyUpgrade(upgrade, upgradeCount)
                    break
                end
            end
        end
    end

    Logger.info(
        "base_rune.upgrades.applied",
        string.format("[BaseRune:applyUpgrades] Upgrades aplicados para %s", self.identifier)
    )
end

--- Aplica um upgrade específico à runa
--- @param upgrade table Dados do upgrade
--- @param count number Quantidade de vezes que o upgrade foi aplicado
function BaseRune:applyUpgrade(upgrade, count)
    if not upgrade or not upgrade.effects then
        error("BaseRune:applyUpgrade - upgrade inválido ou sem efeitos")
    end

    for _, effect in ipairs(upgrade.effects) do
        self:applyUpgradeEffect(effect, count)
    end

    -- Registra o upgrade aplicado
    self.appliedUpgrades[upgrade.id] = (self.appliedUpgrades[upgrade.id] or 0) + count

    Logger.debug(
        "base_rune.upgrade.applied",
        string.format("[BaseRune:applyUpgrade] Upgrade '%s' aplicado %d vez(es)", upgrade.name, count)
    )
end

--- Aplica um efeito específico de upgrade (deve ser sobrescrita pelas classes filhas)
--- @param effect table Efeito do upgrade
--- @param count number Quantidade de aplicações
function BaseRune:applyUpgradeEffect(effect, count)
    -- Implementação base - classes filhas devem sobrescrever
    local effectType = effect.type
    local value = effect.value
    local isPercentage = effect.is_percentage

    if not self.currentConfig[effectType] or not self.baseConfig[effectType] then
        error(string.format("BaseRune:applyUpgradeEffect - Efeito desconhecido: %s", effectType))
    end

    if isPercentage then
        self.currentConfig[effectType] = self.baseConfig[effectType] * (1 + (value * count / 100))
    else
        self.currentConfig[effectType] = self.baseConfig[effectType] + (value * count)
    end
end

--- Atualiza a animação da runa
--- @param dt number Delta time
function BaseRune:updateAnimation(dt)
    if not self.animation or not self.animation.loaded then return end

    self.animation.timer = self.animation.timer + dt
    if self.animation.timer >= self.animation.frameTime then
        self.animation.timer = self.animation.timer - self.animation.frameTime
        self.animation.currentFrame = self.animation.currentFrame + 1

        if self.animation.currentFrame > self.animation.frameCount then
            self.animation.currentFrame = 1
        end
    end
end

--- Aplica dano a um alvo usando CombatHelpers otimizado
--- @param target BaseEnemy Inimigo alvo
--- @param damage number|nil Dano a aplicar (usa currentConfig.damage se nil)
--- @param damageSource string|nil Fonte do dano (padrão: identifier da runa)
--- @return boolean success True se o dano foi aplicado com sucesso
function BaseRune:applyDamageToTarget(target, damage, damageSource)
    if not target or not target.isAlive or not target.isAlive then
        return false
    end

    local finalDamage = damage or self.currentConfig.damage or 0
    local source = damageSource or self.identifier

    -- Usa CombatHelpers para cálculo otimizado de dano
    -- Por enquanto, não usamos crit chance e crit multiplier
    local calculatedDamage, wasCritical, wasSuperCritical = CombatHelpers.calculateOptimizedDamage(
        finalDamage,
        0,
        0
    )

    -- Aplica o dano
    local success = target:takeDamage(calculatedDamage, wasCritical, wasSuperCritical)

    -- Registra estatísticas
    if success and self.playerManager.registerDamageDealt then
        self.playerManager:registerDamageDealt(
            calculatedDamage,
            wasCritical,
            { abilityId = self.identifier },
            wasSuperCritical
        )
    end

    return success
end

--- Encontra inimigos em área circular usando CombatHelpers otimizado
--- @param center Vector2D Centro da busca
--- @param radius number Raio da busca
--- @return BaseEnemy[] Lista de inimigos encontrados (do TablePool)
function BaseRune:findEnemiesInRadius(center, radius)
    return CombatHelpers.findEnemiesInCircularArea(center, radius, self.playerManager:getPlayerSprite())
end

--- Encontra inimigos em área cônica usando CombatHelpers otimizado
--- @param coneArea table Área do cone {position, angle, range, halfWidth}
--- @return BaseEnemy[] Lista de inimigos encontrados (do TablePool)
function BaseRune:findEnemiesInCone(coneArea)
    return CombatHelpers.findEnemiesInConeArea(coneArea, self.playerManager:getPlayerSprite())
end

--- Encontra inimigos em linha usando CombatHelpers otimizado
--- @param lineArea table Área da linha {startPosition, endPosition, width}
--- @return BaseEnemy[] Lista de inimigos encontrados (do TablePool)
function BaseRune:findEnemiesInLine(lineArea)
    return CombatHelpers.findEnemiesInLineArea(lineArea, self.playerManager:getPlayerSprite())
end

--- Desenha a animação da runa (se aplicável)
--- @param x number Posição X
--- @param y number Posição Y
--- @param rotation number|nil Rotação em radianos
--- @param scaleX number|nil Escala X
--- @param scaleY number|nil Escala Y
function BaseRune:drawAnimation(x, y, rotation, scaleX, scaleY)
    if not self.animation or not self.animation.loaded or not self.animation.frames then return end

    local frame = self.animation.frames[self.animation.currentFrame]
    if not frame then return end

    local rot = rotation or 0
    local sx = scaleX or self.animation.scale
    local sy = scaleY or self.animation.scale

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        frame,
        x, y,
        rot,
        sx, sy,
        frame:getWidth() / 2,
        frame:getHeight() / 2
    )
end

--- Métodos padrão que devem ser implementados pelas classes filhas

--- Atualiza a lógica da runa
--- @param dt number Delta time
--- @param enemies BaseEnemy[] Lista de inimigos
--- @param finalStats FinalStats Estatísticas finais do jogador
function BaseRune:update(dt, enemies, finalStats)
    -- Atualiza cooldown
    if self.currentCooldown > 0 then
        self.currentCooldown = math.max(0, self.currentCooldown - dt)
    end

    -- Atualiza animação
    self:updateAnimation(dt)

    -- Classes filhas devem implementar lógica específica
end

--- Desenha a runa
function BaseRune:draw()
    -- Classes filhas devem implementar
end

--- Executa a habilidade da runa
--- @param x number|nil Posição X (se aplicável)
--- @param y number|nil Posição Y (se aplicável)
--- @return boolean success True se a habilidade foi executada
function BaseRune:cast(x, y)
    -- Classes filhas devem implementar
    return true
end

--- Coleta renderáveis para o pipeline de renderização
--- @param renderPipeline RenderPipeline Pipeline de renderização
--- @param sortY number Y base para ordenação
function BaseRune:collectRenderables(renderPipeline, sortY)
    -- Classes filhas podem implementar se necessário
end

--- Limpa recursos da runa (TablePool cleanup)
function BaseRune:cleanup()
    if self.baseConfig then
        TablePool.releaseGeneric(self.baseConfig)
        self.baseConfig = nil
    end

    if self.currentConfig then
        TablePool.releaseGeneric(self.currentConfig)
        self.currentConfig = nil
    end

    if self.appliedUpgrades then
        TablePool.releaseGeneric(self.appliedUpgrades)
        self.appliedUpgrades = nil
    end

    if self.animation and self.animation.frames then
        TablePool.releaseArray(self.animation.frames)
        TablePool.releaseGeneric(self.animation)
        self.animation = nil
    end

    Logger.debug(
        "base_rune.cleanup",
        string.format("[BaseRune:cleanup] Recursos liberados para %s", self.identifier)
    )
end

return BaseRune
