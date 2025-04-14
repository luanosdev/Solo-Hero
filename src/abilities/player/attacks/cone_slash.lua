--[[
    Cone Slash Ability
    A cone-shaped area of effect attack that serves as the character's primary attack method
]]

local BaseAbility = require("src.abilities.player._base_ability")
local Camera = require("src.config.camera")
local SpritePlayer = require("src.animations.sprite_player")

local ConeSlash = {
    name = "Cone Slash",
    description = "Um ataque em cone que causa dano a todos os inimigos na área",
    cooldown = 0.5,
    damageType = "melee",
    angle = math.pi / 3, -- 60 graus
    visual = {
        preview = {
            active = false,
            color = {0.7, 0.7, 0.7, 0.2}, -- Cinza bem transparente para a mira
            segments = 20
        },
        attack = {
            color = {1, 0.302, 0.302, 0.6}, -- Vermelho menos transparente para o ataque
            segments = 20,
            animationDuration = 0.2 -- Duração da animação em segundos
        }
    }
}

function ConeSlash:init(owner)
    self.owner = owner
    self.cooldownRemaining = 0
    self.isAttacking = false
    self.attackProgress = 0
    self.area = {
        x = owner.player.x,
        y = owner.player.y,
        angle = 0,
        range = self.range or 100, -- Valor padrão se não definido
        angleWidth = self.angle
    }
end

function ConeSlash:update(dt)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza animação do ataque
    if self.isAttacking then
        self.attackProgress = self.attackProgress + (dt / self.visual.attack.animationDuration)
        if self.attackProgress >= 1 then
            self.isAttacking = false
            self.attackProgress = 0
        end
    end

    -- Atualiza a posição do cone para seguir o jogador
    if self.area then
        self.area.x = self.owner.player.x
        self.area.y = self.owner.player.y

        local mouseX, mouseY = love.mouse.getPosition()
        local worldX, worldY = Camera:screenToWorld(mouseX, mouseY)

        local dx = worldX - self.area.x
        local dy = worldY - self.area.y
        self.area.angle = math.atan2(dy, dx)
    end
end

function ConeSlash:cast(x, y)
    print("\n=== DEBUG DO ATAQUE ===")
    print("ConeSlash: Tentando executar ataque")
    print("Posição do jogador:", self.owner.player.x, self.owner.player.y)
    print("Posição do alvo:", x, y)
    
    if self.cooldownRemaining > 0 then
        print("ConeSlash: Em cooldown - Tempo restante:", self.cooldownRemaining)
        return false
    end
    
    -- Inicia a animação do ataque
    self.isAttacking = true
    self.attackProgress = 0
    
    -- Aplica o cooldown baseado na velocidade de ataque
    self.cooldownRemaining = self.cooldown / self.attackSpeed
    
    return true
end

function ConeSlash:isPointInArea(x, y)
    if not self.area then return false end
    
    -- Calcula a distância do ponto ao centro do cone
    local dx = x - self.area.x
    local dy = y - self.area.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Verifica se está dentro do alcance
    if distance > self.range then
        return false
    end
    
    -- Calcula o ângulo do ponto em relação ao centro do cone
    local pointAngle = math.atan2(dy, dx)
    local angleDiff = math.abs((pointAngle - self.area.angle + math.pi) % (2 * math.pi) - math.pi)
    
    -- Verifica se está dentro do ângulo do cone
    return angleDiff <= self.angle / 2
end

function ConeSlash:applyDamage(target)
    if not self.area then return false end
    
    if self:isPointInArea(target.positionX, target.positionY) then
        return target:takeDamage(self.damage)
    end
    
    return false
end

function ConeSlash:draw()
    if not self.area then 
        error("[Erro] [ConeSlash.draw] Área não definida!")
        return
    end
    
    -- Desenha a prévia do cone se ativa
    if self.visual.preview.active then
        self:drawCone(self.visual.preview.color, 1)
    end
    
    -- Desenha a animação do ataque
    if self.isAttacking then
        print("ConeSlash: Desenhando ataque")
        self:drawCone(self.visual.attack.color, self.attackProgress)
    end
end

function ConeSlash:drawCone(color, progress)
    -- Configura a cor
    love.graphics.setColor(color)
    
    -- Calcula os ângulos do cone
    local startAngle = self.area.angle - self.angle / 2
    local endAngle = self.area.angle + self.angle / 2
    
    -- Desenha as linhas do cone
    love.graphics.line(
        self.area.x, self.area.y,
        self.area.x + math.cos(startAngle) * self.range,
        self.area.y + math.sin(startAngle) * self.range
    )
    
    love.graphics.line(
        self.area.x, self.area.y,
        self.area.x + math.cos(endAngle) * self.range,
        self.area.y + math.sin(endAngle) * self.range
    )
    
    -- Desenha o arco do cone
    love.graphics.arc(
        "line",
        "open",
        self.area.x,
        self.area.y,
        self.range,
        startAngle,
        endAngle,
        32 -- Número de segmentos para o arco
    )
    
    -- Desenha o preenchimento do cone com animação de slash
    if progress > 0 then
        -- Calcula o ângulo de preenchimento baseado no progresso
        local fillAngle = self.angle * progress
        
        -- Calcula o ângulo inicial do preenchimento (começa da esquerda)
        local fillStartAngle = startAngle
        local fillEndAngle = startAngle + (fillAngle * 1.1)
        
        -- Desenha o setor circular preenchido
        love.graphics.setColor(color[1], color[2], color[3], color[4] * 0.8)
        love.graphics.arc(
            "fill",
            "pie",
            self.area.x,
            self.area.y,
            self.range,
            fillStartAngle,
            fillEndAngle,
            32 -- Número de segmentos para o arco
        )
        
        -- Desenha uma linha mais intensa no final do preenchimento
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        love.graphics.line(
            self.area.x,
            self.area.y,
            self.area.x + math.cos(fillEndAngle) * self.range,
            self.area.y + math.sin(fillEndAngle) * self.range
        )
        
        -- Desenha uma linha mais intensa no início do preenchimento
        love.graphics.line(
            self.area.x,
            self.area.y,
            self.area.x + math.cos(fillStartAngle) * self.range,
            self.area.y + math.sin(fillStartAngle) * self.range
        )
    end
end

function ConeSlash:getCooldownRemaining()
    return self.cooldownRemaining
end

function ConeSlash:togglePreview()
    self.visual.preview.active = not self.visual.preview.active
end

function ConeSlash:getPreview()
    return self.visual.preview.active
end

return ConeSlash