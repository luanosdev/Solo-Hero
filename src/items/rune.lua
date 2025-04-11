--[[
    Rune
    Item que pode ser obtido ao derrotar um boss e que concede novas habilidades ao jogador
]]

local Rune = {
    name = "Runa Base",
    description = "Uma runa mágica que concede poderes ao portador",
    rarity = "common", -- common, rare, epic, legendary
    abilities = {} -- Lista de habilidades que podem ser obtidas
}

function Rune:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

--[[
    Gera uma runa aleatória baseada na raridade
    @param rarity Raridade da runa (opcional)
    @return Rune Uma nova runa
]]
function Rune:generateRandom(rarity)
    rarity = rarity or self:rollRarity()
    
    local rune = Rune:new({
        rarity = rarity,
        abilities = self:getRandomAbilities(rarity)
    })

    return rune
end

--[[
    Rola a raridade da runa
    @return string Raridade da runa
]]
function Rune:rollRarity()
    local roll = math.random()
    if roll < 0.5 then
        return "common"
    elseif roll < 0.8 then
        return "rare"
    elseif roll < 0.95 then
        return "epic"
    else
        return "legendary"
    end
end

--[[
    Obtém habilidades aleatórias baseadas na raridade
    @param rarity Raridade da runa
    @return table Lista de habilidades
]]
function Rune:getRandomAbilities(rarity)
    local abilities = {}
    local count = 1
    
    -- Define quantas habilidades a runa terá baseado na raridade
    if rarity == "common" then
        count = 1
    elseif rarity == "rare" then
        count = 2
    elseif rarity == "epic" then
        count = 3
    else -- legendary
        count = 4
    end
    
    -- Lista de todas as habilidades disponíveis
    local availableAbilities = {
        require("src.runes.aura"),
        require("src.runes.orbital"),
        -- Adicione mais habilidades aqui conforme forem criadas
    }
    
    -- Seleciona habilidades aleatórias
    for i = 1, count do
        if #availableAbilities > 0 then
            local index = math.random(1, #availableAbilities)
            table.insert(abilities, availableAbilities[index])
            table.remove(availableAbilities, index)
        end
    end
    
    return abilities
end

--[[
    Aplica as habilidades da runa ao jogador
    @param player O jogador que receberá as habilidades
]]
function Rune:applyToPlayer(player)
    for _, abilityClass in ipairs(self.abilities) do
        local ability = setmetatable({}, { __index = abilityClass })
        ability:init(player)
        player:addAbility(ability)
    end
end

return Rune 