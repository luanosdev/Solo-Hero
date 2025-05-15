---@class ManagerRegistry
local ManagerRegistry = {
    managers = {},
    initialized = false
}

--[[
    Registra um novo manager
    @param name Nome do manager
    @param manager Instância do manager
    @param drawInCamera Booleano indicando se deve ser desenhado dentro da transformação da câmera
]]
function ManagerRegistry:register(name, manager, drawInCamera)
    if self.managers[name] then
        error(string.format("Manager '%s' já está registrado", name))
    end
    self.managers[name] = {
        instance = manager,
        drawInCamera = drawInCamera or false -- Padrão false se não especificado
    }
end

-- Obtém um manager registrado
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
        return nil
    end
    return self.managers[name].instance
end

-- Inicializa todos os managers registrados
-- Modificado para aceitar uma tabela opcional de configurações para os inits
function ManagerRegistry:init(initConfigs)
    if self.initialized then
        error("ManagerRegistry já foi inicializado")
    end
    initConfigs = initConfigs or {} -- Garante que seja uma tabela

    -- Ordem de inicialização é importante
    local initOrder = {
        "inputManager",     -- Input primeiro
        "itemDataManager",  -- ItemDataManager antes do InventoryManager
        "inventoryManager", -- Inventário antes do Player
        "playerManager",    -- Player depende do inventário (agora)
        "experienceOrbManager",
        "floatingTextManager",
        "runeManager",  -- Runas podem depender do Player
        "enemyManager", -- Inimigos (e seus drops) podem depender do Player/Rank do Mapa
        "dropManager"   -- Drops dependem do EnemyManager e PlayerManager
        -- Adicione outros managers aqui na ordem correta
    }

    print("--- Iniciando Managers --- ")
    for _, name in ipairs(initOrder) do
        local managerData = self.managers[name]
        if managerData and managerData.instance.init then
            print(string.format(" - Inicializando %s...", name))
            managerData.instance:init(initConfigs[name])
        elseif managerData then
            print(string.format(" - Manager %s registrado, mas sem função init().", name))
        else
            print(string.format(" - AVISO: Manager %s na initOrder não está registrado!", name))
        end
    end
    print("-------------------------")

    self.initialized = true
end

-- Define a ordem de atualização dos managers
ManagerRegistry.updateOrder = {
    "inputManager",
    "playerManager",
    "enemyManager",
    "experienceOrbManager",
    "dropManager",
    "floatingTextManager", -- << Deve vir DEPOIS de playerManager e enemyManager
    "runeManager",
    "inventoryManager"
    -- Adicione outros managers que precisam de update em ordem específica aqui
}

-- Atualiza todos os managers registrados
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
            print(string.format("  -> AVISO: Atualizando manager '%s' que não está na updateOrder definida.", name))
            managerData.instance:update(dt)
        end
    end
    -- print("[ManagerRegistry:update] Ciclo de update concluído.") -- Log opcional
end

--[[
    Desenha somente os managers dentro da transformação da câmera
]]
function ManagerRegistry:CameraDraw()
    for _, manager in pairs(self.managers) do
        if manager.drawInCamera and manager.instance.draw then
            manager.instance:draw()
        end
    end
end

--[[
    Desenha todos os managers registrados fora da transformação da câmera
]]
function ManagerRegistry:draw()
    local drawnCount = 0
    local checkedCount = 0
    if not self.managers or next(self.managers) == nil then
        print("  [ManagerRegistry:draw()] AVISO: Tabela self.managers está VAZIA ou NIL.")
        print("[ManagerRegistry:draw()] ----- FIM CICLO DRAW UI (VAZIO) -----")
        return
    end

    for name, managerData in pairs(self.managers) do
        checkedCount = checkedCount + 1
        local hasDrawMethod = (managerData.instance and type(managerData.instance.draw) == "function")
        if not managerData.drawInCamera then
            if hasDrawMethod then
                print(string.format("    -> DESENHANDO UI: %s", name))
                managerData.instance:draw()
                drawnCount = drawnCount + 1
            else
                -- Já logado acima que não tem método draw, não precisa logar de novo aqui
            end
        end
    end
end

function ManagerRegistry:unregister(name)
    self.managers[name] = nil
end

return ManagerRegistry
