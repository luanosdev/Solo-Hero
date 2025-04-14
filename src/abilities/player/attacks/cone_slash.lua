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
            segments = 20
        },
        attack = {
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
    
    -- Usa as cores da arma se disponíveis
    self.visual.preview.color = self.previewColor or {0.7, 0.7, 0.7, 0.2}
    self.visual.attack.color = self.attackColor or {1, 0.302, 0.302, 0.6}
    
    -- Usa os atributos da arma
    local weapon = owner.equippedWeapon
    self.area = {
        x = owner.player.x,
        y = owner.player.y,
        angle = 0,
        range = weapon.range, -- Usa o range da arma
        angleWidth = math.rad(90) -- Ângulo fixo de 90 graus
    }
    
    print("\n=== DEBUG INICIALIZAÇÃO CONE ===")
    print("Posição inicial:", self.area.x, self.area.y)
    print("Alcance:", self.area.range)
    print("Ângulo:", math.deg(self.angle))
    print("Arma:", weapon.name)
    print("Range da arma:", weapon.range)
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
        self.area.y = self.owner.player.y -- Mantém o cone na mesma altura do jogador

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
    print("Posição do cone:", self.area.x, self.area.y)
    print("Ângulo do cone:", math.deg(self.area.angle))
    print("Alcance do cone:", self.area.range)
    
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
    
    -- Debug: Mostra as coordenadas originais
    print(string.format(
        "\n=== DEBUG COORDENADAS ===\n" ..
        "Coordenadas originais:\n" ..
        "Ponto: (%.1f, %.1f)\n" ..
        "Centro: (%.1f, %.1f)",
        x, y,
        self.area.x, self.area.y
    ))
    
    -- Converte as coordenadas para o espaço isométrico
    local isoX = x - self.area.x
    local isoY = (y - self.area.y) * 2 -- Multiplica por 2 para compensar a escala isométrica
    
    -- Debug: Mostra as coordenadas isométricas
    print(string.format(
        "Coordenadas isométricas:\n" ..
        "Ponto: (%.1f, %.1f)\n" ..
        "Centro: (0, 0)",
        isoX, isoY
    ))
    
    -- Calcula a distância do ponto ao centro do cone
    local distance = math.sqrt(isoX * isoX + isoY * isoY)
    
    -- Verifica se está dentro do alcance
    if distance > self.area.range then
        print("Fora do alcance:", distance, ">", self.area.range)
        return false
    end
    
    -- Calcula o ângulo do ponto em relação ao centro do cone
    local pointAngle = math.atan2(isoY, isoX)
    
    -- Normaliza os ângulos para o intervalo [0, 2π]
    local normalizedPointAngle = (pointAngle + 2 * math.pi) % (2 * math.pi)
    local normalizedConeAngle = (self.area.angle + 2 * math.pi) % (2 * math.pi)
    
    -- Calcula a diferença de ângulo
    local angleDiff = math.abs(normalizedPointAngle - normalizedConeAngle)
    if angleDiff > math.pi then
        angleDiff = 2 * math.pi - angleDiff
    end
    
    -- Debug: Mostra informações sobre o ponto
    if self.isAttacking then
        print(string.format(
            "=== DEBUG CONE SLASH ===\n" ..
            "Distância: %.1f\n" ..
            "Ângulo do ponto: %.1f\n" ..
            "Ângulo do cone: %.1f\n" ..
            "Diferença de ângulo: %.1f\n" ..
            "Dentro do cone: %s\n" ..
            "Ângulo do cone (graus): %.1f\n" ..
            "Metade do ângulo do cone: %.1f\n" ..
            "Distância máxima: %.1f",
            distance,
            math.deg(normalizedPointAngle),
            math.deg(normalizedConeAngle),
            math.deg(angleDiff),
            angleDiff <= self.area.angleWidth / 2 and "Sim" or "Não",
            math.deg(self.area.angleWidth),
            math.deg(self.area.angleWidth / 2),
            self.area.range
        ))
    end
    
    -- Verifica se está dentro do ângulo do cone
    return angleDiff <= self.area.angleWidth / 2
end

function ConeSlash:applyDamage(target)
    if not self.area then return false end
    
    if self:isPointInArea(target.positionX, target.positionY) then
        -- Obtém o dano da arma
        local weaponDamage = self.owner.equippedWeapon.damage
        
        -- Calcula o dano total com os bônus
        local totalDamage = self.owner.state:getTotalDamage(weaponDamage)
        
        -- Calcula se o dano é crítico
        local isCritical = math.random() <= self.owner.state:getTotalCriticalChance()
        if isCritical then
            totalDamage = math.floor(totalDamage * self.owner.state:getTotalCriticalMultiplier())
        end
        
        print(string.format(
            "\n=== DEBUG DANO ===\n" ..
            "Aplicando dano ao inimigo\n" ..
            "Posição do inimigo: (%.1f, %.1f)\n" ..
            "Dano da arma: %.1f\n" ..
            "Dano total: %.1f\n" ..
            "Dano crítico: %s",
            target.positionX,
            target.positionY,
            weaponDamage,
            totalDamage,
            isCritical and "Sim" or "Não"
        ))
        
        -- Aplica o dano
        return target:takeDamage(totalDamage, isCritical)
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
    
    -- Salva o estado atual de transformação
    love.graphics.push()
    
    -- Translada para a posição do cone
    love.graphics.translate(self.area.x, self.area.y)
    
    -- Aplica a transformação isométrica
    love.graphics.scale(1, 0.5) -- Escala vertical para efeito isométrico
    
    -- Calcula os ângulos do cone
    local startAngle = self.area.angle - self.area.angleWidth / 2
    local endAngle = self.area.angle + self.area.angleWidth / 2
    
    -- Desenha o preenchimento do cone com animação de slash
    if progress > 0 then
        -- Calcula o ângulo de preenchimento baseado no progresso
        local fillEndAngle = startAngle + (self.area.angleWidth * progress)
        
        -- Desenha o setor circular preenchido
        love.graphics.setColor(color[1], color[2], color[3], color[4] * 0.8)
        love.graphics.arc(
            "fill",
            "pie",
            0, 0,
            self.area.range,
            startAngle,
            fillEndAngle,
            32 -- Número de segmentos para o arco
        )
        
        -- Desenha uma linha mais intensa no final do preenchimento
        love.graphics.setColor(color[1], color[2], color[3], color[4])
        love.graphics.line(
            0, 0,
            math.cos(fillEndAngle) * self.area.range,
            math.sin(fillEndAngle) * self.area.range
        )
    end
    
    -- Desenha as linhas do cone (contorno)
    love.graphics.setColor(color)
    love.graphics.line(
        0, 0,
        math.cos(startAngle) * self.area.range,
        math.sin(startAngle) * self.area.range
    )
    
    love.graphics.line(
        0, 0,
        math.cos(endAngle) * self.area.range,
        math.sin(endAngle) * self.area.range
    )
    
    -- Desenha o arco do cone
    love.graphics.arc(
        "line",
        "open",
        0, 0,
        self.area.range,
        startAngle,
        endAngle,
        32 -- Número de segmentos para o arco
    )
    
    -- Restaura o estado de transformação
    love.graphics.pop()
    
    -- Debug: Desenha um ponto no centro do cone
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.circle("fill", self.area.x, self.area.y, 5)
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