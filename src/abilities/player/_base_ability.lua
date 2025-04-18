--[[
    Base Ability
    Classe base abstrata para todas as habilidades
]]

local Camera = require("src.config.camera")

local BaseAbility = {
    -- Propriedades que devem ser sobrescritas
    name = "Base Ability",
    damageType = nil,
    cooldown = 0,
    damage = 0,

    -- Estado interno
    cooldownRemaining = 0,

    -- Visual State
    visual = {
        active = false,
        angle = 0,
        targetAngle = 0,
    },

    -- New property
    radius = 0,
}

--[[
    Inicializa a habilidade
    @param owner A entidade que possui esta habilidade
]]
function BaseAbility:init(playerManager)
    self.playerManager = playerManager
    self.cooldownRemaining = 0
end

--[[
    Atualiza o estado da habilidade
    @param dt Delta time
]]
function BaseAbility:update(dt)
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = math.max(0, self.cooldownRemaining - dt * self.playerManager.player.state:getTotalAttackSpeed())
    end

    -- Update target angle to follow mouse
    local mouseX, mouseY = love.mouse.getPosition()

    -- Converte a posição do mouse para coordenadas do mundo
    local worldX, worldY = Camera:screenToWorld(mouseX, mouseY)
    local dx = worldX - self.playerManager.player.position.x
    local dy = worldY - self.playerManager.player.position.y

    -- Tratamento especial para alinhamentos exatos
    if math.abs(dx) < 0.1 then  -- Mouse alinhado verticalmente
        self.visual.angle = dy > 0 and math.pi/2 or -math.pi/2
    elseif math.abs(dy) < 0.1 then  -- Mouse alinhado horizontalmente
        self.visual.angle = dx > 0 and 0 or math.pi
    else
        -- Caso normal, calcula o ângulo usando math.atan
        self.visual.angle = math.atan(dy/dx)
        if dx < 0 then
            self.visual.angle = self.visual.angle + math.pi
        end
    end
end

--[[
    Desenha a habilidade
]]
function BaseAbility:draw()
    -- Deve ser implementado pelas classes filhas
end

--[[
    Verifica se um ponto está dentro da área de efeito da habilidade
    @param x Posição X do ponto
    @param y Posição Y do ponto
    @return boolean Se o ponto está dentro da área de efeito
]]
function BaseAbility:isPointInArea()
    -- Deve ser implementado pelas classes filhas
    return false
end

--[[
    Lança a habilidade
    @param x Posição X do mouse
    @param y Posição Y do mouse
    @return boolean Se a habilidade foi lançada com sucesso
]]
function BaseAbility:cast()
    if self.cooldownRemaining > 0 then return false end
    
    self.cooldownRemaining = self.cooldown
    return true
end

--[[
    Obtém o cooldown restante
    @return number Tempo restante do cooldown
]]
function BaseAbility:getCooldownRemaining()
    return self.cooldownRemaining
end

--[[
    Alterna a visualização da habilidade
]]
function BaseAbility:toggleVisual()
    self.visual.active = not self.visual.active
end

--[[
    Return the ability visual
]]
function BaseAbility:getVisual()
    return self.visual.active
end


--[[
    Update visual angle based on target position
    @param x Target X position
    @param y Target Y position
]]
function BaseAbility:updateVisual(x, y)
    if not self.visual.active then return end

    -- Converte a posição do alvo para coordenadas do mundo
    local worldX, worldY = Camera:screenToWorld(x, y)
    local dx = worldX - self.playerManager.player.position.x
    local dy = worldY - self.playerManager.player.position.y

    self.visual.angle = math.atan2(dy, dx)
end

--[[
    Aplica dano a um alvo
    @param target O alvo que receberá o dano
    @return boolean Se o alvo morreu do dano
]]
function BaseAbility:applyDamage(target)
    if not target or not target.takeDamage then return false end
    return target:takeDamage(self.damage)
end

return BaseAbility