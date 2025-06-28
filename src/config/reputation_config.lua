---@class ReputationConfig
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
        E = 75,
        D = 150,
        C = 300,
        B = 600,
        A = 1200,
        S = 2400,
        SS = 4800,
    },

    -- Fator de multiplicação da penalidade por morte.
    -- Ex: Morte em portal Rank E -> 75 * 0.2 = 15 pontos perdidos.
    deathPenaltyMultiplier = 0.2,

    -- Bônus/Penalidade baseado na diferença de rank entre o Caçador e o Portal.
    -- A chave é a diferença (hunterRankIndex - portalRankIndex).
    rankDifferenceBonus = {
        -- Caçador tem rank MUITO maior que o portal (fácil demais)
        [3] = 0.3,
        [2] = 0.5,
        -- Caçador tem rank maior que o portal (fácil)
        [1] = 0.8,
        -- Caçador e portal tem o mesmo rank (desafio ideal)
        [0] = 1.0,
        -- Caçador tem rank menor que o portal (desafiador)
        [-1] = 1.3,
        -- Caçador tem rank MUITO menor (muito desafiador)
        [-2] = 1.6,
        [-3] = 2.0,
        -- Mais do que isso é considerado o mesmo que -3
    },

    -- Como o valor de venda de um item se converte em pontos de reputação.
    -- Ex: Item vale 100 gold, lootToReputationRatio = 0.1 -> 10 pontos de reputação.
    lootToReputationRatio = 0.1,

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
