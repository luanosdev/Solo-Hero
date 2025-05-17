---@class ItemDataManager
local ItemDataManager = {}

-- Banco de dados central de itens (será preenchido em init)
ItemDataManager.itemDatabase = {}

--- Função privada para carregar e mesclar dados de um único arquivo.
---@param self ItemDataManager
---@param filePath string O caminho do módulo a ser carregado (ex: "src.data.items.weapons").
---@param categoryName string Nome da categoria para logging (ex: "armas").
function ItemDataManager:_loadDataFile(filePath, categoryName)
    local success, dataOrError = pcall(require, filePath)
    if success and type(dataOrError) == 'table' then
        local itemCount = 0
        for itemId, itemData in pairs(dataOrError) do
            if self.itemDatabase[itemId] then
                print(string.format(
                    "AVISO [ItemDataManager]: ID de item duplicado '%s' encontrado em %s. Sobrescrevendo.", itemId,
                    filePath))
            end
            -- Garante que o ID dentro da tabela seja o mesmo que a chave
            itemData.id = itemId

            -- Processa o campo 'icon' para carregar a imagem
            if itemData.icon and type(itemData.icon) == 'string' then
                local imagePath = itemData.icon
                local success_img, imgOrError = pcall(love.graphics.newImage, imagePath)
                if success_img then
                    itemData.icon = imgOrError
                else
                    print(string.format(
                        "ERRO [ItemDataManager]: Falha ao carregar ícone para '%s' de '%s'. Erro: %s",
                        itemId, imagePath, tostring(imgOrError)))
                    itemData.icon = nil
                end
            elseif itemData.icon then
                print(string.format(
                    "AVISO [ItemDataManager]: Campo 'icon' para '%s' não é uma string (tipo: %s). Definindo como nil.",
                    itemId, type(itemData.icon)))
                itemData.icon = nil
            end

            self.itemDatabase[itemId] = itemData
            itemCount = itemCount + 1
        end
        print(string.format("  - Carregado %d %s de %s", itemCount, categoryName, filePath))
    else
        print(string.format("ERRO [ItemDataManager]: Falha ao carregar ou dados inválidos em %s.", filePath))
        if not success then
            print(string.format("    Erro: %s", tostring(dataOrError)))
        else
            print("    Erro: O arquivo não retornou uma tabela.")
        end
    end
end

function ItemDataManager:getBaseItemData(itemBaseId)
    if not itemBaseId then return nil end
    local data = self.itemDatabase[itemBaseId]
    if not data then
        print("AVISO [ItemDataManager]: Dados base não encontrados para ID:", itemBaseId)
        return nil
    end
    -- Retorna uma cópia rasa para evitar modificações acidentais no banco de dados
    local copy = {}
    for k, v in pairs(data) do
        copy[k] = v
    end
    return copy
end

-- Inicialização carrega os dados usando o helper _loadDataFile
function ItemDataManager:init()
    print("[ItemDataManager] Carregando dados de itens...")
    self.itemDatabase = {} -- Reseta o banco de dados

    -- Chama _loadDataFile para cada categoria
    self:_loadDataFile("src.data.items.weapons", "armas")
    self:_loadDataFile("src.data.items.consumables", "consumíveis")
    self:_loadDataFile("src.data.items.materials", "materiais")
    self:_loadDataFile("src.data.items.runes", "runas")
    self:_loadDataFile("src.data.items.teleport_stones", "pedras de teletransporte")

    local count = 0
    for _ in pairs(self.itemDatabase) do count = count + 1 end
    print(string.format("[ItemDataManager] Carregamento concluído. %d itens base carregados.", count))
end

-- Construtor
function ItemDataManager:new()
    local instance = setmetatable({}, { __index = self })
    instance:init()
    return instance
end

return ItemDataManager
