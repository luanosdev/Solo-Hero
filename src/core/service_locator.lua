---@class ServiceLocator
---@description Um localizador de serviços global e estático (singleton).
--- Responsável por registrar e fornecer acesso a todos os Serviços "imortais" da aplicação.
--- Diferente do SceneManagerRegistry, este é único e persiste entre todas as cenas.
local ServiceLocator = {}

---@type table<string, any>
local services = {}

--- Registra um novo serviço globalmente.
---@param name string O nome do serviço (e.g., "gameTimerService").
---@param service any A instância ou módulo do serviço.
function ServiceLocator.register(name, service)
    if services[name] then
        Logger.warn(
            "service_locator.register.warning",
            string.format("[ServiceLocator:register] Service '%s' already registered.", name)
        )
        return
    end
    services[name] = service
    Logger.info(
        "service_locator.register.success",
        string.format("[ServiceLocator:register] Service '%s' registered successfully.", name)
    )
end

--- Obtém um serviço global registrado.
--- Lança um erro se o serviço não for encontrado.
---@param name string O nome do serviço.
---@return any service A instância do serviço.
function ServiceLocator.get(name)
    local service = services[name]
    assert(service, string.format("[ServiceLocator:get] Service '%s' not found.", name))

    return service
end

--- Tenta obter um serviço global, retorna nil se não encontrado.
---@param name string O nome do serviço.
---@return any|nil
function ServiceLocator.tryGet(name)
    return services[name]
end

--- Atualiza todos os serviços registrados.
---@param dt number Delta time.
function ServiceLocator.update(dt)
    for _, service in pairs(services) do
        if service.update then
            service:update(dt)
        end
    end
end

return ServiceLocator
