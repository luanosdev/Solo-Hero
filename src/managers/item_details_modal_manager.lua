----------------------------------------------------------
--- Gerenciador de tooltip para o modal de detalhes de item
----------------------------------------------------------
---@class ItemDetailsModalManager
local ItemDetailsModalManager = {}

local ItemDetailsModal = require("src.ui.item_details_modal")
local ManagerRegistry = require("src.managers.manager_registry")

ItemDetailsModalManager.activeItem = nil
ItemDetailsModalManager.activeBaseItemData = nil
ItemDetailsModalManager.mouseX = 0
ItemDetailsModalManager.mouseY = 0
ItemDetailsModalManager.offsetX = 15
ItemDetailsModalManager.offsetY = 15
ItemDetailsModalManager.isVisible = false

--- Mostra o tooltip para um item específico. (Pode ser usado por UIs que precisam de controle mais fino)
--- @param item BaseItem|table A instância do item.
--- @param mx number Posição X do mouse.
--- @param my number Posição Y do mouse.
--- @param owner? string Identificador opcional de quem está solicitando o tooltip.
function ItemDetailsModalManager.show(item, mx, my, owner) -- Owner é opcional agora
    if not item or not item.itemBaseId then
        ItemDetailsModalManager.hide()
        return
    end

    local itemDataManager = ManagerRegistry:get("itemDataManager")
    if not itemDataManager then
        error("[HoverManager.show] ERRO: ItemDataManager não encontrado.")
    end

    local baseData = itemDataManager:getBaseItemData(item.itemBaseId)

    if not baseData then
        error("[HoverManager.show] ERRO: BaseItemData não encontrado para o item: " .. item.itemBaseId)
    end

    ItemDetailsModalManager.activeItem = item
    ItemDetailsModalManager.activeBaseItemData = baseData
    ItemDetailsModalManager.mouseX = mx
    ItemDetailsModalManager.mouseY = my
    ItemDetailsModalManager.isVisible = true
end

--- Esconde o tooltip.
function ItemDetailsModalManager.hide()
    ItemDetailsModalManager.activeItem = nil
    ItemDetailsModalManager.activeBaseItemData = nil
    ItemDetailsModalManager.isVisible = false
end

--- Atualiza o estado e a posição do tooltip com base no item atualmente sob o mouse.
--- @param dt number Delta time.
--- @param mx number Posição X do mouse.
--- @param my number Posição Y do mouse.
--- @param currentHoverItem table|nil A instância do item atualmente sob o mouse (ou nil se nenhum).
function ItemDetailsModalManager.update(dt, mx, my, currentHoverItem)
    ItemDetailsModalManager.mouseX = mx
    ItemDetailsModalManager.mouseY = my

    if currentHoverItem and currentHoverItem.itemBaseId then
        if ItemDetailsModalManager.activeItem ~= currentHoverItem then
            local baseData = nil

            -- Para artefatos, usa os dados já fornecidos em _baseItemData
            if currentHoverItem.type == "artefact" and currentHoverItem._baseItemData then
                baseData = currentHoverItem._baseItemData
            else
                -- Para itens normais, busca no ItemDataManager
                local itemDataManager = ManagerRegistry:get("itemDataManager")
                if not itemDataManager then
                    error("[ItemDetailsModalManager.update] ERRO: ItemDataManager não encontrado.")
                end
                baseData = itemDataManager:getBaseItemData(currentHoverItem.itemBaseId)
            end

            if baseData then
                if currentHoverItem.modifiers then
                    baseData.modifiers = currentHoverItem.modifiers
                end

                ItemDetailsModalManager.activeItem = currentHoverItem
                ItemDetailsModalManager.activeBaseItemData = baseData
                ItemDetailsModalManager.isVisible = true
            else
                -- Se não encontrou baseData, considera como se não houvesse item válido
                ItemDetailsModalManager.hide()
            end
        end
    else
        -- Nenhum item sob o mouse, esconde o tooltip
        if ItemDetailsModalManager.isVisible then
            -- print("[HoverManager] Escondendo tooltip, nenhum item em hover.") -- DEBUG
            ItemDetailsModalManager.hide()
        end
    end
end

--- Desenha o tooltip ativo, se houver.
function ItemDetailsModalManager.draw()
    if ItemDetailsModalManager.isVisible and ItemDetailsModalManager.activeItem and ItemDetailsModalManager.activeBaseItemData then
        -- Adiciona playerStats e equippedItem como nil por enquanto, pois ExtractionSummaryScene não os tem
        -- Outras cenas (como InventoryScreen) podem precisar passar esses dados para HoverDetails
        ItemDetailsModal.draw(
            ItemDetailsModalManager.activeItem,
            ItemDetailsModalManager.activeBaseItemData,
            ItemDetailsModalManager.mouseX + ItemDetailsModalManager.offsetX,
            ItemDetailsModalManager.mouseY + ItemDetailsModalManager.offsetY,
            nil, -- playerStats (opcional)
            nil  -- equippedItem (opcional)
        )
    end
end

return ItemDetailsModalManager
