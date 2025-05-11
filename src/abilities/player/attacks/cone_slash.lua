local EnemyManager = require("src.managers.enemy_manager")

--[[
    Cone Slash Ability
    A cone-shaped area of effect attack that serves as the character's primary attack method
]]

local Camera = require("src.config.camera")

local ConeSlash = {}
ConeSlash.__index = ConeSlash -- Para permitir :new

-- Configurações visuais PADRÃO
ConeSlash.name = "Cone Slash"
ConeSlash.description = "Um ataque em cone que causa dano a todos os inimigos na área"
ConeSlash.damageType = "melee"
ConeSlash.visual = {
    preview = {
        active = false,
        lineLength = 50,
        color = { 0.7, 0.7, 0.7, 0.2 } -- Cor padrão preview
    },
    attack = {
        segments = 20,
        animationDuration = 0.2,         -- Duração da animação em segundos
        color = { 1, 0.302, 0.302, 0.6 } -- Cor padrão ataque
    }
}

-- Função auxiliar para normalizar ângulos
local function normalizeAngle(angle)
    return (angle + math.pi) % (2 * math.pi) - math.pi
end

--- Cria uma nova instância da habilidade ConeSlash.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param weaponInstance BaseWeapon Instância da arma que está usando esta habilidade.
function ConeSlash:new(playerManager, weaponInstance)
    local o = setmetatable({}, self)
    print("[ConeSlash:new] Creating instance...")

    if not playerManager or not weaponInstance then
        error("ConeSlash:new - playerManager e weaponInstance são obrigatórios.")
        return nil
    end

    o.playerManager = playerManager
    o.weaponInstance = weaponInstance

    o.cooldownRemaining = 0
    o.isAttacking = false
    o.attackProgress = 0

    -- Busca cores da weaponInstance
    o.visual.preview.color = weaponInstance.previewColor or o.visual.preview.color
    o.visual.attack.color = weaponInstance.attackColor or o.visual.attack.color
    print("  - Preview/Attack colors set.")

    -- Área de efeito será calculada dinamicamente no update
    o.area = {
        position = { x = 0, y = 0 },
        angle = 0,
        range = 0,      -- Será atualizado
        angleWidth = 0, -- Será atualizado
        halfWidth = 0   -- Será atualizado (calculado a partir de angleWidth)
    }
    if o.playerManager.player then
        o.area.position.x = o.playerManager.player.position.x
        o.area.position.y = o.playerManager.player.position.y
    else
        print("  - WARN: Player sprite not yet available for initial position.")
    end

    print("[ConeSlash:new] Instance created successfully.")
    return o
end

--- Atualiza o estado da habilidade.
---@param dt number Delta time.
---@param angle number Ângulo atual da mira do jogador.
function ConeSlash:update(dt, angle)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza posição e ângulo do cone
    if self.area and self.playerManager.player then
        self.area.position = self.playerManager.player.position
        self.area.angle = angle -- Ângulo central da mira

        -- Obtém os stats finais do jogador UMA VEZ
        local finalStats = self.playerManager:getCurrentFinalStats()

        local baseData = self.weaponInstance:getBaseData()
        local weaponBaseRange = baseData and baseData.range
        local weaponBaseAngle = baseData and baseData.angle

        -- Usa os multiplicadores de range e area dos stats finais
        -- Se weaponBaseRange/Angle ou finalStats.range/attackArea forem nil, o resultado será nil.
        local newRange = weaponBaseRange and finalStats.range and (weaponBaseRange * finalStats.range)
        local newAngleWidth = weaponBaseAngle and finalStats.attackArea and (weaponBaseAngle * finalStats.attackArea)

        if newRange ~= self.area.range or newAngleWidth ~= self.area.angleWidth then
            self.area.range = newRange
            self.area.angleWidth = newAngleWidth
            self.area.halfWidth = newAngleWidth and (newAngleWidth / 2)
            print(string.format(
                "  [ConeSlash UPDATE] Area Recalculated. Range: %s | AngleWidth: %s (BaseRange: %s, BaseAngle: %s, PlayerRangeMult: %s, PlayerAreaMult: %s)",
                tostring(self.area.range), tostring(self.area.angleWidth), tostring(weaponBaseRange),
                tostring(weaponBaseAngle), tostring(finalStats.range), tostring(finalStats.attackArea)))
        end
    end

    -- Atualiza animação do ataque
    if self.isAttacking then
        self.attackProgress = self.attackProgress + (dt / self.visual.attack.animationDuration)
        if self.attackProgress >= 1 then
            self.isAttacking = false
            self.attackProgress = 0
        end
    end
end

--- Tenta executar o ataque.
---@param args table Argumentos opcionais (não usado).
---@return boolean True se o ataque foi iniciado, False se estava em cooldown.
function ConeSlash:cast(args)
    args = args or {}

    if self.cooldownRemaining > 0 then
        return false -- Em cooldown
    end
    print("[ConeSlash:cast] Casting attack.")

    local finalStats = self.playerManager:getCurrentFinalStats()

    -- Inicia a animação do ataque
    self.isAttacking = true
    self.attackProgress = 0

    -- Aplica o cooldown
    local baseData = self.weaponInstance:getBaseData()
    local baseCooldown = baseData and baseData.cooldown -- Sem fallback
    local totalAttackSpeed = finalStats.attackSpeed     -- Sem fallback inicial
    -- Exceção: Evitar divisão por zero ou cooldown inválido
    if not totalAttackSpeed or totalAttackSpeed <= 0 then totalAttackSpeed = 0.01 end

    if baseCooldown and totalAttackSpeed then
        self.cooldownRemaining = baseCooldown / totalAttackSpeed
        print(string.format("  - Cooldown set to %.2fs (Base: %s / FinalASMult: %.2f)", self.cooldownRemaining,
            tostring(baseCooldown), totalAttackSpeed))
    else
        error(
            "[ConeSlash:cast] ERRO: baseCooldown ou totalAttackSpeed é nil/inválido. Não é possível calcular cooldown.")
        self.cooldownRemaining = 1 -- Cooldown de fallback em caso de erro de dados
    end

    -- Calcula ataques extras (multiAttackChance)
    local multiAttackChance = finalStats.multiAttackChance -- Sem fallback
    local extraAttacks = 0
    local decimalChance = 0

    if multiAttackChance then
        extraAttacks = math.floor(multiAttackChance)
        decimalChance = multiAttackChance - extraAttacks
        print(string.format("  - Multi-Attack Chance: %s (Extra: %d + %.2f%%)", tostring(multiAttackChance), extraAttacks,
            decimalChance * 100))
    else
        error("[ConeSlash:cast] AVISO: multiAttackChance é nil. Nenhum ataque extra será calculado.")
    end

    -- Primeiro ataque sempre ocorre
    local success = self:executeAttack(finalStats)

    -- Executa ataques extras inteiros
    for i = 1, extraAttacks do
        if success then
            print(string.format("    - Executing extra attack #%d", i))
            success = self:executeAttack(finalStats)
        else
            print("    - Stopping extra attacks due to previous failure.")
            break
        end
    end

    -- Chance de ataque extra decimal
    if success and decimalChance > 0 and math.random() < decimalChance then
        print("    - Executing decimal chance extra attack")
        self:executeAttack(finalStats)
    end

    return true -- Retorna true porque o cast foi iniciado
end

--- Executa a lógica de um único golpe do ConeSlash.
---@param finalStats table Os stats finais do jogador.
---@return boolean Sempre retorna true (indica que a tentativa de ataque foi feita).
function ConeSlash:executeAttack(finalStats)
    local enemies = self.playerManager.enemyManager:getEnemies()
    local enemiesHitCount = 0
    -- Não precisa chamar updateAreaIfNeeded() pois a área é atualizada em :update

    -- Verifica se a área de ataque é válida antes de prosseguir
    if not self.area or not self.area.range or self.area.range <= 0 or not self.area.halfWidth or self.area.halfWidth <= 0 then
        error(string.format(
            "[ConeSlash:executeAttack] AVISO: Área de ataque inválida. Range: %s, HalfWidth: %s. Nenhum inimigo será atingido.",
            tostring(self.area.range), tostring(self.area.halfWidth)))
    end

    for i, enemy in ipairs(enemies) do
        if enemy.isAlive then
            -- Verifica se o inimigo está dentro da área de ataque
            if self:isPointInArea(enemy.position) then
                local isCritical = finalStats.critChance and (math.random() <= finalStats.critChance)
                enemiesHitCount = enemiesHitCount + 1
                self:applyDamage(enemy, finalStats)
            end
        end
    end
    if enemiesHitCount > 0 then
        print(string.format("    [executeAttack] Hit %d enemies.", enemiesHitCount))
    end

    return true -- Retorna true mesmo se não atingiu ninguém
end

--- Verifica se um ponto está DENTRO do cone TOTAL.
---@param position table Posição {x, y} a verificar.
---@return boolean True se o ponto está na área total.
function ConeSlash:isPointInArea(position)
    if not self.area or not self.area.range or not self.area.halfWidth then return false end

    local dx = position.x - self.area.position.x
    local dy = position.y - self.area.position.y
    local distanceSq = dx * dx + dy * dy

    if distanceSq == 0 or distanceSq > (self.area.range * self.area.range) then return false end

    local pointAngle = math.atan2(dy, dx)
    local relativeAngle = normalizeAngle(pointAngle - self.area.angle)

    -- Usa halfWidth que foi calculado em update()
    return math.abs(relativeAngle) <= self.area.halfWidth
end

--- Aplica dano a um alvo.
---@param target BaseEnemy Instância do inimigo a ser atingido.
---@param finalStats table Os stats finais do jogador.
---@param isCritical boolean True se o ataque é crítico, False caso contrário.
---@return boolean Resultado de target:takeDamage ou false se fora da área.
function ConeSlash:applyDamage(target, finalStats, isCritical)
    -- A verificação de área já foi feita em executeAttack

    -- Usa o dano da arma já calculado nos stats finais
    local totalDamage = finalStats.weaponDamage

    if isCritical then
        totalDamage = totalDamage and finalStats.critDamage and
            math.floor(totalDamage * finalStats.critDamage)
    end

    if totalDamage == nil then
        error(string.format("    [ConeSlash:applyDamage] ERRO: totalDamage é nil. Arma: %s, Crit: %s",
            tostring(self.weaponInstance and self.weaponInstance.itemBaseId), tostring(isCritical)))
    end

    -- Aplica o dano
    return target:takeDamage(totalDamage, isCritical)
end

--- Desenha os elementos visuais da habilidade.
function ConeSlash:draw()
    if not self.area then return end

    -- Desenha a prévia (contorno) se ativa
    if self.visual.preview.active then
        self:drawConeOutline(self.visual.preview.color)
    end

    -- Desenha a animação do ataque (preenchido) se ativa
    if self.isAttacking then
        self:drawConeFill(self.visual.attack.color, self.attackProgress)
    end
end

--- Desenha o CONTORNO do cone (para preview).
---@param color table Cor RGBA.
function ConeSlash:drawConeOutline(color)
    if not self.area or not self.area.range or self.area.range <= 0 or not self.area.halfWidth or self.area.halfWidth <= 0 then
        error("[ConeSlash:drawConeOutline] AVISO: Área inválida para desenho.")
    end
    local segments = 32
    love.graphics.setColor(color)
    local cx, cy = self.area.position.x, self.area.position.y
    local range = self.area.range
    local startAngle = self.area.angle - self.area.halfWidth
    local endAngle = self.area.angle + self.area.halfWidth

    local vertices = {}
    table.insert(vertices, cx)
    table.insert(vertices, cy)
    for i = 0, segments do
        local angle = startAngle + (endAngle - startAngle) * (i / segments)
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

--- Desenha o PREENCHIMENTO do cone (para ataque).
---@param color table Cor RGBA.
---@param progress number Progresso da animação (0 a 1).
function ConeSlash:drawConeFill(color, progress)
    if not self.area or not self.area.range or self.area.range <= 0 or not self.area.angleWidth or self.area.angleWidth <= 0 then
        error("[ConeSlash:drawConeFill] AVISO: Área base inválida para animação.")
    end

    local segments = self.visual.attack.segments or 20
    local innerRange = (self.playerManager.player and self.playerManager.player.radius or 10) * 1.5

    local alpha = color[4] or 1.0
    -- Animação: O cone "cresce" com o progresso
    local currentRange = self.area.range * progress
    local currentAngleWidth = self.area.angleWidth * progress -- O ângulo também pode crescer

    if not currentRange or currentRange <= 0 or not currentAngleWidth or currentAngleWidth <= 0 then
        error("[ConeSlash:drawConeFill] AVISO: Área animada inválida (currentRange ou currentAngleWidth <= 0).")
    end

    local currentHalfWidth = currentAngleWidth / 2

    love.graphics.setColor(color[1], color[2], color[3], alpha * (1 - progress ^ 2)) -- Fade out mais rápido

    local cx, cy = self.area.position.x, self.area.position.y

    local startAngle = self.area.angle - currentHalfWidth
    local endAngle = self.area.angle + currentHalfWidth

    -- Desenha como anel de setor usando o range/ângulo atuais da animação
    local vertices = {}
    -- Arco externo
    for i = 0, segments do
        local angle = startAngle + (endAngle - startAngle) * (i / segments)
        table.insert(vertices, cx + currentRange * math.cos(angle))
        table.insert(vertices, cy + currentRange * math.sin(angle))
    end
    -- Arco interno
    for i = segments, 0, -1 do
        local angle = startAngle + (endAngle - startAngle) * (i / segments)
        -- Garante que innerRange não seja maior que currentRange
        local actualInnerRange = math.min(innerRange, currentRange * 0.9)
        table.insert(vertices, cx + actualInnerRange * math.cos(angle))
        table.insert(vertices, cy + actualInnerRange * math.sin(angle))
    end

    if #vertices >= 6 then
        love.graphics.polygon("fill", unpack(vertices))
    end
    love.graphics.setColor(1, 1, 1, 1)
end

--- Retorna o cooldown restante.
---@return number
function ConeSlash:getCooldownRemaining()
    return self.cooldownRemaining or 0
end

--- Alterna a visualização da prévia.
function ConeSlash:togglePreview()
    self.visual.preview.active = not self.visual.preview.active
end

--- Retorna se a prévia está ativa.
---@return boolean
function ConeSlash:getPreview()
    return self.visual.preview.active
end

return ConeSlash
