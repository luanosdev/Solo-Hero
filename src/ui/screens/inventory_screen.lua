-- src/ui/inventory_screen.lua
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local ManagerRegistry = require("src.managers.manager_registry") -- Adicionado

-- Carrega as NOVAS colunas
local HunterStatsColumn = require("src.ui.components.HunterStatsColumn")
local HunterEquipmentColumn = require("src.ui.components.HunterEquipmentColumn")
local HunterLoadoutColumn = require("src.ui.components.HunterLoadoutColumn") -- Renomeado de Inventory para Loadout

local InventoryScreen = {}
InventoryScreen.isVisible = false

-- Função para obter o shader (mantida, mas o shader não é usado atualmente)
function InventoryScreen.setGlowShader(shader)
    -- glowShader = shader -- Shader não é usado neste novo layout, remover ou adaptar se necessário
end

-- Função para alternar a visibilidade (mantida)
function InventoryScreen.toggle()
    InventoryScreen.isVisible = not InventoryScreen.isVisible
    -- A lógica de pausa/retomada é gerenciada no main.lua ou onde for chamado
    return InventoryScreen.isVisible
end

function InventoryScreen.update(dt, mx, my) -- Adiciona mx, my para passar para tooltips
    if not InventoryScreen.isVisible then return end
    -- Lógica de atualização da UI pode ser adicionada aqui, se necessário
    InventoryScreen.mouseX = mx
    InventoryScreen.mouseY = my
end

-- Função principal de desenho da tela (MODIFICADA)
function InventoryScreen.draw()
    if not InventoryScreen.isVisible then return end

    -- Obtém Managers do registro
    local playerManager = ManagerRegistry:get("playerManager")
    local hunterManager = ManagerRegistry:get("hunterManager")
    local archetypeManager = ManagerRegistry:get("archetypeManager")
    local loadoutManager = ManagerRegistry:get("loadoutManager")
    local itemDataManager = ManagerRegistry:get("itemDataManager")

    if not playerManager or not hunterManager or not archetypeManager or not loadoutManager or not itemDataManager then
        local screenW, screenH = love.graphics.getDimensions()
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: Managers essenciais não encontrados!", 0, screenH / 2, screenW, "center")
        love.graphics.setColor(colors.white)
        return
    end

    local screenW, screenH = love.graphics.getDimensions()

    -- Fundo semi-transparente para escurecer o jogo
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    love.graphics.setColor(colors.white)

    -- Divide a tela em 3 colunas iguais
    local colW = screenW / 3
    local colH = screenH
    local colY = 0

    local statsX = 0
    local equipX = colW
    local loadoutX = colW * 2

    -- Adiciona um pequeno padding interno
    local padding = 10
    local topPadding = 100 -- <<< ADICIONADO: Mesma distância do topo que equipment_screen
    local innerColW = colW - padding * 2
    local innerColXOffset = padding
    local innerColY = topPadding + padding           -- <<< MODIFICADO: Usa topPadding
    local innerColH = screenH - topPadding - padding -- <<< MODIFICADO: Altura disponível considera top e bottom padding

    -- <<< ADICIONADO: Desenho dos Títulos >>>
    local titleFont = fonts.title or love.graphics.getFont()       -- Usa fonte do título ou fallback
    local titleHeight = titleFont:getHeight()
    local titleMarginY = 15                                        -- Espaço entre título e conteúdo
    local titleY = innerColY                                       -- Coloca o título onde o conteúdo começaria
    local contentStartY = titleY + titleHeight + titleMarginY      -- Conteúdo começa abaixo do título + margem
    local contentInnerH = innerColH - (titleHeight + titleMarginY) -- Altura restante para o conteúdo

    love.graphics.setFont(titleFont)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("ATRIBUTOS", statsX + innerColXOffset, titleY, innerColW, "center")
    love.graphics.printf("EQUIPAMENTO", equipX + innerColXOffset, titleY, innerColW, "center")
    love.graphics.printf("MOCHILA", loadoutX + innerColXOffset, titleY, innerColW, "center")
    love.graphics.setColor(colors.white)
    love.graphics.setFont(fonts.main or titleFont) -- Reseta para fonte principal
    -- <<< FIM: Desenho dos Títulos >>>

    -- <<< ADICIONADO: Cálculo para centralização vertical do conteúdo >>>
    local contentMaxHeightFactor = 0.9 -- Fator da altura da coluna que o conteúdo pode ocupar (ajuste conforme necessário)
    local centeredContentH = contentInnerH * contentMaxHeightFactor
    local contentOffsetY = (contentInnerH - centeredContentH) / 2
    local centeredContentStartY = contentStartY + contentOffsetY
    -- <<< FIM: Cálculo para centralização vertical >>>

    -- Obtém dados necessários
    local currentFinalStats = playerManager:getCurrentFinalStats()
    local currentHunterId = playerManager:getCurrentHunterId()
    local hunterArchetypeIds = nil
    if currentHunterId then
        hunterArchetypeIds = hunterManager:getArchetypeIds(currentHunterId)
    end

    -- <<<< CRIA TABELA DE CONFIGURAÇÃO PARA STATS COLUMN >>>>
    local statsColumnConfig = {
        -- Dados de Gameplay (usando 'and' para evitar erro se playerManager.state for nil)
        currentHp = playerManager.state and playerManager.state.currentHealth,
        level = playerManager.state and playerManager.state.level,
        currentXp = playerManager.state and playerManager.state.experience,
        xpToNextLevel = playerManager.state and playerManager.state.experienceToNextLevel,
        -- Dados Comuns
        finalStats = currentFinalStats,
        archetypeIds = hunterArchetypeIds or {},
        archetypeManager = archetypeManager,
        mouseX = InventoryScreen.mouseX or 0,
        mouseY = InventoryScreen.mouseY or 0
    }

    -- Desenha Coluna de Stats -- MODIFICADO: Usa Y e H centralizados
    HunterStatsColumn.draw(
        statsX + innerColXOffset, centeredContentStartY, innerColW, centeredContentH,
        statsColumnConfig
    )

    -- Desenha e guarda área da Coluna de Equipamento -- MODIFICADO: Usa Y e H centralizados
    InventoryScreen.equipmentSlotAreas = HunterEquipmentColumn.draw(
        equipX + innerColXOffset, centeredContentStartY, innerColW, centeredContentH,
        hunterManager,
        currentHunterId
    )

    -- Desenha e guarda área da Coluna de Loadout -- MODIFICADO: Usa Y e H centralizados
    InventoryScreen.loadoutGridArea = HunterLoadoutColumn.draw(
        loadoutX + innerColXOffset, centeredContentStartY, innerColW, centeredContentH,
        loadoutManager,
        itemDataManager
    )
end

-- Mantém as funções de input, mas a lógica interna precisará ser adaptada
-- para interagir com as áreas retornadas pelas colunas (equipmentSlotAreas, loadoutGridArea)

function InventoryScreen.keypressed(key)
    if not InventoryScreen.isVisible then return false end
    if key == "escape" or key == "tab" then
        InventoryScreen.toggle()
        return true
    end
    -- TODO: Adicionar navegação por teclado entre colunas/slots?
    return true -- Consome outras teclas
end

function InventoryScreen.mousepressed(x, y, button)
    if not InventoryScreen.isVisible then return false end

    -- Verifica cliques nos slots de equipamento (usando InventoryScreen.equipmentSlotAreas)
    -- Verifica cliques na grade do loadout (usando InventoryScreen.loadoutGridArea)
    -- Verifica interações com a coluna de stats (se houver)
    -- TODO: Implementar lógica de drag-and-drop entre equipamento e loadout

    print(string.format("Inventory click @ %.0f, %.0f, button %d", x, y, button)) -- DEBUG

    -- Exemplo: Checar clique em um slot de equipamento
    if InventoryScreen.equipmentSlotAreas then
        for slotType, area in pairs(InventoryScreen.equipmentSlotAreas) do
            if x >= area.x and x <= area.x + area.w and y >= area.y and y <= area.y + area.h then
                print("Clicked on equipment slot:", slotType)
                -- Iniciar drag, mostrar tooltip, etc.
                return true -- Consome o clique
            end
        end
    end

    -- Exemplo: Checar clique na área do loadout (precisaria de mais detalhes do ItemGridUI)
    if InventoryScreen.loadoutGridArea then
        local area = InventoryScreen.loadoutGridArea
        if x >= area.x and x <= area.x + area.w and y >= area.y and y <= area.y + area.h then
            print("Clicked within loadout area.")
            -- Determinar qual slot foi clicado baseado em x, y e layout da grade
            -- Iniciar drag, mostrar tooltip, etc.
            return true -- Consome o clique
        end
    end

    return true -- Consome o clique por padrão se estiver dentro da tela
end

return InventoryScreen
