-- Módulo de animação para unidades usando spritesheets completos por animação
local AnimatedSpritesheet = {}

-- Estrutura de configuração padrão da instância
AnimatedSpritesheet.defaultInstanceConfig = {
    position = { x = 0, y = 0 },
    scale = 1.0,
    animation = {
        currentFrame = 1,
        timer = 0,
        direction = 0,               -- Ângulo numérico (ex: 0, 45, 90)
        activeMovementType = 'walk', -- Tipo de movimento atual ('walk', 'run', etc.)
        isDead = false,
        chosenDeathType = nil        -- Será 'death_die1', 'death_die2', etc., quando morrer
    }
}

-- Armazena as configurações carregadas para cada tipo de unidade
AnimatedSpritesheet.configs = {}
-- Armazena os assets carregados (sheets, quads) para cada tipo
AnimatedSpritesheet.assets = {}

-- Função auxiliar para cópia profunda de tabelas
local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

--- Carrega os spritesheets e gera os quads com base na configuração fornecida.
-- @param unitType String: O tipo de unidade (ex: "zombie_male_1").
-- @param config Table: Configuração da unidade, contendo:
--   - assetPaths (Table): Mapeia nomes de animação (ex: "walk", "death_die1") para caminhos de arquivo.
--     Ex: { walk = "path/to/walk.png", run = "path/to/run.png" }
--   - grids (Table): Mapeia nomes de animação para informações da grade.
--     Ex: { walk = { frameWidth=64, frameHeight=64, numAnimationFrames=8 }, ... }
--   - angles (Table): Lista de ângulos suportados, na ordem em que aparecem no spritesheet (de cima para baixo).
--     Ex: { 0, 45, 90, 135, 180, 225, 270, 315 }
--   - frameTimes (Table): Mapeia nomes de animação para o tempo entre frames.
--     Ex: { walk = 0.15, run = 0.10, death_die1 = 0.12 }
--   - defaultSpeed (Number, opcional): Velocidade padrão.
--   - origin (Table, opcional): {x, y} para o ponto de origem do desenho.
--   - instanceDefaults (Table, opcional): Padrões para novas instâncias.
function AnimatedSpritesheet.load(unitType, config)
    print(string.format("Iniciando carregamento de assets para: %s (AnimatedSpritesheet)", unitType))

    AnimatedSpritesheet.configs[unitType] = config
    local assets = {
        sheets = {},   -- Armazena as IMAGENS carregadas (love.graphics.newImage)
        quads = {},    -- Armazena os QUADS gerados
        maxFrames = {} -- Armazena o número máximo de frames por nome de animação
    }
    AnimatedSpritesheet.assets[unitType] = assets

    if not config.assetPaths or not config.grids or not config.angles or not config.frameTimes then
        print(string.format(
            "ERRO [%s]: Configuração incompleta para AnimatedSpritesheet. Faltando assetPaths, grids, angles ou frameTimes.",
            unitType))
        return
    end

    -- Itera sobre os nomes de animação definidos em assetPaths
    for animName, assetPath in pairs(config.assetPaths) do
        local gridInfo = config.grids[animName]
        if not gridInfo then
            print(string.format("AVISO [%s]: Informações de grid não encontradas para a animação '%s'. Pulando.",
                unitType, animName))
            goto continueAnimationLoop
        end

        if not gridInfo.frameWidth or not gridInfo.frameHeight or not gridInfo.numAnimationFrames then
            print(string.format(
                "AVISO [%s]: Informações de grid incompletas para '%s' (frameWidth, frameHeight, numAnimationFrames). Pulando.",
                unitType, animName))
            goto continueAnimationLoop
        end

        local success, sheetImg = pcall(function() return love.graphics.newImage(assetPath) end)
        if not success or not sheetImg then
            print(string.format("ERRO [%s]: Falha ao carregar imagem para '%s' em '%s'. Detalhe: %s", unitType, animName,
                assetPath, tostring(sheetImg)))
            goto continueAnimationLoop
        end

        assets.sheets[animName] = sheetImg -- Armazena a IMAGEM
        assets.quads[animName] = {}
        assets.maxFrames[animName] = gridInfo.numAnimationFrames

        local imgW, imgH = sheetImg:getWidth(), sheetImg:getHeight()

        -- Gera quads para cada ângulo e frame
        for rowIndex, angleValue in ipairs(config.angles) do
            assets.quads[animName][angleValue] = {}
            for frameIndex = 1, gridInfo.numAnimationFrames do
                local x = (frameIndex - 1) * gridInfo.frameWidth
                local y = (rowIndex - 1) * gridInfo.frameHeight -- rowIndex é 1-based de ipairs

                if x + gridInfo.frameWidth > imgW or y + gridInfo.frameHeight > imgH then
                    print(string.format(
                        "ERRO [%s]: Quad para '%s', angulo %s, frame %s (%s,%s) está fora dos limites da imagem (%sx%s).",
                        unitType, animName, angleValue, frameIndex, x, y, imgW, imgH))
                    assets.quads[animName][angleValue][frameIndex] = nil -- Ou um quad dummy
                else
                    assets.quads[animName][angleValue][frameIndex] = love.graphics.newQuad(x, y, gridInfo.frameWidth,
                        gridInfo.frameHeight, imgW, imgH)
                end
            end
        end
        ::continueAnimationLoop::
    end

    print(string.format("Carregamento de assets para %s (AnimatedSpritesheet) concluído.", unitType))
end

--- Retorna o ângulo mais próximo disponível na configuração da unidade.
-- @param unitType String: O tipo de unidade.
-- @param targetAngle Number: O ângulo desejado em graus.
-- @return Number: O ângulo configurado mais próximo.
function AnimatedSpritesheet.getClosestAngle(unitType, targetAngle)
    local config = AnimatedSpritesheet.configs[unitType]
    -- Retorna 0 se não houver configuração de ângulo ou se estiver vazia.
    if not config or not config.angles or #config.angles == 0 then return 0 end

    -- Otimização: Cálculo direto para ângulos uniformemente espaçados (ex: 8 direções)
    local numAngles = #config.angles
    if numAngles > 0 then
        local step = 360 / numAngles
        -- Adiciona metade do passo para arredondamento correto para o múltiplo mais próximo de 'step'.
        -- Ex: targetAngle=60, step=45. (60 + 22.5)/45 = 82.5/45 = 1.83. floor(1.83) = 1. 1*45 = 45.
        -- Ex: targetAngle=70, step=45. (70 + 22.5)/45 = 92.5/45 = 2.05. floor(2.05) = 2. 2*45 = 90.
        local roundedAngle = math.floor((targetAngle + step / 2) / step) * step

        -- Normaliza o ângulo para o intervalo [0, 360 - step]
        -- e garante que o resultado seja um dos ângulos definidos em config.angles
        -- Esta parte assume que os ângulos em config.angles são os múltiplos de 'step'.
        -- Se config.angles puder ter valores arbitrários, esta otimização não é diretamente aplicável
        -- e o loop original é mais seguro, ou uma busca mais complexa seria necessária.

        -- Para garantir que estamos retornando um valor que REALMENTE EXISTE em config.angles,
        -- e não apenas um múltiplo calculado de step (que deveria ser o mesmo se config.angles for regular),
        -- podemos fazer um lookup rápido. No entanto, se config.angles é garantido ser [0, 45, ..., 315],
        -- então roundedAngle % 360 é suficiente.

        -- Se config.angles é [0, 45, 90, 135, 180, 225, 270, 315]
        -- E numAngles = 8, step = 45.
        -- O resultado de roundedAngle % 360 estará correto.
        local finalAngle = roundedAngle % 360

        -- Opcional: Se você precisar ter certeza absoluta que o ângulo retornado está na tabela config.angles
        -- (por exemplo, se config.angles pudesse ser algo como [0, 40, 95, ...]), então o loop original é mais robusto.
        -- Mas para o caso comum de 8 direções, isso deve funcionar.
        -- Para ser ainda mais robusto e ainda evitar o loop principal na maioria das vezes:
        -- local angleIndex = (math.floor((targetAngle + step / 2) / step) % numAngles) + 1
        -- return config.angles[angleIndex] -- Isso retornaria o valor exato da tabela config.angles

        return finalAngle -- Mantendo simples, assumindo que os ângulos são múltiplos regulares de step.
    end

    -- Fallback para o método original se algo der errado ou numAngles for 0 (embora já verificado)
    -- Este bloco de fallback pode ser removido se a otimização acima for considerada robusta para todos os casos.
    local minDiff = 361
    local closestAngle = config.angles[1] -- Já verificado que config.angles existe e não é vazio

    for _, angle in ipairs(config.angles) do
        local diff = math.abs(targetAngle - angle)
        if diff > 180 then
            diff = 360 - diff -- Considera a natureza cíclica dos ângulos (ex: 350 é próximo de 10)
        end
        if diff < minDiff then
            minDiff = diff
            closestAngle = angle
        end
    end
    return closestAngle
end

--- Atualiza a animação da instância.
--- @param unitType string: O tipo de unidade.
--- @param instanceAnimConfig table: A configuração de animação da instância (anteriormente instanceConfig).
--- @param dt number: Delta time.
--- @param targetPosition table|nil (opcional): {x, y} Posição do alvo para movimento e direção.
--- @return boolean: True se a animação de morte terminou, false caso contrário.
function AnimatedSpritesheet.update(unitType, instanceAnimConfig, dt, targetPosition) -- instanceAnimConfig é o self.sprite do inimigo
    local assets = AnimatedSpritesheet.assets[unitType]
    local baseConfig = AnimatedSpritesheet.configs[unitType]
    if not assets or not baseConfig or not instanceAnimConfig then -- Verifique instanceAnimConfig também
        print(string.format(
            "ERRO [%s]: Tentando atualizar animação para tipo não carregado ou config de instância nula.", unitType))
        return false
    end

    local anim = instanceAnimConfig.animation -- Atalho para a sub-tabela de animação
    local currentAnimationKey

    if anim.isDead then
        if not anim.chosenDeathType then -- Se está morto mas nenhum tipo de morte foi escolhido
            -- print(string.format("AVISO [%s]: Unidade morta mas chosenDeathType não definido.", unitType))
            return true                  -- Considera terminada
        end
        currentAnimationKey = anim.chosenDeathType
    else
        currentAnimationKey = anim.activeMovementType
    end

    if not currentAnimationKey or not assets.maxFrames[currentAnimationKey] then
        -- print(string.format("AVISO [%s]: Animação '%s' não encontrada ou sem frames. Unidade: %s", unitType, tostring(currentAnimationKey), unitType))
        if anim.isDead then return true end
        return false
    end

    local frameTime = (baseConfig.frameTimes and baseConfig.frameTimes[currentAnimationKey]) or 0.15
    local maxFrames = assets.maxFrames[currentAnimationKey] or 0

    if maxFrames == 0 then
        if anim.isDead then return true end
        return false
    end

    if anim.isDead then
        anim.timer = anim.timer + dt
        local animationFinished = false
        while anim.timer >= frameTime do
            anim.timer = anim.timer - frameTime
            if anim.currentFrame < maxFrames then
                anim.currentFrame = anim.currentFrame + 1
            else
                animationFinished = true
                break
            end
        end
        return animationFinished
    end

    local dx, dy, length = 0, 0, 0
    local isMoving = false
    if targetPosition then
        dx = targetPosition.x - instanceAnimConfig.position.x
        dy = targetPosition.y - instanceAnimConfig.position.y
        length = math.sqrt(dx * dx + dy * dy)

        local movementThreshold = baseConfig.movementThreshold or 1 -- Pegar da config base do TIPO
        if length > movementThreshold then
            isMoving = true
            local angleRad = math.atan2(dy, dx)
            local angleDeg = angleRad * (180 / math.pi)
            if angleDeg < 0 then angleDeg = angleDeg + 360 end

            if baseConfig.angleOffset then -- Pegar da config base do TIPO
                angleDeg = (angleDeg + baseConfig.angleOffset) % 360
            end
            anim.direction = AnimatedSpritesheet.getClosestAngle(unitType, angleDeg)
        end
    end

    -- Animações como 'idle' ou 'taunt' devem ser executadas mesmo se a entidade estiver parada.
    local alwaysAnimate = (currentAnimationKey == 'idle' or currentAnimationKey == 'taunt')

    if isMoving or alwaysAnimate then
        anim.timer = anim.timer + dt
        while anim.timer >= frameTime do
            anim.timer = anim.timer - frameTime
            anim.currentFrame = anim.currentFrame + 1
            if anim.currentFrame > maxFrames then
                anim.currentFrame = 1
            end
        end
    else
        if baseConfig.resetFrameOnStop then -- Pegar da config base do TIPO
            anim.currentFrame = 1
        end
        anim.timer = 0
    end
    return false
end

--- Cria uma nova configuração de instância de animação.
-- @param unitType String: O tipo de unidade.
-- @param overrides Table (opcional): Valores para sobrescrever os padrões.
-- @return Table: A configuração da nova instância de animação.
function AnimatedSpritesheet.newConfig(unitType, overrides)
    local config = deepcopy(AnimatedSpritesheet.defaultInstanceConfig) -- Começa com o padrão global do AnimatedSpritesheet
    local baseUnitConfig = AnimatedSpritesheet.configs
        [unitType]                                                     -- Configurações carregadas para este unitType específico

    -- 1. Sobrescreve com os padrões definidos em `instanceDefaults` DENTRO da config do unitType
    if baseUnitConfig and baseUnitConfig.instanceDefaults then
        for k, v in pairs(baseUnitConfig.instanceDefaults) do
            if type(v) == "table" and type(config[k]) == "table" then
                for k2, v2 in pairs(v) do
                    if type(v2) == "table" and type(config[k][k2]) == "table" then
                        for k3, v3 in pairs(v2) do config[k][k2][k3] = v3 end
                    elseif config[k][k2] ~= nil then
                        config[k][k2] = v2
                    end
                end
            elseif config[k] ~= nil then
                config[k] = v
            end
        end
    end

    -- 2. Garante um activeMovementType inicial se não foi definido pelos overrides ou instanceDefaults
    if baseUnitConfig and baseUnitConfig.assetPaths and not config.animation.activeMovementType then
        if baseUnitConfig.assetPaths.walk then
            config.animation.activeMovementType = 'walk'
        else
            for animKey, _ in pairs(baseUnitConfig.assetPaths) do
                if not string.match(animKey, "^death_") then
                    config.animation.activeMovementType = animKey
                    break
                end
            end
        end
    end

    -- 3. Aplica overrides específicos fornecidos ao criar a instância (ex: posição inicial)
    if overrides then
        for k, v in pairs(overrides) do
            if type(v) == "table" and type(config[k]) == "table" then
                for k2, v2 in pairs(v) do
                    if type(v2) == "table" and type(config[k][k2]) == "table" then
                        if config[k][k2] then
                            for k3, v3 in pairs(v2) do config[k][k2][k3] = v3 end
                        else
                            config[k][k2] = deepcopy(v2)
                        end
                    elseif config[k][k2] ~= nil then
                        config[k][k2] = v2
                    elseif k == "position" and k2 == "x" then -- Caso especial para position x,y direto
                        config.position.x = v2
                    elseif k == "position" and k2 == "y" then
                        config.position.y = v2
                    end
                end
            elseif k == "position" and type(v) == 'table' then -- Se overrides.position = {x=_, y=_}
                config.position.x = v.x or config.position.x
                config.position.y = v.y or config.position.y
            elseif config[k] ~= nil then
                config[k] = v
            end
        end
    end

    if baseUnitConfig and baseUnitConfig.angles and #baseUnitConfig.angles > 0 then
        config.animation.direction = AnimatedSpritesheet.getClosestAngle(unitType, config.animation.direction or 0)
    else
        config.animation.direction = 0 -- Fallback se não houver ângulos configurados
    end

    return config
end

--- Inicia a animação de morte para a instância.
-- @param unitType String: O tipo de unidade.
-- @param instanceAnimConfig Table: A configuração de animação da instância.
function AnimatedSpritesheet.startDeath(unitType, instanceAnimConfig)
    local anim = instanceAnimConfig.animation
    if anim.isDead then return end

    local baseConfig = AnimatedSpritesheet.configs[unitType]
    local assets = AnimatedSpritesheet.assets[unitType]
    if not baseConfig or not assets or not instanceAnimConfig then return end

    anim.isDead = true
    anim.currentFrame = 1
    anim.timer = 0

    local availableDeathAnimations = {}
    if baseConfig.assetPaths and assets.maxFrames then
        for animName, _ in pairs(baseConfig.assetPaths) do
            if string.sub(animName, 1, 6) == "death_" and assets.maxFrames[animName] and assets.maxFrames[animName] > 0 then
                table.insert(availableDeathAnimations, animName)
            end
        end
    end

    if #availableDeathAnimations > 0 then
        anim.chosenDeathType = availableDeathAnimations[love.math.random(#availableDeathAnimations)]
    else
        anim.chosenDeathType = nil
    end
end

--- Define o tipo de animação de movimento ativa.
-- @param instanceAnimConfig Table: A configuração de animação da instância.
-- @param newMovementType String: O novo tipo de movimento.
-- @param unitType String (opcional): Para validação.
function AnimatedSpritesheet.setMovementType(instanceAnimConfig, newMovementType, unitType)
    if not instanceAnimConfig or not instanceAnimConfig.animation then return end
    local anim = instanceAnimConfig.animation

    if unitType then
        local assets = AnimatedSpritesheet.assets[unitType]
        if not assets or not assets.sheets or not assets.sheets[newMovementType] then
            print(string.format("AVISO [%s]: Tentativa de definir movimento para animação não carregada: %s", unitType,
                newMovementType))
            return
        end
    end

    if anim.activeMovementType ~= newMovementType then
        anim.activeMovementType = newMovementType
        anim.currentFrame = 1
        anim.timer = 0
    end
end

--- Adiciona o frame atual da unidade a um SpriteBatch fornecido.
-- @param unitType String: O tipo de unidade.
-- @param instanceAnimConfig Table: A configuração de animação da instância (o self.sprite do inimigo).
-- @param spriteBatch love.SpriteBatch: O SpriteBatch ao qual adicionar o sprite.
-- @return Boolean: True se adicionado com sucesso, false caso contrário.
function AnimatedSpritesheet.addToBatch(unitType, instanceAnimConfig, spriteBatch)
    local assets = AnimatedSpritesheet.assets[unitType]
    local baseConfig = AnimatedSpritesheet.configs[unitType] -- Config base do TIPO de unidade

    if not assets or not baseConfig or not instanceAnimConfig or not spriteBatch then
        -- print("AnimatedSpritesheet.addToBatch: Argumentos inválidos ou assets não carregados.")
        return false
    end

    local animState = instanceAnimConfig.animation -- A sub-tabela de animação da instância
    local currentAnimationKey

    if animState.isDead then
        currentAnimationKey = animState.chosenDeathType
    else
        currentAnimationKey = animState.activeMovementType
    end

    if not currentAnimationKey then
        return false
    end

    if not assets.sheets[currentAnimationKey] then -- Verifica se a IMAGEM para esta animação foi carregada
        -- print(string.format("AVISO [%s]: Textura para animação '%s' não carregada.", unitType, currentAnimationKey))
        return false
    end

    if assets.sheets[currentAnimationKey] ~= spriteBatch:getTexture() then
        print(string.format(
            "ERRO FATAL [%s]: Textura do SpriteBatch não corresponde à textura da animação atual ('%s').", unitType,
            currentAnimationKey))
        return false
    end

    local quadsForAnimation = assets.quads[currentAnimationKey]
    local maxFramesForCurrentAnim = assets.maxFrames[currentAnimationKey]

    if not quadsForAnimation or not maxFramesForCurrentAnim or maxFramesForCurrentAnim == 0 then
        return false
    end

    local angleToDraw = animState.direction
    local quadsForAngle = quadsForAnimation[angleToDraw]

    if not quadsForAngle then
        return false
    end

    local frameToDraw = animState.currentFrame
    if frameToDraw > maxFramesForCurrentAnim or frameToDraw <= 0 then
        frameToDraw = 1
        animState.currentFrame = 1
    end

    local quad = quadsForAngle[frameToDraw]

    if not quad then
        return false
    end

    local ox, oy
    if baseConfig.origin then
        ox = baseConfig.origin.x
        oy = baseConfig.origin.y
    else
        local _, _, q_w, q_h = quad:getViewport()
        ox = q_w / 2
        oy = q_h / 2
    end

    spriteBatch:add(quad, instanceAnimConfig.position.x, instanceAnimConfig.position.y, 0, instanceAnimConfig.scale,
        instanceAnimConfig.scale, ox, oy)
    return true
end

return AnimatedSpritesheet
