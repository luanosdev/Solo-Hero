local BaseEnemy = require("src.classes.enemies.base_enemy")
local AnimatedSkeleton = require("src.animations.animated_skeleton")

local Skeleton = setmetatable({}, { __index = BaseEnemy })

-- Configurações específicas do esqueleto
Skeleton.name = "Skeleton"
Skeleton.radius = 10
Skeleton.speed = 30
Skeleton.maxHealth = 200
Skeleton.damage = 30
Skeleton.experienceValue = 10
Skeleton.color = { 0.7, 0.7, 0.7 } -- Cor cinza para o esqueleto

-- Tabela de Drops do Esqueleto
Skeleton.dropTable = {
    normal = {
        guaranteed = {
            -- Nenhum drop garantido
        },
        chance = {
            { type = "item", itemId = "bone_fragment", chance = 25 }, -- 25% chance de Fragmento de Osso (1x1)
        }
    },
    mvp = {
        guaranteed = {
            -- Nenhum drop garantido
        },
        chance = {
            { type = "item", itemId = "intact_skull", chance = 10 }, -- 10% chance Crânio Intacto (2x2)
            {
                type = "item_pool",
                chance = 5, -- 5% de chance de dropar UMA runa do pool
                itemIds = { "rune_orbital_e", "rune_thunder_e", "rune_aura_e" }
            },
        }
    }
}

-- Configurações de animação
Skeleton.animationConfig = {
    scale = 1.2,
    walkPath = "assets/enemies/skeleton/walk/%s/skeleton_default_walk_%s_%s_%d.png",
    deathPath = "assets/enemies/skeleton/death/%s/skeleton_special_death_%s_%s_%d.png",
    frameTime = 0.05,
    deathFrameTime = 0.15
}

function Skeleton:new(position, id)
    -- Cria uma nova instância do inimigo base
    local enemy = BaseEnemy.new(self, position, id)

    -- Configura o sprite do esqueleto
    enemy.sprite = AnimatedSkeleton.newConfig({
        position = position,
        scale = self.animationConfig.scale,
        speed = self.speed,
        animation = {
            frameTime = self.animationConfig.frameTime,
            deathFrameTime = self.animationConfig.deathFrameTime
        }
    })

    -- Inicializa o estado de morte
    enemy.isDying = false
    enemy.isDeathAnimationComplete = false
    enemy.deathTimer = 0
    enemy.deathDuration = 2.0 -- Tempo em segundos para remover após a animação

    -- Sobrescreve a metatable para usar o __index desta classe
    return setmetatable(enemy, { __index = self })
end

-- Função para iniciar a animação de morte
function Skeleton:startDeathAnimation()
    -- Inicia a animação de morte
    AnimatedSkeleton.startDeath(self.sprite)
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
function Skeleton:update(dt, playerManager, enemies)
    -- Se estiver morto, apenas atualiza a animação de morte
    if not self.isAlive then
        AnimatedSkeleton.update(self.sprite, dt, self.sprite.position)

        -- Incrementa o timer de morte
        self.deathTimer = self.deathTimer + dt

        -- Se o tempo de morte passou, marca para remoção
        if self.deathTimer >= self.deathDuration then
            self.shouldRemove = true
        end

        return
    end

    -- Atualiza a posição e animação do esqueleto
    AnimatedSkeleton.update(self.sprite, dt, playerManager.player.position)

    -- Atualiza a posição do inimigo base para corresponder ao sprite
    self.position = self.sprite.position

    -- Chama a função original de BaseEnemy para verificar colisões
    BaseEnemy.update(self, dt, playerManager, enemies)
end

-- Sobrescreve a função draw da classe BaseEnemy
function Skeleton:draw()
    -- Se estiver marcado para remoção, não desenha nada
    if self.shouldRemove then
        return
    end

    -- Chama a função original de BaseEnemy para desenhar a área de colisão e barra de vida
    BaseEnemy.draw(self)

    -- Se estiver morto, desenha apenas a animação de morte
    if not self.isAlive then
        AnimatedSkeleton.draw(self.sprite)
        return
    end

    -- Desenha o sprite do esqueleto
    love.graphics.setColor(1, 1, 1, 1)
    AnimatedSkeleton.draw(self.sprite)
end

return Skeleton
