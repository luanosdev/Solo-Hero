---@class ItemDataService
---@description Serviço centralizado para carregar e fornecer acesso a dados de itens.
--- Este serviço é responsável por carregar os dados brutos dos itens de
--- diferentes arquivos e fornecer uma API unificada para acessá-los.
---@field itemDatabase table<string, table> O banco de dados de todos os itens base.
local ItemDataService = {}
ItemDataService.__index = ItemDataService

local uuid = require("src.utils.uuid")

function ItemDataService:new()
    local instance = setmetatable({}, ItemDataService)
    instance.itemDatabase = {}
    return instance
end

--- Carrega todos os dados de itens de seus respectivos arquivos de dados.
--- Este método deve ser chamado uma vez durante a inicialização do jogo.
function ItemDataService:loadAllData()
    Logger.info("item_data_service.load", "[ItemDataService:loadAllData] Loading all item data...")
    self.itemDatabase = {} -- Reseta o banco de dados

    self:_loadDataFile("src.data.items.weapons", "armas")
    self:_loadDataFile("src.data.items.runes", "runas")
    self:_loadDataFile("src.data.items.teleport_stones", "pedras de teletransporte")
    self:_loadDataFile("src.data.items.artefacts", "artefatos")

    local count = 0
    for _ in pairs(self.itemDatabase) do count = count + 1 end
    Logger.info(
        "item_data_service.load_complete",
        string.format("[ItemDataService:loadAllData] Load complete. %d base items loaded.", count)
    )
end

--- Função privada para carregar e mesclar dados de um único arquivo.
---@param filePath string O caminho do módulo a ser carregado.
---@param categoryName string Nome da categoria para logging.
function ItemDataService:_loadDataFile(filePath, categoryName)
    local success, dataOrError = pcall(require, filePath)
    if not success or type(dataOrError) ~= 'table' then
        Logger.error(
            "item_data_service.load_file_fail",
            string.format("[ItemDataService] Failed to load or invalid data in %s. Error: %s", filePath,
                tostring(dataOrError))
        )
        return
    end

    local itemCount = 0
    for itemId, itemData in pairs(dataOrError) do
        if self.itemDatabase[itemId] then
            Logger.warn(
                "item_data_service.duplicate_id",
                string.format("[ItemDataService] Duplicate item ID '%s' found in %s. Overwriting.", itemId, filePath)
            )
        end
        itemData.id = itemId -- Garante consistência
        self.itemDatabase[itemId] = itemData
        itemCount = itemCount + 1
    end
    Logger.debug(
        "item_data_service.load_category",
        string.format("  - Loaded %d %s from %s", itemCount, categoryName, filePath)
    )
end

--- Obtém os dados base de um item.
---@param itemBaseId string O ID base do item.
---@return table Os dados base do item, ou nil se não encontrado.
function ItemDataService:getBaseItemData(itemBaseId)
    assert(itemBaseId, "ItemDataService:getBaseItemData need a itemBaseId")

    if type(itemBaseId) ~= "string" then
        error("Invalid itemBaseId provided: " .. tostring(itemBaseId))
    end

    local data = self.itemDatabase[itemBaseId]
    if not data then
        error("Base data not found for ID: " .. itemBaseId)
    end

    -- Retorna uma cópia rasa para evitar modificações acidentais no banco de dados.
    local copy = {}
    for k, v in pairs(data) do
        copy[k] = v
    end

    return copy
end

--- Cria uma nova instância de item com base no seu ID base.
---@param itemBaseId string O ID base do item.
---@param quantity number|nil A quantidade para a instância (padrão 1).
---@return table|nil A nova instância do item, ou nil se a base não existir.
function ItemDataService:createItemInstanceById(itemBaseId, quantity)
    local baseData = self:getBaseItemData(itemBaseId)

    local newInstance = {}
    for k, v in pairs(baseData) do
        newInstance[k] = v
    end

    newInstance.instanceId = uuid.generate()
    newInstance.quantity = quantity or 1
    newInstance.itemBaseId = itemBaseId

    Logger.info(
        "item_data_service.create_instance.success",
        string.format("Instance created for '%s' (ID: %s), Qtd: %d", itemBaseId, newInstance.instanceId,
            newInstance.quantity)
    )
    return newInstance
end

return ItemDataService
