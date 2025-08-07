---@class EventListener
---@field id number um identificador unico para o listener
---@field callback function
---@field context table | nil

---@class EventListenerIdentifier
---@field event string
---@field id number

---@class EventService
---@description Um gerenciador de eventos global, desacoplado e de alta performance.
--- Permite que diferentes partes do sistema se comuniquem sem dependências diretas,
--- seguindo o padrão publish-subscribe.
---@field listeners table<string, EventListener[]>
---@field nextListenerId number
local EventService = {}
EventService.__index = EventService

EventService.EVENTS = {
    -- Player Events
    PLAYER_WRAPPED = 'player_wrapped',
    PLAYER_LEVELED_UP = 'player_leveled_up',
    PLAYER_XP_GAINED = 'player_xp_gained',
    
    PLAYER_HEALTH_UPDATED = 'player_health_updated',
    PLAYER_DIED = 'player_died',
    PLAYER_STAT_UPDATED = 'player_stat_updated',
    PLAYER_TOOK_DAMAGE = 'player_took_damage',
    PLAYER_STATE_INITIALIZED = 'player_state_initialized',
    -- Equipment & Stats Events
    EQUIPMENT_CHANGED = 'equipment_changed',
    EQUIPMENT_BONUSES_UPDATED = 'equipment_bonuses_updated',
    ARCHETYPE_BONUSES_UPDATED = 'archetype_bonuses_updated',
    -- Level Up Events
    REQUEST_LEVEL_UP_MODAL = 'request_level_up_modal',
    LEVEL_UP_MODAL_CLOSED = 'level_up_modal_closed',
    LEVEL_UP_BONUSES_UPDATED = 'level_up_bonuses_updated',
    -- Game State
    REQUEST_GAME_PAUSE = 'request_game_pause',
    REQUEST_GAME_UNPAUSE = 'request_game_unpause',
    -- Potion Events
    POTION_STATE_UPDATED = 'potion_state_updated',
    POTION_USED = 'potion_used',
    -- Enemy Events
    ENEMY_KILLED = 'enemy_killed',
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
    self.nextListenerId = 1
    Logger.info("event_service.init", "[EventService] Sistema de eventos inicializado.")
end

--- Registra um ouvinte (callback) para um evento específico.
---@param eventName string O nome do evento a ser ouvido.
---@param callback function A função a ser executada quando o evento for emitido.
---@param context table|nil O contexto ('self') a ser aplicado ao callback.
---@return EventListenerIdentifier eventIdentifier Um identificador para o listener, para remoção posterior.
function EventService:on(eventName, callback, context)
    assert(eventName, "[EventService:on] missing a eventName")
    assert(callback, "[EventService:on] missing a callback")

    local listenerId = self.nextListenerId
    self.nextListenerId = self.nextListenerId + 1

    Logger.info("event_service.on", "[EventService:on] Registrando evento: " .. eventName)
    self.listeners[eventName] = self.listeners[eventName] or {}
    table.insert(self.listeners[eventName], { id = listenerId, callback = callback, context = context })

    return { event = eventName, id = listenerId }
end

--- Remove um ouvinte específico de um evento usando seu identificador.
---@param eventIdentifier EventListenerIdentifier O identificador do listener retornado por :on().
function EventService:off(eventIdentifier)
    if not self.listeners or not self.listeners[eventIdentifier.event] then
        return
    end

    for i = #self.listeners[eventIdentifier.event], 1, -1 do
        if self.listeners[eventIdentifier.event][i].id == eventIdentifier.id then
            table.remove(self.listeners[eventIdentifier.event], i)
            return
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
