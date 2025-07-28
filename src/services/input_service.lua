--------------------------------------------------------------------------------
--- InputService

--------------------------------------------------------------------------------
local ActionTypes = require("src.types.action_types")

---@class InputService
---@description Um serviço global que captura inputs físicos (teclado, mouse, etc.)
--- e os mapeia para ações lógicas do jogo. Ele gerencia diferentes estados de
--- input (pressionado, segurado, solto) para essas ações.
---@field bindings ActionBindings O mapeamento de teclas para ações.
---@field keyboardBindings table<string, love.KeyConstant[]>
---@field mouseBindings table<string, number[]>
---@field reverseKeyboardBindings table<love.KeyConstant, string> Mapeamento reverso para busca rápida.
---@field reverseMouseBindings table<number, string> Mapeamento reverso para busca rápida.
---@field actionsDown table<string, boolean> Ações que estão atualmente ativas (tecla segurada).
---@field actionsPressed table<string, boolean> Ações que foram pressionadas neste frame.
---@field actionsReleased table<string, boolean> Ações que foram soltas neste frame.
local InputService = {}
InputService.__index = InputService

function InputService:new()
    local instance = setmetatable({}, InputService)
    instance.bindings = {}
    instance.keyboardBindings = {}
    instance.mouseBindings = {}
    instance.reverseKeyboardBindings = {}
    instance.reverseMouseBindings = {}
    instance.actionsDown = {}
    instance.actionsPressed = {}
    instance.actionsReleased = {}

    instance:_loadDefaultBindings()
    instance:_buildReverseBindings()

    return instance
end

---@private Carrega os mapeamentos de tecla padrão.
function InputService:_loadDefaultBindings()
    self.bindings = require("src.config.action_bindings")
end

---@private Constrói um mapa reverso de tecla -> ação para buscas rápidas.
function InputService:_buildReverseBindings()
    self.reverseKeyboardBindings = {}
    self.reverseMouseBindings = {}
    for action, keys in pairs(self.bindings) do
        self.keyboardBindings[action] = {}
        self.mouseBindings[action] = {}
        for _, key in ipairs(keys) do
            if type(key) == "string" and key:match("mouse") then
                -- É um botão do mouse, ex: "mouse1"
                -- Adicionado parêntese extra para pegar apenas o primeiro retorno do gsub
                local buttonIndex = tonumber((key:gsub("mouse", "")))
                table.insert(self.mouseBindings[action], buttonIndex)
                self.reverseMouseBindings[buttonIndex] = action
            else
                -- É uma tecla do teclado
                table.insert(self.keyboardBindings[action], key)
                self.reverseKeyboardBindings[key] = action
            end
        end
    end
end

--- Chamado a cada frame no main.lua ANTES de processar os eventos.
function InputService:update(dt)
    -- Limpa os eventos de frame único
    self.actionsPressed = {}
    self.actionsReleased = {}

    -- Atualiza o estado 'down' para o teclado
    self.actionsDown = {}
    for action, keys in pairs(self.keyboardBindings) do
        for _, key in ipairs(keys) do
            if love.keyboard.isDown(key) then
                self.actionsDown[action] = true
                break
            end
        end
    end

    -- Atualiza o estado 'down' para o mouse
    for action, buttons in pairs(self.mouseBindings) do
        for _, button in ipairs(buttons) do
            if love.mouse.isDown(button) then
                self.actionsDown[action] = true
                break
            end
        end
    end
end

---@public Manipula o evento love.keypressed
---@param key love.KeyConstant
function InputService:handleKeyPressed(key)
    local action = self.reverseKeyboardBindings[key]
    if action then
        self.actionsPressed[action] = true
    end
end

---@public Manipula o evento love.keyreleased
---@param key love.KeyConstant
function InputService:handleKeyReleased(key)
    local action = self.reverseKeyboardBindings[key]
    if action then
        self.actionsReleased[action] = true
    end
end

---@public Manipula o evento love.mousepressed
---@param x number
---@param y number
---@param button number
function InputService:handleMousePressed(x, y, button)
    local action = self.reverseMouseBindings[button]
    if action then
        self.actionsPressed[action] = true
    end
end

---@public Manipula o evento love.mousereleased
---@param x number
---@param y number
---@param button number
function InputService:handleMouseReleased(x, y, button)
    local action = self.reverseMouseBindings[button]
    if action then
        self.actionsReleased[action] = true
    end
end

---@public Verifica se uma ação de botão foi pressionada NESTE frame.
---@param action string A ação a ser verificada (usando ActionTypes).
---@return boolean
function InputService:wasActionPressed(action)
    return self.actionsPressed[action] or false
end

---@public Verifica se uma ação de botão está sendo segurada.
---@param action string A ação a ser verificada (usando ActionTypes).
---@return boolean
function InputService:isActionDown(action)
    return self.actionsDown[action] or false
end

---@public Verifica se uma ação de botão foi solta NESTE frame.
---@param action string A ação a ser verificada (usando ActionTypes).
---@return boolean
function InputService:wasActionReleased(action)
    return self.actionsReleased[action] or false
end

---@public Retorna a posição atual do mouse.
--- As coordenadas são relativas à janela do jogo. A conversão para
--- coordenadas do mundo/UI é feita pela câmera ou por utils de resolução.
---@return number mouseX Posição X do mouse.
---@return number mouseY Posição Y do mouse.
function InputService:getMousePosition()
    return love.mouse.getPosition()
end

---@public Retorna um vetor 2D normalizado para o movimento.
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
