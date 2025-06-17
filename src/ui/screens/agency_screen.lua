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
local ItemDataManager = require("src.managers.item_data_manager")                -- << NOVO
local LoadoutManager = require("src.managers.loadout_manager")                   -- << NOVO
local HunterStatsColumn = require("src.ui.components.HunterStatsColumn")         -- << NOVO
local HunterEquipmentColumn = require("src.ui.components.HunterEquipmentColumn") -- << NOVO
local HunterLoadoutColumn = require("src.ui.components.HunterLoadoutColumn")     -- << NOVO
local ItemDetailsModalManager = require("src.managers.item_details_modal_manager")

---@class AgencyScreen
---@field hunterManager HunterManager
---@field archetypeManager ArchetypeManager
---@field itemDataManager ItemDataManager
---@field loadoutManager LoadoutManager
---@field agencyManager AgencyManager
---@field selectedHunterId string|nil ID do caçador atualmente selecionado na lista.
---@field hunterListScrollY number Posição Y atual do scroll da lista de caçadores.
---@field hunterSlotRects table<string, table> Retângulos calculados para cada slot de caçador { [hunterId] = {x, y, w, h} }.
---@field recruitButton Button|nil Instância do botão de recrutar.
---@field recruitCancelButton Button|nil Instância do botão de cancelar no modal.
---@field isRecruiting boolean Flag que indica se o modal de recrutamento está ativo.
---@field hunterCandidates table|nil Lista de dados dos caçadores candidatos gerados.
---@field recruitModalColumns table<number, YStack>|nil Colunas (YStacks) com o conteúdo scrollável.
---@field recruitModalButtons table<number, Button>|nil Botões "Escolher" abaixo de cada coluna.
---@field isActiveFrame boolean
---@field setActiveButton Button|nil Instância do botão 'Definir Ativo'.
---@field hoveredItemOwnerSignature string
---@field equipmentSlotAreas table|nil Áreas dos slots de equipamento do caçador selecionado
---@field itemToShowTooltip table|nil
local AgencyScreen = {}
AgencyScreen.__index = AgencyScreen

--- Cria uma nova instância da tela da Agência.
---@param hunterManager HunterManager
---@param archetypeManager ArchetypeManager
---@param itemDataManager ItemDataManager
---@param loadoutManager LoadoutManager
---@param agencyManager AgencyManager
---@return AgencyScreen
function AgencyScreen:new(hunterManager, archetypeManager, itemDataManager, loadoutManager, agencyManager)
    print("[AgencyScreen] Creating new instance...")
    local instance = setmetatable({}, AgencyScreen)
    instance.hunterManager = hunterManager
    instance.archetypeManager = archetypeManager
    instance.itemDataManager = itemDataManager
    instance.loadoutManager = loadoutManager
    instance.agencyManager = agencyManager
    instance.selectedHunterId = hunterManager:getActiveHunterId() -- Começa selecionando o ativo
    instance.hunterListScrollY = 0
    instance.hunterSlotRects = {}
    instance.isRecruiting = false -- Modal começa inativo
    instance.hunterCandidates = nil
    instance.recruitModalColumns = {}
    instance.recruitModalButtons = {}
    instance.isActiveFrame = false
    instance.recruitCancelButton = nil
    instance.setActiveButton = nil
    instance.equipmentSlotAreas = nil
    instance.itemToShowTooltip = nil

    if not instance.hunterManager or not instance.archetypeManager or not instance.itemDataManager or not instance.loadoutManager or not instance.agencyManager then
        error(
            "[AgencyScreen] CRITICAL ERROR: um dos managers não foi injetado!")
    end

    -- Define a função onClick para o botão de recrutar
    local function onClickRecruit()
        print("[AgencyScreen] Recruit Hunter onClick triggered!")
        -- Gera os candidatos
        instance.hunterCandidates = instance.hunterManager:generateHunterCandidates(3) -- Gera 3 opções
        if instance.hunterCandidates and #instance.hunterCandidates > 0 then
            instance.isRecruiting = true                                               -- Ativa o modo modal
            instance.recruitButton.isEnabled = false                                   -- Desabilita o botão principal
            instance.recruitModalColumns = {}                                          -- Limpa/reseta colunas do modal anterior
            print(string.format("  >> Generated %d candidates. Recruitment modal active.", #instance.hunterCandidates))
            -- Cria o botão Cancelar AQUI, quando o modal é ativado
            instance:_createRecruitCancelButton()
        else
            print("ERROR [AgencyScreen]: Failed to generate hunter candidates.")
            -- Poderia mostrar uma mensagem de erro na UI
        end
    end

    -- Cria a instância do botão de Recrutar
    local screenW, screenH = love.graphics.getDimensions()
    local headerHeight = 60
    local contentH = screenH - headerHeight - 50
    local buttonW = 180
    local buttonH = 40
    local buttonPadding = 15
    local buttonX = (screenW - buttonW) / 2
    local buttonY = headerHeight + contentH - buttonH - buttonPadding

    instance.recruitButton = Button:new({
        rect = { x = buttonX, y = buttonY, w = buttonW, h = buttonH },
        text = "Recrutar Caçador",
        variant = "primary",
        onClick = onClickRecruit,
        font = fonts.main
    })

    -- <<< CRIAÇÃO DO BOTÃO 'DEFINIR ATIVO' >>>
    local function onClickSetActive()
        if instance.selectedHunterId and instance.selectedHunterId ~= instance.hunterManager:getActiveHunterId() then
            print(string.format("[AgencyScreen] Setting active hunter to: %s", instance.selectedHunterId))
            local success = instance.hunterManager:setActiveHunter(instance.selectedHunterId)
            if success then
                print("  >> Active hunter set successfully.")
            else
                print("  >> Failed to set active hunter.")
            end
            instance.setActiveButton.isEnabled = (instance.selectedHunterId ~= instance.hunterManager:getActiveHunterId())
        end
    end

    -- Cria a instância do botão 'Definir Ativo'
    local setActiveButtonW = 180
    local setActiveButtonH = 40
    instance.setActiveButton = Button:new({
        rect = { w = setActiveButtonW, h = setActiveButtonH }, -- x, y definidos dinamicamente no draw
        text = "Definir Ativo",
        variant = "secondary",
        onClick = onClickSetActive,
        font = fonts.main,
        isEnabled = false -- Começa desabilitado, será atualizado no :update
    })

    print(string.format("[AgencyScreen] Ready. Initial selected hunter: %s", instance.selectedHunterId or "None"))
    return instance
end

function AgencyScreen:draw(x, y, w, h, mx, my)
    love.graphics.setFont(fonts.main) -- Usar fonte padrão
    love.graphics.push()
    love.graphics.translate(x, y)

    local headerHeight = 60
    local agencyData = self.agencyManager:getAgencyData()
    local agencyName = (agencyData and agencyData.name) or "Agência Desconhecida"
    local agencyRank = (agencyData and agencyData.rank) or "E"
    local agencyReputation = (agencyData and agencyData.reputation) or 0
    local currentHunters = table.maxn(self.hunterManager.hunters or {})
    local maxHunters = 20

    love.graphics.setFont(fonts.title)
    love.graphics.setColor(colors.text_title)
    love.graphics.printf(agencyName, 0, 5, w, "center")

    love.graphics.setFont(fonts.main_large or fonts.main)
    local padding = 40
    local rankColor = (colors.rankDetails[agencyRank] and colors.rankDetails[agencyRank].text) or colors.text_default
    love.graphics.setColor(colors.text_label)
    love.graphics.print("Rank: ", padding, 35)
    love.graphics.setColor(rankColor)
    love.graphics.print(agencyRank, padding + fonts.main_large:getWidth("Rank: "), 35)

    local countText = string.format("Caçadores: %d/%d", currentHunters, maxHunters)
    love.graphics.setColor(colors.text_label)
    love.graphics.printf(countText, 0, 35, w, "center")

    local reputationText = string.format("Reputação: %d", agencyReputation)
    love.graphics.setColor(colors.text_label)
    love.graphics.print(reputationText, w - fonts.main_large:getWidth(reputationText) - padding, 35)

    love.graphics.setColor(colors.window_border)
    love.graphics.line(10, headerHeight - 5, w - 10, headerHeight - 5)

    local contentY = headerHeight
    local contentH = h - headerHeight

    -- Layout Básico do Conteúdo
    local listWidth = math.floor(w * 0.25) -- Largura da lista
    local detailsX = listWidth + 10        -- Posição X da área de detalhes
    local detailsWidth = w - detailsX      -- Largura da área de detalhes

    -- Resetar retângulos da lista a cada frame
    self.hunterSlotRects = {}

    -- 2.1 Desenhar Lista de Caçadores (Esquerda)
    local listStartY = 10 -- Posição Y inicial DENTRO da área de conteúdo
    local currentListY = listStartY
    local slotHeight = 60
    local slotPadding = 5
    local listContentWidth = listWidth - 20         -- Largura interna com padding
    local listVisibleHeight = contentH - listStartY -- Altura visível para a lista

    -- Desenha um fundo para a lista (agora dentro da área de conteúdo)
    love.graphics.setColor(colors.panel_bg)
    love.graphics.rectangle("fill", 0, contentY, listWidth, contentH)
    love.graphics.setColor(colors.white) -- Reset cor

    -- Itera sobre todos os caçadores gerenciados
    love.graphics.push()
    love.graphics.translate(0, contentY) -- Translada para o início da área de conteúdo da lista
    -- TODO: Adicionar Scissor/Clipping para a lista aqui se o scroll for implementado
    -- love.graphics.scissor(0, listStartY, listWidth, listVisibleHeight)
    for hunterId, hunterData in pairs(self.hunterManager.hunters) do
        local isSelected = (hunterId == self.selectedHunterId)
        local isActive = (hunterId == self.hunterManager:getActiveHunterId())
        local slotX = 10
        local slotW = listContentWidth

        -- Calcula o retângulo do slot e armazena (Coordenadas RELATIVAS à tela, não à área de conteúdo)
        local slotScreenY = y + contentY + currentListY -- Ajusta para coordenadas da tela
        local rect = { x = x + slotX, y = slotScreenY, w = slotW, h = slotHeight }
        self.hunterSlotRects[hunterId] = rect

        -- Verifica hover (usa coordenadas da tela)
        local isHovering = mx >= rect.x and mx < rect.x + rect.w and my >= rect.y and my < rect.y + rect.h

        -- Define cor de fundo do slot
        if isSelected then
            love.graphics.setColor(isHovering and colors.tab_highlighted_hover or colors.tab_highlighted_bg)
        elseif isHovering then
            love.graphics.setColor(colors.slot_hover_bg)
        else
            love.graphics.setColor(colors.slot_bg)
        end
        love.graphics.rectangle("fill", slotX, currentListY, slotW, slotHeight)

        -- Desenha borda se for o caçador ativo
        if isActive then
            love.graphics.setLineWidth(2)
            love.graphics.setColor(colors.border_active)
            love.graphics.rectangle("line", slotX, currentListY, slotW, slotHeight)
            love.graphics.setLineWidth(1) -- Reset largura da linha
        end

        -- Desenha informações do caçador no slot
        love.graphics.setColor(colors.text_default)
        love.graphics.printf(hunterData.name or ("Hunter " .. hunterId), slotX + 5, currentListY + 5, slotW - 10, "left")
        love.graphics.printf(string.format("Rank: %s", hunterData.finalRankId or "?"), slotX + 5, currentListY + 25,
            slotW - 10, "left")
        if isActive then
            love.graphics.setColor(colors.text_highlight)
            love.graphics.printf("(Ativo)", slotX + 5, currentListY + 45, slotW - 10, "left")
        end

        currentListY = currentListY + slotHeight + slotPadding -- Move para o próximo slot
    end
    -- love.graphics.scissor() -- Desativa o Scissor
    love.graphics.pop() -- Restaura translação da lista

    -- <<< DESENHO DO BOTÃO 'Definir Ativo' >>>
    if self.setActiveButton then
        -- Posiciona ABAIXO do último slot desenhado, centralizado na coluna da lista
        -- currentListY está relativo à área de conteúdo (0, contentY)
        -- O botão será desenhado relativo a (x, y) da AgencyScreen
        local buttonDrawY = contentY + currentListY +
            10                                                            -- Y relativo a (x, y), 10px abaixo do último slot
        local buttonDrawX = (listWidth - self.setActiveButton.rect.w) / 2 -- X relativo a (x, y)
        self.setActiveButton.rect.x = buttonDrawX
        self.setActiveButton.rect.y = buttonDrawY
        self.setActiveButton:draw() -- Desenha relativo a (x, y)
    end
    -- <<< FIM DESENHO BOTÃO >>>

    -- 2.2 Desenhar Área de Detalhes (Direita, dentro da área de conteúdo)
    love.graphics.setColor(colors.panel_bg) -- Fundo para área de detalhes
    love.graphics.rectangle("fill", detailsX, contentY, detailsWidth, contentH)
    love.graphics.setColor(colors.white)    -- Reset cor

    if self.selectedHunterId then
        local selectedData = self.hunterManager.hunters[self.selectedHunterId]
        if selectedData then
            local detailsPadding = 10
            local titleFont = fonts.title or love.graphics.getFont()
            local titleHeight = titleFont:getHeight()
            local titleMarginBottom = 5 -- Espaço abaixo do título (Reduzido de 15 para 5)

            -- Posição Y inicial para os TÍTULOS
            local titlesY = contentY + detailsPadding
            -- Posição Y inicial para o CONTEÚDO (abaixo dos títulos)
            local detailsContentY = titlesY + titleHeight + titleMarginBottom
            -- Largura do conteúdo
            local detailsContentWidth = detailsWidth - (detailsPadding * 2)
            -- Altura restante para o conteúdo
            local detailsContentHeight = contentH - (titlesY - contentY) - titleHeight - titleMarginBottom -
                detailsPadding

            local columnPadding = 10

            -- Divide a largura disponível para as 3 colunas
            local availableWidth = detailsContentWidth - (columnPadding * 2) -- Espaço entre 3 colunas

            if availableWidth > 0 then
                local statsColW = math.floor(availableWidth * 0.34)        -- Atributos/Arquétipos (um pouco maior)
                local equipColW = math.floor(availableWidth * 0.33)        -- Equipamento
                local loadoutColW = availableWidth - statsColW - equipColW -- Loadout/Mochila (restante)

                local statsColX = detailsX +
                    detailsPadding -- Posição X da coluna de stats (relativa à tela)
                local equipColX = statsColX + statsColW + columnPadding
                local loadoutColX = equipColX + equipColW + columnPadding

                -- <<< DESENHA TÍTULOS >>>
                love.graphics.setFont(titleFont)
                love.graphics.setColor(colors.text_highlight)
                love.graphics.printf("Atributos", statsColX, titlesY, statsColW, "center") -- Centraliza no espaço da coluna
                love.graphics.printf("Equipamento", equipColX, titlesY, equipColW, "center")
                love.graphics.printf("Mochila", loadoutColX, titlesY, loadoutColW, "center")
                love.graphics.setFont(fonts.main) -- Restaura fonte padrão
                love.graphics.setColor(colors.white)
                -- <<< FIM DESENHO TÍTULOS >>>

                -- <<< DESENHA CONTEÚDO DAS COLUNAS (usando novas Y e Height) >>>
                -- 1. Desenha Coluna de Stats e Arquétipos
                local finalStatsData = self.hunterManager:getHunterFinalStats(self.selectedHunterId) -- Pega stats do selecionado
                if finalStatsData and selectedData.archetypeIds and self.archetypeManager then
                    local configForColumn = {
                        finalStats = finalStatsData,
                        archetypeIds = selectedData.archetypeIds,
                        archetypeManager = self.archetypeManager,
                        mouseX = mx, -- mx global da AgencyScreen:draw
                        mouseY = my  -- my global da AgencyScreen:draw
                        -- Campos opcionais de gameplay (currentHp, level, etc.) não são passados aqui intencionalmente,
                        -- pois esta é a tela da Agência, não gameplay.
                    }
                    HunterStatsColumn.draw(statsColX, detailsContentY, statsColW, detailsContentHeight, configForColumn)
                else
                    love.graphics.setColor(colors.red)
                    love.graphics.printf("Dados Stats/Arch Indisp.", statsColX,
                        detailsContentY + detailsContentHeight / 2,
                        statsColW, "center")
                end

                -- 2. Desenha Coluna de Equipamento
                if self.hunterManager then
                    -- Passa o ID do caçador selecionado para a coluna
                    self.equipmentSlotAreas = HunterEquipmentColumn.draw(
                        equipColX,
                        detailsContentY,
                        equipColW,
                        detailsContentHeight,
                        self.selectedHunterId
                    )
                else
                    love.graphics.setColor(colors.red)
                    love.graphics.printf("HunterMan. Indisp.", equipColX, detailsContentY + detailsContentHeight / 2,
                        equipColW, "center")
                end

                -- 3. Desenha Coluna de Loadout (Mochila)
                if self.loadoutManager and self.itemDataManager then
                    -- Passa os managers, a coluna internamente pegará os dados do caçador ativo (definido via setActiveHunter)
                    HunterLoadoutColumn.draw(loadoutColX, detailsContentY, loadoutColW, detailsContentHeight,
                        self.loadoutManager, self.itemDataManager)
                else
                    love.graphics.setColor(colors.red)
                    love.graphics.printf("Loadout/ItemMan. Indisp.", loadoutColX,
                        detailsContentY + detailsContentHeight / 2, loadoutColW, "center")
                end
                -- <<< FIM DESENHO CONTEÚDO >>>
            else
                -- Não há espaço suficiente para as colunas
                love.graphics.setColor(colors.text_muted)
                love.graphics.printf("Área de detalhes muito estreita.", detailsContentX, detailsContentY + 20,
                    detailsContentWidth, "center")
            end

            -- TODO: Desenhar Stats Finais
            -- TODO: Desenhar outras informações relevantes
        else
            -- Caçador selecionado não encontrado (erro?)
            love.graphics.setColor(colors.red)
            love.graphics.printf("Erro: Caçador selecionado não encontrado!", detailsX + 10, contentY + 10,
                detailsWidth - 20,
                "center")
        end
    else
        -- Nenhum caçador selecionado
        love.graphics.setColor(colors.text_muted)
        love.graphics.printf("Selecione um caçador na lista.", detailsX + 10, contentY + 10, detailsWidth - 20, "center")
    end

    -- 3. Desenhar Botão de Recrutar (AGORA USANDO A CLASSE BUTTON)
    -- O rect foi calculado e armazenado no self.recruitButton no :new
    -- A posição é relativa à janela inteira
    -- TODO: Ajustar cálculo do rect se AgencyScreen for desenhada com offset (x, y != 0, 0)
    if self.recruitButton then
        self.recruitButton:draw()
    end

    love.graphics.pop() -- Restaura transformações e estado gráfico

    -- 4. Desenhar Modal de Recrutamento (se ativo)
    if self.isRecruiting then
        -- Passa coordenadas globais para o modal
        self:_drawRecruitmentModal(0, 0, w, h, mx, my) -- Usa 0,0 porque o pop anterior restaurou
    end

    -- Desenha o Tooltip no final, somente se o modal de recrutamento não estiver ativo
    if not self.isRecruiting then
        ItemDetailsModalManager.draw()
    end
end

function AgencyScreen:_drawRecruitmentModal(areaX, areaY, areaW, areaH, mx, my)
    -- Fundo semi-transparente (TELA INTEIRA)
    local screenW, screenH = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    if not self.hunterCandidates or #self.hunterCandidates == 0 then
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro ao gerar candidatos!", 0, screenH / 2, screenW, "center") -- Centraliza na tela
        -- Mesmo com erro, desenha o botão Cancelar se ele existir
        if self.recruitCancelButton then
            -- Ajusta a posição X do botão Cancelar se ele foi baseado em areaW
            self.recruitCancelButton.rect.x = (screenW - self.recruitCancelButton.rect.w) / 2
            self.recruitCancelButton:draw()
        end
        return
    end

    -- Cálculos de Dimensão e Posição
    local numCandidates = #self.hunterCandidates
    local totalPadding = 40
    local modalColumnGap = 20
    local modalHeaderGap = 6
    local fixedModalContentHeight = screenH * 0.80 -- Altura da área visível/scrollável
    local buttonAreaHeight = 50                    -- Espaço ABAIXO do card para o botão Escolher
    local totalColumnHeight = fixedModalContentHeight + buttonAreaHeight
    local modalBottomPadding = 80                  -- Espaço abaixo de tudo para o botão Cancelar
    local availableWidthForColumns = areaW - totalPadding
    local modalWidth = math.max(0, (availableWidthForColumns - (modalColumnGap * (numCandidates - 1))) / numCandidates)
    local modalBaseY = areaY + (screenH - totalColumnHeight - modalBottomPadding) / 2 -- Centraliza altura total
    local startX = areaX + (totalPadding / 2)
    local modalContentPadding = 14
    local modalButtonW = 150
    local modalButtonH = 35
    local buttonPaddingY = (buttonAreaHeight - modalButtonH) / 2 -- Padding vertical dentro da área do botão

    for i, candidate in ipairs(self.hunterCandidates) do
        local modalX = startX + (i - 1) * (modalWidth + modalColumnGap)
        local columnStack
        local chooseButton

        if not self.recruitModalColumns[i] then
            print(string.format("Creating YStack column AND Button for candidate %d", i))
            -- 1. Cria a Stack de CONTEÚDO (Header, Attr, Arch)
            columnStack = YStack:new({
                x = modalX, -- Passa posição/largura inicial (embora layout recalcule)
                y = modalBaseY,
                width = modalWidth,
                height = fixedModalContentHeight, -- Altura fixa para clipping interno
                padding = modalContentPadding,
                gap = modalColumnGap,
                alignment = "center",
            })
            -- ... (Adiciona header, attributes, archetypes à columnStack - SEM BOTÃO)
            local headerStack = YStack:new({
                x = 0,
                y = 0,
                width = modalWidth,
                padding = 0,
                gap = modalHeaderGap,
                alignment =
                "center"
            });

            headerStack:addChild(Text:new({
                text = candidate.name,
                width = 0,
                size = "h1",
                variant = "text_title",
                align = "center"
            }))
            headerStack:addChild(Text:new({
                text = "Caçador Rank " .. candidate.finalRankId,
                width = 0,
                size = "h2",
                variant = "rank_" .. candidate.finalRankId,
                align = "center"
            }))

            -- Adiciona headerStack como PRIMEIRO filho da coluna
            columnStack:addChild(headerStack)
            local attributesComponent = HunterAttributesList:new({
                attributes = candidate.finalStats,
                archetypes =
                    candidate.archetypes,
                archetypeManager = self.archetypeManager
            }); local attributesSection = Section:new({
                titleConfig = { text = "Atributos", font = fonts.main_large },
                contentComponent =
                    attributesComponent,
                gap = 10
            }); columnStack:addChild(attributesSection)
            local archetypeGrid = Grid:new({ x = 0, y = 0, width = modalWidth, columns = 3, gap = { vertical = 5, horizontal = 5 } }); if candidate.archetypes and #candidate.archetypes > 0 then
                for _, d in ipairs(candidate.archetypes) do
                    archetypeGrid:addChild(ArchetypeDetails:new({ archetypeData = d }))
                end
            else
                archetypeGrid:addChild(
                    Text:new({ text = "Nenhum", width = modalWidth, align = "center" }))
            end; local archetypeSection = Section:new({
                titleConfig = { text = "Arquétipos", font = fonts.main_large },
                contentComponent =
                    archetypeGrid,
                gap = 10
            }); columnStack:addChild(archetypeSection)

            self.recruitModalColumns[i] = columnStack

            -- 2. Cria e guarda o Botão "Escolher"
            local selfRef = self
            local index = i
            local function onChooseClick() selfRef:_recruitCandidate(index) end
            chooseButton = Button:new({
                rect = { w = modalButtonW, h = modalButtonH }, -- x, y serão definidos depois
                text = "Escolher",
                variant = "primary",
                onClick = onChooseClick,
                font = fonts.main
            })
            self.recruitModalButtons[i] = chooseButton
        else
            columnStack = self.recruitModalColumns[i]
            chooseButton = self.recruitModalButtons[i] -- Pega botão existente
            -- Atualiza dimensões/posição da stack (caso janela mude)
            columnStack.rect.x = modalX
            columnStack.rect.y = modalBaseY
            columnStack.rect.w = modalWidth
            columnStack.fixedHeight = fixedModalContentHeight
            columnStack.needsLayout = true
        end

        -- Calcula layout interno da stack (necessário para scroll)
        columnStack:_updateLayout()

        -- 3. Desenha o Card de fundo (apenas área de conteúdo)
        local cardHeight = fixedModalContentHeight
        local backgroundCard = Card:new({
            rect = { x = modalX, y = modalBaseY, w = modalWidth, h = cardHeight },
            backgroundColor = colors.window_bg,
            borderColor = colors.window_border,
            borderWidth = 1,
        })
        backgroundCard:draw()

        -- 4. Desenha o CONTEÚDO da Stack (com clipping interno e scroll)
        columnStack:draw()

        -- 5. Desenha o Botão "Escolher" ABAIXO do card
        local buttonX = modalX + (modalWidth - modalButtonW) / 2
        local buttonY = modalBaseY + cardHeight + buttonPaddingY -- Abaixo do card, com padding
        chooseButton.rect.x = math.floor(buttonX)
        chooseButton.rect.y = math.floor(buttonY)
        chooseButton:draw()
    end

    -- 6. Desenha o botão Cancelar global
    if self.recruitCancelButton then
        local cancelY = modalBaseY + totalColumnHeight + 20 -- Abaixo da coluna inteira (conteúdo + botão)
        self.recruitCancelButton.rect.x = (screenW - self.recruitCancelButton.rect.w) / 2
        self.recruitCancelButton.rect.y = math.floor(cancelY)
        self.recruitCancelButton:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function AgencyScreen:_closeRecruitmentModal()
    print("[AgencyScreen] Closing recruitment modal.")
    self.isRecruiting = false
    self.hunterCandidates = nil
    self.recruitModalColumns = {}
    self.recruitModalButtons = {}
    self.recruitCancelButton = nil
    if self.recruitButton then self.recruitButton.isEnabled = true end
end

function AgencyScreen:_createRecruitCancelButton()
    local screenW, screenH = love.graphics.getDimensions()
    local buttonW = 150
    local buttonH = 35
    local buttonX = (screenW - buttonW) / 2
    -- A posição Y será ajustada dinamicamente no _drawRecruitmentModal
    local buttonY = screenH - buttonH - 20 -- Posição inicial (será ajustada)

    local selfRef = self
    self.recruitCancelButton = Button:new({
        rect = { x = buttonX, y = buttonY, w = buttonW, h = buttonH },
        text = "Cancelar",
        variant = "secondary", -- Usar variante secundária
        onClick = function() selfRef:_closeRecruitmentModal() end,
        font = fonts.main
    })
    print("[AgencyScreen] Cancel button created for recruitment modal.")
end

function AgencyScreen:_recruitCandidate(candidateIndex)
    if not self.hunterCandidates or not self.hunterCandidates[candidateIndex] then
        print(string.format("ERROR [_recruitCandidate]: Invalid candidate index %d", candidateIndex))
        return
    end

    local chosenCandidate = self.hunterCandidates[candidateIndex]
    print(string.format("[AgencyScreen] Recruiting candidate %d (%s)...", candidateIndex, chosenCandidate.name))

    local newHunterId = self.hunterManager:recruitHunter(chosenCandidate)
    if newHunterId then
        print(string.format("  >> Hunter %s recruited successfully! Closing modal.", newHunterId))
        self.selectedHunterId = newHunterId -- Seleciona o novo caçador
    else
        print("ERROR [AgencyScreen]: Failed to recruit hunter.")
    end

    self:_closeRecruitmentModal()
end

function AgencyScreen:update(mx, my, dt)
    self.isActiveFrame = true -- Marca que a tela está ativa neste frame
    self.itemToShowTooltip = nil

    -- Lógica de hover/clique para a lista de caçadores
    if not self.isRecruiting then -- Só processa cliques na lista se o modal não estiver ativo
        for hunterId, rect in pairs(self.hunterSlotRects) do
            if mx >= rect.x and mx < rect.x + rect.w and my >= rect.y and my < rect.y + rect.h then
                if love.mouse.wasPressed(1) then
                    self.selectedHunterId = hunterId
                    print(string.format("[AgencyScreen] Hunter selected: %s", hunterId))
                end
                break -- Para de checar outros slots se um foi "hoverado"
            end
        end

        -- Lógica de hover para itens de equipamento e inventário do caçador selecionado
        if self.equipmentSlotAreas then
            local equippedItems = self.hunterManager:getEquippedItems(self.selectedHunterId)
            if equippedItems then
                for slotId, area in pairs(self.equipmentSlotAreas) do
                    if area and mx >= area.x and mx < area.x + area.w and my >= area.y and my < area.y + area.h then
                        if equippedItems[slotId] then
                            self.itemToShowTooltip = equippedItems[slotId]
                            break
                        end
                    end
                end
            end
        end
    end

    -- Atualiza o HoverManager com o item que está sob o mouse (se houver)
    ItemDetailsModalManager.update(dt, mx, my, self.itemToShowTooltip)

    -- Atualiza os botões (sempre, para que o de cancelar no modal funcione)
    if self.recruitButton then
        self.recruitButton:update(mx, my)
    end
    if self.recruitCancelButton then
        self.recruitCancelButton:update(mx, my)
    end
    if self.setActiveButton then
        self.setActiveButton.isEnabled = self.selectedHunterId and
        (self.selectedHunterId ~= self.hunterManager:getActiveHunterId())
        self.setActiveButton:update(mx, my)
    end

    -- Atualiza colunas/botões do modal de recrutamento
    if self.isRecruiting then
        for i, col in ipairs(self.recruitModalColumns) do
            col:update(dt, mx, my)
        end
        for i, btn in ipairs(self.recruitModalButtons) do
            btn:update(mx, my)
        end
    end
end

function AgencyScreen:keypressed(key)
    if key == "escape" and self.isRecruiting then
        self:_cancelRecruitment()
        return true -- Impede que o 'escape' feche a LobbyScene
    end
    return false
end

function AgencyScreen:handleMousePress(clickX, clickY, button)
    if self.isActiveFrame then return true end

    if button == 1 then
        if self.isRecruiting then
            if self.recruitCancelButton and self.recruitCancelButton:handleMousePress(clickX, clickY, button) then return true end
            for i, btn in pairs(self.recruitModalButtons) do
                if btn:handleMousePress(clickX, clickY, button) then return true end
            end
            for i, stack in pairs(self.recruitModalColumns) do
                if clickX >= stack.rect.x and clickX < stack.rect.x + stack.rect.w and
                    clickY >= stack.rect.y and clickY < stack.rect.y + stack.rect.h then
                    if stack:handleMousePress(clickX - stack.rect.x, clickY - stack.rect.y - (stack.scrollY or 0), button) then return true end
                end
            end
            return true
        else
            if self.setActiveButton and self.setActiveButton:handleMousePress(clickX, clickY, button) then
                return true
            end

            if self.recruitButton then
                local consumed = self.recruitButton:handleMousePress(clickX, clickY, button)
                if consumed then return true end
            end

            local globalClickX, globalClickY = love.mouse.getPosition()
            for hunterId, rect in pairs(self.hunterSlotRects) do
                if globalClickX >= rect.x and globalClickX < rect.x + rect.w and
                    globalClickY >= rect.y and globalClickY < rect.y + rect.h then
                    if self.selectedHunterId ~= hunterId then
                        self.selectedHunterId = hunterId
                        print(string.format("[AgencyScreen] Hunter selected: %s", hunterId))
                        if self.setActiveButton then
                            self.setActiveButton.isEnabled = (self.selectedHunterId ~= nil and self.selectedHunterId ~= self.hunterManager:getActiveHunterId())
                        end
                    end
                    return true
                end
            end
        end
    end
    return false
end

function AgencyScreen:handleMouseRelease(clickX, clickY, button)
    if button == 1 then
        if self.isRecruiting then
            if self.recruitCancelButton and self.recruitCancelButton:handleMouseRelease(clickX, clickY, button) then return true end
            for i, btn in pairs(self.recruitModalButtons) do
                if btn:handleMouseRelease(clickX, clickY, button) then return true end
            end
            for i, stack in pairs(self.recruitModalColumns) do
                stack:handleMouseRelease(clickX - stack.rect.x, clickY - stack.rect.y - (stack.scrollY or 0), button)
            end
        else
            if self.setActiveButton and self.setActiveButton:handleMouseRelease(clickX, clickY, button) then
                return true
            end

            if self.recruitButton then
                local consumed = self.recruitButton:handleMouseRelease(clickX, clickY, button)
                if consumed then return true end
            end
        end
    end
    return false
end

function AgencyScreen:handleMouseScroll(dx, dy, mx, my)
    if not self.isRecruiting or dy == 0 then return false end

    for i, stack in pairs(self.recruitModalColumns) do
        local stackX, stackY = stack.rect.x, stack.rect.y
        local stackW, stackH = stack.rect.w, stack.rect.h

        if mx >= stackX and mx < stackX + stackW and my >= stackY and my < stackY + stackH then
            local availableHeight = stackH - stack.padding.top - stack.padding.bottom
            local contentHeight = stack.actualHeight

            if contentHeight > availableHeight then
                local scrollSpeed = 30
                local currentScrollY = stack.scrollY or 0
                local newScrollY = currentScrollY - dy * scrollSpeed
                local maxScrollY = math.min(0, availableHeight - contentHeight)
                stack.scrollY = math.clamp(newScrollY, maxScrollY, 0)
                print(string.format("Scrolled column %d. New scrollY: %.2f", i, stack.scrollY))
                return true
            else
                stack.scrollY = 0
            end
        end
    end
    return false
end

return AgencyScreen
