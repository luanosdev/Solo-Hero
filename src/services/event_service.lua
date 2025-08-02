---@class EventListener
---@field callback function
---@field context table | nil

---@class EventService
---@description Um gerenciador de eventos global, desacoplado e de alta performance.
--- Permite que diferentes partes do sistema se comuniquem sem dependências diretas,
--- seguindo o padrão publish-subscribe.
---@field listeners table<string, EventListener[]>
local EventService = {}
EventService.__index = EventService

EventService.EVENTS = {
    PLAYER_WRAPPED = 'player_wrapped',
    PLAYER_LEVELED_UP = 'player_leveled_up',
    PLAYER_XP_GAINED = 'player_xp_gained',
    EQUIPMENT_CHANGED = 'equipment_changed',
    EQUIPMENT_BONUSES_UPDATED = 'equipment_bonuses_updated',
    ARCHETYPE_BONUSES_UPDATED = 'archetype_bonuses_updated',
}

--- Cria uma nova instância do EventService.
---@return EventService
function EventService:new()
    local instance = setmetatable({}, EventService)
    instance:init()
    return instance
end

--- Inicializa ou reseta o sistema de eventos, limpando todos os ouvintes.
function EventService:init()
    self.listeners = {}
    Logger.info("event_service.init", "[EventService] Sistema de eventos inicializado.")
end

--- Registra um ouvinte (callback) para um evento específico.
---@param eventName string O nome do evento a ser ouvido.
---@param callback function A função a ser executada quando o evento for emitido.
---@param context table|nil O contexto ('self') a ser aplicado ao callback.
function EventService:on(eventName, callback, context)
    if not eventName or not callback then
        error("[EventService:on] Tentativa de registrar evento com nome ou callback nulo.")
    end

    Logger.info("event_service.on", "[EventService:on] Registrando evento: " .. eventName)
    self.listeners[eventName] = self.listeners[eventName] or {}
    table.insert(self.listeners[eventName], { callback = callback, context = context })
end

--- Remove um ouvinte específico de um evento.
--- O callback fornecido deve ser a mesma instância da função usada em :on().
---@param eventName string O nome do evento.
---@param callback function A função de callback a ser removida.
function EventService:off(eventName, callback)
    if not (self.listeners and self.listeners[eventName]) then
        return
    end
    for i = #self.listeners[eventName], 1, -1 do
        if self.listeners[eventName][i].callback == callback then
            table.remove(self.listeners[eventName], i)
            return -- Retorna após remover para evitar problemas com múltiplos registros do mesmo callback
        end
    end
end

--- Emite um evento, acionando todos os seus ouvintes registrados.
--- Argumentos adicionais (...) são passados para os callbacks.
---@param eventName string O nome do evento a ser emitido.
---@param ... any Argumentos a serem passados para os ouvintes.
function EventService:emit(eventName, ...)
    if self.listeners and self.listeners[eventName] then
        -- Cria uma cópia da tabela de listeners para evitar problemas se um listener
        -- tentar modificar a tabela original (ex: se um :off() for chamado dentro de um :on()).
        local listenersCopy = {}
        for _, listener in ipairs(self.listeners[eventName]) do
            table.insert(listenersCopy, listener)
        end

        for _, listener in ipairs(listenersCopy) do
            if listener.context then
                listener.callback(listener.context, ...)
            else
                listener.callback(...)
            end
        end
    end
end

return EventService
