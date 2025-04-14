local BaseEnemy = require("src.classes.enemies.base_enemy")
local AnimatedSkeleton = require("src.animations.animated_skeleton")

local Skeleton = setmetatable({}, { __index = BaseEnemy })

-- Configurações específicas do esqueleto
Skeleton.name = "Skeleton"
Skeleton.radius = 25
Skeleton.speed = 80
Skeleton.maxHealth = 100
Skeleton.damage = 10
Skeleton.experienceValue = 10
Skeleton.color = {0.7, 0.7, 0.7} -- Cor cinza para o esqueleto

-- Configurações de animação
Skeleton.animationConfig = {
    scale = 1.5,
    walkPath = "assets/enemies/skeleton/walk/%s/skeleton_default_walk_%s_%s_%d.png",
    deathPath = "assets/enemies/skeleton/death/%s/skeleton_special_death_%s_%s_%d.png",
    frameTime = 0.1,
    deathFrameTime = 0.15
}

function Skeleton:new(x, y)
    -- Cria uma nova instância do inimigo base
    local enemy = BaseEnemy.new(self, x, y)
    
    -- Configura o sprite do esqueleto
    enemy.sprite = AnimatedSkeleton.newConfig({
        x = x,
        y = y,
        scale = self.animationConfig.scale,
        speed = self.speed,
        animation = {
            frameTime = self.animationConfig.frameTime,
            deathFrameTime = self.animationConfig.deathFrameTime
        }
    })
    
    -- Sobrescreve a metatable para usar o __index desta classe
    return setmetatable(enemy, { __index = self })
end

-- Sobrescreve a função takeDamage da classe BaseEnemy
function Skeleton:takeDamage(damage, isCritical)
    -- Chama a função original de BaseEnemy para aplicar dano, mostrar texto, etc.
    local died = BaseEnemy.takeDamage(self, damage, isCritical)
    
    -- Se o inimigo morreu, inicia a animação de morte
    if died then
        AnimatedSkeleton.startDeath(self.sprite)
    end
    
    return died
end

-- Sobrescreve a função update da classe BaseEnemy
function Skeleton:update(dt, player, enemies)
    if not self.isAlive then
        -- Se estiver morto, apenas atualiza a animação de morte
        AnimatedSkeleton.update(self.sprite, dt, self.sprite.x, self.sprite.y)
        return
    end
    
    -- Atualiza a posição e animação do esqueleto
    AnimatedSkeleton.update(self.sprite, dt, player.positionX, player.positionY)
    
    -- Atualiza a posição do inimigo base para corresponder ao sprite
    self.positionX = self.sprite.x
    self.positionY = self.sprite.y
    
    -- Chama a função original de BaseEnemy para verificar colisões
    BaseEnemy.update(self, dt, player, enemies)
end

-- Sobrescreve a função draw da classe BaseEnemy
function Skeleton:draw()
    if not self.isAlive then
        -- Se estiver morto, apenas desenha a animação de morte
        AnimatedSkeleton.draw(self.sprite)
        return
    end
    
    -- Chama a função original de BaseEnemy para desenhar a área de colisão e barra de vida
    BaseEnemy.draw(self)
    
    -- Desenha o sprite do esqueleto
    love.graphics.setColor(1, 1, 1, 1)
    AnimatedSkeleton.draw(self.sprite)
end

return Skeleton 