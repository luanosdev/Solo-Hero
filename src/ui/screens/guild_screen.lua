-- src/ui/guild_screen.lua
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local Button = require("src.ui.components.Button")
local YStack = require("src.ui.components.YStack")
local Text = require("src.ui.components.Text")
local Card = require("src.ui.components.Card")
local Section = require("src.ui.components.Section")
local ArchetypeDetails = require("src.ui.components.ArchetypeDetails")

---@class GuildScreen
---@field hunterManager HunterManager
---@field archetypeManager ArchetypeManager
---@field selectedHunterId string|nil ID do caçador atualmente selecionado na lista.
---@field hunterListScrollY number Posição Y atual do scroll da lista de caçadores.
---@field hunterSlotRects table<string, table> Retângulos calculados para cada slot de caçador { [hunterId] = {x, y, w, h} }.
---@field recruitButton Button|nil Instância do botão de recrutar.
---@field recruitCancelButton Button|nil Instância do botão de cancelar no modal.
---@field isRecruiting boolean Flag que indica se o modal de recrutamento está ativo.
---@field hunterCandidates table|nil Lista de dados dos caçadores candidatos gerados.
---@field recruitModalColumns table<number, YStack>|nil Colunas (YStacks) para cada candidato no modal.
---@field isActiveFrame boolean Flag to ignore input on the first frame after activation.
local GuildScreen = {}
GuildScreen.__index = GuildScreen

--- Cria uma nova instância da tela de Guilda.
---@param hunterManager HunterManager
---@param archetypeManager ArchetypeManager
---@return GuildScreen
function GuildScreen:new(hunterManager, archetypeManager)
    print("[GuildScreen] Creating new instance...")
    local instance = setmetatable({}, GuildScreen)
    instance.hunterManager = hunterManager
    instance.archetypeManager = archetypeManager
    instance.selectedHunterId = hunterManager:getActiveHunterId() -- Começa selecionando o ativo
    instance.hunterListScrollY = 0
    instance.hunterSlotRects = {}
    instance.isRecruiting = false      -- Modal começa inativo
    instance.hunterCandidates = nil
    instance.recruitModalColumns = {}  -- Inicializa como tabela vazia
    instance.isActiveFrame = false     -- Initialize flag
    instance.recruitCancelButton = nil -- Inicializa botão cancelar

    if not instance.hunterManager or not instance.archetypeManager then
        error("[GuildScreen] CRITICAL ERROR: hunterManager or archetypeManager not injected!")
    end

    -- Define a função onClick para o botão de recrutar
    -- Ela precisa acessar 'instance' (o self da GuildScreen)
    local function onClickRecruit()
        print("[GuildScreen] Recruit Hunter onClick triggered!")
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
            print("ERROR [GuildScreen]: Failed to generate hunter candidates.")
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

    print(string.format("[GuildScreen] Ready. Initial selected hunter: %s", instance.selectedHunterId or "None"))
    return instance
end

--- Desenha a tela da Guilda.
---@param x number Posição X inicial da área da tela.
---@param y number Posição Y inicial da área da tela.
---@param w number Largura disponível para a tela.
---@param h number Altura disponível para a tela.
---@param mx number Posição X do mouse.
---@param my number Posição Y do mouse.
function GuildScreen:draw(x, y, w, h, mx, my)
    love.graphics.setFont(fonts.main) -- Usar fonte padrão
    love.graphics.push()
    love.graphics.translate(x, y)     -- Translada para o início da área da GuildScreen

    -- 1. Desenhar Cabeçalho
    local headerHeight = 60                                             -- Altura reservada para o cabeçalho
    local guildName = "Guilda dos Heróis Solitários"                    -- Mock
    local guildRank = "S"                                               -- Mock
    local currentHunters = table.maxn(self.hunterManager.hunters or {}) -- Conta caçadores atuais (pode precisar de um método melhor)
    local maxHunters = 20                                               -- Mock

    -- Nome da Guilda
    love.graphics.setFont(fonts.title)
    love.graphics.setColor(colors.text_title)
    love.graphics.printf(guildName, 0, 5, w, "center")

    -- Rank e Contagem (na linha abaixo)
    love.graphics.setFont(fonts.main_large or fonts.main) -- Usar fonte maior se disponível
    local rankColor = colors.rank[guildRank] or colors.text_default
    local rankText = string.format("Rank: %s", guildRank)
    local countText = string.format("Caçadores: %d/%d", currentHunters, maxHunters)
    local rankTextWidth = love.graphics.getFont():getWidth(rankText)
    local countTextWidth = love.graphics.getFont():getWidth(countText)
    local totalInfoWidth = rankTextWidth + countTextWidth + 40 -- Largura total com espaçamento
    local infoStartX = (w - totalInfoWidth) / 2

    love.graphics.setColor(colors.text_label) -- Cor para "Rank:"
    love.graphics.print("Rank: ", infoStartX, 35)
    love.graphics.setColor(rankColor)
    love.graphics.print(guildRank, infoStartX + love.graphics.getFont():getWidth("Rank: "), 35)

    love.graphics.setColor(colors.text_label) -- Cor para "Caçadores:"
    love.graphics.print(countText, infoStartX + rankTextWidth + 40, 35)

    -- Linha separadora (opcional)
    love.graphics.setColor(colors.window_border)
    love.graphics.line(10, headerHeight - 5, w - 10, headerHeight - 5)

    -- 2. Área de Conteúdo Principal (Lista e Detalhes)
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

    -- 2.2 Desenhar Área de Detalhes (Direita, dentro da área de conteúdo)
    love.graphics.setColor(colors.panel_bg) -- Fundo para área de detalhes
    love.graphics.rectangle("fill", detailsX, contentY, detailsWidth, contentH)
    love.graphics.setColor(colors.white)    -- Reset cor

    if self.selectedHunterId then
        local selectedData = self.hunterManager.hunters[self.selectedHunterId]
        if selectedData then
            love.graphics.setFont(fonts.title)
            love.graphics.setColor(colors.text_title)
            love.graphics.printf(selectedData.name or "Unknown Hunter", detailsX + 10, contentY + 10, detailsWidth - 20,
                "center")
            love.graphics.setFont(fonts.main)

            -- Desenha Arquétipos (placeholder)
            local archetypesY = contentY + 60
            love.graphics.setColor(colors.text_default)
            love.graphics.printf("Arquétipos:", detailsX + 10, archetypesY, detailsWidth - 20, "left")
            archetypesY = archetypesY + 25

            if selectedData.archetypeIds and #selectedData.archetypeIds > 0 then
                for i, archetypeId in ipairs(selectedData.archetypeIds) do
                    local archetypeData = self.archetypeManager:getArchetypeData(archetypeId)
                    local text = archetypeData and archetypeData.name or archetypeId -- Usa nome se disponível
                    love.graphics.setColor(colors.text_label)
                    love.graphics.printf("- " .. text, detailsX + 20, archetypesY, detailsWidth - 30, "left")
                    archetypesY = archetypesY + 20
                end
            else
                love.graphics.setColor(colors.text_muted)
                love.graphics.printf("Nenhum arquétipo.", detailsX + 20, archetypesY, detailsWidth - 30, "left")
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
    -- TODO: Ajustar cálculo do rect se GuildScreen for desenhada com offset (x, y != 0, 0)
    if self.recruitButton then
        self.recruitButton:draw()
    end

    love.graphics.pop() -- Restaura transformações e estado gráfico

    -- 4. Desenhar Modal de Recrutamento (se ativo)
    if self.isRecruiting then
        -- Passa coordenadas globais para o modal
        self:_drawRecruitmentModal(0, 0, w, h, mx, my) -- Usa 0,0 porque o pop anterior restaurou
    end
end

--- Desenha os modais de seleção de caçador usando Card e YStack.
function GuildScreen:_drawRecruitmentModal(areaX, areaY, areaW, areaH, mx, my)
    -- Fundo semi-transparente (COBRINDO A TELA INTEIRA)
    local screenW, screenH = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH) -- <<< Usa 0, 0 e dimensões da tela

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

    -- Calcula dimensões e posição base das colunas (Usa areaW/areaH para CÁLCULO, não para fundo)
    local numCandidates = #self.hunterCandidates
    local totalPadding = 40 -- Padding lateral geral do modal
    local modalColumnGap = 20
    local modalHeaderGap = 6
    -- Usa areaW para calcular a largura DISPONÍVEL DENTRO da área da GuildScreen para as colunas
    local availableWidthForColumns = areaW - totalPadding
    local modalWidth = (availableWidthForColumns - (modalColumnGap * (numCandidates - 1))) / numCandidates
    -- Posiciona o início das colunas relativo à área da GuildScreen (areaX)
    local modalBaseY = areaY + 50 -- Y inicial relativo à área da GuildScreen
    local startX = areaX + (totalPadding / 2)

    local modalContentPadding = 14
    local modalButtonW = 150
    local modalButtonH = 35

    -- Encontra a maior altura entre as colunas para posicionar o botão Cancelar abaixo
    local maxColumnHeight = 0

    for i, candidate in ipairs(self.hunterCandidates) do
        local modalX = startX + (i - 1) * (modalWidth + modalColumnGap)
        local columnStack

        if not self.recruitModalColumns[i] then
            print(string.format("Creating YStack column for candidate %d", i))

            -- 1. Cria a Stack Principal (Layout)
            columnStack = YStack:new({
                x = modalX,
                y = modalBaseY,
                width = modalWidth,
                padding = modalContentPadding,
                gap = modalColumnGap, -- <<< Restaura gap original da coluna
                alignment = "center",
            })

            -- 2. Cria e adiciona Header Stack
            local headerStack = YStack:new({
                x = 0,                -- Placeholder, será definido pelo pai
                y = 0,                -- Placeholder, será definido pelo pai
                width = modalWidth,   -- <<< USA A LARGURA DISPONÍVEL CALCULADA
                padding = 0,
                gap = modalHeaderGap, -- Gap entre Nome e Rank
                alignment = "center",
            })
            headerStack:addChild(Text:new({
                text = candidate.name,
                width = 0,
                size = "h1",
                variant = "text_title",
                align = "center"
                -- Sem margin aqui
            }))
            headerStack:addChild(Text:new({
                text = "Caçador Rank " .. candidate.finalRankId,
                width = 0,
                size = "h2",
                variant = "rank_" .. candidate.finalRankId,
                align = "center"
                -- Sem margin aqui
            }))
            -- Adiciona headerStack como PRIMEIRO filho da coluna
            columnStack:addChild(headerStack)

            local archetypesYStack = YStack:new({
                x = 0,
                y = 0,
                width = modalWidth,
                padding = { vertical = 10 },
                gap = 10,
                alignment = "center"
            })

            -- 3. Adiciona DETALHES DOS ARQUÉTIPOS usando o novo componente
            local archetypes = candidate.archetypes -- Assumindo que os dados estão em candidate.archetypes
            if archetypes and #archetypes > 0 then
                for _, archetypeData in ipairs(archetypes) do
                    -- Passa os dados do arquétipo para o componente
                    local detailsComponent = ArchetypeDetails:new({
                        archetypeData = archetypeData
                        -- x, y, width serão definidos pelo columnStack (pai)
                    })
                    archetypesYStack:addChild(detailsComponent)
                end
            else
                -- Opcional: Mostrar um texto se não houver arquétipos
                archetypesYStack:addChild(Text:new({
                    text = "Sem arquétipos.",
                    width = 0,
                    size = "small",
                    variant = "text_muted",
                    align = "left"
                }))
            end

            local archetypeSection = Section:new({
                titleConfig = {
                    text = "Arquétipos",
                    size = "h3",
                    variant = "text_highlight"
                },
                contentComponent = archetypesYStack,
                gap = 10
            })

            columnStack:addChild(archetypeSection)

            -- 4. Adiciona Texto de Stats (Placeholder ainda)
            columnStack:addChild(Text:new({
                text = "Stats: [TODO]",
                width = 0,
                size = "label",
                variant = "text_label",
                align = "left"
            }))

            -- 5. Adiciona Botão
            local selfRef = self
            local index = i
            local function onChooseClick() selfRef:_recruitCandidate(index) end
            local chooseButton = Button:new({
                rect = { w = modalButtonW, h = modalButtonH },
                text = "Escolher",
                variant = "primary",
                onClick = onChooseClick,
                font = fonts.main
                -- Margin top será controlada pelo gap da columnStack
            })
            columnStack:addChild(chooseButton)

            self.recruitModalColumns[i] = columnStack
        else
            columnStack = self.recruitModalColumns[i]
            columnStack.x = modalX
            columnStack.y = modalBaseY
            columnStack.width = modalWidth
            columnStack.needsLayout = true
        end

        -- Calcular layout da YStack ANTES de desenhar o Card
        columnStack:_updateLayout()

        -- Criar e desenhar o Card de fundo
        local backgroundCard = Card:new({
            rect = { x = columnStack.rect.x, y = columnStack.rect.y, w = columnStack.rect.w, h = columnStack.rect.h },
            backgroundColor = colors.window_bg,
            borderColor = colors.window_border,
            borderWidth = 1,
        })
        backgroundCard:draw()

        -- Desenhar a YStack (conteúdo) por cima do Card
        columnStack:draw()

        -- Atualiza altura máxima
        maxColumnHeight = math.max(maxColumnHeight, columnStack.rect.h)
    end

    -- Desenha o botão Cancelar (se existir)
    if self.recruitCancelButton then
        -- Posiciona abaixo da coluna mais alta
        local cancelY = modalBaseY + maxColumnHeight + 30 -- Espaçamento abaixo das colunas
        -- Reposiciona X para centralizar na TELA
        self.recruitCancelButton.rect.x = (screenW - self.recruitCancelButton.rect.w) / 2
        self.recruitCancelButton.rect.y = math.floor(cancelY)
        self.recruitCancelButton:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

--- NOVO: Helper para fechar o modal e limpar estado.
function GuildScreen:_closeRecruitmentModal()
    print("[GuildScreen] Closing recruitment modal.")
    self.isRecruiting = false
    self.hunterCandidates = nil
    self.recruitModalColumns = {}
    self.recruitCancelButton = nil -- Destroi/limpa referência ao botão cancelar
    if self.recruitButton then self.recruitButton.isEnabled = true end
end

--- NOVO: Helper para criar o botão Cancelar do modal.
function GuildScreen:_createRecruitCancelButton()
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
    print("[GuildScreen] Cancel button created for recruitment modal.")
end

--- Método chamado pelo onClick do botão "Escolher".
function GuildScreen:_recruitCandidate(candidateIndex)
    if not self.hunterCandidates or not self.hunterCandidates[candidateIndex] then
        print(string.format("ERROR [_recruitCandidate]: Invalid candidate index %d", candidateIndex))
        return
    end

    local chosenCandidate = self.hunterCandidates[candidateIndex]
    print(string.format("[GuildScreen] Recruiting candidate %d (%s)...", candidateIndex, chosenCandidate.name))

    local newHunterId = self.hunterManager:recruitHunter(chosenCandidate)
    if newHunterId then
        print(string.format("  >> Hunter %s recruited successfully! Closing modal.", newHunterId))
        self.selectedHunterId = newHunterId -- Seleciona o novo caçador
    else
        print("ERROR [GuildScreen]: Failed to recruit hunter.")
        -- Manter modal aberto ou mostrar erro?
    end

    -- Fecha o modal usando a nova função helper
    self:_closeRecruitmentModal()
end

--- Atualiza o estado da tela (ex: hover de botões).
---@param dt number Delta time.
---@param mx number Posição X do mouse.
---@param my number Posição Y do mouse.
---@param allowHover boolean Se o hover de elementos nesta tela é permitido.
function GuildScreen:update(dt, mx, my, allowHover)
    if self.isActiveFrame then
        self.isActiveFrame = false
    end

    if self.isRecruiting then
        -- Atualiza colunas do modal
        for _, stack in pairs(self.recruitModalColumns) do
            stack:update(dt, mx, my, allowHover)
        end
        -- Atualiza botão Cancelar do modal
        if self.recruitCancelButton then
            self.recruitCancelButton:update(dt, mx, my, allowHover)
        end
    else
        -- Atualiza botão Recrutar principal
        if self.recruitButton then
            self.recruitButton:update(dt, mx, my, allowHover)
            self.recruitButton.isEnabled = true -- Garante que está habilitado fora do modal
        end
    end
end

--- Processa cliques do mouse dentro da área da tela da Guilda.
---@param clickX number Posição X do clique.
---@param clickY number Posição Y do clique.
---@param button number Índice do botão do mouse.
---@return boolean consumed Se o clique foi consumido por esta tela.
function GuildScreen:handleMousePress(clickX, clickY, button)
    if self.isActiveFrame then return true end

    if button == 1 then
        if self.isRecruiting then
            -- 1. Verifica clique no botão Cancelar
            if self.recruitCancelButton then
                local consumed = self.recruitCancelButton:handleMousePress(clickX, clickY, button)
                if consumed then
                    print("[GuildScreen] Modal Cancel button consumed mouse press.")
                    return true
                end
            end
            -- 2. Verifica clique nas colunas/botões dos candidatos
            for i, stack in pairs(self.recruitModalColumns) do
                local consumed = stack:handleMousePress(clickX, clickY, button)
                if consumed then
                    print(string.format("[GuildScreen] Modal column %d consumed mouse press.", i))
                    return true
                end
            end
            -- 3. Clicou na área do modal, mas fora de elementos interativos -> Consome
            print("[GuildScreen] Click inside modal area (missed elements). Consuming.")
            return true
        else
            -- Lógica fora do modal (botão recrutar, lista de caçadores) - Código existente
            if self.recruitButton then
                local consumed = self.recruitButton:handleMousePress(clickX, clickY, button)
                if consumed then return true end
            end
            for hunterId, rect in pairs(self.hunterSlotRects) do
                if clickX >= rect.x and clickX < rect.x + rect.w and
                    clickY >= rect.y and clickY < rect.y + rect.h then
                    self.selectedHunterId = hunterId
                    print(string.format("[GuildScreen] Hunter selected: %s", hunterId))
                    return true
                end
            end
        end
    end
    return false
end

--- Processa o soltar do mouse.
---@param clickX number Posição X do clique.
---@param clickY number Posição Y do clique.
---@param button number Índice do botão do mouse.
---@return boolean consumed Se o evento foi consumido.
function GuildScreen:handleMouseRelease(clickX, clickY, button)
    if button == 1 then
        if self.isRecruiting then
            -- 1. Verifica release no botão Cancelar
            if self.recruitCancelButton then
                local consumed = self.recruitCancelButton:handleMouseRelease(clickX, clickY, button)
                if consumed then
                    print("[GuildScreen] Modal Cancel button consumed mouse release.")
                    return true
                end
            end
            -- 2. Verifica release nas colunas/botões dos candidatos
            for i, stack in pairs(self.recruitModalColumns) do
                local consumed = stack:handleMouseRelease(clickX, clickY, button)
                if consumed then
                    print(string.format("[GuildScreen] Modal column %d consumed mouse release."), i)
                    return true
                end
            end
            -- 3. Soltou na área do modal, mas fora de elementos -> Não consome (permitir drag talvez?)
            -- return true -- Descomentar se quiser consumir mesmo soltando fora
        else
            -- Lógica fora do modal (botão recrutar) - Código existente
            if self.recruitButton then
                local consumed = self.recruitButton:handleMouseRelease(clickX, clickY, button)
                if consumed then return true end
            end
        end
    end
    return false
end

--- Processa o scroll do mouse.
---@param dx number Scroll horizontal (não usado geralmente).
---@param dy number Scroll vertical (+1 para cima, -1 para baixo).
function GuildScreen:handleMouseScroll(dx, dy)
    -- TODO: Implementar scroll da lista de caçadores
    if dy ~= 0 then
        print(string.format("[GuildScreen] Scroll dy: %d", dy))
        -- self.hunterListScrollY = self.hunterListScrollY + dy * 20 -- Exemplo de ajuste
        -- Limitar scrollY para não sair dos limites da lista
    end
end

return GuildScreen
