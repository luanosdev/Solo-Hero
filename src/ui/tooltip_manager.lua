---@class TooltipManager
local TooltipManager = {}

local ItemTooltip = require("src.ui.item_tooltip")
local ManagerRegistry = require("src.managers.manager_registry")

TooltipManager.activeItem = nil
TooltipManager.activeBaseItemData = nil
TooltipManager.mouseX = 0
TooltipManager.mouseY = 0
TooltipManager.offsetX = 15 -- Pequeno offset para o tooltip não ficar exatamente sob o mouse
TooltipManager.offsetY = 15
TooltipManager.isVisible = false
-- TooltipManager.hoveredElementOwner = nil -- Removido, pois a lógica de owner será simplificada ou tratada por quem chama show/hide diretamente.

--- Mostra o tooltip para um item específico. (Pode ser usado por UIs que precisam de controle mais fino)
--- @param item table A instância do item.
--- @param mx number Posição X do mouse.
--- @param my number Posição Y do mouse.
--- @param owner string|nil Identificador opcional de quem está solicitando o tooltip.
function TooltipManager.show(item, mx, my, owner) -- Owner é opcional agora
    if not item or not item.itemBaseId then
        TooltipManager.hide()
        return
    end

    local itemDataManager = ManagerRegistry:get("itemDataManager")
    if not itemDataManager then
        print("[TooltipManager.show] ERRO: ItemDataManager não encontrado.")
        TooltipManager.hide()
        return
    end
    local baseData = itemDataManager:getBaseItemData(item.itemBaseId)

    if not baseData then
        TooltipManager.hide()
        return
    end

    TooltipManager.activeItem = item
    TooltipManager.activeBaseItemData = baseData
    TooltipManager.mouseX = mx
    TooltipManager.mouseY = my
    TooltipManager.isVisible = true
    -- TooltipManager.hoveredElementOwner = owner -- Removido
end

--- Esconde o tooltip.
function TooltipManager.hide()
    TooltipManager.activeItem = nil
    TooltipManager.activeBaseItemData = nil
    TooltipManager.isVisible = false
    -- TooltipManager.hoveredElementOwner = nil -- Removido
end

-- TooltipManager.requestHide foi removido pois sua lógica agora está em update ou hide direto.

--- Atualiza o estado e a posição do tooltip com base no item atualmente sob o mouse.
--- @param dt number Delta time.
--- @param mx number Posição X do mouse.
--- @param my number Posição Y do mouse.
--- @param currentHoverItem table|nil A instância do item atualmente sob o mouse (ou nil se nenhum).
function TooltipManager.update(dt, mx, my, currentHoverItem)
    TooltipManager.mouseX = mx
    TooltipManager.mouseY = my

    if currentHoverItem and currentHoverItem.itemBaseId then
        if TooltipManager.activeItem ~= currentHoverItem then -- Só atualiza se o item mudou
            local itemDataManager = ManagerRegistry:get("itemDataManager")
            if not itemDataManager then
                print("[TooltipManager.update] ERRO: ItemDataManager não encontrado.")
                TooltipManager.hide() -- Esconde se não puder obter dados
                return
            end
            local baseData = itemDataManager:getBaseItemData(currentHoverItem.itemBaseId)
            if baseData then
                TooltipManager.activeItem = currentHoverItem
                TooltipManager.activeBaseItemData = baseData
                TooltipManager.isVisible = true
                -- print(string.format("[TooltipManager] Mostrando tooltip para: %s", currentHoverItem.itemBaseId)) -- DEBUG
            else
                -- Se não encontrou baseData, considera como se não houvesse item válido
                TooltipManager.hide()
            end
        end
    else
        -- Nenhum item sob o mouse, esconde o tooltip
        if TooltipManager.isVisible then -- Só loga/esconde se estava visível
            -- print("[TooltipManager] Escondendo tooltip, nenhum item em hover.") -- DEBUG
            TooltipManager.hide()
        end
    end
end

--- Desenha o tooltip ativo, se houver.
function TooltipManager.draw()
    if TooltipManager.isVisible and TooltipManager.activeItem and TooltipManager.activeBaseItemData then
        -- Adiciona playerStats e equippedItem como nil por enquanto, pois ExtractionSummaryScene não os tem
        -- Outras cenas (como InventoryScreen) podem precisar passar esses dados para ItemTooltip
        ItemTooltip.draw(
            TooltipManager.activeItem,
            TooltipManager.activeBaseItemData,
            TooltipManager.mouseX + TooltipManager.offsetX,
            TooltipManager.mouseY + TooltipManager.offsetY,
            nil, -- playerStats (opcional)
            nil  -- equippedItem (opcional)
        )
    end
end

return TooltipManager
