--[[
    Rune
    Item que pode ser obtido ao derrotar um boss e que concede novas habilidades ao jogador
]]

local BaseItem = require("src.items.base_item")

local Rune = setmetatable({}, {__index = BaseItem })
Rune.__index = Rune

-- Mapeamento de Raridade para Nome/Descrição (Exemplo)
local RARITY_DETAILS = {
    E = { name_suffix = "Comum", description = "Uma runa básica com potencial oculto." },
    D = { name_suffix = "Incomum", description = "Uma runa com um leve brilho mágico." },
    C = { name_suffix = "Rara", description = "Uma runa que emana um poder notável." },
    B = { name_suffix = "Épica", description = "Uma runa imbuída de forte energia arcana." },
    A = { name_suffix = "Lendária", description = "Uma runa forjada com magia ancestral." },
    S = { name_suffix = "Mítica", description = "Uma runa cujo poder rivaliza com os deuses." },
    SS = { name_suffix = "Divina", description = "Uma runa de poder transcendental." },
    SSS = { name_suffix = " Suprema", description = "Uma runa que transcende a própria realidade." }
}

-- A função 'new' agora é primariamente tratada por BaseItem,
-- mas podemos manter uma aqui para inicializações específicas de Rune se necessário no futuro.
-- Por ora, generateRandom será o construtor principal.
-- function Rune:new(config)
--     local instance = BaseItem:new(config)
--     setmetatable(instance, Rune)
--     return instance
-- end

--[[
    Gera uma runa aleatória baseada na raridade
    @param rarity Raridade da runa (opcional)
    @return Rune Uma nova runa
]]
function Rune:generateRandom(rarity)
    rarity = rarity or self:rollRarity()
    local details = RARITY_DETAILS[rarity] or { name_suffix = "Desconhecida", description = "Uma runa de origem misteriosa."}
    local abilities = self:getRandomAbilities(rarity)

    -- Monta a tabela de configuração para BaseItem:new
    local config = {
        type = "rune",
        name = "Runa " .. details.name_suffix,
        description = details.description,
        rarity = rarity,
        abilities = abilities,
        icon = "rune_icon" -- Exemplo de ícone padrão para runas
        -- Runas provavelmente não são stackáveis
        -- maxStack = 1
    }

    -- Cria a instância usando BaseItem:new
    local instance = BaseItem:new(config)
    -- Garante que a metatable aponte para Rune para métodos específicos de Rune
    setmetatable(instance, Rune)

    return instance
end

--[[
    Rola a raridade da runa
    @return string Raridade da runa
]]
function Rune:rollRarity()
    local roll = math.random()
    if roll < 0.5 then
        return "E"
    elseif roll < 0.8 then
        return "D"
    elseif roll < 0.95 then
        return "C"
    elseif roll < 0.98 then
        return "B"
    elseif roll < 0.99 then
        return "A"
    elseif roll < 0.995 then
        return "S"
    elseif roll < 0.999 then
        return "SS"
    else
        return "SSS"
    end
end

--[[
    Obtém habilidades aleatórias baseadas na raridade
    @param rarity Raridade da runa
    @return table Lista de referências às classes de habilidade
]]
function Rune:getRandomAbilities(rarity)
    local abilities = {}
    local count = 1
    
    -- Define quantas habilidades a runa terá baseado na raridade
    if rarity == "E" then
        count = 2
    elseif rarity == "D" then
        count = 3
    elseif rarity == "C" then
        count = 4
    elseif rarity == "B" then
        count = 3
    elseif rarity == "A" then
        count = 3
    elseif rarity == "S" then
        count = 4
    elseif rarity == "SS" then
        count = 4
    elseif rarity == "SSS" then
        count = 5
    end
    
    -- Lista de todas as habilidades disponíveis (referências às classes)
    local availableAbilities = {
        require("src.runes.aura"),
        require("src.runes.orbital"),
        require("src.runes.thunder"),
        -- Adicione mais referências de classes de habilidade aqui
    }
    
    -- Seleciona classes de habilidades aleatórias
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
    Aplica as habilidades da runa ao jogador.
    Este método agora opera na *instância* da runa.
    @param player O jogador que receberá as habilidades
]]
function Rune:applyToPlayer(player)
    if not self.abilities or #self.abilities == 0 then
        print("Aviso: Tentando aplicar runa sem habilidades definida: ", self.name)
        return
    end
    print(string.format("Aplicando habilidades da %s (%d habilidades) ao jogador...", self.name, #self.abilities))
    for _, abilityClass in ipairs(self.abilities) do
        if type(abilityClass) == 'table' and abilityClass.init then -- Verifica se é uma classe válida
            print("- Aplicando habilidade: ", abilityClass.name or "NomeDesconhecido")
            -- Cria uma instância da habilidade
            -- Nota: Pode ser necessário ajustar como as habilidades são estruturadas/instanciadas.
            --       Assumindo que a classe tem um método 'new' ou que podemos setar a metatable.
            local abilityInstance = setmetatable({}, { __index = abilityClass })
            -- Idealmente, a classe de habilidade teria um :new() que recebe o jogador/config
            abilityInstance:init(player) -- Assumindo que init existe e recebe o jogador

            -- Adiciona a *instância* da habilidade ao jogador
            -- (Assumindo que player:addAbility espera uma instância)
            player:addAbility(abilityInstance)
        else
             print("Aviso: Item inválido na lista de habilidades da runa.")
        end
    end
end

return Rune 