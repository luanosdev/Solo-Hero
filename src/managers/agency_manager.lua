local PersistenceManager = require("src.core.persistence_manager")

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
        Logger.info("AgencyManager", "Dados da agência carregados com sucesso.")
    else
        Logger.info("AgencyManager",
            "Nenhum arquivo de dados da agência encontrado. Uma nova agência precisa ser criada.")
        self.data = nil
    end
end

--- Salva os dados atuais da agência no arquivo.
---@param agencyData table Os dados da agência a serem salvos.
function AgencyManager:save(agencyData)
    if not agencyData then
        Logger.warn("AgencyManager", "Tentativa de salvar dados de agência nulos. Nada foi salvo.")
        return false
    end

    self.data = agencyData
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
    self:save(newAgency)
    return newAgency
end

return AgencyManager
