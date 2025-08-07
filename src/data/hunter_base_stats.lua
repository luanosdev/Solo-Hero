--- Este arquivo centraliza os atributos base para todos os caçadores.
-- Ele serve como a fonte da verdade para o estado inicial de um jogador,
-- antes da aplicação de quaisquer bônus de arquétipos, equipamentos, etc.
-- Seguindo a regra de separação de Lógica e Dados, este arquivo contém
-- apenas dados puros e balanceáveis.

---@class HunterBaseStats
local HunterBaseStats = {
    maxHealth = 300,
    attackSpeed = 1.0,       -- Attacks per second
    moveSpeed = 5.0,         -- Metros por segundo (m/s) - convertido automaticamente para pixels
    critChance = 0.10,       -- 10%
    critDamage = 1.5,        -- 150% Multiplier
    multiAttackChance = 0.1, -- 20%
    expBonus = 1.0,          -- 100%
    defense = 10,
    healthRegen = 0.5,       -- 0.2 hp por segundo
    range = 1.0,             -- Multiplier (1.0 = base weapon/skill)
    area = 1.0,              -- Multiplier (1.0 = base weapon/skill)
    pickupRadius = 3,        -- Metros - convertido automaticamente para pixels
    healingBonus = 1.0,      -- Multiplier (1.0 = 100% healing received)
    runeSlots = 3,           -- Number of rune slots
    luck = 1.0,              -- Multiplier (1.0 = 100% luck)
    strength = 1.0,          -- Multiplier (1.0 = 100% strength)
    -- Atributos de Dash
    dashCharges = 1,         -- Quantidade de cargas de dash
    dashCooldown = 8.0,      -- Tempo em segundos para recuperar uma carga
    dashDistance = 5.5,      -- Distância em metros que o dash percorre
    dashDuration = 0.1,      -- Duração do dash em segundos
    -- Atributos de Poções
    potionFlasks = 2,        -- Quantidade de frascos de poção
    potionHealAmount = 50,   -- Vida recuperada por frasco
    potionFillRate = 2.0,    -- Multiplicador da velocidade de preenchimento (1.0 = normal)
}

return HunterBaseStats
