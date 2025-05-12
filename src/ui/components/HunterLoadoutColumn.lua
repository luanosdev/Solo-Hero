local ItemGridUI = require("src.ui.item_grid_ui")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")

local HunterInventoryColumn = {}

--- Desenha a coluna do Inventário/Mochila (Loadout).
---@param x number Posição X da coluna.
---@param y number Posição Y inicial do conteúdo da coluna.
---@param w number Largura da coluna.
---@param h number Altura total disponível para o conteúdo da coluna.
---@param loadoutManager LoadoutManager Instância do LoadoutManager.
---@param itemDataManager ItemDataManager Instância do ItemDataManager.
---@return table loadoutGridArea Retorna a área calculada da grade.
function HunterInventoryColumn.draw(x, y, w, h, loadoutManager, itemDataManager)
    local loadoutGridArea = { x = x, y = y, w = w, h = h } -- Define a área baseada nos parâmetros

    -- Desenha Grade do Loadout
    if loadoutManager and itemDataManager then
        local loadoutItems = loadoutManager:getItems()
        local loadoutRows, loadoutCols = loadoutManager:getDimensions()
        ItemGridUI.drawItemGrid(loadoutItems, loadoutRows, loadoutCols,
            x, y, w, h,           -- Usa diretamente x, y, w, h passados para a coluna
            itemDataManager, nil) -- nil para sectionInfo
    else
        -- Mensagem de erro se os managers não estiverem disponíveis
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: Loadout/Item Manager não inicializado!",
            x + w / 2, y + h / 2, 0, "center")
        love.graphics.setColor(colors.white)
    end

    -- Retorna a área calculada para possível uso (ex: detecção de drop)
    return loadoutGridArea
end

return HunterInventoryColumn
