local Arrow = require("src.projectiles.arrow") -- Precisaremos criar este arquivo

---@class ArrowProjectile
local ArrowProjectile = {}
ArrowProjectile.__index = ArrowProjectile

-- Configurações Visuais (pode ser herdado da arma)
ArrowProjectile.visual = {
    preview = {
        active = false,
        lineLength = 150
        -- color será definido no :new
    },
    attack = {
        arrowSpeed = 400 -- Velocidade padrão das flechas (pixels por segundo)
        -- color será definido no :new
    }
}

--- Cria uma nova instância da habilidade ArrowProjectile.
---@param playerManager PlayerManager
---@param weaponInstance BaseWeapon Instância da arma (Bow) que está usando esta habilidade.
function ArrowProjectile:new(playerManager, weaponInstance)
    local o = setmetatable({}, ArrowProjectile)

    o.playerManager = playerManager
    o.weaponInstance = weaponInstance
    o.cooldownRemaining = 0
    o.activeArrows = {} -- Tabela para guardar as flechas ativas

    -- Busca dados base da arma
    local baseData = o.weaponInstance:getBaseData()
    if not baseData then
        error(string.format("ArrowProjectile:new - Falha ao obter dados base para %s",
            o.weaponInstance.itemBaseId or "arma desconhecida"))
        return nil
    end
    o.baseDamage = baseData.damage
    o.baseCooldown = baseData.cooldown
    o.baseRange = baseData.range
    o.baseAngleWidth = baseData.angle
    o.baseProjectiles = baseData.projectiles

    -- Define cores (usando as da arma ou padrão)
    o.visual.preview.color = o.weaponInstance.previewColor or { 0.7, 0.7, 0.7, 0.2 }
    o.visual.attack.color = o.weaponInstance.attackColor or { 0.2, 0.8, 0.2, 0.7 }

    -- Inicializa valores que serão atualizados no update
    o.currentPosition = { x = 0, y = 0 }
    o.currentAngle = 0
    o.currentRange = o.baseRange
    o.currentAngleWidth = o.baseAngleWidth

    print("[ArrowProjectile:new] Instância criada.")
    return o
end

function ArrowProjectile:update(dt, angle)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza posição e ângulo base
    self.currentPosition = self.playerManager.player.position
    self.currentAngle = angle

    -- Obtem bônus do jogador
    local state = self.playerManager.state
    local rangeBonus = state:getTotalRange()
    local areaBonus = state:getTotalArea()

    -- Calcula valores FINAIS para este frame
    self.currentRange = self.baseRange * (1 + rangeBonus)
    self.currentAngleWidth = self.baseAngleWidth * (1 + areaBonus)

    -- Atualiza as flechas ativas
    for i = #self.activeArrows, 1, -1 do
        local arrow = self.activeArrows[i]
        arrow:update(dt)
        -- Remove flechas que atingiram o alcance máximo ou colidiram
        if not arrow.isActive then
            table.remove(self.activeArrows, i)
        end
    end
end

function ArrowProjectile:cast(args)
    args = args or {}

    if self.cooldownRemaining > 0 then
        return false
    end

    local state = self.playerManager.state

    -- Aplica o cooldown baseado na velocidade de ataque do player
    local attackSpeed = state:getTotalAttackSpeed()
    self.cooldownRemaining = self.baseCooldown / attackSpeed

    -- Calcula o número total de flechas
    -- Usa o baseProjectiles armazenado da arma
    local multiAttackChance = state:getTotalMultiAttackChance()
    local extraArrows = math.floor(multiAttackChance)
    local decimalChance = multiAttackChance - extraArrows
    local totalArrows = self.baseProjectiles + extraArrows
    if decimalChance > 0 and math.random() < decimalChance then
        totalArrows = totalArrows + 1
    end

    -- Calcula o dano por flecha e stats de crítico
    local totalDamagePerArrow = state:getTotalDamage(self.baseDamage)
    local criticalChance = state:getTotalCritChance()
    local criticalMultiplier = state:getTotalCritDamage()

    -- Calcula os ângulos das flechas usando currentAngle e currentAngleWidth
    local startAngle = self.currentAngle - self.currentAngleWidth / 2
    local endAngle = self.currentAngle + self.currentAngleWidth / 2
    local angleStep = 0
    if totalArrows > 1 then
        angleStep = self.currentAngleWidth / (totalArrows - 1)
    end

    -- Cria e dispara as flechas
    for i = 0, totalArrows - 1 do
        local currentArrowAngle
        if totalArrows == 1 then
            currentArrowAngle = self.currentAngle -- Se for só uma flecha, vai reto
        else
            currentArrowAngle = startAngle + i * angleStep
        end

        -- Calcula se é crítico (feito por flecha)
        local isCritical = math.random() * 100 <= criticalChance
        local damage = totalDamagePerArrow
        if isCritical then
            damage = math.floor(damage * criticalMultiplier)
        end

        local arrow = Arrow:new(
            self.currentPosition.x,          -- Usa posição atual
            self.currentPosition.y,
            currentArrowAngle,               -- Usa ângulo calculado
            self.visual.attack.arrowSpeed,   -- Usa velocidade definida
            self.currentRange,               -- Usa range atual como max distance
            damage,                          -- Dano calculado
            isCritical,                      -- Flag de crítico
            self.playerManager.enemyManager, -- Passa a referência do EnemyManager
            self.visual.attack.color         -- Cor definida
        )
        table.insert(self.activeArrows, arrow)
    end

    return true
end

function ArrowProjectile:draw()
    -- Desenha a prévia da linha/cone se ativa
    if self.visual.preview.active then
        -- Poderia desenhar o cone completo como em FlameStream, ou só a linha
        self:drawPreviewLine(self.visual.preview.color)
        self:drawPreviewCone(self.visual.preview.color)
    end

    -- Desenha as flechas ativas
    for _, arrow in ipairs(self.activeArrows) do
        arrow:draw()
    end
end

function ArrowProjectile:drawPreviewLine(color)
    love.graphics.setColor(color)
    love.graphics.line(
        self.currentPosition.x,
        self.currentPosition.y,
        self.currentPosition.x + math.cos(self.currentAngle) * self.visual.preview.lineLength,
        self.currentPosition.y + math.sin(self.currentAngle) * self.visual.preview.lineLength
    )
end

-- Adiciona função para desenhar o cone de preview
function ArrowProjectile:drawPreviewCone(color)
    local segments = 16
    love.graphics.setColor(color)
    local cx, cy = self.currentPosition.x, self.currentPosition.y
    local range = self.visual.preview.lineLength -- Usa o lineLength para o tamanho do preview
    local startAngle = self.currentAngle - self.currentAngleWidth / 2
    local endAngle = self.currentAngle + self.currentAngleWidth / 2

    -- love.graphics.arc("line", "open", cx, cy, range, startAngle, endAngle, segments) -- Descomentar se quiser o arco
    love.graphics.line(cx, cy, cx + range * math.cos(startAngle), cy + range * math.sin(startAngle))
    love.graphics.line(cx, cy, cx + range * math.cos(endAngle), cy + range * math.sin(endAngle))
end

function ArrowProjectile:getCooldownRemaining()
    return self.cooldownRemaining or 0 -- Garante que retorne 0 se for nil
end

function ArrowProjectile:togglePreview()
    self.visual.preview.active = not self.visual.preview.active
end

function ArrowProjectile:getPreview()
    return self.visual.preview.active
end

return ArrowProjectile
