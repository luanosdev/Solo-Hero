local ItemGridUI = require("src.ui.item_grid_ui")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")

local HunterInventoryColumn = {}

--- Desenha a coluna do Inventário (Gameplay).
---@param x number Posição X da coluna.
---@param y number Posição Y inicial do conteúdo da coluna.
---@param w number Largura da coluna.
---@param h number Altura total disponível para o conteúdo da coluna.
---@param inventoryManager InventoryManager Instância do InventoryManager (gameplay).
---@param itemDataManager ItemDataManager Instância do ItemDataManager.
---@return table inventoryGridArea Retorna a área calculada da grade.
function HunterInventoryColumn.draw(x, y, w, h, inventoryManager, itemDataManager)
    local inventoryGridArea = { x = x, y = y, w = w, h = h } -- Define a área baseada nos parâmetros

    -- Desenha Grade do Inventário de Gameplay
    if inventoryManager and itemDataManager then
        -- <<< MODIFICADO: Chama métodos do inventoryManager >>>
        local inventoryItems = inventoryManager:getInventoryGridItems() -- Obtém itens formatados para UI
        local gridDims = inventoryManager:getGridDimensions()           -- Obtém {rows, cols}
        local invRows = gridDims and gridDims.rows
        local invCols = gridDims and gridDims.cols

        if invRows and invCols then
            ItemGridUI.drawItemGrid(inventoryItems, invRows, invCols,
                x, y, w, h,           -- Usa diretamente x, y, w, h passados para a coluna
                itemDataManager, nil) -- nil para sectionInfo
        else
            -- Erro se não conseguiu obter dimensões
            love.graphics.setColor(colors.red)
            love.graphics.printf("Erro: Dimensões Inválidas!", x + w / 2, y + h / 2, 0, "center")
            love.graphics.setColor(colors.white)
        end
    else
        -- Mensagem de erro se os managers não estiverem disponíveis
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: Inv/Item Manager!", x + w / 2, y + h / 2, 0, "center")
        love.graphics.setColor(colors.white)
    end

    -- Retorna a área calculada para possível uso (ex: detecção de drop)
    return inventoryGridArea
end

return HunterInventoryColumn
