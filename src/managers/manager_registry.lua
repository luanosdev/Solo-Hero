---@class ManagerRegistry
local ManagerRegistry = {
    managers = {},
    initialized = false,
    updateOrder = {
        "persistenceManager",
        "itemDataManager",
        "archetypeManager",
        "reputationManager",
        "gameStatisticsManager",
    }
}

-- Register a new manager
---@param name string
---@param manager table
---@param drawInCamera? boolean
function ManagerRegistry:register(name, manager, drawInCamera)
    if self.managers[name] then
        Logger.warn("ManagerRegistry:register", string.format("Manager '%s' já está registrado", name))
        return
    end

    self.managers[name] = {
        instance = manager,
        drawInCamera = drawInCamera or false -- Padrão false se não especificado
    }
end

-- Obtém um manager registrado
---@param name string
---@return table
function ManagerRegistry:get(name)
    if not self.managers[name] then
        error(string.format("Manager '%s' não encontrado", name))
    end

    return self.managers[name].instance
end

-- Obtém um manager registrado, mas retorna nil se não encontrado
---@param name string
---@return table|nil
function ManagerRegistry:tryGet(name)
    if not self.managers[name] then
        Logger.error("ManagerRegistry:tryGet", string.format("Manager '%s' não encontrado", name))
        return nil
    end

    return self.managers[name].instance
end

-- Initialize all registered managers
---@param initConfigs table
function ManagerRegistry:init(initConfigs)
    if self.initialized then
        error("ManagerRegistry já foi inicializado")
    end

    initConfigs = initConfigs or {}

    -- Order of initialization is important
    ---@type table<string, number>
    local initOrder = {
        persistenceManager = 1,
        itemDataManager = 2,
        archetypeManager = 3,
        reputationManager = 4,
        gameStatisticsManager = 5,
        hudGameplayManager = 6,
        gameOverManager = 7
    }

    Logger.debug("ManagerRegistry:init", "--- Iniciando Managers --- ")
    for _, name in ipairs(initOrder) do
        local managerData = self.managers[name]
        if managerData and managerData.instance.init then
            Logger.debug("ManagerRegistry:init.start", string.format(" - Inicializando %s...", name))
            managerData.instance:init(initConfigs[name])
        elseif managerData then
            Logger.debug("ManagerRegistry:init.noInit",
                string.format(" - Manager %s registrado, mas sem função init().", name))
        else
            Logger.warn(
                "ManagerRegistry:init.notFoundInInitOrder",
                string.format(" - AVISO: Manager %s na initOrder não está registrado!", name)
            )
        end
    end

    self.initialized = true
end

-- Define the order of update for the managers
---@param dt number
function ManagerRegistry:update(dt)
    -- print("[ManagerRegistry:update] Iniciando ciclo de update...") -- Log opcional
    for _, name in ipairs(self.updateOrder) do
        local managerData = self.managers[name]
        if managerData and managerData.instance and managerData.instance.update then
            -- print(string.format("  -> Atualizando %s", name)) -- Log opcional
            managerData.instance:update(dt)
        elseif managerData and managerData.instance and not managerData.instance.update then
            -- print(string.format("  -> Manager %s na updateOrder NÃO tem método update.", name)) -- Log opcional
        elseif not managerData then
            -- print(string.format("  -> AVISO: Manager %s na updateOrder não está registrado!", name)) -- Log opcional
        end
    end

    -- Atualiza quaisquer outros managers que não estão na updateOrder (caso existam e precisem de update)
    -- Isso pode ser útil para managers adicionados dinamicamente ou que não têm ordem crítica.
    -- No entanto, para um controle estrito, é melhor que todos os managers com `update` estejam na `updateOrder`.
    for name, managerData in pairs(self.managers) do
        local foundInOrder = false
        for _, orderedName in ipairs(self.updateOrder) do
            if name == orderedName then
                foundInOrder = true
                break
            end
        end
        if not foundInOrder and managerData.instance and managerData.instance.update then
            -- Logger.debug("ManagerRegistry:update", string.format("  -> AVISO: Atualizando manager '%s' que não está na updateOrder definida.", name))
            managerData.instance:update(dt)
        end
    end
    -- print("[ManagerRegistry:update] Ciclo de update concluído.") -- Log opcional
end

-- Draw only the managers inside the camera transformation
function ManagerRegistry:CameraDraw()
    for _, manager in pairs(self.managers) do
        if manager.drawInCamera and manager.instance.draw then
            manager.instance:draw()
        end
    end
end

-- Draw all registered managers
function ManagerRegistry:draw()
    local drawnCount = 0
    local checkedCount = 0
    if not self.managers or next(self.managers) == nil then
        Logger.warn("ManagerRegistry:draw", "Tabela self.managers está VAZIA ou NIL.")
        return
    end

    for name, managerData in pairs(self.managers) do
        checkedCount = checkedCount + 1
        local hasDrawMethod = (managerData.instance and type(managerData.instance.draw) == "function")
        if not managerData.drawInCamera then
            if hasDrawMethod then
                managerData.instance:draw()
                drawnCount = drawnCount + 1
            else
                -- Já logado acima que não tem método draw, não precisa logar de novo aqui
            end
        end
    end
end

-- Unregister a manager
---@param name string
function ManagerRegistry:unregister(name)
    self.managers[name] = nil
end

return ManagerRegistry
