local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local EquipmentSection = require("src.ui.inventory.sections.equipment_section")

local HunterEquipmentColumn = {}

--- Desenha a coluna de Equipamento do caçador.
---@param x number Posição X da coluna.
---@param y number Posição Y inicial do conteúdo da coluna.
---@param w number Largura da coluna.
---@param h number Altura total disponível para o conteúdo da coluna.
---@param hunterManager HunterManager Instância do HunterManager.
---@param hunterId string ID do caçador.
---@return table equipmentSlotAreas Tabela com as áreas calculadas dos slots de equipamento.
function HunterEquipmentColumn.draw(x, y, w, h, hunterManager, hunterId)
    local equipmentSlotAreas = {} -- Cria tabela local para as áreas

    -- Desenha Seção de Equipamento/Runas
    -- Passa a tabela local 'equipmentSlotAreas' para ser preenchida por EquipmentSection:draw
    EquipmentSection:draw(x, y, w, h, hunterManager, equipmentSlotAreas, hunterId)

    -- DEBUG: Imprime a tabela antes de retornar
    -- print("[HunterEquipmentColumn] Returning slot areas:")
    -- for id, data in pairs(equipmentSlotAreas) do
    --     print(string.format("  SlotID: %s, Area: {x=%s, y=%s, w=%s, h=%s}",
    --         tostring(id), tostring(data.x), tostring(data.y), tostring(data.w), tostring(data.h)))
    -- end

    -- Retorna a tabela preenchida com as áreas dos slots
    return equipmentSlotAreas
end

return HunterEquipmentColumn
