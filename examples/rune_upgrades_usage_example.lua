-- Exemplo de uso do sistema de melhorias de runas
-- Este arquivo demonstra como usar o sistema de melhorias de runas

local RuneUpgradesData = require("src.data.rune_upgrades_data")

-- Exemplo 1: Obter nível máximo por raridade
print("=== Exemplo 1: Níveis máximos por raridade ===")
local rarities = { "E", "D", "C", "B", "A", "S" }
for _, rarity in ipairs(rarities) do
    local maxLevel = RuneUpgradesData.GetMaxLevelByRarity(rarity)
    print(string.format("Rank %s: %d níveis máximos", rarity, maxLevel))
end

-- Exemplo 2: Obter melhorias para uma runa específica
print("\n=== Exemplo 2: Melhorias para Runa Orbital ===")
local orbitalUpgrades = RuneUpgradesData.GetUpgradesByRuneId("rune_orbital_e")
for _, upgrade in ipairs(orbitalUpgrades) do
    local upgradeType = upgrade.is_ultra and "ULTRA" or "NORMAL"
    print(string.format("[%s] %s - %s (Max: %d usos)",
        upgradeType, upgrade.name, upgrade.description, upgrade.max_uses))
end

-- Exemplo 3: Verificar melhorias disponíveis baseado no nível
print("\n=== Exemplo 3: Melhorias disponíveis por nível ===")
local runeId = "rune_orbital_e"
local usedUpgrades = {} -- Simula que nenhuma melhoria foi usada ainda

-- Testa diferentes níveis
for level = 1, 10 do
    local availableUpgrades = RuneUpgradesData.GetAvailableUpgrades(runeId, level, usedUpgrades)
    print(string.format("Nível %d: %d melhorias disponíveis", level, #availableUpgrades))

    for _, upgrade in ipairs(availableUpgrades) do
        local upgradeType = upgrade.is_ultra and "ULTRA" or "NORMAL"
        print(string.format("  - [%s] %s", upgradeType, upgrade.name))
    end
end

-- Exemplo 4: Simular aplicação de melhorias
print("\n=== Exemplo 4: Simulação de aplicação de melhorias ===")

-- Simula uma instância de runa orbital
local runeInstance = {
    damage = 150,
    orbitRadius = 90,
    orbCount = 3,
    orbRadius = 20,
    rotationSpeed = 2
}

print("Estado inicial da runa:")
for attr, value in pairs(runeInstance) do
    print(string.format("  %s: %s", attr, tostring(value)))
end

-- Aplica melhoria de dano
local damageUpgradeId = "rune_orbital_e_damage_boost"
print(string.format("\nAplicando melhoria: %s", damageUpgradeId))
RuneUpgradesData.ApplyRuneUpgrade(runeInstance, damageUpgradeId)

print("Estado após aplicar melhoria de dano:")
for attr, value in pairs(runeInstance) do
    print(string.format("  %s: %s", attr, tostring(value)))
end

-- Aplica melhoria de velocidade de rotação
local speedUpgradeId = "rune_orbital_e_rotation_speed"
print(string.format("\nAplicando melhoria: %s", speedUpgradeId))
RuneUpgradesData.ApplyRuneUpgrade(runeInstance, speedUpgradeId)

print("Estado após aplicar melhoria de velocidade:")
for attr, value in pairs(runeInstance) do
    print(string.format("  %s: %s", attr, tostring(value)))
end

-- Exemplo 5: Demonstrar ultra melhorias
print("\n=== Exemplo 5: Ultra melhorias ===")
local ultraUpgradeId = "rune_orbital_e_ultra_extra_orb"
local ultraUpgrade = RuneUpgradesData.Upgrades[ultraUpgradeId]

if ultraUpgrade then
    print(string.format("Ultra melhoria: %s", ultraUpgrade.name))
    print(string.format("Descrição: %s", ultraUpgrade.description))
    print(string.format("Requer nível: %d", ultraUpgrade.required_level))

    print("Modificadores:")
    for _, modifier in ipairs(ultraUpgrade.modifiers) do
        local sign = modifier.value > 0 and "+" or ""
        local suffix = modifier.type == "percentage" and "%" or ""
        print(string.format("  %s: %s%s%s",
            modifier.attribute, sign, tostring(modifier.value), suffix))
    end
end

-- Exemplo 6: Demonstrar sistema de limitação de uso
print("\n=== Exemplo 6: Sistema de limitação de uso ===")
local upgradeId = "rune_orbital_e_damage_boost"
local upgrade = RuneUpgradesData.Upgrades[upgradeId]

if upgrade then
    print(string.format("Melhoria: %s (Máximo %d usos)", upgrade.name, upgrade.max_uses))

    -- Simula usar a melhoria várias vezes
    local usedCount = {}
    for i = 1, upgrade.max_uses + 2 do -- Tenta usar mais que o máximo
        local currentUses = usedCount[upgradeId] or 0

        if currentUses < upgrade.max_uses then
            print(string.format("  Uso %d/%d: Sucesso", currentUses + 1, upgrade.max_uses))
            usedCount[upgradeId] = currentUses + 1
        else
            print(string.format("  Uso %d/%d: Falha - Máximo atingido", i, upgrade.max_uses))
        end
    end
end

print("\n=== Exemplo concluído ===")
