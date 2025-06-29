-- src/ui/item_details_modal.lua
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local Formatters = require("src.utils.formatters")

local ItemDetailsModal = {
    isVisible = false,
    item = nil,
    -- inputManager = nil -- Removido, obter via ManagerRegistry se necessário
}

function ItemDetailsModal:show(itemToShow)
    if not itemToShow then return end
    self.item = itemToShow
    self.isVisible = true
    print("Mostrando detalhes para:", self.item.name or "Item desconhecido")
    -- TODO: Pausar o jogo ou bloquear input principal aqui?
    return true
end

function ItemDetailsModal:hide()
    self.isVisible = false
    self.item = nil
    -- TODO: Despausar o jogo?
end

function ItemDetailsModal:update(dt)
    if not self.isVisible then return end
    -- Lógica de update do modal, se houver (ex: hover nos botões)
end

function ItemDetailsModal:draw()
    if not self.isVisible or not self.item then return end

    -- Fundo escuro semi-transparente (como outros modais)
    love.graphics.setColor(colors.window_bg[1], colors.window_bg[2], colors.window_bg[3], 0.8)
    local gameW, gameH = ResolutionUtils.getGameDimensions()
    love.graphics.rectangle("fill", 0, 0, gameW, gameH)

    -- Calcula posição central do modal
    local modalWidth = 350  -- Largura menor que a seção anterior
    local modalHeight = 500 -- Altura ajustável
    local modalX = (ResolutionUtils.getGameWidth() - modalWidth) / 2
    local modalY = (ResolutionUtils.getGameHeight() - modalHeight) / 2

    -- Desenha o frame do modal (usando ui_elements)
    elements.drawWindowFrame(modalX, modalY, modalWidth, modalHeight, "Detalhes do Item")

    local padding = 15
    local currentY = modalY + fonts.title:getHeight() * 1.5 + padding -- Y abaixo do título da janela
    local w = modalWidth
    local x = modalX

    -- Desenha Ícone (Placeholder - usar dados de self.item)
    local iconSize = 64
    local iconX = x + (w - iconSize) / 2
    love.graphics.setColor(colors.slot_empty_bg)
    love.graphics.rectangle("fill", iconX, currentY, iconSize, iconSize, 3, 3)
    if elements and elements.drawRarityBorderAndGlow then
        elements.drawRarityBorderAndGlow(self.item.rarity or 'E', iconX, currentY, iconSize, iconSize)
    else
        local rarityColor = colors.rarity[self.item.rarity or 'E'] or colors.rarity['E']
        love.graphics.setLineWidth(2)
        love.graphics.setColor(rarityColor)
        love.graphics.rectangle("line", iconX, currentY, iconSize, iconSize, 3, 3)
        love.graphics.setLineWidth(1)
    end
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(colors.white)
    -- TODO: Usar ícone real do item se disponível
    love.graphics.printf(
        self.item.iconPlaceholder or string.sub(self.item.name or "?", 1, 1),
        iconX,
        currentY + iconSize * 0.25,
        iconSize,
        "center"
    )
    currentY = currentY + iconSize + padding

    -- Nome do Item
    love.graphics.setFont(fonts.details_title)
    local rarityColor = colors.rarity[self.item.rarity or 'E'] or colors.rarity['E']
    love.graphics.setColor(rarityColor)
    love.graphics.printf(self.item.name or "Item Desconhecido", x, currentY, w, "center")
    currentY = currentY + fonts.details_title:getHeight() * 1.2

    -- Tipo e Raridade
    love.graphics.setFont(fonts.main_small)
    love.graphics.setColor(colors.text_label)
    local typeText = string.format("Tipo: %s | Raridade: %s", self.item.type or "N/A", self.item.rarity or "N/A")
    love.graphics.printf(typeText, x, currentY, w, "center")
    currentY = currentY + fonts.main_small:getHeight() * 1.5

    -- Descrição
    love.graphics.setFont(fonts.tooltip)
    love.graphics.setColor(colors.text_main)
    local wrapLimit = w - padding * 2
    if wrapLimit > 0 then
        local wrappedDesc, lines = fonts.tooltip:getWrap(self.item.description or "", wrapLimit)
        -- print(string.format("DEBUG: getWrap result - Type: %s, Value: %s", type(wrappedDesc), tostring(wrappedDesc))) -- DEBUG
        if type(wrappedDesc) == "table" then
            for i, line in ipairs(wrappedDesc) do
                love.graphics.print(line, x + padding, currentY)
                currentY = currentY + fonts.tooltip:getHeight() * 1.1
            end
        else
            love.graphics.setColor(1, 0, 0, 1)
            love.graphics.print(string.format("AVISO: Desc getWrap: %s", type(wrappedDesc)), x + padding, currentY)
            currentY = currentY + (fonts.tooltip:getHeight() * 1.1 or 15)
        end
    else
        love.graphics.setColor(1, 0.5, 0, 1)
        love.graphics.print("(Largura insuficiente)", x + padding, currentY)
        currentY = currentY + (fonts.tooltip:getHeight() * 1.1 or 15)
    end
    currentY = currentY + padding

    -- Atributos/Stats
    if self.item.stats and type(self.item.stats) == "table" and #self.item.stats > 0 then
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.text_highlight)
        love.graphics.print("Atributos:", x + padding, currentY)
        currentY = currentY + fonts.main:getHeight() * 1.3
        love.graphics.setFont(fonts.main_small)
        for _, stat in ipairs(self.item.stats) do
            local statName = stat[1]
            local statValue = stat[2]
            local valueColor = colors.text_value
            local sign = statValue > 0 and "+" or ""
            if statValue < 0 then valueColor = colors.damage_player end

            love.graphics.setColor(colors.text_label)
            love.graphics.print(statName .. ":", x + padding, currentY)
            love.graphics.setColor(valueColor)
            love.graphics.printf(sign .. tostring(statValue), x + padding, currentY, w - padding * 2, "right")
            currentY = currentY + fonts.main_small:getHeight() * 1.2
        end
        currentY = currentY + padding
    end

    -- Modificadores de Atributos do Caçador
    if self.item.modifiers and type(self.item.modifiers) == "table" and #self.item.modifiers > 0 then
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.text_highlight)
        love.graphics.print("Modificadores:", x + padding, currentY)
        currentY = currentY + fonts.main:getHeight() * 1.3
        love.graphics.setFont(fonts.main_small)

        for _, mod in ipairs(self.item.modifiers) do
            local statLabel = Formatters.getStatLabel(mod.stat) or mod.stat
            local statValueStr = Formatters.formatStatValue(mod.stat, mod.value, mod.type)

            local valueColor = colors.positive
            local prefix = mod.value >= 0 and "+" or ""
            if mod.value < 0 then
                valueColor = colors.negative
            end

            love.graphics.setColor(colors.text_label)
            love.graphics.print(statLabel .. ":", x + padding, currentY)
            love.graphics.setColor(valueColor)
            love.graphics.printf(prefix .. statValueStr, x + padding, currentY, w - padding * 2, "right")
            currentY = currentY + fonts.main_small:getHeight() * 1.2
        end
        currentY = currentY + padding
    end

    -- Botões de Ação (Placeholders)
    local buttonW = (w - padding * 3) / 2
    local buttonH = 35
    local buttonY = modalY + modalHeight - buttonH - padding -- Baseado no Y/H do modal
    local equipButtonX = x + padding
    local dropButtonX = equipButtonX + buttonW + padding

    -- Botão Equipar/Usar (Placeholder)
    love.graphics.setColor(colors.text_highlight[1], colors.text_highlight[2], colors.text_highlight[3], 0.7)
    love.graphics.rectangle("fill", equipButtonX, buttonY, buttonW, buttonH, 3, 3)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.rectangle("line", equipButtonX, buttonY, buttonW, buttonH, 3, 3)
    love.graphics.setColor(colors.white)
    love.graphics.setFont(fonts.main)
    love.graphics.printf("Equipar", equipButtonX, buttonY + (buttonH - fonts.main:getHeight()) / 2, buttonW, "center")

    -- Botão Dropar (Placeholder)
    love.graphics.setColor(colors.damage_player[1], colors.damage_player[2], colors.damage_player[3], 0.7)
    love.graphics.rectangle("fill", dropButtonX, buttonY, buttonW, buttonH, 3, 3)
    love.graphics.setColor(colors.damage_player)
    love.graphics.rectangle("line", dropButtonX, buttonY, buttonW, buttonH, 3, 3)
    love.graphics.setColor(colors.white)
    love.graphics.setFont(fonts.main)
    love.graphics.printf("Dropar", dropButtonX, buttonY + (buttonH - fonts.main:getHeight()) / 2, buttonW, "center")
end

-- Input do Modal
function ItemDetailsModal:keypressed(key)
    if not self.isVisible then return false end

    if key == "escape" then
        self:hide()
        return true -- Input tratado
    end

    -- TODO: Adicionar navegação por botões?

    return true -- Consome input se o modal está visível
end

function ItemDetailsModal:mousepressed(x, y, button)
    if not self.isVisible then return false end

    -- TODO: Verificar clique nos botões Equipar/Dropar
    -- 1. Calcular área dos botões
    -- 2. Verificar se x,y está dentro de um botão
    -- 3. Executar ação correspondente (ex: chamar PlayerManager:equipItem(self.item) ou InventoryManager:removeItem(self.item))
    -- 4. Chamar self:hide()

    -- Verifica clique fora do modal para fechar (opcional)
    local modalWidth = 350
    local modalHeight = 500
    local modalX = (ResolutionUtils.getGameWidth() - modalWidth) / 2
    local modalY = (ResolutionUtils.getGameHeight() - modalHeight) / 2
    if not (x > modalX and x < modalX + modalWidth and y > modalY and y < modalY + modalHeight) then
        self:hide()
        return true -- Input tratado (clique fora)
    end

    -- Se o clique foi dentro mas não num botão, ainda consome
    print("ItemDetailsModal handled click")
    return true
end

return ItemDetailsModal
