local BaseEnemy = require("src.classes.enemies.base_enemy")

local BaseBoss = setmetatable({}, { __index = BaseEnemy })

-- Configurações base para todos os bosses
BaseBoss.isBoss = true
BaseBoss.healthBarWidth = 100 -- Barra de vida maior para bosses
BaseBoss.experienceValue = 1000 -- Experiência base alta para bosses

-- Sistema de habilidades
BaseBoss.abilities = {} -- Tabela de habilidades do boss
BaseBoss.currentAbilityIndex = 1 -- Índice da habilidade atual
BaseBoss.abilityCooldown = 0 -- Cooldown entre habilidades
BaseBoss.abilityTimer = 0 -- Timer para controle de habilidades

function BaseBoss:new(x, y)
    local boss = BaseEnemy.new(self, x, y)
    setmetatable(boss, { __index = self })
    
    -- Inicializa o sistema de habilidades
    boss.abilityTimer = 0
    boss.currentAbilityIndex = 1
    boss.class = self -- Define a classe do boss
    
    return boss
end

function BaseBoss:update(dt, player, enemies)
    if not self.isAlive then return end
    
    -- Atualiza o timer de habilidades
    self.abilityTimer = self.abilityTimer + dt
    
    -- Verifica se pode usar uma habilidade
    if self.abilityTimer >= self.abilityCooldown then
        self:useAbility(player, enemies)
        self.abilityTimer = 0
    end
    
    -- Chama o update da classe base para movimento e colisão
    BaseEnemy.update(self, dt, player, enemies)
end

function BaseBoss:useAbility(player, enemies)
    if not self.abilities or #self.abilities == 0 then return end
    
    -- Usa a habilidade atual
    local ability = self.abilities[self.currentAbilityIndex]
    if ability and ability.cast then
        ability:cast(self, player, enemies)
    end
    
    -- Avança para a próxima habilidade
    self.currentAbilityIndex = (self.currentAbilityIndex % #self.abilities) + 1
end

function BaseBoss:draw()
    if not self.isAlive then return end
    
    -- Desenha o boss com efeito visual especial
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.positionX, self.positionY, self.radius)
    
    -- Desenha um círculo de brilho ao redor do boss
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.3)
    love.graphics.circle("fill", self.positionX, self.positionY, self.radius * 1.5)
end

return BaseBoss 