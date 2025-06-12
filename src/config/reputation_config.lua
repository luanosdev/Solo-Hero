-- src/config/reputation_config.lua

local ReputationConfig = {
    -- Pontos de reputação necessários para alcançar cada ranking de agência.
    rankThresholds = {
        E = 0,
        D = 1000,
        C = 5000,
        B = 15000,
        A = 40000,
        S = 100000,
    },

    -- Pontos base ganhos ao completar um portal com sucesso, por rank do portal.
    basePointsForSuccess = {
        E = 50,
        D = 100,
        C = 200,
        B = 400,
        A = 800,
        S = 1600,
        SS = 3200,
    },

    -- Fator de multiplicação da penalidade por morte.
    -- Ex: Morte em portal Rank E -> 50 * 0.4 = 20 pontos perdidos.
    deathPenaltyMultiplier = 0.4,

    -- Bônus/Penalidade baseado na diferença de rank entre o Caçador e o Portal.
    -- A chave é a diferença (hunterRankIndex - portalRankIndex).
    rankDifferenceBonus = {
        -- Caçador tem rank MUITO maior que o portal (fácil demais)
        [3] = 0.5,  -- -50% de bônus (penalidade)
        [2] = 0.7,  -- -30% de bônus (penalidade)
        -- Caçador tem rank maior que o portal (fácil)
        [1] = 0.9,  -- -10% de bônus (penalidade)
        -- Caçador e portal tem o mesmo rank (desafio ideal)
        [0] = 1.2,  -- +20% de bônus
        -- Caçador tem rank menor que o portal (desafiador)
        [-1] = 1.5, -- +50% de bônus
        -- Caçador tem rank MUITO menor (muito desafiador)
        [-2] = 2.0, -- +100% de bônus (dobro de pontos)
        [-3] = 2.5, -- +150% de bônus
        -- Mais do que isso é considerado o mesmo que -3
    },

    -- Como o valor de venda de um item se converte em pontos de reputação.
    -- Ex: Item vale 100 gold, lootToReputationRatio = 0.5 -> 50 pontos de reputação.
    lootToReputationRatio = 0.5,

    -- Mapeamento interno para calcular a diferença de ranks.
    rankOrder = { "E", "D", "C", "B", "A", "S", "SS" },
}

--- Retorna o índice numérico de um rank.
---@param rankLetter string "E", "D", "C", etc.
---@return number | nil O índice do rank ou nil se não encontrado.
function ReputationConfig.getRankIndex(rankLetter)
    for i, rank in ipairs(ReputationConfig.rankOrder) do
        if rank == rankLetter then
            return i
        end
    end
    return nil
end

return ReputationConfig
