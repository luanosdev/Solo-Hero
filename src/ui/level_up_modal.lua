local LevelUpModal = {
    visible = false,
    options = {},
    selectedOption = 1,
    player = nil,
    hoveredOption = nil
}

local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")

-- Atributos que podem ser melhorados
local ATTRIBUTES = {
    {
        name = "vida_maxima",
        displayName = "Vida Máxima",
        description = "Aumenta a vida máxima em 10%",
        icon = "♥"
    },
    {
        name = "dano",
        displayName = "Dano",
        description = "Aumenta o dano em 5%",
        icon = "⚔"
    },
    {
        name = "velocidade",
        displayName = "Velocidade",
        description = "Aumenta a velocidade em 5%",
        icon = "→"
    },
    {
        name = "defesa",
        displayName = "Defesa",
        description = "Aumenta a defesa em 5%",
        icon = "■"
    },
    {
        name = "velocidade_ataque",
        displayName = "Velocidade de Ataque",
        description = "Aumenta a velocidade de ataque em 5%",
        icon = "⚡"
    },
    {
        name = "chance_critico",
        displayName = "Chance Crítico",
        description = "Aumenta a chance de acerto crítico em 5%",
        icon = "🎯"
    },
    {
        name = "multiplicador_critico",
        displayName = "Multiplicador Crítico",
        description = "Aumenta o dano crítico em 5%",
        icon = "💥"
    }
}

function LevelUpModal:init(player)
    self.player = player
end

function LevelUpModal:show()
    self.visible = true
    self:generateOptions()
end

function LevelUpModal:hide()
    self.visible = false
end

function LevelUpModal:generateOptions()
    self.options = {}
    local availableAttributes = {}
    
    -- Copia os atributos disponíveis
    for _, attr in ipairs(ATTRIBUTES) do
        table.insert(availableAttributes, attr)
    end
    
    -- Seleciona 3 atributos aleatórios
    for i = 1, 3 do
        if #availableAttributes > 0 then
            local randomIndex = love.math.random(1, #availableAttributes)
            table.insert(self.options, availableAttributes[randomIndex])
            table.remove(availableAttributes, randomIndex)
        end
    end
end

function LevelUpModal:update(dt)
    if not self.visible then return end
    
    -- Navegação com setas
    if love.keyboard.isDown("up") then
        self.selectedOption = math.max(1, self.selectedOption - 1)
    elseif love.keyboard.isDown("down") then
        self.selectedOption = math.min(#self.options, self.selectedOption + 1)
    end
    
    -- Seleção com Enter
    if love.keyboard.isDown("return") then
        self:applyUpgrade(self.options[self.selectedOption].name)
        self:hide()
    end
    
    -- Atualiza a opção com hover do mouse
    local mouseX, mouseY = love.mouse.getPosition()
    self.hoveredOption = self:getOptionAtPosition(mouseX, mouseY)
    if self.hoveredOption then
        self.selectedOption = self.hoveredOption
    end
end

function LevelUpModal:getOptionAtPosition(x, y)
    local modalWidth = 500
    local modalHeight = 400
    local modalX = (love.graphics.getWidth() - modalWidth) / 2
    local modalY = (love.graphics.getHeight() - modalHeight) / 2
    
    for i, _ in ipairs(self.options) do
        local optionY = modalY + 120 + (i - 1) * 80
        local optionHeight = 70
        
        if x >= modalX + 20 and x <= modalX + modalWidth - 20 and
           y >= optionY and y <= optionY + optionHeight then
            return i
        end
    end
    
    return nil
end

function LevelUpModal:mousepressed(x, y, button)
    if not self.visible then return end
    
    if button == 1 then -- Left click
        local clickedOption = self:getOptionAtPosition(x, y)
        if clickedOption then
            self:applyUpgrade(self.options[clickedOption].name)
            self:hide()
        end
    end
end

function LevelUpModal:applyUpgrade(attribute)
    if attribute == "vida_maxima" then
        self.player.state:addAttributeBonus("health", 10)
    elseif attribute == "dano" then
        self.player.state:addAttributeBonus("damage", 5)
    elseif attribute == "velocidade" then
        self.player.state:addAttributeBonus("speed", 5)
    elseif attribute == "defesa" then
        self.player.state:addAttributeBonus("defense", 5)
    elseif attribute == "velocidade_ataque" then
        self.player.state:addAttributeBonus("attackSpeed", 5)
    elseif attribute == "chance_critico" then
        self.player.state:addAttributeBonus("criticalChance", 5)
    elseif attribute == "multiplicador_critico" then
        self.player.state:addAttributeBonus("criticalMultiplier", 5)
    end
end

function LevelUpModal:draw()
    if not self.visible then return end
    
    -- Desenha fundo semi-transparente
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Configurações do modal
    local modalWidth = 500
    local modalHeight = 400
    local modalX = (love.graphics.getWidth() - modalWidth) / 2
    local modalY = (love.graphics.getHeight() - modalHeight) / 2
    
    -- Desenha o frame do modal usando a função do ui_elements
    elements.drawWindowFrame(modalX, modalY, modalWidth, modalHeight, "Level Up!")
    
    -- Título
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(colors.window_title)
    love.graphics.printf("Escolha um atributo para melhorar:", 
        modalX + 20, modalY + 50, modalWidth - 40, "center")
    
    -- Opções
    love.graphics.setFont(fonts.main)
    for i, option in ipairs(self.options) do
        local optionY = modalY + 120 + (i - 1) * 80
        local optionHeight = 70
        
        -- Desenha o fundo da opção
        if i == self.selectedOption then
            love.graphics.setColor(colors.window_border[1], colors.window_border[2], colors.window_border[3], 0.3)
            love.graphics.rectangle("fill", 
                modalX + 20, optionY, 
                modalWidth - 40, optionHeight, 5, 5)
        end
        
        -- Ícone
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(option.icon, 
            modalX + 30, optionY + 10, 40, "left")
        
        -- Nome do atributo
        love.graphics.setColor(colors.window_title)
        love.graphics.printf(option.displayName, 
            modalX + 80, optionY + 10, modalWidth - 100, "left")
        
        -- Descrição
        love.graphics.setColor(colors.white)
        love.graphics.setFont(fonts.main_small)
        love.graphics.printf(option.description, 
            modalX + 80, optionY + 35, modalWidth - 100, "left")
    end
    
    -- Instruções
    love.graphics.setFont(fonts.main_small)
    love.graphics.setColor(colors.window_border[1], colors.window_border[2], colors.window_border[3], 0.7)
    love.graphics.printf("Use as setas ou o mouse para navegar e Enter/Clique para selecionar", 
        modalX, modalY + modalHeight - 40, modalWidth, "center")
end

return LevelUpModal 