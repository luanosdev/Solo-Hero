-- src/abilities/player/attacks/triple_arrow.lua
local Arrow = require("src.projectiles.arrow") -- Precisaremos criar este arquivo

local TripleArrow = {
    name = "Triple Arrow",
    description = "Dispara três flechas em cone. Ataques múltiplos adicionam mais flechas.",
    cooldown = 1.0, -- Será sobrescrito pela arma
    damageType = "ranged",
    visual = {
        preview = {
            active = false,
            lineLength = 50
        },
        attack = { 
            -- Não teremos uma animação de cone como ConeSlash, mas sim projéteis
        }
    }
}

function TripleArrow:init(playerManager)
    self.playerManager = playerManager
    self.cooldownRemaining = 0
    self.activeArrows = {} -- Tabela para guardar as flechas ativas
    self.arrowSpeed = 400 -- Velocidade das flechas (pixels por segundo)

    -- Usa as cores da arma se disponíveis
    self.visual.preview.color = self.previewColor or {0.7, 0.7, 0.7, 0.2}
    self.visual.attack.color = self.attackColor or {0.2, 0.8, 0.2, 0.7}

    -- Usa os atributos da arma
    local weapon = self.playerManager.equippedWeapon
    self.area = {
        position = {
            x = self.playerManager.player.position.x,
            y = self.playerManager.player.position.y
        },
        angle = 0, -- Ângulo central do disparo
        range = weapon.range + self.playerManager.state:getTotalRange(), -- Alcance máximo das flechas
        angleWidth = weapon.angle + self.playerManager.state:getTotalArea() -- Largura do cone de disparo
    }
    self.baseDamage = weapon.damage
    self.baseCooldown = weapon.cooldown
    self.baseArrows = self.baseProjectiles or 3 -- Lê o número de flechas da arma, ou usa 3 como padrão
end

function TripleArrow:update(dt, angle)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza a posição e ângulo base para seguir o jogador
    if self.area then
        self.area.position = self.playerManager.player.position
        self.area.angle = angle
    end

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

function TripleArrow:cast()
    if self.cooldownRemaining > 0 then
        return false
    end

    -- Aplica o cooldown baseado na velocidade de ataque do player
    local attackSpeed = self.playerManager.state:getTotalAttackSpeed()
    self.cooldownRemaining = self.baseCooldown / attackSpeed

    -- Calcula o número total de flechas
    local baseArrows = self.baseArrows -- Usa o valor definido na inicialização
    local multiAttackChance = self.playerManager.state:getTotalMultiAttackChance()
    local extraArrows = math.floor(multiAttackChance)
    local decimalChance = multiAttackChance - extraArrows
    local totalArrows = baseArrows + extraArrows
    if decimalChance > 0 and math.random() < decimalChance then
        totalArrows = totalArrows + 1
    end

    -- Calcula o dano por flecha
    local totalDamagePerArrow = self.playerManager.state:getTotalDamage(self.baseDamage)
    local criticalChance = self.playerManager.state:getTotalCriticalChance()
    local criticalMultiplier = self.playerManager.state:getTotalCriticalMultiplier()

    -- Calcula os ângulos das flechas
    local startAngle = self.area.angle - self.area.angleWidth / 2
    local endAngle = self.area.angle + self.area.angleWidth / 2
    local angleStep = 0
    if totalArrows > 1 then
        angleStep = self.area.angleWidth / (totalArrows - 1)
    end

    -- Cria e dispara as flechas
    for i = 0, totalArrows - 1 do
        local currentAngle
        if totalArrows == 1 then
            currentAngle = self.area.angle -- Se for só uma flecha, vai reto
        else
            currentAngle = startAngle + i * angleStep
        end
        
        -- Calcula se é crítico (feito por flecha)
        local isCritical = math.random() * 100 <= criticalChance
        local damage = totalDamagePerArrow
        if isCritical then
            damage = math.floor(damage * criticalMultiplier)
        end
        
        local arrow = Arrow:new(
            self.area.position.x,
            self.area.position.y,
            currentAngle,
            self.arrowSpeed,
            self.area.range, -- Alcance da flecha
            damage,
            isCritical,
            self.playerManager.enemyManager, -- Passa a referência do EnemyManager
            self.visual.attack.color
        )
        table.insert(self.activeArrows, arrow)
    end

    return true
end

function TripleArrow:draw()
    if not self.area then 
        error("[Erro] [TripleArrow.draw] Área não definida!")
        return
    end

    -- Desenha a prévia da linha se ativa
    if self.visual.preview.active then
        self:drawPreviewLine()
        -- Poderia desenhar o cone de preview também
    end

    -- Desenha as flechas ativas
    for _, arrow in ipairs(self.activeArrows) do
        arrow:draw()
    end
end

function TripleArrow:drawPreviewLine()
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.line(
        self.area.position.x, 
        self.area.position.y,
        self.area.position.x + math.cos(self.area.angle) * self.visual.preview.lineLength,
        self.area.position.y + math.sin(self.area.angle) * self.visual.preview.lineLength
    )
    -- Adicionar desenho do cone de preview aqui se desejado
end

function TripleArrow:getCooldownRemaining()
    return self.cooldownRemaining
end

function TripleArrow:togglePreview()
    self.visual.preview.active = not self.visual.preview.active
end

function TripleArrow:getPreview()
    return self.visual.preview.active
end

return TripleArrow 