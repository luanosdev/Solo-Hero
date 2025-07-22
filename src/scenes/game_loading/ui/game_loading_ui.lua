local fonts = require("src.ui.fonts")
local ResolutionUtils = require("src.utils.resolution_utils")
local DashCooldownIndicator = require("src.ui.components.dash_cooldown_indicator")

---@class GameLoadingDrawData
---@field progress number
---@field currentTaskIndex number
---@field currentTask string
---@field totalTasks number
---@field currentTip string
---@field portalRank string

---@class GameLoadingUI
--- Módulo de UI para a Cena de Carregamento
--- @description Responsável exclusivamente por desenhar a interface
--- da tela de carregamento, com base em um estado fornecido pela cena.
--- @field animator DashCooldownIndicator
--- @field animationTimer number
--- @field currentFrame number
--- @field maxFrames number
--- @field animationSpeed number
local GameLoadingUI = {}

local animator = nil
local animationTimer = 0
local currentFrame = 1
local maxFrames = 7
local animationSpeed = 0.4
local currentTip = ""
local tipTimer = 0
local tipChangeInterval = 10

--- Inicializa os recursos visuais necessários para a UI.
function GameLoadingUI.init()
    animator = DashCooldownIndicator:new()
    animationTimer = 0
    currentFrame = 1
    currentTip = ""
    tipTimer = 0
    tipChangeInterval = 10

    GameLoadingUI:_selectRandomTip()
    Logger.info("game_loading_ui.init.success", "[GameLoadingUI] UI de carregamento inicializada.")
end

--- Seleciona uma dica aleatória do pool
function GameLoadingUI:_selectRandomTip()
    -- Pega a quantidade de dicas disponiveis do idioma atual
    local currentTranslationTable = GetCurrentTranslationTable()
    local currentTipsCount = #currentTranslationTable.ui.game_loading.tips
    if currentTipsCount > 0 then
        local randomIndex = love.math.random(1, currentTipsCount)
        self.currentTip = _T("ui.game_loading.tips.tip" .. randomIndex)
    end
end

--- Atualiza a animação da UI.
---@param dt number
function GameLoadingUI.update(dt)
    if not animator then return end

    animationTimer = animationTimer + dt
    if animationTimer >= (1 / animationSpeed) then
        currentFrame = currentFrame + 1
        if currentFrame > maxFrames then
            currentFrame = 1
        end
        animationTimer = 0
    end

    tipTimer = tipTimer + dt
    if tipTimer >= tipChangeInterval then
        GameLoadingUI:_selectRandomTip()
        tipTimer = 0
    end
end

--- Desenha a tela de carregamento.
---@param state GameLoadingDrawData O estado atual do carregamento, fornecido pela cena.
function GameLoadingUI.draw(state)
    local w = ResolutionUtils.getGameWidth()
    local h = ResolutionUtils.getGameHeight()

    -- Fundo
    love.graphics.setColor(0.08, 0.1, 0.14, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local centerX = w / 2
    local headerY = h * 0.12
    local imageY = h * 0.35
    local textY = h * 0.55
    local loadingY = h * 0.75

    local progress = state.currentTaskIndex / math.max(1, state.totalTasks)
    local currentTask = state.currentTask

    -- Cabeçalho
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.title_large)
    love.graphics.printf(_T("ui.game_loading.title"), 0, headerY, w, "center")

    -- Animação Central
    if animator and animator.quads then
        local quad = animator.quads[currentFrame]
        if quad then
            local scale = 0.8
            love.graphics.setColor(0.3, 0.7, 1.0, 0.4)
            love.graphics.draw(
                animator.image,
                quad,
                centerX - (animator.frameWidth * scale) / 2,
                imageY - (animator.frameHeight * scale) / 2,
                0,
                scale,
                scale
            )
        end
    end

    love.graphics.setColor(0.8, 0.9, 1.0, 1)
    love.graphics.setFont(fonts.main_large)
    love.graphics.printf(_T("ui.game_loading.loading_texts." .. currentTask .. ".title"), 0, textY, w, "center")

    love.graphics.setColor(0.6, 0.7, 0.9, 1)
    love.graphics.setFont(fonts.main)
    love.graphics.printf(_T("ui.game_loading.loading_texts." .. currentTask .. ".subtitle"), 0, textY + 35, w, "center")

    love.graphics.setColor(0.5, 0.6, 0.7, 0.8)
    love.graphics.setFont(fonts.main_small)
    love.graphics.printf(_T("ui.game_loading.loading_texts." .. currentTask .. ".detail"), 0, textY + 65, w, "center")

    -- Informações do portal
    if state.portalRank then
        love.graphics.setColor(0.7, 0.8, 0.9, 0.9)
        love.graphics.setFont(fonts.main or love.graphics.getFont())
        love.graphics.printf(_P("portals.title", { rank = state.portalRank }), 0, textY + 95, w, "center")
    end

    -- Barra de Progresso
    local barW = 500
    local barH = 8
    local barX = centerX - barW / 2

    -- Barra de progresso
    -- TODO: Trocar o estilo para a barra de progresso padrao do game
    -- Fundo da barra
    love.graphics.setColor(0.2, 0.25, 0.3, 0.8)
    love.graphics.rectangle("fill", barX, loadingY, barW, barH)

    -- Progresso
    love.graphics.setColor(0.3, 0.7, 1.0, 0.9)
    love.graphics.rectangle("fill", barX, loadingY, barW * progress, barH)

    -- Efeito de brilho simplificado
    if progress > 0 then
        love.graphics.setColor(0.3, 0.7, 1.0, 0.9)
        love.graphics.rectangle("line", barX, loadingY, barW, barH)
    end

    -- Borda da barra
    love.graphics.setColor(0.5, 0.6, 0.7, 1)
    love.graphics.rectangle("line", barX, loadingY, barW, barH)

    -- Percentual
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.setFont(fonts.main_small)
    love.graphics.printf(
        _P("ui.game_loading.loading_progress", { progress = math.floor(progress * 100) }),
        0,
        loadingY + 20,
        w,
        "center"
    )

    -- Dica de Sobrevivência
    if currentTip then
        local tipBoxY = h - 180
        love.graphics.setColor(0.7, 0.8, 0.9, 1)
        love.graphics.setFont(fonts.main)
        love.graphics.printf(_T("ui.game_loading.tips_title"), 0, tipBoxY + 15, w, "center")

        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        love.graphics.setFont(fonts.main_small)
        love.graphics.printf(currentTip, 40, tipBoxY + 50, w - 80, "center")
    end

    -- === ELEMENTOS DE INTERFACE SIMPLES ===
    -- Cantos minimalistas
    love.graphics.setColor(0.3, 0.7, 1.0, 0.4)
    love.graphics.setLineWidth(2)

    love.graphics.line(25, 25, 60, 25)
    love.graphics.line(25, 25, 25, 60)
    love.graphics.line(w - 25, 25, w - 60, 25)
    love.graphics.line(w - 25, 25, w - 25, 60)

    -- Status da agência
    love.graphics.setColor(0.4, 0.6, 0.8, 0.7)
    love.graphics.setFont(fonts.main_small or love.graphics.getFont())
    --- TODO: Adicionar o nome da agencia do jogador futuramente
    love.graphics.printf(_T("ui.game_loading.system"), 0, 30, w, "center")

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.setColor(1, 1, 1, 1)
end

function GameLoadingUI.destroy()
    animator = nil
    Logger.info("GameLoadingUI", "UI de carregamento destruída.")
end

return GameLoadingUI
