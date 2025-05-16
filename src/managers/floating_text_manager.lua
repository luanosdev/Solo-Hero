local FloatingText = require("src.entities.floating_text")
local Camera = require("src.config.camera")
local colors = require("src.ui.colors")

--- Gerencia a criação, atualização e desenho de todos os textos flutuantes no jogo.
--- Implementa um sistema de empilhamento/atraso para textos no mesmo alvo.
---@class FloatingTextManager
local FloatingTextManager = {
    texts = {},
    ---@type table<any, {count: number, lastSpawnTime: number}>
    --- Registra a contagem de textos ativos e o tempo do último spawn por alvo
    --- para gerenciar o atraso e o deslocamento de empilhamento.
    activeTargetInfo = {},
    TEXT_DELAY_INTERVAL = 0.15, -- Intervalo de atraso entre textos empilhados (segundos)
    TEXT_STACK_OFFSET_Y = 10    -- Deslocamento vertical entre textos empilhados (pixels)
}

--- Inicializa o gerenciador de texto flutuante.
function FloatingTextManager:init()
    self.texts = {}
    self.activeTargetInfo = {}
end

--- Atualiza todos os textos flutuantes ativos.
--- Remove textos que expiraram e gerencia a contagem de textos por alvo.
---@param dt number O tempo delta desde a última atualização.
function FloatingTextManager:update(dt)
    local currentTime = love.timer.getTime() -- Usado para verificar expiração de activeTargetInfo
    -- Atualiza e remove textos mortos
    for i = #self.texts, 1, -1 do
        local textInstance = self.texts[i]
        if not textInstance:update(dt) then
            -- Se o texto expirou, e ele tinha um alvo, decrementa a contagem para esse alvo.
            if textInstance.targetPosition and self.activeTargetInfo[textInstance.targetPosition] then
                self.activeTargetInfo[textInstance.targetPosition].count = self.activeTargetInfo
                    [textInstance.targetPosition].count - 1
                if self.activeTargetInfo[textInstance.targetPosition].count <= 0 then
                    self.activeTargetInfo[textInstance.targetPosition] = nil -- Limpa se não houver mais textos ativos para este alvo
                end
            end
            table.remove(self.texts, i)
        end
    end

    -- Limpa entradas antigas em activeTargetInfo (opcional, mas bom para higiene)
    -- Se um alvo não tem texto por um tempo, sua entrada pode ser removida.
    -- Isso é mais complexo de gerenciar perfeitamente sem saber quando um "combate" termina.
    -- A lógica atual de decrementar no fim do texto deve ser suficiente.
end

--- Desenha todos os textos flutuantes ativos.
function FloatingTextManager:draw()
    if #self.texts > 0 then
        local firstText = self.texts[1]
        if firstText and firstText.position then
            print(string.format("  - Primeiro texto: '%s' em (%.2f, %.2f), Alpha: %.2f, Delay: %.2f",
                firstText.text, firstText.position.x, firstText.position.y, firstText.alpha,
                firstText.initialDelay or 0))
        end

        -- O DESENHO AGORA É FEITO DIRETAMENTE PELO MANAGER
        for _, textInstance in ipairs(self.texts) do
            textInstance:draw()
        end
    end
end

--- Adiciona um texto flutuante genérico.
--- Calcula o atraso e o deslocamento de empilhamento se necessário.
---@param factoryFunction function A função fábrica de FloatingText (ex: FloatingText.newEnemyDamage).
---@param worldPosition {x: number, y: number} Posição {x, y} inicial do texto NO MUNDO.
---@param textContent string O conteúdo do texto.
---@param targetEntity table|nil O objeto alvo (ex: inimigo, jogador).
---@param propsForFactory table Tabela de propriedades que será passada para a factoryFunction.
---                          Esta tabela é o último argumento da factory (geralmente chamado 'props').
function FloatingTextManager:_addTextInternal(factoryFunction, worldPosition, textContent, targetEntity, propsForFactory)
    local initialDelay = 0
    local initialStackOffsetY = 0
    local stackOffsetX = 0
    local targetPositionRef = targetEntity and targetEntity.position -- Usado para a chave do activeTargetInfo
    local targetNameForLog = (targetEntity and targetEntity.name) or
        (targetEntity and "id_" .. tostring(targetEntity.id)) or "UnknownTarget_FTM"

    -- DEBUG: Log da posição inicial fornecida para o texto
    if worldPosition then
        print(string.format("[FTM:_addInternal] Adding text '%s' for %s. Initial world pos: (%.2f, %.2f). TargetRef: %s",
            textContent, targetNameForLog, worldPosition.x, worldPosition.y, tostring(targetPositionRef)))
    else
        print(string.format("[FTM:_addInternal] Adding text '%s' (no worldPosition!). TargetRef: %s", textContent,
            tostring(targetPositionRef)))
        worldPosition = { x = 0, y = 0 } -- Fallback para evitar erro, mas isso é um problema.
    end

    if targetPositionRef then
        if not self.activeTargetInfo[targetPositionRef] or self.activeTargetInfo[targetPositionRef].count == 0 then
            self.activeTargetInfo[targetPositionRef] = { count = 0, lastSpawnTime = love.timer.getTime() }
        end

        local info = self.activeTargetInfo[targetPositionRef]
        info.count = info.count + 1

        if info.count > 1 then
            initialDelay = (info.count - 1) * self.TEXT_DELAY_INTERVAL
            initialStackOffsetY = (info.count - 1) * self.TEXT_STACK_OFFSET_Y
            stackOffsetX = love.math.random(-8, 8)
        end
        info.lastSpawnTime = love.timer.getTime() + initialDelay
    end

    local screenX, screenY = Camera:worldToScreen(worldPosition.x, worldPosition.y)
    local initialScreenPosition = { x = screenX + stackOffsetX, y = screenY }

    -- As factories (newEnemyDamage, newPlayerDamage, newText) esperam:
    -- (self, initialScreenPosition, text, targetEntity, initialDelay, initialStackOffsetY, props)
    -- Onde 'props' é a tabela propsForFactory que passamos.
    local floatingTextInstance = factoryFunction(
        FloatingText, -- self para a factory
        initialScreenPosition,
        textContent,
        targetEntity,
        initialDelay,
        initialStackOffsetY,
        propsForFactory or {} -- A tabela de props específica da factory
    )
    table.insert(self.texts, floatingTextInstance)
end

--- Adiciona um texto flutuante para dano causado a um inimigo.
---@param position {x: number, y: number} Posição {x, y} inicial do texto NO MUNDO.
---@param text string O conteúdo do texto.
---@param isCritical boolean Se o dano é crítico.
---@param enemyTarget table O objeto inimigo alvo.
function FloatingTextManager:addEnemyDamageText(position, text, isCritical, enemyTarget)
    local factoryProps = {
        isCritical = isCritical
        -- Outras props como scale, lifetime, velocityY, baseOffsetY serão definidas
        -- dentro de newEnemyDamage com base em isCritical.
        -- Se quisermos permitir overrides de addEnemyDamageText, eles seriam adicionados aqui.
    }
    self:_addTextInternal(FloatingText.newEnemyDamage, position, text, enemyTarget, factoryProps)
end

--- Adiciona um texto flutuante para dano recebido pelo jogador.
---@param position {x: number, y: number} Posição {x, y} inicial do texto NO MUNDO.
---@param text string O conteúdo do texto.
---@param playerTarget table O objeto jogador alvo.
function FloatingTextManager:addPlayerDamageText(position, text, playerTarget)
    local factoryProps = {
        isCritical = false -- Dano no jogador geralmente não é crítico desta forma
        -- Outras props como scale, lifetime, velocityY, baseOffsetY serão definidas
        -- dentro de newPlayerDamage.
    }
    self:_addTextInternal(FloatingText.newPlayerDamage, position, text, playerTarget, factoryProps)
end

--- Adiciona um texto flutuante para cura recebida pelo jogador.
---@param position {x: number, y: number} Posição {x, y} inicial do texto.
---@param text string O conteúdo do texto.
---@param playerTarget table O objeto jogador alvo.
function FloatingTextManager:addPlayerHealText(position, text, playerTarget)
    local factoryProps = {
        textColor = colors.heal, -- newText espera 'textColor' em sua tabela de props
        scale = 1.1,
        velocityY = -30,
        lifetime = 1.0,
        baseOffsetY = -40
        -- isCritical é false por padrão em newText se não especificado
    }
    self:_addTextInternal(FloatingText.newText, position, text, playerTarget, factoryProps)
end

--- Adds a floating text for a collected item.
--- The text color will be based on the item's rarity.
---@param position {x: number, y: number} Initial position {x, y} of the text.
---@param itemName string The name of the item.
---@param itemRarity string The item's rarity (e.g., "S", "A", etc.).
---@param target table|nil Optional target object that the text should follow.
function FloatingTextManager:addItemCollectedText(position, itemName, itemRarity, target)
    local itemColor = colors.rarity[itemRarity] or colors.text_default
    local factoryProps = {
        textColor = itemColor, -- newText espera 'textColor'
        scale = 1.0,
        velocityY = -25,
        lifetime = 1.2,
        baseOffsetY = -45
    }
    self:_addTextInternal(FloatingText.newText, position, itemName, target, factoryProps)
end

--- Adiciona um texto flutuante customizado.
--- Permite especificar todas as propriedades diretamente.
---@param position {x: number, y: number} Posição {x, y} inicial.
---@param text string O texto.
---@param target table|nil O alvo (opcional, para rastreamento de posição e empilhamento).
---@param props table As propriedades do texto (color, scale, velocityY, lifetime, etc.).
function FloatingTextManager:addCustomText(position, text, target, props)
    print(string.format("[FloatingTextManager:addCustomText] Tentando adicionar: '%s' em (%.2f, %.2f) MUNDO", text,
        position.x,
        position.y))
    local initialDelay = 0
    local initialStackOffsetY = 0
    local stackOffsetX = 0 -- Novo: Deslocamento X para empilhamento
    local targetPositionRef = target and target.position
    local targetNameForLog = (target and target.name) or (target and "id_" .. tostring(target.id)) or "UnknownTarget"

    props = props or {}

    if targetPositionRef then
        if not self.activeTargetInfo[targetPositionRef] or self.activeTargetInfo[targetPositionRef].count == 0 then
            self.activeTargetInfo[targetPositionRef] = { count = 0, lastSpawnTime = love.timer.getTime() }
        end
        local info = self.activeTargetInfo[targetPositionRef]
        info.count = info.count + 1
        if info.count > 1 then
            initialDelay = (info.count - 1) * (props.customDelayInterval or self.TEXT_DELAY_INTERVAL)
            initialStackOffsetY = (info.count - 1) * (props.customStackOffsetY or self.TEXT_STACK_OFFSET_Y)
            stackOffsetX = love.math.random(-8, 8) -- Deslocamento X aleatório entre -8 e 8 pixels
        end
        info.lastSpawnTime = love.timer.getTime() + initialDelay
    end

    -- Converte a posição do mundo para a tela ANTES de aplicar o offset de empilhamento X
    local screenX, screenY = Camera:worldToScreen(position.x, position.y)
    print(string.format("  -> Posição convertida para TELA: (%.2f, %.2f)", screenX, screenY))

    -- Ajusta a posição X inicial com o stackOffsetX (agora em coordenadas de tela)
    local finalPosition = { x = screenX + stackOffsetX, y = screenY }

    -- props.initialDelay = initialDelay -- Isso já é calculado e passado separadamente
    -- props.initialStackOffsetY = initialStackOffsetY -- Isso já é calculado e passado separadamente

    -- Chamada correta para FloatingText:new
    local floatingTextInstance = FloatingText:new(finalPosition, text, props, targetPositionRef, initialDelay,
        initialStackOffsetY, targetNameForLog, target)
    table.insert(self.texts, floatingTextInstance)
end

---@deprecated Utilizar :addEnemyDamageText, :addPlayerDamageText, :addPlayerHealText ou :addCustomText.
--- Adiciona um texto flutuante com base na lógica original.
---@param x number Posição X do texto.
---@param y number Posição Y do texto.
---@param textContent string O conteúdo do texto.
---@param isCritical boolean|nil Se o dano é crítico.
---@param target table|nil O objeto alvo (ex: inimigo, jogador) que possui um campo `position`.
---@param customColor table|nil Cor customizada opcional {r,g,b} ou {r,g,b,a}.
function FloatingTextManager:addText(x, y, textContent, isCritical, target, customColor)
    local Colors = require("src.ui.colors") -- Necessário aqui se não for global ou upvalue
    local props = {}
    props.isCritical = isCritical or false  -- Garante que seja booleano

    if customColor then
        props.color = customColor
        -- isCritical ainda afeta outros aspectos mesmo com customColor, conforme a lógica original
        if props.isCritical then
            props.scale = 1.5
            props.velocityY = -80 -- Movimento mais rápido
            props.lifetime = 0.8  -- Vida mais curta
        else
            props.scale = 1.0     -- Default
            props.velocityY = -20 -- Default
            props.lifetime = 0.5  -- Default
        end
    else
        if props.isCritical then
            props.color = Colors.damage_crit -- Usar cor de crítico definida no colors.lua
            props.scale = 1.5
            props.velocityY = -80
            props.lifetime = 0.8
        else
            props.color = Colors.text_default -- Usar cor de texto padrão
            props.scale = 1.0
            props.velocityY = -20
            props.lifetime = 0.5
        end
    end

    -- Definir um baseOffsetY padrão para a função depreciada,
    -- já que o FloatingText:new espera isso dentro de props ou usa -20.
    -- Pode ser ajustado se a lógica original implicava um offsetY diferente implicitamente.
    props.baseOffsetY = -20

    -- A função addCustomText cuidará de obter target.position, e aplicar
    -- o sistema de delay e stacking com os valores padrão do manager.
    -- A conversão de coordenadas MUNDO->TELA é feita em addCustomText.
    self:addCustomText({ x = x, y = y }, textContent, target, props)
end

return FloatingTextManager
