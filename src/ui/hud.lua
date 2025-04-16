--[[
    HUD (Heads Up Display)
    Handles all UI elements and their rendering
]]

local HUD = {}
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
local BossHealthBar = require("src.ui.boss_health_bar")
local PlayerManager = require("src.managers.player_manager")

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
]]
function HUD:draw()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Desenha a barra de vida do boss se houver um boss ativo
    BossHealthBar:draw()

    -- Barra de XP (Centralizada)
    -- Calcula a experiência necessária apenas para o próximo nível
    local experienceForNextLevel = PlayerManager.experienceToNextLevel - (PlayerManager.level > 1 and PlayerManager.experienceToNextLevel / (1 + PlayerManager.experienceMultiplier) or 0)
    local currentExperience = PlayerManager.experience - (PlayerManager.level > 1 and PlayerManager.experienceToNextLevel / (1 + PlayerManager.experienceMultiplier) or 0)
    local xpPercent = currentExperience / experienceForNextLevel
    local barW = screenW * 0.4
    local barH = 18
    local barX = (screenW - barW) / 2 -- Centraliza horizontalmente
    local barY = 20 -- Posição fixa no topo
    
    -- Desenha a barra de progresso de XP
    elements.drawResourceBar({
        x = barX,
        y = barY,
        width = barW,
        height = barH,
        current = currentExperience,
        max = experienceForNextLevel,
        color = colors.xp_fill,
        bgColor = colors.bar_bg,
        borderColor = colors.bar_border,
        showText = false,
        showShadow = true,
        shadowColor = {0, 0, 0, 0.5},
        segments = 0,
        glow = true,
        glowColor = {colors.xp_fill[1], colors.xp_fill[2], colors.xp_fill[3], 0.6},
        glowRadius = 4.0
    })
    
    -- Desenha o texto da XP separadamente
    local text = string.format("%.0f/%.0f", PlayerManager.experience, PlayerManager.experienceToNextLevel)
    love.graphics.setFont(fonts.hud)  -- Define explicitamente a fonte
    local textHeight = fonts.hud:getHeight()
    
    -- Desenha a sombra do texto
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.printf(text, barX, barY + (barH - textHeight) / 2 + 1, barW, "center")
    
    -- Desenha o texto principal
    love.graphics.setColor(colors.text_main)
    love.graphics.printf(text, barX, barY + (barH - textHeight) / 2, barW, "center")

    -- Nível do Player (abaixo da barra de XP)
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_gold)
    local levelText = string.format("Nível %d", PlayerManager.level or 1)
    love.graphics.printf(levelText, barX, barY + barH + 5, barW, "center")

    -- Informações do Player (Tempo, Kills, Ouro)
    love.graphics.setFont(fonts.hud)
    local textX = barX + barW + 20
    local textY = barY + barH/2 - fonts.hud:getHeight()/2

    -- Desenha o fundo das informações
    local totalWidth = fonts.hud:getWidth("Tempo: 00:00") + fonts.hud:getWidth("Kills: XXXX") + fonts.hud:getWidth("Ouro: XXXX") + 60
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", textX - 10, textY - 5, totalWidth, fonts.hud:getHeight() + 10, 3, 3)

    drawPlayerStatus(textX, textY, "Tempo:", formatTime(PlayerManager.gameTime or 0), colors.text_highlight)
    textX = textX + fonts.hud:getWidth("Tempo: 00:00") + 30

    drawPlayerStatus(textX, textY, "Kills:", tostring(PlayerManager.kills or 0), colors.text_highlight)
    textX = textX + fonts.hud:getWidth("Kills: XXXX") + 30

    drawPlayerStatus(textX, textY, "Ouro:", tostring(PlayerManager.gold or 0), colors.text_gold)

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
    local autoAttackText = "[X] Auto-Ataque: " .. (PlayerManager.autoAttackEnabled and "ON" or "OFF")
    love.graphics.setColor(PlayerManager.autoAttackEnabled and colors.heal or colors.damage_player)
    love.graphics.printf(autoAttackText, autoX, autoY + 15, autoWindowW - 20, "left")

    -- Auto-Aim
    local autoAimText = "[Z] Auto-Aim: " .. (PlayerManager.autoAimEnabled and "ON" or "OFF")
    love.graphics.setColor(PlayerManager.autoAimEnabled and colors.heal or colors.damage_player)
    love.graphics.printf(autoAimText, autoX, autoY + 15 + autoSpacing, autoWindowW - 20, "left")

    -- Visualização da habilidade
    local abilityText = "[V] Previa da habilidade: " .. (PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.attackInstance and PlayerManager.equippedWeapon.attackInstance:getPreview() and "ON" or "OFF")
    love.graphics.setColor(PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.attackInstance and PlayerManager.equippedWeapon.attackInstance:getPreview() and colors.heal or colors.damage_player)
    love.graphics.printf(abilityText, autoX, autoY + 15 + autoSpacing * 2, autoWindowW - 20, "left")
end

return HUD