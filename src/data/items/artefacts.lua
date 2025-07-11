--- Função auxiliar para adicionar métodos de localização às armas
---@param artefactData table A definição do artefato
---@return table artefactData A artefato com métodos de localização adicionados
local function addLocalizationMethods(artefactData)
    --- Obtém o nome localizado da arma
    ---@return string localizedName
    function artefactData:getLocalizedName()
        return _T("artefacts." .. self.id .. ".name")
    end

    --- Obtém a descrição localizada da arma
    ---@return string localizedDescription
    function artefactData:getLocalizedDescription()
        return _T("artefacts." .. self.id .. ".description")
    end

    return artefactData
end

---@class ArtefactDefinition
---@field id string ID único do artefato
---@field icon string Caminho para o ícone
---@field rank "E"|"D"|"C"|"B"|"A"|"S" Raridade
---@field value number Valor de venda unitário

---@type table<string, ArtefactDefinition>
local artefacts = {
    empty_stone = {
        id = "empty_stone",
        icon = "assets/items/artefacts/empty_stone.png",
        rank = "E",
        value = 2,
    },

    crystal_fragment = {
        id = "crystal_fragment",
        icon = "assets/items/artefacts/crystal_fragment.png",
        rank = "E",
        value = 3,
    },

    putrefied_core = {
        id = "putrefied_core",
        icon = "assets/items/artefacts/putrefied_core.png",
        rank = "E",
        value = 5,
    },

    unstable_core = {
        id = "unstable_core",
        icon = "assets/items/artefacts/unstable_core.png",
        rank = "D",
        value = 50,
    },

    --- The Rotten Immortal
    eternal_decay_relic = {
        id = "eternal_decay_relic",
        icon = "assets/items/artefacts/eternal_decay_relic.png",
        rank = "C",
        value = 500,
    },
}

-- Aplica métodos de localização a todos os artefatos
for _, artefactData in pairs(artefacts) do
    addLocalizationMethods(artefactData)
end

return artefacts
