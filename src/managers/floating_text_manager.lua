local FloatingText = require("src.entities.floating_text")

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
    for _, textInstance in ipairs(self.texts) do
        textInstance:draw()
    end
end

--- Adiciona um texto flutuante genérico.
--- Calcula o atraso e o deslocamento de empilhamento se necessário.
---@param factoryFunction function A função fábrica de FloatingText (ex: FloatingText.newEnemyDamage).
---@param position {x: number, y: number} Posição {x, y} inicial do texto.
---@param textContent string O conteúdo do texto.
---@param isCriticalOrExtra boolean|any Se o texto é para um acerto crítico. Pode ser outro valor dependendo da factoryFunction.
---@param target table|nil O objeto alvo (ex: inimigo, jogador) que possui um campo `position`.
---@param ... any Argumentos adicionais para a factoryFunction.
function FloatingTextManager:_addTextInternal(factoryFunction, position, textContent, isCriticalOrExtra, target, ...)
    local initialDelay = 0
    local initialStackOffsetY = 0
    local stackOffsetX = 0                               -- Novo: Deslocamento X para empilhamento
    local targetPositionRef = target and target.position -- Usa a tabela de posição do alvo como chave

    if targetPositionRef then
        if not self.activeTargetInfo[targetPositionRef] or self.activeTargetInfo[targetPositionRef].count == 0 then
            self.activeTargetInfo[targetPositionRef] = { count = 0, lastSpawnTime = love.timer.getTime() }
        end

        local info = self.activeTargetInfo[targetPositionRef]
        info.count = info.count + 1

        if info.count > 1 then
            -- Aplica delay e offset com base na contagem (a partir do segundo texto)
            initialDelay = (info.count - 1) * self.TEXT_DELAY_INTERVAL
            initialStackOffsetY = (info.count - 1) * self.TEXT_STACK_OFFSET_Y
            stackOffsetX = love.math.random(-8, 8)               -- Deslocamento X aleatório entre -8 e 8 pixels
        end
        info.lastSpawnTime = love.timer.getTime() + initialDelay -- Atualiza o tempo de spawn considerando o delay
    end

    -- Ajusta a posição X inicial com o stackOffsetX
    local finalPosition = { x = position.x + stackOffsetX, y = position.y }

    -- A factoryFunction é chamada com `FloatingText` como `self`, seguido pelos argumentos.
    local floatingTextInstance = factoryFunction(FloatingText, finalPosition, textContent, isCriticalOrExtra,
        targetPositionRef, initialDelay, initialStackOffsetY, ...)
    table.insert(self.texts, floatingTextInstance)
end

--- Adiciona um texto flutuante para dano causado a um inimigo.
---@param position {x: number, y: number} Posição {x, y} inicial do texto.
---@param text string O conteúdo do texto.
---@param isCritical boolean Se o dano é crítico.
---@param enemyTarget table O objeto inimigo alvo.
function FloatingTextManager:addEnemyDamageText(position, text, isCritical, enemyTarget)
    self:_addTextInternal(FloatingText.newEnemyDamage, position, text, isCritical, enemyTarget)
end

--- Adiciona um texto flutuante para dano recebido pelo jogador.
---@param position {x: number, y: number} Posição {x, y} inicial do texto.
---@param text string O conteúdo do texto.
---@param playerTarget table O objeto jogador alvo.
function FloatingTextManager:addPlayerDamageText(position, text, playerTarget)
    self:_addTextInternal(FloatingText.newPlayerDamage, position, text, false, playerTarget)
end

--- Adiciona um texto flutuante para cura recebida pelo jogador.
---@param position {x: number, y: number} Posição {x, y} inicial do texto.
---@param text string O conteúdo do texto.
---@param playerTarget table O objeto jogador alvo.
function FloatingTextManager:addPlayerHealText(position, text, playerTarget)
    -- Para cura, isCritical geralmente é false.
    self:_addTextInternal(FloatingText.newPlayerHeal, position, text, false, playerTarget)
end

--- Adds a floating text for a collected item.
--- The text color will be based on the item's rarity.
---@param position {x: number, y: number} Initial position {x, y} of the text.
---@param itemName string The name of the item.
---@param itemRarity string The item's rarity (e.g., "S", "A", etc.).
---@param target table|nil Optional target object that the text should follow.
function FloatingTextManager:addItemCollectedText(position, itemName, itemRarity, target)
    -- The factoryFunction newItemCollectedText expects: initialPosition, itemName, itemRarity, targetPosition, initialDelay, initialStackOffsetY
    -- _addTextInternal provides: position, textContent (itemName), isCriticalOrExtra (itemRarity), target, initialDelay, initialStackOffsetY
    -- The parameter name isCriticalOrExtra is now used for itemRarity in this case.
    self:_addTextInternal(FloatingText.newItemCollectedText, position, itemName, itemRarity, target)
end

--- Adiciona um texto flutuante customizado.
--- Permite especificar todas as propriedades diretamente.
---@param position {x: number, y: number} Posição {x, y} inicial.
---@param text string O texto.
---@param target table|nil O alvo (opcional, para rastreamento de posição e empilhamento).
---@param props table As propriedades do texto (color, scale, velocityY, lifetime, etc.).
function FloatingTextManager:addCustomText(position, text, target, props)
    local initialDelay = 0
    local initialStackOffsetY = 0
    local stackOffsetX = 0 -- Novo: Deslocamento X para empilhamento
    local targetPositionRef = target and target.position

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

    -- Ajusta a posição X inicial com o stackOffsetX
    local finalPosition = { x = position.x + stackOffsetX, y = position.y }

    props.initialDelay = initialDelay
    props.initialStackOffsetY = initialStackOffsetY
    -- A função :new do FloatingText espera targetPosition como argumento separado, não dentro de props.
    local floatingTextInstance = FloatingText:new(finalPosition, text, targetPositionRef, props)
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
    self:addCustomText({ x = x, y = y }, textContent, target, props)
end

return FloatingTextManager
