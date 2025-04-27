-- src/data/character_data.lua
-- Define os atributos base para diferentes arquétipos de personagens.

local CharacterData = {
    warrior = {
        name = "Guerreiro",
        description = "Um combatente robusto e equilibrado.",
        -- Atributos Base
        baseHealth = 120,
        baseDefense = 15,
        baseSpeed = 5.0,              -- Velocidade de Movimento
        baseCriticalChance = 0.05,    -- 5%
        baseCriticalMultiplier = 1.5, -- Dano Crítico (150%)
        baseHealthRegen = 0.5,        -- HP por segundo
        baseMultiAttackChance = 0.0,  -- 0%
        baseAttackSpeed = 1.0,        -- Ataques por segundo (inverso do cooldown base)
        baseDamage = 12,              -- Dano base inicial (necessário para PlayerState)
        moveSpeed = 150,
        maxHealth = 100,
        defense = 5,
        maxRuneSlots = 3 -- <<< ADICIONADO: Número máximo de runas
        -- Poderíamos adicionar outros stats base específicos aqui se necessário
    },
    -- Adicionar outros arquétipos aqui (ex: archer, mage)
    -- archer = { ... },
}

return CharacterData
