local BaseEnemy = require("src.classes.enemies.base_enemy")
local AnimatedCharacter = require("src.animations.animated_character")

local Zombie = setmetatable({}, { __index = BaseEnemy })

-- Configurações específicas do Zumbi
Zombie.name = "Zombie"
Zombie.radius = 12 -- Ajuste conforme o tamanho do sprite
Zombie.speed = 20  -- Usará a speed da config de animação
Zombie.maxHealth = 500
Zombie.damage = 50
Zombie.experienceValue = 12
Zombie.color = { 0.2, 0.6, 0.2 } -- Cor verde musgo para o zumbi

-- Tabela de Drops do Zumbi
Zombie.dropTable = {
    normal = {
        guaranteed = {},
        chance = {
            { type = "item", itemId = "tattered_cloth", chance = 30 }, -- 30% chance de Pano Rasgado (1x1)
        }
    },
    mvp = {
        guaranteed = {
            -- Nenhum drop garantido
        },
        chance = {
            { type = "item", itemId = "intact_skull", chance = 12 }, -- 12% chance Crânio Intacto (2x2)
            {
                type = "item_pool",
                chance = 5, -- 5% de chance de dropar UMA runa do pool
                itemIds = { "rune_orbital_e", "rune_thunder_e", "rune_aura_e" }
            },
            -- { type = "item", itemId = "minor_heal_orb", chance = 5 }
        }
    }
}

-- Configuração do Desvio Aleatório
Zombie.deviationMagnitudeMax = 90     -- Quão longe o zumbi pode desviar lateralmente
Zombie.deviationChangeFrequency = 0.8 -- Com que frequência (em segundos) o desvio pode mudar

-- CONFIGURAÇÃO DE ANIMAÇÃO PARA AnimatedCharacter
-- Esta tabela será usada na chamada AnimatedCharacter.load("Zombie", Zombie.animationConfig)
-- Essa chamada deve ocorrer uma vez no início do jogo (ex: main.lua)
Zombie.animationConfig = {
    angles = { 0, 45, 90, 135, 180, 225, 270, 315 },
    assetPaths = {
        walk = {
            body = "assets/enemies/zombie/walk/Walk_Body_%s.png",
            shadow = "assets/enemies/zombie/walk/Walk_Shadow_%s.png"
        },
        death = {
            die1 = {
                body = "assets/enemies/zombie/die1/Die1_Body_%s.png",
                shadow = "assets/enemies/zombie/die1/Die1_Shadow_%s.png"
            },
            die2 = {
                body = "assets/enemies/zombie/die2/Die2_Body_%s.png",
                shadow = "assets/enemies/zombie/die2/Die2_Shadow_%s.png"
            }
        }
    },
    grid = {
        walk = { cols = 4, rows = 5 },     -- 20 frames
        death = {
            die1 = { cols = 6, rows = 4 }, -- 24 frames
            die2 = { cols = 6, rows = 4 }  -- 24 frames
        }
    },
    origin = { x = 128, y = 128 }, -- Ponto de origem (centro para 256x256)
    angleOffset = 90,              -- Ajuste para alinhar 0 graus do sprite com a matemática
    drawShadow = true,
    resetFrameOnStop = false,
    instanceDefaults = { -- Valores padrão para cada instância Zumbi
        scale = 0.4,
        speed = Zombie.speed,
        animation = {
            frameTime = 0.05,     -- Tempo entre frames de walk
            deathFrameTime = 0.12 -- Tempo entre frames de death
        }
    }
}

function Zombie:new(position, id)
    -- Cria uma nova instância do inimigo base
    local enemy = BaseEnemy.new(self, position, id)

    -- Configura o sprite do zumbi usando AnimatedCharacter
    enemy.sprite = AnimatedCharacter.newConfig("Zombie", {
        position = { x = position.x, y = position.y } -- Passa posição inicial como override
        -- Scale, speed, frameTime, etc., virão dos instanceDefaults definidos acima
    })
    enemy.speed = enemy.sprite.speed -- Garante que a speed da classe e do sprite sejam a mesma

    -- Estado para desvio aleatório
    enemy.deviationAngle = 0                                                  -- Ângulo atual do desvio (será +/- 90 graus da direção principal)
    enemy.deviationMagnitude = 0                                              -- Magnitude atual do desvio
    enemy.deviationTimer = love.math.random() * self.deviationChangeFrequency -- Inicia com timer aleatório

    -- Estado de morte (similar ao Skeleton)
    enemy.isDying = false
    enemy.isDeathAnimationComplete = false
    enemy.deathTimer = 0
    enemy.deathDuration = 1.5 -- Tempo para remover após animação de morte terminar

    -- Sobrescreve a metatable para usar o __index desta classe
    return setmetatable(enemy, { __index = self })
end

-- Sobrescreve a função takeDamage
function Zombie:takeDamage(damage, isCritical)
    -- Chama a função original de BaseEnemy
    local died = BaseEnemy.takeDamage(self, damage, isCritical)

    -- Se morreu e ainda não está no estado de morte, inicia animação
    if died and not self.isDying then
        self.isDying = true
        AnimatedCharacter.startDeath("Zombie", self.sprite)
    end

    return died
end

-- Sobrescreve a função update
function Zombie:update(dt, playerManager, enemies)
    -- Se já está marcado para remoção, não faz nada
    if self.shouldRemove then return end

    -- Atualiza animação de morte se estiver morrendo
    if not self.isAlive then
        -- Atualiza a animação sem alvo de movimento
        local animationFinished = AnimatedCharacter.update("Zombie", self.sprite, dt, nil)
        -- Se a animação terminou, começa timer para remover o corpo
        if animationFinished and not self.isDeathAnimationComplete then
            self.isDeathAnimationComplete = true
            self.deathTimer = 0 -- Inicia timer agora
        end
        -- Se a animação terminou e o timer expirou, marca para remoção
        if self.isDeathAnimationComplete then
            self.deathTimer = self.deathTimer + dt
            if self.deathTimer >= self.deathDuration then
                self.shouldRemove = true
            end
        end
        -- Atualiza a posição base para a posição do sprite (mesmo morrendo)
        self.position = self.sprite.position
        return -- Não faz mais nada se estiver morto/morrendo
    end

    -- Lógica de movimento para zumbi vivo
    local playerPos = playerManager.player.position

    -- 1. Atualizar Timer de Desvio e Recalcular Desvio se necessário
    self.deviationTimer = self.deviationTimer + dt
    if self.deviationTimer >= self.deviationChangeFrequency then
        -- Subtrai para acumular excesso
        self.deviationTimer = self.deviationTimer - self.deviationChangeFrequency
        -- Sorteia uma nova magnitude de desvio (pode ser 0 para andar reto)
        self.deviationMagnitude = love.math.random() * self.deviationMagnitudeMax *
            (love.math.random(2) == 1 and 1 or -1) -- Magnitude aleatória positiva ou negativa
        -- print(string.format("Zombie %s new deviation: %.1f", self.id, self.deviationMagnitude))
    end

    -- 2. Calcular Vetor Direto para o Jogador
    local dx = playerPos.x - self.sprite.position.x
    local dy = playerPos.y - self.sprite.position.y
    local distToPlayer = math.sqrt(dx * dx + dy * dy)

    local targetForAnimation = playerPos -- Ponto de referência inicial

    if distToPlayer > 0 then             -- Evita divisão por zero se estiver exatamente na posição do jogador
        local dirX = dx / distToPlayer
        local dirY = dy / distToPlayer

        -- 3. Calcular Vetor Perpendicular
        local perpX = -dirY
        local perpY = dirX

        -- 4. Calcular Posição Alvo com Desvio
        -- O "alvo" que passaremos para a animação será um ponto à frente na direção
        -- direta + o desvio perpendicular atual.
        -- Usamos a velocidade como uma forma de projetar um ponto à frente, o que ajuda
        -- a suavizar a mudança de direção na animação.
        local lookAheadDist = self.speed -- Distância para projetar o ponto alvo

        targetForAnimation = {
            x = self.sprite.position.x + dirX * lookAheadDist + perpX * self.deviationMagnitude,
            y = self.sprite.position.y + dirY * lookAheadDist + perpY * self.deviationMagnitude
        }
    else
        -- Se já está em cima do jogador, não há desvio ou direção definida
        targetForAnimation = playerPos
    end

    -- 5. Atualiza a animação/movimento do Zumbi usando o alvo COM DESVIO
    AnimatedCharacter.update("Zombie", self.sprite, dt, targetForAnimation)

    -- Atualiza a posição do inimigo base para corresponder ao sprite após o movimento
    self.position = self.sprite.position

    -- Chama a função original de BaseEnemy para verificar colisões e aplicar dano ao jogador
    BaseEnemy.update(self, dt, playerManager, enemies)
end

-- Sobrescreve a função draw
function Zombie:draw()
    -- Não desenha se marcado para remoção
    if self.shouldRemove then return end

    -- Desenha o sprite (que lida com estado walk/death)
    love.graphics.setColor(1, 1, 1, 1)
    AnimatedCharacter.draw("Zombie", self.sprite)

    -- Desenha a barra de vida e área de colisão (apenas se vivo)
    BaseEnemy.draw(self) -- Chama draw base para health bar e collision area (se debug ativado)
end

return Zombie
