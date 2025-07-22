--------------------------------------------------------------------------------
--- ActionBindings
--- 
--------------------------------------------------------------------------------
local ActionTypes = require("src.types.action_types")

---@alias ActionBindingsType table<string, love.KeyConstant[]|string[]>

---@class ActionBindings
---@description Define o mapeamento padrão de teclas físicas para ações lógicas do jogo.
--- Este arquivo serve como a configuração "de fábrica". As configurações
--- personalizadas do jogador poderão sobrescrever este mapeamento.
---@field bindings ActionBindingsType
local bindings = {
    -- Ações de Movimento
    [ActionTypes.MOVE_UP] = { "w", "up" },
    [ActionTypes.MOVE_DOWN] = { "s", "down" },
    [ActionTypes.MOVE_LEFT] = { "a", "left" },
    [ActionTypes.MOVE_RIGHT] = { "d", "right" },

    -- Ações de Botão
    [ActionTypes.CONFIRM] = { "return", "kpenter" },
    [ActionTypes.CANCEL] = { "escape" },
    [ActionTypes.USE_POTION] = { "q" },
    [ActionTypes.OPEN_INVENTORY] = { "tab" },
    [ActionTypes.DASH] = { "space" },
    [ActionTypes.TOGGLE_AUTO_ATTACK] = { "x" },
    [ActionTypes.TOGGLE_AUTO_AIM] = { "z" },
    [ActionTypes.TOGGLE_AIM_PREVIEW] = { "c" },
}

return bindings
