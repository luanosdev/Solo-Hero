-------------------------------------------------------
-- Arrow Projectile Ability
-- A habilidade ArrowProjectile é uma habilidade de projétil de flecha que atira flechas em um ângulo e alcance específicos.
-------------------------------------------------------

local Arrow = require("src.projectiles.arrow")
local ManagerRegistry = require("src.managers.manager_registry")

---@class ArrowProjectile
---@field visual table Configurações visuais da habilidade.
---@field currentPosition table Posição atual de origem dos disparos {x, y}.
---@field currentAngle number Ângulo base atual para o disparo (em radianos).
---@field currentRange number Alcance final das flechas, afetado por stats.
---@field currentAngleWidth number Largura do ângulo de dispersão para múltiplos projéteis (afetado por stats de área, se aplicável, ou fixo).
---@field currentPreviewLength number Comprimento da linha de preview.
---@field cooldownRemaining number Tempo restante para o próximo uso.
---@field activeArrows table Tabela de instâncias ativas de Arrow.
---@field baseDamage number Dano base da arma (não usado diretamente para flechas, weaponDamage de finalStats é usado).
---@field baseCooldown number Cooldown base da habilidade.
---@field baseRange number Alcance base da habilidade/arma.
---@field baseAngleWidth number Largura do ângulo de dispersão base para múltiplos projéteis.
---@field baseProjectiles number Número base de projéteis por disparo.
---@field basePiercing number Perfuração base fornecida pela arma (antes de bônus de stats).
---@field playerManager PlayerManager Referência ao gerenciador do jogador.
---@field weaponInstance BaseWeapon Referência à instância da arma que usa esta habilidade.
---@field pooledArrows table Tabela para flechas reutilizáveis.
local ArrowProjectile = {}
ArrowProjectile.__index = ArrowProjectile

-- Configurações Visuais
ArrowProjectile.visual = {
    preview = {
        active = false,
        -- color será definido no :new
    },
    attack = {
        arrowSpeed = 450, -- Velocidade padrão das flechas (pixels por segundo)
        -- color será definido no :new
        -- Define o ângulo máximo de dispersão para múltiplas flechas (em radianos)
        -- Ex: math.rad(30) para um leque total de 30 graus se houver muitas flechas.
        maxTotalSpreadAngle = math.rad(20)
    }
}

--- Cria uma nova instância da habilidade ArrowProjectile.
---@param playerManager PlayerManager
---@param weaponInstance BaseWeapon Instância da arma (Bow) que está usando esta habilidade.
function ArrowProjectile:new(playerManager, weaponInstance)
    local o = setmetatable({}, ArrowProjectile)

    o.playerManager = playerManager
    o.weaponInstance = weaponInstance
    o.cooldownRemaining = 0
    o.activeArrows = {} -- Tabela para guardar as flechas ativas
    o.pooledArrows = {} -- NOVA TABELA para flechas reutilizáveis

    local baseData = o.weaponInstance:getBaseData()
    if not baseData then
        error(string.format("ArrowProjectile:new - Falha ao obter dados base para %s",
            o.weaponInstance.itemBaseId or "arma desconhecida"))
    end

    o.baseDamage = baseData.damage -- Guardado mas finalStats.weaponDamage é o que será usado por flecha
    o.baseCooldown = baseData.cooldown
    o.baseRange = baseData.range
    o.baseAngleWidth = baseData.angle -- Usado para calcular a dispersão dos projéteis
    o.baseProjectiles = baseData.projectiles
    -- Assume que a arma tem um atributo 'piercing'. Se não, padrão 1 (atinge 1 e para).
    -- Este valor pode ser 0 se a flecha deve parar no primeiro inimigo sem bônus de força.
    -- Para balanceamento, sugiro que arcos tenham piercing base >= 1.
    o.basePiercing = baseData.piercing or 1

    o.visual.preview.color = o.weaponInstance.previewColor or { 0.7, 0.7, 0.7, 0.2 }
    o.visual.attack.color = o.weaponInstance.attackColor or { 0.2, 0.8, 0.2, 0.7 }

    o.currentPosition = { x = 0, y = 0 }
    o.currentAngle = 0
    -- Valores atuais serão calculados no update com base nos finalStats
    o.currentRange = o.baseRange
    o.currentAngleWidth = o.baseAngleWidth -- Este será o 'maxTotalSpreadAngle' efetivo
    o.currentPreviewLength = o.currentRange / 2

    print("[ArrowProjectile:new] Instância criada.")
    return o
end

function ArrowProjectile:update(dt, angle)
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    if self.playerManager and self.playerManager.player and self.playerManager.player.position then
        self.currentPosition = self.playerManager.player.position
    else
        -- Não dar erro fatal, mas logar e talvez impedir disparos se a posição não for conhecida
        -- print("AVISO [ArrowProjectile:update]: Posição do jogador não disponível.")
        -- self.currentPosition = {x = 0, y = 0} -- Fallback ou manter a última conhecida
        return -- Impede atualização se não há jogador
    end
    self.currentAngle = angle

    local finalStats = self.playerManager:getCurrentFinalStats()
    if not finalStats then
        -- print("AVISO [ArrowProjectile:update]: finalStats não disponíveis.")
        return -- Impede atualização se não há stats
    end

    -- Multiplicador de alcance de finalStats (ex: 1.1 para +10%)
    local rangeMultiplier = finalStats.range or 1
    self.currentRange = self.baseRange * rangeMultiplier

    -- Multiplicador de área de finalStats (ex: 1.2 para +20% de área/tamanho)
    -- Este `attackArea` do `finalStats` será o `areaScale` para a flecha.
    -- O `currentAngleWidth` para dispersão é diferente, usaremos `maxTotalSpreadAngle` da config visual.
    -- Se quisermos que `attackArea` influencie a dispersão, essa lógica precisaria ser adicionada aqui.
    -- Por ora, a dispersão é controlada por `maxTotalSpreadAngle`.

    self.currentPreviewLength = self.currentRange and (self.currentRange / 2)

    for i = #self.activeArrows, 1, -1 do
        local arrow = self.activeArrows[i]
        arrow:update(dt)
        if not arrow.isActive then
            table.remove(self.activeArrows, i)
            table.insert(self.pooledArrows, arrow) -- ADICIONADO: Move para o pool
        end
    end
end

function ArrowProjectile:cast(args)
    args = args or {}

    if self.cooldownRemaining > 0 then
        return false
    end

    local finalStats = self.playerManager:getCurrentFinalStats()
    if not finalStats then
        -- print("ERRO [ArrowProjectile:cast]: finalStats não disponíveis. Não é possível disparar.")
        return false
    end

    local totalAttackSpeed = finalStats.attackSpeed or 1
    if totalAttackSpeed <= 0 then totalAttackSpeed = 0.01 end
    self.cooldownRemaining = (self.baseCooldown or 1) / totalAttackSpeed

    -- Cálculo de Flechas (MultiAttack)
    local baseProjectilesActual = self.baseProjectiles or 1
    local currentMultiAttackChance = finalStats.multiAttackChance or 0
    local extraArrowsInteger = math.floor(currentMultiAttackChance)
    local decimalChanceForExtra = currentMultiAttackChance - extraArrowsInteger
    local totalArrows = baseProjectilesActual + extraArrowsInteger
    if decimalChanceForExtra > 0 and math.random() < decimalChanceForExtra then
        totalArrows = totalArrows + 1
    end

    if totalArrows <= 0 then
        -- print(string.format("[ArrowProjectile:cast] AVISO: totalArrows calculado é zero ou negativo (%s). Nenhum projétil disparado.", totalArrows))
        return false
    end

    -- Dano, Crítico
    local damagePerArrow = finalStats.weaponDamage or 10 -- Padrão baixo se weaponDamage for nil
    local criticalChance = finalStats.critChance or 0
    local criticalMultiplier = finalStats.critDamage or 1.5

    -- Área de Efeito (para escala da flecha)
    local areaScaleMultiplier = finalStats.attackArea or 1

    -- Perfuração
    -- Fator de conversão: quantos pontos de 'strength' para +1 piercing.
    -- Exemplo: 10 de strength = +1 piercing. Ajuste conforme necessário para balanceamento.
    local STRENGTH_TO_PIERCING_FACTOR = 0.1 -- (1 / 10)
    local strengthBonusPiercing = 0
    if finalStats.strength and finalStats.strength > 0 then
        strengthBonusPiercing = math.floor(finalStats.strength * STRENGTH_TO_PIERCING_FACTOR)
    end
    local currentPiercing = (self.basePiercing or 1) + strengthBonusPiercing

    -- Alcance (já calculado e armazenado em self.currentRange)
    local currentArrowRange = self.currentRange

    -- Ângulos para Múltiplas Flechas
    local arrowAngles = {}
    if totalArrows == 1 then
        table.insert(arrowAngles, self.currentAngle) -- Flecha única vai no ângulo central
    else
        local actualSpreadAngle = self.visual.attack.maxTotalSpreadAngle
        -- Se a arma tiver um baseAngleWidth, podemos usá-lo para modificar o spread?
        -- Por ora, vamos usar um fixed maxTotalSpreadAngle da visual config.
        -- Se quisermos que finalStats.attackArea aumente o leque, essa lógica entraria aqui.

        local angleStep = actualSpreadAngle / (totalArrows - 1)
        local startAngleOffset = -actualSpreadAngle / 2

        for i = 0, totalArrows - 1 do
            table.insert(arrowAngles, self.currentAngle + startAngleOffset + (i * angleStep))
        end
    end

    local enemyManager = ManagerRegistry:get("enemyManager")
    local spatialGrid = enemyManager and enemyManager.spatialGrid
    if not spatialGrid then
        -- print("AVISO [ArrowProjectile:cast]: spatialGrid não encontrado. Flechas podem não colidir corretamente.")
        -- Continuar sem spatialGrid é uma opção, mas a colisão da flecha falhará ou será ineficiente.
    end

    for _, arrowAngle in ipairs(arrowAngles) do
        local isCritical = math.random() <= criticalChance
        local finalDamageThisArrow = damagePerArrow
        if isCritical then
            finalDamageThisArrow = math.floor(finalDamageThisArrow * criticalMultiplier)
        end

        local arrowInstance = nil
        if #self.pooledArrows > 0 then
            -- Reutiliza uma flecha do pool
            arrowInstance = table.remove(self.pooledArrows)
            arrowInstance:reset(
                self.currentPosition.x,
                self.currentPosition.y,
                arrowAngle,
                self.visual.attack.arrowSpeed,
                currentArrowRange,
                finalDamageThisArrow,
                isCritical,
                spatialGrid,
                self.visual.attack.color,
                currentPiercing,
                areaScaleMultiplier
            )
            -- print("Flecha REUTILIZADA do pool. Pool size: " .. #self.pooledArrows)
        else
            -- Cria uma nova flecha se o pool estiver vazio
            arrowInstance = Arrow:new(
                self.currentPosition.x,
                self.currentPosition.y,
                arrowAngle,
                self.visual.attack.arrowSpeed,
                currentArrowRange,
                finalDamageThisArrow,
                isCritical,
                spatialGrid,
                self.visual.attack.color,
                currentPiercing,
                areaScaleMultiplier
            )
            -- print("Nova flecha CRIADA. Pool size: " .. #self.pooledArrows)
        end
        table.insert(self.activeArrows, arrowInstance)
    end

    return true
end

function ArrowProjectile:draw()
    if self.visual.preview.active then
        -- Usa self.currentAngle (ângulo central) e self.currentPreviewLength para a linha.
        -- Para o cone, usa o maxTotalSpreadAngle da configuração visual, não o baseAngleWidth.
        self:drawPreviewLine(self.visual.preview.color, self.currentAngle, self.currentPreviewLength)
        self:drawPreviewCone(self.visual.preview.color, self.currentAngle, self.currentPreviewLength,
            self.visual.attack.maxTotalSpreadAngle)
    end

    for _, arrow in ipairs(self.activeArrows) do
        arrow:draw()
    end
end

--- Desenha a linha de preview.
---@param color table Cor da linha.
---@param angle number Ângulo da linha.
---@param length number Comprimento da linha.
function ArrowProjectile:drawPreviewLine(color, angle, length)
    if not length or length <= 0 or not self.currentPosition then return end

    love.graphics.setColor(color)
    love.graphics.line(
        self.currentPosition.x,
        self.currentPosition.y,
        self.currentPosition.x + math.cos(angle) * length,
        self.currentPosition.y + math.sin(angle) * length
    )
end

--- Desenha o cone de preview.
---@param color table Cor do cone.
---@param centerAngle number Ângulo central do cone.
---@param length number Comprimento das linhas do cone.
---@param spreadAngleTotal number Largura total do ângulo do cone.
function ArrowProjectile:drawPreviewCone(color, centerAngle, length, spreadAngleTotal)
    if not length or length <= 0 or not spreadAngleTotal or spreadAngleTotal <= 0 or not self.currentPosition then
        return
    end

    love.graphics.setColor(color)
    local cx, cy = self.currentPosition.x, self.currentPosition.y
    local startAngle = centerAngle - spreadAngleTotal / 2
    local endAngle = centerAngle + spreadAngleTotal / 2

    love.graphics.line(cx, cy, cx + length * math.cos(startAngle), cy + length * math.sin(startAngle))
    love.graphics.line(cx, cy, cx + length * math.cos(endAngle), cy + length * math.sin(endAngle))

    -- Opcional: desenhar um arco para fechar o cone
    -- local segments = math.ceil(spreadAngleTotal / math.rad(5)) -- Ex: 1 segmento a cada 5 graus
    -- love.graphics.arc("line", "open", cx, cy, length, startAngle, endAngle, segments)

    love.graphics.setColor(1, 1, 1, 1)
end

function ArrowProjectile:getCooldownRemaining()
    return self.cooldownRemaining or 0
end

function ArrowProjectile:togglePreview()
    self.visual.preview.active = not self.visual.preview.active
end

function ArrowProjectile:getPreview()
    return self.visual.preview.active
end

return ArrowProjectile
