----------------------------------------------------------------------------
-- Alternating Cone Strike Ability
-- Um ataque em cone rápido que atinge alternadamente a metade esquerda ou direita.
-- Refatorado para receber weaponInstance e buscar stats dinamicamente.
-- OTIMIZADO: Cache de dados, redução de alocações e performance melhorada.
----------------------------------------------------------------------------

local TablePool = require("src.utils.table_pool")
local CombatHelpers = require("src.utils.combat_helpers")

--- @class AlternatingConeStrike
--- @field playerManager PlayerManager
--- @field weaponInstance BaseWeapon
--- @field cooldownRemaining number
--- @field activeAttacks table
--- @field hitLeftNext boolean
--- @field visual table
--- @field knockbackPower number
--- @field knockbackForce number
--- @field enemiesKnockedBackInThisCast table
--- @field area table
--- @field cachedStats table
--- @field cachedBaseData table
--- @field lastStatsUpdateTime number
--- @field playerPosition table
--- @field knockbackData { power: number, force: number, attackerPosition: Vector2D }
local AlternatingConeStrike = {}
AlternatingConeStrike.__index = AlternatingConeStrike

-- Configurações visuais PADRÃO
AlternatingConeStrike.name = "Golpe Cônico Alternado"
AlternatingConeStrike.description = "Golpeia rapidamente em metades alternadas de um cone."
AlternatingConeStrike.damageType = "melee"
AlternatingConeStrike.visual = {
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
}

-- Cache de constantes para evitar recálculos
local STATS_CACHE_TIME = 0.1 -- Atualiza cache de stats a cada 100ms
local MIN_ATTACK_SPEED = 0.01
local DELAY_STEP = 0.2
local SHELL_WIDTH_RATIO = 0.18
local MIN_SHELL_WIDTH = 12

function AlternatingConeStrike:new(playerManager, weaponInstance)
    local o = setmetatable({}, self)

    if not playerManager or not weaponInstance then
        error("AlternatingConeStrike:new - playerManager e weaponInstance são obrigatórios.")
    end

    o.playerManager = playerManager
    o.weaponInstance = weaponInstance

    -- Cache de dados da arma (não muda durante o jogo)
    o.cachedBaseData = o.weaponInstance:getBaseData()
    if not o.cachedBaseData then
        error("AlternatingConeStrike:new - BaseData não encontrado.")
    end

    o.knockbackPower = o.cachedBaseData.knockbackPower
    o.knockbackForce = o.cachedBaseData.knockbackForce

    -- Pre-aloca tabela de knockback para reutilização
    o.knockbackData = {
        power = o.knockbackPower,
        force = o.knockbackForce,
        attackerPosition = { x = 0, y = 0 } -- Será atualizado
    }

    o.cooldownRemaining = 0
    o.activeAttacks = {}
    o.hitLeftNext = true

    -- Cache de stats e posição
    o.cachedStats = nil
    o.lastStatsUpdateTime = 0
    o.playerPosition = { x = 0, y = 0 } -- Reutiliza a mesma tabela

    -- Cores da weaponInstance
    o.visual.preview.color = weaponInstance.previewColor or o.visual.preview.color
    o.visual.attack.color = weaponInstance.attackColor or o.visual.attack.color

    -- Área de efeito
    o.area = {
        position = o.playerPosition, -- Referencia direta
        angle = 0,
        range = 0,
        angleWidth = 0,
        halfWidth = 0
    }

    -- Atualiza caches iniciais
    o:updateCaches(0)

    return o
end

-- Atualiza caches de dados frequentemente acessados
---@param currentTime number Tempo atual
function AlternatingConeStrike:updateCaches(currentTime)
    -- Atualiza posição do jogador (sempre)
    local newPos = self.playerManager:getPlayerPosition()
    self.playerPosition.x = newPos.x
    self.playerPosition.y = newPos.y
    self.knockbackData.attackerPosition.x = newPos.x
    self.knockbackData.attackerPosition.y = newPos.y

    -- Atualiza stats apenas se necessário (throttling)
    if not self.cachedStats or (currentTime - self.lastStatsUpdateTime) > STATS_CACHE_TIME then
        self.cachedStats = self.playerManager:getCurrentFinalStats()
        self.lastStatsUpdateTime = currentTime

        -- Recalcula área apenas quando stats mudam
        local newRange = self.cachedBaseData.range * self.cachedStats.range
        local newAngleWidth = self.cachedBaseData.angle * self.cachedStats.attackArea

        if newRange ~= self.area.range or newAngleWidth ~= self.area.angleWidth then
            self.area.range = newRange
            self.area.angleWidth = newAngleWidth
            self.area.halfWidth = newAngleWidth * 0.5
        end
    end
end

---@param dt number Delta time
---@param angle number Ângulo atual da mira do jogador.
function AlternatingConeStrike:update(dt, angle)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza caches de forma eficiente
    self:updateCaches(love.timer.getTime())

    -- Atualiza ângulo
    self.area.angle = angle

    -- Atualiza animações de ataques ativos
    local animationDuration = self.visual.attack.animationDuration
    for i = #self.activeAttacks, 1, -1 do
        local attackInstance = self.activeAttacks[i]
        if attackInstance.delay > 0 then
            attackInstance.delay = attackInstance.delay - dt
        else
            attackInstance.progress = attackInstance.progress + (dt / animationDuration)
        end

        if attackInstance.progress >= 1 then
            table.remove(self.activeAttacks, i)
        end
    end
end

---@return boolean success True se o ataque foi iniciado (mesmo que não acerte), False se estava em cooldown.
function AlternatingConeStrike:cast(args)
    -- Rastreia inimigos que já sofreram knockback
    self.enemiesKnockedBackInThisCast = {}

    if self.cooldownRemaining > 0 then
        return false
    end

    local attackLeftThisCast = self.hitLeftNext

    -- Garante que temos stats atualizados
    if not self.cachedStats then
        self.cachedStats = self.playerManager:getCurrentFinalStats()
    end

    -- Aplica cooldown
    local baseCooldown = self.cachedBaseData.cooldown or 1.0
    local totalAttackSpeed = math.max(self.cachedStats.attackSpeed, MIN_ATTACK_SPEED)
    self.cooldownRemaining = baseCooldown / totalAttackSpeed

    -- Calcula ataques extras
    local multiAttackChance = self.cachedStats.multiAttackChance
    local extraAttacks = math.floor(multiAttackChance)
    local decimalChance = multiAttackChance - extraAttacks

    local currentDelay = 0
    local currentHitIsLeft = attackLeftThisCast

    -- Executa primeiro ataque
    local success = self:executeAttack(currentHitIsLeft)
    self:createAttackAnimationInstance(currentHitIsLeft, currentDelay)
    currentDelay = currentDelay + DELAY_STEP

    -- Executa ataques extras
    for i = 1, extraAttacks do
        if success then
            currentHitIsLeft = not currentHitIsLeft
            success = self:executeAttack(currentHitIsLeft)
            self:createAttackAnimationInstance(currentHitIsLeft, currentDelay)
            currentDelay = currentDelay + DELAY_STEP
        else
            break
        end
    end

    -- Chance decimal de ataque extra
    if success and decimalChance > 0 and math.random() < decimalChance then
        currentHitIsLeft = not currentHitIsLeft
        self:executeAttack(currentHitIsLeft)
        self:createAttackAnimationInstance(currentHitIsLeft, currentDelay)
    end

    -- Alterna estado para próximo cast
    self.hitLeftNext = not self.hitLeftNext

    return true
end

-- Otimizado: remove parâmetro desnecessário e usa cache
---@param hitLeft boolean True para atacar a metade esquerda, False para a direita.
function AlternatingConeStrike:executeAttack(hitLeft)
    if not self.area.range or self.area.range <= 0 then
        error("AlternatingConeStrike:executeAttack: Área de ataque inválida")
    end

    local enemiesHit = CombatHelpers.findEnemiesInConeHalfArea(
        self.area,
        hitLeft,
        self.playerManager:getPlayerSprite()
    )

    if #enemiesHit > 0 then
        -- Usa tabela pre-alocada de knockback
        CombatHelpers.applyHitEffects(
            enemiesHit,
            self.cachedStats,
            self.knockbackData,
            self.enemiesKnockedBackInThisCast,
            self.playerManager,
            self.weaponInstance
        )
    end

    TablePool.release(enemiesHit)
    return true
end

-- Otimizado: evita recriação desnecessária de tabelas
---@param hitLeft boolean True para atacar a metade esquerda, False para a direita.
---@param delay number Delay para iniciar a animação.
function AlternatingConeStrike:createAttackAnimationInstance(hitLeft, delay)
    local attackAnimationInstance = {
        progress = 0,
        hitLeft = hitLeft,
        delay = delay or 0,
        -- Snapshot otimizado - só copia valores necessários
        area = {
            position = { x = self.area.position.x, y = self.area.position.y },
            angle = self.area.angle,
            range = self.area.range,
            angleWidth = self.area.angleWidth,
            halfWidth = self.area.halfWidth
        }
    }
    table.insert(self.activeAttacks, attackAnimationInstance)
end

--- Desenha os elementos visuais da habilidade.
function AlternatingConeStrike:draw()
    if not self.area then return end

    -- Preview
    if self.visual.preview.active then
        self:drawConeOutline(self.visual.preview.color)
    end

    -- Animações de ataque
    for i = 1, #self.activeAttacks do
        local attackInstance = self.activeAttacks[i]
        if attackInstance and attackInstance.delay <= 0 then
            self:drawConeFill(
                self.visual.attack.color,
                attackInstance.progress,
                attackInstance.area,
                attackInstance.hitLeft
            )
        end
    end
end

-- Otimizado: usa constantes e evita recálculos
---@param color table Cor RGBA a ser usada.
function AlternatingConeStrike:drawConeOutline(color)
    if not self.area.range or self.area.range <= 0 then return end

    local segments = 32
    love.graphics.setColor(color)

    local cx, cy = self.area.position.x, self.area.position.y
    local range = self.area.range
    local startAngle = self.area.angle - self.area.halfWidth
    local endAngle = self.area.angle + self.area.halfWidth

    local vertices = {}
    table.insert(vertices, cx)
    table.insert(vertices, cy)

    local angleStep = (endAngle - startAngle) / segments
    for i = 0, segments do
        local angle = startAngle + angleStep * i
        table.insert(vertices, cx + range * math.cos(angle))
        table.insert(vertices, cy + range * math.sin(angle))
    end

    table.insert(vertices, cx)
    table.insert(vertices, cy)

    if #vertices >= 4 then
        love.graphics.line(unpack(vertices))
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Otimizado: cache de cálculos e constantes
---@param color table Cor RGBA a ser usada.
---@param progress number Progresso da animação (0 a 1).
---@param areaInstance table A instância da área para este desenho específico (com position, angle, range, halfWidth, angleWidth).
---@param drawLeft boolean True para desenhar a metade esquerda, False para a direita.
function AlternatingConeStrike:drawConeFill(color, progress, areaInstance, drawLeft)
    if not areaInstance or not areaInstance.range or areaInstance.range <= 0 or
        not areaInstance.halfWidth or areaInstance.halfWidth <= 0 then
        return
    end

    local segments = self.visual.attack.segments
    local playerRadius = self.playerManager.movementController.player.radius or 10
    local fullRange = areaInstance.range

    if progress < 0.01 then return end

    -- Cálculos de shell otimizados
    local shellWidth = math.max(MIN_SHELL_WIDTH, fullRange * SHELL_WIDTH_RATIO)
    local shellRadius = playerRadius + (fullRange - playerRadius) * progress
    local shellInner = math.max(playerRadius, shellRadius - shellWidth * 0.5)
    local shellOuter = math.min(fullRange, shellRadius + shellWidth * 0.5)

    if shellOuter <= shellInner then return end

    local cx, cy = areaInstance.position.x, areaInstance.position.y
    local baseAngle = areaInstance.angle
    local halfWidth = areaInstance.halfWidth

    local coneCurrentStartAngle, coneCurrentEndAngle
    if drawLeft then
        coneCurrentStartAngle = baseAngle - halfWidth
        coneCurrentEndAngle = baseAngle
    else
        coneCurrentStartAngle = baseAngle
        coneCurrentEndAngle = baseAngle + halfWidth
    end

    -- Desenho otimizado
    local vertices = {}
    local angleStep = (coneCurrentEndAngle - coneCurrentStartAngle) / segments

    for i = 0, segments do
        local angle = coneCurrentStartAngle + angleStep * i
        table.insert(vertices, cx + shellOuter * math.cos(angle))
        table.insert(vertices, cy + shellOuter * math.sin(angle))
    end

    if #vertices >= 6 then
        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1.0) * 0.6)
        love.graphics.polygon("fill", unpack(vertices))

        -- Borda
        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1.0) * 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.line(unpack(vertices))
        love.graphics.setLineWidth(1)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function AlternatingConeStrike:getCooldownRemaining()
    return self.cooldownRemaining or 0
end

function AlternatingConeStrike:togglePreview()
    self.visual.preview.active = not self.visual.preview.active
end

function AlternatingConeStrike:getPreview()
    return self.visual.preview.active
end

return AlternatingConeStrike
