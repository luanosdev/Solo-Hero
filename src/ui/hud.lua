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

-- Função auxiliar para desenhar status do player com estilo Solo Leveling
local function drawPlayerStatus(x, y, label, value, color)
    love.graphics.setFont(fonts.hud)
    
    local labelWidth = fonts.hud:getWidth(label)
    local valueWidth = fonts.hud:getWidth(value)
    local totalWidth = labelWidth + valueWidth + 10
    local height = fonts.hud:getHeight() + 8
    
    -- Fundo do status com efeito gradiente
    love.graphics.setColor(colors.window_bg[1], colors.window_bg[2], colors.window_bg[3], 0.7)
    love.graphics.rectangle("fill", x, y, totalWidth, height, 2, 2)
    
    -- Borda com efeito de brilho
    love.graphics.setColor(colors.window_border)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, totalWidth, height, 2, 2)
    
    -- Desenha o label com efeito de brilho
    love.graphics.setColor(colors.text_label)
    love.graphics.print(label, x + 5, y + 4)
    
    -- Desenha o valor com efeito de brilho
    love.graphics.setColor(color or colors.text_value)
    love.graphics.print(value, x + labelWidth + 10, y + 4)
    
    -- Reset font após desenhar status
    love.graphics.setFont(fonts.main)
end

--[[
    Draw the HUD elements
]]
function HUD:draw()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Desenha a barra de vida do boss
    BossHealthBar:draw()

    -- Barra de XP com estilo Solo Leveling
    local experienceForNextLevel = PlayerManager.state.experienceToNextLevel - (PlayerManager.state.level > 1 and PlayerManager.state.experienceToNextLevel / (1 + PlayerManager.state.experienceMultiplier) or 0)
    local currentExperience = PlayerManager.state.experience - (PlayerManager.state.level > 1 and PlayerManager.state.experienceToNextLevel / (1 + PlayerManager.state.experienceMultiplier) or 0)
    local barW = screenW * 0.4
    local barH = 20
    local barX = (screenW - barW) / 2
    local barY = 20
    
    -- Desenha a barra de XP com o novo estilo
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
        showText = true,
        textColor = colors.text_main,
        showShadow = true,
        glow = true,
        glowColor = colors.xp_fill
    })
    
    -- Nível do Player com estilo Solo Leveling
    love.graphics.setFont(fonts.hud)
    local levelText = string.format("Nível %d", PlayerManager.state.level or 1)
    local levelWidth = fonts.hud:getWidth(levelText)
    local levelX = barX + (barW - levelWidth) / 2
    local levelY = barY + barH + 5
    
    -- Fundo do nível
    love.graphics.setColor(colors.window_bg[1], colors.window_bg[2], colors.window_bg[3], 0.7)
    love.graphics.rectangle("fill", levelX - 10, levelY, levelWidth + 20, fonts.hud:getHeight() + 8, 2, 2)
    
    -- Borda com efeito de brilho
    love.graphics.setColor(colors.window_border)
    love.graphics.rectangle("line", levelX - 10, levelY, levelWidth + 20, fonts.hud:getHeight() + 8, 2, 2)
    
    -- Texto do nível com efeito de brilho
    love.graphics.setColor(colors.text_highlight)
    love.graphics.print(levelText, levelX, levelY + 4)
    
    -- Reset font após nível
    love.graphics.setFont(fonts.main)

    -- Informações do Player com novo estilo
    local textX = barX + barW + 20
    local textY = barY
    local spacing = 35

    -- Desenha as informações com o novo estilo
    drawPlayerStatus(textX, textY, "Tempo:", formatTime(PlayerManager.gameTime or 0), colors.text_highlight)
    drawPlayerStatus(textX + 150, textY, "Kills:", tostring(PlayerManager.kills or 0), colors.text_highlight)
    drawPlayerStatus(textX + 300, textY, "Ouro:", tostring(PlayerManager.gold or 0), colors.text_gold)

    -- Status de Auto-Ataque e Auto-Aim com novo estilo
    local autoX = screenW - 250
    local autoY = screenH - 100
    local autoWindowW = 230
    local autoWindowH = 100

    -- Desenha a janela de controles com o novo estilo
    elements.drawWindowFrame(autoX - 10, autoY - 10, autoWindowW, autoWindowH, "Controles")

    -- Auto-Ataque
    love.graphics.setFont(fonts.hud)
    local autoAttackText = "[X] Auto-Ataque: " .. (PlayerManager.autoAttackEnabled and "ON" or "OFF")
    love.graphics.setColor(PlayerManager.autoAttackEnabled and colors.text_highlight or colors.damage_player)
    love.graphics.print(autoAttackText, autoX, autoY + 15)


    -- Auto-Aim
    local autoAimText = "[Z] Auto-Aim: " .. (PlayerManager.autoAimEnabled and "ON" or "OFF")
    love.graphics.setColor(PlayerManager.autoAimEnabled and colors.text_highlight or colors.damage_player)
    love.graphics.print(autoAimText, autoX, autoY + 45)


    -- Visualização da habilidade
    local previewEnabled = PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.attackInstance and PlayerManager.equippedWeapon.attackInstance:getPreview()
    local abilityText = "[V] Previa da habilidade: " .. (previewEnabled and "ON" or "OFF")
    love.graphics.setColor(previewEnabled and colors.text_highlight or colors.damage_player)
    love.graphics.print(abilityText, autoX, autoY + 75)

    
    -- Reset font no final do HUD
    love.graphics.setFont(fonts.main)

    --[[
    -- Janela de teste do drawModernWindow
    local testWindowX = 50
    local testWindowY = 50
    local testWindowW = 300
    local testWindowH = 200

    -- Exemplo 1: Janela padrão com título centralizado
    elements.drawModernWindow(testWindowX, testWindowY, testWindowW, testWindowH, {
        title = "Teste Moderno",
        titleAlign = "center",
        glow = true
    })

    -- Exemplo 2: Janela com cores personalizadas
    elements.drawModernWindow(testWindowX + testWindowW + 20, testWindowY, testWindowW, testWindowH, {
        title = "Cores Personalizadas",
        titleAlign = "center",
        borderColor = {0.3, 0.6, 1.0, 1.0}, -- Azul Solo Leveling
        bgColor = {0.1, 0.1, 0.15, 0.9}, -- Preto azulado escuro
        glowColor = {0.3, 0.6, 1.0, 1.0}, -- Azul Solo Leveling
        cornerSize = 25
    })

    -- Exemplo 3: Janela sem título e sem brilho
    elements.drawModernWindow(testWindowX, testWindowY + testWindowH + 20, testWindowW, testWindowH, {
        glow = false,
        cornerSize = 15
    })
    ]]

end

return HUD