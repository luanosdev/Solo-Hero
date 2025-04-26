---@class ItemDataManager
local ItemDataManager = {}

-- Banco de dados central de itens (será preenchido em init)
ItemDataManager.itemDatabase = {}

-- Função privada para carregar e mesclar dados
local function loadAndMergeData()
    local mergedDatabase = {}
    local itemFiles = {
        "src.data.items.jewels",
        "src.data.items.weapons",
        "src.data.items.consumables",
        "src.data.items.materials",
        "src.data.items.ammo",
        -- Adicione outros arquivos de dados aqui conforme criá-los
    }

    print("[ItemDataManager] Carregando dados de itens...")
    for _, filePath in ipairs(itemFiles) do
        local success, dataOrError = pcall(require, filePath)
        if success and type(dataOrError) == 'table' then
            local itemCount = 0
            for itemId, itemData in pairs(dataOrError) do
                if mergedDatabase[itemId] then
                    print(string.format(
                        "AVISO [ItemDataManager]: ID de item duplicado '%s' encontrado em %s. Sobrescrevendo.", itemId,
                        filePath))
                end
                -- Garante que o ID dentro da tabela seja o mesmo que a chave (opcional, mas bom para consistência)
                itemData.id = itemId

                -- Processa o campo 'icon' para carregar a imagem
                if itemData.icon and type(itemData.icon) == 'string' then
                    local imagePath = itemData.icon
                    -- Usamos pcall para capturar erros de carregamento de imagem (ex: arquivo não encontrado)
                    local success_img, imgOrError = pcall(love.graphics.newImage, imagePath)
                    if success_img then
                        itemData.icon = imgOrError -- Substitui o path pela imagem carregada
                    else
                        -- Log de erro se a imagem não puder ser carregada
                        print(string.format(
                            "ERRO [ItemDataManager]: Falha ao carregar ícone para '%s' de '%s'. Erro: %s",
                            itemId, imagePath, tostring(imgOrError)))
                        itemData.icon = nil -- Define como nil para evitar erros posteriores
                    end
                elseif itemData.icon then
                    -- Caso 'icon' exista mas não seja uma string, loga um aviso e define como nil
                    print(string.format(
                        "AVISO [ItemDataManager]: Campo 'icon' para '%s' não é uma string (tipo: %s). Definindo como nil.",
                        itemId, type(itemData.icon)))
                    itemData.icon = nil
                end

                mergedDatabase[itemId] = itemData
                itemCount = itemCount + 1
            end
            print(string.format("  - Carregado %d itens de %s", itemCount, filePath))
        else
            print(string.format("ERRO [ItemDataManager]: Falha ao carregar ou dados inválidos em %s.", filePath))
            if not success then
                print(string.format("    Erro: %s", tostring(dataOrError)))
            else
                print("    Erro: O arquivo não retornou uma tabela.")
            end
        end
    end
    print("[ItemDataManager] Carregamento concluído.")
    return mergedDatabase
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

-- Inicialização carrega os dados
function ItemDataManager:init()
    self.itemDatabase = loadAndMergeData() -- Carrega e mescla os dados

    local count = 0
    for _ in pairs(self.itemDatabase) do count = count + 1 end
    print("ItemDataManager inicializado com", count, "itens base.")
end

-- Construtor
function ItemDataManager:new()
    local instance = setmetatable({}, { __index = self })
    instance:init()
    return instance
end

return ItemDataManager
