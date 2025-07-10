--- Função auxiliar para adicionar métodos de localização às armas
---@param teleportStoneData table A definição da pedra de teleporte
---@return table teleportStoneData A pedra de teleporte com métodos de localização adicionados
local function addLocalizationMethods(teleportStoneData)
    --- Obtém o nome localizado da pedra de teleporte
    ---@return string localizedName
    function teleportStoneData:getLocalizedName()
        return _T("teleport_stones." .. self.id .. ".name")
    end

    --- Obtém a descrição localizada da pedra de teleporte
    ---@return string localizedDescription
    function teleportStoneData:getLocalizedDescription()
        return _T("teleport_stones." .. self.id .. ".description")
    end

    return teleportStoneData
end

local teleport_stones = {
    teleport_stone_d = {
        name = "Pedra de Teleporte (D)",
        type = "consumable",
        description = "Te teleporta em menos de 1 segundo. Apenas equipamentos são levados, util para saidas de emergência.",
        icon = "assets/items/teleport_stones/teleport_stone_d.png", -- Exemplo de caminho
        stackable = true,
        maxStack = 5,
        gridWidth = 1,
        gridHeight = 1,
        rarity = "D",
        useDetails = {
            castTime = 0.75, -- Muito rápida
            extractionType = "equipment_only",
            consumesOnUse = true,
        },
        value = 500,
    },
    teleport_stone_b = {
        name = "Pedra de Teleporte (B)",
        type = "consumable",
        description = "Te teleporta em menos de 4 segundos. Uma seleção aleatória de seus items coletados é perdida.",
        icon = "assets/items/teleport_stones/teleport_stone_b.png", -- Exemplo de caminho
        stackable = true,
        maxStack = 5,
        gridWidth = 1,
        gridHeight = 1,
        rarity = "B",
        useDetails = {
            castTime = 3.5, -- Média
            extractionType = "random_backpack_items",
            consumesOnUse = true,
            -- Para random_equipment, podemos adicionar um detalhe de quantos itens ou qual chance por item
            extractionRandomParams = {
                percentageToKeep = 50 -- Ex: 50% dos itens equipados, arredondado para cima, mínimo 1
            }
        },
        value = 1000,
    },
    teleport_stone_a = {
        name = "Pedra de Teleporte (A)",
        type = "consumable",
        description = "Te teleporta em menos de 7 segundos. Leva todos os equipamentos e itens da mochila.",
        icon = "assets/items/teleport_stones/teleport_stone_a.png", -- Exemplo de caminho
        stackable = true,
        maxStack = 5,
        gridWidth = 1,
        gridHeight = 1,
        rarity = "A",
        useDetails = {
            castTime = 7.0, -- Bem demorada
            extractionType = "all_items",
            consumesOnUse = true,
        },
        value = 5000,
    },
    teleport_stone_s = {
        name = "Pedra de Teleporte (S)",
        type = "consumable",
        description = "Te teleporta instantaneamente. Leva todos os equipamentos e itens da mochila.",
        icon = "assets/items/teleport_stones/teleport_stone_s.png", -- Exemplo de caminho
        stackable = true,
        maxStack = 5,
        gridWidth = 1,
        gridHeight = 1,
        rarity = "S",
        useDetails = {
            castTime = 0.0,                       -- Instantânea
            extractionType = "all_items_instant", -- Mesmo resultado que "all_items", mas o castTime define a velocidade
            consumesOnUse = true,
        },
        value = 10000,
    },
}

-- Aplica métodos de localização a todas as pedras de teleporte
for _, teleportStoneData in pairs(teleport_stones) do
    addLocalizationMethods(teleportStoneData)
end

return teleport_stones
