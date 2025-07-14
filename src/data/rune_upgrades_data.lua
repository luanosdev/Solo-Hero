---------------------------------------------------------------------------------
-- Rune Upgrades Data
-- Sistema de melhorias para runas equipadas
-- Cada runa tem melhorias específicas que só afetam seus próprios atributos
-- Melhorias são limitadas por número de usos e removidas quando a runa atinge nível máximo
---------------------------------------------------------------------------------

local Colors = require("src.ui.colors")

---@class RuneUpgradeEffect
---@field type string Tipo do efeito (damage, cooldown, radius, etc.)
---@field value number Valor do efeito
---@field is_percentage boolean Se é modificação percentual ou absoluta

---@class RuneUpgrade
---@field id string ID único da melhoria
---@field name string Nome da melhoria
---@field description string Descrição da melhoria
---@field image_path string Caminho para o ícone
---@field max_uses number Número máximo de vezes que pode ser escolhida
---@field rune_id string ID da runa que esta melhoria afeta
---@field is_ultra boolean Se é uma ultra melhoria (múltiplos de 5)
---@field required_level number Nível mínimo da runa para aparecer
---@field effects RuneUpgradeEffect[] Lista de efeitos
---@field color table Cor da melhoria

---@class RuneUpgradesData
---@field Upgrades RuneUpgrade[]
---@field GetUpgradesByRuneId fun(runeId: string): RuneUpgrade[]
---@field GetAvailableUpgrades fun(runeId: string, currentLevel: number, usedUpgrades: table): RuneUpgrade[]
---@field ApplyRuneUpgrade fun(runeInstance: table, upgradeId: string)
---@field GetMaxLevelByRarity fun(rarity: string): number
local RuneUpgradesData = {}

-- Cores para diferentes tipos de melhorias
local UPGRADE_COLORS = {
    normal = Colors.attribute_colors.damage,
    ultra = Colors.rankDetails.S.text
}

-- Ícones temporários
local tempIconPath = "assets/images/skills/55.png"

-- Função para calcular nível máximo baseado na raridade
function RuneUpgradesData.GetMaxLevelByRarity(rarity)
    local rarityToMaxLevel = {
        E = 5,
        D = 10,
        C = 15,
        B = 20,
        A = 25,
        S = 30
    }
    return rarityToMaxLevel[rarity] or 5
end

-- Todas as melhorias de runas organizadas por runa
RuneUpgradesData.Upgrades = {
    ---------------------------------------------------------------------------------
    -- RUNA ORBITAL (rune_orbital)
    ---------------------------------------------------------------------------------

    -- Melhoria de Dano
    rune_orbital_damage_boost = {
        id = "rune_orbital_damage_boost",
        name = "Energia Concentrada",
        description = "As esferas orbitais causam |25%| mais dano.",
        image_path = tempIconPath,
        max_uses = 3,
        rune_id = "rune_orbital",
        is_ultra = false,
        required_level = 1,
        effects = {
            { type = "damage", value = 25, is_percentage = true }
        },
        color = UPGRADE_COLORS.normal
    },

    -- Melhoria de Velocidade de Rotação
    rune_orbital_rotation_speed = {
        id = "rune_orbital_rotation_speed",
        name = "Rotação Acelerada",
        description = "As esferas orbitais giram |20%| mais rápido.",
        image_path = tempIconPath,
        max_uses = 3,
        rune_id = "rune_orbital",
        is_ultra = false,
        required_level = 1,
        effects = {
            { type = "rotation_speed", value = 20, is_percentage = true }
        },
        color = UPGRADE_COLORS.normal
    },

    -- Melhoria de Raio de Órbita
    rune_orbital_orbit_radius = {
        id = "rune_orbital_orbit_radius",
        name = "Órbita Expandida",
        description = "As esferas orbitam |15%| mais longe do herói.",
        image_path = tempIconPath,
        max_uses = 3,
        rune_id = "rune_orbital",
        is_ultra = false,
        required_level = 2,
        effects = {
            { type = "orbit_radius", value = 15, is_percentage = true }
        },
        color = UPGRADE_COLORS.normal
    },

    -- Melhoria de Tamanho das Esferas
    rune_orbital_orb_size = {
        id = "rune_orbital_orb_size",
        name = "Esferas Ampliadas",
        description = "As esferas orbitais ficam |10%| maiores.",
        image_path = tempIconPath,
        max_uses = 3,
        rune_id = "rune_orbital",
        is_ultra = false,
        required_level = 2,
        effects = {
            { type = "orb_size", value = 10, is_percentage = true }
        },
        color = UPGRADE_COLORS.normal
    },

    -- Ultra Melhoria - Orbe Extra
    rune_orbital_ultra_constellation = {
        id = "rune_orbital_ultra_constellation",
        name = "Constelação Orbital",
        description = "Adiciona |+1| esfera orbital, mas cada esfera causa |15%| menos dano.",
        image_path = tempIconPath,
        max_uses = 1,
        rune_id = "rune_orbital",
        is_ultra = true,
        required_level = 5,
        effects = {
            { type = "extra_orb", value = 1,   is_percentage = false },
            { type = "damage",    value = -15, is_percentage = true }
        },
        color = UPGRADE_COLORS.ultra
    },

    ---------------------------------------------------------------------------------
    -- RUNA DE TROVÃO (rune_thunder)
    ---------------------------------------------------------------------------------

    -- Melhoria de Dano
    rune_thunder_damage_boost = {
        id = "rune_thunder_damage_boost",
        name = "Tempestade Furiosa",
        description = "Os raios causam |30%| mais dano.",
        image_path = tempIconPath,
        max_uses = 3,
        rune_id = "rune_thunder",
        is_ultra = false,
        required_level = 1,
        effects = {
            { type = "damage", value = 30, is_percentage = true }
        },
        color = UPGRADE_COLORS.normal
    },

    -- Melhoria de Frequência
    rune_thunder_frequency = {
        id = "rune_thunder_frequency",
        name = "Descarga Rápida",
        description = "Os raios são disparados |20%| mais frequentemente.",
        image_path = tempIconPath,
        max_uses = 3,
        rune_id = "rune_thunder",
        is_ultra = false,
        required_level = 1,
        effects = {
            { type = "cooldown", value = -20, is_percentage = true }
        },
        color = UPGRADE_COLORS.normal
    },

    -- Melhoria de Alcance
    rune_thunder_range = {
        id = "rune_thunder_range",
        name = "Alcance Estendido",
        description = "Os raios podem atingir inimigos |25%| mais distantes.",
        image_path = tempIconPath,
        max_uses = 3,
        rune_id = "rune_thunder",
        is_ultra = false,
        required_level = 2,
        effects = {
            { type = "range", value = 25, is_percentage = true }
        },
        color = UPGRADE_COLORS.normal
    },

    -- Ultra Melhoria - Tempestade Devastadora
    rune_thunder_ultra_storm = {
        id = "rune_thunder_ultra_storm",
        name = "Tempestade Devastadora",
        description = "Os raios causam |100%| mais dano, mas são disparados |50%| mais lentamente.",
        image_path = tempIconPath,
        max_uses = 1,
        rune_id = "rune_thunder",
        is_ultra = true,
        required_level = 5,
        effects = {
            { type = "damage",   value = 100, is_percentage = true },
            { type = "cooldown", value = 50,  is_percentage = true }
        },
        color = UPGRADE_COLORS.ultra
    },

    ---------------------------------------------------------------------------------
    -- RUNA DE AURA (rune_aura)
    ---------------------------------------------------------------------------------

    -- Melhoria de Dano
    rune_aura_damage_boost = {
        id = "rune_aura_damage_boost",
        name = "Aura Tóxica",
        description = "A aura causa |25%| mais dano por tick.",
        image_path = tempIconPath,
        max_uses = 3,
        rune_id = "rune_aura",
        is_ultra = false,
        required_level = 1,
        effects = {
            { type = "damage_per_tick", value = 25, is_percentage = true }
        },
        color = UPGRADE_COLORS.normal
    },

    -- Melhoria de Frequência
    rune_aura_frequency = {
        id = "rune_aura_frequency",
        name = "Pulso Acelerado",
        description = "A aura pulsa |20%| mais frequentemente.",
        image_path = tempIconPath,
        max_uses = 3,
        rune_id = "rune_aura",
        is_ultra = false,
        required_level = 1,
        effects = {
            { type = "cooldown", value = -20, is_percentage = true }
        },
        color = UPGRADE_COLORS.normal
    },

    -- Melhoria de Alcance
    rune_aura_range = {
        id = "rune_aura_range",
        name = "Aura Expandida",
        description = "A aura tem |20%| mais alcance.",
        image_path = tempIconPath,
        max_uses = 3,
        rune_id = "rune_aura",
        is_ultra = false,
        required_level = 2,
        effects = {
            { type = "radius", value = 20, is_percentage = true }
        },
        color = UPGRADE_COLORS.normal
    },

    -- Ultra Melhoria - Aura Devastadora
    rune_aura_ultra_lethal = {
        id = "rune_aura_ultra_lethal",
        name = "Aura Devastadora",
        description = "A aura causa |80%| mais dano, mas tem |30%| menos alcance.",
        image_path = tempIconPath,
        max_uses = 1,
        rune_id = "rune_aura",
        is_ultra = true,
        required_level = 5,
        effects = {
            { type = "damage_per_tick", value = 80,  is_percentage = true },
            { type = "radius",          value = -30, is_percentage = true }
        },
        color = UPGRADE_COLORS.ultra
    },
}

-- Função para obter melhorias por ID da runa
function RuneUpgradesData.GetUpgradesByRuneId(runeId)
    local upgrades = {}
    for _, upgrade in pairs(RuneUpgradesData.Upgrades) do
        if upgrade.rune_id == runeId then
            table.insert(upgrades, upgrade)
        end
    end
    return upgrades
end

-- Função para obter melhorias disponíveis baseado no nível atual e uso
function RuneUpgradesData.GetAvailableUpgrades(runeId, currentLevel, usedUpgrades)
    local availableUpgrades = {}
    local upgradesForRune = RuneUpgradesData.GetUpgradesByRuneId(runeId)

    for _, upgrade in pairs(upgradesForRune) do
        local timesUsed = usedUpgrades[upgrade.id] or 0
        local canUse = timesUsed < upgrade.max_uses
        local levelRequirement = currentLevel >= upgrade.required_level

        -- Regras para ultra vs normais
        local ultraRequirement
        if upgrade.is_ultra then
            -- Ultras só podem aparecer em níveis múltiplos de 5 (e não no nível 0)
            ultraRequirement = (currentLevel > 0 and currentLevel % 5 == 0)
        else
            -- Melhorias normais não podem aparecer em níveis de ultra
            ultraRequirement = (currentLevel % 5 ~= 0 or currentLevel == 0)
        end

        if canUse and levelRequirement and ultraRequirement then
            table.insert(availableUpgrades, upgrade)
        end
    end

    return availableUpgrades
end

-- Função para aplicar melhoria de runa
function RuneUpgradesData.ApplyRuneUpgrade(runeInstance, upgradeId)
    local upgrade = RuneUpgradesData.Upgrades[upgradeId]
    if not upgrade then
        error("ERRO [RuneUpgradesData.ApplyRuneUpgrade]: Melhoria com ID '" .. tostring(upgradeId) .. "' não encontrada.")
    end

    if not runeInstance then
        error("ERRO [RuneUpgradesData.ApplyRuneUpgrade]: Instância de runa inválida.")
    end

    if upgrade.is_ultra then
        Logger.info(
            "rune_upgrades_data.apply_upgrade.ultra",
            "[RuneUpgradesData.ApplyRuneUpgrade] ✦ APLICANDO ULTRA MELHORIA: " .. upgrade.name .. " ✦"
        )
    else
        Logger.info(
            "rune_upgrades_data.apply_upgrade.normal",
            "[RuneUpgradesData.ApplyRuneUpgrade] Aplicando melhoria de runa: " .. upgrade.name
        )
    end

    -- Aplica os efeitos através do sistema de upgrades das runas
    if runeInstance.applyUpgrade then
        runeInstance:applyUpgrade(upgrade, 1)
    else
        Logger.warn(
            "rune_upgrades_data.apply_upgrade.no_method",
            "[RuneUpgradesData.ApplyRuneUpgrade] Instância de runa não possui método applyUpgrade"
        )
    end
end

return RuneUpgradesData
