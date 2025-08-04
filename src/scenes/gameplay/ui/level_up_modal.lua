--------------------------------------------------------------------------------
-- LevelUpModal (UI Container)
-- @description Container da UI para a seleção de bônus de level up.
-- Responsável por orquestrar a exibição dos cards de bônus e gerenciar o
-- estado geral do modal (visibilidade, animações).
--------------------------------------------------------------------------------

local ServiceLocator = require("src.core.service_locator")
local Colors = require("src.ui.colors")
local Fonts = require("src.ui.fonts")
local LevelUpCard = require("src.scenes.gameplay.ui.components.level_up_card")
local ActionTypes = require("src.types.action_types")

---@class LevelUpModal
---@field isVisible boolean Se o modal está visível ou não.
---@field cards LevelUpCard[] Os cards de bônus a serem exibidos.
---@field onChoice fun(choice: LevelUpBonus):nil Callback a ser chamado quando uma escolha é feita.
local LevelUpModal = {}
LevelUpModal.__index = LevelUpModal

LevelUpModal.CARD_SPACING = ResolutionUtils.scaleSpacing(50)

---@public Cria uma nova instância do modal de level up.
---@return LevelUpModal
function LevelUpModal:new()
    local instance = setmetatable({}, LevelUpModal)

    instance.isVisible = false
    instance.cards = {}
    instance.onChoice = function() end -- Callback padrão vazio

    return instance
end

---@public Mostra o modal com um conjunto de opções de bônus.
---@param options LevelUpBonus[] Uma tabela contendo os dados das opções de bônus.
---@param onChoiceCallback fun(choice: LevelUpBonus) Callback para quando uma opção é escolhida.
function LevelUpModal:show(options, onChoiceCallback)
    if self.isVisible then return end
    if not options or #options == 0 then
        Logger.warn("LevelUpModal:show", "[LevelUpModal:show] Tentou mostrar o modal sem opções válidas.")
        return
    end

    Logger.info("LevelUpModal:show", "[LevelUpModal:show] Exibindo modal de level up.")
    self.isVisible = true
    self.onChoice = onChoiceCallback

    self.cards = {} -- Limpa cards antigos

    -- Calcula a posição inicial para centralizar o conjunto de cards
    local totalCardsWidth = (#options * LevelUpCard.WIDTH) + ((#options - 1) * LevelUpModal.CARD_SPACING)
    local startX = (ResolutionUtils.getGameWidth() - totalCardsWidth) / 2
    local startY = (ResolutionUtils.getGameHeight() - LevelUpCard.HEIGHT) / 2

    for i, optionData in ipairs(options) do
        local cardX = startX + ((i - 1) * (LevelUpCard.WIDTH + LevelUpModal.CARD_SPACING))
        local assetService = ServiceLocator.getAssetService()
        local image = assetService:getImage(optionData.image_path)
        local card = LevelUpCard:new(
            cardX,
            startY,
            optionData,
            image,
            optionData.current_level_for_display
        )

        -- Define o callback para quando este card específico for selecionado
        card:setOnSelect(function()
            if self.onChoice then
                self.onChoice(optionData)
            end
            self:hide() -- Esconde o modal após a escolha
        end)

        table.insert(self.cards, card)
    end

    -- Dispara evento para pausar o jogo
    local eventService = ServiceLocator.getEventService()
    eventService:emit(eventService.EVENTS.REQUEST_GAME_PAUSE)
end

---@public Esconde o modal.
function LevelUpModal:hide()
    if not self.isVisible then return end

    Logger.info("LevelUpModal:hide", "[LevelUpModal:hide] Escondendo modal de level up.")
    self.isVisible = false
    self.cards = {} -- Limpa os cards

    -- Dispara evento para despausar o jogo
    local eventService = ServiceLocator.getEventService()
    eventService:emit(eventService.EVENTS.REQUEST_GAME_UNPAUSE)
end

---@public Atualiza o estado do modal e de seus componentes.
---@param dt number Delta time.
function LevelUpModal:update(dt)
    if not self.isVisible then return end

    local inputService = ServiceLocator.getInputService()
    local mx, my = inputService:getMousePosition()

    -- Atualiza os cards (para efeito de hover)
    for _, card in ipairs(self.cards) do
        card:update(dt, mx, my)
    end

    -- Verifica se a ação de selecionar UI foi pressionada
    if inputService:wasActionPressed(ActionTypes.UI_SELECT) then
        for _, card in ipairs(self.cards) do
            if card:isHovered(mx, my) then
                card.onSelect() -- Aciona o callback do card
                break           -- Impede que múltiplos cards sejam selecionados no mesmo frame
            end
        end
    end
end

---Desenha o modal e seus componentes.
function LevelUpModal:draw()
    if not self.isVisible then return end

    -- Desenha um fundo escuro semi-transparente para pausar a ação
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, ResolutionUtils.getGameWidth(), ResolutionUtils.getGameHeight())

    love.graphics.setColor(Colors.white)
    love.graphics.setFont(Fonts.main_bold)
    love.graphics.printf("VOCÊ SUBIU DE NÍVEL!", 0, 100, ResolutionUtils.getGameWidth(), "center")
    love.graphics.setFont(Fonts.main)
    love.graphics.printf("Escolha uma melhoria", 0, 150, ResolutionUtils.getGameWidth(), "center")


    -- Desenha os cards
    for _, card in ipairs(self.cards) do
        card:draw()
    end
end

---Processa inputs de teclado.
---@param key love.KeyConstant Tecla pressionada.
function LevelUpModal:keypressed(key)
    if not self.isVisible then return end

    if key == "escape" then
        -- Não permite fechar, o jogador DEVE escolher um bônus.
        return
    end
end

return LevelUpModal
