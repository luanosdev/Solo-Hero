-- Sistema de Player Animado com Renderização em Camadas
---@class SpritePlayer
local SpritePlayer = {}
local Colors = require("src.ui.colors")
local Constants = require("src.config.constants")

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
    scale = 1.5,
    -- Configurações de animação
    animation = {
        currentFrame = 1,
        timer = 0,
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
        framesPerDirection = 15,
        -- Sistema de idle aleatório
        wasMoving = false, -- Flag para detectar quando para de se mover
        currentIdleVariant = "idle",
        -- Sistema de animação reversa
        isReversed = false,      -- Flag para executar frames em ordem reversa
        -- Sistema de animação de ataque
        attackAnimationTimer = 0 -- Timer para controlar duração de ataques
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
            type = nil,         -- axe, sword, bow, etc.
            sprite = nil,
            folderPath = nil,   -- Pasta dos sprites da arma (ex: "sword_tier_1")
            animationType = nil -- "melee" ou "ranged"
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
    weapons = {} -- Sprites das armas por pasta
}

-- Quads para otimização de renderização
SpritePlayer.quads = {}

-- Lista de animações conhecidas
SpritePlayer.knownAnimationStates = {
    "attack_melee", "attack_ranged", "attack_run_melee", "attack_run_ranged",
    "die", "idle", "idle2", "idle3", "idle4",
    "strafe_left", "strafe_right", "taunt", "walk"
}

-- Pastas de armas conhecidas
SpritePlayer.knownWeaponFolders = {
    "sword_tier_1",
    "bow_tier_1",
    "hammer_tier_1"
}


--- Carrega todos os recursos do sistema de camadas
function SpritePlayer.load()
    Logger.info("sprite_player.load", "[SpritePlayer:load] Carregando sistema de renderização em camadas...")

    -- Carrega sprites do corpo
    SpritePlayer._loadBodySprites()

    -- Carrega sprites de equipamentos (se existirem)
    SpritePlayer._loadEquipmentSprites()

    -- Carrega sprites de armas
    SpritePlayer._loadWeaponSprites()

    Logger.info("sprite_player.load", "[SpritePlayer:load] Sistema de renderização em camadas carregado com sucesso.")
end

--- Carrega todos os sprites do corpo
function SpritePlayer._loadBodySprites()
    local bodyPath = "assets/player/body/"
    local states = SpritePlayer.knownAnimationStates

    for _, state in ipairs(states) do
        local filePath = bodyPath .. state .. ".png"
        local success, sprite = pcall(function()
            return love.graphics.newImage(filePath)
        end)

        if success and sprite then
            SpritePlayer.resources.body[state] = sprite
            SpritePlayer._createQuadsForSprite(state, sprite)
            Logger.debug("sprite_player.load_body",
                string.format("[SpritePlayer:_loadBodySprites] Carregado sprite do corpo: %s", state))
        else
            Logger.warn("sprite_player.load_body",
                string.format("[SpritePlayer:_loadBodySprites] Não foi possível carregar sprite: %s", filePath))
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
            string.format("[SpritePlayer:_loadEquipmentSprites] Estrutura preparada para equipamentos: %s", equipType)
        )
    end
end

--- Carrega sprites de armas baseado nas pastas disponíveis
function SpritePlayer._loadWeaponSprites()
    -- Lista de pastas de armas conhecidas para carregar
    local weaponFolders = SpritePlayer.knownWeaponFolders

    for _, folderName in ipairs(weaponFolders) do
        SpritePlayer._loadWeaponFolder(folderName)
    end
end

--- Carrega todos os sprites de uma pasta de arma específica
---@param folderName string Nome da pasta da arma
function SpritePlayer._loadWeaponFolder(folderName)
    local weaponPath = "assets/player/weapons/" .. folderName .. "/"

    -- Lista de animações que devem sincronizar com o corpo
    local animationStates = SpritePlayer.knownAnimationStates

    SpritePlayer.resources.weapons[folderName] = {}

    for _, state in ipairs(animationStates) do
        local filePath = weaponPath .. state .. ".png"
        local success, sprite = pcall(function()
            return love.graphics.newImage(filePath)
        end)

        if success and sprite then
            SpritePlayer.resources.weapons[folderName][state] = sprite
            SpritePlayer._createQuadsForWeaponSprite(folderName, state, sprite)
        end
    end

    if next(SpritePlayer.resources.weapons[folderName]) then
        Logger.info(
            "sprite_player.load_weapons",
            string.format("[SpritePlayer:_loadWeaponFolder] Carregados sprites da arma: %s", folderName)
        )
    else
        -- Remove entrada vazia se nenhum sprite foi carregado
        SpritePlayer.resources.weapons[folderName] = nil
        Logger.warn(
            "sprite_player.load_weapons",
            string.format("[SpritePlayer:_loadWeaponFolder] Nenhum sprite encontrado para: %s", folderName)
        )
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

--- Cria quads para sprites de armas (mesmo formato que corpo: 8 direções x 15 frames)
---@param weaponFolder string Pasta da arma
---@param stateName string Nome do estado da animação
---@param sprite love.Image Sprite carregado da arma
function SpritePlayer._createQuadsForWeaponSprite(weaponFolder, stateName, sprite)
    if not SpritePlayer.quads[weaponFolder] then
        SpritePlayer.quads[weaponFolder] = {}
    end

    if not SpritePlayer.quads[weaponFolder][stateName] then
        SpritePlayer.quads[weaponFolder][stateName] = {}
    end

    local frameWidth = SpritePlayer.defaultConfig.animation.frameWidth
    local frameHeight = SpritePlayer.defaultConfig.animation.frameHeight
    local framesPerDirection = SpritePlayer.defaultConfig.animation.framesPerDirection

    -- Para cada direção (8 linhas)
    for direction, row in pairs(SpritePlayer.defaultConfig.animation.directions) do
        SpritePlayer.quads[weaponFolder][stateName][direction] = {}

        -- Para cada frame na direção (15 colunas)
        for frame = 1, framesPerDirection do
            local x = (frame - 1) * frameWidth
            local y = (row - 1) * frameHeight

            SpritePlayer.quads[weaponFolder][stateName][direction][frame] = love.graphics.newQuad(
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

--- Calcula os tempos de frame dinâmicos baseados na velocidade atual do jogador
---@param currentSpeed number Velocidade atual do jogador
---@return table Tabela com tempos de frame ajustados
function SpritePlayer._calculateDynamicFrameTimes(currentSpeed)
    local baseSpeed = Constants.HUNTER_DEFAULT_STATS.moveSpeed
    local speedRatio = currentSpeed / baseSpeed

    -- Tempos de frame base (quando velocidade = valor base)
    local baseFrameTimes = {
        walk = 0.12,
        walk_backward = 0.12,
        strafe_left = 0.12,
        strafe_right = 0.12,
        -- Estes não são afetados pela velocidade de movimento
        idle = 0.1,
        idle2 = 0.1,
        idle3 = 0.1,
        idle4 = 0.1,
        attack_melee = 0.02,
        attack_ranged = 0.02,
        attack_run_melee = 0.02,
        attack_run_ranged = 0.02,
        die = 0.1,
        taunt = 0.08
    }

    -- Calcula tempos ajustados para animações de movimento
    local adjustedFrameTimes = {}
    for state, baseTime in pairs(baseFrameTimes) do
        if state == "walk" or state == "walk_backward" or
            state == "strafe_left" or state == "strafe_right" then
            -- Aplica a velocidade: mais rápido = frames mais rápidos
            adjustedFrameTimes[state] = baseTime / speedRatio

            -- Limita para evitar animações muito rápidas ou muito lentas
            local minFrameTime = 0.04 -- Máximo 25 FPS na animação
            local maxFrameTime = 0.20 -- Mínimo 5 FPS na animação
            adjustedFrameTimes[state] = math.max(minFrameTime, math.min(maxFrameTime, adjustedFrameTimes[state]))
        else
            -- Outras animações não são afetadas pela velocidade
            adjustedFrameTimes[state] = baseTime
        end
    end

    return adjustedFrameTimes
end

--- Atualiza o estado da animação
---@param config PlayerSpriteConfig Configuração do player
---@param dt number Delta time
---@param targetPosition Vector2D Posição alvo
---@param currentSpeed number Velocidade atual do jogador (stats finais)
---@return number|nil distanceMoved Distância movida neste frame
function SpritePlayer.update(config, dt, targetPosition, currentSpeed)
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

    -- Calcula o deslocamento usando a velocidade atual do jogador
    local moveX = dx * currentSpeed * dt
    local moveY = dy * currentSpeed * dt

    -- Atualiza a posição
    config.position.x = config.position.x + moveX
    config.position.y = config.position.y + moveY

    -- Define o estado da animação
    local newState
    if config.animation.isAttacking then
        -- Atualiza timer de ataque
        config.animation.attackAnimationTimer = config.animation.attackAnimationTimer + dt

        -- Calcula duração real da animação baseada no frameTime atual
        local dynamicFrameTimes = SpritePlayer._calculateDynamicFrameTimes(currentSpeed)
        local currentFrameTime = dynamicFrameTimes[config.animation.state] or 0.1
        local animationDuration = config.animation.framesPerDirection * currentFrameTime

        -- Para a animação quando completa um ciclo
        if config.animation.attackAnimationTimer >= animationDuration then
            SpritePlayer.stopAttackAnimation(config)
        else
            -- Determina estado de ataque baseado no tipo da arma e movimento
            if config.appearance.weapon.animationType == "ranged" then
                newState = isMoving and 'attack_run_ranged' or 'attack_ranged'
            else
                newState = isMoving and 'attack_run_melee' or 'attack_melee'
            end
        end
    else
        if not isMoving then
            -- Detecta se acabou de parar de se mover
            if config.animation.wasMoving then
                -- Escolhe uma nova animação idle aleatória
                config.animation.currentIdleVariant = SpritePlayer._chooseRandomIdle(config.animation.currentIdleVariant)
                config.animation.wasMoving = false

                -- Reinicia a animação para a nova variante
                config.animation.currentFrame = 1
                config.animation.timer = 0
            end

            newState = config.animation.currentIdleVariant
        else
            -- Marca que estava se movendo
            config.animation.wasMoving = true

            -- Determina o tipo de movimento
            local movementState = SpritePlayer._getMovementState(dx, dy, config.animation.direction)
            newState = movementState
        end
    end

    -- Reseta a animação se o estado mudou
    if newState ~= config.animation.state then
        config.animation.state = newState
        config.animation.timer = 0

        -- Configura se a animação deve ser executada em reverso
        config.animation.isReversed = (newState == 'walk_backward')

        -- Define o frame inicial baseado na direção da animação
        if config.animation.isReversed then
            config.animation.currentFrame = config.animation.framesPerDirection -- Começa do último frame
        else
            config.animation.currentFrame = 1                                   -- Começa do primeiro frame
        end
    end

    -- Atualiza o timer da animação
    config.animation.timer = config.animation.timer + dt

    -- Calcula tempos de frame dinâmicos baseados na velocidade atual
    local dynamicFrameTimes = SpritePlayer._calculateDynamicFrameTimes(currentSpeed)

    -- Obtém o tempo do frame para o estado atual
    local frameTime = dynamicFrameTimes[config.animation.state] or 0.1

    -- Avança o frame se o tempo passou
    if config.animation.timer >= frameTime then
        config.animation.timer = config.animation.timer - frameTime
        local maxFrames = config.animation.framesPerDirection

        if config.animation.isReversed then
            -- Animação reversa: vai de maxFrames para 1
            config.animation.currentFrame = config.animation.currentFrame - 1
            if config.animation.currentFrame < 1 then
                config.animation.currentFrame = maxFrames
            end
        else
            -- Animação normal: vai de 1 para maxFrames
            config.animation.currentFrame = (config.animation.currentFrame % maxFrames) + 1
        end
    end

    return math.sqrt(moveX * moveX + moveY * moveY)
end

--- Escolhe uma nova animação idle aleatória diferente da atual
---@param currentIdleVariant string Variante de idle atual
---@return string Nova variante de idle escolhida
function SpritePlayer._chooseRandomIdle(currentIdleVariant)
    -- Lista de todas as variações de idle disponíveis
    local idleVariants = { "idle", "idle2", "idle3", "idle4" }

    -- Filtra para não repetir a mesma animação e só incluir sprites que existem
    local availableVariants = {}
    for _, variant in ipairs(idleVariants) do
        if variant ~= currentIdleVariant and SpritePlayer.resources.body[variant] then
            table.insert(availableVariants, variant)
        end
    end

    -- Se não houver outras variantes disponíveis, mantém a atual
    if #availableVariants == 0 then
        Logger.debug(
            "sprite_player.idle_choice",
            string.format(
                "[SpritePlayer:_chooseRandomIdle] Nenhuma variante disponível, mantendo %s",
                currentIdleVariant
            )
        )
        return currentIdleVariant
    end

    -- Escolhe aleatoriamente uma das variantes disponíveis
    local randomIndex = love.math.random(1, #availableVariants)
    local newVariant = availableVariants[randomIndex]

    Logger.debug(
        "sprite_player.idle_choice",
        string.format(
            "[SpritePlayer:_chooseRandomIdle] Personagem parou: mudando de %s para %s",
            currentIdleVariant, newVariant
        )
    )

    return newVariant
end

--- Determina o tipo de movimento baseado na direção do movimento vs direção do olhar
---@param dx number Componente X do movimento normalizado
---@param dy number Componente Y do movimento normalizado
---@param facingDirection string Direção que o personagem está olhando
---@return string Estado de movimento apropriado
function SpritePlayer._getMovementState(dx, dy, facingDirection)
    -- Se não há movimento, retorna walk padrão (não deveria chegar aqui)
    if dx == 0 and dy == 0 then
        return 'walk'
    end

    -- Calcula o ângulo do movimento
    local movementAngle = math.atan2(dy, dx)

    -- Obtém o ângulo da direção que o personagem está olhando
    local facingAngle = SpritePlayer._getAngleFromDirection(facingDirection)

    -- Calcula a diferença angular entre movimento e direção que olha
    local angleDiff = SpritePlayer._normalizeAngleDiff(movementAngle - facingAngle)

    -- Define thresholds
    local strafeThreshold = math.pi / 6   -- 30 graus para strafe
    local backwardThreshold = math.pi / 4 -- 45 graus para movimento de costas

    -- Verifica movimento de costas (aproximadamente 180° oposto)
    local backwardAngle = math.pi -- 180 graus
    if math.abs(math.abs(angleDiff) - backwardAngle) < backwardThreshold then
        Logger.debug(
            "sprite_player.movement_detection",
            string.format(
                "[SpritePlayer:_getMovementState] Movimento de costas detectado - angleDiff: %.2f°, threshold: %.2f°",
                math.deg(math.abs(angleDiff)), math.deg(backwardThreshold)
            )
        )

        return 'walk_backward'
    end

    -- Verifica strafe para a direita (90 graus à direita)
    local rightStrafeAngle = math.pi / 2
    if math.abs(angleDiff - rightStrafeAngle) < strafeThreshold then
        return 'strafe_right'
    end

    -- Verifica strafe para a esquerda (90 graus à esquerda)
    local leftStrafeAngle = -math.pi / 2
    if math.abs(angleDiff - leftStrafeAngle) < strafeThreshold then
        return 'strafe_left'
    end

    -- Movimento normal (para frente ou diagonal não específico)
    return 'walk'
end

--- Converte direção em ângulo
---@param direction string Direção (E, SE, S, SW, W, NW, N, NE)
---@return number Ângulo em radianos
function SpritePlayer._getAngleFromDirection(direction)
    local angleMap = {
        E = 0,                -- 0°
        SE = math.pi / 4,     -- 45°
        S = math.pi / 2,      -- 90°
        SW = 3 * math.pi / 4, -- 135°
        W = math.pi,          -- 180°
        NW = 5 * math.pi / 4, -- 225°
        N = 3 * math.pi / 2,  -- 270°
        NE = 7 * math.pi / 4  -- 315°
    }
    return angleMap[direction] or 0
end

--- Normaliza diferença angular para -π a π
---@param angleDiff number Diferença angular em radianos
---@return number Diferença normalizada
function SpritePlayer._normalizeAngleDiff(angleDiff)
    while angleDiff > math.pi do
        angleDiff = angleDiff - 2 * math.pi
    end
    while angleDiff < -math.pi do
        angleDiff = angleDiff + 2 * math.pi
    end
    return angleDiff
end

--- Desenha o jogador com sistema de camadas sincronizadas
function SpritePlayer.draw(config)
    local currentState = config.animation.state
    local currentDirection = config.animation.direction
    local currentFrame = config.animation.currentFrame

    -- Para walk_backward, usa o sprite walk normal
    local spriteState = currentState
    if currentState == 'walk_backward' then
        spriteState = 'walk'
    end

    -- Verifica se o sprite do corpo existe
    if not SpritePlayer.resources.body[spriteState] then
        return
    end

    love.graphics.push()
    love.graphics.translate(config.position.x, config.position.y)

    -- Obtém o quad atual
    local bodyQuad = SpritePlayer.quads[spriteState] and
        SpritePlayer.quads[spriteState][currentDirection] and
        SpritePlayer.quads[spriteState][currentDirection][currentFrame]

    if bodyQuad then
        -- Desenha a camada do corpo com cor de pele
        local skinColor = Colors.skinTones[config.appearance.skinTone] or Colors.skinTones.medium
        love.graphics.setColor(skinColor)

        love.graphics.draw(
            SpritePlayer.resources.body[spriteState],
            bodyQuad,
            -config.animation.frameWidth * config.scale / 2,
            -config.animation.frameHeight * config.scale / 2,
            0,
            config.scale,
            config.scale
        )

        -- Reseta cor para branco
        love.graphics.setColor(1, 1, 1, 1)

        -- Desenha camadas de equipamentos (se existirem) - sempre sincronizadas
        SpritePlayer._drawEquipmentLayers(config, spriteState, currentDirection, currentFrame)

        -- Desenha camada de arma (se existir) - sempre sincronizada
        SpritePlayer._drawWeaponLayer(config, spriteState, currentDirection, currentFrame)
    end

    love.graphics.pop()
end

--- Desenha as camadas de equipamentos sempre sincronizadas com o corpo
function SpritePlayer._drawEquipmentLayers(config, state, direction, frame)
    -- Por enquanto apenas a estrutura - implementação futura quando tivermos os sprites
    local equipmentOrder = { "leg", "shoe", "belt", "chest", "bag", "head" }

    for _, equipType in ipairs(equipmentOrder) do
        local equipmentId = config.appearance.equipment[equipType]
        if equipmentId and SpritePlayer.resources.equipment[equipType][equipmentId] then
            -- TODO: Implementar quando tivermos os sprites de equipamentos
            -- Os equipamentos usarão o mesmo state, direction e frame do corpo
        end
    end
end

--- Desenha a camada de arma sempre sincronizada com o corpo
function SpritePlayer._drawWeaponLayer(config, state, direction, frame)
    -- Só desenha arma se tiver uma equipada
    if not config.appearance.weapon.folderPath then
        return
    end

    local weaponFolder = config.appearance.weapon.folderPath
    local weaponSprites = SpritePlayer.resources.weapons[weaponFolder]

    -- Verifica se temos sprites da arma carregados
    if not weaponSprites or not weaponSprites[state] then
        return
    end

    -- Verifica se o quad da arma existe para o estado atual
    local weaponQuad = SpritePlayer.quads[weaponFolder] and
        SpritePlayer.quads[weaponFolder][state] and
        SpritePlayer.quads[weaponFolder][state][direction] and
        SpritePlayer.quads[weaponFolder][state][direction][frame]

    if not weaponQuad then
        return
    end

    -- Desenha a arma exatamente sincronizada com o corpo
    love.graphics.draw(
        weaponSprites[state],
        weaponQuad,
        -config.animation.frameWidth * config.scale / 2,
        -config.animation.frameHeight * config.scale / 2,
        0,
        config.scale,
        config.scale
    )
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

--- Inicia a animação de ataque baseada no tipo da arma
---@param config PlayerSpriteConfig Configuração do sprite do player
---@param attackType string|nil Tipo de ataque (opcional, será detectado automaticamente se não fornecido)
---@param isMoving boolean|nil Se o player está se movendo
function SpritePlayer.startAttackAnimation(config, attackType, isMoving)
    if not config.animation.isAttacking then
        config.animation.isAttacking = true
        config.animation.currentFrame = 1
        config.animation.timer = 0
        config.animation.attackAnimationTimer = 0 -- Reset timer de ataque

        -- Detecta tipo de animação baseado na arma equipada
        local weaponAnimationType = config.appearance.weapon.animationType
        local finalAttackType = attackType or weaponAnimationType or "melee"

        -- Define estado de animação baseado no tipo da arma e movimento
        if finalAttackType == "ranged" then
            config.animation.state = isMoving and 'attack_run_ranged' or 'attack_ranged'
        else
            config.animation.state = isMoving and 'attack_run_melee' or 'attack_melee'
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
        config.appearance.weapon.folderPath = appearance.weapon.folderPath
        config.appearance.weapon.animationType = appearance.weapon.animationType
    end
end

--- Força uma nova escolha de idle na próxima vez que o personagem parar
---@param config PlayerSpriteConfig Configuração do sprite do player
function SpritePlayer.forceIdleChange(config)
    config.animation.wasMoving = true
    Logger.debug(
        "sprite_player.force_idle_change",
        string.format("[SpritePlayer:forceIdleChange] Forçando nova escolha de idle na próxima parada: %s",
            config.animation.state))
end

return SpritePlayer
