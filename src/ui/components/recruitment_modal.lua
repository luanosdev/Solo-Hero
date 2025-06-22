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
local lume = require("src.libs.lume")

---@class RecruitmentModal
---@field recruitmentManager RecruitmentManager
---@field archetypeManager ArchetypeManager
---@field onRecruit function
---@field columns table<number, YStack>
---@field hoveredIndex number|nil
---@field scales table<number, number>
---@field backgroundColors table<number, {number, number, number}>
local RecruitmentModal = {}
RecruitmentModal.__index = RecruitmentModal

---@param recruitmentManager RecruitmentManager
---@param archetypeManager ArchetypeManager
function RecruitmentModal:new(recruitmentManager, archetypeManager)
    local instance = setmetatable({}, RecruitmentModal)
    instance.recruitmentManager = recruitmentManager
    instance.archetypeManager = archetypeManager
    instance.columns = {}
    instance.hoveredIndex = nil
    instance.scales = {}
    instance.backgroundColors = {}
    Logger.debug("[RecruitmentModal:new]", "Created.")
    return instance
end

function RecruitmentModal:_drawCard(index)
    local columnStack = self.columns[index]
    if not columnStack then
        return
    end

    local screenW, screenH = love.graphics.getDimensions()
    local numCandidates = #self.recruitmentManager.hunterCandidates
    local totalPadding = 40
    local modalColumnGap = 20
    local fixedModalContentHeight = screenH * 0.95
    local modalBaseY = (screenH - fixedModalContentHeight) / 2
    local availableWidthForColumns = screenW - (totalPadding * 2) - (modalColumnGap * (numCandidates - 1))
    local baseCardWidth = availableWidthForColumns / numCandidates

    local currentScale = self.scales[index] or 1.0
    local baseX = columnStack.rect.x
    local currentBgColor = self.backgroundColors[index] or colors.window_bg

    love.graphics.push()
    love.graphics.translate(baseX + baseCardWidth / 2, modalBaseY + fixedModalContentHeight / 2)
    love.graphics.scale(currentScale, currentScale)
    love.graphics.translate(-(baseX + baseCardWidth / 2), -(modalBaseY + fixedModalContentHeight / 2))

    local backgroundCard = Card:new({
        rect = { x = baseX, y = modalBaseY, w = baseCardWidth, h = fixedModalContentHeight },
        backgroundColor = currentBgColor,
        borderColor = (self.hoveredIndex == index) and colors.border_active or colors.window_border,
        borderWidth = (self.hoveredIndex == index) and 2 or 1,
    })
    backgroundCard:draw()

    columnStack:draw()

    love.graphics.pop()
end

function RecruitmentModal:draw(mx, my)
    if not self.recruitmentManager.isRecruiting then
        return
    end

    local screenW, screenH = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    if not self.recruitmentManager.hunterCandidates or #self.recruitmentManager.hunterCandidates == 0 then
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro ao gerar candidatos!", 0, screenH / 2, screenW, "center")
        return
    end

    local numCandidates = #self.recruitmentManager.hunterCandidates
    for i = 1, numCandidates do
        if i ~= self.hoveredIndex then
            self:_drawCard(i)
        end
    end

    if self.hoveredIndex then
        self:_drawCard(self.hoveredIndex)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function RecruitmentModal:_createOrUpdateModalElements()
    local screenW, screenH = love.graphics.getDimensions()
    local numCandidates = #self.recruitmentManager.hunterCandidates
    local totalPadding = 40
    local modalColumnGap = 20
    local fixedModalContentHeight = screenH * 0.95
    local availableWidthForColumns = screenW - (totalPadding * 2) - (modalColumnGap * (numCandidates - 1))
    local modalBaseY = (screenH - fixedModalContentHeight) / 2
    local modalContentPadding = 14

    if #self.columns ~= numCandidates then
        self.columns = {}
        self.scales = {}
        self.backgroundColors = {}
    end

    for i, candidate in ipairs(self.recruitmentManager.hunterCandidates) do
        local initialWidth = availableWidthForColumns / numCandidates
        local baseX = totalPadding + (i - 1) * (initialWidth + modalColumnGap)

        if not self.columns[i] then
            self.scales[i] = 1.0
            local r, g, b = unpack(colors.window_bg)
            self.backgroundColors[i] = { r, g, b }

            local columnStack = YStack:new({
                x = 0,
                y = 0,
                width = initialWidth,
                height = fixedModalContentHeight,
                padding = modalContentPadding,
                gap = modalColumnGap,
                alignment = "center",
            })

            local headerStack = YStack:new({
                x = 0,
                y = 0,
                width = initialWidth,
                padding = 0,
                gap = 6,
                alignment = "center",
            })
            headerStack:addChild(Text:new({
                width = 0,
                text = candidate.name,
                size = "h1",
                variant = "text_title",
                align = "center",
            }))
            headerStack:addChild(Text:new({
                width = 0,
                text = "Caçador Rank " .. candidate.finalRankId,
                size = "h2",
                variant = "rank_" .. candidate.finalRankId,
                align = "center",
            }))
            columnStack:addChild(headerStack)

            local attributesComponent = HunterAttributesList:new({
                attributes = candidate.finalStats,
                archetypes = candidate.archetypes,
                archetypeManager = self.archetypeManager,
            })
            local attributesSection = Section:new({
                titleConfig = { text = "Atributos", font = fonts.main_large },
                contentComponent = attributesComponent,
                gap = 10,
            })
            columnStack:addChild(attributesSection)

            local archetypeGrid = Grid:new({ width = initialWidth, columns = 3, gap = { vertical = 5, horizontal = 5 } })
            if candidate.archetypes and #candidate.archetypes > 0 then
                for _, d in ipairs(candidate.archetypes) do
                    archetypeGrid:addChild(ArchetypeDetails:new({ archetypeData = d, showModifiers = false }))
                end
            else
                archetypeGrid:addChild(Text:new({ text = "Nenhum", width = initialWidth, align = "center" }))
            end
            local archetypeSection = Section:new({
                titleConfig = { text = "Arquétipos", font = fonts.main_large },
                contentComponent = archetypeGrid,
                gap = 10,
            })
            columnStack:addChild(archetypeSection)

            self.columns[i] = columnStack
        end

        local stack = self.columns[i]
        stack.rect.x = baseX
        stack.rect.y = modalBaseY
        stack.rect.w = initialWidth
        stack.rect.h = fixedModalContentHeight
        stack:_updateLayout()
    end
end

function RecruitmentModal:update(dt, mx, my, allowHover)
    if not self.recruitmentManager.isRecruiting then
        if #self.columns > 0 then -- Limpa estado ao fechar
            self.columns = {}
            self.scales = {}
            self.backgroundColors = {}
            self.hoveredIndex = nil
        end
        return
    end

    if #self.columns == 0 then
        self:_createOrUpdateModalElements()
    end

    -- Lógica de Hover e Animação de Escala
    local screenW, screenH = love.graphics.getDimensions()
    local numCandidates = #self.columns
    if numCandidates == 0 then return end

    local totalPadding = 40
    local modalColumnGap = 20
    local availableWidth = screenW - (totalPadding * 2) - (modalColumnGap * (numCandidates - 1))
    local baseCardWidth = availableWidth / numCandidates
    local fixedModalContentHeight = screenH * 0.95
    local modalBaseY = (screenH - fixedModalContentHeight) / 2

    -- Detecta qual card está sob o mouse (usando as posições BASE)
    self.hoveredIndex = nil
    if allowHover then
        for i = 1, numCandidates do
            local cardX = totalPadding + (i - 1) * (baseCardWidth + modalColumnGap)
            if mx >= cardX and mx < cardX + baseCardWidth and my >= modalBaseY and my < modalBaseY + fixedModalContentHeight then
                self.hoveredIndex = i
                break
            end
        end
    end

    -- Anima (lerp) a escala e a cor atual em direção ao alvo
    local lerpFactor = dt * 8.0
    for i = 1, numCandidates do
        -- Animação da escala
        local targetScale = (i == self.hoveredIndex) and 1.05 or 1.0
        self.scales[i] = (self.scales[i] or 1.0) + (targetScale - self.scales[i]) * lerpFactor
        local currentScale = self.scales[i]

        -- Animação da cor
        local targetColor = (i == self.hoveredIndex) and colors.slot_hover_bg or colors.window_bg
        local currentColor = self.backgroundColors[i]
        currentColor[1] = lume.lerp(currentColor[1], targetColor[1], lerpFactor)
        currentColor[2] = lume.lerp(currentColor[2], targetColor[2], lerpFactor)
        currentColor[3] = lume.lerp(currentColor[3], targetColor[3], lerpFactor)

        -- Transforma as coordenadas do mouse para o sistema de coordenadas do card escalado
        local tmx, tmy = mx, my
        local cardIsHovered = allowHover and self.hoveredIndex == i
        if currentScale ~= 1.0 then
            local cardStack = self.columns[i]
            local cardCenterX = cardStack.rect.x + cardStack.rect.w / 2
            local cardCenterY = cardStack.rect.y + cardStack.rect.h / 2
            tmx = cardCenterX + (mx - cardCenterX) / currentScale
            tmy = cardCenterY + (my - cardCenterY) / currentScale
        end

        self.columns[i]:update(dt, tmx, tmy, cardIsHovered)
    end
end

function RecruitmentModal:handleMousePress(x, y, button)
    if not self.recruitmentManager.isRecruiting or button ~= 1 then return false end

    -- O clique agora é no próprio card, que é verificado pelo hoverIndex
    if self.hoveredIndex then
        local index = self.hoveredIndex
        Logger.debug("[RecruitmentModal]", string.format("Card %d clicado para recrutar.", index))
        local newHunterId = self.recruitmentManager:recruitCandidate(index)
        if self.onRecruit then self.onRecruit(newHunterId) end
        return true -- Consome o clique
    end

    return true -- Consome o clique na área do modal para evitar interação com a tela de fundo
end

function RecruitmentModal:handleMouseRelease(x, y, button)
    if not self.recruitmentManager.isRecruiting or button ~= 1 then return false end

    -- Não há mais botões para tratar o release, mas consumimos para evitar click-through
    for i, stack in pairs(self.columns) do
        stack:handleMouseRelease(x - stack.rect.x, y - stack.rect.y - (stack.scrollY or 0), button)
    end
    return true
end

function RecruitmentModal:handleKeyPress(key)
    if key == "escape" then
        self.recruitmentManager:cancelRecruitment()
    end
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
