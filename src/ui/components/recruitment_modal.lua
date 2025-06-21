local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local Button = require("src.ui.components.button")
local YStack = require("src.ui.components.YStack")
local Text = require("src.ui.components.Text")
local Card = require("src.ui.components.Card")
local Section = require("src.ui.components.Section")
local ArchetypeDetails = require("src.ui.components.ArchetypeDetails")
local HunterAttributesList = require("src.ui.components.HunterAttributesList")
local Grid = require("src.ui.components.Grid")

---@class RecruitmentModal
---@field recruitmentManager RecruitmentManager
---@field archetypeManager ArchetypeManager
---@field columns table<number, YStack>
---@field chooseButtons table<number, Button>
---@field cancelButton Button|nil
local RecruitmentModal = {}
RecruitmentModal.__index = RecruitmentModal

---@param recruitmentManager RecruitmentManager
---@param archetypeManager ArchetypeManager
function RecruitmentModal:new(recruitmentManager, archetypeManager)
    local instance = setmetatable({}, RecruitmentModal)
    instance.recruitmentManager = recruitmentManager
    instance.archetypeManager = archetypeManager
    instance.columns = {}
    instance.chooseButtons = {}
    instance.cancelButton = nil
    Logger.debug("[RecruitmentModal:new]", "Created.")
    return instance
end

function RecruitmentModal:draw(mx, my)
    if not self.recruitmentManager.isRecruiting then
        return
    end

    -- Fundo semi-transparente (TELA INTEIRA)
    local screenW, screenH = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    if not self.recruitmentManager.hunterCandidates or #self.recruitmentManager.hunterCandidates == 0 then
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro ao gerar candidatos!", 0, screenH / 2, screenW, "center")
        if self.cancelButton then
            self.cancelButton.rect.x = (screenW - self.cancelButton.rect.w) / 2
            self.cancelButton:draw()
        end
        return
    end

    -- Cálculos de Dimensão e Posição
    local numCandidates = #self.recruitmentManager.hunterCandidates
    local totalPadding = 40
    local modalColumnGap = 20
    local fixedModalContentHeight = screenH * 0.80
    local buttonAreaHeight = 50
    local totalColumnHeight = fixedModalContentHeight + buttonAreaHeight
    local modalBottomPadding = 80
    local availableWidthForColumns = screenW - totalPadding
    local modalWidth = math.max(0, (availableWidthForColumns - (modalColumnGap * (numCandidates - 1))) / numCandidates)
    local modalBaseY = (screenH - totalColumnHeight - modalBottomPadding) / 2
    local startX = totalPadding / 2
    local modalButtonW = 150
    local modalButtonH = 35
    local buttonPaddingY = (buttonAreaHeight - modalButtonH) / 2

    for i, candidate in ipairs(self.recruitmentManager.hunterCandidates) do
        local modalX = startX + (i - 1) * (modalWidth + modalColumnGap)
        local columnStack = self.columns[i]
        local chooseButton = self.chooseButtons[i]

        -- Desenha o Card de fundo
        local cardHeight = fixedModalContentHeight
        local backgroundCard = Card:new({
            rect = { x = modalX, y = modalBaseY, w = modalWidth, h = cardHeight },
            backgroundColor = colors.window_bg,
            borderColor = colors.window_border,
            borderWidth = 1,
        })
        backgroundCard:draw()

        -- Desenha o CONTEÚDO da Stack (com clipping e scroll)
        if columnStack then
            columnStack:draw()
        end

        -- Desenha o Botão "Escolher"
        if chooseButton then
            local buttonX = modalX + (modalWidth - modalButtonW) / 2
            local buttonY = modalBaseY + cardHeight + buttonPaddingY
            chooseButton.rect.x = math.floor(buttonX)
            chooseButton.rect.y = math.floor(buttonY)
            chooseButton:draw()
        end
    end

    -- Desenha o botão Cancelar global
    if self.cancelButton then
        local cancelY = modalBaseY + totalColumnHeight + 20
        self.cancelButton.rect.x = (screenW - self.cancelButton.rect.w) / 2
        self.cancelButton.rect.y = math.floor(cancelY)
        self.cancelButton:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function RecruitmentModal:_createOrUpdateModalElements()
    local screenW, screenH = love.graphics.getDimensions()
    local numCandidates = #self.recruitmentManager.hunterCandidates
    local totalPadding = 40
    local modalColumnGap = 20
    local fixedModalContentHeight = screenH * 0.80
    local availableWidthForColumns = screenW - totalPadding
    local modalWidth = math.max(0, (availableWidthForColumns - (modalColumnGap * (numCandidates - 1))) / numCandidates)
    local modalBaseY = (screenH - (fixedModalContentHeight + 50 + 80)) / 2
    local startX = totalPadding / 2
    local modalContentPadding = 14

    -- Limpa elementos antigos se o número de candidatos mudar
    if #self.columns ~= numCandidates then
        self.columns = {}
        self.chooseButtons = {}
    end

    for i, candidate in ipairs(self.recruitmentManager.hunterCandidates) do
        local modalX = startX + (i - 1) * (modalWidth + modalColumnGap)

        if not self.columns[i] then
            -- Cria a Stack de Conteúdo
            local columnStack = YStack:new({
                x = modalX,
                y = modalBaseY,
                width = modalWidth,
                height = fixedModalContentHeight,
                padding = modalContentPadding,
                gap = modalColumnGap,
                alignment = "center",
            })

            local headerStack = YStack:new({
                x = 0,
                y = 0,
                width = modalWidth,
                padding = 0,
                gap = 6,
                alignment = "center"
            })
            headerStack:addChild(Text:new({
                width = 0,
                text = candidate.name,
                size = "h1",
                variant = "text_title",
                align = "center"
            }))
            headerStack:addChild(Text:new({
                width = 0,
                text = "Caçador Rank " .. candidate.finalRankId,
                size = "h2",
                variant = "rank_" .. candidate.finalRankId,
                align = "center"
            }))
            columnStack:addChild(headerStack)

            local attributesComponent = HunterAttributesList:new({
                attributes = candidate.finalStats,
                archetypes =
                    candidate.archetypes,
                archetypeManager = self.archetypeManager
            })
            local attributesSection = Section:new({
                titleConfig = { text = "Atributos", font = fonts.main_large },
                contentComponent =
                    attributesComponent,
                gap = 10
            })
            columnStack:addChild(attributesSection)

            local archetypeGrid = Grid:new({ width = modalWidth, columns = 3, gap = { vertical = 5, horizontal = 5 } })
            if candidate.archetypes and #candidate.archetypes > 0 then
                for _, d in ipairs(candidate.archetypes) do
                    archetypeGrid:addChild(ArchetypeDetails:new({ archetypeData = d }))
                end
            else
                archetypeGrid:addChild(Text:new({ text = "Nenhum", width = modalWidth, align = "center" }))
            end
            local archetypeSection = Section:new({
                titleConfig = { text = "Arquétipos", font = fonts.main_large },
                contentComponent =
                    archetypeGrid,
                gap = 10
            })
            columnStack:addChild(archetypeSection)

            self.columns[i] = columnStack

            -- Cria o Botão "Escolher"
            local index = i
            local onChooseClick = function()
                local newHunterId = self.recruitmentManager:recruitCandidate(index)
                if self.onRecruit then self.onRecruit(newHunterId) end
            end
            self.chooseButtons[i] = Button:new({
                rect = { w = 150, h = 35 },
                text = "Escolher",
                variant = "primary",
                onClick = onChooseClick,
                font = fonts.main
            })
        else
            -- Atualiza posição/dimensão
            local columnStack = self.columns[i]
            columnStack.rect.x = modalX
            columnStack.rect.y = modalBaseY
            columnStack.rect.w = modalWidth
            columnStack.fixedHeight = fixedModalContentHeight
            columnStack.needsLayout = true
        end

        self.columns[i]:_updateLayout()
    end

    -- Cria o botão Cancelar
    if not self.cancelButton then
        self.cancelButton = Button:new({
            rect = { w = 150, h = 35 },
            text = "Cancelar",
            variant = "secondary",
            onClick = function() self.recruitmentManager:cancelRecruitment() end,
            font = fonts.main
        })
    end
end

function RecruitmentModal:update(dt, mx, my, allowHover)
    if not self.recruitmentManager.isRecruiting then
        -- Limpa os botões quando não está recrutando para evitar updates desnecessários
        if #self.chooseButtons > 0 or self.cancelButton then
            self.columns = {}
            self.chooseButtons = {}
            self.cancelButton = nil
        end
        return
    end

    -- Cria os elementos do modal na primeira vez que o update é chamado
    if #self.chooseButtons == 0 then
        self:_createOrUpdateModalElements()
    end

    for i, stack in pairs(self.columns) do
        stack:update(dt, mx, my, allowHover)
        local button = self.chooseButtons[i]
        if button then
            button:update(dt, mx, my, allowHover)
        end
    end
    if self.cancelButton then
        self.cancelButton:update(dt, mx, my, allowHover)
    end
end

function RecruitmentModal:handleMousePress(x, y, button)
    if not self.recruitmentManager.isRecruiting or button ~= 1 then return false end

    if self.cancelButton and self.cancelButton:handleMousePress(x, y, button) then return true end
    for i, btn in pairs(self.chooseButtons) do
        if btn:handleMousePress(x, y, button) then return true end
    end

    for i, stack in pairs(self.columns) do
        if x >= stack.rect.x and x < stack.rect.x + stack.rect.w and
            y >= stack.rect.y and y < stack.rect.y + stack.rect.h then
            if stack:handleMousePress(x - stack.rect.x, y - stack.rect.y - (stack.scrollY or 0), button) then return true end
        end
    end

    return true -- Consome o clique para evitar interação com a tela de fundo
end

function RecruitmentModal:handleMouseRelease(x, y, button)
    if not self.recruitmentManager.isRecruiting or button ~= 1 then return false end

    if self.cancelButton and self.cancelButton:handleMouseRelease(x, y, button) then return true end
    for i, btn in pairs(self.chooseButtons) do
        if btn:handleMouseRelease(x, y, button) then return true end
    end
    for i, stack in pairs(self.columns) do
        stack:handleMouseRelease(x - stack.rect.x, y - stack.rect.y - (stack.scrollY or 0), button)
    end
    return true
end

function RecruitmentModal:handleMouseScroll(dx, dy, mx, my)
    if not self.recruitmentManager.isRecruiting or dy == 0 then return false end

    for i, stack in pairs(self.columns) do
        if mx >= stack.rect.x and mx < stack.rect.x + stack.rect.w and
            my >= stack.rect.y and my < stack.rect.y + stack.rect.h then
            local availableHeight = stack.rect.h - stack.padding.top - stack.padding.bottom
            local contentHeight = stack.actualHeight

            if contentHeight > availableHeight then
                local scrollSpeed = 30
                local currentScrollY = stack.scrollY or 0
                local newScrollY = currentScrollY - dy * scrollSpeed
                local maxScrollY = math.min(0, availableHeight - contentHeight)
                stack.scrollY = math.clamp(newScrollY, maxScrollY, 0)
                return true
            else
                stack.scrollY = 0
            end
        end
    end
    return false
end

return RecruitmentModal
