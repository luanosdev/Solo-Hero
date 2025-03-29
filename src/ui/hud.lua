--[[
    HUD (Heads Up Display)
    Handles all UI elements and their rendering
]]

local HUD = {}

--[[
    Draw the HUD elements
    @param player Player entity to get auto-attack status
]]
function HUD:draw(player)
    -- Draw controls and status
    local startX = 10
    local startY = 10
    local lineHeight = 20
    local padding = 10
    
    -- Draw background
    local bgWidth = 200
    local bgHeight = lineHeight * 9 + padding * 2
    love.graphics.setColor(0, 0, 0, 0.7)  -- Preto semi-transparente
    love.graphics.rectangle("fill", 
        startX - padding,  -- X
        startY - padding,  -- Y
        bgWidth,  -- Width
        bgHeight  -- Height
    )
    
    -- Movement controls
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("Movement:", startX, startY, 0, 1)
    love.graphics.print("WASD - Move", startX, startY + lineHeight, 0, 1)
    
    -- Combat controls
    love.graphics.print("Combat:", startX, startY + lineHeight * 2, 0, 1)
    love.graphics.print("Left Click - Attack", startX, startY + lineHeight * 3, 0, 1)
    
    -- Auto-attack status
    local autoAttackText = "X - Auto Attack: OFF"
    if player.autoAttack then
        love.graphics.setColor(0, 1, 0, 0.8)  -- Green when active
        autoAttackText = "X - Auto Attack: ON"
    else
        love.graphics.setColor(1, 0, 0, 0.8)  -- Red when inactive
    end
    love.graphics.print(autoAttackText, startX, startY + lineHeight * 4, 0, 1)
    
    -- Test controls
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("Test Controls:", startX, startY + lineHeight * 5, 0, 1)
    love.graphics.print("H - Heal 20 HP", startX, startY + lineHeight * 6, 0, 1)
    love.graphics.print("Q - Increase Max Health", startX, startY + lineHeight * 7, 0, 1)
    love.graphics.print("G - Take 30 Damage", startX, startY + lineHeight * 8, 0, 1)
    love.graphics.print("V - Toggle Ability Visual", startX, startY + lineHeight * 9, 0, 1)
    love.graphics.print("X - Toggle Auto Attack", startX, startY + lineHeight * 10, 0, 1)
end

return HUD