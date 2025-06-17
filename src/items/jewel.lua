-- src/items/jewel.lua
local BaseItem = require("src.entities.equipments.base_item")

local Jewel = setmetatable({}, {__index = BaseItem })
Jewel.__index = Jewel -- Garante que métodos sejam encontrados na própria tabela

-- Mapa de Ranks
local RANKS = {"E", "D", "C", "B", "A", "S", "SS"}
local RANK_INDEX = {}
for i, r in ipairs(RANKS) do RANK_INDEX[r] = i end

-- Mapeamento Rank -> Stack Size
local RANK_STACK_SIZES = {
    E = 999, D = 500, C = 250, B = 100, A = 50, S = 10, SS = 1
}

-- Mapeamento Rank -> Cor (Valores RGB 0-1) e Nome da Cor
local RANK_DETAILS = {
    E = { color = {0.5, 0.5, 0.5}, name = "Quartzo", prefix = "Fragmento de"}, -- Cinza
    D = { color = {0, 1, 0},       name = "Jade", prefix = "Gema Bruta de"},    -- Verde
    C = { color = {0, 0, 1},       name = "Safira", prefix = "Gema de"},        -- Azul
    B = { color = {1, 0, 1},       name = "Ametista", prefix = "Gema Polida de"}, -- Magenta
    A = { color = {1, 1, 0},       name = "Topázio", prefix = "Joia de"},       -- Amarelo
    S = { color = {1, 0.5, 0},     name = "Âmbar", prefix = "Joia Radiante de"}, -- Laranja
    SS = { color = {1, 0, 0},      name = "Rubi", prefix = "Joia Perfeita de"}   -- Vermelho
}

function Jewel:new(rank)
    rank = rank or "E" -- Rank padrão E se não especificado
    local details = RANK_DETAILS[rank] or RANK_DETAILS["E"] -- Fallback para E

    -- Monta a tabela de configuração para BaseItem:new
    local config = {
        type = "jewel", -- Tipo específico do item
        name = string.format("[%s] %s %s", rank, details.prefix, details.name),
        rank = rank,
        color = details.color,
        maxStack = RANK_STACK_SIZES[rank] or 999,
        radius = 5, -- Atributos específicos da joia
        icon = "gem"
    }

    -- Chama BaseItem:new passando a tabela de configuração
    local instance = BaseItem:new(config)

    --[[ O metatable já é definido corretamente por BaseItem:new,
         mas redefinir para Jewel garante que métodos específicos de Jewel
         tenham precedência se houver conflito com BaseItem (improvável com __index)
    ]]
    setmetatable(instance, Jewel)

    return instance
end

-- Função para obter o próximo rank
function Jewel.getNextRank(currentRank, levelsUp)
    levelsUp = levelsUp or 1
    local currentIndex = RANK_INDEX[currentRank]
    if not currentIndex then return currentRank end

    local nextIndex = math.min(currentIndex + levelsUp, #RANKS)
    return RANKS[nextIndex]
end

-- Função para obter detalhes (cor, nome) de um rank
function Jewel.getRankDetails(rank)
    return RANK_DETAILS[rank] or RANK_DETAILS["E"]
end


return Jewel 