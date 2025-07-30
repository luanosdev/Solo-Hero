local fonts = require("src.ui.fonts")

---@class HUDGameplayManager
---@field context GameplaySceneContext
local HUDGameplayManager = {}
HUDGameplayManager.__index = HUDGameplayManager

---@param context GameplaySceneContext
---@return HUDGameplayManager
function HUDGameplayManager:new(context)
    assert(context, "[HUDGameplayManager] missing a GameplaySceneContext")

    local instance = setmetatable({}, HUDGameplayManager)
    instance.context = context

    return instance
end

--- Configura o HUDGameplayManager para o gameplay com base nos dados de um caçador específico.
--- Chamado pela GameplayScene após a inicialização dos managers.
function HUDGameplayManager:init()
end

--- Atualiza todos os elementos da UI gerenciados.
---@param dt number Delta time.
function HUDGameplayManager:update(dt)
end

--- Desenha o painel de debug com informações dos inimigos.
function HUDGameplayManager:_drawEnemyDebugInfo()
    local enemyManager = self.context.registry:getEnemyManager()

    local info = enemyManager:getDebugInfo()
    if not info then return end

    love.graphics.setFont(fonts.main)
    love.graphics.setColor(1, 1, 1)

    local x = 10
    local y = 10
    local lineHeight = fonts.main:getHeight()

    love.graphics.print("--- Enemy Culling Debug ---", x, y)
    y = y + lineHeight
    love.graphics.print(string.format("Total: %d", info.total), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("Active (Full Logic): %d", info.active), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("Slow (Anim Only): %d", info.slow), x, y)
end

--- Desenha todos os elementos da UI gerenciados.
---@param isPaused boolean Se o jogo está pausado.
function HUDGameplayManager:draw(isPaused)
    -- Desenha as informações de debug
    self:_drawEnemyDebugInfo()
end

function HUDGameplayManager:destroy()
    Logger.info("hud_gameplay_manager.destroy", "[HUDGameplayManager:destroy] Destroying...")
end

return HUDGameplayManager
