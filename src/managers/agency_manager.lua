local PersistenceManager = require("src.core.persistence_manager")
local ReputationConfig = require("src.config.reputation_config")

---@class AgencyManager
local AgencyManager = {}
AgencyManager.__index = AgencyManager

local SAVE_FILE = "agency.dat"

function AgencyManager:new()
    local self = setmetatable({}, AgencyManager)
    self.data = nil
    self:load()
    return self
end

--- Tenta carregar os dados da agência do arquivo de save.
function AgencyManager:load()
    Logger.info("AgencyManager", "Tentando carregar dados da agência...")
    local loadedData = PersistenceManager.loadData(SAVE_FILE)

    if loadedData and type(loadedData) == "table" then
        self.data = loadedData
        -- Garante que a reputação seja um número ao carregar
        self.data.reputation = tonumber(self.data.reputation) or 0
        Logger.info("AgencyManager", "Dados da agência carregados com sucesso.")
    else
        Logger.info("AgencyManager",
            "Nenhum arquivo de dados da agência encontrado. Uma nova agência precisa ser criada.")
        self.data = nil
    end
end

--- Salva os dados atuais da agência no arquivo.
function AgencyManager:saveState()
    if not self.data then
        Logger.warn("AgencyManager", "Tentativa de salvar dados de agência nulos. Nada foi salvo.")
        return false
    end

    Logger.info("AgencyManager", "Solicitando salvamento dos dados da agência...")
    local success = PersistenceManager.saveData(SAVE_FILE, self.data)

    if success then
        Logger.info("AgencyManager", "Dados da agência salvos com sucesso.")
    else
        Logger.error("AgencyManager", "Falha ao salvar os dados da agência.")
    end
    return success
end

--- Verifica se já existe uma agência criada.
---@return boolean
function AgencyManager:hasAgency()
    return self.data ~= nil
end

--- Retorna os dados da agência.
---@return table|nil
function AgencyManager:getAgencyData()
    return self.data
end

--- Retorna a reputação atual da agência.
---@return number
function AgencyManager:getReputation()
    return self.data and self.data.reputation or 0
end

--- Adiciona (ou remove) pontos de reputação e atualiza o rank se necessário.
---@param points number A quantidade de pontos a adicionar (pode ser negativa).
function AgencyManager:addReputation(points)
    if not self.data then return end

    self.data.reputation = self.data.reputation + points
    -- Garante que a reputação não caia abaixo de 0.
    if self.data.reputation < 0 then
        self.data.reputation = 0
    end

    self:_updateRank()
    self:saveState()
end

--- (Privado) Atualiza o rank da agência com base na reputação atual.
function AgencyManager:_updateRank()
    if not self.data then return end

    local currentReputation = self.data.reputation
    local newRank = self.data.rank
    local currentRankIndex = -1

    -- Encontra o rank mais alto que a agência pode ter com a reputação atual.
    -- Itera de trás para frente para garantir que o rank mais alto seja pego primeiro.
    for i = #ReputationConfig.rankOrder, 1, -1 do
        local rankLetter = ReputationConfig.rankOrder[i]
        local requiredRep = ReputationConfig.rankThresholds[rankLetter]
        if requiredRep ~= nil and currentReputation >= requiredRep then
            newRank = rankLetter
            break -- Encontrou o rank mais alto, pode parar.
        end
    end

    if self.data.rank ~= newRank then
        print(string.format("RANK UP! Agência promovida de Rank %s para Rank %s!", self.data.rank, newRank))
        self.data.rank = newRank
    end
end

--- Cria uma nova agência e a salva.
---@param name string O nome da agência.
---@return table Os dados da nova agência.
function AgencyManager:createAgency(name)
    local newAgency = {
        name = name,
        rank = "E", -- E, D, C, B, A, S
        reputation = 0,
        unlockedPortals = { "portal_zumbi_E" },
        createdAt = os.time(),
    }
    self.data = newAgency
    self:saveState()
    return newAgency
end

return AgencyManager
