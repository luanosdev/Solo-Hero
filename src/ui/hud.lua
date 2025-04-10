--[[
    HUD (Heads Up Display)
    Handles all UI elements and their rendering
]]

local HUD = {}
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
local BossHealthBar = require("src.ui.boss_health_bar")

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

    -- Desenha a barra de vida do boss se houver um boss ativo
    BossHealthBar:draw()

    -- Barra de XP (Centralizada)
    local xpPercent = (player.experience or 0) / (player.experienceToNextLevel or 100)
    local barW = screenW * 0.4
    local barH = 18
    local barX = (screenW - barW) / 2 -- Centraliza horizontalmente
    local barY = 20 -- Posição fixa no topo
    
    elements.drawResourceBar(
        barX,
        barY,
        barW,
        barH,
        player.experience or 0,
        player.experienceToNextLevel or 100,
        colors.xp_fill,
        colors.bar_bg,
        colors.bar_border,
        true,
        colors.text_main,
        "%.0f/%.0f"
    )

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

    -- Barra de HP
    local hudBarW = 300
    local hudBarH = 20
    local hudBarX = (screenW - hudBarW) / 2
    local hudBarY_hp = screenH - 100
    
    elements.drawResourceBar(
        hudBarX,
        hudBarY_hp,
        hudBarW,
        hudBarH,
        player.state.currentHealth or 0,
        player.state:getTotalHealth() or 100,
        colors.hp_fill,
        colors.bar_bg,
        colors.bar_border,
        true,
        colors.text_main,
        "%.0f/%.0f"
    )

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
    drawPlayerStatus(statusX, statusY, "Ataque:", string.format("%.1f", player.state:getTotalDamage() or 0), colors.text_highlight)
    statusY = statusY + statusSpacing

    -- Defesa
    drawPlayerStatus(statusX, statusY, "Defesa:", string.format("%.1f", player.state:getTotalDefense() or 0), colors.text_highlight)
    statusY = statusY + statusSpacing

    -- Velocidade
    drawPlayerStatus(statusX, statusY, "Velocidade:", string.format("%.1f", player.state:getTotalSpeed() or 0), colors.text_highlight)
    statusY = statusY + statusSpacing

    -- Taxa de Crítico
    if player.state:getTotalCriticalChance() then
        drawPlayerStatus(statusX, statusY, "Chance de Crítico:", string.format("%.1f%%", player.state:getTotalCriticalChance() * 100), colors.text_highlight)
        statusY = statusY + statusSpacing
    end

    -- Dano Crítico
    if player.state:getTotalCriticalMultiplier() then
        drawPlayerStatus(statusX, statusY, "Dano Crítico:", string.format("%.1fx", player.state:getTotalCriticalMultiplier()), colors.text_highlight)
    end

    -- Status de Auto-Ataque e Auto-Aim
    local autoX = screenW - 250
    local autoY = screenH - 100  -- Movido um pouco mais para baixo
    local autoSpacing = 25
    local autoWindowW = 230
    local autoWindowH = 100  -- Aumentado de 85 para 100

    -- Fundo da janela de Auto-Ataque/Auto-Aim
    love.graphics.setColor(colors.window_bg[1], colors.window_bg[2], colors.window_bg[3], 0.8)
    love.graphics.rectangle("fill", autoX - 10, autoY - 10, autoWindowW, autoWindowH, 5, 5)
    love.graphics.setColor(colors.window_border)
    love.graphics.rectangle("line", autoX - 10, autoY - 10, autoWindowW, autoWindowH, 5, 5)

    -- Título da janela
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("Controles", autoX - 10, autoY - 5, autoWindowW, "center")

    -- Auto-Ataque
    local autoAttackText = "[X] Auto-Ataque: " .. (player.autoAttackEnabled and "ON" or "OFF")
    love.graphics.setColor(player.autoAttackEnabled and colors.heal or colors.damage_player)
    love.graphics.printf(autoAttackText, autoX, autoY + 15, autoWindowW - 20, "left")

    -- Auto-Aim
    local autoAimText = "[Z] Auto-Aim: " .. (player.autoAimEnabled and "ON" or "OFF")
    love.graphics.setColor(player.autoAimEnabled and colors.heal or colors.damage_player)
    love.graphics.printf(autoAimText, autoX, autoY + 15 + autoSpacing, autoWindowW - 20, "left")

    -- Visualização da habilidade
    local abilityText = "[V] Previa da habilidade: " .. (player:getAbilityVisual() and "ON" or "OFF")
    love.graphics.setColor(player:getAbilityVisual() and colors.heal or colors.damage_player)
    love.graphics.printf(abilityText, autoX, autoY + 15 + autoSpacing * 2, autoWindowW - 20, "left")
end

return HUD