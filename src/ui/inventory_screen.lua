-- src/ui/inventory_screen.lua
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local glowShader = nil -- Variável para armazenar o shader, se carregado
local ManagerRegistry = require("src.managers.manager_registry") -- Adicionado
-- local player = require("src.entities.player") -- Assumindo que os dados do jogador virão daqui

-- Carrega as seções refatoradas
local StatsSection = require("src.ui.inventory.sections.stats_section")
local EquipmentSection = require("src.ui.inventory.sections.equipment_section")
local InventoryGridSection = require("src.ui.inventory.sections.inventory_grid_section")

-- Helper para formatar números (MOVIDO PARA ui_elements.lua)
-- local function formatNumber(num) ... end

-- Helper para formatar Chance de Ataque Múltiplo (MOVIDO PARA stats_section.lua)
-- local function formatMultiAttack(value) ... end

local InventoryScreen = {}
InventoryScreen.isVisible = false
InventoryScreen.slotsPerRow = 7 -- Reduzido de 8 para 7
InventoryScreen.slotSize = 58 -- Aumentado de 48 (48 * 1.2 = 57.6 -> 58)
InventoryScreen.slotSpacing = 5
InventoryScreen.equipmentSlotSize = 64 -- Tamanho maior para slots de equipamento
InventoryScreen.runeSlotSize = 32 -- Tamanho menor para runas

-- Função para obter o shader (será chamado pelo main.lua)
function InventoryScreen.setGlowShader(shader)
    glowShader = shader
end

-- Função para alternar a visibilidade e pausar/retomar o jogo
function InventoryScreen.toggle()
    -- print("  [InventoryScreen] toggle START. Current isVisible:", InventoryScreen.isVisible) -- DEBUG Removido
    InventoryScreen.isVisible = not InventoryScreen.isVisible
    -- print("  [InventoryScreen] toggle END. New isVisible:", InventoryScreen.isVisible) -- DEBUG Removido
    -- A lógica real de pausa/retomada será gerenciada no main.lua
    if InventoryScreen.isVisible then
        -- print("Inventário aberto.") -- DEBUG Removido
        -- TODO: Potencialmente buscar dados frescos do jogador aqui, se necessário
    else
        -- print("Inventário fechado.") -- DEBUG Removido
    end
    return InventoryScreen.isVisible -- Retorna o novo estado
end

function InventoryScreen.update(dt)
    if not InventoryScreen.isVisible then return end
    -- Lógica de atualização da UI, se houver (ex: efeitos de hover, animações)
end

-- Função principal de desenho da tela
function InventoryScreen.draw() -- Removido playerManager como argumento
    if not InventoryScreen.isVisible then return end

    -- Obtém PlayerManager do registro
    local playerManager = ManagerRegistry:get("playerManager")

    local screenW, screenH = love.graphics.getDimensions()
    -- Dimensões e posição do painel principal (Aumentado)
    local panelW = math.min(screenW * 0.95, 1400)
    local panelH = math.min(screenH * 0.85, 800)
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2
    -- print("  [InventoryScreen.draw] Calculou Painel e Seções") -- DEBUG Removido

    -- print("  [InventoryScreen.draw] Chamando drawWindowFrame...") -- DEBUG Removido
    elements.drawWindowFrame(panelX, panelY, panelW, panelH, "CHEERFUL JACK")
    -- print("  [InventoryScreen.draw] Retornou de drawWindowFrame") -- DEBUG Removido

    -- Calcula dimensões e posições das seções
    local padding = 20
    local titleHeight = fonts.title:getHeight()
    -- Ajusta Y inicial das seções para caber títulos internos
    local sectionTopY = panelY + titleHeight * 1.5 + padding
    local sectionContentH = panelH - (sectionTopY - panelY) - padding

    -- Larguras das seções (Ajustando para talvez dar mais espaço ao equipamento?)
    local statsW = panelW * 0.25
    local equipmentW = panelW * 0.30 -- Aumentado
    local inventoryW = panelW - statsW - equipmentW - padding * 4 -- O restante

    local statsX = panelX + padding
    local equipmentX = statsX + statsW + padding
    local inventoryX = equipmentX + equipmentW + padding

    -- Chama as funções de desenho das seções refatoradas
    StatsSection.draw(statsX, sectionTopY, statsW, sectionContentH, playerManager)
    EquipmentSection.draw(equipmentX, sectionTopY, equipmentW, sectionContentH) -- Chama a seção movida
    InventoryGridSection.draw(inventoryX, sectionTopY, inventoryW, sectionContentH) -- Chama a seção movida
end

-- Desenha a seção de equipamento (centro)
-- function InventoryScreen.drawEquipment(x, y, w, h) ... end

-- Desenha a seção do inventário (direita)
-- function InventoryScreen.drawInventory(x, y, w, h) ... end

-- Função para processar input quando o inventário está visível
function InventoryScreen.keypressed(key)
    if not InventoryScreen.isVisible then return false end

    -- TODO: Adicionar lógica de navegação/interação dentro do inventário
    if key == "escape" or key == "tab" then -- 'tab' também fecha (a pausa é tratada em main.lua)
        InventoryScreen.toggle()
        return true
    end

    -- print("Inventory handled key:", key) -- DEBUG Removido
    return true -- Consome outras teclas por enquanto
end

-- Função para tratar cliques do mouse quando o inventário está visível
function InventoryScreen.mousepressed(x, y, button)
    if not InventoryScreen.isVisible then return false end

    -- TODO: Lógica de clique nos slots
    -- print("Inventory click detection placeholder @", x, y, button) -- DEBUG Removido

    -- Consome o clique por enquanto para evitar interação com o jogo
    return true
end

return InventoryScreen 