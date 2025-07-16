---@class EventManager
---@description Um gerenciador de eventos global, desacoplado e de alta performance.
--- Permite que diferentes partes do sistema se comuniquem sem dependências diretas,
--- seguindo o padrão publish-subscribe.
---@field listeners table<string, function[]>
local EventManager = {}
EventManager.__index = EventManager

--- Cria uma nova instância do EventManager.
---@return EventManager
function EventManager:new()
    local instance = setmetatable({}, EventManager)
    instance:init()
    return instance
end

--- Inicializa ou reseta o sistema de eventos, limpando todos os ouvintes.
function EventManager:init()
    self.listeners = {}
    Logger.info("event_manager.init", "[EventManager] Sistema de eventos inicializado.")
end

--- Registra um ouvinte (callback) para um evento específico.
---@param eventName string O nome do evento a ser ouvido.
---@param callback function A função a ser executada quando o evento for emitido.
function EventManager:on(eventName, callback)
    if not eventName or not callback then
        error("[EventManager:on] Tentativa de registrar evento com nome ou callback nulo.")
    end

    self.listeners[eventName] = self.listeners[eventName] or {}
    table.insert(self.listeners[eventName], callback)
end

--- Remove um ouvinte específico de um evento.
--- O callback fornecido deve ser a mesma instância da função usada em :on().
---@param eventName string O nome do evento.
---@param callback function A função de callback a ser removida.
function EventManager:off(eventName, callback)
    if not (self.listeners and self.listeners[eventName]) then
        return
    end
    for i = #self.listeners[eventName], 1, -1 do
        if self.listeners[eventName][i] == callback then
            table.remove(self.listeners[eventName], i)
            return -- Retorna após remover para evitar problemas com múltiplos registros do mesmo callback
        end
    end
end

--- Emite um evento, acionando todos os seus ouvintes registrados.
--- Argumentos adicionais (...) são passados para os callbacks.
---@param eventName string O nome do evento a ser emitido.
---@param ... any Argumentos a serem passados para os ouvintes.
function EventManager:emit(eventName, ...)
    if self.listeners and self.listeners[eventName] then
        -- Cria uma cópia da tabela de listeners para evitar problemas se um listener
        -- tentar modificar a tabela original (ex: se um :off() for chamado dentro de um :on()).
        local listenersCopy = {}
        for _, listener in ipairs(self.listeners[eventName]) do
            table.insert(listenersCopy, listener)
        end

        for _, callback in ipairs(listenersCopy) do
            callback(...)
        end
    end
end

return EventManager
