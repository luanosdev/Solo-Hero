--[[
    Rune Choice Modal
    Modal que aparece quando o jogador pega uma runa, permitindo escolher qual habilidade usar
]]

local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local ManagerRegistry = require("src.managers.manager_registry")

local RuneChoiceModal = {
    playerManager = nil,
    inputManager = nil,
    floatingTextManager = nil,
    runeManager = nil,
    visible = false,
    rune = nil,
    abilities = {},
    selectedIndex = 1,
    hoveredOption = nil
}

--[[
    Inicializa o modal
    @param playerManager (table) Instância do PlayerManager.
    @param inputManager (table) Instância do InputManager.
    @param floatingTextManager (table) Instância do FloatingTextManager.
]]
function RuneChoiceModal:init(playerManager, inputManager, floatingTextManager)
    self.playerManager = playerManager
    self.inputManager = inputManager
    self.floatingTextManager = floatingTextManager
    -- Obtém o RuneManager do registro
    self.runeManager = ManagerRegistry:get("runeManager")
    print("RuneChoiceModal inicializado.")
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

    -- Keep Mouse Hover Logic
    local mouseX, mouseY = self.inputManager:getMousePosition()
    self.hoveredOption = self:getOptionAtPosition(mouseX, mouseY)
    -- Don't automatically change selectedIndex on hover
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
        local optionX = modalX + 20                        -- Added definition for optionX
        local optionWidth = modalWidth - 40                -- Added definition for optionWidth

        if x >= optionX and x <= optionX + optionWidth and -- Use defined variables
            y >= optionY and y <= optionY + optionHeight then
            return i
        end
    end

    return nil
end

--[[
    Aplica a habilidade selecionada.
    @param abilityClass Classe da habilidade a ser aplicada
]]
function RuneChoiceModal:applyAbility(abilityClass)
    if not abilityClass then return end

    -- Cria uma nova instância da habilidade
    local ability = setmetatable({}, { __index = abilityClass })

    -- Inicializa a habilidade com o jogador
    ability:init(self.playerManager)

    -- Chama o RuneManager para aplicar a habilidade, passando também a runa original
    if self.runeManager and self.runeManager.applyRuneAbility then
        -- Passa a instância da habilidade E o item runa original (self.rune)
        self.runeManager:applyRuneAbility(ability, self.rune)
        print(string.format("Habilidade '%s' (da runa '%s') aplicada via RuneManager.",
            ability.name or "Desconhecida", self.rune and self.rune.name or "Original Desconhecida"))

        -- Mostra mensagem de habilidade obtida
        self.floatingTextManager:addText(
            self.playerManager.player.position.x,
            self.playerManager.player.position.y - 30,
            "Nova Habilidade: " .. (ability.name or "Desconhecida"),
            true,
            self.playerManager.player.position,
            { 0, 1, 0 } -- Cor verde para habilidades
        )
    else
        print("ERRO [RuneChoiceModal]: RuneManager ou RuneManager:applyRuneAbility não encontrado!")
    end

    -- Esconde o modal após a tentativa de aplicar a habilidade
    self:hide()
end

-- Adiciona a função mousepressed que estava faltando
function RuneChoiceModal:mousepressed(x, y, button)
    print("[RuneChoiceModal:mousepressed] START - Visible:", self.visible)
    if not self.visible then return false end

    local clickedOption = self:getOptionAtPosition(x, y)
    print("[RuneChoiceModal:mousepressed] Clicked Option Index:", clickedOption)
    if clickedOption then
        print("[RuneChoiceModal:mousepressed] Calling applyAbility for index:", clickedOption)
        self:applyAbility(self.abilities[clickedOption])
        print("[RuneChoiceModal:mousepressed] Ability applied. Returning true.")
        return true -- Retorna true aqui!
    end
    print("[RuneChoiceModal:mousepressed] Click was not on an option. Returning false.")
    return false
end

-- ADICIONANDO A FUNÇÃO KEYPRESSED
function RuneChoiceModal:keypressed(key)
    print("[RuneChoiceModal:keypressed] START - Key:", key, "Visible:", self.visible)
    if not self.visible then return false end

    if key == "up" or key == "w" then
        self.selectedIndex = math.max(1, (self.selectedIndex or 1) - 1)
        self.hoveredOption = nil -- Clear mouse hover if using keyboard
        print("[RuneChoiceModal:keypressed] Navigated Up. SelectedIndex:", self.selectedIndex)
        return true              -- Key handled
    elseif key == "down" or key == "s" then
        self.selectedIndex = math.min(#self.abilities, (self.selectedIndex or 1) + 1)
        self.hoveredOption = nil -- Clear mouse hover if using keyboard
        print("[RuneChoiceModal:keypressed] Navigated Down. SelectedIndex:", self.selectedIndex)
        return true              -- Key handled
    elseif key == "return" or key == "kpenter" then
        if self.selectedIndex and self.abilities[self.selectedIndex] then
            print("[RuneChoiceModal:keypressed] Enter pressed. Applying ability index:", self.selectedIndex)
            self:applyAbility(self.abilities[self.selectedIndex])
            -- self:hide() is called within applyAbility
            return true -- Key handled
        else
            print("[RuneChoiceModal:keypressed] Enter pressed, but no valid option selected:", self.selectedIndex)
            return true -- Still handle the key, just do nothing
        end
    end

    -- If no relevant key was pressed, let InputManager continue
    print("[RuneChoiceModal:keypressed] Key not handled. Returning false.")
    return false
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
        local optionX = modalX + 20         -- Added optionX definition
        local optionWidth = modalWidth - 40 -- Added optionWidth definition

        local isSelectedByKey = (i == self.selectedIndex)
        local isHoveredByMouse = (i == self.hoveredOption)

        -- Desenha o fundo da opção com efeito de brilho/hover
        if isSelectedByKey or isHoveredByMouse then
            if isSelectedByKey then
                -- Highlight mais forte para seleção via teclado
                elements.drawRarityBorderAndGlow(self.rune.rarity, optionX, optionY, optionWidth, optionHeight)
                love.graphics.setColor(colors.window_border[1], colors.window_border[2], colors.window_border[3], 0.3)
                love.graphics.rectangle("fill", optionX, optionY, optionWidth, optionHeight, 5, 5)
            elseif isHoveredByMouse then
                -- Highlight mais suave para hover do mouse
                love.graphics.setColor(colors.slot_hover_bg[1], colors.slot_hover_bg[2], colors.slot_hover_bg[3], 0.5) -- Usando slot_hover_bg como exemplo
                love.graphics.rectangle("fill", optionX, optionY, optionWidth, optionHeight, 5, 5)
            end
        end

        -- Ícone (usando o primeiro caractere do nome da habilidade)
        love.graphics.setColor(1, 0.5, 0)                                           -- Cor laranja para runas
        love.graphics.printf(ability.name:sub(1, 1),
            optionX + 10, optionY + optionHeight / 2 - fonts.title:getHeight() / 2, -- Centraliza verticalmente
            40, "center")                                                           -- Ajusta a largura para centralizar melhor o ícone

        -- Define a cor do texto baseado na seleção/hover
        local textColor = (isSelectedByKey or isHoveredByMouse) and colors.text_highlight or colors.window_title
        love.graphics.setColor(textColor)
        love.graphics.setFont(fonts.main) -- Garante a fonte correta para o nome

        -- Nome da habilidade
        love.graphics.printf(ability.name,
            optionX + 60, optionY + 10, optionWidth - 70, "left")

        -- Descrição
        love.graphics.setColor(colors.white) -- Cor padrão para descrição
        love.graphics.setFont(fonts.main_small)
        love.graphics.printf(ability.description or "Uma nova habilidade poderosa",
            optionX + 60, optionY + 35, optionWidth - 70, "left")
    end

    -- Instruções
    love.graphics.setFont(fonts.main_small)
    love.graphics.setColor(colors.window_border[1], colors.window_border[2], colors.window_border[3], 0.7)
    love.graphics.printf("Use as setas ou clique para selecionar (Enter para confirmar)",
        modalX, modalY + modalHeight - 40, modalWidth, "center")
end

return RuneChoiceModal
