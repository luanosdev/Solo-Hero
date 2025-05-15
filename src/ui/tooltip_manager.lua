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
TooltipManager.hoveredElementOwner = nil -- Para identificar quem pediu o tooltip (ex: "equipment_screen_storage")

--- Mostra o tooltip para um item específico.
--- @param item table A instância do item.
--- @param mx number Posição X do mouse.
--- @param my number Posição Y do mouse.
--- @param owner string Identificador de quem está solicitando o tooltip.
function TooltipManager.show(item, mx, my, owner)
    if not item or not item.itemBaseId then
        TooltipManager.hide()
        return
    end

    local itemDataManager = ManagerRegistry:get("itemDataManager")
    if not itemDataManager then
        print("[TooltipManager.show] ERRO: ItemDataManager não encontrado no ManagerRegistry.")
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
    TooltipManager.hoveredElementOwner = owner
end

--- Esconde o tooltip.
--- @param owner string|nil Se fornecido, só esconde se o owner for o mesmo que ativou.
function TooltipManager.requestHide(owner)
    if owner == nil or TooltipManager.hoveredElementOwner == owner then
        TooltipManager.activeItem = nil
        TooltipManager.activeBaseItemData = nil
        TooltipManager.isVisible = false
        TooltipManager.hoveredElementOwner = nil
    end
end

-- Função para forçar o hide, independente do owner (usado ao iniciar drag, por exemplo)
function TooltipManager.hide()
    TooltipManager.activeItem = nil
    TooltipManager.activeBaseItemData = nil
    TooltipManager.isVisible = false
    TooltipManager.hoveredElementOwner = nil
end

--- Atualiza a posição do mouse.
--- @param dt number Delta time.
--- @param mx number Posição X do mouse.
--- @param my number Posição Y do mouse.
function TooltipManager.update(dt, mx, my)
    if TooltipManager.isVisible then
        TooltipManager.mouseX = mx
        TooltipManager.mouseY = my
    end
end

--- Desenha o tooltip ativo, se houver.
function TooltipManager.draw()
    if TooltipManager.isVisible and TooltipManager.activeItem and TooltipManager.activeBaseItemData then
        ItemTooltip.draw(
            TooltipManager.activeItem,
            TooltipManager.activeBaseItemData,
            TooltipManager.mouseX + TooltipManager.offsetX,
            TooltipManager.mouseY + TooltipManager.offsetY
        )
    end
end

return TooltipManager
