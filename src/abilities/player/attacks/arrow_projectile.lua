-------------------------------------------------------
-- Arrow Projectile Ability
-- A habilidade ArrowProjectile é uma habilidade de projétil de flecha que atira flechas em um ângulo e alcance específicos.
-------------------------------------------------------

local Arrow = require("src.projectiles.arrow") -- Precisaremos criar este arquivo

---@class ArrowProjectile
---@field visual table
---@field currentPosition table
---@field currentAngle number
---@field currentRange number
---@field currentAngleWidth number
---@field currentPreviewLength number
---@field cooldownRemaining number
---@field activeArrows table
---@field baseDamage number
---@field baseCooldown number
---@field baseRange number
---@field baseAngleWidth number
---@field baseProjectiles number
---@field playerManager PlayerManager
---@field weaponInstance BaseWeapon
local ArrowProjectile = {}
ArrowProjectile.__index = ArrowProjectile

-- Configurações Visuais (pode ser herdado da arma)
ArrowProjectile.visual = {
    preview = {
        active = false,
        -- lineLength = 150 -- REMOVIDO: Será calculado dinamicamente
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
    o.currentPreviewLength = o.currentRange / 2 -- Inicializa preview length

    print("[ArrowProjectile:new] Instância criada.")
    return o
end

function ArrowProjectile:update(dt, angle)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza posição e ângulo base
    if self.playerManager and self.playerManager.player and self.playerManager.player.position then
        self.currentPosition = self.playerManager.player.position
    else
        error("[ArrowProjectile:update] ERRO: Posição do jogador não disponível.")
    end
    self.currentAngle = angle

    -- Obtem stats finais do jogador
    local finalStats = self.playerManager:getCurrentFinalStats()

    -- Calcula valores FINAIS para este frame
    -- Assumindo que finalStats.range e finalStats.attackArea são multiplicadores totais (ex: 1.1 para +10%)
    self.currentRange = self.baseRange and finalStats.range and (self.baseRange * finalStats.range)
    self.currentAngleWidth = self.baseAngleWidth and finalStats.attackArea and
        (self.baseAngleWidth * finalStats.attackArea)

    -- Calcula preview length baseado no range atual
    -- Se self.currentRange for nil, self.currentPreviewLength também será nil.
    self.currentPreviewLength = self.currentRange and (self.currentRange / 2)

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

    local finalStats = self.playerManager:getCurrentFinalStats()

    -- Aplica o cooldown baseado na velocidade de ataque do player
    local totalAttackSpeed = finalStats.attackSpeed
    if not totalAttackSpeed or totalAttackSpeed <= 0 then totalAttackSpeed = 0.01 end -- Exceção para evitar divisão por zero

    if self.baseCooldown and totalAttackSpeed then
        self.cooldownRemaining = self.baseCooldown / totalAttackSpeed
    else
        error(string.format(
            "[ArrowProjectile:cast] ERRO: baseCooldown (%s) ou totalAttackSpeed (%s) é nil/inválido. Cooldown não aplicado corretamente.",
            tostring(self.baseCooldown), tostring(finalStats.attackSpeed)))
    end

    -- Calcula o número total de flechas
    local baseProjectilesActual = self.baseProjectiles or
    1                                                                  -- Garante pelo menos 1 projétil base se não definido na arma
    local currentMultiAttackChance = finalStats.multiAttackChance or 0 -- Trata nil como 0 para evitar erro

    local extraArrowsInteger = math.floor(currentMultiAttackChance)
    local decimalChanceForExtra = currentMultiAttackChance - extraArrowsInteger

    local totalArrows = baseProjectilesActual + extraArrowsInteger
    if decimalChanceForExtra > 0 and math.random() < decimalChanceForExtra then
        totalArrows = totalArrows + 1
    end

    if totalArrows == nil or totalArrows <= 0 then
        error(string.format(
            "[ArrowProjectile:cast] ERRO: totalArrows calculado é inválido (%s). Base: %s, MultiAttack: %s",
            tostring(totalArrows), tostring(self.baseProjectiles), tostring(finalStats.multiAttackChance)))
        return false -- Não dispara flechas se o cálculo falhar
    end

    -- Dano por flecha e stats de crítico dos finalStats
    local damagePerArrow = finalStats.weaponDamage
    local criticalChance = finalStats.critChance
    local criticalMultiplier = finalStats.critDamage

    if damagePerArrow == nil then
        error("[ArrowProjectile:cast] ERRO: finalStats.weaponDamage é nil. Não é possível calcular o dano das flechas.")
    end

    -- Calcula os ângulos das flechas usando currentAngle e currentAngleWidth
    local angleForSpread = self.currentAngleWidth
    local startAngle = self.currentAngle - angleForSpread / 2
    local angleStep = 0
    if totalArrows > 1 and angleForSpread > 0 then -- Evita divisão por zero se angleForSpread é 0
        angleStep = angleForSpread / (totalArrows - 1)
    end

    -- Cria e dispara as flechas
    for i = 0, totalArrows - 1 do
        local currentArrowAngle
        if totalArrows == 1 or angleForSpread == 0 then
            currentArrowAngle = self.currentAngle -- Se for só uma flecha ou sem spread, vai reto
        else
            currentArrowAngle = startAngle + i * angleStep
        end

        -- Calcula se é crítico (feito por flecha)
        local isCritical = criticalChance and (math.random() <= criticalChance)
        local finalDamageThisArrow = damagePerArrow
        if isCritical then
            if criticalMultiplier then
                finalDamageThisArrow = math.floor(finalDamageThisArrow * criticalMultiplier)
            else
                error(
                    "[ArrowProjectile:cast] AVISO: Acerto crítico mas finalStats.critDamage é nil. Usando dano normal.")
            end
        end

        local arrow = Arrow:new(
            self.currentPosition.x,
            self.currentPosition.y,
            currentArrowAngle,
            self.visual.attack.arrowSpeed,
            self.currentRange, -- Pode ser nil, Arrow:new precisa tratar
            finalDamageThisArrow,
            isCritical,
            self.playerManager.enemyManager,
            self.visual.attack.color
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
    if not self.currentPreviewLength or self.currentPreviewLength <= 0 or not self.currentPosition then return end

    love.graphics.setColor(color)
    love.graphics.line(
        self.currentPosition.x,
        self.currentPosition.y,
        self.currentPosition.x + math.cos(self.currentAngle) * self.currentPreviewLength, -- Usa currentPreviewLength
        self.currentPosition.y + math.sin(self.currentAngle) * self.currentPreviewLength  -- Usa currentPreviewLength
    )
end

-- Adiciona função para desenhar o cone de preview
function ArrowProjectile:drawPreviewCone(color)
    if not self.currentPreviewLength or self.currentPreviewLength <= 0 or
        not self.currentAngleWidth or self.currentAngleWidth <= 0 or
        not self.currentPosition then
        return
    end

    love.graphics.setColor(color)
    local cx, cy = self.currentPosition.x, self.currentPosition.y
    local range = self.currentPreviewLength -- Usa currentPreviewLength para o tamanho do preview
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
