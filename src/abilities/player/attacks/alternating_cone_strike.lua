--[[----------------------------------------------------------------------------
    Alternating Cone Strike Ability
    Um ataque em cone rápido que atinge alternadamente a metade esquerda ou direita.
----------------------------------------------------------------------------]]--

local AlternatingConeStrike = {}

-- Configurações visuais e de jogabilidade
AlternatingConeStrike.name = "Golpe Cônico Alternado"
AlternatingConeStrike.description = "Golpeia rapidamente em metades alternadas de um cone."
AlternatingConeStrike.damageType = "melee"
AlternatingConeStrike.visual = {
    preview = {
        active = false,
        lineLength = 50 -- Comprimento da linha de preview
    },
    attack = {
        animationDuration = 0.1 -- Duração MUITO curta da animação de cada golpe
    }
}

-- Função auxiliar para normalizar ângulos para [-pi, pi]
local function normalizeAngle(angle)
    return (angle + math.pi) % (2 * math.pi) - math.pi
end

function AlternatingConeStrike:init(playerManager)
    self.playerManager = playerManager
    self.cooldownRemaining = 0
    self.isAttacking = false
    self.attackProgress = 0
    self.hitLeftNext = true -- Começa atacando pela esquerda
    self.lastAttackWasLeft = false -- Para saber qual metade desenhar

    -- Usa as cores da arma se disponíveis
    self.visual.preview.color = self.previewColor or {0.7, 0.7, 0.7, 0.2}
    self.visual.attack.color = self.attackColor or {0.8, 0.1, 0.8, 0.6}

    -- Usa os atributos da arma
    local weapon = self.playerManager.equippedWeapon
    self.area = {
        position = {x = 0, y = 0}, -- Será atualizado
        angle = 0,                -- Ângulo central, será atualizado
        range = weapon.range + self.playerManager.state:getTotalRange(),
        angleWidth = weapon.angle + self.playerManager.state:getTotalArea(), -- Largura total do cone
        halfWidth = (weapon.angle + self.playerManager.state:getTotalArea()) / 2 -- Metade da largura
    }
    self.baseDamage = weapon.damage
    self.baseCooldown = weapon.cooldown

    -- Atualiza posição inicial
    self.area.position.x = self.playerManager.player.position.x
    self.area.position.y = self.playerManager.player.position.y
end

function AlternatingConeStrike:update(dt, angle)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza posição e ângulo do cone para seguir o jogador e o mouse
    if self.area then
        self.area.position = self.playerManager.player.position
        self.area.angle = angle -- Ângulo central da mira
        -- Recalcula larguras caso os bônus de área mudem
        self.area.angleWidth = self.playerManager.equippedWeapon.angle + self.playerManager.state:getTotalArea()
        self.area.halfWidth = self.area.angleWidth / 2
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

function AlternatingConeStrike:cast(args)
    args = args or {}

    if self.cooldownRemaining > 0 then
        return false
    end
    
    -- Determina qual lado atacar NESTE cast
    local attackLeftThisCast = self.hitLeftNext
    
    -- Inicia a animação (sempre mostra a animação do PRIMEIRO golpe do cast)
    self.isAttacking = true
    self.attackProgress = 0
    self.lastAttackWasLeft = attackLeftThisCast -- Para o draw
    
    -- Aplica o cooldown
    local attackSpeed = self.playerManager.state:getTotalAttackSpeed()
    self.cooldownRemaining = self.baseCooldown / attackSpeed
    
    -- Calcula ataques extras
    local multiAttackChance = self.playerManager.state:getTotalMultiAttackChance()
    local extraAttacks = math.floor(multiAttackChance)
    local decimalChance = multiAttackChance - extraAttacks
    
    -- Executa o PRIMEIRO ataque
    local success = self:executeAttack(attackLeftThisCast)
    local currentHitIsLeft = attackLeftThisCast -- Variável para alternar nos extras
    
    -- Executa ataques extras, alternando a CADA extra
    for i = 1, extraAttacks do
        if success then
            currentHitIsLeft = not currentHitIsLeft -- Alterna para o próximo extra
            success = self:executeAttack(currentHitIsLeft)
        else
            break -- Se um ataque falhar (hipoteticamente), para
        end
    end
    
    -- Chance de ataque extra decimal, também alterna
    if success and decimalChance > 0 and math.random() < decimalChance then
        currentHitIsLeft = not currentHitIsLeft -- Alterna para este extra
        self:executeAttack(currentHitIsLeft)
    end

    -- IMPORTANTE: Alterna o estado APENAS UMA VEZ no final, preparando o PRÓXIMO cast
    self.hitLeftNext = not self.hitLeftNext
    
    return success -- Retorna sucesso do primeiro golpe
end

-- Função auxiliar para executar um único ataque em uma metade específica
function AlternatingConeStrike:executeAttack(hitLeft)
    local enemies = self.playerManager.enemyManager:getEnemies()
    local enemiesHit = 0
    
    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            -- Verifica se o inimigo está na metade correta do cone
            if self:isPointInCorrectHalf(enemy.position, hitLeft) then
                enemiesHit = enemiesHit + 1
                self:applyDamage(enemy) -- Aplica o dano (a checagem de área já foi feita)
            end
        end
    end
    
    return true -- Retorna true mesmo se não atingiu ninguém
end

-- Verifica se um ponto está DENTRO do cone TOTAL
function AlternatingConeStrike:isPointInArea(position)
    if not self.area then return false end

    local dx = position.x - self.area.position.x
    local dy = position.y - self.area.position.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Verifica distância
    if distance == 0 or distance > self.area.range then return false end

    -- Verifica ângulo
    local pointAngle = math.atan2(dy, dx)
    local relativeAngle = normalizeAngle(pointAngle - self.area.angle)
    
    return math.abs(relativeAngle) <= self.area.halfWidth
end

-- Verifica se um ponto está na METADE ESPECÍFICA do cone
function AlternatingConeStrike:isPointInCorrectHalf(position, checkLeft)
    if not self.area then return false end

    local dx = position.x - self.area.position.x
    local dy = position.y - self.area.position.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Verifica distância primeiro (mais rápido)
    if distance == 0 or distance > self.area.range then return false end

    -- Verifica ângulo
    local pointAngle = math.atan2(dy, dx)
    local relativeAngle = normalizeAngle(pointAngle - self.area.angle)
    
    if checkLeft then -- Checa metade esquerda
        return relativeAngle >= -self.area.halfWidth and relativeAngle <= 0
    else -- Checa metade direita
        return relativeAngle > 0 and relativeAngle <= self.area.halfWidth
    end
end

function AlternatingConeStrike:applyDamage(target)    
    -- Calcula o dano total com os bônus do player
    local totalDamage = self.playerManager.state:getTotalDamage(self.baseDamage)
    
    -- Calcula se o dano é crítico
    local isCritical = math.random() <= self.playerManager.state:getTotalCriticalChance() / 100
    if isCritical then
        totalDamage = math.floor(totalDamage * self.playerManager.state:getTotalCriticalMultiplier())
    end
    
    -- Aplica o dano
    return target:takeDamage(totalDamage, isCritical)
end

function AlternatingConeStrike:draw()
    if not self.area then 
        -- error("[Erro] [AlternatingConeStrike.draw] Área não definida!")
        return
    end
    
    -- Desenha a prévia da linha se ativa (mostra o cone inteiro)
    if self.visual.preview.active then
        self:drawPreviewLine()
        self:drawConeOutline(self.visual.preview.color) -- Desenha contorno do cone inteiro
    end
    
    -- Desenha a animação do ataque (apenas a metade ativa)
    if self.isAttacking then
        self:drawHalfConeFill(self.visual.attack.color, self.attackProgress, self.lastAttackWasLeft)
    end
end

function AlternatingConeStrike:drawPreviewLine()
    love.graphics.setColor(1, 1, 1, 0.5) -- Branco semi-transparente
    love.graphics.line(
        self.area.position.x, self.area.position.y,
        self.area.position.x + math.cos(self.area.angle) * self.visual.preview.lineLength,
        self.area.position.y + math.sin(self.area.angle) * self.visual.preview.lineLength
    )
end

-- Desenha o CONTORNO do cone inteiro (para preview)
function AlternatingConeStrike:drawConeOutline(color)
    local segments = 32
    love.graphics.setColor(color)
    local cx, cy = self.area.position.x, self.area.position.y
    local range = self.area.range
    local startAngle = self.area.angle - self.area.halfWidth
    local endAngle = self.area.angle + self.area.halfWidth

    love.graphics.arc("line", "open", cx, cy, range, startAngle, endAngle, segments)
    love.graphics.line(cx, cy, cx + range * math.cos(startAngle), cy + range * math.sin(startAngle))
    love.graphics.line(cx, cy, cx + range * math.cos(endAngle), cy + range * math.sin(endAngle))
end

-- Desenha o PREENCHIMENTO de METADE do cone (para ataque)
function AlternatingConeStrike:drawHalfConeFill(color, progress, drawLeft)
    local segments = 16 -- Metade dos segmentos normais
    local innerRange = self.playerManager.radius * 1.5 -- Remove ponta perto do player

    love.graphics.setColor(color)
    local cx, cy = self.area.position.x, self.area.position.y
    local outerRange = self.area.range
    local coneHalfWidth = self.area.halfWidth
    local centerAngle = self.area.angle

    local startAngle, endAngle
    if drawLeft then
        startAngle = centerAngle - coneHalfWidth
        endAngle = centerAngle
    else
        startAngle = centerAngle
        endAngle = centerAngle + coneHalfWidth
    end

    if progress > 0 then
        -- A animação cobre a metade do início ao fim baseado no progresso
        local fillEndAngle = startAngle + (coneHalfWidth * progress)
        if not drawLeft then -- Se for direita, o progresso vai de center até end
             fillEndAngle = startAngle + (coneHalfWidth * progress)
        else -- Se for esquerda, inverte o progresso visualmente (opcional, pode só preencher normal)
             fillEndAngle = endAngle - (coneHalfWidth * (1-progress)) -- Ou preencher da borda para o centro
             -- Ou mais simples: fillEndAngle = startAngle + (coneHalfWidth * progress)
        end
        -- Simplificação: Sempre preenche de startAngle até o progresso relativo.
        fillEndAngle = startAngle + (coneHalfWidth * progress)

        local vertices = {}
        local currentSegments = math.max(1, math.ceil(segments * progress))
        local angle_step = (fillEndAngle - startAngle) / currentSegments

        -- Arco externo
        for i = 0, currentSegments do
            local angle = startAngle + i * angle_step
            table.insert(vertices, cx + outerRange * math.cos(angle))
            table.insert(vertices, cy + outerRange * math.sin(angle))
        end
        -- Arco interno (invertido)
        for i = currentSegments, 0, -1 do
            local angle = startAngle + i * angle_step
            table.insert(vertices, cx + innerRange * math.cos(angle))
            table.insert(vertices, cy + innerRange * math.sin(angle))
        end

        -- Desenha polígono preenchido
        love.graphics.setColor(color[1], color[2], color[3], color[4] * 0.8)
        if #vertices >= 6 then
             love.graphics.polygon("fill", vertices)
        end

        -- Linha intensa no final do preenchimento
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        love.graphics.line(
            cx + innerRange * math.cos(fillEndAngle),
            cy + innerRange * math.sin(fillEndAngle),
            cx + outerRange * math.cos(fillEndAngle),
            cy + outerRange * math.sin(fillEndAngle)
        )
    end
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

-- return setmetatable(AlternatingConeStrike, {__index = require("src.abilities.player.attacks.cone_slash")}) -- Herda de ConeSlash? Não, melhor não herdar diretamente.
return AlternatingConeStrike 