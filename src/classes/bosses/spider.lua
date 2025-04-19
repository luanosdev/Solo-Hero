local BaseBoss = require("src.classes.bosses.base_boss")
local AnimatedCharacter = require("src.animations.animated_character")

local Spider = setmetatable({}, { __index = BaseBoss })

-- Configurações específicas do boss Spider
Spider.name = "Spider"
Spider.radius = 60
Spider.speed = 80
Spider.maxHealth = 2000
Spider.damage = 60
Spider.color = {0.3, 0.3, 0.3} -- Cinza escuro
Spider.abilityCooldown = 4
Spider.class = Spider

-- CONFIGURAÇÃO DE ANIMAÇÃO PARA AnimatedCharacter
-- Esta tabela será usada na chamada AnimatedCharacter.load("Spider", Spider.animationConfig)
-- Essa chamada deve ocorrer uma vez no início do jogo (ex: main.lua)
Spider.animationConfig = {
    angles = {0, 30, 45, 60, 90, 120, 135, 150, 180, 210, 225, 240, 270, 300, 315, 330},
    assetPaths = {
        walk = {
            body = "assets/bosses/spider/walk/Walk_Body_%s.png",
            shadow = "assets/bosses/spider/walk/Walk_Shadow_%s.png"
        },
        death = {
            die1 = {
                body = "assets/bosses/spider/die1/Die1_Body_%s.png",
                shadow = "assets/bosses/spider/die1/Die1_Shadow_%s.png"
            },
            die2 = {
                body = "assets/bosses/spider/die2/Die2_Body_%s.png",
                shadow = "assets/bosses/spider/die2/Die2_Shadow_%s.png"
            }
        }
    },
    grid = {
        walk = { cols = 4, rows = 4 }, -- 16 frames
        death = {
            die1 = { cols = 8, rows = 3 }, -- 24 frames
            die2 = { cols = 5, rows = 4 }  -- 20 frames
        }
    },
    origin = { x = 128, y = 128 }, -- Ponto de origem (centro para 256x256)
    angleOffset = 90,          -- Ajuste para alinhar 0 graus do sprite com a matemática
    drawShadow = true,
    shadowColor = {1, 1, 1, 0.5}, -- Sombra mais clara para a aranha
    resetFrameOnStop = false,
    instanceDefaults = { -- Valores padrão para cada instância Spider
        scale = 2.0,
        speed = 80,
        animation = {
            frameTime = 0.12, -- Tempo entre frames de walk
            deathFrameTime = 0.10 -- Tempo entre frames de death (mais rápido)
        }
    }
}

function Spider:new(position, id)
    local boss = BaseBoss.new(self, position, id)
    setmetatable(boss, { __index = self })
    -- Configura o sprite da Aranha usando AnimatedCharacter
    boss.sprite = AnimatedCharacter.newConfig("Spider", {
        position = { x = position.x, y = position.y } -- Passa posição inicial
    })
    boss.position = boss.sprite.position
    boss.isAlive = true
    boss.isDying = false
    boss.deathTimer = 0
    boss.deathDuration = 5.0
    boss.health = self.maxHealth
    boss.lastDirection = 0
    return boss
end

function Spider:update(dt, playerManager, enemies)
    if not self.isAlive then 
        -- Atualiza a animação de morte usando a última direção
        if self.lastDirection then
            -- Usa a última direção para a animação de morte
            self.sprite.animation.direction = self.lastDirection
            AnimatedCharacter.update("Spider", self.sprite, dt, nil) -- Atualiza animação sem alvo
        else
            -- Se por algum motivo a direção não estiver definida, usa a direção atual do sprite
            AnimatedCharacter.update("Spider", self.sprite, dt, nil) -- Atualiza animação sem alvo
        end
        self.deathTimer = self.deathTimer + dt
        if self.deathTimer >= self.deathDuration then
            self.shouldRemove = true
        end
        return 
    end
    
    -- Atualiza animação e posição
    AnimatedCharacter.update("Spider", self.sprite, dt, playerManager.player.position)
    self.position = self.sprite.position
    -- Salva a direção atual
    self.lastDirection = self.sprite.animation.direction
    -- Chama update base para lógica de habilidades
    BaseBoss.update(self, dt, playerManager, enemies)
end

function Spider:draw()
    AnimatedCharacter.draw("Spider", self.sprite)
end

function Spider:takeDamage(amount)
    self.health = self.health - amount
    if self.health <= 0 and self.isAlive then
        self.isAlive = false
    end
end

-- Função para iniciar a animação de morte
function Spider:startDeathAnimation()
    -- Garante que a direção da animação de morte seja a última direção
    self.sprite.animation.direction = self.lastDirection
    AnimatedCharacter.startDeath("Spider", self.sprite)
end

return Spider 