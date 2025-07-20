---@class SceneManagerRegistry
---@field managers table<string, {instance: any, drawInCamera: boolean}>
local SceneManagerRegistry = {}
SceneManagerRegistry.__index = SceneManagerRegistry

-- Cria uma nova instância de um registro de manager.
-- Cada cena deve ter sua própria instância.
---@return SceneManagerRegistry
function SceneManagerRegistry:new()
    local instance = setmetatable({}, SceneManagerRegistry)
    instance.managers = {}
    Logger.debug("scene_manager_registry.new.success", "SceneManagerRegistry instance created.")
    return instance
end

--- Registra um novo manager na instância da cena.
---@param name string
---@param manager table
function SceneManagerRegistry:register(name, manager)
    if self.managers[name] then
        Logger.warn(
            "scene_manager_registry.register.warning",
            string.format("Manager '%s' already registered in this scene.", name)
        )
        return
    end

    self.managers[name] = {
        instance = manager,
    }
end

--- Obtém um manager registrado na instância da cena.
---@param name string
---@return any
function SceneManagerRegistry:get(name)
    local managerData = self.managers[name]
    assert(managerData, string.format("Manager '%s' not found in this scene's registry.", name))
    return managerData.instance
end

--- Tenta obter um manager registrado, retorna nil se não encontrado.
---@param name string
---@return any|nil
function SceneManagerRegistry:tryGet(name)
    if not self.managers[name] then
        return nil
    end
    return self.managers[name].instance
end

--- Retorna todos os managers registrados na instância.
---@return table<string, any>
function SceneManagerRegistry:getAll()
    local all = {}
    for name, data in pairs(self.managers) do
        all[name] = data.instance
    end
    return all
end

-- Itera sobre todos os managers e chama seu método update, se existir.
---@param dt number
function SceneManagerRegistry:updateAll(dt)
    for _, managerData in pairs(self.managers) do
        if managerData.instance and managerData.instance.update then
            managerData.instance:update(dt)
        end
    end
end

-- Itera sobre todos os managers e chama seu método draw, se existir.
function SceneManagerRegistry:drawAll()
    for _, managerData in pairs(self.managers) do
        if not managerData.drawInCamera and managerData.instance and managerData.instance.draw then
            managerData.instance:draw()
        end
    end
end

-- Itera e desenha os managers que devem ser renderizados dentro da câmera.
function SceneManagerRegistry:drawAllInCamera()
    for _, managerData in pairs(self.managers) do
        if managerData.drawInCamera and managerData.instance and managerData.instance.draw then
            managerData.instance:draw()
        end
    end
end

-- Limpa todos os managers registrados, preparando para a destruição da cena.
function SceneManagerRegistry:clear()
    -- Primeiro chama o destroy de cada manager, se existir
    for name, managerData in pairs(self.managers) do
        if managerData.instance and type(managerData.instance.destroy) == "function" then
            managerData.instance:destroy()
        end
    end
    -- Depois limpa a tabela
    self.managers = {}
    Logger.info("scene_manager_registry.clear.success", "SceneManagerRegistry cleared and managers destroyed.")
end

--- Desregistra um manager específico.
---@param name string
function SceneManagerRegistry:unregister(name)
    if self.managers[name] and self.managers[name].instance.destroy then
        self.managers[name].instance:destroy()
    else
        Logger.error(
            "scene_manager_registry.unregister.error",
            string.format("Manager '%s' not found in this scene's registry.", name)
        )
    end
    self.managers[name] = nil
    Logger.info(
        "scene_manager_registry.unregister.success",
        string.format("Manager '%s' unregistered from this scene's registry.", name)
    )
end

return SceneManagerRegistry
