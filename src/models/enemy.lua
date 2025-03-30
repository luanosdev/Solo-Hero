local Enemy = {
    positionX = 0,
    positionY = 0,

    class = nil,

    -- Base Stats (will be set by class)
    maxHealth = 0,
    damage = 0,
    defense = 0,
    baseSpeed = 0,
    attackSpeed = 0,

    -- Abilities
    abilities = {},

    -- Target
    targetX = 0,
    targetY = 0,

    init = function(self, class, targetX, targetY)
        self.class = class
        local baseStats = self.class:getBaseStats()

        -- Apply base stats
        self.maxHealth = baseStats.health
        self.damage = baseStats.damage
        self.defense = baseStats.defense
        self.baseSpeed = baseStats.speed
        self.attackSpeed = baseStats.attackSpeed

        -- Initialize abilities
        local abilities = self.class:getAbilities()
        self.abilities = abilities
        for _, ability in ipairs(self.abilities) do
            ability:init(self)
        end

        -- Initialize target
        self.targetX = targetX
        self.targetY = targetY
    end;

    --[[
        Update enemy position
        @param dt Delta time (time between frames)
    ]]
    update = function(self, dt)
        if not self.isAlive then return end

        -- Update abilities
        for _, ability in ipairs(self.abilities) do
            ability:update(dt)
        end

        -- Auto Attack logic
        if self.autoAttack then
            for _, ability in ipairs(self.abilities) do
                local cooldown = ability:getCooldownRemaining()
                if cooldown <= 0 then
                    ability:cast(self.targetX, self.targetY)
                end
            end
        end
    end
}

return Enemy
