local ContactDamage = {
    -- Propriedades da habilidade
    name = "Contact Damage",
    damage = 20,
    cooldown = 1.0,  -- Tempo entre danos em segundos
    cooldownRemaining = 0,
    
    -- Métodos
    init = function(self, owner)
        self.owner = owner
        self.cooldownRemaining = 0
    end,
    
    update = function(self, dt)
        if self.cooldownRemaining > 0 then
            self.cooldownRemaining = math.max(0, self.cooldownRemaining - dt)
        end
    end,
    
    draw = function(self)
        -- Não precisa desenhar nada
    end,
    
    onCollision = function(self, target)
        if self.cooldownRemaining <= 0 then
            target:takeDamage(self.damage)
            self.cooldownRemaining = self.cooldown
        end
    end
}

return ContactDamage 