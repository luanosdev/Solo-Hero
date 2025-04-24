-- Módulo de animação genérico para personagens
local AnimatedCharacter = {}

-- Estrutura de configuração padrão (alguns valores serão sobrescritos no load)
AnimatedCharacter.defaultInstanceConfig = {
    position = { x = 0, y = 0 },
    scale = 1.0,
    speed = 50,
    animation = {
        currentFrame = 1,
        timer = 0,
        frameTime = 0.15, -- Tempo padrão entre frames de "walk"
        direction = 0,
        state = 'walk',   -- walk, die1, die2, etc.
        isDead = false,
        deathFrameTime = 0.12, -- Tempo padrão entre frames de morte
        deathType = 'die1'     -- Tipo de morte padrão
    }
}

-- Armazena as configurações carregadas para cada tipo de personagem
AnimatedCharacter.configs = {}
-- Armazena os assets carregados (sheets, quads) para cada tipo
AnimatedCharacter.assets = {}

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

-- Carrega os spritesheets e gera os quads com base na configuração fornecida
-- config: Tabela com detalhes do personagem (assetPaths, grid, angles, etc.)
function AnimatedCharacter.load(characterType, config)
    print(string.format("Iniciando carregamento dos sprites para: %s", characterType))

    -- Armazena a configuração para uso posterior (update, draw, etc.)
    AnimatedCharacter.configs[characterType] = config
    -- Inicializa a estrutura de assets para este tipo
    local assets = {
        bodySheets = {},
        shadowSheets = {},
        bodyQuads = {},
        shadowQuads = {},
        maxFrames = {} -- Armazena o número máximo de frames por estado/tipo
    }
    AnimatedCharacter.assets[characterType] = assets

    -- Define os estados de animação baseados na configuração (ex: walk, die1, die2)
    local animationStates = {}
    if config.assetPaths.walk then animationStates.walk = config.grid.walk end
    if config.assetPaths.death then
        for deathType, pathPattern in pairs(config.assetPaths.death) do
            if config.grid.death and config.grid.death[deathType] then
                animationStates['death_' .. deathType] = config.grid.death[deathType] -- Prefixo para evitar conflito
            else
                 print(string.format("AVISO [%s]: Grid não definida para o tipo de morte '%s'", characterType, deathType))
            end
        end
    end

    -- Itera sobre os estados definidos para carregar assets
    for stateName, gridInfo in pairs(animationStates) do
        local isDeathState = string.sub(stateName, 1, 6) == 'death_'
        local actualState = isDeathState and 'death' or stateName -- "death"
        local deathType = isDeathState and stateName:sub(7) or nil -- "die1", "die2", etc. or nil

        -- Estrutura aninhada para assets
        if not assets.bodySheets[actualState] then
            assets.bodySheets[actualState] = {}
            assets.shadowSheets[actualState] = {}
            assets.bodyQuads[actualState] = {}
            assets.shadowQuads[actualState] = {}
            assets.maxFrames[actualState] = {}
        end
        if isDeathState then
             if not assets.bodySheets.death[deathType] then
                assets.bodySheets.death[deathType] = {}
                assets.shadowSheets.death[deathType] = {}
                assets.bodyQuads.death[deathType] = {}
                assets.shadowQuads.death[deathType] = {}
             end
        end

        -- Determina o padrão de path para o estado atual
        local pathPatternConfig = config.assetPaths[actualState]
        local pathPatternBody, pathPatternShadow
        if isDeathState and pathPatternConfig then
             pathPatternBody = pathPatternConfig[deathType] and pathPatternConfig[deathType].body
             pathPatternShadow = pathPatternConfig[deathType] and pathPatternConfig[deathType].shadow
        elseif pathPatternConfig then
             pathPatternBody = pathPatternConfig.body
             pathPatternShadow = pathPatternConfig.shadow
        end

        if not pathPatternBody then
             print(string.format("ERRO [%s]: Padrão de path do corpo não encontrado para estado '%s'%s",
                                 characterType, actualState, deathType and (" tipo '"..deathType.."'") or ""))
            goto continueStateLoop -- Pula para o próximo estado se o path do corpo não existir
        end

        -- Carrega assets para cada ângulo
        for _, angle in ipairs(config.angles) do
            local angleStr = string.format("%03d", angle)
            local bodyPath = string.format(pathPatternBody, angleStr)
            local shadowPath = pathPatternShadow and string.format(pathPatternShadow, angleStr)

            -- Carrega Imagem do Corpo
            local successBody, bodyImg = pcall(function() return love.graphics.newImage(bodyPath) end)
            if successBody then
                local imgW, imgH = bodyImg:getWidth(), bodyImg:getHeight()
                local frameW = imgW / gridInfo.cols
                local frameH = imgH / gridInfo.rows
                local totalFrames = gridInfo.cols * gridInfo.rows

                -- Armazena sheet e inicializa quads
                local bodySheetTarget = isDeathState and assets.bodySheets.death[deathType] or assets.bodySheets.walk
                local bodyQuadTarget = isDeathState and assets.bodyQuads.death[deathType] or assets.bodyQuads.walk
                local maxFramesTarget = isDeathState and assets.maxFrames.death or assets.maxFrames.walk

                bodySheetTarget[angle] = bodyImg
                bodyQuadTarget[angle] = {}

                -- Define maxFrames (usa o último carregado, devem ser todos iguais)
                 if isDeathState then
                    assets.maxFrames.death[deathType] = totalFrames
                 else
                    assets.maxFrames.walk = totalFrames
                 end

                -- Cria Quads
                for row = 0, gridInfo.rows - 1 do
                    for col = 0, gridInfo.cols - 1 do
                        local frame = row * gridInfo.cols + col + 1
                        bodyQuadTarget[angle][frame] = love.graphics.newQuad(col * frameW, row * frameH, frameW, frameH, imgW, imgH)
                    end
                end
            else
                print(string.format("Erro ao carregar corpo %s [%s] Ang %s: %s", stateName, characterType, angleStr, bodyPath))
            end

            -- Carrega Imagem da Sombra (se existir path)
            if shadowPath then
                 local successShadow, shadowImg = pcall(function() return love.graphics.newImage(shadowPath) end)
                 if successShadow then
                    local imgW, imgH = shadowImg:getWidth(), shadowImg:getHeight()
                    local frameW = imgW / gridInfo.cols
                    local frameH = imgH / gridInfo.rows

                    -- Armazena sheet e inicializa quads
                    local shadowSheetTarget = isDeathState and assets.shadowSheets.death[deathType] or assets.shadowSheets.walk
                    local shadowQuadTarget = isDeathState and assets.shadowQuads.death[deathType] or assets.shadowQuads.walk

                    shadowSheetTarget[angle] = shadowImg
                    shadowQuadTarget[angle] = {}

                    -- Cria Quads da Sombra
                    for row = 0, gridInfo.rows - 1 do
                        for col = 0, gridInfo.cols - 1 do
                            local frame = row * gridInfo.cols + col + 1
                            shadowQuadTarget[angle][frame] = love.graphics.newQuad(col * frameW, row * frameH, frameW, frameH, imgW, imgH)
                        end
                    end
                 else
                    -- Aviso apenas se o arquivo realmente deveria existir (evita avisos para padrões opcionais)
                     if not shadowPath:match("Shadow_") then -- Heurística simples
                        print(string.format("Aviso/Erro ao carregar sombra %s [%s] Ang %s: %s", stateName, characterType, angleStr, shadowPath))
                     end
                 end
            end
        end
        ::continueStateLoop:: -- Label para goto
    end

    print(string.format("Carregamento de sprites para %s concluído.", characterType))
end

-- Função para pegar o ângulo mais próximo disponível
function AnimatedCharacter.getClosestAngle(characterType, angle)
    local config = AnimatedCharacter.configs[characterType]
    if not config or not config.angles then return 0 end -- Retorna 0 se não configurado

    local minDiff, closest = 360, config.angles[1] or 0 -- Default para o primeiro ângulo ou 0
    for _, a in ipairs(config.angles) do
        local diff = math.abs(((angle - a + 180) % 360) - 180)
        if diff < minDiff then
            minDiff = diff
            closest = a
        end
    end
    return closest
end

-- Atualiza a animação
-- instanceConfig: A configuração da instância específica (com estado atual, posição, etc.)
-- dt: Delta time
-- targetPosition: Posição do alvo (opcional, para movimento e direção)
-- Retorna true se a animação de morte terminou, false caso contrário
function AnimatedCharacter.update(characterType, instanceConfig, dt, targetPosition)
    local assets = AnimatedCharacter.assets[characterType]
    local baseConfig = AnimatedCharacter.configs[characterType] -- Configuração base carregada
    if not assets or not baseConfig then
        print("ERRO: Tentando atualizar animação para tipo não carregado:", characterType)
        return false
    end

    local anim = instanceConfig.animation -- Atalho para a tabela de animação da instância

    -- Lógica de Animação de Morte
    if anim.isDead then
        anim.state = 'death' -- Garante que o estado seja 'death'
        anim.timer = anim.timer + dt

        local frameTime = anim.deathFrameTime or baseConfig.defaultDeathFrameTime or 0.12
        local deathType = anim.deathType or 'die1'
        local maxFrames = (assets.maxFrames.death and assets.maxFrames.death[deathType]) or 0

        if maxFrames == 0 then
            print(string.format("AVISO [%s]: Animação de morte tipo '%s' não tem frames carregados.", characterType, deathType))
            return true -- Considera 'terminada' se não há frames
        end

        local animationFinished = false
        while anim.timer >= frameTime do -- Loop para caso dt seja muito grande
            anim.timer = anim.timer - frameTime
            if anim.currentFrame < maxFrames then
                anim.currentFrame = anim.currentFrame + 1
            else
                 animationFinished = true -- Chegou ao último frame
                 -- Mantém no último frame, não reseta o timer aqui
                 break -- Sai do loop while
            end
        end
        return animationFinished -- Retorna true se chegou ao último frame
    end

    -- Lógica de Movimento e Animação Normal (ex: walk)
    local dx, dy, length = 0, 0, 0
    local move = false
    if targetPosition then
        dx = targetPosition.x - instanceConfig.position.x
        dy = targetPosition.y - instanceConfig.position.y
        length = math.sqrt(dx*dx + dy*dy)

        -- Move apenas se a distância for maior que um pequeno limiar
        if length > (baseConfig.movementThreshold or 1) then
            move = true
            local angleRad = math.atan2(dy, dx)
            local angleDeg = angleRad * (180 / math.pi)
            if angleDeg < 0 then angleDeg = angleDeg + 360 end

            -- Ajuste de 90 graus se necessário (configurável)
            if baseConfig.angleOffset then
                 angleDeg = (angleDeg + baseConfig.angleOffset) % 360
            end

            anim.direction = AnimatedCharacter.getClosestAngle(characterType, angleDeg)

            -- Movimento
            local speed = instanceConfig.speed or baseConfig.defaultSpeed or 50
            local moveDx = dx / length * speed * dt
            local moveDy = dy / length * speed * dt
            instanceConfig.position.x = instanceConfig.position.x + moveDx
            instanceConfig.position.y = instanceConfig.position.y + moveDy
        end
    end

    -- Atualiza frame da animação de 'walk' (ou estado ativo não-morte)
    anim.state = 'walk' -- Assume 'walk' se não estiver morto (pode ser expandido)
    local currentWalkState = 'walk' -- Poderia ser 'run', 'idle' etc. no futuro
    local maxFrames = assets.maxFrames[currentWalkState] or 1

    if move then
        anim.timer = anim.timer + dt
        local frameTime = anim.frameTime or baseConfig.defaultFrameTime or 0.15
        while anim.timer >= frameTime do
            anim.timer = anim.timer - frameTime
            anim.currentFrame = anim.currentFrame + 1
            if anim.currentFrame > maxFrames then
                anim.currentFrame = 1 -- Volta ao primeiro frame
            end
        end
    else
        -- Se parado, pode resetar para o frame 1 ou manter o último
        if baseConfig.resetFrameOnStop then
            anim.currentFrame = 1
        end
        anim.timer = 0 -- Reseta o timer se parado
    end

    return false -- Animação de walk/idle nunca "termina" no sentido da morte
end


-- Desenha o Personagem (sombra + corpo)
function AnimatedCharacter.draw(characterType, instanceConfig)
    local assets = AnimatedCharacter.assets[characterType]
    local baseConfig = AnimatedCharacter.configs[characterType]
    if not assets or not baseConfig then return end -- Não desenha se não carregado

    local anim = instanceConfig.animation
    local angle = anim.direction
    local frame = anim.currentFrame
    local state = anim.state
    local deathType = anim.deathType -- Usado apenas se state == 'death'

    local sheetTableShadow, quadTableShadow
    local sheetTableBody, quadTableBody
    local maxFrames = 1

    -- Determina quais tabelas de assets usar
    if state == 'death' then
        if assets.shadowSheets.death and assets.shadowSheets.death[deathType] then
            sheetTableShadow = assets.shadowSheets.death[deathType]
            quadTableShadow = assets.shadowQuads.death[deathType]
        end
        if assets.bodySheets.death and assets.bodySheets.death[deathType] then
            sheetTableBody = assets.bodySheets.death[deathType]
            quadTableBody = assets.bodyQuads.death[deathType]
            maxFrames = assets.maxFrames.death and assets.maxFrames.death[deathType] or 1
        end
    else -- Assume 'walk' ou outro estado não-morte
        state = 'walk' -- Garante que 'state' seja um índice válido (simplificação por agora)
         if assets.shadowSheets[state] then
             sheetTableShadow = assets.shadowSheets[state]
             quadTableShadow = assets.shadowQuads[state]
         end
         if assets.bodySheets[state] then
            sheetTableBody = assets.bodySheets[state]
            quadTableBody = assets.bodyQuads[state]
            maxFrames = assets.maxFrames[state] or 1
         end
    end

    -- Valida o frame atual para evitar erros de índice
    if frame > maxFrames then
         print(string.format("AVISO [%s]: Frame %d excede maxFrames %d para estado %s%s. Resetando para 1.",
                            characterType, frame, maxFrames, state, deathType and "/"..deathType or ""))
         frame = 1
         anim.currentFrame = 1 -- Corrige na instância também
    end

    -- Desenha a Sombra (se existir e for configurado)
    local drawShadow = baseConfig.drawShadow == nil or baseConfig.drawShadow -- Default true
    if drawShadow and sheetTableShadow and quadTableShadow and sheetTableShadow[angle] and quadTableShadow[angle] and quadTableShadow[angle][frame] then
        local sheet = sheetTableShadow[angle]
        local quad = quadTableShadow[angle][frame]
        if type(quad) == 'userdata' then
            local ox = baseConfig.origin and baseConfig.origin.x or (quad:getViewport()[3] / 2) -- Centro X do quad
            local oy = baseConfig.origin and baseConfig.origin.y or (quad:getViewport()[4] / 2) -- Centro Y do quad
            local shadowColor = baseConfig.shadowColor or {0, 0, 0, 0.4}
            love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowColor[4])
            love.graphics.draw(
                sheet, quad,
                instanceConfig.position.x, instanceConfig.position.y,
                0, -- Rotação (geralmente 0)
                instanceConfig.scale, instanceConfig.scale,
                ox, oy
            )
        else
            print(string.format("!!! Draw Shadow Error: Expected userdata quad, got %s for %s angle %s, frame %s", type(quad), characterType, angle, frame))
        end
    end

    -- Desenha o Corpo
    if sheetTableBody and quadTableBody and sheetTableBody[angle] and quadTableBody[angle] and quadTableBody[angle][frame] then
        local sheet = sheetTableBody[angle]
        local quad = quadTableBody[angle][frame]
        if type(quad) == 'userdata' then
             local ox = baseConfig.origin and baseConfig.origin.x or (quad:getViewport()[3] / 2) -- Centro X do quad
             local oy = baseConfig.origin and baseConfig.origin.y or (quad:getViewport()[4] / 2) -- Centro Y do quad
            love.graphics.setColor(1, 1, 1, 1) -- Cor normal
            love.graphics.draw(
                sheet, quad,
                instanceConfig.position.x, instanceConfig.position.y,
                0,
                instanceConfig.scale, instanceConfig.scale,
                ox, oy
            )
        else
            print(string.format("!!! Draw Body Error: Expected userdata quad, got %s for %s angle %s, frame %s", type(quad), characterType, angle, frame))
            -- Desenha um placeholder
            love.graphics.setColor(1, 0, 1, 1)
            love.graphics.rectangle("fill", instanceConfig.position.x - 10 * instanceConfig.scale, instanceConfig.position.y - 10 * instanceConfig.scale, 20 * instanceConfig.scale, 20 * instanceConfig.scale)
        end
    else
         print(string.format("!!! Draw Body Error: Quad not found for %s state=%s, angle=%s, frame=%s", characterType, state, angle, frame))
        -- Desenha um placeholder
        love.graphics.setColor(1, 0, 1, 1)
        love.graphics.rectangle("fill", instanceConfig.position.x - 10 * instanceConfig.scale, instanceConfig.position.y - 10 * instanceConfig.scale, 20 * instanceConfig.scale, 20 * instanceConfig.scale)
    end
end

-- Cria uma nova configuração de instância, baseada no padrão e com overrides
function AnimatedCharacter.newConfig(characterType, overrides)
    local config = deepcopy(AnimatedCharacter.defaultInstanceConfig) -- Começa com o padrão genérico
    local baseConfig = AnimatedCharacter.configs[characterType]

    -- Sobrescreve com padrões específicos do characterType (se existirem)
    if baseConfig and baseConfig.instanceDefaults then
        for k, v in pairs(baseConfig.instanceDefaults) do
             if type(v) == "table" and config[k] then
                 for k2, v2 in pairs(v) do
                     if type(v2) == "table" and config[k][k2] then -- Nível 2 (ex: animation)
                         for k3, v3 in pairs(v2) do config[k][k2][k3] = v3 end
                     else
                         config[k][k2] = v2
                     end
                 end
             else
                 config[k] = v
             end
        end
    end

    -- Aplica overrides específicos da instância
    if overrides then
        for k, v in pairs(overrides) do
            if type(v) == "table" and config[k] then -- Merge tabelas (nível 1)
                for k2, v2 in pairs(v) do
                     if type(v2) == "table" and config[k][k2] then -- Merge tabelas (nível 2, ex: animation, position)
                          if config[k][k2] then -- Garante que a sub-tabela exista
                            for k3, v3 in pairs(v2) do
                                config[k][k2][k3] = v3
                            end
                          else
                             config[k][k2] = deepcopy(v2) -- Cria a sub-tabela se não existir
                          end
                     elseif config[k][k2] ~= nil then -- Sobrescreve valor simples se a chave existir
                        config[k][k2] = v2
                     end
                end
            elseif config[k] ~= nil then -- Sobrescreve valor simples se a chave existir
                config[k] = v
            end
        end
    end

     -- Garante que a posição seja uma tabela separada se veio de overrides como tabela simples
    if overrides and overrides.position and type(overrides.position) == 'table' then
        config.position = { x = overrides.position.x or config.position.x, y = overrides.position.y or config.position.y }
    end


    return config
end

-- Inicia a animação de morte
function AnimatedCharacter.startDeath(characterType, instanceConfig)
    local anim = instanceConfig.animation
    if anim.isDead then return end -- Já está morrendo

    local baseConfig = AnimatedCharacter.configs[characterType]
    local assets = AnimatedCharacter.assets[characterType]
    if not baseConfig or not assets or not assets.maxFrames.death then
         print(string.format("ERRO [%s]: Impossível iniciar morte, assets ou config não carregados.", characterType))
         return
    end

    anim.isDead = true
    anim.state = 'death'
    anim.currentFrame = 1 -- Começa do frame 1 da morte
    anim.timer = 0

    -- Escolhe um tipo de morte aleatório entre os disponíveis que têm frames
    local availableDeathTypes = {}
    for dType, maxF in pairs(assets.maxFrames.death) do
        if maxF and maxF > 0 then
             table.insert(availableDeathTypes, dType)
        end
    end

    if #availableDeathTypes > 0 then
        local randomIndex = love.math.random(#availableDeathTypes)
        anim.deathType = availableDeathTypes[randomIndex]
        print(string.format("[%s] Animação de morte escolhida: %s", characterType, anim.deathType))
    else
         print(string.format("AVISO [%s]: Nenhuma animação de morte com frames encontrada. Usando fallback.", characterType))
         anim.deathType = 'die1' -- Fallback
         -- Considera a animação terminada imediatamente se não há frames?
         -- Ou deixa o update/draw falhar/mostrar placeholder?
    end
end

return AnimatedCharacter 