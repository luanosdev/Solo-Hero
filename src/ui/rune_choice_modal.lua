--[[
    Rune Choice Modal
    Modal que aparece quando o jogador pega uma runa, permitindo escolher qual habilidade usar
]]

local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local FloatingTextManager = require("src.managers.floating_text_manager")

local RuneChoiceModal = {
    playerManager = nil,
    visible = false,
    rune = nil,
    abilities = {},
    selectedIndex = 1,
    hoveredOption = nil
}

--[[
    Inicializa o modal
]]
function RuneChoiceModal:init(playerManager)
    self.playerManager = playerManager
end

--[[
    Mostra o modal com as opções de habilidade da runa
    @param rune A runa que foi coletada
]]
function RuneChoiceModal:show(rune)
    self.visible = true
    self.rune = rune
    self.abilities = rune.abilities
    self.selectedIndex = 1
end

--[[
    Esconde o modal
]]
function RuneChoiceModal:hide()
    self.visible = false
end

--[[
    Atualiza o estado do modal
    @param dt Delta time
]]
function RuneChoiceModal:update()
    if not self.visible then return end
    
    -- Atualiza a opção com hover do mouse
    local mouseX, mouseY = love.mouse.getPosition()
    self.hoveredOption = self:getOptionAtPosition(mouseX, mouseY)
    if self.hoveredOption then
        self.selectedIndex = self.hoveredOption
    end
end

--[[
    Obtém a opção na posição do mouse
    @param x Posição X do mouse
    @param y Posição Y do mouse
    @return number Índice da opção ou nil
]]
function RuneChoiceModal:getOptionAtPosition(x, y)
    local modalWidth = 500
    local modalHeight = 400
    local modalX = (love.graphics.getWidth() - modalWidth) / 2
    local modalY = (love.graphics.getHeight() - modalHeight) / 2
    
    for i, _ in ipairs(self.abilities) do
        local optionY = modalY + 120 + (i - 1) * 80
        local optionHeight = 70
        
        if x >= modalX + 20 and x <= modalX + modalWidth - 20 and
           y >= optionY and y <= optionY + optionHeight then
            return i
        end
    end
    
    return nil
end

--[[
    Lida com cliques do mouse
    @param x Posição X do mouse
    @param y Posição Y do mouse
    @param button Botão do mouse pressionado
]]
function RuneChoiceModal:mousepressed(x, y, button)
    if not self.visible or button ~= 1 then return end
    
    local clickedOption = self:getOptionAtPosition(x, y)
    if clickedOption then
        self:applyAbility(self.abilities[clickedOption])
        self:hide()
    end
end

--[[
    Aplica a habilidade selecionada ao jogador
    @param abilityClass Classe da habilidade a ser aplicada
]]
function RuneChoiceModal:applyAbility(abilityClass)
    if not abilityClass then return end
    
    -- Cria uma nova instância da habilidade
    local ability = setmetatable({}, { __index = abilityClass })
    
    -- Inicializa a habilidade com o jogador
    ability:init(self.playerManager)
    
    -- Adiciona a habilidade ao jogador
    self.playerManager.addRune(ability)
    
    -- Mostra mensagem de habilidade obtida
    FloatingTextManager:addText(
        self.playerManager.player.position.x,
        self.playerManager.player.position.y - self.playerManager.player.radius - 30,
        "Nova Habilidade: " .. ability.name,
        true,
        self.playerManager.player.position,
        {0, 1, 0} -- Cor verde para habilidades
    )
    
    -- Esconde o modal após aplicar a habilidade
    self:hide()
end

--[[
    Desenha o modal
]]
function RuneChoiceModal:draw()
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
    elements.drawWindowFrame(modalX, modalY, modalWidth, modalHeight, "Nova Runa!")
    
    -- Título
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(colors.window_title)
    love.graphics.printf("Escolha uma habilidade:", 
        modalX + 20, modalY + 50, modalWidth - 40, "center")
    
    -- Opções
    love.graphics.setFont(fonts.main)
    for i, ability in ipairs(self.abilities) do
        local optionY = modalY + 120 + (i - 1) * 80
        local optionHeight = 70
        local optionWidth = modalWidth - 40
        
        -- Desenha o fundo da opção com efeito de brilho se selecionada
        if i == self.selectedIndex then
            elements.drawRarityBorderAndGlow("rare", modalX + 20, optionY, optionWidth, optionHeight)
            love.graphics.setColor(colors.window_border[1], colors.window_border[2], colors.window_border[3], 0.3)
            love.graphics.rectangle("fill", 
                modalX + 20, optionY, 
                optionWidth, optionHeight, 5, 5)
        end
        
        -- Ícone (usando o primeiro caractere do nome da habilidade)
        love.graphics.setColor(1, 0.5, 0) -- Cor laranja para runas
        local icon = ability.name:sub(1, 1)
        love.graphics.printf(icon, 
            modalX + 30, optionY + 10, 40, "left")
        
        -- Nome da habilidade
        love.graphics.setColor(colors.window_title)
        love.graphics.printf(ability.name, 
            modalX + 80, optionY + 10, modalWidth - 100, "left")
        
        -- Descrição
        love.graphics.setColor(colors.white)
        love.graphics.setFont(fonts.main_small)
        love.graphics.printf(ability.description or "Uma nova habilidade poderosa", 
            modalX + 80, optionY + 35, modalWidth - 100, "left")
    end
    
    -- Instruções
    love.graphics.setFont(fonts.main_small)
    love.graphics.setColor(colors.window_border[1], colors.window_border[2], colors.window_border[3], 0.7)
    love.graphics.printf("Clique em uma habilidade para selecionar", 
        modalX, modalY + modalHeight - 40, modalWidth, "center")
end

return RuneChoiceModal 