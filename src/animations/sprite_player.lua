-- Sistema de Player Animado com Renderização em Camadas
---@class SpritePlayer
local SpritePlayer = {}
local Colors = require("src.ui.colors")

---@class PlayerSpriteConfig
---@field position Vector2D Posição do jogador
---@field scale number Fator de escala
---@field speed number Velocidade de movimento
---@field animation table Configurações de animação
---@field appearance table Aparência do jogador (cor de pele, equipamentos, etc.)

-- Configuração padrão
SpritePlayer.defaultConfig = {
    position = {
        x = 0,
        y = 0,
    },
    scale = 1,
    speed = 150,
    -- Configurações de animação
    animation = {
        currentFrame = 1,
        timer = 0,
        frameTime = {
            walk = 0.05,
            idle = 0.1,
            attack_melee = 0.03,
            attack_ranged = 0.03,
            attack_run_melee = 0.03,
            attack_run_ranged = 0.03,
            die = 0.1,
            idle2 = 0.1,
            idle3 = 0.1,
            idle4 = 0.1,
            strafe_left = 0.05,
            strafe_right = 0.05,
            taunt = 0.08
        },
        -- Mapeamento de direções (primeira linha é oeste, sentido horário)
        direction = 'E',
        state = 'idle',
        isMovingBackward = false,
        isAttacking = false,
        frameWidth = 128,
        frameHeight = 128,
        -- Definição das 8 direções conforme sprite sheets
        directions = {
            E = 1,  -- Este (primeira linha - direita, 0°)
            SE = 2, -- Sudeste (45°)
            S = 3,  -- Sul (90°)
            SW = 4, -- Sudoeste (135°)
            W = 5,  -- Oeste (180°)
            NW = 6, -- Noroeste (225°)
            N = 7,  -- Norte (270°)
            NE = 8  -- Nordeste (315°)
        },
        framesPerDirection = 15
    },
    -- Aparência do jogador
    appearance = {
        skinTone = "medium", -- Cor de pele padrão
        equipment = {
            bag = nil,
            belt = nil,
            chest = nil,
            head = nil,
            leg = nil,
            shoe = nil
        },
        weapon = {
            type = nil, -- axe, sword, bow, etc.
            sprite = nil
        }
    }
}

-- Armazenamento de recursos carregados
SpritePlayer.resources = {
    body = {}, -- Sprites do corpo
    equipment = {
        bag = {},
        belt = {},
        chest = {},
        head = {},
        leg = {},
        shoe = {}
    },
    weapons = {} -- Sprites das armas por tipo
}

-- Quads para otimização de renderização
SpritePlayer.quads = {}

--- Carrega todos os recursos do sistema de camadas
function SpritePlayer.load()
    Logger.info("sprite_player.load", "Carregando sistema de renderização em camadas...")

    -- Carrega sprites do corpo
    SpritePlayer._loadBodySprites()

    -- Carrega sprites de equipamentos (se existirem)
    SpritePlayer._loadEquipmentSprites()

    -- Carrega sprites de armas (se existirem)
    SpritePlayer._loadWeaponSprites()

    Logger.info("sprite_player.load", "Sistema de renderização em camadas carregado com sucesso.")
end

--- Carrega todos os sprites do corpo
function SpritePlayer._loadBodySprites()
    local bodyPath = "assets/player/body/"
    local states = {
        "attack_melee", "attack_ranged", "attack_run_melee", "attack_run_ranged",
        "die", "idle", "idle2", "idle3", "idle4",
        "strafe_left", "strafe_right", "taunt", "walk"
    }

    for _, state in ipairs(states) do
        local filePath = bodyPath .. state .. ".png"
        local success, sprite = pcall(function()
            return love.graphics.newImage(filePath)
        end)

        if success and sprite then
            SpritePlayer.resources.body[state] = sprite
            SpritePlayer._createQuadsForSprite(state, sprite)
            Logger.debug("sprite_player.load_body",
                string.format("Carregado sprite do corpo: %s", state))
        else
            Logger.warn("sprite_player.load_body",
                string.format("Não foi possível carregar sprite: %s", filePath))
        end
    end
end

--- Carrega sprites de equipamentos
function SpritePlayer._loadEquipmentSprites()
    local equipmentTypes = { "bag", "belt", "chest", "head", "leg", "shoe" }

    for _, equipType in ipairs(equipmentTypes) do
        local equipPath = "assets/player/" .. equipType .. "/"
        SpritePlayer.resources.equipment[equipType] = {}

        -- Tenta carregar diferentes variações de cada equipamento
        -- Por enquanto apenas registra a estrutura
        Logger.debug(
            "sprite_player.load_equipment",
            string.format("Estrutura preparada para equipamentos: %s", equipType)
        )
    end
end

--- Carrega sprites de armas
function SpritePlayer._loadWeaponSprites()
    local weaponTypes = {
        "axe",
        "sword",
        "bow",
        "dagger",
        "staff",
        "mace"
    }

    for _, weaponType in ipairs(weaponTypes) do
        local weaponPath = "assets/player/weapons/" .. weaponType .. "/"
        SpritePlayer.resources.weapons[weaponType] = {}

        -- Tenta carregar diferentes variações de cada arma
        -- Por enquanto apenas registra a estrutura
        Logger.debug("sprite_player.load_weapons",
            string.format("Estrutura preparada para armas: %s", weaponType))
    end
end

--- Cria quads para um sprite (8 direções x 15 frames cada)
---@param stateName string Nome do estado da animação
---@param sprite love.Image Sprite carregado
function SpritePlayer._createQuadsForSprite(stateName, sprite)
    if not SpritePlayer.quads[stateName] then
        SpritePlayer.quads[stateName] = {}
    end

    local frameWidth = SpritePlayer.defaultConfig.animation.frameWidth
    local frameHeight = SpritePlayer.defaultConfig.animation.frameHeight
    local framesPerDirection = SpritePlayer.defaultConfig.animation.framesPerDirection

    -- Para cada direção (8 linhas)
    for direction, row in pairs(SpritePlayer.defaultConfig.animation.directions) do
        SpritePlayer.quads[stateName][direction] = {}

        -- Para cada frame na direção (15 colunas)
        for frame = 1, framesPerDirection do
            local x = (frame - 1) * frameWidth
            local y = (row - 1) * frameHeight

            SpritePlayer.quads[stateName][direction][frame] = love.graphics.newQuad(
                x, y, frameWidth, frameHeight, sprite:getDimensions()
            )
        end
    end
end

--- Função auxiliar para determinar direção baseada no ângulo
function SpritePlayer.getDirectionFromAngle(angle)
    -- Normaliza o ângulo para 0 a 2pi
    angle = angle % (2 * math.pi)
    if angle < 0 then
        angle = angle + 2 * math.pi
    end

    -- Converte radianos para graus (0-360)
    local degrees = math.deg(angle)

    -- Define as fatias para 8 direções (45 graus cada)
    local slice = 45

    -- Sistema de coordenadas de tela: 0° = direita, 90° = baixo, 180° = esquerda, 270° = cima
    if degrees >= (slice * 7.5) or degrees < (slice * 0.5) then
        return "E"  -- Este (0° - direita)
    elseif degrees >= (slice * 0.5) and degrees < (slice * 1.5) then
        return "SE" -- Sudeste (45°)
    elseif degrees >= (slice * 1.5) and degrees < (slice * 2.5) then
        return "S"  -- Sul (90° - baixo)
    elseif degrees >= (slice * 2.5) and degrees < (slice * 3.5) then
        return "SW" -- Sudoeste (135°)
    elseif degrees >= (slice * 3.5) and degrees < (slice * 4.5) then
        return "W"  -- Oeste (180° - esquerda)
    elseif degrees >= (slice * 4.5) and degrees < (slice * 5.5) then
        return "NW" -- Noroeste (225°)
    elseif degrees >= (slice * 5.5) and degrees < (slice * 6.5) then
        return "N"  -- Norte (270° - cima)
    else            -- degrees >= (slice * 6.5) and degrees < (slice * 7.5)
        return "NE" -- Nordeste (315°)
    end
end

--- Atualiza o estado da animação
function SpritePlayer.update(config, dt, targetPosition)
    local dx, dy = 0, 0
    local isMoving = false

    -- Processa entrada de movimento
    if love.keyboard.isDown('w') or love.keyboard.isDown('up') then
        dy = -1
        isMoving = true
    end
    if love.keyboard.isDown('s') or love.keyboard.isDown('down') then
        dy = dy + 1                      -- Usa += para permitir cancelamento (W+S = 0)
        isMoving = isMoving or (dy ~= 0) -- Atualiza flag se houve mudança
    end
    if love.keyboard.isDown('a') or love.keyboard.isDown('left') then
        dx = -1
        isMoving = true
    end
    if love.keyboard.isDown('d') or love.keyboard.isDown('right') then
        dx = dx + 1                      -- Usa += para permitir cancelamento (A+D = 0)
        isMoving = isMoving or (dx ~= 0) -- Atualiza flag se houve mudança
    end

    -- Lógica de direção com histerese
    local currentDirection = config.animation.direction
    local targetDx = targetPosition.x - config.position.x
    local targetDy = targetPosition.y - config.position.y

    -- Evita erro com atan2(0,0) e adiciona zona morta MÍNIMA
    if math.abs(targetDx) > 1 or math.abs(targetDy) > 1 then
        local targetAngle = math.atan2(targetDy, targetDx)
        local newDirection = SpritePlayer.getDirectionFromAngle(targetAngle)

        if newDirection ~= currentDirection then
            config.animation.direction = newDirection
            config.animation.currentFrame = 1
            config.animation.timer = 0
        end
    end

    -- Normaliza o vetor de movimento se necessário
    local magnitude = math.sqrt(dx * dx + dy * dy)
    if magnitude > 0 then
        dx = dx / magnitude
        dy = dy / magnitude
    end

    -- Calcula o deslocamento
    local moveX = dx * config.speed * dt
    local moveY = dy * config.speed * dt

    -- Atualiza a posição
    config.position.x = config.position.x + moveX
    config.position.y = config.position.y + moveY

    -- Define o estado da animação
    local newState
    if config.animation.isAttacking then
        newState = isMoving and 'attack_run_melee' or 'attack_melee'
    else
        newState = isMoving and 'walk' or 'idle'
    end

    -- Reseta a animação se o estado mudou
    if newState ~= config.animation.state then
        config.animation.state = newState
        config.animation.currentFrame = 1
        config.animation.timer = 0
    end

    -- Atualiza o timer da animação
    config.animation.timer = config.animation.timer + dt

    -- Obtém o tempo do frame para o estado atual
    local frameTime = config.animation.frameTime[config.animation.state] or 0.1

    -- Avança o frame se o tempo passou
    if config.animation.timer >= frameTime then
        config.animation.timer = config.animation.timer - frameTime
        local maxFrames = config.animation.framesPerDirection
        config.animation.currentFrame = (config.animation.currentFrame % maxFrames) + 1
    end

    return math.sqrt(moveX * moveX + moveY * moveY)
end

--- Desenha o jogador com sistema de camadas
function SpritePlayer.draw(config)
    local currentState = config.animation.state
    local currentDirection = config.animation.direction
    local currentFrame = config.animation.currentFrame

    -- Verifica se o sprite do corpo existe
    if not SpritePlayer.resources.body[currentState] then
        return
    end

    love.graphics.push()
    love.graphics.translate(config.position.x, config.position.y)

    -- Obtém o quad atual
    local bodyQuad = SpritePlayer.quads[currentState] and
        SpritePlayer.quads[currentState][currentDirection] and
        SpritePlayer.quads[currentState][currentDirection][currentFrame]

    if bodyQuad then
        -- Desenha a camada do corpo com cor de pele
        local skinColor = Colors.skinTones[config.appearance.skinTone] or Colors.skinTones.medium
        love.graphics.setColor(skinColor)

        love.graphics.draw(
            SpritePlayer.resources.body[currentState],
            bodyQuad,
            -config.animation.frameWidth * config.scale / 2,
            -config.animation.frameHeight * config.scale / 2,
            0,
            config.scale,
            config.scale
        )

        -- Reseta cor para branco
        love.graphics.setColor(1, 1, 1, 1)

        -- Desenha camadas de equipamentos (se existirem)
        SpritePlayer._drawEquipmentLayers(config, currentState, currentDirection, currentFrame)

        -- Desenha camada de arma (se existir)
        SpritePlayer._drawWeaponLayer(config, currentState, currentDirection, currentFrame)
    end

    love.graphics.pop()
end

--- Desenha as camadas de equipamentos
function SpritePlayer._drawEquipmentLayers(config, state, direction, frame)
    -- Por enquanto apenas a estrutura - implementação futura quando tivermos os sprites
    local equipmentOrder = { "leg", "shoe", "belt", "chest", "bag", "head" }

    for _, equipType in ipairs(equipmentOrder) do
        local equipmentId = config.appearance.equipment[equipType]
        if equipmentId and SpritePlayer.resources.equipment[equipType][equipmentId] then
            -- TODO: Implementar quando tivermos os sprites de equipamentos
        end
    end
end

--- Desenha a camada de arma
function SpritePlayer._drawWeaponLayer(config, state, direction, frame)
    local weaponType = config.appearance.weapon.type
    local weaponSprite = config.appearance.weapon.sprite

    if weaponType and weaponSprite and SpritePlayer.resources.weapons[weaponType] then
        -- TODO: Implementar quando tivermos os sprites de armas
    end
end

--- Cria uma nova configuração de jogador
function SpritePlayer.newConfig(overrides)
    local config = {}

    -- Deep copy da configuração padrão
    for k, v in pairs(SpritePlayer.defaultConfig) do
        if type(v) == "table" then
            config[k] = {}
            for k2, v2 in pairs(v) do
                if type(v2) == "table" then
                    config[k][k2] = {}
                    for k3, v3 in pairs(v2) do
                        if type(v3) == "table" then
                            config[k][k2][k3] = {}
                            for k4, v4 in pairs(v3) do
                                config[k][k2][k3][k4] = v4
                            end
                        else
                            config[k][k2][k3] = v3
                        end
                    end
                else
                    config[k][k2] = v2
                end
            end
        else
            config[k] = v
        end
    end

    -- Aplica overrides se fornecidos
    if overrides then
        for k, v in pairs(overrides) do
            if type(v) == "table" and config[k] and type(config[k]) == "table" then
                for k2, v2 in pairs(v) do
                    if type(v2) == "table" and config[k][k2] and type(config[k][k2]) == "table" then
                        for k3, v3 in pairs(v2) do
                            config[k][k2][k3] = v3
                        end
                    else
                        config[k][k2] = v2
                    end
                end
            else
                config[k] = v
            end
        end
    end

    return config
end

--- Inicia a animação de ataque
function SpritePlayer.startAttackAnimation(config, attackType)
    if not config.animation.isAttacking then
        config.animation.isAttacking = true
        config.animation.currentFrame = 1
        config.animation.timer = 0

        -- Determine o tipo de ataque baseado no parâmetro ou arma equipada
        if attackType == "ranged" or (config.appearance.weapon.type == "bow") then
            config.animation.state = 'attack_ranged'
        else
            config.animation.state = 'attack_melee'
        end
    end
end

--- Para a animação de ataque
function SpritePlayer.stopAttackAnimation(config)
    config.animation.isAttacking = false
end

--- Define a aparência do jogador
function SpritePlayer.setAppearance(config, appearance)
    if appearance.skinTone then
        config.appearance.skinTone = appearance.skinTone
    end

    if appearance.equipment then
        for equipType, equipId in pairs(appearance.equipment) do
            if config.appearance.equipment[equipType] ~= nil then
                config.appearance.equipment[equipType] = equipId
            end
        end
    end

    if appearance.weapon then
        config.appearance.weapon.type = appearance.weapon.type
        config.appearance.weapon.sprite = appearance.weapon.sprite
    end
end

return SpritePlayer
