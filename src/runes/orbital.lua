--[[
    Orbital Rune
    Cria orbes que orbitam ao redor do jogador e causam dano aos inimigos próximos
]]

local BaseAbility = require("src.abilities.player._base_ability")

local OrbitalRune = setmetatable({}, { __index = BaseAbility })

OrbitalRune.name = "Orbes Orbitais"
OrbitalRune.description = "Cria orbes que orbitam ao redor do jogador e causam dano aos inimigos próximos"
OrbitalRune.damage = 15
OrbitalRune.damageType = "orbital"
OrbitalRune.color = {0, 0.8, 1, 0.3} -- Cor azul para os orbes

OrbitalRune.orbitRadius = 50 -- Raio da órbita
OrbitalRune.orbCount = 3 -- Número de orbes
OrbitalRune.orbRadius = 8 -- Tamanho de cada orbe
OrbitalRune.rotationSpeed = 2 -- Velocidade de rotação em radianos por segundo

function OrbitalRune:init(owner)
    BaseAbility.init(self, owner)
    
    -- Estado dos orbes
    self.orbs = {}
    for i = 1, self.orbCount do
        table.insert(self.orbs, {
            angle = (i - 1) * (2 * math.pi / self.orbCount), -- Distribui os orbes igualmente
            damagedEnemies = {} -- Lista de inimigos que já foram danificados por este orbe
        })
    end
end

function OrbitalRune:update(dt)
    BaseAbility.update(self, dt)
    
    -- Atualiza a posição dos orbes
    for _, orb in ipairs(self.orbs) do
        -- Atualiza o ângulo de rotação
        orb.angle = orb.angle + self.rotationSpeed * dt
        
        -- Aplica dano constantemente
        self:applyOrbitalDamage(orb)
    end
end

function OrbitalRune:draw()
    for _, orb in ipairs(self.orbs) do
        -- Calcula a posição do orbe
        local x = self.owner.positionX + math.cos(orb.angle) * self.orbitRadius
        local y = self.owner.positionY + math.sin(orb.angle) * self.orbitRadius
        
        -- Desenha o orbe base
        love.graphics.setColor(self.color)
        love.graphics.circle("fill", x, y, self.orbRadius)
        
        -- Desenha o efeito de pulso
        local pulseRadius = self.orbRadius * 1.5
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.color[4] * 0.5)
        love.graphics.circle("line", x, y, pulseRadius)
    end
end

function OrbitalRune:cast(x, y)
    if not BaseAbility.cast(self, x, y) then return false end
    return true
end

function OrbitalRune:applyOrbitalDamage(orb)
    if not self.owner.world or not self.owner.world.enemies then return end
    
    -- Calcula a posição do orbe
    local orbX = self.owner.positionX + math.cos(orb.angle) * self.orbitRadius
    local orbY = self.owner.positionY + math.sin(orb.angle) * self.orbitRadius
    
    for _, enemy in ipairs(self.owner.world.enemies) do
        if enemy.isAlive and not orb.damagedEnemies[enemy] then
            local dx = enemy.positionX - orbX
            local dy = enemy.positionY - orbY
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance <= self.orbRadius * 2 then -- Área de dano um pouco maior que o orbe
                if self:applyDamage(enemy) then
                    -- Marca o inimigo como danificado por este orbe
                    orb.damagedEnemies[enemy] = true
                end
            end
        end
    end
end

return OrbitalRune 