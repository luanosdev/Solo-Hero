--[[-
    Inventory Manager
    Gerencia os itens que o jogador possui.
]]

local InventoryManager = {}

--[[-
    Inicializa o gerenciador de inventário.
]]
function InventoryManager:init()
    -- Armazena os itens. A chave será uma combinação única (ex: "jewel_E")
    -- O valor será uma tabela: { item = <instância base>, quantity = N, maxStack = M }
    self.items = {}
    print("InventoryManager inicializado.")
end

--[[-
    Adiciona um item (ou pilha de itens) ao inventário.
    Tenta empilhar com itens existentes do mesmo tipo/rank.

    @param itemToAdd (table): A instância do item a ser adicionado (ex: uma Jewel, uma Rune).
    @param quantity (number): A quantidade a ser adicionada.
    @return number: A quantidade de itens que *não* puderam ser adicionados (por falta de espaço no stack).
]]
function InventoryManager:addItem(itemToAdd, quantity)
    if not itemToAdd or not quantity or quantity <= 0 then
        return quantity or 0 -- Retorna a quantidade original se os parâmetros forem inválidos
    end

    -- Gera uma chave única para este tipo de item
    -- Para joias, inclui o rank. Para outros itens, pode ser só o tipo.
    local itemKey
    if itemToAdd.type == "jewel" and itemToAdd.rank then
        itemKey = itemToAdd.type .. "_" .. itemToAdd.rank
    else
        itemKey = itemToAdd.type
        -- TODO: Adicionar lógica para outros identificadores únicos se necessário (ex: ID de equipamento)
    end

    local maxStack = itemToAdd.maxStack or 1 -- Assume 1 se não for definido
    local remainingQuantity = quantity

    print(string.format("Tentando adicionar %d de %s (Max Stack: %d)", quantity, itemKey, maxStack))

    -- Verifica se já existe um stack deste item
    if self.items[itemKey] then
        local existingSlot = self.items[itemKey]
        local spaceAvailable = existingSlot.maxStack - existingSlot.quantity

        if spaceAvailable > 0 then
            local amountToAdd = math.min(remainingQuantity, spaceAvailable)
            existingSlot.quantity = existingSlot.quantity + amountToAdd
            remainingQuantity = remainingQuantity - amountToAdd
            print(string.format("Adicionado %d ao stack existente de %s. Quantidade atual: %d", amountToAdd, itemKey, existingSlot.quantity))
        end
    end

    -- Se ainda houver itens restantes e o item pode ser empilhado (maxStack > 1),
    -- e não havia um stack antes, ou o stack existente está cheio.
    -- (Simplificação: Por enquanto, só permitimos um stack por itemKey)
    if remainingQuantity > 0 and not self.items[itemKey] then
         local amountToAdd = math.min(remainingQuantity, maxStack)
         self.items[itemKey] = {
             item = itemToAdd, -- Guarda uma referência ao tipo de item
             quantity = amountToAdd,
             maxStack = maxStack
         }
         remainingQuantity = remainingQuantity - amountToAdd
         print(string.format("Criado novo stack para %s com %d itens.", itemKey, amountToAdd))
     elseif remainingQuantity > 0 then
         print(string.format("Stack de %s cheio. %d itens não puderam ser adicionados.", itemKey, remainingQuantity))
    end

    -- Retorna a quantidade que não coube
    return remainingQuantity
end

--[[-
    Retorna a quantidade atual de um item específico no inventário.

    @param itemKey (string): A chave única do item (ex: "jewel_E").
    @return number: A quantidade do item, ou 0 se não encontrado.
]]
function InventoryManager:getItemCount(itemKey)
    if self.items[itemKey] then
        return self.items[itemKey].quantity
    end
    return 0
end

--[[-
    Retorna todos os itens no inventário.

    @return table: A tabela interna de itens.
]]
function InventoryManager:getAllItems()
    return self.items
end

--[[-
    (Exemplo) Imprime o estado atual do inventário no console.
]]
function InventoryManager:printInventory()
    print("--- Inventário --- ")
    local count = 0
    for key, slot in pairs(self.items) do
        print(string.format("  [%s]: %d / %d (Item: %s)", key, slot.quantity, slot.maxStack, slot.item:getName()))
        count = count + 1
    end
    if count == 0 then
        print("  (Vazio)")
    end
    print("-----------------")
end


-- Retorna uma nova instância do InventoryManager
function InventoryManager:new()
    local instance = {}
    setmetatable(instance, self)
    self.__index = self
    -- Não chama init() aqui, deixa para quem criar a instância
    return instance
end

return InventoryManager 