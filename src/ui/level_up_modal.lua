local elements = require("src.ui.ui_elements")
local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local LevelUpBonusesData = require("src.data.level_up_bonuses_data")

---@class LevelUpModal
---@field visible boolean
---@field options table
---@field selectedOption number|nil
---@field playerManager PlayerManager|nil
---@field inputManager InputManager|nil
---@field hoveredOption number|nil
---@field choiceDelay number
---@field onCloseCallback function|nil
local LevelUpModal = {
    visible = false,
    options = {},                  -- Agora vai armazenar as definições completas dos bônus de LevelUpBonusesData
    selectedOption = nil,          -- Para seleção por teclado, resetado ao mostrar
    playerManager = nil,
    inputManager = nil,            -- Para obter a posição do mouse
    hoveredOption = nil,           -- Para feedback visual do mouse hover

    choiceDelay = 1.0,             -- Segundos de delay antes de poder escolher
    currentChoiceDelayTimer = 0.0, -- Timer regressivo para o delay
    canChoose = false,             -- Flag que permite a escolha após o delay
    onCloseCallback = nil,         -- Callback chamado quando o modal é fechado
}

--- Inicializa o LevelUpModal.
--- @param playerManager PlayerManager Instância do PlayerManager.
--- @param inputManager InputManager Instância do InputManager.
function LevelUpModal:init(playerManager, inputManager)
    self.playerManager = playerManager
    self.inputManager = inputManager -- Armazena a referência ao inputManager
    print("[LevelUpModal] Inicializado com PlayerManager:", playerManager and "OK" or "NULO", "InputManager:",
        inputManager and "OK" or "NULO")
end

function LevelUpModal:show(onCloseCallback)
    self.visible = true
    self.selectedOption = nil                       -- Reseta a opção selecionada por teclado
    self.hoveredOption = nil                        -- Reseta a opção com hover do mouse
    self.currentChoiceDelayTimer = self.choiceDelay -- Inicia o timer de delay
    self.canChoose = false                          -- Desabilita a escolha inicialmente
    self.onCloseCallback = onCloseCallback          -- Armazena o callback de fechamento
    self:generateOptions()                          -- Gera as opções de bônus
    print(string.format("[LevelUpModal:show] Modal aberto. Delay de %.1fs iniciado.", self.choiceDelay))
end

function LevelUpModal:hide()
    self.visible = false
    love.graphics.setFont(fonts.main) -- Reseta a fonte para o padrão do jogo

    -- Chama o callback de fechamento se existir
    if self.onCloseCallback then
        Logger.debug(
            "level_up_modal.hide.callback",
            "[LevelUpModal:hide] Chamando callback de fechamento"
        )
        self.onCloseCallback()
        self.onCloseCallback = nil
    end
end

function LevelUpModal:generateOptions()
    self.options = {}
    local availableBonuses = {}

    if not self.playerManager or not self.playerManager.state or not self.playerManager.state.learnedLevelUpBonuses then
        error(
            "ERRO [LevelUpModal:generateOptions]: PlayerManager, PlayerState ou learnedLevelUpBonuses não está pronto.")
    end

    local learned = self.playerManager.state.learnedLevelUpBonuses

    for bonusId, bonusData in pairs(LevelUpBonusesData.Bonuses) do
        local currentLevel = learned[bonusId] or 0
        if currentLevel < bonusData.max_level then
            local optionData = {}
            for k, v in pairs(bonusData) do optionData[k] = v end
            optionData.current_level_for_display = currentLevel
            table.insert(availableBonuses, optionData)
        end
    end

    local numToSelect = math.min(4, #availableBonuses)
    for i = 1, numToSelect do
        if #availableBonuses > 0 then
            local randomIndex = love.math.random(1, #availableBonuses)
            table.insert(self.options, availableBonuses[randomIndex])
            table.remove(availableBonuses, randomIndex)
        else
            break
        end
    end

    if #self.options == 0 then
        print("AVISO [LevelUpModal:generateOptions]: Nenhuma opção de bônus disponível.")
        -- TODO: Considerar adicionar uma opção padrão como "Pegar Ouro" ou "Pular"
        -- Por agora, se não houver opções, o modal pode ficar vazio ou fechar automaticamente.
        -- Para este exemplo, vamos permitir que ele apareça vazio, mas o ideal seria ter um fallback.
    end
end

function LevelUpModal:update(dt) -- dt é delta time
    if not self.visible then return end

    if self.currentChoiceDelayTimer > 0 then
        self.currentChoiceDelayTimer = self.currentChoiceDelayTimer - dt
        if self.currentChoiceDelayTimer <= 0 then
            self.canChoose = true
            self.currentChoiceDelayTimer = 0 -- Garante que não fique negativo
            print("[LevelUpModal:update] Delay concluído. Escolha habilitada.")
        end
    end

    if self.canChoose then
        if self.inputManager then
            local mouseX, mouseY = self.inputManager:getMousePosition()
            self.hoveredOption = self:getOptionAtPosition(mouseX, mouseY)
        else
            self.hoveredOption = nil
        end
    else
        self.hoveredOption = nil
    end
end

-- Unificada para usar as dimensões de draw()
function LevelUpModal:getOptionAtPosition(x, y)
    local modalWidth = 550
    local modalHeight = 512 -- Altura total do modal, MODIFICADO: Era 450
    local modalX = (love.graphics.getWidth() - modalWidth) / 2
    local modalY = (love.graphics.getHeight() - modalHeight) / 2

    local titleAreaHeight = 45        -- Altura estimada da área do título (sem a linha divisória)
    local dividerHeight = 2           -- Altura da linha divisória
    local progressBarVisualHeight = 3 -- Altura da linha de progresso
    local paddingBelowProgressBar = 5

    local optionBlockStartY = modalY + titleAreaHeight + dividerHeight
    if self.currentChoiceDelayTimer > 0 then
        optionBlockStartY = optionBlockStartY + progressBarVisualHeight + paddingBelowProgressBar
    else
        optionBlockStartY = optionBlockStartY + paddingBelowProgressBar -- Só o padding se a barra sumiu
    end

    local optionVisualHeight = 100
    local optionGap = 15

    for i, _ in ipairs(self.options) do
        local currentOptionY = optionBlockStartY + (i - 1) * (optionVisualHeight + optionGap)
        local optionActualX = modalX + 20
        local optionActualWidth = modalWidth - 40

        if x >= optionActualX and x <= optionActualX + optionActualWidth and
            y >= currentOptionY and y <= currentOptionY + optionVisualHeight then
            return i -- Retorna o índice da opção (1, 2 ou 3)
        end
    end
    return nil -- Nenhuma opção na posição do mouse
end

function LevelUpModal:applyUpgrade(optionData)
    if not self.playerManager or not self.playerManager.state then
        error("ERRO [LevelUpModal:applyUpgrade]: PlayerManager ou PlayerState não está pronto.")
    end
    if not optionData or not optionData.id then
        error("ERRO [LevelUpModal:applyUpgrade]: optionData inválido ou sem ID.")
    end

    LevelUpBonusesData.ApplyBonus(self.playerManager.state, optionData.id)

    local bonusId = optionData.id
    local learnedBonuses = self.playerManager.state.learnedLevelUpBonuses
    learnedBonuses[bonusId] = (learnedBonuses[bonusId] or 0) + 1
    self.playerManager:invalidateStatsCache()

    -- Registra a escolha para as estatísticas
    local gameStatsManager = self.playerManager.gameStatisticsManager
    if gameStatsManager then
        local currentLevel = self.playerManager.state.level
        local choiceText = optionData.name or "Melhoria Desconhecida"
        gameStatsManager:registerLevelUpChoice(learnedBonuses[bonusId], choiceText)
    end

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
    local modalHeight = 512 -- MODIFICADO: Era 450
    local modalX = (love.graphics.getWidth() - modalWidth) / 2
    local modalY = (love.graphics.getHeight() - modalHeight) / 2

    -- Desenha o frame do modal
    elements.drawWindowFrame(modalX, modalY, modalWidth, modalHeight, "Level Up!")

    -- Estimativas para o posicionamento da barra de progresso em relação ao frame
    local titleAreaHeight = 45                        -- Altura da área do título (onde "Level Up!" é desenhado)
    local dividerLineY = modalY + titleAreaHeight + 2 -- Posição Y da linha divisória (estimativa)
    local dividerThickness = 2

    local progressBarWidth = modalWidth - 20
    local progressBarX = modalX + 10
    local progressBarLineThickness = 3
    -- Posiciona a barra de progresso colada à linha divisória (ou onde ela estaria)
    local progressBarY = dividerLineY + dividerThickness

    if self.currentChoiceDelayTimer > 0 then
        love.graphics.setColor(colors.bar_border or { 0.3, 0.3, 0.35, 0.8 })
        love.graphics.rectangle("fill", progressBarX, progressBarY, progressBarWidth, progressBarLineThickness)
        local progress = self.currentChoiceDelayTimer / self.choiceDelay
        progress = math.max(0, math.min(1, progress)) -- Garante que o progresso fique entre 0 e 1
        local currentBarWidth = progressBarWidth * progress
        love.graphics.setColor(colors.xp_fill or { 0.8, 0.6, 0.2, 1 })
        love.graphics.rectangle("fill", progressBarX, progressBarY, currentBarWidth, progressBarLineThickness)
    end

    local optionBlockStartY = progressBarY + progressBarLineThickness +
        5 -- Opções começam abaixo da barra de progresso
    local optionVisualHeight = 100
    local optionGap = 15
    local iconWrapWidth = 55
    local iconPaddingRight = 10

    for i, optionData in ipairs(self.options) do
        local currentOptionY = optionBlockStartY + (i - 1) * (optionVisualHeight + optionGap)
        local optionActualX = modalX + 20
        local optionActualWidth = modalWidth - 40

        local isSelectedByKey = (i == self.selectedOption)
        local isHoveredByMouse = (i == self.hoveredOption)

        local bgColor = nil -- MODIFICADO: Sem cor de fundo por padrão
        local textColor = colors.text_main
        local nameColor = colors.text_highlight
        local globalAlpha = self.canChoose and 1.0 or 0.5

        if isSelectedByKey and self.canChoose then
            elements.drawRarityBorderAndGlow('S', optionActualX, currentOptionY, optionActualWidth, optionVisualHeight,
                globalAlpha)
            bgColor = { colors.window_border[1], colors.window_border[2], colors.window_border[3], 0.3 * globalAlpha }
            textColor = colors.text_highlight
        elseif isHoveredByMouse and self.canChoose then
            bgColor = { colors.slot_hover_bg[1], colors.slot_hover_bg[2], colors.slot_hover_bg[3], 0.6 * globalAlpha }
            textColor = colors.text_highlight
        end

        local originalR, originalG, originalB, originalA = love.graphics.getColor()
        -- Desenha o fundo SOMENTE se bgColor estiver definido
        if bgColor then
            love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.7 * globalAlpha)
            love.graphics.rectangle("fill", optionActualX, currentOptionY, optionActualWidth, optionVisualHeight, 5, 5)
        end

        love.graphics.setFont(fonts.title)
        love.graphics.setColor(textColor[1], textColor[2], textColor[3], (textColor[4] or 1.0) * globalAlpha)

        local iconX = optionActualX + 15
        love.graphics.printf(optionData.icon or "?", iconX,
            currentOptionY + optionVisualHeight / 2 - fonts.title:getHeight() / 2, iconWrapWidth, "center")

        local textStartX = iconX + iconWrapWidth + iconPaddingRight
        local textAvailableWidth = optionActualWidth - (textStartX - optionActualX) - 15

        love.graphics.setFont(fonts.hud)
        love.graphics.setColor(nameColor[1], nameColor[2], nameColor[3], (nameColor[4] or 1.0) * globalAlpha)
        local currentDisplayLevel = (optionData.current_level_for_display or 0)
        local nextLevel = currentDisplayLevel + 1
        local nameText = string.format("%s (Nv. %d/%d)", optionData.name, nextLevel, optionData.max_level)
        love.graphics.printf(nameText, textStartX, currentOptionY + 10, textAvailableWidth, "left")

        love.graphics.setFont(fonts.main_small)
        love.graphics.setColor(textColor[1], textColor[2], textColor[3], (textColor[4] or 1.0) * globalAlpha)
        local description = optionData.description_template or ""
        if optionData.modifiers_per_level then
            for idx, mod in ipairs(optionData.modifiers_per_level) do
                local valueString = ""
                if mod.type == "fixed" then
                    valueString = string.format("%.1f", mod.value):gsub("%.0$", "")
                elseif mod.type == "percentage" then
                    valueString = string.format("%.1f", mod.value):gsub("%.0$", "") .. "%"
                elseif mod.type == "fixed_percentage_as_fraction" then
                    valueString = string.format("%.1f", mod.value * 100):gsub("%.0$", "") .. "%"
                else
                    valueString = tostring(mod.value)
                end
                local placeholder = "{value" .. (idx > 1 and tostring(idx) or "") .. "}"
                description = string.gsub(description, placeholder, valueString)
            end
        end
        description = string.gsub(description, "{value[1-9]?}", "?")
        love.graphics.printf(description, textStartX, currentOptionY + 35, textAvailableWidth, "left", 0, 1, 1)
        love.graphics.setColor(originalR, originalG, originalB, originalA)
    end
end

function LevelUpModal:mousepressed(x, y, button)
    if not self.visible then return false end
    if not self.canChoose then
        -- print("[LevelUpModal:mousepressed] Escolha desabilitada (delay ativo).") -- Comentado para reduzir spam no log
        return false
    end

    local clickedOptionIndex = self:getOptionAtPosition(x, y)
    if clickedOptionIndex then
        self.selectedOption = clickedOptionIndex
        self:applyUpgrade(self.options[clickedOptionIndex])
        self:hide()
        print(string.format("[LevelUpModal:mousepressed] Opção %d clicada e aplicada.", clickedOptionIndex))
        return true
    end
    return false
end

function LevelUpModal:keypressed(key)
    if not self.visible then return false end

    if not self.canChoose then
        -- print("[LevelUpModal:keypressed] Escolha desabilitada (delay ativo).") -- Comentado para reduzir spam no log
        return false
    end

    if key == "up" or key == "w" then
        if #self.options > 0 then
            if self.selectedOption == nil then
                self.selectedOption = #self.options
            else
                self.selectedOption = math.max(1, self.selectedOption - 1)
            end
            self.hoveredOption = nil
            print("[LevelUpModal:keypressed] Navegou para Cima. Índice Selecionado:", self.selectedOption)
        end
        return true
    elseif key == "down" or key == "s" then
        if #self.options > 0 then
            if self.selectedOption == nil then
                self.selectedOption = 1
            else
                self.selectedOption = math.min(#self.options, self.selectedOption + 1)
            end
            self.hoveredOption = nil
            print("[LevelUpModal:keypressed] Navegou para Baixo. Índice Selecionado:", self.selectedOption)
        end
        return true
    elseif key == "return" or key == "kpenter" or key == "space" then
        if self.selectedOption and self.options[self.selectedOption] then
            print("[LevelUpModal:keypressed] Enter/Space pressionado. Aplicando opção índice:", self.selectedOption)
            self:applyUpgrade(self.options[self.selectedOption])
            self:hide()
            return true
        else
            print("[LevelUpModal:keypressed] Enter/Space pressionado, mas nenhuma opção válida selecionada:",
                self.selectedOption)
            if #self.options > 0 and self.options[1] then
            end
            return true
        end
    end
    return false
end

return LevelUpModal
