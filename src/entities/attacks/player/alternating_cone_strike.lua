----------------------------------------------------------------------------
-- Alternating Cone Strike V2 (Otimizado)
-- Versão super otimizada usando a nova arquitetura BaseAttackAbility.
-- Performance máxima com cache, pooling e sistemas unificados.
----------------------------------------------------------------------------

local BaseAttackAbility = require("src.entities.attacks.base_attack_ability")
local AttackAnimationSystem = require("src.utils.attack_animation_system")
local MultiAttackCalculator = require("src.utils.multi_attack_calculator")
local CombatHelpers = require("src.utils.combat_helpers")

---@class AlternatingConeStrikeVisualAttack
---@field animationDuration number
---@field segments number
---@field color table

---@class AlternatingConeStrike : BaseAttackAbility
---@field hitLeftNext boolean Controla alternância dos lados
---@field activeAnimations AnimationInstance[] Animações ativas
---@field area table Área de efeito calculada
---@field enemiesKnockedBackInThisCast table Controle de knockback
local AlternatingConeStrike = setmetatable({}, { __index = BaseAttackAbility })
AlternatingConeStrike.__index = AlternatingConeStrike

-- Configurações otimizadas da habilidade
local CONFIG = {
    name = "Golpe Cônico Alternado",
    description = "Golpeia alternadamente metades de um cone.",
    damageType = "melee",
    attackType = "melee",
    visual = {
        preview = {
            active = false,
            lineLength = 50,
            color = { 0.7, 0.7, 0.7, 0.2 }
        },
        attack = {
            animationDuration = 0.1,
            segments = 16,
            color = { 0.8, 0.1, 0.8, 0.6 }
        }
    },
    constants = {
        DELAY_STEP = 0.2,
        SHELL_WIDTH_RATIO = 0.18,
        MIN_SHELL_WIDTH = 12
    }
}

--- Cria nova instância otimizada
---@param playerManager PlayerManager
---@param weaponInstance BaseWeapon
---@return AlternatingConeStrike
function AlternatingConeStrike:new(playerManager, weaponInstance)
    ---@type AlternatingConeStrike
    local o = BaseAttackAbility.new(self, playerManager, weaponInstance, CONFIG)
    setmetatable(o, self)

    -- Estado específico da habilidade
    o.hitLeftNext = true
    o.activeAnimations = {}
    o.enemiesKnockedBackInThisCast = {}

    -- Área de efeito pré-alocada (reutilizada)
    o.area = {
        position = { x = 0, y = 0 }, -- Será atualizada com spawn offset
        angle = 0,
        range = 0,
        angleWidth = 0,
        halfWidth = 0
    }

    -- Cores da weaponInstance
    if weaponInstance.previewColor then
        o.visual.preview.color = weaponInstance.previewColor
    end
    if weaponInstance.attackColor then
        o.visual.attack.color = weaponInstance.attackColor
    end

    return o
end

--- Hook para atualização quando stats mudam (otimizado)
function AlternatingConeStrike:onStatsUpdated()
    -- Recalcula área apenas quando stats mudam
    local baseData = self.cachedBaseData
    local stats = self.cachedStats

    local newRange = baseData.range * stats.range
    local newAngleWidth = baseData.angle * stats.attackArea

    if newRange ~= self.area.range or newAngleWidth ~= self.area.angleWidth then
        self.area.range = newRange
        self.area.angleWidth = newAngleWidth
        self.area.halfWidth = newAngleWidth * 0.5
    end
end

--- Update específico otimizado
---@param dt number Delta time
---@param angle number Ângulo atual
function AlternatingConeStrike:updateSpecific(dt, angle)
    -- Atualiza ângulo (sempre necessário)
    self.area.angle = angle

    -- Atualiza posição de spawn com offset do raio do player
    local spawnPos = self:calculateSpawnPosition(angle)
    self.area.position.x = spawnPos.x
    self.area.position.y = spawnPos.y

    -- Atualiza animações usando sistema unificado
    AttackAnimationSystem.updateBatch(self.activeAnimations, dt)
end

--- Cast específico super otimizado
---@param args table Argumentos do cast
---@return boolean success
function AlternatingConeStrike:castSpecific(args)
    -- Rastreia inimigos com knockback neste cast
    self.enemiesKnockedBackInThisCast = {}

    local attackLeftThisCast = self.hitLeftNext

    -- Calcula multi-attacks usando calculadora unificada
    local multiResult = MultiAttackCalculator.calculateBasic(
        self.cachedStats.multiAttackChance,
        love.timer.getTime() -- Frame number para cache
    )

    -- Executa ataques com delays escalonados
    local delays = MultiAttackCalculator.calculateAttackDelays(
        multiResult.totalAttacks,
        CONFIG.constants.DELAY_STEP
    )

    local currentHitIsLeft = attackLeftThisCast
    local attackInstances = {} -- Para processamento em lote

    -- Executa todos os ataques
    for i = 1, multiResult.totalAttacks do
        local delay = delays[i]

        -- Executa ataque imediato (sem delay)
        if delay == 0 then
            local enemies = CombatHelpers.findEnemiesInConeHalfArea(
                self.area,
                currentHitIsLeft,
                self.playerManager:getPlayerSprite()
            )
            if #enemies > 0 then
                table.insert(attackInstances, {
                    enemies = enemies,
                    knockbackData = self.knockbackData
                })
            end
        end

        -- Cria animação usando sistema unificado
        local animationData = AttackAnimationSystem.createConeData(self.area, currentHitIsLeft)
        local animation = AttackAnimationSystem.createInstance(
            "alternating_cone",
            CONFIG.visual.attack.animationDuration,
            delay,
            animationData
        )
        table.insert(self.activeAnimations, animation)

        -- Alterna lado para próximo ataque
        currentHitIsLeft = not currentHitIsLeft
    end

    -- Aplica efeitos em lote (mais eficiente)
    if #attackInstances > 0 then
        CombatHelpers.applyBatchHitEffects(
            attackInstances,
            self.cachedStats,
            self.playerManager,
            self.weaponInstance
        )
    end

    -- Alterna estado para próximo cast
    self.hitLeftNext = not self.hitLeftNext

    return true
end

--- Executa ataque otimizado usando helpers unificados
---@param hitLeft boolean True para lado esquerdo
---@return BaseEnemy[] enemies Lista de inimigos atingidos
function AlternatingConeStrike:executeAttackOptimized(hitLeft)
    if not self.area.range or self.area.range <= 0 then
        return {}
    end

    -- Usa função otimizada com cache
    local enemies = CombatHelpers.findEnemiesInConeHalfArea(
        self.area,
        hitLeft,
        self.playerManager:getPlayerSprite()
    )

    return enemies
end

--- Desenho otimizado com menos chamadas
function AlternatingConeStrike:draw()
    if not self.area then return end

    -- Preview otimizado
    if self.visual.preview.active then
        self:drawConeOutlineOptimized()
    end

    -- Animações ativas usando sistema unificado
    for _, animation in ipairs(self.activeAnimations) do
        if animation.delay <= 0 then
            self:drawConeFillOptimized(animation)
        end
    end
end

--- Desenho de outline otimizado (menos allocations)
function AlternatingConeStrike:drawConeOutlineOptimized()
    if not self.area.range or self.area.range <= 0 then return end

    love.graphics.setColor(self.visual.preview.color)

    local cx, cy = self.area.position.x, self.area.position.y
    local range = self.area.range
    local halfWidth = self.area.halfWidth
    local startAngle = self.area.angle - halfWidth
    local endAngle = self.area.angle + halfWidth

    -- Desenho simplificado usando menos vértices
    local segments = 16 -- Reduzido para melhor performance
    local angleStep = (endAngle - startAngle) / segments

    -- Usa uma única chamada de line
    local vertices = { cx, cy }
    for i = 0, segments do
        local angle = startAngle + angleStep * i
        table.insert(vertices, cx + range * math.cos(angle))
        table.insert(vertices, cy + range * math.sin(angle))
    end
    table.insert(vertices, cx)
    table.insert(vertices, cy)

    love.graphics.line(unpack(vertices))
    love.graphics.setColor(1, 1, 1, 1)
end

--- Desenho de preenchimento otimizado
---@param animation AnimationInstance Instância da animação
function AlternatingConeStrike:drawConeFillOptimized(animation)
    local areaData = animation.data.area
    local hitLeft = animation.data.hitLeft
    local progress = animation.progress

    if not areaData or progress < 0.01 then return end

    local playerRadius = self.playerManager.movementController.player.radius or 10
    local fullRange = areaData.range

    -- Calcula shell usando sistema unificado
    local shellWidth = math.max(CONFIG.constants.MIN_SHELL_WIDTH, fullRange * CONFIG.constants.SHELL_WIDTH_RATIO)
    local shellInner, shellOuter, isValid = AttackAnimationSystem.calculateShellProgress(
        progress, playerRadius, fullRange, shellWidth
    )

    if not isValid then return end

    local cx, cy = areaData.position.x, areaData.position.y
    local baseAngle = areaData.angle
    local halfWidth = areaData.halfWidth

    -- Determina ângulos baseado no lado
    local startAngle, endAngle
    if hitLeft then
        startAngle = baseAngle - halfWidth
        endAngle = baseAngle
    else
        startAngle = baseAngle
        endAngle = baseAngle + halfWidth
    end

    -- Desenho otimizado com menos chamadas
    local segments = CONFIG.visual.attack.segments
    local vertices = {}
    local angleStep = (endAngle - startAngle) / segments

    -- Arco externo
    for i = 0, segments do
        local angle = startAngle + angleStep * i
        table.insert(vertices, cx + shellOuter * math.cos(angle))
        table.insert(vertices, cy + shellOuter * math.sin(angle))
    end

    -- Arco interno (invertido)
    for i = segments, 0, -1 do
        local angle = startAngle + angleStep * i
        table.insert(vertices, cx + shellInner * math.cos(angle))
        table.insert(vertices, cy + shellInner * math.sin(angle))
    end

    if #vertices >= 6 then
        local color = self.visual.attack.color
        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1.0) * 0.6)
        love.graphics.polygon("fill", unpack(vertices))
        love.graphics.setColor(1, 1, 1, 1)
    end
end

--- Função de debug para performance
function AlternatingConeStrike:getDebugInfo()
    local baseInfo = {
        cooldown = self:getCooldownRemaining(),
        activeAnimations = #self.activeAnimations,
        area = {
            range = self.area.range,
            angleWidth = self.area.angleWidth
        }
    }

    -- Informações de cache dos sistemas
    local combatInfo = CombatHelpers.getPerformanceInfo()
    local animInfo = AttackAnimationSystem.getPoolInfo()
    local calcInfo = MultiAttackCalculator.getCacheInfo()

    return {
        ability = baseInfo,
        combatHelpers = combatInfo,
        animationSystem = animInfo,
        multiAttackCalc = calcInfo
    }
end

return AlternatingConeStrike
