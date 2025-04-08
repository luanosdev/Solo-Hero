--[[
    Enemy Base Ability
    Base class for enemy abilities
]]

local EnemyBaseAbility = {
    name = "Enemy Base Ability",
    cooldown = 0,
    cooldownRemaining = 0,
    damage = 0,
    damageType = "enemy",
    owner = nil
}

function EnemyBaseAbility:init(owner)
    self.owner = owner
    self.cooldownRemaining = 0
end

function EnemyBaseAbility:update(dt)
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = math.max(0, self.cooldownRemaining - dt)
    end
end

function EnemyBaseAbility:draw()
    -- Implementação base vazia
end

function EnemyBaseAbility:cast(targetX, targetY)
    if self.cooldownRemaining > 0 then return false end
    self.cooldownRemaining = self.cooldown
    return true
end

function EnemyBaseAbility:getCooldownRemaining()
    return self.cooldownRemaining
end

return EnemyBaseAbility 