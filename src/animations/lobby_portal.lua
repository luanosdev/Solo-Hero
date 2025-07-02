--- Sistema de animação para portais do lobby com 3 camadas
---@class LobbyPortal
local LobbyPortal = {}
LobbyPortal.__index = LobbyPortal

--- Configuração padrão de uma instância de portal
---@class PortalAnimationConfig
---@field position? Vector2D Posição do portal no mundo
---@field scale? number Escala do portal
---@field color? table Cor RGB para aplicar sobre as texturas (formato LÖVE 0-1)
---@field alpha? number Transparência (0-1)
---@field animation? table Configurações de animação

LobbyPortal.defaultConfig = {
    position = { x = 0, y = 0 },
    scale = 0.5,
    color = { 1, 1, 1 }, -- Branco por padrão (sem alteração)
    alpha = 0.5,
    animation = {
        currentFrame = 1,
        timer = 0,
        frameTime = 0.1,  -- Tempo entre frames (em segundos)
        totalFrames = 10, -- 2 linhas x 5 colunas = 10 frames
        rows = 2,
        cols = 5,
        isActive = true
    }
}

-- Armazena os assets carregados (imagens e quads)
LobbyPortal.assets = {
    loaded = false,
    images = {},
    quads = {}
}

--- Carrega os assets do portal (3 camadas)
function LobbyPortal.loadAssets()
    if LobbyPortal.assets.loaded then
        Logger.info("lobby_portal.loadAssets.already_loaded", "[LobbyPortal] Assets já carregados")
        return true
    end

    Logger.info("lobby_portal.loadAssets", "[LobbyPortal] Carregando assets das 3 camadas...")

    local layerPaths = {
        back = "assets/effects/portal-back.png",
        middle = "assets/effects/portal.png",
        front = "assets/effects/portal-front.png"
    }

    Logger.info("lobby_portal.loadAssets.layers",
        string.format("[LobbyPortal] Tentando carregar %d camadas: %s",
            3, table.concat({ "back", "middle", "front" }, ", ")))

    -- Carregar imagens
    local loadedCount = 0
    for layerName, path in pairs(layerPaths) do
        Logger.info("lobby_portal.loadAssets.loading", "[LobbyPortal] Tentando carregar: " .. path)
        local success, image = pcall(love.graphics.newImage, path)
        if success then
            LobbyPortal.assets.images[layerName] = image
            local w, h = image:getDimensions()
            Logger.info("lobby_portal.loadAssets.layer",
                string.format("[LobbyPortal] Camada '%s' carregada com sucesso - Dimensões: %dx%d",
                    layerName, w, h))
            loadedCount = loadedCount + 1
        else
            Logger.error("lobby_portal.loadAssets.error",
                "[LobbyPortal] Falha ao carregar '" .. path .. "': " .. tostring(image))
            return false
        end
    end

    Logger.info("lobby_portal.loadAssets.summary",
        string.format("[LobbyPortal] %d/%d camadas carregadas com sucesso", loadedCount, 3))

    -- Criar quads para cada camada (assumindo que todas têm as mesmas dimensões)
    Logger.info("lobby_portal.loadAssets.createQuads", "[LobbyPortal] Iniciando criação de quads...")
    local success, result = pcall(LobbyPortal._createQuads, LobbyPortal)
    if not success then
        Logger.error("lobby_portal.loadAssets.createQuads", "[LobbyPortal] Erro ao criar quads: " .. tostring(result))
        return false
    end

    LobbyPortal.assets.loaded = true
    Logger.info("lobby_portal.loadAssets.complete", "[LobbyPortal] Assets carregados com sucesso!")
    return true
end

--- Cria os quads para animação (2 linhas x 5 colunas)
function LobbyPortal:_createQuads()
    local config = LobbyPortal.defaultConfig.animation

    -- Usar a primeira imagem carregada para calcular dimensões dos frames
    local refImage = next(LobbyPortal.assets.images)
    if not refImage then
        Logger.error("lobby_portal._createQuads", "[LobbyPortal] Nenhuma imagem disponível para criar quads")
        return
    end

    local imageWidth, imageHeight = LobbyPortal.assets.images[refImage]:getDimensions()
    local frameWidth = imageWidth / config.cols
    local frameHeight = imageHeight / config.rows

    Logger.info("lobby_portal._createQuads.dimensions",
        "[LobbyPortal] Dimensões: " .. imageWidth .. "x" .. imageHeight ..
        " | Frame: " .. frameWidth .. "x" .. frameHeight)

    -- Criar quads para cada camada
    for layerName, _ in pairs(LobbyPortal.assets.images) do
        LobbyPortal.assets.quads[layerName] = {}

        for row = 0, config.rows - 1 do
            for col = 0, config.cols - 1 do
                local frameIndex = row * config.cols + col + 1
                local x = col * frameWidth
                local y = row * frameHeight

                LobbyPortal.assets.quads[layerName][frameIndex] = love.graphics.newQuad(
                    x, y, frameWidth, frameHeight, imageWidth, imageHeight
                )
            end
        end

        Logger.info("lobby_portal._createQuads.layer",
            "[LobbyPortal] Quads criados para camada '" .. layerName .. "': " .. config.totalFrames .. " frames")
    end
end

--- Cria uma nova configuração de instância de portal
---@param overrides table|nil Configurações para sobrescrever os padrões
---@return PortalAnimationConfig config Nova configuração de instância
function LobbyPortal.createInstance(overrides)
    -- Copia profunda da configuração padrão
    local config = {}
    for key, value in pairs(LobbyPortal.defaultConfig) do
        if type(value) == "table" then
            config[key] = {}
            for subKey, subValue in pairs(value) do
                config[key][subKey] = subValue
            end
        else
            config[key] = value
        end
    end

    -- Aplica overrides se fornecidos
    if overrides then
        for key, value in pairs(overrides) do
            if type(value) == "table" and config[key] and type(config[key]) == "table" then
                -- Merge de tabelas
                for subKey, subValue in pairs(value) do
                    config[key][subKey] = subValue
                end
            else
                config[key] = value
            end
        end
    end

    return config
end

--- Atualiza a animação do portal
---@param config PortalAnimationConfig Configuração da instância
---@param dt number Delta time
function LobbyPortal.update(config, dt)
    if not config.animation.isActive then
        return
    end

    local anim = config.animation
    anim.timer = anim.timer + dt

    -- Avança para o próximo frame se necessário
    if anim.timer >= anim.frameTime then
        anim.timer = anim.timer - anim.frameTime
        anim.currentFrame = anim.currentFrame + 1

        if anim.currentFrame > anim.totalFrames then
            anim.currentFrame = 1 -- Loop da animação
        end
    end
end

--- Desenha o portal com todas as 3 camadas
---@param config PortalAnimationConfig Configuração da instância
function LobbyPortal.draw(config)
    if not LobbyPortal.assets.loaded then
        -- Desenha placeholder se assets não carregados
        love.graphics.setColor(1, 0, 1, 0.5) -- Magenta transparente
        love.graphics.circle("fill", config.position.x, config.position.y, 20 * config.scale)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    local frame = config.animation.currentFrame

    -- Ordem de desenho: back -> middle -> front
    local drawOrder = { "back", "middle", "front" }

    for _, layerName in ipairs(drawOrder) do
        local image = LobbyPortal.assets.images[layerName]
        local quad = LobbyPortal.assets.quads[layerName][frame]

        if image and quad then
            -- Aplicar cor e transparência
            love.graphics.setColor(
                config.color[1] or 1,
                config.color[2] or 1,
                config.color[3] or 1,
                config.alpha or 1
            )

            -- Calcular offset para centralizar o frame
            local _, _, frameWidth, frameHeight = quad:getViewport()
            local offsetX = frameWidth * config.scale / 2
            local offsetY = frameHeight * config.scale / 2

            -- Desenhar a camada
            love.graphics.draw(
                image, quad,
                config.position.x, config.position.y,
                0, -- rotação
                config.scale, config.scale,
                offsetX, offsetY
            )
        end
    end

    -- Resetar cor
    love.graphics.setColor(1, 1, 1, 1)
end

--- Define a cor do portal
---@param config PortalAnimationConfig Configuração da instância
---@param r number Componente vermelho (0-1)
---@param g number Componente verde (0-1)
---@param b number Componente azul (0-1)
function LobbyPortal.setColor(config, r, g, b)
    config.color[1] = r or 1
    config.color[2] = g or 1
    config.color[3] = b or 1
end

--- Define a transparência do portal
---@param config PortalAnimationConfig Configuração da instância
---@param alpha number Transparência (0-1)
function LobbyPortal.setAlpha(config, alpha)
    config.alpha = alpha or 1
end

--- Para ou inicia a animação
---@param config PortalAnimationConfig Configuração da instância
---@param active boolean Se a animação deve estar ativa
function LobbyPortal.setAnimationActive(config, active)
    config.animation.isActive = active
end

--- Verifica se os assets estão carregados
---@return boolean loaded Se os assets estão carregados
function LobbyPortal.areAssetsLoaded()
    return LobbyPortal.assets.loaded
end

return LobbyPortal
