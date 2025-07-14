-- Definições básicas para runas como itens

--- Função auxiliar para adicionar métodos de localização às armas
---@param runeData table A definição da runa
---@return table runeData A runa com métodos de localização adicionados
local function addLocalizationMethods(runeData)
    --- Obtém o nome localizado da runa
    ---@return string localizedName
    function runeData:getLocalizedName()
        return _T("runes." .. self.id .. ".name")
    end

    --- Obtém a descrição localizada da runa
    ---@return string localizedDescription
    function runeData:getLocalizedDescription()
        return _T("runes." .. self.id .. ".description")
    end

    return runeData
end

local runes = {
    -- Runa Orbital
    rune_orbital_e = {
        itemBaseId = "rune_orbital_e",
        runeFamilyId = "rune_orbital",
        type = "rune", -- Tipo específico para runas
        name = "Runa Orbital",
        description = "Invoca esferas de energia que orbitam o herói.",
        icon = "assets/runes/rune_orbital_e.png",     -- Ícone temporário
        rarity = 'E',
        color = { 0 / 255, 200 / 255, 255 / 255, 1 }, -- Ciano
        gridWidth = 1,
        gridHeight = 1,
        stackable = false,
        -- Atributos específicos da runa (podemos adicionar mais tarde)
        effect = "orbital",
        abilityClass = "src.entities.equipments.runes.orbital",
        num_projectiles = 3,
        damage = 150,
        orbitRadius = 90,
        orbCount = 3,
        orbRadius = 20,
        rotationSpeed = 2,
    },

    -- Runa de Trovão
    rune_thunder_e = {
        itemBaseId = "rune_thunder_e",
        runeFamilyId = "rune_thunder",
        type = "rune",
        name = "Runa do Trovão",
        description = "Invoca raios periodicamente em inimigos próximos.",
        icon = "assets/runes/rune_thunder_e.png",     -- Ícone temporário
        rarity = "E",
        color = { 255 / 255, 255 / 255, 0 / 255, 1 }, -- Amarelo
        gridWidth = 1,
        gridHeight = 1,
        stackable = false,
        effect = "thunder",
        abilityClass = "src.entities.equipments.runes.thunder",
        interval = 2.0,
        damage = 200,
        radius = 150
    },

    -- Runa de Aura
    rune_aura_e = {
        itemBaseId = "rune_aura_e",
        runeFamilyId = "rune_aura",
        type = "rune",
        name = "Runa de Aura",
        description = "Cria uma aura que causa dano contínuo a inimigos dentro dela.",
        icon = "assets/runes/rune_aura_e.png", -- Ícone temporário
        rarity = "E",
        color = { 0.8, 0, 0.8, 1 },
        gridWidth = 1,
        gridHeight = 1,
        stackable = false,
        effect = "aura",
        abilityClass = "src.entities.equipments.runes.aura",
        damage = 50,
        tick_interval = 1,
        radius = 100
    }
    -- Adicione outras runas aqui...
}

-- Aplica métodos de localização a todas as runas
for _, runeData in pairs(runes) do
    addLocalizationMethods(runeData)
end

return runes
