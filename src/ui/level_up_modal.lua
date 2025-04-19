local LevelUpModal = {
    visible = false,
    options = {},
    selectedOption = 1,
    playerManager = nil,
    hoveredOption = nil,
    upgradeOptions = {},
    upgrades = {}
}

local elements = require("src.ui.ui_elements")
local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")

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
        name = "vida_fixa",
        displayName = "Vida Fixa",
        description = "Aumenta a vida máxima em 20 pontos",
        icon = "H",
        attribute = "fixed_health",
        bonus = 20
    },
    {
        name = "dano",
        displayName = "Dano",
        description = "Aumenta o dano em 10%",
        icon = "D",
        attribute = "damage",
        bonus = 10
    },
    {
        name = "velocidade",
        displayName = "Velocidade",
        description = "Aumenta a velocidade em 10%",
        icon = "S",
        attribute = "speed",
        bonus = 10
    },
    {
        name = "velocidade_fixa",
        displayName = "Velocidade Fixa",
        description = "Aumenta a velocidade em 3 m/s",
        icon = "F",
        attribute = "fixed_speed",
        bonus = 3
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
        name = "defesa_fixa",
        displayName = "Defesa Fixa",
        description = "Aumenta a defesa em 5 pontos",
        icon = "D",
        attribute = "fixed_defense",
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
        name = "chance_critico_fixa",
        displayName = "Chance Crítico Fixa",
        description = "Aumenta a chance de acerto crítico em 0.3x",
        icon = "C",
        attribute = "fixed_critical_chance",
        bonus = 0.3
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
        name = "multiplicador_critico_fixo",
        displayName = "Multiplicador Crítico Fixo",
        description = "Aumenta o dano crítico base em 0.3",
        icon = "M",
        attribute = "fixed_critical_multiplier",
        bonus = 3
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
        name = "regeneracao_vida_fixa",
        displayName = "Regeneração de Vida Fixa",
        description = "Aumenta a regeneração de vida em 0.1 HP/s",
        icon = "R",
        attribute = "fixed_health_regen",
        bonus = 0.1
    },
    {
        name = "ataque_multiplo",
        displayName = "Ataque Múltiplo",
        description = "Aumenta a chance de ataque múltiplo em 5%",
        icon = "X",
        attribute = "multiAttackChance",
        bonus = 5
    },
    {
        name = "ataque_multiplo_fixo",
        displayName = "Ataque Múltiplo Fixo",
        description = "Aumenta a chance de ataque múltiplo em 0.2x",
        icon = "X",
        attribute = "fixed_multi_attack",
        bonus = 0.2
    },
    {
        name = "area",
        displayName = "Área de Ataque",
        description = "Aumenta a área de ataque em 10%",
        icon = "A",
        attribute = "area",
        bonus = 10
    },
    {
        name = "alcance",
        displayName = "Alcance",
        description = "Aumenta o alcance do ataque em 10%",
        icon = "R",
        attribute = "range",
        bonus = 10
    }
}

function LevelUpModal:init(playerManager, inputManager)
    self.playerManager = playerManager
    self.inputManager = inputManager
    self.upgradeOptions = {}
    self.upgrades = {}
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
    if self.inputManager:isKeyPressed("up") or self.inputManager:isKeyPressed("w") then
        self.selectedOption = math.max(1, (self.selectedOption or 1) - 1)
        self.hoveredOption = nil -- Limpa o hover quando usa as setas
    elseif self.inputManager:isKeyPressed("down") or self.inputManager:isKeyPressed("s") then
        self.selectedOption = math.min(#self.options, (self.selectedOption or 1) + 1)
        self.hoveredOption = nil -- Limpa o hover quando usa as setas
    end
    
    -- Seleção com Enter
    if self.inputManager:isKeyPressed("return") and self.selectedOption then
        self:applyUpgrade(self.options[self.selectedOption])
        self:hide()
    end

    -- Verifica clique do mouse
    if self.inputManager.mouse.wasLeftButtonPressed then
        local clickedOption = self:getOptionAtPosition(self.inputManager.mouse.x, self.inputManager.mouse.y)
        if clickedOption then
            self.selectedOption = clickedOption
            self:applyUpgrade(self.options[clickedOption])
            self:hide()
        end
    end

    -- Atualiza a opção com hover do mouse
    local mouseX, mouseY = self.inputManager:getMousePosition()
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

function LevelUpModal:applyAttributeBonus(attribute)
    if attribute == "fixed_speed" then
        self.playerState:addAttributeBonus("speed", 0, self.attributes[attribute].bonus)
    elseif attribute == "fixed_health" then
        self.playerState:addAttributeBonus("health", 0, self.attributes[attribute].bonus)
    elseif attribute == "fixed_defense" then
        self.playerState:addAttributeBonus("defense", 0, self.attributes[attribute].bonus)
    elseif attribute == "fixed_health_regen" then
        self.playerState:addAttributeBonus("healthRegen", 0, self.attributes[attribute].bonus)
    elseif attribute == "fixed_critical_chance" then
        self.playerState:addAttributeBonus("criticalChance", 0, self.attributes[attribute].bonus)
    elseif attribute == "fixed_critical_multiplier" then
        self.playerState:addAttributeBonus("criticalMultiplier", 0, self.attributes[attribute].bonus)
    elseif attribute == "fixed_multi_attack" then
        self.playerState:addAttributeBonus("multiAttackChance", 0, self.attributes[attribute].bonus)
    else
        self.playerState:addAttributeBonus(attribute, self.attributes[attribute].bonus, 0)
    end
end

function LevelUpModal:draw()
    if not self.visible then return end
    
    -- Fundo escuro semi-transparente
    love.graphics.setColor(colors.window_bg[1], colors.window_bg[2], colors.window_bg[3], 0.8)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- Calcula posição central do modal
    local modalWidth = 500
    local modalHeight = 400
    local modalX = (love.graphics.getWidth() - modalWidth) / 2
    local modalY = (love.graphics.getHeight() - modalHeight) / 2

    -- Desenha o frame do modal
    elements.drawWindowFrame(modalX, modalY, modalWidth, modalHeight, "Level Up!")

    -- Desenha as opções de atributos
    for i, option in ipairs(self.options) do
        local optionY = modalY + 120 + (i - 1) * 80
        local optionHeight = 70
        local isSelected = i == self.selectedOption
        local isHovered = i == self.hoveredOption

        -- Define a cor baseada na seleção/hover
        if isSelected then
            love.graphics.setColor(colors.text_highlight)
        elseif isHovered then
            love.graphics.setColor(colors.text_label)
        else
            love.graphics.setColor(colors.text_main)
        end

        -- Desenha o ícone
        love.graphics.setFont(fonts.title)
        love.graphics.printf(
            option.icon,
            modalX + 30,
            optionY + 10,
            30,
            "center"
        )

        -- Desenha o nome e bônus
        local bonusText = ""
        if string.find(option.attribute, "fixed_") then
            bonusText = string.format("+%.1f", option.bonus)
        else
            bonusText = string.format("+%.1f%%", option.bonus)
        end

        love.graphics.setFont(fonts.main)
        love.graphics.printf(
            string.format("%s %s", option.displayName, bonusText),
            modalX + 70,
            optionY + 10,
            modalWidth - 100,
            "left"
        )

        -- Desenha a descrição
        love.graphics.setColor(colors.text_label)
        love.graphics.printf(
            option.description,
            modalX + 70,
            optionY + 35,
            modalWidth - 100,
            "left"
        )
    end

    -- Desenha as opções de upgrades
    if self.upgradeOptions and #self.upgradeOptions > 0 then
        for i, upgrade in ipairs(self.upgradeOptions) do
            local optionY = modalY + 120 + (#self.options + i - 1) * 80
            local optionHeight = 70
            local isSelected = #self.options + i == self.selectedOption
            local isHovered = #self.options + i == self.hoveredOption

            -- Define a cor baseada na seleção/hover
            if isSelected then
                love.graphics.setColor(colors.text_highlight)
            elseif isHovered then
                love.graphics.setColor(colors.text_label)
            else
                love.graphics.setColor(colors.text_main)
            end

            -- Desenha o ícone do upgrade
            love.graphics.setFont(fonts.title)
            love.graphics.printf(
                self.upgrades[upgrade] and self.upgrades[upgrade].icon or "U",
                modalX + 30,
                optionY + 10,
                30,
                "center"
            )

            -- Desenha o nome do upgrade
            love.graphics.setFont(fonts.main)
            love.graphics.printf(
                self.upgrades[upgrade] and self.upgrades[upgrade].name or "Upgrade",
                modalX + 70,
                optionY + 10,
                modalWidth - 100,
                "left"
            )

            -- Desenha a descrição do upgrade
            love.graphics.setColor(colors.text_label)
            love.graphics.printf(
                self.upgrades[upgrade] and self.upgrades[upgrade].description or "Descrição do upgrade",
                modalX + 70,
                optionY + 35,
                modalWidth - 100,
                "left"
            )
        end
    end
end

return LevelUpModal 