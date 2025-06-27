local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local Button = require("src.ui.components.button")
local HunterStatsColumn = require("src.ui.components.HunterStatsColumn")
local HunterEquipmentColumn = require("src.ui.components.HunterEquipmentColumn")
local HunterLoadoutColumn = require("src.ui.components.HunterLoadoutColumn")
local ItemDetailsModalManager = require("src.managers.item_details_modal_manager")
local RecruitmentManager = require("src.managers.recruitment_manager")
local RecruitmentModal = require("src.ui.components.recruitment_modal")

---@class AgencyScreen
---@field hunterManager HunterManager
---@field archetypeManager ArchetypeManager
---@field itemDataManager ItemDataManager
---@field loadoutManager LoadoutManager
---@field agencyManager AgencyManager
---@field recruitmentManager RecruitmentManager
---@field recruitmentModal RecruitmentModal
---@field selectedHunterId string|nil ID do caçador atualmente selecionado na lista.
---@field hunterListScrollY number Posição Y atual do scroll da lista de caçadores.
---@field hunterSlotRects table<string, table> Retângulos calculados para cada slot de caçador { [hunterId] = {x, y, w, h} }.
---@field recruitButton Button|nil Instância do botão de recrutar.
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

    instance.recruitmentManager = RecruitmentManager:new(hunterManager, archetypeManager)
    instance.recruitmentModal = RecruitmentModal:new(instance.recruitmentManager, archetypeManager)
    -- Callback para quando um recruta é escolhido no modal
    instance.recruitmentModal.onRecruit = function(newHunterId)
        if newHunterId then
            instance.selectedHunterId = newHunterId -- Seleciona o novo caçador na lista
        end
    end

    instance.selectedHunterId = hunterManager:getActiveHunterId() -- Começa selecionando o ativo
    instance.hunterListScrollY = 0
    instance.hunterSlotRects = {}
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
        instance.recruitmentManager:startRecruitment()
    end

    -- Cria a instância do botão de Recrutar
    local screenW, screenH = love.graphics.getDimensions()
    local contentH = screenH - 50
    local buttonW = 180
    local buttonH = 40
    local buttonPadding = 15
    local buttonX = (screenW - buttonW) / 2
    local buttonY = contentH - buttonH - buttonPadding

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

    local contentY = 0
    local contentH = h

    -- Layout Básico do Conteúdo
    local listWidth = math.floor(w * 0.25) -- Largura da lista
    local detailsX = listWidth + 10        -- Posição X da área de detalhes
    local detailsWidth = w - detailsX      -- Largura da área de detalhes

    -- Resetar retângulos da lista a cada frame
    self.hunterSlotRects = {}

    -- 2.1 Desenhar Lista de Caçadores (Esquerda)
    local listStartY = 20 -- Posição Y inicial DENTRO da área de conteúdo
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
        local buttonLocalY = contentY + currentListY +
            10                                                             -- Y relativo a (x, y), 10px abaixo do último slot
        local buttonLocalX = (listWidth - self.setActiveButton.rect.w) / 2 -- X relativo a (x, y)

        -- Para desenho, usa coordenadas locais (após translate)
        self.setActiveButton.rect.x = buttonLocalX
        self.setActiveButton.rect.y = buttonLocalY

        -- Armazena coordenadas globais para update
        self.setActiveButtonGlobalX = x + buttonLocalX
        self.setActiveButtonGlobalY = y + buttonLocalY

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
            local detailsPadding = 20
            local titleFont = fonts.title or love.graphics.getFont()
            local titleHeight = titleFont:getHeight()
            local titleMarginBottom = 10 -- Espaço abaixo do título

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
    if self.recruitButton then
        self.recruitButton:draw()
    end

    love.graphics.pop() -- Restaura transformações e estado gráfico

    -- 4. Desenhar Modal de Recrutamento (se ativo)
    -- O modal é desenhado em coordenadas globais (tela cheia)
    self.recruitmentModal:draw(mx, my)

    -- Desenha o Tooltip no final, somente se o modal de recrutamento não estiver ativo
    if not self.recruitmentManager.isRecruiting then
        ItemDetailsModalManager.draw()
    end
end

function AgencyScreen:update(dt, mx, my, allowHover)
    self.itemToShowTooltip = nil -- Reseta a cada frame

    -- O hover geral é permitido se o modal de recrutamento NÃO estiver ativo.
    local isHoverAllowed = allowHover and not self.recruitmentManager.isRecruiting

    -- Atualiza o modal de recrutamento primeiro. Ele internamente sabe se está ativo ou não.
    self.recruitmentModal:update(dt, mx, my, allowHover)

    if self.setActiveButton then
        local canSetActive = self.selectedHunterId ~= nil and
            self.selectedHunterId ~= self.hunterManager:getActiveHunterId()
        self.setActiveButton.isEnabled = canSetActive

        -- Usa coordenadas globais para detecção de hover/clique
        if self.setActiveButtonGlobalX and self.setActiveButtonGlobalY then
            -- Temporariamente ajusta as coordenadas do botão para globais
            local originalX, originalY = self.setActiveButton.rect.x, self.setActiveButton.rect.y
            self.setActiveButton.rect.x = self.setActiveButtonGlobalX
            self.setActiveButton.rect.y = self.setActiveButtonGlobalY

            self.setActiveButton:update(dt, mx, my, isHoverAllowed)

            -- Restaura coordenadas locais
            self.setActiveButton.rect.x = originalX
            self.setActiveButton.rect.y = originalY
        else
            self.setActiveButton:update(dt, mx, my, isHoverAllowed)
        end
    end

    if self.recruitButton then
        -- Lógica de habilitação movida para o update, que é o local correto.
        self.recruitButton.isEnabled = not self.recruitmentManager.isRecruiting
        self.recruitButton:update(dt, mx, my, isHoverAllowed)
    end

    -- Atualiza o ItemDetailsModalManager com o item que está sob o mouse no slot de equipamento
    if not self.recruitmentManager.isRecruiting and self.selectedHunterId and self.equipmentSlotAreas and allowHover then
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

    ItemDetailsModalManager.update(dt, mx, my, self.itemToShowTooltip)
end

---@param key string
---@return boolean
function AgencyScreen:handleKeyPress(key)
    if self.recruitmentManager.isRecruiting then
        if self.recruitmentModal:handleKeyPress(key) then
            return true
        end
    end
    return false
end

function AgencyScreen:handleMousePress(clickX, clickY, button)
    Logger.debug("[AgencyScreen]", string.format("handleMousePress recebido em (%d, %d)", clickX, clickY))

    -- O modal de recrutamento tem prioridade de input somente se estiver ativo.
    if self.recruitmentManager.isRecruiting then
        -- Se o modal consumir o clique, encerramos o processamento aqui.
        if self.recruitmentModal:handleMousePress(clickX, clickY, button) then
            return true
        end
        -- Se o modal estiver ativo mas não consumiu o clique (ex: clique fora dos elementos),
        -- ainda queremos impedir a interação com a tela de fundo, então retornamos true.
        return true
    end

    -- Se o modal não estiver ativo, processa os cliques da tela principal.
    if button == 1 then
        if self.setActiveButton then
            -- Usa coordenadas globais para detecção de clique
            if self.setActiveButtonGlobalX and self.setActiveButtonGlobalY then
                -- Temporariamente ajusta as coordenadas do botão para globais
                local originalX, originalY = self.setActiveButton.rect.x, self.setActiveButton.rect.y
                self.setActiveButton.rect.x = self.setActiveButtonGlobalX
                self.setActiveButton.rect.y = self.setActiveButtonGlobalY

                local consumed = self.setActiveButton:handleMousePress(clickX, clickY, button)

                -- Restaura coordenadas locais
                self.setActiveButton.rect.x = originalX
                self.setActiveButton.rect.y = originalY

                if consumed then
                    return true
                end
            else
                if self.setActiveButton:handleMousePress(clickX, clickY, button) then
                    return true
                end
            end
        end

        if self.recruitButton then
            Logger.debug("[AgencyScreen]", "Verificando clique no botão Recrutar...")
            local consumed = self.recruitButton:handleMousePress(clickX, clickY, button)
            if consumed then
                Logger.debug("[AgencyScreen]", "Clique consumido pelo botão Recrutar.")
                return true
            end
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
    return false
end

function AgencyScreen:handleMouseRelease(clickX, clickY, button)
    -- O modal de recrutamento tem prioridade de input somente se estiver ativo.
    if self.recruitmentManager.isRecruiting then
        -- Se o modal consumir o release, encerramos.
        if self.recruitmentModal:handleMouseRelease(clickX, clickY, button) then
            return true
        end
        -- Impede o "click-through" para a tela de fundo.
        return true
    end

    -- Se o modal não estiver ativo, processa os releases da tela principal.
    if button == 1 then
        if self.setActiveButton then
            -- Usa coordenadas globais para detecção de release
            if self.setActiveButtonGlobalX and self.setActiveButtonGlobalY then
                -- Temporariamente ajusta as coordenadas do botão para globais
                local originalX, originalY = self.setActiveButton.rect.x, self.setActiveButton.rect.y
                self.setActiveButton.rect.x = self.setActiveButtonGlobalX
                self.setActiveButton.rect.y = self.setActiveButtonGlobalY

                local consumed = self.setActiveButton:handleMouseRelease(clickX, clickY, button)

                -- Restaura coordenadas locais
                self.setActiveButton.rect.x = originalX
                self.setActiveButton.rect.y = originalY

                if consumed then
                    return true
                end
            else
                if self.setActiveButton:handleMouseRelease(clickX, clickY, button) then
                    return true
                end
            end
        end

        if self.recruitButton then
            local consumed = self.recruitButton:handleMouseRelease(clickX, clickY, button)
            if consumed then return true end
        end
    end
    return false
end

function AgencyScreen:handleMouseScroll(dx, dy, mx, my)
    -- O modal de recrutamento tem prioridade de input
    if self.recruitmentManager.isRecruiting then
        if self.recruitmentModal:handleMouseScroll(dx, dy, mx, my) then
            return true
        end
    end

    -- Se o scroll não foi consumido pelo modal, não faz mais nada.
    return false
end

return AgencyScreen
