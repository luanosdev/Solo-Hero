local LevelUpModal = {
    visible = false,
    options = {},
    selectedOption = 1,
    playerManager = nil,
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
        icon = "H",
        attribute = "health",
        bonus = 10
    },
    {
        name = "dano",
        displayName = "Dano",
        description = "Aumenta o dano em 5%",
        icon = "D",
        attribute = "damage",
        bonus = 5
    },
    {
        name = "velocidade",
        displayName = "Velocidade",
        description = "Aumenta a velocidade em 5%",
        icon = "S",
        attribute = "speed",
        bonus = 5
    },
    {
        name = "defesa",
        displayName = "Defesa",
        description = "Aumenta a defesa em 5%",
        icon = "D",
        attribute = "defense",
        bonus = 5
    },
    {
        name = "velocidade_ataque",
        displayName = "Velocidade de Ataque",
        description = "Aumenta a velocidade de ataque em 5%",
        icon = "A",
        attribute = "attackSpeed",
        bonus = 5
    },
    {
        name = "chance_critico",
        displayName = "Chance Crítico",
        description = "Aumenta a chance de acerto crítico em 5%",
        icon = "C",
        attribute = "criticalChance",
        bonus = 5
    },
    {
        name = "multiplicador_critico",
        displayName = "Multiplicador Crítico",
        description = "Aumenta o dano crítico em 5%",
        icon = "M",
        attribute = "criticalMultiplier",
        bonus = 5
    },
    {
        name = "regeneracao_vida",
        displayName = "Regeneração de Vida",
        description = "Aumenta a regeneração de vida em 5%",
        icon = "R",
        attribute = "healthRegen",
        bonus = 5
    },
    {
        name = "ataque_multiplo",
        displayName = "Ataque Múltiplo",
        description = "Aumenta a chance de ataque múltiplo em 5%",
        icon = "X",
        attribute = "multiAttackChance",
        bonus = 5
    }
}

function LevelUpModal:init(playerManager)
    self.playerManager = playerManager
    print("[LevelUpModal] Inicializado com PlayerManager:", playerManager and "OK" or "NULO")
end

function LevelUpModal:show()
    self.visible = true
    self.selectedOption = nil -- Reseta a opção selecionada
    self:generateOptions()
end

function LevelUpModal:hide()
    self.visible = false
    -- Reseta as fontes para o padrão
    love.graphics.setFont(fonts.main)
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

function LevelUpModal:update()
    if not self.visible then return end
    
    -- Navegação com setas
    if love.keyboard.isDown("up") then
        self.selectedOption = math.max(1, self.selectedOption - 1)
        self.hoveredOption = nil -- Limpa o hover quando usa as setas
    elseif love.keyboard.isDown("down") then
        self.selectedOption = math.min(#self.options, self.selectedOption + 1)
        self.hoveredOption = nil -- Limpa o hover quando usa as setas
    end
    
    -- Seleção com Enter
    if love.keyboard.isDown("return") then
        self:applyUpgrade(self.options[self.selectedOption])
        self:hide()
    end
    
    -- Atualiza a opção com hover do mouse
    local mouseX, mouseY = love.mouse.getPosition()
    local hoveredOption = self:getOptionAtPosition(mouseX, mouseY)
    
    -- Se o mouse estiver sobre uma opção, atualiza o hoveredOption
    if hoveredOption then
        self.hoveredOption = hoveredOption
    else
        self.hoveredOption = nil
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
        local optionX = modalX + 20
        local optionWidth = modalWidth - 40
        
        if x >= optionX and x <= optionX + optionWidth and
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
            self.selectedOption = clickedOption
            self:applyUpgrade(self.options[clickedOption])
            self:hide()
        end
    end
end

function LevelUpModal:applyUpgrade(option)
    if not self.playerManager or not self.playerManager.state then return end
    
    -- Aplica o bônus ao atributo
    self.playerManager.state:addAttributeBonus(option.attribute, option.bonus)
    
    -- Atualiza os valores totais se necessário
    if option.attribute == "health" then
        self.playerManager.state.maxHealth = self.playerManager.state:getTotalHealth()
        self.playerManager.state.currentHealth = self.playerManager.state.maxHealth
    end
end

function LevelUpModal:draw()
    if not self.visible then return end
    
    -- Salva a fonte atual
    local currentFont = love.graphics.getFont()
    
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
        local isSelected = i == self.selectedOption
        local isHovered = i == self.hoveredOption
        
        if isSelected or isHovered then
            love.graphics.setColor(colors.window_border[1], colors.window_border[2], colors.window_border[3], 0.3)
            love.graphics.rectangle("fill", 
                modalX + 20, optionY, 
                modalWidth - 40, optionHeight, 5, 5)
        end
        
        -- Ícone
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.title) -- Usa a fonte title para o ícone
        local iconWidth = fonts.title:getWidth(option.icon)
        local iconHeight = fonts.title:getHeight()
        love.graphics.printf(option.icon, 
            modalX + 30, optionY + (optionHeight - iconHeight)/2, 40, "center")
        
        -- Nome do atributo
        love.graphics.setFont(fonts.main)
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
    
    -- Restaura a fonte original
    love.graphics.setFont(currentFont)
end

return LevelUpModal 