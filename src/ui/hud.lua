--[[
    HUD (Heads Up Display)
    Handles all UI elements and their rendering
]]

local HUD = {}
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")

-- Função auxiliar para formatar tempo
local function formatTime(s)
    local m = math.floor(s / 60)
    local sec = math.floor(s % 60)
    return string.format("%02d:%02d", m, sec)
end

-- Função auxiliar para desenhar status do player
local function drawPlayerStatus(x, y, label, value, color)
    -- Define a fonte
    love.graphics.setFont(fonts.hud)
    
    -- Desenha o fundo do texto
    local labelWidth = fonts.hud:getWidth(label)
    local valueWidth = fonts.hud:getWidth(value)
    local totalWidth = labelWidth + valueWidth + 5
    local height = fonts.hud:getHeight()
    
    -- Desenha o texto do label
    love.graphics.setColor(colors.text_label)
    love.graphics.print(label, x, y)
    
    -- Desenha o texto do valor
    love.graphics.setColor(color or colors.text_value)
    love.graphics.print(value, x + labelWidth + 5, y)
end

--[[
    Draw the HUD elements
    @param player Player entity to get status information
]]
function HUD:draw(player)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Barra de XP (Centralizada)
    local xpPercent = (player.experience or 0) / (player.experienceToNextLevel or 100)
    local barW = screenW * 0.4
    local barH = 18
    local barX = (screenW - barW) / 2 -- Centraliza horizontalmente
    local barY = 20 -- Posição fixa no topo

    elements.drawResourceBar(barX, barY, barW, barH, xpPercent, colors.bar_bg, colors.xp_fill)
    love.graphics.setFont(fonts.main_small)
    love.graphics.setColor(colors.white)
    love.graphics.printf(string.format("XP: %d / %d", player.experience or 0, player.experienceToNextLevel or 100),
                        barX, barY + barH/2 - fonts.main_small:getHeight()/2, barW, "center")

    -- Nível do Player (abaixo da barra de XP)
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_gold)
    local levelText = string.format("Nível %d", player.level or 1)
    love.graphics.printf(levelText, barX, barY + barH + 5, barW, "center")

    -- Informações do Player (Tempo, Kills, Ouro)
    love.graphics.setFont(fonts.hud)
    local textX = barX + barW + 20
    local textY = barY + barH/2 - fonts.hud:getHeight()/2

    -- Desenha o fundo das informações
    local totalWidth = fonts.hud:getWidth("Tempo: 00:00") + fonts.hud:getWidth("Kills: XXXX") + fonts.hud:getWidth("Ouro: XXXX") + 60
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", textX - 10, textY - 5, totalWidth, fonts.hud:getHeight() + 10, 3, 3)

    drawPlayerStatus(textX, textY, "Tempo:", formatTime(player.gameTime or 0), colors.text_highlight)
    textX = textX + fonts.hud:getWidth("Tempo: 00:00") + 30

    drawPlayerStatus(textX, textY, "Kills:", tostring(player.kills or 0), colors.text_highlight)
    textX = textX + fonts.hud:getWidth("Kills: XXXX") + 30

    drawPlayerStatus(textX, textY, "Ouro:", tostring(player.gold or 0), colors.text_gold)

    -- Barras de HP e MP (Centralizadas)
    local hudBarW = 300
    local hudBarH = 20
    local hudBarX = (screenW - hudBarW) / 2
    local hudBarY_hp = screenH - 100

    -- Barra de HP
    local hpPercent = (player.state.currentHealth or 0) / (player.state.maxHealth or 100)
    
    -- Desenha a barra de HP
    elements.drawResourceBar(hudBarX, hudBarY_hp, hudBarW, hudBarH, hpPercent, colors.bar_bg, colors.hp_fill, "HP", 
        string.format("%d/%d", player.state.currentHealth or 0, player.state.maxHealth or 100))

    -- Status do Player (Atributos) - Agora em uma janela separada
    local statusWindowW = 250
    local statusWindowH = 200
    local statusWindowX = 20
    local statusWindowY = barY + barH + 40 -- Ajustado para dar espaço ao nível

    -- Fundo da janela de status
    love.graphics.setColor(colors.window_bg[1], colors.window_bg[2], colors.window_bg[3], 0.8)
    love.graphics.rectangle("fill", statusWindowX, statusWindowY, statusWindowW, statusWindowH, 5, 5)
    love.graphics.setColor(colors.window_border)
    love.graphics.rectangle("line", statusWindowX, statusWindowY, statusWindowW, statusWindowH, 5, 5)

    -- Título da janela de status
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("Atributos", statusWindowX, statusWindowY + 10, statusWindowW, "center")

    -- Atributos
    local statusX = statusWindowX + 20
    local statusY = statusWindowY + 40
    local statusSpacing = 25

    -- Ataque
    drawPlayerStatus(statusX, statusY, "Ataque:", string.format("%.1f", player.damage or 0), colors.text_highlight)
    statusY = statusY + statusSpacing

    -- Defesa
    drawPlayerStatus(statusX, statusY, "Defesa:", string.format("%.1f", player.defense or 0), colors.text_highlight)
    statusY = statusY + statusSpacing

    -- Velocidade
    drawPlayerStatus(statusX, statusY, "Velocidade:", string.format("%.1f", player.baseSpeed or 0), colors.text_highlight)
    statusY = statusY + statusSpacing

    -- Taxa de Crítico
    if player.criticalChance then
        drawPlayerStatus(statusX, statusY, "Crítico:", string.format("%.1f%%", player.criticalChance * 100), colors.text_highlight)
        statusY = statusY + statusSpacing
    end

    -- Dano Crítico
    if player.criticalMultiplier then
        drawPlayerStatus(statusX, statusY, "Dano Crítico:", string.format("%.1fx", player.criticalMultiplier), colors.text_highlight)
    end

    -- Status de Auto-Ataque e Auto-Aim
    local autoX = screenW - 200
    local autoY = screenH - 60
    local autoSpacing = 20

    -- Auto-Ataque
    love.graphics.setFont(fonts.main_small)
    local autoAttackText = "Auto-Ataque: " .. (player.autoAttackEnabled and "ON" or "OFF")
    love.graphics.setColor(player.autoAttackEnabled and colors.heal or colors.damage_player)
    love.graphics.printf(autoAttackText, autoX, autoY, 0, "left")

    -- Auto-Aim
    local autoAimText = "Auto-Aim: " .. (player.autoAimEnabled and "ON" or "OFF")
    love.graphics.setColor(player.autoAimEnabled and colors.heal or colors.damage_player)
    love.graphics.printf(autoAimText, autoX, autoY + autoSpacing, 0, "left")
end

return HUD