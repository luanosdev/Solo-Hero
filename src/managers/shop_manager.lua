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
---@field patrimonyManager PatrimonyManager|nil Referência ao gerenciador de patrimônio
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
    -- Armas (peso médio)
    { itemId = "arrow_projectile_e_001",        weight = 30, minStock = 1, maxStock = 3 },
    { itemId = "alternating_cone_strike_e_001", weight = 20, minStock = 1, maxStock = 2 },
    { itemId = "cone_slash_e_001",              weight = 20, minStock = 1, maxStock = 2 },
    { itemId = "circular_smash_e_001",          weight = 20, minStock = 1, maxStock = 2 },
    { itemId = "flamethrower",                  weight = 20, minStock = 1, maxStock = 2 },
    { itemId = "chain_laser",                   weight = 20, minStock = 1, maxStock = 2 },
    { itemId = "hammer",                        weight = 20, minStock = 1, maxStock = 2 },

    -- Pedras de teleporte (peso baixo) - assumindo que existem
    { itemId = "teleport_stone_a",              weight = 15, minStock = 1, maxStock = 2 },
    { itemId = "teleport_stone_b",              weight = 10, minStock = 1, maxStock = 2 },
    { itemId = "teleport_stone_s",              weight = 5,  minStock = 1, maxStock = 1 },
}

--- Cria uma nova instância do ShopManager
---@param itemDataManager ItemDataManager|nil Referência ao gerenciador de itens
---@param patrimonyManager PatrimonyManager|nil Referência ao gerenciador de patrimônio
---@return ShopManager
function ShopManager:new(itemDataManager, patrimonyManager)
    local instance = setmetatable({}, ShopManager)
    instance.itemDataManager = itemDataManager
    instance.patrimonyManager = patrimonyManager
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

    -- Verifica se o jogador tem dinheiro suficiente
    local effectivePrice = targetItem.isOnSale and targetItem.salePrice or targetItem.price
    local totalCost = effectivePrice * quantity

    if self.patrimonyManager then
        if not self.patrimonyManager:hasEnoughGold(totalCost) then
            NotificationDisplay.showInsufficientFunds()
            Logger.warn(
                "shop_manager.purchase_item.insufficient_funds",
                "[ShopManager.purchaseItem] Fundos insuficientes para comprar " .. itemId ..
                ". Custo: " .. totalCost .. ", Disponível: " .. self.patrimonyManager:getCurrentGold()
            )
            return false
        end

        -- Pega o item base
        local itemBase = self.itemDataManager:getBaseItemData(itemId)
        -- Pega a imagem do item base
        local itemIcon = nil
        if itemBase and itemBase.icon then
            if type(itemBase.icon) == "string" then
                itemIcon = love.graphics.newImage(itemBase.icon)
            else
                itemIcon = itemBase.icon
            end
        end

        -- Processa a compra
        local purchased = self.patrimonyManager:purchaseItem(totalCost, itemBase.name, itemIcon)
        if not purchased then
            return false
        end
    end

    -- Remove item do estoque
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

--- Calcula o preço de venda de um item
---@param itemInstance table Instância do item
---@return number price Preço de venda
function ShopManager:calculateSellPrice(itemInstance)
    if not itemInstance or not itemInstance.itemBaseId then return 0 end

    local baseData = self.itemDataManager and self.itemDataManager:getBaseItemData(itemInstance.itemBaseId)
    if not baseData then return 0 end

    -- Preço de venda é o valor integral do item (valor base)
    local sellValue = baseData.value * itemInstance.quantity
    return sellValue
end

--- Vende um item individual para a loja
---@param itemInstance table Instância do item
---@return number sellPrice Preço obtido pela venda, 0 se falhou
function ShopManager:sellItem(itemInstance)
    if not itemInstance or not itemInstance.itemBaseId then
        Logger.warn("shop_manager.sell.failed", "[ShopManager.sellItem] Item inválido para venda")
        return 0
    end

    local sellPrice = self:calculateSellPrice(itemInstance)

    if sellPrice > 0 then
        NotificationDisplay.showItemSale(itemInstance.name, itemInstance.icon, 1)
        -- Adiciona dinheiro ao patrimônio do jogador
        if self.patrimonyManager then
            self.patrimonyManager:sellItem(sellPrice, itemInstance.name, itemInstance.icon)
        end

        Logger.info(
            "shop_manager.sell.success",
            "[ShopManager.sellItem] Item vendido: " .. itemInstance.itemBaseId .. " por " .. sellPrice .. " gold"
        )
    else
        Logger.warn(
            "shop_manager.sell.failed",
            "[ShopManager.sellItem] Item sem valor: " .. (itemInstance.itemBaseId or "unknown")
        )
    end

    return sellPrice
end

--- Vende todos os itens do loadout
---@param loadoutManager LoadoutManager
---@return number totalValue Valor total da venda
function ShopManager:sellAllFromLoadout(loadoutManager)
    if not loadoutManager then return 0 end

    local totalValue = 0
    local itemsToBulkSell = {}
    local loadoutItems = loadoutManager:getItems()

    for instanceId, item in pairs(loadoutItems) do
        local baseData = self.itemDataManager and self.itemDataManager:getBaseItemData(item.itemBaseId)
        if baseData then
            -- Usa o valor integral do item para venda
            local sellValue = (baseData.value or 1) * item.quantity
            totalValue = totalValue + sellValue

            -- Adiciona à lista para log
            table.insert(itemsToBulkSell, { name = baseData.name, quantity = item.quantity, value = sellValue })

            NotificationDisplay.showItemSale(baseData.name, baseData.icon, item.quantity)
            -- Remove o item do loadout
            loadoutManager:removeItemInstance(instanceId)
        end
    end

    -- Adiciona o dinheiro ao patrimônio do jogador
    if self.patrimonyManager and totalValue > 0 then
        self.patrimonyManager:sellItem(totalValue, "Venda do Loadout") -- Ícone não se aplica a venda em massa
    end

    -- Log aprimorado
    local itemNames = {}
    for _, itemInfo in ipairs(itemsToBulkSell) do
        table.insert(itemNames, itemInfo.quantity .. "x " .. itemInfo.name)
    end

    Logger.info(
        "shop_manager.sell_all_from_loadout",
        "[ShopManager.sellAllFromLoadout] Vendidos itens (" ..
        table.concat(itemNames, ", ") .. ") por valor total: " .. totalValue
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
