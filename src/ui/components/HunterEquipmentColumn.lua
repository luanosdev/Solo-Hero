local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local EquipmentSection = require("src.ui.inventory.sections.equipment_section")
local elements = require("src.ui.ui_elements")    -- Adicionado para drawEmptySlotBackground e ícones
local Constants = require("src.config.constants") -- Adicionado para SLOT_IDS

local HunterEquipmentColumn = {}

--- Desenha a coluna de Equipamento do caçador.
---@param x number Posição X da coluna.
---@param y number Posição Y inicial do conteúdo da coluna.
---@param w number Largura da coluna.
---@param h number Altura total disponível para o conteúdo da coluna.
---@param hunterId string|nil ID do caçador (pode ser nil se overrideEquipmentData for usado).
---@param overrideEquipmentData table|nil Tabela de itens de equipamento para exibir (formato: {slotId = itemInstance}).
---@return table equipmentSlotClickAreas Tabela com as áreas calculadas dos slots de equipamento.
function HunterEquipmentColumn.draw(
    x,
    y,
    w,
    h,
    hunterId,
    overrideEquipmentData
)
    local equipmentSlotClickAreas = {}

    if overrideEquipmentData then
        -- Layout inspirado em EquipmentSection.lua
        local currentY = y
        local generalPadding = 5 -- Espaçamento geral
        local columnInnerWidth = w - generalPadding * 2
        local columnInnerX = x + generalPadding

        -- 1. Desenha Slots de Armadura (Grade 2x2 no topo)
        local armorSlotSize = math.min((columnInnerWidth - generalPadding) / 2, (h * 0.4 - generalPadding) / 2)
        armorSlotSize = math.max(armorSlotSize, 48)
        local armorGridWidth = armorSlotSize * 2 + generalPadding
        local armorGridStartX = columnInnerX + (columnInnerWidth - armorGridWidth) / 2

        local armorSlotsDefinition = {
            { slotId = Constants.SLOT_IDS.HELMET, label = "Cabeça" },
            { slotId = Constants.SLOT_IDS.CHEST,  label = "Peito" },
            { slotId = Constants.SLOT_IDS.LEGS,   label = "Pernas" },
            { slotId = Constants.SLOT_IDS.BOOTS,  label = "Pés" }
        }
        local armorGrid = { { armorSlotsDefinition[1], armorSlotsDefinition[2] }, { armorSlotsDefinition[3], armorSlotsDefinition[4] } }

        for r = 1, 2 do
            for c = 1, 2 do
                local slotDef = armorGrid[r][c]
                local slotId = slotDef.slotId
                local itemInstance = overrideEquipmentData[slotId]

                local slotX = armorGridStartX + (c - 1) * (armorSlotSize + generalPadding)
                local slotY = currentY + (r - 1) * (armorSlotSize + generalPadding)

                elements.drawEmptySlotBackground(slotX, slotY, armorSlotSize, armorSlotSize)
                if itemInstance and type(itemInstance) == "table" and itemInstance.icon then
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(
                        itemInstance.icon,
                        slotX,
                        slotY, 0,
                        armorSlotSize / itemInstance.icon:getWidth(),
                        armorSlotSize / itemInstance.icon:getHeight()
                    )
                    elements.drawRarityBorderAndGlow(
                        itemInstance.rarity or 'E',
                        slotX,
                        slotY,
                        armorSlotSize,
                        armorSlotSize
                    )
                else
                    -- Placeholder de texto para slot vazio
                    love.graphics.setFont(fonts.main_small or fonts.main)
                    love.graphics.setColor(colors.negative)
                    love.graphics.printf(
                        slotDef.label,
                        slotX,
                        slotY + armorSlotSize / 2 - fonts.main_small:getHeight() / 2,
                        armorSlotSize,
                        "center"
                    )
                    love.graphics.setColor(colors.white)
                end
                equipmentSlotClickAreas[slotId] = {
                    x = slotX,
                    y = slotY,
                    w = armorSlotSize,
                    h = armorSlotSize,
                    slotId = slotId,
                    item = itemInstance
                }
            end
        end
        currentY = currentY + 2 * armorSlotSize + generalPadding + generalPadding -- Avança Y

        -- 2. Desenha Slot da Arma (Abaixo da armadura)
        local weaponSlotH = armorSlotSize * 0.75 -- Um pouco menor em altura que os de armadura
        local weaponSlotW = armorGridWidth       -- Mesma largura da grade de armadura
        local weaponSlotX = armorGridStartX
        local weaponSlotY = currentY
        local weaponSlotId = Constants.SLOT_IDS.WEAPON
        local weaponInstance = overrideEquipmentData[weaponSlotId]

        elements.drawEmptySlotBackground(weaponSlotX, weaponSlotY, weaponSlotW, weaponSlotH)
        if weaponInstance and type(weaponInstance) == "table" and weaponInstance.icon then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(
                weaponInstance.icon,
                weaponSlotX,
                weaponSlotY,
                0,
                weaponSlotW / weaponInstance.icon:getWidth(),
                weaponSlotH / weaponInstance.icon:getHeight()
            )
            elements.drawRarityBorderAndGlow(
                weaponInstance.rarity or 'E',
                weaponSlotX,
                weaponSlotY,
                weaponSlotW,
                weaponSlotH
            )
        else
            love.graphics.setFont(fonts.main_small or fonts.main)
            love.graphics.setColor(colors.negative)
            love.graphics.printf(
                "Arma",
                weaponSlotX,
                weaponSlotY + weaponSlotH / 2 - fonts.main_small:getHeight() / 2,
                weaponSlotW, "center"
            )
            love.graphics.setColor(colors.white)
        end
        equipmentSlotClickAreas[weaponSlotId] = {
            x = weaponSlotX,
            y = weaponSlotY,
            w = weaponSlotW,
            h = weaponSlotH,
            slotId = weaponSlotId,
            item = weaponInstance
        }
        currentY = currentY + weaponSlotH + generalPadding

        -- 3. Desenha Slots de Runa (Linearmente abaixo, por enquanto)
        local runeSlotSize = armorSlotSize * 0.6
        local runesStartX = columnInnerX +
            (columnInnerWidth - (runeSlotSize * 3 + generalPadding * 2)) /
            2 -- Tenta centralizar 3 runas
        local runeIndex = 0
        Logger.debug("HunterEquipmentColumn.draw", "overrideEquipmentData" .. overrideEquipmentData)
        for slotKey, itemInstance in pairs(overrideEquipmentData) do
            if string.sub(slotKey, 1, #Constants.SLOT_IDS.RUNE_PREFIX) == Constants.SLOT_IDS.RUNE_PREFIX then
                local slotX = runesStartX + runeIndex * (runeSlotSize + generalPadding)
                if slotX + runeSlotSize > columnInnerX + columnInnerWidth then -- Quebra linha se não couber
                    currentY = currentY + runeSlotSize + generalPadding
                    slotX = runesStartX
                    runeIndex = 0
                end
                local slotY = currentY

                if slotY + runeSlotSize > y + h then break end -- Impede de desenhar fora da altura da coluna

                elements.drawEmptySlotBackground(slotX, slotY, runeSlotSize, runeSlotSize)
                if itemInstance and type(itemInstance) == "table" and itemInstance.icon then
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(itemInstance.icon, slotX, slotY, 0,
                        runeSlotSize / itemInstance.icon:getWidth(), runeSlotSize / itemInstance.icon:getHeight())
                    elements.drawRarityBorderAndGlow(itemInstance.rarity or 'E', slotX, slotY, runeSlotSize, runeSlotSize)
                else
                    love.graphics.setFont(fonts.main_very_small or fonts.main_small)
                    love.graphics.setColor(colors.negative)
                    love.graphics.printf(slotKey, slotX,
                        slotY + runeSlotSize / 2 - (fonts.main_very_small or fonts.main_small):getHeight() / 2,
                        runeSlotSize, "center")
                    love.graphics.setColor(colors.white)
                end
                equipmentSlotClickAreas[slotKey] = {
                    x = slotX,
                    y = slotY,
                    w = runeSlotSize,
                    h = runeSlotSize,
                    slotId =
                        slotKey,
                    item = itemInstance
                }
                runeIndex = runeIndex + 1
            end
        end
        -- currentY = currentY + runeSlotSize + generalPadding -- Atualiza Y se houver runas
    else
        EquipmentSection:draw(x, y, w, h, equipmentSlotClickAreas, hunterId)
    end

    return equipmentSlotClickAreas
end

return HunterEquipmentColumn
