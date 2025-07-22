--------------------------------------------------------------------------------
--- ActionTypes
--- @description Define um enum centralizado para todas as ações lógicas de input do jogo.
--- Isso previne erros de digitação e serve como uma documentação viva das
--- ações possíveis, permitindo o uso de autocompletar no editor.
--------------------------------------------------------------------------------

---@class ActionTypes
---@field MOVE_UP "move_up"
---@field MOVE_DOWN "move_down"
---@field MOVE_LEFT "move_left"
---@field MOVE_RIGHT "move_right"
---@field CONFIRM "confirm" Ação de confirmar (UI)
---@field CANCEL "cancel" Ação de cancelar/voltar (UI)
---@field USE_POTION "use_potion" Usar poção de cura
---@field OPEN_INVENTORY "open_inventory" Abrir/Fechar inventário
---@field DASH "dash" Ação de esquiva
---@field TOGGLE_AUTO_ATTACK "toggle_auto_attack" Ativar/desativar ataque automático
---@field TOGGLE_AUTO_AIM "toggle_auto_aim" Ativar/desativar mira automática
---@field TOGGLE_AIM_PREVIEW "toggle_aim_preview" Ativar/desativar preview da mira
local ActionTypes = {
    -- Ações de Movimento
    MOVE_UP = "move_up",
    MOVE_DOWN = "move_down",
    MOVE_LEFT = "move_left",
    MOVE_RIGHT = "move_right",

    -- Ações de Botão (eventos discretos)
    CONFIRM = "confirm",
    CANCEL = "cancel",
    USE_POTION = "use_potion",
    OPEN_INVENTORY = "open_inventory",
    DASH = "dash",
    TOGGLE_AUTO_ATTACK = "toggle_auto_attack",
    TOGGLE_AUTO_AIM = "toggle_auto_aim",
    TOGGLE_AIM_PREVIEW = "toggle_aim_preview",
    -- Adicionar futuras ações aqui...
}

return ActionTypes
