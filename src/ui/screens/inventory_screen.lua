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
    local hunterManager = ManagerRegistry:get("hunterManager") -- <<<< REINTRODUZIDO
    local archetypeManager = ManagerRegistry:get("archetypeManager")
    local loadoutManager = ManagerRegistry:get("loadoutManager")
    local itemDataManager = ManagerRegistry:get("itemDataManager")

    -- MODIFICADO: Reintroduz hunterManager na checagem
    if not playerManager or not hunterManager or not archetypeManager or not loadoutManager or not itemDataManager then
        -- Desenha uma mensagem de erro se algum manager essencial faltar
        local screenW, screenH = love.graphics.getDimensions()
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: Managers essenciais não encontrados!", 0, screenH / 2, screenW, "center")
        love.graphics.setColor(colors.white)
        return
    end

    local screenW, screenH = love.graphics.getDimensions()

    -- Fundo semi-transparente para escurecer o jogo
    love.graphics.setColor(0, 0, 0, 0.8) -- Preto com 80% de opacidade
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    love.graphics.setColor(colors.white) -- Reset color

    -- Divide a tela em 3 colunas iguais
    local colW = screenW / 3
    local colH = screenH -- Usa a altura total da tela
    local colY = 0       -- Começa no topo

    local statsX = 0
    local equipX = colW
    local loadoutX = colW * 2

    -- Adiciona um pequeno padding interno para as colunas (opcional)
    local padding = 10
    local innerColW = colW - padding * 2
    local innerColXOffset = padding
    local innerColY = colY + padding
    local innerColH = colH - padding * 2

    -- Obtém os stats finais ATUAIS do PlayerManager
    local currentFinalStats = playerManager:getCurrentFinalStats()
    -- Obtém os IDs dos arquétipos do HunterManager
    local currentHunterId = playerManager:getCurrentHunterId() -- Pega o ID primeiro
    local hunterArchetypeIds = nil
    if currentHunterId then
        hunterArchetypeIds = hunterManager:getArchetypeIds(currentHunterId)
    end

    -- <<<< CRIA TABELA DE CONFIGURAÇÃO >>>>
    local columnConfig = {
        currentHp = playerManager.state and playerManager.state.currentHealth, -- Passa dados de gameplay
        level = playerManager.state and playerManager.state.level,
        currentXp = playerManager.state and playerManager.state.experience,
        xpToNextLevel = playerManager.state and playerManager.state.experienceToNextLevel,
        finalStats = currentFinalStats,          -- Passa stats finais de gameplay
        archetypeIds = hunterArchetypeIds or {}, -- Passa IDs de arquétipo
        archetypeManager = archetypeManager,
        mouseX = InventoryScreen.mouseX or 0,
        mouseY = InventoryScreen.mouseY or 0
    }

    -- Desenha as 3 colunas usando os novos módulos
    HunterStatsColumn.draw(
        statsX + innerColXOffset, innerColY, innerColW, innerColH,
        columnConfig -- <<<< Passa a tabela de configuração
    )

    -- Guarda as áreas dos slots retornadas pela coluna de equipamento
    InventoryScreen.equipmentSlotAreas = HunterEquipmentColumn.draw(
        equipX + innerColXOffset, innerColY, innerColW, innerColH,
        playerManager,                     -- Passa o PlayerManager
        playerManager:getCurrentHunterId() -- Passa o ID do Hunter atual
    )

    -- Guarda a área da grade retornada pela coluna de loadout
    InventoryScreen.loadoutGridArea = HunterLoadoutColumn.draw(
        loadoutX + innerColXOffset, innerColY, innerColW, innerColH,
        loadoutManager, -- Passa o LoadoutManager
        itemDataManager -- Passa o ItemDataManager
    )

    -- Linhas divisórias entre as colunas (opcional)
    love.graphics.setColor(colors.border_dark)
    love.graphics.setLineWidth(2)
    love.graphics.line(colW, 0, colW, screenH)
    love.graphics.line(colW * 2, 0, colW * 2, screenH)
    love.graphics.setLineWidth(1)        -- Reset line width
    love.graphics.setColor(colors.white) -- Reset color
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
