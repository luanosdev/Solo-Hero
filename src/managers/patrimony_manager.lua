------------------------------------------------------------------------------------------------
-- PatrimonyManager.lua
-- Gerencia o patrimônio do jogador, incluindo ouro e itens.
------------------------------------------------------------------------------------------------

local PersistenceManager = require("src.core.persistence_manager")
local Logger = require("src.libs.logger")

---@class PatrimonyManager
---@field currentGold number Quantidade atual de ouro
---@field filename string Nome do arquivo de persistência
local PatrimonyManager = {}
PatrimonyManager.__index = PatrimonyManager

--- Cria uma nova instância do PatrimonyManager
---@return PatrimonyManager
function PatrimonyManager:new()
    local instance = setmetatable({}, PatrimonyManager)
    instance.currentGold = 0
    instance.filename = "patrimony.dat"
    return instance
end

--- Inicializa o gerenciador carregando dados salvos
function PatrimonyManager:initialize()
    self:loadData()
    Logger.info("patrimony_manager.initialize", "[PatrimonyManager:initialize] Sistema de patrimônio inicializado")
end

--- Carrega dados do patrimônio
function PatrimonyManager:loadData()
    local data = PersistenceManager.loadData(self.filename)
    if data and data.currentGold then
        self.currentGold = data.currentGold
        Logger.info(
            "patrimony_manager.load",
            "[PatrimonyManager:loadData] Patrimônio carregado: " .. self.currentGold .. " gold"
        )
    else
        -- Valores iniciais para novos jogadores
        self.currentGold = 1000 -- Começa com 1000 de ouro
        Logger.info(
            "patrimony_manager.load",
            "[PatrimonyManager:loadData] Novo patrimônio criado: " .. self.currentGold .. " gold"
        )
        self:saveData()
    end
end

--- Salva dados do patrimônio
function PatrimonyManager:saveData()
    local data = {
        currentGold = self.currentGold
    }

    local success = PersistenceManager.saveData(self.filename, data)
    if success then
        Logger.info(
            "patrimony_manager.save",
            "[PatrimonyManager:saveData] Patrimônio salvo: " .. self.currentGold .. " gold"
        )
    else
        Logger.error("patrimony_manager.save", "[PatrimonyManager:saveData] Falha ao salvar patrimônio")
    end
end

--- Obtém a quantidade atual de ouro
---@return number currentGold Quantidade atual de ouro
function PatrimonyManager:getCurrentGold()
    return self.currentGold
end

--- Verifica se o jogador tem ouro suficiente
---@param amount number Quantidade a verificar
---@return boolean hasEnoughGold Se tem ouro suficiente
function PatrimonyManager:hasEnoughGold(amount)
    return self.currentGold >= amount
end

--- Adiciona ouro ao patrimônio
---@param amount number Quantidade de ouro a adicionar
---@param reason string|nil Motivo da adição (para log)
---@return boolean success Se a operação foi bem-sucedida
function PatrimonyManager:addGold(amount, reason)
    if amount <= 0 then
        Logger.warn(
            "patrimony_manager.add_gold",
            "[PatrimonyManager:addGold] Tentativa de adicionar quantidade inválida: " .. amount
        )
        return false
    end

    self.currentGold = self.currentGold + amount
    reason = reason or "unknown"
    Logger.info(
        "patrimony_manager.add_gold",
        "[PatrimonyManager:addGold] +" .. amount .. " gold (" .. reason .. "). Total: " .. self.currentGold
    )

    -- Exibir notificação de mudança de patrimônio
    if NotificationDisplay then
        NotificationDisplay.showMoneyChange(amount)
        Logger.debug("patrimony_manager.notification.money_change",
            "[PatrimonyManager:addGold] Notificação de mudança de patrimônio exibida: +" .. amount)
    end

    self:saveData()
    return true
end

--- Remove ouro do patrimônio
---@param amount number Quantidade de ouro a remover
---@param reason string|nil Motivo da remoção (para log)
---@return boolean success Se a operação foi bem-sucedida
function PatrimonyManager:removeGold(amount, reason)
    if amount <= 0 then
        Logger.warn(
            "patrimony_manager.remove_gold",
            "[PatrimonyManager:removeGold] Tentativa de remover quantidade inválida: " .. amount
        )
        return false
    end

    if not self:hasEnoughGold(amount) then
        Logger.warn(
            "patrimony_manager.remove_gold",
            "[PatrimonyManager:removeGold] Ouro insuficiente. Tentativa: -"
            .. amount .. ", Disponível: " .. self.currentGold
        )
        return false
    end

    self.currentGold = self.currentGold - amount
    reason = reason or "unknown"
    Logger.info(
        "patrimony_manager.remove_gold",
        "[PatrimonyManager:removeGold] -" .. amount .. " gold (" .. reason .. "). Total: " .. self.currentGold
    )

    -- Exibir notificação de mudança de patrimônio (exceto para compras/vendas que já têm notificações próprias)
    if NotificationDisplay then
        NotificationDisplay.showMoneyChange(-amount)
        Logger.debug("patrimony_manager.notification.money_change",
            "[PatrimonyManager:removeGold] Notificação de mudança de patrimônio exibida: -" .. amount)
    end

    self:saveData()
    return true
end

--- Define a quantidade de ouro (usado para debugging/testes)
---@param amount number Nova quantidade de ouro
---@param reason string|nil Motivo da alteração (para log)
function PatrimonyManager:setGold(amount, reason)
    if amount < 0 then
        Logger.warn(
            "patrimony_manager.set_gold",
            "[PatrimonyManager:setGold] Tentativa de definir quantidade negativa: " .. amount)
        return
    end

    local oldAmount = self.currentGold
    self.currentGold = amount
    reason = reason or "manual_set"
    Logger.info(
        "patrimony_manager.set_gold",
        "[PatrimonyManager:setGold] Ouro alterado de " .. oldAmount .. " para " .. amount .. " (" .. reason .. ")"
    )

    self:saveData()
end

--- Formata o valor de ouro para exibição
---@param amount number|nil Quantidade a formatar (usa currentGold se nil)
---@return string formattedGold String formatada (ex: "1,234G")
function PatrimonyManager:formatGold(amount)
    amount = amount or self.currentGold

    -- Adiciona separadores de milhares
    local formatted = tostring(amount)
    local pos = string.len(formatted) % 3
    if pos == 0 then pos = 3 end

    local result = string.sub(formatted, 1, pos)
    while pos < string.len(formatted) do
        result = result .. "," .. string.sub(formatted, pos + 1, pos + 3)
        pos = pos + 3
    end

    return result .. "G"
end

--- Processa transação de compra
---@param itemPrice number Preço do item
---@param itemName string Nome do item (para log)
---@param icon love.Image|nil Ícone do item para a notificação
---@return boolean success Se a compra foi bem-sucedida
function PatrimonyManager:purchaseItem(itemPrice, itemName, icon)
    itemName = itemName or "unknown_item"

    if not self:hasEnoughGold(itemPrice) then
        Logger.warn(
            "patrimony_manager.purchase",
            "[PatrimonyManager:purchaseItem] Compra negada - ouro insuficiente. Item: " ..
            itemName .. ", Preço: " .. itemPrice .. ", Disponível: " .. self.currentGold
        )
        return false
    end

    local success = self:removeGold(itemPrice, "purchase_" .. itemName)
    if success then
        Logger.info(
            "patrimony_manager.purchase",
            "[PatrimonyManager:purchaseItem] Compra realizada. Item: " ..
            itemName .. ", Preço: " .. itemPrice .. ", Novo total: " .. self.currentGold
        )

        -- Exibir notificação de compra
        if NotificationDisplay then
            NotificationDisplay.showItemPurchase(itemName, icon, itemPrice)
            Logger.debug("patrimony_manager.notification.purchase",
                "[PatrimonyManager:purchaseItem] Notificação de compra exibida: " .. itemName .. " por " .. itemPrice)
        end
    end

    return success
end

--- Processa transação de venda
---@param sellPrice number Preço de venda do item
---@param itemName string Nome do item (para log)
---@param icon love.Image|nil Ícone do item para a notificação
---@return boolean success Se a venda foi bem-sucedida
function PatrimonyManager:sellItem(sellPrice, itemName, icon)
    itemName = itemName or "unknown_item"

    local success = self:addGold(sellPrice, "sale_" .. itemName)
    if success then
        Logger.info(
            "patrimony_manager.sell",
            "[PatrimonyManager:sellItem] Venda realizada. Item: " ..
            itemName .. ", Preço: " .. sellPrice .. ", Novo total: " .. self.currentGold
        )

        -- Exibir notificação de venda
        if NotificationDisplay then
            NotificationDisplay.showItemSale(itemName, icon, sellPrice)
            Logger.debug("patrimony_manager.notification.sale",
                "[PatrimonyManager:sellItem] Notificação de venda exibida: " .. itemName .. " por " .. sellPrice)
        end
    end

    return success
end

return PatrimonyManager
