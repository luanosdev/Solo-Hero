---@class ControllerServices
---@field eventService EventService
---@field assetService AssetService
---@field inputService InputService
---@field itemDataService ItemDataService
---@field gameTimerService GameTimerService

---@class GameplayControllerContext
---@field services ControllerServices

---@class BaseController
---@description Classe base para todos os controllers do jogo.
--- Fornece uma estrutura comum para inicialização, atualização e destruição,
--- além de acesso padronizado aos serviços globais.
---@field context GameplayControllerContext Tabela contendo todos os serviços globais.
---@field eventListeners EventListenerIdentifier[] Tabela para armazenar os listeners de eventos.
local BaseController = {}
BaseController.__index = BaseController

--- Cria uma nova instância de um controller.
---@param context GameplayControllerContext Uma tabela contendo todos os serviços disponíveis.
---@return any
function BaseController:new(context)
    local instance = setmetatable({}, self)
    assert(context, "[BaseController:new] Missing context.")
    assert(context.services, "[BaseController:new] Missing conservices.")

    instance.context = context
    instance.eventListeners = {}

    return instance
end

---@public Hook de inicialização. Deve ser chamado após a criação de todos os objetos.
function BaseController:init(...)
    -- A ser implementado pelas subclasses.
end

---@public Hook de atualização, chamado a cada frame.
---@param dt number Delta time.
function BaseController:update(dt, ...)
    -- A ser implementado pelas subclasses.
end

---@public Hook para coletar objetos renderizáveis.
---@param renderPipeline RenderPipeline
function BaseController:collectRenderables(renderPipeline)
    -- A ser implementado pelas subclasses.
end

---@public Hook para limpeza de recursos.
function BaseController:destroy()
    for _, listener in ipairs(self.eventListeners) do
        self.context.services.eventService:off(listener)
    end
    self.eventListeners = {}
end

---@protected Registra um listener de evento, garantindo que o `self` do controller seja passado para o callback.
---@param event string Nome do evento.
---@param callback function Callback para o evento.
function BaseController:_listen(event, callback)
    local listener = self.context.services.eventService:on(event, function(...)
        callback(self, ...)
    end)
    table.insert(self.eventListeners, listener)
end

return BaseController
