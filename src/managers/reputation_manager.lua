local ReputationConfig = require("src.config.reputation_config")

---@class ReputationManager
---@field agencyManager AgencyManager
---@field itemDataManager ItemDataManager
local ReputationManager = {}
ReputationManager.__index = ReputationManager

--- Cria uma nova instância do ReputationManager.
---@param agencyManager AgencyManager
---@param itemDataManager ItemDataManager
---@return ReputationManager
function ReputationManager:new(agencyManager, itemDataManager)
    local instance = setmetatable({}, ReputationManager)
    instance.agencyManager = assert(agencyManager, "ReputationManager requer um AgencyManager.")
    instance.itemDataManager = assert(itemDataManager, "ReputationManager requer um ItemDataManager.")
    return instance
end

---@class ReputationManagerParams
---@field extractionSuccessful boolean|nil Se a extração foi bem-sucedida (compatibilidade).
---@field wasSuccess boolean|nil Se a extração foi bem-sucedida (novo formato).
---@field portalData table Dados do portal (ex: { id = "...", rank = "C" }).
---@field hunterData table Dados do caçador (ex: { id = "...", finalRankId = "B" }).
---@field lootedItems table<ItemInstance> | nil Lista de itens adquiridos na incursão.

--- Calcula e aplica a mudança de reputação após uma incursão em portal.
--- Além de aplicar, retorna os detalhes do cálculo para UI.
---@param params ReputationManagerParams
---@return table reputationDetails Contém o detalhamento dos pontos ganhos/perdidos.
function ReputationManager:processIncursionResult(params)
    assert(params.portalData and params.portalData.rank, "Dados do portal ou rank do portal ausente.")
    assert(params.hunterData and params.hunterData.finalRankId, "Dados do caçador ou rank do caçador ausente.")

    -- Suporte para ambos os nomes de parâmetros (extractionSuccessful e wasSuccess)
    local extractionSuccessful = params.extractionSuccessful
    if extractionSuccessful == nil then
        extractionSuccessful = params.wasSuccess
    end

    print(string.format(
        "[ReputationManager] Processando incursão: Portal %s (rank %s), Hunter %s (rank %s), Sucesso: %s",
        params.portalData.name or "Desconhecido",
        params.portalData.rank,
        params.hunterData.name or "Desconhecido",
        params.hunterData.finalRankId,
        tostring(extractionSuccessful)
    ))

    local basePoints = ReputationConfig.basePointsForSuccess[params.portalData.rank] or 0
    if basePoints == 0 then
        print(string.format(
            "AVISO [ReputationManager]: Nenhum ponto base de sucesso configurado para o rank de portal '%s'.",
            params.portalData.rank))
    end

    local reputationChange = 0
    local reputationDetails = {
        basePoints = 0,
        rankBonusMultiplier = 1,
        rankBonusPoints = 0,
        lootPoints = 0,
        penaltyMultiplier = 0,
        totalChange = 0,
        wasSuccess = extractionSuccessful
    }

    if extractionSuccessful then
        -- SUCESSO NA EXTRAÇÃO
        local rankBonusMultiplier = self:_getRankDifferenceBonus(params.hunterData.finalRankId, params.portalData.rank)
        local lootPoints = self:_calculateLootPoints(params.lootedItems)
        local rankBonusPoints = basePoints * (rankBonusMultiplier - 1)

        reputationChange = basePoints + rankBonusPoints + lootPoints

        reputationDetails.basePoints = basePoints
        reputationDetails.rankBonusMultiplier = rankBonusMultiplier
        reputationDetails.rankBonusPoints = rankBonusPoints
        reputationDetails.lootPoints = lootPoints
        reputationDetails.totalChange = reputationChange

        print(string.format(
            "[ReputationManager] Sucesso! Reputação: (Base %d + Bônus Rank %.2fx) + Loot %d = %d",
            basePoints, rankBonusMultiplier, lootPoints, reputationChange
        ))
    else
        -- MORTE / FALHA NA EXTRAÇÃO
        reputationChange = -(basePoints * ReputationConfig.deathPenaltyMultiplier)

        reputationDetails.basePoints = basePoints -- Base para o cálculo da penalidade
        reputationDetails.penaltyMultiplier = ReputationConfig.deathPenaltyMultiplier
        reputationDetails.totalChange = reputationChange

        print(string.format(
            "[ReputationManager] Falha. Reputação: -(Base %d * Penalidade %.2fx) = %d",
            basePoints, ReputationConfig.deathPenaltyMultiplier, reputationChange
        ))
    end

    if reputationChange ~= 0 then
        self.agencyManager:addReputation(reputationChange)
        print(string.format("[ReputationManager] Reputação da Agência alterada em %d. Novo total: %d",
            math.floor(reputationChange), self.agencyManager:getReputation()))
    end

    return reputationDetails
end

--- Calcula o bônus de reputação com base na diferença de rank.
---@param hunterRank string O rank do caçador.
---@param portalRank string O rank do portal.
---@return number O multiplicador de bônus.
function ReputationManager:_getRankDifferenceBonus(hunterRank, portalRank)
    local hunterRankIndex = ReputationConfig.getRankIndex(hunterRank)
    local portalRankIndex = ReputationConfig.getRankIndex(portalRank)

    if not hunterRankIndex or not portalRankIndex then
        print(string.format(
            "AVISO [ReputationManager]: Rank inválido para caçador ('%s') ou portal ('%s'). Bônus será 1x.",
            hunterRank, portalRank
        ))
        return 1
    end

    local difference = hunterRankIndex - portalRankIndex
    -- Garante que a diferença esteja dentro dos limites definidos em config (-3 a 3)
    difference = math.max(-3, math.min(3, difference))

    return ReputationConfig.rankDifferenceBonus[difference] or 1
end

--- Calcula os pontos de reputação ganhos com base nos itens saqueados.
---@param lootedItems table<BaseItem> | nil
---@return number O total de pontos de reputação dos itens.
function ReputationManager:_calculateLootPoints(lootedItems)
    if not lootedItems or #lootedItems == 0 then
        return 0
    end

    local totalLootValue = 0
    for _, itemInstance in ipairs(lootedItems) do
        local itemData = self.itemDataManager:getBaseItemData(itemInstance.itemBaseId)
        if itemData and itemData.value then
            totalLootValue = totalLootValue + (itemData.value * itemInstance.quantity)
        end
    end

    return totalLootValue * ReputationConfig.lootToReputationRatio
end

return ReputationManager
