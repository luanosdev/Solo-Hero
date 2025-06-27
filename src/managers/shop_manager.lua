local PersistenceManager = require("src.core.persistence_manager")
local Constants = require("src.config.constants")
local ShopColumn = require("src.ui.components.ShopColumn")

---@class ShopItem
---@field itemId string ID do item base
---@field price number Preço do item
---@field stock number Quantidade disponível
---@field maxStock number Quantidade máxima original
---@field weight number Peso de chance de aparecer
---@field isOnSale boolean Se está em promoção
---@field salePrice number|nil Preço promocional
---@field gridWidth number Largura na grade
---@field gridHeight number Altura na grade

---@class ShopData
---@field name string Nome da loja
---@field items ShopItem[] Lista de itens disponíveis
---@field featuredItems ShopItem[] Lista de itens em promoção
---@field timeUntilRefresh number Tempo até próxima atualização
---@field refreshInterval number Intervalo de atualização em segundos

---@class ShopManager
---@field currentShop ShopData|nil Loja atual
---@field itemDataManager ItemDataManager|nil Referência ao gerenciador de itens
---@field shopNames string[] Lista de nomes possíveis para lojas
---@field shopItemsPool table Pool de itens disponíveis para lojas
local ShopManager = {}
ShopManager.__index = ShopManager

--- Nomes aleatórios para as lojas
ShopManager.shopNames = {
    "Mercado do Aventureiro",
    "Loja do Caçador",
    "Empório Mágico",
    "Mercado Negro",
    "Loja de Antiguidades",
    "Mercado dos Heróis",
    "Bazar do Leveling",
    "Loja de Raridades",
    "Mercado Central",
    "Empório do Guerreiro"
}

--- Pool de itens disponíveis para as lojas com seus pesos
ShopManager.shopItemsPool = {
    -- Itens comuns (peso alto)
    { itemId = "rotting_flesh",    weight = 100, minStock = 10, maxStock = 50 },
    { itemId = "intact_brain",     weight = 80,  minStock = 5,  maxStock = 20 },
    { itemId = "ruined_heart",     weight = 60,  minStock = 3,  maxStock = 15 },
    { itemId = "bone_fragment",    weight = 120, minStock = 20, maxStock = 100 },

    -- Pedras de teleporte (peso baixo) - assumindo que existem
    { itemId = "teleport_stone_a", weight = 15,  minStock = 1,  maxStock = 2 },
    { itemId = "teleport_stone_b", weight = 10,  minStock = 1,  maxStock = 2 },
    { itemId = "teleport_stone_c", weight = 5,   minStock = 1,  maxStock = 1 },
}

--- Cria uma nova instância do ShopManager
---@param itemDataManager ItemDataManager|nil Referência ao gerenciador de itens
---@return ShopManager
function ShopManager:new(itemDataManager)
    local instance = setmetatable({}, ShopManager)
    instance.itemDataManager = itemDataManager
    instance.currentShop = nil
    instance:loadState()

    -- Se não há loja carregada, gera uma nova
    if not instance.currentShop then
        instance:generateNewShop()
    end

    return instance
end

--- Atualiza o gerenciador da loja
---@param dt number Delta time
function ShopManager:update(dt)
    if not self.currentShop then return end

    self.currentShop.timeUntilRefresh = self.currentShop.timeUntilRefresh - dt

    -- Se o tempo acabou, gera uma nova loja
    if self.currentShop.timeUntilRefresh <= 0 then
        self:generateNewShop()
        self:saveState()
    end
end

--- Gera uma nova loja com itens aleatórios
function ShopManager:generateNewShop()
    local shopName = self.shopNames[math.random(1, #self.shopNames)]
    local refreshInterval = 300 + math.random(-60, 60) -- 5 minutos +/- 1 minuto

    local newShop = {
        name = shopName,
        items = {},
        featuredItems = {},
        timeUntilRefresh = refreshInterval,
        refreshInterval = refreshInterval
    }

    -- Seleciona itens aleatórios baseado nos pesos
    local totalWeight = 0
    for _, poolItem in ipairs(self.shopItemsPool) do
        totalWeight = totalWeight + poolItem.weight
    end

    -- Gera 8-15 itens para a loja
    local numGeneicos = math.random(8, 15)
    local selectedItems = {}

    for _ = 1, numGeneicos do
        local roll = math.random() * totalWeight
        local currentWeight = 0

        for _, poolItem in ipairs(self.shopItemsPool) do
            currentWeight = currentWeight + poolItem.weight
            if roll <= currentWeight then
                -- Evita duplicatas
                local alreadySelected = false
                for _, selected in ipairs(selectedItems) do
                    if selected.itemId == poolItem.itemId then
                        alreadySelected = true
                        break
                    end
                end

                if not alreadySelected then
                    local itemData = nil
                    if self.itemDataManager then
                        itemData = self.itemDataManager:getBaseItemData(poolItem.itemId)
                    end

                    -- Sistema de preços baseado no valor do item
                    local baseValue = (itemData and itemData.value) or 1
                    local price = baseValue * 3 -- Compra é 3x o valor
                    local stock = math.random(poolItem.minStock, poolItem.maxStock)

                    -- Verifica se item deve estar em promoção (15% de chance)
                    local isOnSale = math.random() < 0.15
                    local salePrice = nil
                    if isOnSale then
                        salePrice = math.floor(price * (0.6 + math.random() * 0.2)) -- 60%-80% do preço original
                    end

                    local shopItem = {
                        itemId = poolItem.itemId,
                        price = price,
                        sellPrice = baseValue, -- Venda é o valor integral
                        stock = stock,
                        maxStock = stock,
                        weight = poolItem.weight,
                        isOnSale = isOnSale,
                        salePrice = salePrice,
                        gridWidth = itemData and itemData.gridWidth or 1,
                        gridHeight = itemData and itemData.gridHeight or 1
                    }

                    if isOnSale then
                        table.insert(newShop.featuredItems, shopItem)
                    else
                        table.insert(newShop.items, shopItem)
                    end

                    table.insert(selectedItems, shopItem)
                end
                break
            end
        end
    end

    self.currentShop = newShop
    Logger.info(
        "shop_manager.generate_new_shop",
        "[ShopManager.generateNewShop] Nova loja gerada: " .. shopName .. " com " .. #selectedItems .. " itens"
    )
end

--- Obtém a loja atual
---@return ShopData|nil
function ShopManager:getCurrentShop()
    return self.currentShop
end

--- Verifica se um item está em uma posição específica
---@param x number Posição X do mouse
---@param y number Posição Y do mouse
---@param shopArea table Área da loja
---@return ShopItem|nil
function ShopManager:getItemAtPosition(x, y, shopArea)
    return ShopColumn.getItemAtPosition(x, y, shopArea, self)
end

--- Tenta comprar um item
---@param itemId string ID do item
---@param quantity number Quantidade a comprar
---@return boolean success Se a compra foi bem-sucedida
function ShopManager:purchaseItem(itemId, quantity)
    if not self.currentShop then return false end

    quantity = quantity or 1

    -- Procura o item nas listas
    local targetItem = nil
    local targetList = nil

    for _, item in ipairs(self.currentShop.featuredItems) do
        if item.itemId == itemId then
            targetItem = item
            targetList = self.currentShop.featuredItems
            break
        end
    end

    if not targetItem then
        for _, item in ipairs(self.currentShop.items) do
            if item.itemId == itemId then
                targetItem = item
                targetList = self.currentShop.items
                break
            end
        end
    end

    if not targetItem or targetItem.stock < quantity then
        return false
    end

    -- TODO: Verificar se o jogador tem dinheiro suficiente
    local effectivePrice = targetItem.isOnSale and targetItem.salePrice or targetItem.price
    local totalCost = effectivePrice * quantity

    -- Por enquanto, sempre permite a compra
    targetItem.stock = targetItem.stock - quantity

    -- Remove o item da lista se o stock chegou a zero
    if targetItem.stock <= 0 then
        for i, item in ipairs(targetList) do
            if item == targetItem then
                table.remove(targetList, i)
                break
            end
        end
    end

    self:saveState()
    Logger.info(
        "shop_manager.purchase_item",
        "[ShopManager.purchaseItem] Item comprado: " .. itemId .. " x" .. quantity .. " por " .. totalCost
    )
    return true
end

--- Vende todos os itens do loadout
---@param loadoutManager LoadoutManager
---@return number totalValue Valor total da venda
function ShopManager:sellAllFromLoadout(loadoutManager)
    if not loadoutManager then return 0 end

    local totalValue = 0
    local loadoutItems = loadoutManager:getItems()

    for instanceId, item in pairs(loadoutItems) do
        local baseData = self.itemDataManager and self.itemDataManager:getBaseItemData(item.itemBaseId)
        if baseData then
            -- Usa o valor integral do item para venda
            local sellValue = (baseData.value or 1) * item.quantity
            totalValue = totalValue + sellValue

            -- Remove o item do loadout
            loadoutManager:removeItemInstance(instanceId)
        end
    end

    -- TODO: Adicionar o dinheiro ao jogador
    Logger.info(
        "shop_manager.sell_all_from_loadout",
        "[ShopManager.sellAllFromLoadout] Vendidos itens por valor total: " .. totalValue
    )
    return totalValue
end

--- Salva o estado da loja
function ShopManager:saveState()
    if self.currentShop then
        PersistenceManager.saveData("shop_state.dat", self.currentShop)
    end
end

--- Carrega o estado da loja
function ShopManager:loadState()
    local success, data = pcall(PersistenceManager.loadData, "shop_state.dat")
    if success and data then
        self.currentShop = data
        Logger.info("shop_manager.load_state", "[ShopManager.loadState] Estado da loja carregado")
    else
        Logger.info("shop_manager.load_state", "[ShopManager.loadState] Nenhum estado de loja encontrado")
    end
end

return ShopManager
