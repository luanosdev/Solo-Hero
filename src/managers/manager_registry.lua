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

-- Inicializa todos os managers registrados
-- Modificado para aceitar uma tabela opcional de configurações para os inits
function ManagerRegistry:init(initConfigs)
    if self.initialized then
        error("ManagerRegistry já foi inicializado")
    end
    initConfigs = initConfigs or {} -- Garante que seja uma tabela

    -- Ordem de inicialização é importante
    local initOrder = {
        "inputManager",      -- Input primeiro
        "itemDataManager",   -- ItemDataManager antes do InventoryManager
        "inventoryManager",  -- Inventário antes do Player
        "playerManager",     -- Player depende do inventário (agora)
        "experienceOrbManager",
        "floatingTextManager",
        "runeManager",       -- Runas podem depender do Player
        "enemyManager",      -- Inimigos (e seus drops) podem depender do Player/Rank do Mapa
        "dropManager"        -- Drops dependem do EnemyManager e PlayerManager
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

-- Atualiza todos os managers registrados
function ManagerRegistry:update(dt)
    for _, manager in pairs(self.managers) do
        if manager.instance.update then
            manager.instance:update(dt)
        end
    end
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
    for _, manager in pairs(self.managers) do
        if not manager.drawInCamera and manager.instance.draw then
            manager.instance:draw()
        end
    end
end

return ManagerRegistry 