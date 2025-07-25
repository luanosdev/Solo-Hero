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
    local startTime = love.timer.getTime()
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
        end
        -- Adicionamos um yield aqui para distribuir a carga
        coroutine.yield()
    end
    local elapsedTime = (love.timer.getTime() - startTime) * 1000
    Logger.info("SpritePlayer:_loadBodySprites", string.format("Body sprites loaded in %.2f ms", elapsedTime))
end

--- Carrega sprites de equipamentos
function SpritePlayer._loadEquipmentSprites()
    -- Esta função atualmente é leve, mas a preparamos para o futuro
    local equipmentTypes = { "bag", "belt", "chest", "head", "leg", "shoe" }

    for _, equipType in ipairs(equipmentTypes) do
        local equipPath = "assets/player/" .. equipType .. "/"
        SpritePlayer.resources.equipment[equipType] = {}
        Logger.debug(
            "sprite_player.load_equipment",
            string.format("[SpritePlayer:_loadEquipmentSprites] Estrutura preparada para equipamentos: %s", equipType)
        )
        coroutine.yield()
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
    local startTime = love.timer.getTime()
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
        -- Adicionamos um yield aqui para distribuir a carga
        coroutine.yield()
    end

    if next(SpritePlayer.resources.weapons[folderName]) then
        local elapsedTime = (love.timer.getTime() - startTime) * 1000
        Logger.info(
            "sprite_player.load_weapons",
            string.format("[SpritePlayer:_loadWeaponFolder] Loaded weapon sprites for '%s' in %.2f ms", folderName,
                elapsedTime)
        )
    else
        -- Remove entrada vazia se nenhum sprite foi carregado
        SpritePlayer.resources.weapons[folderName] = nil
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
        walk = 2,
        walk_backward = 2,
        strafe_left = 2,
        strafe_right = 2,
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
            adjustedFrameTimes[state] = baseTime / (speedRatio > 0 and speedRatio or 1)

            -- Limita para evitar animações muito rápidas ou muito lentas
            local minFrameTime = 0.02 -- Máximo 25 FPS na animação
            local maxFrameTime = 4    -- Mínimo 5 FPS na animação
            adjustedFrameTimes[state] = math.max(minFrameTime, math.min(maxFrameTime, adjustedFrameTimes[state]))
        else
            -- Outras animações não são afetadas pela velocidade
            adjustedFrameTimes[state] = baseTime
        end
    end

    return adjustedFrameTimes
end

--- Função auxiliar para determinar direção baseada no vetor de velocidade
---@param dx number Componente x do vetor de velocidade
---@param dy number Componente y do vetor de velocidade
---@return string Direção (ex: 'N', 'SE')
function SpritePlayer.getFacingDirection(dx, dy)
    if dx == 0 and dy == 0 then
        -- Se parado, não muda a direção
        return nil
    end

    local angle = math.atan2(dy, dx)
    return SpritePlayer.getDirectionFromAngle(angle)
end

--- Atualiza o estado da animação.
--- Esta função agora é muito mais simples. Ela depende que `sprite.velocity` seja
--- atualizado externamente (pelo MovementController) para refletir a intenção de movimento.
--- A lógica de posição e input foi removida.
---@param sprite PlayerSprite A instância do sprite a ser atualizada
---@param dt number Delta time
---@param targetPosition Vector2D A posição do mouse/alvo para mira
---@param moveSpeedInTiles number A velocidade de movimento atual em tiles/seg
function SpritePlayer.update(sprite, dt, targetPosition, moveSpeedInTiles)
    -- O MovementController agora controla a posição lógica.
    -- O SpritePlayer só se preocupa com a animação baseada na velocidade.
    local speed = math.sqrt(sprite.velocity.x ^ 2 + sprite.velocity.y ^ 2)
    local isMoving = speed > 0.1 -- Pequena zona morta para evitar "tremor"

    -- 1. ATUALIZAR DIREÇÃO DA MIRA (FACING)
    -- A direção que o personagem "olha" (para atirar, etc.) é baseada na posição do alvo (mouse).
    local targetDx = targetPosition.x - sprite.position.x
    local targetDy = targetPosition.y - sprite.position.y
    local facingAngle = math.atan2(targetDy, targetDx)
    if math.abs(targetDx) > 1 or math.abs(targetDy) > 1 then
        local newFacingDirection = SpritePlayer.getDirectionFromAngle(facingAngle)
        -- A direção da animação será definida abaixo, dependendo do estado.
        -- Por padrão, o personagem olha para onde está mirando.
        sprite.animation.direction = newFacingDirection
    end

    -- 2. DETERMINAR ESTADO DA ANIMAÇÃO (IDLE, WALK, ATTACK)
    local newState
    if sprite.animation.isAttacking then
        -- Lógica de animação de ataque
        sprite.animation.attackAnimationTimer = sprite.animation.attackAnimationTimer + dt

        local dynamicFrameTimes = SpritePlayer._calculateDynamicFrameTimes(moveSpeedInTiles)
        local currentAttackAnim = sprite.animation.state
        local currentFrameTime = dynamicFrameTimes[currentAttackAnim] or 0.1
        local animationDuration = sprite.animation.framesPerDirection * currentFrameTime

        if sprite.animation.attackAnimationTimer >= animationDuration then
            SpritePlayer.stopAttackAnimation(sprite)
            -- Após o ataque, volta para idle ou walk
            newState = isMoving and 'walk' or sprite.animation.currentIdleVariant
        else
            -- Mantém a animação de ataque
            if sprite.appearance.weapon.animationType == "ranged" then
                newState = isMoving and 'attack_run_ranged' or 'attack_ranged'
            else
                newState = isMoving and 'attack_run_melee' or 'attack_melee'
            end
        end
    else
        -- Lógica de animação de movimento/parado
        if isMoving then
            sprite.animation.wasMoving = true

            local moveAngle = math.atan2(sprite.velocity.y, sprite.velocity.x)
            local angleDiff = SpritePlayer._normalizeAngleDiff(moveAngle - facingAngle)

            -- Verifica se o movimento é cardinal (um botão) ou diagonal (dois botões).
            -- Movimento cardinal tem um eixo predominante (ex: {1, 0}). A diferença absoluta dos componentes é próxima de 1.
            -- Movimento diagonal tem componentes com magnitudes parecidas (ex: {0.7, 0.7}). A diferença é próxima de 0.
            local isCardinal = math.abs(math.abs(sprite.velocity.x) - math.abs(sprite.velocity.y)) > 0.95

            if isCardinal then
                -- Movimento Cardinal (um botão)
                if math.abs(angleDiff) <= math.pi / 4 then        -- Para frente (±45°)
                    newState = 'walk'
                elseif math.abs(angleDiff) > math.pi * 3 / 4 then -- Para trás (±135°)
                    newState = 'walk_backward'
                else                                              -- Strafe (laterais)
                    if angleDiff > 0 then
                        newState = 'strafe_right'
                    else
                        newState = 'strafe_left'
                    end
                end
            else
                -- Movimento Diagonal (dois botões)
                if math.abs(angleDiff) > math.pi / 2 then
                    newState = 'walk_backward'
                else
                    newState = 'walk'
                end
            end

            -- Define a direção da animação baseado no estado de movimento
            if newState == 'walk' then
                -- Para 'walk' (frente), o personagem se vira na direção do movimento.
                sprite.animation.direction = SpritePlayer.getDirectionFromAngle(moveAngle)
            else
                -- Para 'walk_backward' e 'strafe', o personagem sempre olha para a mira.
                sprite.animation.direction = SpritePlayer.getDirectionFromAngle(facingAngle)
            end
        else
            if sprite.animation.wasMoving then
                sprite.animation.currentIdleVariant = SpritePlayer._chooseRandomIdle(sprite.animation.currentIdleVariant)
                sprite.animation.wasMoving = false
                -- Força o reset da nova animação idle
                sprite.animation.state = nil
            end
            newState = sprite.animation.currentIdleVariant
            -- Quando parado, o personagem se vira para a mira
            sprite.animation.direction = SpritePlayer.getDirectionFromAngle(facingAngle)
        end
    end

    -- 3. ATUALIZAR TIMERS E FRAMES DA ANIMAÇÃO
    if newState ~= sprite.animation.state then
        sprite.animation.state = newState
        sprite.animation.timer = 0
        sprite.animation.isReversed = (newState == 'walk_backward')
        sprite.animation.currentFrame = sprite.animation.isReversed and sprite.animation.framesPerDirection or 1
    end

    sprite.animation.timer = sprite.animation.timer + dt
    local dynamicFrameTimes = SpritePlayer._calculateDynamicFrameTimes(moveSpeedInTiles)
    local frameTime = dynamicFrameTimes[sprite.animation.state] or 0.1

    if sprite.animation.timer >= frameTime then
        sprite.animation.timer = sprite.animation.timer - frameTime
        local maxFrames = sprite.animation.framesPerDirection

        if sprite.animation.isReversed then
            sprite.animation.currentFrame = sprite.animation.currentFrame - 1
            if sprite.animation.currentFrame < 1 then
                sprite.animation.currentFrame = maxFrames
            end
        else
            sprite.animation.currentFrame = (sprite.animation.currentFrame % maxFrames) + 1
        end
    end
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
        Logger.warn(
            "sprite_player.draw",
            string.format("[SpritePlayer:draw] Tentou desenhar, mas o estado '%s' não tem sprite carregado.", spriteState)
        )
        return
    end

    -- Obtém o quad atual
    local bodyQuad = SpritePlayer.quads[spriteState] and
        SpritePlayer.quads[spriteState][currentDirection] and
        SpritePlayer.quads[spriteState][currentDirection][currentFrame]

    if not bodyQuad then
        Logger.warn(
            "sprite_player.draw.quad_fail",
            string.format(
                "[SpritePlayer:draw] Quad não encontrado para state: '%s', direction: '%s', frame: %d. Draw ignorado.",
                tostring(spriteState),
                tostring(currentDirection),
                tostring(currentFrame)
            )
        )
        return
    end

    if bodyQuad then
        -- A translação (posição) é tratada pelo RenderPipeline.
        -- A função de desenho só precisa se preocupar em desenhar no ponto (0,0) relativo.

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
    if not weaponSprites then
        Logger.warn("sprite_player.debug.no_weapon_sprites",
            string.format("[DEBUG] No weapon sprites loaded for folder: %s", tostring(weaponFolder)))
        return
    end

    if not weaponSprites[state] then
        Logger.warn("sprite_player.debug.no_weapon_state",
            string.format("[DEBUG] No weapon sprite for state '%s' in folder '%s'", tostring(state),
                tostring(weaponFolder)))
        return
    end

    -- Verifica se o quad da arma existe para o estado atual
    local weaponQuad = SpritePlayer.quads[weaponFolder] and
        SpritePlayer.quads[weaponFolder][state] and
        SpritePlayer.quads[weaponFolder][state][direction] and
        SpritePlayer.quads[weaponFolder][state][direction][frame]

    if not weaponQuad then
        Logger.warn("sprite_player.debug.no_weapon_quad",
            string.format("[DEBUG] No weapon quad for folder: %s, state: %s, direction: %s, frame: %d",
                tostring(weaponFolder), tostring(state), tostring(direction), tostring(frame)))
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
