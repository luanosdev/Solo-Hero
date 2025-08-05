local Fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local LevelUpCard = require("src.scenes.gameplay.ui.components.level_up_card")
local adaptiveFonts = Fonts.getAdaptive()

---@class LevelUpModal
---@field visible boolean
---@field options LevelUpBonusOption[]
---@field selectedOption number|nil
---@field hoveredOption number|nil
---@field onChoiceCallback fun(chosenBonus: LevelUpBonusOption)|nil
---@field cards LevelUpCard[]
---@field scales table<number, number>
---@field backgroundColors Color[]
---@field cardAnimationTimer number
---@field cardsAnimated number
---@field canChoose boolean
---@field appearanceSequenceCompleted boolean
---@field inputService InputService
---@field eventService EventService
---@field assetService AssetService
local LevelUpModal = {}
LevelUpModal.__index = LevelUpModal

---@public Cria uma nova instância do LevelUpModal.
---@param inputService InputService
---@param eventService EventService
---@param assetService AssetService
function LevelUpModal:new(inputService, eventService, assetService)
    assert(inputService, "[LevelUpModal] missing inputService")
    assert(eventService, "[LevelUpModal] missing eventService")
    assert(assetService, "[LevelUpModal] missing assetService")

    local instance = setmetatable({}, LevelUpModal)

    instance.visible = false
    instance.options = {}
    instance.selectedOption = nil
    instance.hoveredOption = nil
    instance.onChoiceCallback = nil
    instance.cards = {}
    instance.scales = {}
    instance.backgroundColors = {}
    instance.cardAnimationTimer = 0.0
    instance.cardsAnimated = 0
    instance.canChoose = false
    instance.appearanceSequenceCompleted = false

    instance.inputService = inputService
    instance.eventService = eventService
    instance.assetService = assetService

    return instance
end

---@public Mostra o modal de level up.
---@param options LevelUpBonus[]
---@param onChoiceCallback fun(chosenBonus: LevelUpBonusOption)|nil
function LevelUpModal:show(options, onChoiceCallback)
    self.visible = true
    self.options = options or {}
    self.selectedOption = nil
    self.hoveredOption = nil
    self.canChoose = false
    self.appearanceSequenceCompleted = false
    self.cardAnimationTimer = 0.0
    self.cardsAnimated = 0
    self.onChoiceCallback = onChoiceCallback
    self.cards = {}
    self.scales = {}
    self.backgroundColors = {}

    self:_ensureImagesLoaded()
    self:_createCards()

    self.eventService:emit(self.eventService.EVENTS.REQUEST_GAME_PAUSE)
    Logger.debug("level_up_modal.show", "[LevelUpModal] Modal aberto com " .. #self.options .. " opções.")
end

---@private Esconde o modal de level up.
function LevelUpModal:_hide()
    self.visible = false
    self.eventService:emit(self.eventService.EVENTS.REQUEST_GAME_UNPAUSE)
    self.eventService:emit(self.eventService.EVENTS.LEVEL_UP_MODAL_CLOSED)
end

---@private Garante que as imagens dos bônus estejam carregadas.
function LevelUpModal:_ensureImagesLoaded()
    for _, option in ipairs(self.options) do
        if option.image_path then
            self.assetService:getImage(option.image_path)
        end
    end
end

---@private Cria os cards de bônus.
function LevelUpModal:_createCards()
    local screenW, screenH = ResolutionUtils.getGameDimensions()
    local numOptions = #self.options

    if numOptions == 0 then return end

    local cardWidth = LevelUpCard.WIDTH
    local cardHeight = LevelUpCard.HEIGHT
    local cardGap = ResolutionUtils.scaleSpacing(40)
    local totalWidth = (cardWidth * numOptions) + (cardGap * (numOptions - 1))
    local startX = (screenW - totalWidth) / 2
    local startY = (screenH - cardHeight) / 2

    for i, optionData in ipairs(self.options) do
        local cardX = startX + (i - 1) * (cardWidth + cardGap)

        local image = nil
        if optionData.image_path then
            image = self.assetService:getImage(optionData.image_path)
        end
        local card = LevelUpCard:new(cardX, startY, optionData, image, optionData.current_level_for_display)
        self.cards[i] = card
        self.scales[i] = 1.0
        local r, g, b = unpack(colors.window_bg)
        self.backgroundColors[i] = { r, g, b }
    end
end

function LevelUpModal:update(dt)
    if not self.visible then return end

    if not self.appearanceSequenceCompleted then
        self.cardAnimationTimer = self.cardAnimationTimer + dt
        local cardAppearanceDelay = 0.15
        local targetCardsAnimated = math.floor(self.cardAnimationTimer / cardAppearanceDelay) + 1

        for i = self.cardsAnimated + 1, math.min(targetCardsAnimated, #self.cards) do
            self.cardsAnimated = i
        end

        local allAnimated = true
        for i = 1, self.cardsAnimated do
            if self.cards[i] then
                self.cards[i]:update(dt, 0, 0) -- Passando 0,0 para mouse pois o hover só ativa depois
                if not self.cards[i].animationComplete then
                    allAnimated = false
                end
            end
        end

        if self.cardsAnimated >= #self.cards and allAnimated then
            self.appearanceSequenceCompleted = true
            self.canChoose = true
        end
    end

    if self.canChoose and self.inputService then
        local mouseX, mouseY = self.inputService:getMousePosition()
        self.hoveredOption = self:getCardAtPosition(mouseX, mouseY)

        for i = 1, #self.cards do
            self.cards[i]:update(dt, mouseX, mouseY)
        end

        if self.inputService:wasActionPressed("ui_select") then
            local clickedCardIndex = self:getCardAtPosition(mouseX, mouseY)
            if clickedCardIndex then
                self.selectedOption = clickedCardIndex
                local chosenBonus = self.options[clickedCardIndex]

                if self.onChoiceCallback then
                    self.onChoiceCallback(chosenBonus)
                end

                self:_hide()
                Logger.debug("level_up_modal.mouse_click",
                    string.format("Card %d (%s) clicado e aplicado", clickedCardIndex, chosenBonus.id))
            end
        end
    end
end

function LevelUpModal:getCardAtPosition(x, y)
    for i, card in ipairs(self.cards) do
        if i <= self.cardsAnimated and card:isHovered(x, y) then
            return i
        end
    end
    return nil
end

function LevelUpModal:draw()
    if not self.visible then return end

    local gameW, gameH = ResolutionUtils.getGameDimensions()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, gameW, gameH)

    love.graphics.setFont(adaptiveFonts.title_large)
    love.graphics.setColor(colors.text_title)
    love.graphics.printf("Você subiu de nível!", 0, gameH * 0.1, gameW, "center")
    love.graphics.setFont(adaptiveFonts.main_large)
    love.graphics.setColor(colors.text_main)
    love.graphics.printf("Escolha uma melhoria", 0, gameH * 0.1 + 60, gameW, "center")

    for i = 1, self.cardsAnimated do
        local card = self.cards[i]
        if card then
            card:draw()
        end
    end

    if not self.canChoose then
        love.graphics.setFont(adaptiveFonts.main)
        love.graphics.setColor(colors.text_default[1], colors.text_default[2], colors.text_default[3], 0.8)
        love.graphics.printf("Aguarde...", 0, gameH - 50, gameW, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return LevelUpModal
