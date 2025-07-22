--------------------------------------------------------------------------------
--- InputService

--------------------------------------------------------------------------------
local ActionTypes = require("src.types.action_types")

---@class InputService
---@description Um serviço global que captura inputs físicos (teclado, mouse, etc.)
--- e os mapeia para ações lógicas do jogo. Ele gerencia diferentes estados de
--- input (pressionado, segurado, solto) para essas ações.
---@field bindings ActionBindings O mapeamento de teclas para ações.
---@field reverseBindings table<love.KeyConstant, string> Mapeamento reverso para busca rápida.
---@field actionsDown table<string, boolean> Ações que estão atualmente ativas (tecla segurada).
---@field actionsPressed table<string, boolean> Ações que foram pressionadas neste frame.
---@field actionsReleased table<string, boolean> Ações que foram soltas neste frame.
local InputService = {}
InputService.__index = InputService

function InputService:new()
    local instance = setmetatable({}, InputService)
    instance.bindings = {}
    instance.reverseBindings = {}
    instance.actionsDown = {}
    instance.actionsPressed = {}
    instance.actionsReleased = {}

    instance:_loadDefaultBindings()
    instance:_buildReverseBindings()

    return instance
end

--- Carrega os mapeamentos de tecla padrão.
function InputService:_loadDefaultBindings()
    self.bindings = require("src.config.action_bindings")
end

--- Constrói um mapa reverso de tecla -> ação para buscas rápidas.
function InputService:_buildReverseBindings()
    self.reverseBindings = {}
    for action, keys in pairs(self.bindings) do
        for _, key in ipairs(keys) do
            self.reverseBindings[key] = action
        end
    end
end

--- Chamado a cada frame no main.lua ANTES de processar os eventos.
function InputService:update(dt)
    -- Limpa os eventos de frame único
    self.actionsPressed = {}
    self.actionsReleased = {}

    -- Atualiza o estado 'down'
    self.actionsDown = {}
    for action, keys in pairs(self.bindings) do
        for _, key in ipairs(keys) do
            if love.keyboard.isDown(key) then
                self.actionsDown[action] = true
                break -- Basta uma tecla para a ação estar ativa
            end
        end
    end
end

--- Manipula o evento love.keypressed
---@param key love.KeyConstant
function InputService:handleKeyPressed(key)
    local action = self.reverseBindings[key]
    if action then
        self.actionsPressed[action] = true
    end
end

--- Manipula o evento love.keyreleased
---@param key love.KeyConstant
function InputService:handleKeyReleased(key)
    local action = self.reverseBindings[key]
    if action then
        self.actionsReleased[action] = true
    end
end

--- Verifica se uma ação de botão foi pressionada NESTE frame.
---@param action string A ação a ser verificada (usando ActionTypes).
---@return boolean
function InputService:wasActionPressed(action)
    return self.actionsPressed[action] or false
end

--- Verifica se uma ação de botão está sendo segurada.
---@param action string A ação a ser verificada (usando ActionTypes).
---@return boolean
function InputService:isActionDown(action)
    return self.actionsDown[action] or false
end

--- Verifica se uma ação de botão foi solta NESTE frame.
---@param action string A ação a ser verificada (usando ActionTypes).
---@return boolean
function InputService:wasActionReleased(action)
    return self.actionsReleased[action] or false
end

--- Retorna um vetor 2D normalizado para o movimento.
---@return Vector2D
function InputService:getMovementVector()
    local vec = { x = 0, y = 0 }

    if self:isActionDown(ActionTypes.MOVE_UP) then vec.y = vec.y - 1 end
    if self:isActionDown(ActionTypes.MOVE_DOWN) then vec.y = vec.y + 1 end
    if self:isActionDown(ActionTypes.MOVE_LEFT) then vec.x = vec.x - 1 end
    if self:isActionDown(ActionTypes.MOVE_RIGHT) then vec.x = vec.x + 1 end

    local length = math.sqrt(vec.x * vec.x + vec.y * vec.y)
    if length > 0 then
        vec.x = vec.x / length
        vec.y = vec.y / length
    end

    return vec
end

return InputService
