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
        drawInCamera = drawInCamera
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
function ManagerRegistry:init()
    if self.initialized then
        error("ManagerRegistry já foi inicializado")
    end

    -- Ordem de inicialização é importante
    local initOrder = {
        "playerManager",
        "experienceOrbManager",
        "floatingTextManager",
        "runeManager",
        "enemyManager",
        "dropManager"
    }

    for _, name in ipairs(initOrder) do
        local manager = self.managers[name]
        if manager and manager.instance.init then
            print(string.format("Inicializando %s", name))
            manager.instance:init()
        end
    end

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

--[[
    Gerencia o evento mousepressed para todos os managers (Especialmente para os modais)
    @param x Coordenada x do mouse
    @param y Coordenada y do mouse
    @param button Botão do mouse
]]
function ManagerRegistry:mousepressed(x, y, button)
    for _, manager in pairs(self.managers) do
        if manager.instance.mousepressed then
            if manager.instance.visible then
                manager.instance:mousepressed(x, y, button)
            end
        end
    end
end

return ManagerRegistry 