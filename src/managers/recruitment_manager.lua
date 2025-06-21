---@class RecruitmentManager
---@field hunterManager HunterManager
---@field isRecruiting boolean
---@field hunterCandidates table|nil
local RecruitmentManager = {}
RecruitmentManager.__index = RecruitmentManager

---@param hunterManager HunterManager
---@return RecruitmentManager
function RecruitmentManager:new(hunterManager)
    local instance = setmetatable({}, RecruitmentManager)
    instance.hunterManager = hunterManager
    instance.isRecruiting = false
    instance.hunterCandidates = nil
    Logger.debug("[RecruitmentManager:new]", "Created.")
    return instance
end

--- Inicia o processo de recrutamento, gerando novos candidatos.
function RecruitmentManager:startRecruitment()
    if self.isRecruiting then return end

    Logger.debug("[RecruitmentManager:startRecruitment]", "Starting recruitment...")
    self.hunterCandidates = self.hunterManager:generateHunterCandidates(3) -- Gera 3 opções

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

return RecruitmentManager
