local elements = require("src.ui.ui_elements")
local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local LevelUpBonusesData = require("src.data.level_up_bonuses_data")

local LevelUpModal = {
    visible = false,
    options = {}, -- Agora vai armazenar as definições completas dos bônus de LevelUpBonusesData
    selectedOption = 1,
    playerManager = nil,
    hoveredOption = nil,
}

function LevelUpModal:init(playerManager, inputManager)
    self.playerManager = playerManager
    self.inputManager = inputManager
    print("[LevelUpModal] Inicializado com PlayerManager:", playerManager and "OK" or "NULO")
end

function LevelUpModal:show()
    self.visible = true
    self.selectedOption = nil -- Reseta a opção selecionada
    self:generateOptions()    -- Chama para gerar as opções
end

function LevelUpModal:hide()
    self.visible = false
    -- Reseta as fontes para o padrão
    love.graphics.setFont(fonts.main)
end

function LevelUpModal:generateOptions()
    self.options = {}
    local availableBonuses = {}

    if not self.playerManager or not self.playerManager.state or not self.playerManager.state.learnedLevelUpBonuses then
        error("ERRO [LevelUpModal:generateOptions]: PlayerManager ou learnedLevelUpBonuses não está pronto.")
    end

    local learned = self.playerManager.state.learnedLevelUpBonuses

    -- Itera sobre todos os bônus definidos em LevelUpBonusesData.Bonuses
    for bonusId, bonusData in pairs(LevelUpBonusesData.Bonuses) do
        local currentLevel = learned[bonusId] or 0
        if currentLevel < bonusData.max_level then
            -- Adiciona uma cópia dos dados do bônus para evitar modificar o original,
            -- e podemos adicionar o nível atual para fácil acesso na UI se necessário.
            local optionData = {} -- Cópia rasa (shallow copy)
            for k, v in pairs(bonusData) do
                optionData[k] = v
            end
            optionData.current_level_for_display = currentLevel -- Para UI
            table.insert(availableBonuses, optionData)
        end
    end

    -- Seleciona até 3 bônus aleatórios da lista de disponíveis
    local numToSelect = math.min(3, #availableBonuses)
    for i = 1, numToSelect do
        if #availableBonuses > 0 then
            local randomIndex = love.math.random(1, #availableBonuses)
            table.insert(self.options, availableBonuses[randomIndex])
            table.remove(availableBonuses, randomIndex)
        else
            break -- Não há mais bônus disponíveis para selecionar
        end
    end

    if #self.options == 0 then
        print(
            "AVISO [LevelUpModal:generateOptions]: Nenhuma opção de bônus disponível para o nível atual ou todos no máx.")
        -- Opcional: Adicionar uma opção "Pular" ou "Pegar Ouro" se nenhuma melhoria estiver disponível.
    end
end

function LevelUpModal:update()
    if not self.visible then return end

    -- Keep Mouse Hover Logic
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

function LevelUpModal:applyUpgrade(optionData) -- Renomeado para clareza que é o full data do bônus
    if not self.playerManager or not self.playerManager.state then
        error("ERRO [LevelUpModal:applyUpgrade]: PlayerManager ou PlayerState não está pronto.")
    end

    if not optionData or not optionData.id then
        error("ERRO [LevelUpModal:applyUpgrade]: optionData inválido ou sem ID.")
    end

    -- 1. Aplica os modificadores de atributos usando a função de LevelUpBonusesData
    LevelUpBonusesData.ApplyBonus(self.playerManager.state, optionData.id)

    -- 2. Atualiza o nível do bônus aprendido no PlayerState
    local bonusId = optionData.id
    local learnedBonuses = self.playerManager.state.learnedLevelUpBonuses
    learnedBonuses[bonusId] = (learnedBonuses[bonusId] or 0) + 1
    self.playerManager:invalidateStatsCache()

    print(string.format("[LevelUpModal:applyUpgrade] Bônus '%s' (ID: %s) aplicado. Novo nível: %d",
        optionData.name, bonusId, learnedBonuses[bonusId]))
end

function LevelUpModal:draw()
    if not self.visible then return end

    -- Fundo escuro semi-transparente
    love.graphics.setColor(colors.window_bg[1], colors.window_bg[2], colors.window_bg[3], 0.8)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    -- Calcula posição central do modal
    local modalWidth = 550
    local modalHeight = 450
    local modalX = (love.graphics.getWidth() - modalWidth) / 2
    local modalY = (love.graphics.getHeight() - modalHeight) / 2

    -- Desenha o frame do modal
    elements.drawWindowFrame(modalX, modalY, modalWidth, modalHeight, "Level Up!")

    -- Desenha as opções de atributos
    local optionStartY = modalY + 90 -- Ajustado para título
    local optionHeight = 100         -- Aumentado para mais detalhes
    local optionGap = 15

    for i, optionData in ipairs(self.options) do
        local currentOptionY = optionStartY + (i - 1) * (optionHeight + optionGap)
        local optionX = modalX + 20
        local optionY = currentOptionY
        local optionWidth = modalWidth - 40

        local isSelectedByKey = (i == self.selectedOption)
        local isHoveredByMouse = (i == self.hoveredOption)

        local bgColor = nil
        local textColor = colors.text_main
        local nameColor = colors.text_highlight -- Cor para o nome da melhoria

        if isSelectedByKey then
            elements.drawRarityBorderAndGlow('S', optionX, optionY, optionWidth, optionHeight) -- Usar rank/tier do bônus?
            bgColor = { colors.window_border[1], colors.window_border[2], colors.window_border[3], 0.3 }
            textColor = colors.text_highlight
            nameColor = colors.text_selected -- Nome mais destacado se selecionado
        elseif isHoveredByMouse then
            bgColor = { colors.slot_hover_bg[1], colors.slot_hover_bg[2], colors.slot_hover_bg[3], 0.5 }
            textColor = colors.text_highlight
            nameColor = colors.text_hover -- Nome destacado no hover
        end

        if bgColor then
            love.graphics.setColor(bgColor)
            love.graphics.rectangle("fill", optionX, currentOptionY, optionWidth, optionHeight, 5, 5)
        end

        -- Ícone
        love.graphics.setFont(fonts.title) -- Fonte maior para ícone
        love.graphics.setColor(textColor)
        love.graphics.printf(optionData.icon or "?", optionX + 15,
            currentOptionY + optionHeight / 2 - fonts.title:getHeight() / 2, 40, "center")

        local textStartX = optionX + 65
        local textWidth = optionWidth - 80 -- Espaço para texto (descontando ícone e paddings)

        -- Nome da Melhoria e Nível
        love.graphics.setFont(fonts.hud) -- Fonte um pouco maior para o nome
        love.graphics.setColor(nameColor)
        local currentDisplayLevel = (optionData.current_level_for_display or 0)
        local nextLevel = currentDisplayLevel + 1
        local nameText = string.format("%s (Nv. %d/%d)", optionData.name, nextLevel, optionData.max_level)
        love.graphics.printf(nameText, textStartX, currentOptionY + 10, textWidth, "left")

        -- Descrição Formatada
        love.graphics.setFont(fonts.main_small)
        love.graphics.setColor(textColor) -- Usar textColor normal para descrição

        local description = optionData.description_template or ""
        -- Tenta substituir placeholders na descrição
        if optionData.modifiers_per_level then
            for idx, mod in ipairs(optionData.modifiers_per_level) do
                local valueString = ""
                if mod.type == "fixed" then
                    valueString = string.format("%.1f", mod.value):gsub("%.0$", "") -- Remove .0
                elseif mod.type == "percentage" then
                    valueString = string.format("%.1f", mod.value):gsub("%.0$", "") .. "%"
                elseif mod.type == "fixed_percentage_as_fraction" then
                    valueString = string.format("%.1f", mod.value * 100):gsub("%.0$", "") .. "%"
                else
                    valueString = tostring(mod.value)
                end

                local placeholder = "{value" .. (idx > 1 and tostring(idx) or "") .. "}" -- {value} ou {value1}, {value2}
                description = string.gsub(description, placeholder, valueString)
            end
        end
        -- Fallback se algum placeholder não foi substituído (raro se templates e mods estiverem alinhados)
        description = string.gsub(description, "{value[1-9]?}", "?")

        love.graphics.printf(description, textStartX, currentOptionY + 35, textWidth, "left", 0, 1, 1) -- Permitir quebra de linha
    end
end

function LevelUpModal:mousepressed(x, y, button)
    print("[LevelUpModal:mousepressed] START - Visible:", self.visible)
    if not self.visible then return false end            -- Check if visible

    local clickedOption = self:getOptionAtPosition(x, y) -- Calculates which option index (1, 2, or 3) was clicked
    print("[LevelUpModal:mousepressed] Clicked Option Index:", clickedOption)
    if clickedOption then
        self.selectedOption = clickedOption            -- Updates internal state
        self:applyUpgrade(self.options[clickedOption]) -- Calls applyUpgrade with the selected option data
        self:hide()                                    -- Hides the modal
        print("[LevelUpModal:mousepressed] Option clicked and handled. Returning true.")
        return true                                    -- IMPORTANT: Should return true to indicate the click was handled
    end
    print("[LevelUpModal:mousepressed] Click was not on an option. Returning false.")
    return false -- Click was not on an option
end

function LevelUpModal:keypressed(key)
    print("[LevelUpModal:keypressed] START - Key:", key, "Visible:", self.visible)
    if not self.visible then return false end

    if key == "up" or key == "w" then
        self.selectedOption = math.max(1, (self.selectedOption or 1) - 1)
        self.hoveredOption = nil -- Clear mouse hover if using keyboard
        print("[LevelUpModal:keypressed] Navigated Up. SelectedIndex:", self.selectedOption)
        return true              -- Key handled
    elseif key == "down" or key == "s" then
        self.selectedOption = math.min(#self.options, (self.selectedOption or 1) + 1)
        self.hoveredOption = nil -- Clear mouse hover if using keyboard
        print("[LevelUpModal:keypressed] Navigated Down. SelectedIndex:", self.selectedOption)
        return true              -- Key handled
    elseif key == "return" or key == "kpenter" then
        if self.selectedOption and self.options[self.selectedOption] then
            print("[LevelUpModal:keypressed] Enter pressed. Applying upgrade index:", self.selectedOption)
            self:applyUpgrade(self.options[self.selectedOption])
            self:hide()
            return true -- Key handled
        else
            print("[LevelUpModal:keypressed] Enter pressed, but no valid option selected:", self.selectedOption)
            return true -- Still handle the key, just do nothing
        end
    end

    print("[LevelUpModal:keypressed] Key not handled. Returning false.")
    return false -- Key not handled by this modal
end

return LevelUpModal
