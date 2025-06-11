-------------------------------------------------------
--  ConeSlash
--- @author ReyalS
--- @release 1.0
--- @license MIT
--- @description
--  Habilidade de ataque em cone.
--  Executa múltiplos cortes baseados em chance de ataque múltiplo.
--  O dano é aplicado a todos os inimigos dentro do cone.
-------------------------------------------------------

local ManagerRegistry = require("src.managers.manager_registry")
local TablePool = require("src.utils.table_pool")         -- Garante que temos acesso ao TablePool
local Helpers = require("src.utils.helpers")
local CombatHelpers = require("src.utils.combat_helpers") -- Adicionado

---@class ConeSlash
---@field name string Nome da habilidade.
---@field description string Descrição.
---@field damageType string Tipo de dano ("melee").
---@field visual table Configurações visuais (preview e attack).
---@field cooldownRemaining number Tempo restante de cooldown.
---@field activeAttacks table Lista de ataques ativos {progress, areaSnapshot, delay}.
---@field area table Área atual do cone {position, angle, range, angleWidth, halfWidth}.
---@field playerManager PlayerManager Referência ao gerenciador de jogador.
---@field weaponInstance BaseWeapon Referência à arma que executa este ataque.
---@field knockbackPower number
---@field knockbackForce number
---@field enemiesKnockedBackInThisCast table
local ConeSlash = {}
ConeSlash.__index = ConeSlash -- Para permitir :new

-- Configurações visuais PADRÃO
ConeSlash.name = "Cone Slash"
ConeSlash.description = "Um ataque em cone que causa dano a todos os inimigos na área"
ConeSlash.damageType = "melee"
ConeSlash.visual = {
    preview = {
        active = false,
        lineLength = 50,
        color = { 1, 1, 1, 0.2 } -- Cor padrão preview
    },
    attack = {
        segments = 20,
        animationDuration = 0.15, -- Duração da animação em segundos
        color = { 1, 1, 1, 0.8 }  -- Cor padrão ataque
    }
}

--- Cria uma nova instância da habilidade ConeSlash.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param weaponInstance BaseWeapon Instância da arma que está usando esta habilidade.
function ConeSlash:new(playerManager, weaponInstance)
    local o = setmetatable({}, self)
    Logger.info("ConeSlash:new", " Creating instance...")

    if not playerManager or not weaponInstance then
        error("[ConeSlash:new] ERRO: playerManager e weaponInstance são obrigatórios.")
    end

    o.playerManager = playerManager
    o.weaponInstance = weaponInstance

    -- Propriedades de Knockback da arma
    local baseData = o.weaponInstance:getBaseData()
    o.knockbackPower = baseData and baseData.knockbackPower or 0
    o.knockbackForce = baseData and baseData.knockbackForce or 0

    o.cooldownRemaining = 0
    o.activeAttacks = {} -- Rastreia animações de ataque individuais

    -- Área de efeito será calculada dinamicamente no update
    o.area = {
        position = { x = 0, y = 0 },
        angle = 0,
        range = 0,      -- Será atualizado
        angleWidth = 0, -- Será atualizado
        halfWidth = 0   -- Será atualizado (calculado a partir de angleWidth)
    }
    if o.playerManager.player then
        o.area.position.x = o.playerManager.player.position.x
        o.area.position.y = o.playerManager.player.position.y
    else
        Logger.warn("ConeSlash:new", "  - WARN: Player sprite not yet available for initial position.")
    end

    Logger.debug("ConeSlash:new", " Instance created successfully.")
    return o
end

--- Atualiza o estado da habilidade.
---@param dt number Delta time.
---@param angle number Ângulo atual da mira do jogador.
function ConeSlash:update(dt, angle)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza posição e ângulo do cone
    if self.area and self.playerManager.player then
        self.area.position = self.playerManager.player.position
        self.area.angle = angle -- Ângulo central da mira

        -- Obtém os stats finais do jogador UMA VEZ
        local finalStats = self.playerManager:getCurrentFinalStats()

        local baseData = self.weaponInstance:getBaseData()
        local weaponBaseRange = baseData and baseData.range
        local weaponBaseAngle = baseData and baseData.angle

        -- Usa os multiplicadores de range e area dos stats finais
        local newRange = weaponBaseRange and finalStats.range and (weaponBaseRange * finalStats.range)
        local newAngleWidth = weaponBaseAngle and finalStats.attackArea and (weaponBaseAngle * finalStats.attackArea)

        if newRange ~= self.area.range or newAngleWidth ~= self.area.angleWidth then
            self.area.range = newRange
            self.area.angleWidth = newAngleWidth
            self.area.halfWidth = newAngleWidth and (newAngleWidth / 2)
            Logger.debug("[ConeSlash UPDATE]", string.format(
                " Area Recalculated. Range: %s | AngleWidth: %s (BaseRange: %s, BaseAngle: %s, PlayerRangeMult: %s, PlayerAreaMult: %s)",
                tostring(self.area.range), tostring(self.area.angleWidth), tostring(weaponBaseRange),
                tostring(weaponBaseAngle), tostring(finalStats.range), tostring(finalStats.attackArea)))
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
---@param args table Argumentos opcionais (não usado).
---@return boolean True se o ataque foi iniciado, False se estava em cooldown.
function ConeSlash:cast(args)
    args = args or {}

    -- Rastreia inimigos que já sofreram knockback nesta chamada de cast
    self.enemiesKnockedBackInThisCast = {}

    if self.cooldownRemaining > 0 then
        return false -- Em cooldown
    end
    Logger.debug("[ConeSlash:cast]", "Casting attack.")

    local finalStats = self.playerManager:getCurrentFinalStats()

    -- Aplica o cooldown
    local baseData = self.weaponInstance:getBaseData()
    local baseCooldown = baseData and baseData.cooldown -- Sem fallback
    local totalAttackSpeed = finalStats.attackSpeed     -- Sem fallback inicial
    if not totalAttackSpeed or totalAttackSpeed <= 0 then totalAttackSpeed = 0.01 end

    if baseCooldown and totalAttackSpeed then
        self.cooldownRemaining = baseCooldown / totalAttackSpeed
        Logger.debug("[ConeSlash:cast]",
            string.format("  - Cooldown set to %.2fs (Base: %s / FinalASMult: %.2f)", self.cooldownRemaining,
                tostring(baseCooldown), totalAttackSpeed))
    else
        error(
            "[ConeSlash:cast] ERRO: baseCooldown ou totalAttackSpeed é nil/inválido. Não é possível calcular cooldown.")
        self.cooldownRemaining = 1 -- Cooldown de fallback em caso de erro de dados
    end

    -- Calcula ataques extras (multiAttackChance)
    local multiAttackChance = finalStats.multiAttackChance -- Sem fallback
    local extraAttacks = 0
    local decimalChance = 0

    if multiAttackChance then
        extraAttacks = math.floor(multiAttackChance)
        decimalChance = multiAttackChance - extraAttacks
        Logger.info("[ConeSlash:cast]",
            string.format("  - Multi-Attack Chance: %s (Extra: %d + %.2f%%)", tostring(multiAttackChance), extraAttacks,
                decimalChance * 100), true)
        print("multiAttackChance: " .. multiAttackChance)
    else
        error("[ConeSlash:cast] AVISO: multiAttackChance é nil. Nenhum ataque extra será calculado.")
    end

    -- Parâmetro de delay entre ataques extras
    local delayStep = 0.1 -- segundos entre cada ataque extra
    local currentDelay = 0

    -- Primeiro ataque sempre ocorre
    local success = self:executeAttackAndAnimate(finalStats, currentDelay)
    currentDelay = currentDelay + delayStep

    -- Executa ataques extras inteiros
    for i = 1, extraAttacks do
        if success then -- success aqui refere-se à capacidade de executar o ataque (não se atingiu algo)
            Logger.debug("[ConeSlash:cast]", string.format("    - Executing extra attack #%d", i), true)
            success = self:executeAttackAndAnimate(finalStats, currentDelay)
            currentDelay = currentDelay + delayStep
        else
            Logger.debug("[ConeSlash:cast]", "    - Stopping extra attacks due to previous (logical) failure.", true)
            break
        end
    end

    -- Chance de ataque extra decimal
    if success and decimalChance > 0 and math.random() < decimalChance then
        Logger.debug("[ConeSlash:cast]", "    - Executing decimal chance extra attack", true)
        self:executeAttackAndAnimate(finalStats, currentDelay)
    end

    return true -- Retorna true porque o cast foi iniciado (pelo menos uma tentativa de ataque)
end

--- Executa a lógica de um único golpe do ConeSlash E INICIA SUA ANIMAÇÃO.
---@param finalStats table Os stats finais do jogador.
---@param delay number Delay (em segundos) para iniciar a animação deste ataque.
---@return boolean Sempre retorna true (indica que a tentativa de ataque foi feita).
function ConeSlash:executeAttackAndAnimate(finalStats, delay)
    delay = delay or 0
    local hitSomething = self:_executeSingleAttackLogic(finalStats)
    if self.area and self.area.range and self.area.range > 0 and self.area.halfWidth and self.area.halfWidth > 0 then
        local attackAnimationInstance = {
            progress = 0,
            delay = delay
        }
        table.insert(self.activeAttacks, attackAnimationInstance)
        Logger.debug("[ConeSlash:executeAttackAndAnimate]",
            string.format("Animation instance created. Range: %s, Angle: %s, Delay: %.2f",
                tostring(self.area.range), tostring(self.area.angle), delay), true)
    else
        Logger.warn("[ConeSlash:executeAttackAndAnimate]",
            "Área de mira inválida no momento do cast, animação não será criada para este golpe.")
    end
    return true
end

--- Lógica interna para um único golpe de ConeSlash (dano).
---@param finalStats table Os stats finais do jogador.
---@return boolean True se pelo menos um inimigo foi atingido, false caso contrário.
function ConeSlash:_executeSingleAttackLogic(finalStats)
    -- Verifica se a área de ataque (de mira) é válida antes de prosseguir
    if not self.area or not self.area.range or self.area.range <= 0 or not self.area.halfWidth or self.area.halfWidth <= 0 then
        error(string.format(
            "[ConeSlash:_executeSingleAttackLogic] AVISO: Área de ataque (mira) inválida. Range: %s, HalfWidth: %s. Nenhum inimigo será atingido.",
            tostring(self.area.range), tostring(self.area.halfWidth)))
        return false -- Retorna false, pois a tentativa falhou em atingir algo devido à área inválida
    end

    -- Usa o helper para encontrar inimigos na área de cone
    local enemiesHit = CombatHelpers.findEnemiesInConeArea(self.area, self.playerManager.player)
    local enemiesHitCount = #enemiesHit

    if enemiesHitCount > 0 then
        -- Logger.debug("[ConeSlash:_executeSingleAttackLogic]", string.format("Hit %d enemies.", enemiesHitCount))
        local knockbackData = {
            power = self.knockbackPower,
            force = self.knockbackForce,
            attackerPosition = self.area.position
        }
        -- Usa o helper para aplicar dano e knockback
        CombatHelpers.applyHitEffects(enemiesHit, finalStats, knockbackData, self.enemiesKnockedBackInThisCast)
    end

    -- Libera a tabela de inimigos obtida do pool
    TablePool.release(enemiesHit)

    return enemiesHitCount > 0
end

--- Desenha os elementos visuais da habilidade.
function ConeSlash:draw()
    if not self.area then return end

    -- Desenha a prévia (contorno) se ativa
    if self.visual.preview.active then
        self:drawConeOutline(self.visual.preview.color)
    end

    -- Desenha a animação do ataque (preenchido) para cada ataque ativo
    for i = 1, #self.activeAttacks do
        local attackInstance = self.activeAttacks[i]
        if attackInstance and (not attackInstance.delay or attackInstance.delay <= 0) then
            self:drawConeFill(self.visual.attack.color, attackInstance.progress, self.area)
        end
    end
end

--- Desenha o CONTORNO do cone (para preview).
---@param color table Cor RGBA.
function ConeSlash:drawConeOutline(color)
    if not self.area or not self.area.range or self.area.range <= 0 or not self.area.halfWidth or self.area.halfWidth <= 0 then
        error("[ConeSlash:drawConeOutline] AVISO: Área inválida para desenho.")
    end
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

--- Desenha o PREENCHIMENTO do cone (para ataque).
---@param color table Cor RGBA.
---@param progress number Progresso da animação (0 a 1).
---@param areaInstance table A instância da área para este desenho específico (com position, angle, range, halfWidth, angleWidth).
function ConeSlash:drawConeFill(color, progress, areaInstance)
    if not areaInstance or not areaInstance.range or areaInstance.range <= 0 or not areaInstance.angleWidth or areaInstance.angleWidth <= 0 then
        if not areaInstance then
            error("[ConeSlash:drawConeFill] AVISO: areaInstance é nil.")
            return
        end
        if not areaInstance.range or areaInstance.range <= 0 then
            error(string.format("[ConeSlash:drawConeFill] AVISO: areaInstance.range inválido: %s",
                tostring(areaInstance.range)))
            return
        end
        if not areaInstance.angleWidth or areaInstance.angleWidth <= 0 then
            error(string.format("[ConeSlash:drawConeFill] AVISO: areaInstance.angleWidth inválido: %s",
                tostring(areaInstance.angleWidth)))
            return
        end
        return
    end

    local segments = self.visual.attack.segments or 20
    local playerRadius = (self.playerManager.player and self.playerManager.player.radius or 10)
    local fullRange = areaInstance.range
    if not fullRange or fullRange <= 0 then return end

    -- Parâmetros da onda
    local shellWidth = math.max(24, fullRange * 0.18)
    local shellRadius = playerRadius + (fullRange - playerRadius) * progress
    local shellInner = math.max(playerRadius, shellRadius - shellWidth * 0.5)
    local shellOuter = math.min(fullRange, shellRadius + shellWidth * 0.5)
    if shellOuter <= shellInner then return end

    local cx, cy = areaInstance.position.x, areaInstance.position.y
    local coneBaseStartAngle = areaInstance.angle - areaInstance.halfWidth
    local coneBaseEndAngle = areaInstance.angle + areaInstance.halfWidth

    if progress < 0.01 then return end

    -- Preenchimento principal (onda)
    local vertices = {}
    for i = 0, segments do
        local angle = coneBaseStartAngle + (coneBaseEndAngle - coneBaseStartAngle) * (i / segments)
        table.insert(vertices, cx + shellOuter * math.cos(angle))
        table.insert(vertices, cy + shellOuter * math.sin(angle))
    end
    for i = segments, 0, -1 do
        local angle = coneBaseStartAngle + (coneBaseEndAngle - coneBaseStartAngle) * (i / segments)
        table.insert(vertices, cx + shellInner * math.cos(angle))
        table.insert(vertices, cy + shellInner * math.sin(angle))
    end
    if #vertices >= 6 then
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1.0)
        love.graphics.polygon("fill", unpack(vertices))
    end

    -- Faixa inferior mais transparente (gradiente fake)
    local baseFadeWidth = shellWidth * 0.35
    local fadeInner = shellInner
    local fadeOuter = math.min(shellOuter, shellInner + baseFadeWidth)
    if fadeOuter > fadeInner then
        local fadeVertices = {}
        for i = 0, segments do
            local angle = coneBaseStartAngle + (coneBaseEndAngle - coneBaseStartAngle) * (i / segments)
            table.insert(fadeVertices, cx + fadeOuter * math.cos(angle))
            table.insert(fadeVertices, cy + fadeOuter * math.sin(angle))
        end
        for i = segments, 0, -1 do
            local angle = coneBaseStartAngle + (coneBaseEndAngle - coneBaseStartAngle) * (i / segments)
            table.insert(fadeVertices, cx + fadeInner * math.cos(angle))
            table.insert(fadeVertices, cy + fadeInner * math.sin(angle))
        end
        if #fadeVertices >= 6 then
            love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1.0) * 0.3)
            love.graphics.polygon("fill", unpack(fadeVertices))
        end
    end

    -- Borda brilhante no arco externo
    if #vertices >= 6 then
        love.graphics.setColor(1, 1, 1, 0.7 * (1 - progress))
        love.graphics.setLineWidth(2)
        local borderVertices = {}
        for i = 0, segments do
            local angle = coneBaseStartAngle + (coneBaseEndAngle - coneBaseStartAngle) * (i / segments)
            table.insert(borderVertices, cx + shellOuter * math.cos(angle))
            table.insert(borderVertices, cy + shellOuter * math.sin(angle))
        end
        love.graphics.line(unpack(borderVertices))
        love.graphics.setLineWidth(1)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

--- Retorna o cooldown restante.
---@return number
function ConeSlash:getCooldownRemaining()
    return self.cooldownRemaining or 0
end

--- Alterna a visualização da prévia.
function ConeSlash:togglePreview()
    self.visual.preview.active = not self.visual.preview.active
end

--- Retorna se a prévia está ativa.
---@return boolean
function ConeSlash:getPreview()
    return self.visual.preview.active
end

return ConeSlash
