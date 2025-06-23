----------------------------------------------------------------------------
-- Alternating Cone Strike Ability
-- Um ataque em cone rápido que atinge alternadamente a metade esquerda ou direita.
-- Refatorado para receber weaponInstance e buscar stats dinamicamente.
----------------------------------------------------------------------------

local TablePool = require("src.utils.table_pool")
local CombatHelpers = require("src.utils.combat_helpers")

--- @class AlternatingConeStrike
--- @field playerManager PlayerManager
--- @field weaponInstance BaseWeapon
--- @field cooldownRemaining number
--- @field activeAttacks table
--- @field hitLeftNext boolean
--- @field visual table
--- @field knockbackPower number
--- @field knockbackForce number
--- @field enemiesKnockedBackInThisCast table
--- @field area table
local AlternatingConeStrike = {}
AlternatingConeStrike.__index = AlternatingConeStrike -- Para permitir :new

-- Configurações visuais PADRÃO (serão sobrescritas pela weaponInstance se disponíveis)
AlternatingConeStrike.name = "Golpe Cônico Alternado"
AlternatingConeStrike.description = "Golpeia rapidamente em metades alternadas de um cone."
AlternatingConeStrike.damageType = "melee"
AlternatingConeStrike.visual = {
    preview = {
        active = false,
        lineLength = 50,
        color = { 0.7, 0.7, 0.7, 0.2 } -- Cor padrão preview
    },
    attack = {
        animationDuration = 0.1,
        color = { 0.8, 0.1, 0.8, 0.6 } -- Cor padrão ataque
    }
}

--- Cria uma nova instância da habilidade AlternatingConeStrike.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param weaponInstance BaseWeapon Instância da arma que está usando esta habilidade.
function AlternatingConeStrike:new(playerManager, weaponInstance)
    local o = setmetatable({}, self)
    Logger.debug("AlternatingConeStrike:new", "Creating instance...")

    if not playerManager or not weaponInstance then
        error("AlternatingConeStrike:new - playerManager e weaponInstance são obrigatórios.")
        return nil
    end

    o.playerManager = playerManager
    o.weaponInstance = weaponInstance -- Armazena a instância da arma

    -- Propriedades de Knockback da arma
    local baseData = o.weaponInstance:getBaseData()
    o.knockbackPower = baseData and baseData.knockbackPower or 0
    o.knockbackForce = baseData and baseData.knockbackForce or 0

    o.cooldownRemaining = 0
    o.activeAttacks = {} -- Rastreia animações de ataque individuais
    o.hitLeftNext = true -- Começa atacando pela esquerda

    -- Busca cores da weaponInstance (sobrescreve os padrões)
    o.visual.preview.color = weaponInstance.previewColor or o.visual.preview.color
    o.visual.attack.color = weaponInstance.attackColor or o.visual.attack.color
    Logger.debug("[AlternatingConeStrike:new]", "Preview/Attack colors set (using weaponInstance if available).")

    -- Área de efeito será calculada dinamicamente no update/cast
    o.area = {
        position = { x = 0, y = 0 },
        angle = 0,
        range = 0,      -- Será atualizado
        angleWidth = 0, -- Será atualizado
        halfWidth = 0   -- Será atualizado
    }
    -- Atualiza posição inicial
    if o.playerManager.player then
        o.area.position.x = o.playerManager.player.position.x
        o.area.position.y = o.playerManager.player.position.y
    else
        Logger.warn("[AlternatingConeStrike:new]", "Player sprite not yet available for initial position.")
    end

    -- REMOVIDO: Stats não são mais armazenados aqui
    -- o.baseDamage = weapon.damage
    -- o.baseCooldown = weapon.cooldown

    Logger.debug("[AlternatingConeStrike:new]", "Instance created successfully.")
    return o
end

--- Atualiza o estado da habilidade.
---@param dt number Delta time.
---@param angle number Ângulo atual da mira do jogador.
function AlternatingConeStrike:update(dt, angle)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza posição e ângulo do cone para seguir o jogador e o mouse
    if self.area and self.playerManager.player then
        self.area.position = self.playerManager.player.position
        self.area.angle = angle -- Ângulo central da mira

        -- Obtém os stats finais do jogador UMA VEZ
        local finalStats = self.playerManager:getCurrentFinalStats()

        local baseData = self.weaponInstance:getBaseData()
        local weaponBaseRange = (baseData and baseData.range)
        local weaponBaseAngle = (baseData and baseData.angle)

        -- Usa os multiplicadores de range e area dos stats finais
        -- Assumindo que finalStats.range e finalStats.attackArea são multiplicadores diretos (ex: 1.1 para +10%)
        -- Se weaponBaseRange, finalStats.range ou finalStats.attackArea forem nil, o resultado será nil, o que pode causar erro adiante.
        -- Isso é intencional para detectar problemas de dados.
        local newRange = weaponBaseRange and finalStats.range and (weaponBaseRange * finalStats.range)
        local newAngleWidth = weaponBaseAngle and finalStats.attackArea and (weaponBaseAngle * finalStats.attackArea)

        -- Atualiza apenas se mudou (otimização)
        if newRange ~= self.area.range or newAngleWidth ~= self.area.angleWidth then
            self.area.range = newRange
            self.area.angleWidth = newAngleWidth
            self.area.halfWidth = newAngleWidth and
                (newAngleWidth / 2) -- Protege contra nil
            Logger.debug("[AlternatingConeStrike:update]", string.format(
                "  [UPDATE] Area Recalculated. Range: %s | AngleWidth: %s (BaseRange: %s, BaseAngle: %.2f, PlayerRangeMult: %s, PlayerAreaMult: %s)",
                tostring(self.area.range), tostring(self.area.angleWidth), tostring(weaponBaseRange), weaponBaseAngle,
                tostring(finalStats.range), tostring(finalStats.attackArea)))
        end
    end

    -- Atualiza animação dos ataques ativos
    for i = #self.activeAttacks, 1, -1 do
        local attackInstance = self.activeAttacks[i]
        if attackInstance.delay and attackInstance.delay > 0 then
            attackInstance.delay = attackInstance.delay - dt
            if attackInstance.delay < 0 then attackInstance.delay = 0 end
        else
            attackInstance.progress = attackInstance.progress + (dt / self.visual.attack.animationDuration)
        end

        if attackInstance.progress >= 1 then
            table.remove(self.activeAttacks, i)
        end
    end
end

--- Tenta executar o ataque.
---@param args table Argumentos opcionais (não usado atualmente).
---@return boolean True se o ataque foi iniciado (mesmo que não acerte), False se estava em cooldown.
function AlternatingConeStrike:cast(args)
    args = args or {}

    -- Rastreia inimigos que já sofreram knockback nesta chamada de cast
    self.enemiesKnockedBackInThisCast = {}

    if self.cooldownRemaining > 0 then
        return false -- Em cooldown
    end
    Logger.debug("[AlternatingConeStrike:cast]", "Casting attack.")

    -- Determina qual lado atacar NESTE cast
    local attackLeftThisCast = self.hitLeftNext

    -- Inicia a animação (sempre mostra a animação do PRIMEIRO golpe do cast)
    Logger.debug("[AlternatingConeStrike:cast]",
        string.format("Attacking %s side first.", attackLeftThisCast and "LEFT" or "RIGHT"))

    -- Obtém os stats finais do jogador UMA VEZ
    local finalStats = self.playerManager:getCurrentFinalStats()

    -- Aplica o cooldown baseado no attackSpeed TOTAL do jogador
    local baseData = self.weaponInstance:getBaseData()
    local baseCooldown = (baseData and baseData.cooldown) or 1.0 -- Padrão 1s
    local totalAttackSpeed = finalStats.attackSpeed              -- Usa attackSpeed dos stats finais
    if totalAttackSpeed <= 0 then totalAttackSpeed = 0.01 end    -- Evita divisão por zero ou cooldown infinito
    self.cooldownRemaining = baseCooldown / totalAttackSpeed
    Logger.debug("[AlternatingConeStrike:cast]",
        string.format("Cooldown set to %.2fs (Base: %.2f / FinalASMult: %.2f)", self.cooldownRemaining,
            baseCooldown,
            totalAttackSpeed))

    -- Calcula ataques extras usando multiAttackChance dos stats finais
    local multiAttackChance = finalStats.multiAttackChance
    local extraAttacks = math.floor(multiAttackChance)
    local decimalChance = multiAttackChance - extraAttacks
    Logger.debug("[AlternatingConeStrike:cast]",
        string.format("Multi-Attack Chance: %.2f (Extra: %d + %.2f%%)", multiAttackChance, extraAttacks,
            decimalChance * 100))

    -- Parâmetro de delay entre animações de ataques extras
    local delayStep = 0.45 -- segundos entre cada animação de ataque extra
    local currentDelay = 0

    -- Executa o PRIMEIRO ataque
    local success = self:executeAttack(attackLeftThisCast, finalStats) -- Passa finalStats
    self:createAttackAnimationInstance(attackLeftThisCast, currentDelay)
    local currentHitIsLeft = attackLeftThisCast                        -- Variável para alternar nos extras
    currentDelay = currentDelay + delayStep

    -- Executa ataques extras inteiros, alternando a CADA extra
    for i = 1, extraAttacks do
        if success then                             -- Só continua se o anterior (hipoteticamente) teve sucesso
            currentHitIsLeft = not currentHitIsLeft -- Alterna para o próximo extra
            Logger.debug("[AlternatingConeStrike:cast]",
                string.format("Executing extra attack #%d (%s side)", i, currentHitIsLeft and "LEFT" or "RIGHT"))
            success = self:executeAttack(currentHitIsLeft, finalStats) -- Passa finalStats
            self:createAttackAnimationInstance(currentHitIsLeft, currentDelay)
            currentDelay = currentDelay + delayStep
        else
            Logger.debug("[AlternatingConeStrike:cast]", "Stopping extra attacks due to previous failure.")
            break
        end
    end

    -- Chance de ataque extra decimal, também alterna
    if success and decimalChance > 0 and math.random() < decimalChance then
        currentHitIsLeft = not currentHitIsLeft -- Alterna para este extra
        Logger.debug("[AlternatingConeStrike:cast]", string.format("Executing decimal chance extra attack (%s side)",
            currentHitIsLeft and "LEFT" or "RIGHT"))
        self:executeAttack(currentHitIsLeft, finalStats) -- Passa finalStats
        self:createAttackAnimationInstance(currentHitIsLeft, currentDelay)
    end

    -- IMPORTANTE: Alterna o estado APENAS UMA VEZ no final, preparando o PRÓXIMO cast
    self.hitLeftNext = not self.hitLeftNext
    Logger.debug("[AlternatingConeStrike:cast]",
        string.format("Next cast will start on %s side.", self.hitLeftNext and "LEFT" or "RIGHT"))

    return true -- Retorna true porque o cast foi iniciado
end

--- Cria uma instância de animação de ataque.
---@param hitLeft boolean True se o ataque foi no lado esquerdo.
---@param delay number Delay para iniciar a animação.
function AlternatingConeStrike:createAttackAnimationInstance(hitLeft, delay)
    -- Captura um snapshot da área no momento em que a animação é criada
    local areaSnapshot = {
        position = { x = self.area.position.x, y = self.area.position.y },
        angle = self.area.angle,
        range = self.area.range,
        angleWidth = self.area.angleWidth,
        halfWidth = self.area.halfWidth
    }

    local attackAnimationInstance = {
        progress = 0,
        hitLeft = hitLeft,
        delay = delay or 0,
        area = areaSnapshot -- Armazena o snapshot
    }
    table.insert(self.activeAttacks, attackAnimationInstance)
    -- Logger.debug("[AlternatingConeStrike:createAttackAnimationInstance]",
    --     string.format("Animation instance created. HitLeft: %s, Delay: %.2f", tostring(hitLeft), delay))
end

--- Executa a lógica de um único golpe em uma metade específica.
---@param hitLeft boolean True para atacar a metade esquerda, False para a direita.
---@param finalStats table Stats finais do jogador.
---@return boolean Sempre retorna true (indica que a tentativa de ataque foi feita).
function AlternatingConeStrike:executeAttack(hitLeft, finalStats)
    if not self.area or not self.area.range or self.area.range <= 0 then
        error("AlternatingConeStrike:executeAttack: Área de ataque inválida ou alcance zero, não buscando inimigos.")
    end

    -- Usa o helper para encontrar inimigos na meia área de cone correta
    local enemiesHit = CombatHelpers.findEnemiesInConeHalfArea(self.area, hitLeft, self.playerManager.player)
    local enemiesHitCount = #enemiesHit

    local side = hitLeft and "LEFT" or "RIGHT"
    -- Logger.debug("executeAttack", string.format("Checking %d nearby enemies on %s side.", #nearbyEnemies, side))

    if enemiesHitCount > 0 then
        -- print(string.format("    [executeAttack - %s] Hit %d enemies.", side, enemiesHitCount))
        local knockbackData = {
            power = self.knockbackPower,
            force = self.knockbackForce,
            attackerPosition = self.area.position
        }
        -- Usa o helper para aplicar dano e knockback
        CombatHelpers.applyHitEffects(
            enemiesHit,
            finalStats,
            knockbackData,
            self.enemiesKnockedBackInThisCast,
            self.playerManager,
            self.weaponInstance
        )
    end

    -- Libera a tabela de inimigos obtida do pool
    TablePool.release(enemiesHit)

    return true -- Retorna true mesmo se não atingiu ninguém
end

--- Desenha os elementos visuais da habilidade.
function AlternatingConeStrike:draw()
    if not self.area then return end

    -- Desenha a prévia da linha se ativa (mostra o cone inteiro)
    if self.visual.preview.active then
        self:drawConeOutline(self.visual.preview.color) -- Usa cor da instância
    end

    -- Desenha a animação do ataque
    for i = 1, #self.activeAttacks do
        local attackInstance = self.activeAttacks[i]
        if attackInstance and (not attackInstance.delay or attackInstance.delay <= 0) then
            self:drawConeFill(self.visual.attack.color, attackInstance.progress, attackInstance.area,
                attackInstance.hitLeft) -- Passa a área do snapshot
        end
    end
end

--- Desenha o CONTORNO do cone inteiro (para preview).
function AlternatingConeStrike:drawConeOutline(color)
    if not self.area or self.area.range <= 0 then return end
    -- REMOVIDO: Chamada a updateAreaIfNeeded()
    local segments = 32
    love.graphics.setColor(color)
    local cx, cy = self.area.position.x, self.area.position.y
    local range = self.area.range
    local startAngle = self.area.angle - self.area.halfWidth
    local endAngle = self.area.angle + self.area.halfWidth

    local vertices = {}
    table.insert(vertices, cx)
    table.insert(vertices, cy)
    for i = 0, segments do
        local angle = startAngle + (endAngle - startAngle) * (i / segments)
        table.insert(vertices, cx + range * math.cos(angle))
        table.insert(vertices, cy + range * math.sin(angle))
    end
    table.insert(vertices, cx)
    table.insert(vertices, cy)

    if #vertices >= 4 then
        love.graphics.line(unpack(vertices))
    end

    love.graphics.setColor(1, 1, 1, 1)
end

--- Desenha o PREENCHIMENTO de METADE do cone com ESTILO DE ONDA (para ataque).
--- Baseado no drawConeFill do ConeSlash, mas adaptado para desenhar apenas uma metade.
---@param color table Cor RGBA a ser usada.
---@param progress number Progresso da animação (0 a 1).
---@param areaInstance table A instância da área para este desenho específico (com position, angle, range, halfWidth, angleWidth).
---@param drawLeft boolean True para desenhar a metade esquerda, False para a direita.
function AlternatingConeStrike:drawConeFill(color, progress, areaInstance, drawLeft)
    if not areaInstance or not areaInstance.range or areaInstance.range <= 0 or not areaInstance.angleWidth or areaInstance.angleWidth <= 0 or not areaInstance.halfWidth or areaInstance.halfWidth <= 0 then
        Logger.warn("[AlternatingConeStrike:drawConeFill]", string.format("Invalid area for drawing. R:%s AW:%s HW:%s",
            tostring(areaInstance.range), tostring(areaInstance.angleWidth), tostring(areaInstance.halfWidth)))
        return
    end

    local segments = (self.visual and self.visual.attack and self.visual.attack.segments) or 16 -- 16 para metade do cone
    local playerRadius = (self.playerManager.player and self.playerManager.player.radius or 10)
    local fullRange = areaInstance.range
    if not fullRange or fullRange <= 0 then return end

    -- Parâmetros da onda (shell)
    local shellWidth = math.max(12, fullRange * 0.18) -- Ajustado para ser potencialmente menor em meio cone
    local shellRadius = playerRadius + (fullRange - playerRadius) * progress
    local shellInner = math.max(playerRadius, shellRadius - shellWidth * 0.5)
    local shellOuter = math.min(fullRange, shellRadius + shellWidth * 0.5)

    -- Garante que há algo para desenhar e que o shell não é inválido
    if shellOuter <= shellInner or progress < 0.01 then return end

    local cx, cy = areaInstance.position.x, areaInstance.position.y
    local baseAngle = areaInstance.angle
    local halfWidth = areaInstance.halfWidth

    local coneCurrentStartAngle, coneCurrentEndAngle

    if drawLeft then
        -- Metade Esquerda: do ângulo (base - halfWidth) ao ângulo base
        coneCurrentStartAngle = baseAngle - halfWidth
        coneCurrentEndAngle = baseAngle
    else
        -- Metade Direita: do ângulo base ao ângulo (base + halfWidth)
        coneCurrentStartAngle = baseAngle
        coneCurrentEndAngle = baseAngle + halfWidth
    end

    -- Preenchimento principal (onda na metade do cone)
    local vertices = {}
    -- Ponto central (ou do jogador) para fechar o polígono da metade do cone
    -- table.insert(vertices, cx + playerRadius * math.cos(coneCurrentStartAngle)) -- Ponto inicial no raio do jogador
    -- table.insert(vertices, cy + playerRadius * math.sin(coneCurrentStartAngle))

    -- Arco externo da onda
    for i = 0, segments do
        local angle = coneCurrentStartAngle + (coneCurrentEndAngle - coneCurrentStartAngle) * (i / segments)
        table.insert(vertices, cx + shellOuter * math.cos(angle))
        table.insert(vertices, cy + shellOuter * math.sin(angle))
    end

    -- table.insert(vertices, cx + playerRadius * math.cos(coneCurrentEndAngle)) -- Ponto final no raio do jogador
    -- table.insert(vertices, cy + playerRadius * math.sin(coneCurrentEndAngle))

    if #vertices >= 6 then -- Mínimo para um polígono com inner/outer shell
        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1.0) * 0.6)
        love.graphics.polygon("fill", unpack(vertices))
    end

    -- Borda brilhante no arco externo da metade do cone
    if #vertices >= 4 then -- Apenas o arco externo para a linha
        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1.0) * 0.5)
        love.graphics.setLineWidth(2)
        local borderVertices = {}
        for i = 0, segments do
            local angle = coneCurrentStartAngle + (coneCurrentEndAngle - coneCurrentStartAngle) * (i / segments)
            table.insert(borderVertices, cx + shellOuter * math.cos(angle))
            table.insert(borderVertices, cy + shellOuter * math.sin(angle))
        end
        love.graphics.line(unpack(borderVertices))
        love.graphics.setLineWidth(1)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function AlternatingConeStrike:getCooldownRemaining()
    return self.cooldownRemaining or 0
end

function AlternatingConeStrike:togglePreview()
    self.visual.preview.active = not self.visual.preview.active
end

function AlternatingConeStrike:getPreview()
    return self.visual.preview.active
end

return AlternatingConeStrike
