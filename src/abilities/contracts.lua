--[[
    Contracts
    Define os contratos que as habilidades devem seguir
]]

local Contracts = {}

-- Contrato base que todas as habilidades devem seguir
Contracts.Ability = {
    -- Propriedades obrigatórias
    name = "string",
    description = "string",
    damage = "number",
    damageType = "string",
    cooldown = "number",
    
    -- Métodos obrigatórios
    init = "function", -- function(playerManager)
    update = "function", -- function(dt, enemies)
    draw = "function", -- function()
    cast = "function", -- function() -> boolean
    applyDamage = "function", -- function(target) -> boolean
}

-- Função para verificar se uma habilidade segue um contrato
function Contracts.verify(ability, contract)
    for key, expectedType in pairs(contract) do
        if type(ability[key]) ~= expectedType then
            return false, string.format("Propriedade '%s' deve ser do tipo '%s'", key, expectedType)
        end
    end
    return true
end

return Contracts 