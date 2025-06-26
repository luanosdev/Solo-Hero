---@class RecruitmentManager
---@field hunterManager HunterManager
---@field archetypeManager ArchetypeManager
---@field isRecruiting boolean
---@field hunterCandidates table|nil
local RecruitmentManager = {}
RecruitmentManager.__index = RecruitmentManager

local Constants = require("src.config.constants")
local ArchetypesData = require("src.data.archetypes_data")
local NamesData = require("src.data.names")
local Colors = require("src.ui.colors")
local TablePool = require("src.utils.table_pool")

--- Helper function for weighted random selection from a table.
--- Input table format: { { weight = w1, data = d1 }, { weight = w2, data = d2 }, ... }
--- OR { key1 = { weight = w1, ... }, key2 = { weight = w2, ... } } (returns the key)
---@param choices table Table of choices with weights.
---@return any The chosen data element or key.
local function weightedRandomChoice(choices)
    local totalWeight = 0
    local isArray = type(choices[1]) == "table"

    if isArray then
        for i, choice in ipairs(choices) do
            totalWeight = totalWeight + (choice.weight or 0)
        end
    else
        for key, choiceData in pairs(choices) do
            totalWeight = totalWeight + (choiceData.recruitment_weight or 0)
        end
    end

    if totalWeight <= 0 then return nil end

    local randomNum = love.math.random() * totalWeight
    local cumulativeWeight = 0

    if isArray then
        -- Implementar lógica para array se necessário no futuro
    else
        for key, choiceData in pairs(choices) do
            local weight = choiceData.recruitment_weight or 0
            if randomNum < cumulativeWeight + weight then
                return key
            end
            cumulativeWeight = cumulativeWeight + weight
        end
    end
    return nil
end

---@param hunterManager HunterManager
---@param archetypeManager ArchetypeManager
---@return RecruitmentManager
function RecruitmentManager:new(hunterManager, archetypeManager)
    local instance = setmetatable({}, RecruitmentManager)
    instance.hunterManager = hunterManager
    instance.archetypeManager = archetypeManager
    instance.isRecruiting = false
    instance.hunterCandidates = nil
    Logger.debug("[RecruitmentManager:new]", "Created.")
    return instance
end

--- Inicia o processo de recrutamento, gerando novos candidatos.
function RecruitmentManager:startRecruitment()
    if self.isRecruiting then return end

    Logger.debug("[RecruitmentManager:startRecruitment]", "Starting recruitment...")
    self.hunterCandidates = self:generateHunterCandidates(3) -- Gera 3 opções

    if self.hunterCandidates and #self.hunterCandidates > 0 then
        self.isRecruiting = true
        Logger.debug("[RecruitmentManager:startRecruitment]",
            string.format("Generated %d candidates. Recruitment is active.", #self.hunterCandidates))
    else
        error("[RecruitmentManager:startRecruitment] Failed to generate hunter candidates.")
    end
end

--- Cancela o processo de recrutamento.
function RecruitmentManager:cancelRecruitment()
    if not self.isRecruiting then return end
    Logger.debug("[RecruitmentManager:cancelRecruitment]", "Cancelling recruitment.")
    self.isRecruiting = false
    self.hunterCandidates = nil
end

--- Recruta um candidato específico e finaliza o processo.
---@param candidateIndex number O índice do candidato na lista `hunterCandidates`.
---@return string|nil O ID do novo caçador se o recrutamento for bem-sucedido.
function RecruitmentManager:recruitCandidate(candidateIndex)
    if not self.isRecruiting or not self.hunterCandidates or not self.hunterCandidates[candidateIndex] then
        error(string.format("ERROR [RecruitmentManager]: Invalid candidate index %d for recruitment.", candidateIndex))
    end

    local chosenCandidate = self.hunterCandidates[candidateIndex]
    Logger.debug("[RecruitmentManager:recruitCandidate]",
        string.format("Recruiting candidate %d (%s)...", candidateIndex, chosenCandidate.name))

    local newHunterId = self.hunterManager:recruitHunter(chosenCandidate)
    if newHunterId then
        Logger.debug("[RecruitmentManager:recruitCandidate]",
            string.format("Hunter %s recruited successfully!", newHunterId))
    else
        error("[RecruitmentManager:recruitCandidate] Failed to recruit hunter in HunterManager.")
    end

    -- Limpa o estado independentemente do sucesso ou falha
    self.isRecruiting = false
    self.hunterCandidates = nil

    return newHunterId
end

--- Internal helper to calculate final stats based ONLY on archetype IDs and base stats.
--- Does NOT consider equipped items.
--- @param archetypeIdsToCalculate table List of archetype IDs.
--- @return table Table with calculated final stats.
function RecruitmentManager:_calculateStatsForCandidate(archetypeIdsToCalculate)
    local finalStats = {}
    for key, value in pairs(Constants.HUNTER_DEFAULT_STATS) do
        finalStats[key] = value
    end

    local currentArchetypeIds = archetypeIdsToCalculate or {}

    for _, archetypeId in ipairs(currentArchetypeIds) do
        local archetypeData = self.archetypeManager:getArchetypeData(archetypeId)
        if archetypeData and archetypeData.modifiers then
            for _, mod in ipairs(archetypeData.modifiers) do
                local statName = mod.stat
                local modType = mod.type
                local modValue = mod.value

                if finalStats[statName] == nil then
                    print(string.format(
                        "WARNING [_calculateStatsForCandidate]: Stat base '%s' não definido em HUNTER_DEFAULT_STATS para arquétipo '%s'. Modificador ignorado.",
                        statName, archetypeId))
                    goto continue_candidate_mod_loop
                end
                if modType == nil or modValue == nil then
                    print(string.format(
                        "WARNING [_calculateStatsForCandidate]: Modificador para stat '%s' no arquétipo '%s' não possui 'type' ou 'value'. Modificador ignorado.",
                        statName, archetypeId))
                    goto continue_candidate_mod_loop
                end

                if modType == "fixed" then
                    finalStats[statName] = finalStats[statName] + modValue
                elseif modType == "percentage" then
                    finalStats[statName] = finalStats[statName] * (1 + modValue / 100)
                elseif modType == "fixed_percentage_as_fraction" then
                    finalStats[statName] = finalStats[statName] + modValue
                else
                    print(string.format(
                        "WARNING [_calculateStatsForCandidate]: Tipo de modificador de arquétipo desconhecido '%s' para stat '%s' no arquétipo '%s'.",
                        modType, statName, archetypeId))
                end
                ::continue_candidate_mod_loop::
            end
        end
    end
    return finalStats
end

--- Generates a list of potential hunter candidates for recruitment, respecting rank rules.
--- @param count number The number of candidates to generate.
--- @return table A list of candidate data tables, each containing { id, name, baseRankId, finalRankId, archetypeIds, archetypes, finalStats }.
function RecruitmentManager:generateHunterCandidates(count)
    print(string.format("[RecruitmentManager] Generating %d hunter candidates...", count))
    local candidates = {}
    local archetypesByRank = {}
    for archId, archData in pairs(self.archetypeManager:getAllArchetypeData()) do -- Usa getter do ArchetypeManager
        local rank = archData.rank
        if rank then
            archetypesByRank[rank] = archetypesByRank[rank] or {}
            table.insert(archetypesByRank[rank], archId)
        end
    end

    for i = 1, count do
        local candidate = {}
        candidate.id = "candidate_" .. i
        local firstName = NamesData.first_names[love.math.random(#NamesData.first_names)]
        local lastName = NamesData.last_names[love.math.random(#NamesData.last_names)]
        candidate.name = firstName .. " " .. lastName

        local chosenRankId = weightedRandomChoice(ArchetypesData.Ranks)
        if not chosenRankId then
            print("ERROR [generateHunterCandidates]: Could not determine candidate rank. Defaulting to E.")
            chosenRankId = "E"
        end
        local rankData = ArchetypesData.Ranks[chosenRankId]
        candidate.baseRankId = chosenRankId
        candidate.finalRankId = chosenRankId

        local minArchetypes = rankData.archetype_count_min or 1
        local maxArchetypes = rankData.archetype_count_max or minArchetypes
        local numArchetypes = love.math.random(minArchetypes, maxArchetypes)

        candidate.archetypeIds = {}
        local pickedArchetypesSet = {}
        local rankSpecificArchetypes = archetypesByRank[chosenRankId] or {}
        local availableRankSpecific = {}
        for _, id in ipairs(rankSpecificArchetypes) do table.insert(availableRankSpecific, id) end

        local lowerRankArchetypesPool = {}
        local rankOrder = { "E", "D", "C", "B", "A", "S" }
        for _, currentRankId in ipairs(rankOrder) do
            if currentRankId == chosenRankId then break end
            local archetypesInThisRank = archetypesByRank[currentRankId] or {}
            for _, archId in ipairs(archetypesInThisRank) do
                table.insert(lowerRankArchetypesPool, archId)
            end
        end

        local numMandatoryPicked = 0
        if #availableRankSpecific > 0 then -- Tenta pegar um do rank específico primeiro
            local randomIndex = love.math.random(#availableRankSpecific)
            local chosenArchId = availableRankSpecific[randomIndex]
            table.insert(candidate.archetypeIds, chosenArchId)
            pickedArchetypesSet[chosenArchId] = true
            table.remove(availableRankSpecific, randomIndex)
            numMandatoryPicked = 1
        end

        local numRemainingToPick = numArchetypes - numMandatoryPicked
        if numRemainingToPick > 0 then
            local combinedPool = {}
            for _, id in ipairs(availableRankSpecific) do table.insert(combinedPool, id) end
            for _, id in ipairs(lowerRankArchetypesPool) do table.insert(combinedPool, id) end

            if #combinedPool > 0 then
                for _ = 1, math.min(numRemainingToPick, #combinedPool) do
                    if #combinedPool == 0 then break end -- Segurança extra
                    local randomIndex = love.math.random(#combinedPool)
                    local pickedId = combinedPool[randomIndex]
                    if not pickedArchetypesSet[pickedId] then
                        table.insert(candidate.archetypeIds, pickedId)
                        pickedArchetypesSet[pickedId] = true
                    else
                        -- Tenta pegar outro se o sorteado já foi pego (simples, pode repetir se o pool for pequeno)
                        -- Para uma solução mais robusta, removeria o pickedId do combinedPool
                        -- e re-sortearia ou pegaria o próximo se o pool ficasse vazio.
                        -- Por ora, a duplicidade é evitada pelo pickedArchetypesSet, mas pode resultar em menos arquétipos que o desejado.
                    end
                    table.remove(combinedPool, randomIndex) -- Remove para evitar pegar o mesmo novamente nesta fase
                end
            end
        end

        -- Garante que a contagem final não exceda o desejado, mesmo que a lógica de seleção tenha peculiaridades
        while #candidate.archetypeIds > numArchetypes do
            table.remove(candidate.archetypeIds)
        end

        candidate.archetypes = {}
        for _, arcId in ipairs(candidate.archetypeIds) do
            local arcData = self.archetypeManager:getArchetypeData(arcId)
            if arcData then
                table.insert(candidate.archetypes, arcData)
            else
                print(string.format(
                    "WARNING [generateHunterCandidates]: Could not get data for selected archetype ID '%s'", arcId))
            end
        end

        candidate.finalStats = self:_calculateStatsForCandidate(candidate.archetypeIds)

        -- Adiciona cor de pele aleatória
        local skinToneKeys = TablePool.getArray()
        for skinKey, _ in pairs(Colors.skinTones) do
            table.insert(skinToneKeys, skinKey)
        end
        candidate.skinTone = skinToneKeys[love.math.random(#skinToneKeys)]

        table.insert(candidates, candidate)
        print(string.format("  > Candidate %d: Name=%s, Rank=%s, SkinTone=%s, Archetypes=[%s] (%d total)",
            i, candidate.name, candidate.finalRankId, candidate.skinTone,
            table.concat(candidate.archetypeIds, ", "), #candidate.archetypeIds))
        Logger.debug("[RecruitmentManager] Generated Candidate Data:", Logger.dumpTable(candidate, 2))

        TablePool.releaseArray(skinToneKeys)
    end

    return candidates
end

return RecruitmentManager
