--[[----------------------------------------------------------------------------
    Chain Lightning Ability
    Dispara um raio que salta entre inimigos próximos.
----------------------------------------------------------------------------]] --

---@class ChainLightning
local ChainLightning = {}
ChainLightning.__index = ChainLightning

-- Configurações
ChainLightning.name = "Corrente Elétrica"
ChainLightning.description = "Um raio que atinge um inimigo e salta para outros próximos."
ChainLightning.damageType = "lightning" -- ou 'energy'
ChainLightning.visual = {
    preview = {
        active = false,
        -- Preview poderia mostrar o alcance inicial?
    },
    attack = {
        segmentDuration = 0.15, -- Quanto tempo cada segmento do raio fica visível
        thickness = 3           -- Espessura da linha do raio
        -- color será definido no :new
    }
}

--- Cria uma nova instância da habilidade ChainLightning.
---@param playerManager PlayerManager
---@param weaponInstance BaseWeapon Instância da arma (ChainLaser) que está usando esta habilidade.
function ChainLightning:new(playerManager, weaponInstance)
    local o = setmetatable({}, ChainLightning)

    o.playerManager = playerManager
    o.weaponInstance = weaponInstance
    o.cooldownRemaining = 0
    o.activeChains = {} -- Tabela para guardar informações das correntes de raios ativas (para desenho)

    -- Busca dados base da arma
    local baseData = o.weaponInstance:getBaseData()
    if not baseData then
        error(string.format("ChainLightning:new - Falha ao obter dados base para %s",
            o.weaponInstance.itemBaseId or "arma desconhecida"))
        return nil
    end
    o.baseDamage = baseData.damage
    o.baseCooldown = baseData.cooldown
    o.baseRange = baseData.range                -- Alcance para o primeiro alvo
    o.baseChainCount = baseData.chainCount      -- Número MÁXIMO de saltos adicionais
    o.baseJumpRange = baseData.jumpRange        -- Distância MÁXIMA para saltar
    o.baseThickness = o.visual.attack.thickness -- Armazena a espessura base

    -- Define cores (usando as da arma ou padrão)
    o.visual.preview.color = o.weaponInstance.previewColor or { 0.2, 0.8, 1, 0.2 }
    o.visual.attack.color = o.weaponInstance.attackColor or { 0.5, 1, 1, 0.9 }

    -- Inicializa valores que serão atualizados no update
    o.currentPosition = { x = 0, y = 0 }
    -- currentAngle não é usado diretamente para mirar, mas pode ser útil saber a direção do jogador
    o.currentAngle = 0
    o.currentRange = o.baseRange
    o.currentJumpRange = o.baseJumpRange
    o.currentThickness = o.baseThickness -- Inicializa a espessura atual

    print("[ChainLightning:new] Instância criada.")
    return o
end

function ChainLightning:update(dt, angle)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza posição e ângulo (pode não ser necessário para mira, mas útil ter)
    self.currentPosition = self.playerManager.player.position
    self.currentAngle = angle

    -- Obtem bônus do jogador (Range e Area podem afetar o raio inicial e o salto?)
    local state = self.playerManager.state
    local rangeBonus = state:getTotalRange()
    local areaBonus = state:getTotalArea() -- Poderia aumentar o jumpRange?

    -- Calcula valores FINAIS para este frame
    self.currentRange = self.baseRange * (1 + rangeBonus)
    -- Decisão: O bônus de área aumenta o alcance do salto? Vamos assumir que sim por enquanto.
    self.currentJumpRange = self.baseJumpRange * (1 + areaBonus)
    -- Calcula a espessura atual do laser
    self.currentThickness = self.baseThickness * (1 + areaBonus)

    -- Atualiza a duração dos raios visíveis
    for i = #self.activeChains, 1, -1 do
        local chain = self.activeChains[i]
        chain.duration = chain.duration - dt
        if chain.duration <= 0 then
            table.remove(self.activeChains, i)
        end
    end
end

--- Encontra o inimigo mais próximo dentro de um raio a partir de um ponto.
--- Exclui inimigos cujos IDs estão na tabela `excludedIDs`.
---@param centerX number Posição X do centro da busca.
---@param centerY number Posição Y do centro da busca.
---@param radius number Raio máximo da busca.
---@param excludedIDs table Tabela com IDs de inimigos a serem ignorados { [id] = true }.
---@return table? Instância do inimigo encontrado ou nil.
function ChainLightning:findClosestEnemy(centerX, centerY, radius, excludedIDs)
    -- Tenta usar getEnemiesInRange se existir, senão usa getEnemies e filtra
    local enemies
    if self.playerManager.enemyManager.getEnemiesInRange then
        enemies = self.playerManager.enemyManager:getEnemiesInRange(centerX, centerY, radius)
    else
        enemies = self.playerManager.enemyManager:getEnemies()
    end

    local closestEnemy = nil
    local minDistanceSq = radius * radius + 1 -- Inicia com distância maior que o raio

    for id, enemy in pairs(enemies) do
        -- Verifica se o inimigo está vivo e não está na lista de exclusão
        if enemy.isAlive and (not excludedIDs or not excludedIDs[id]) then
            local dx = enemy.position.x - centerX
            local dy = enemy.position.y - centerY
            local distSq = dx * dx + dy * dy

            -- Verifica se está dentro do raio e é mais próximo que o anterior
            if distSq <= radius * radius and distSq < minDistanceSq then
                -- Adiciona checagem adicional se getEnemiesInRange não foi usado
                if not self.playerManager.enemyManager.getEnemiesInRange then
                    if distSq > radius * radius then -- Garante que está dentro do raio se filtramos manualmente
                        goto continue                -- Pula para a próxima iteração (Lua 5.2+)
                    end
                end
                minDistanceSq = distSq
                closestEnemy = enemy
            end
        end
        ::continue:: -- Label para goto (Lua 5.2+)
    end
    return closestEnemy
end

function ChainLightning:cast(args)
    args = args or {}

    if self.cooldownRemaining > 0 then
        return false
    end

    local state = self.playerManager.state

    -- Aplica o cooldown
    local attackSpeed = state:getTotalAttackSpeed()
    self.cooldownRemaining = self.baseCooldown / attackSpeed

    -- Calcula stats no momento do disparo
    local damagePerHit = state:getTotalDamage(self.baseDamage)
    local criticalChance = state:getTotalCritChance()
    local criticalMultiplier = state:getTotalCritDamage()

    -- Lógica do Chain Lightning
    local targetsHit = {}   -- Guarda os inimigos atingidos nesta corrente { [id] = enemyInstance }
    local hitPositions = {} -- Guarda as posições dos alvos para desenhar a linha
    local excludedIDs = {}  -- Guarda IDs dos inimigos já atingidos para não saltar para o mesmo

    -- 1. Encontra o primeiro alvo (mais próximo do jogador dentro do range inicial)
    local firstTarget = self:findClosestEnemy(self.currentPosition.x, self.currentPosition.y, self.currentRange, nil)

    if not firstTarget then
        -- print("ChainLightning: Nenhum alvo inicial encontrado.")
        return false -- Não faz nada se não achar o primeiro alvo
    end

    local currentTarget = firstTarget
    table.insert(hitPositions, { x = self.currentPosition.x, y = self.currentPosition.y }) -- Posição inicial (jogador)
    table.insert(hitPositions, { x = currentTarget.position.x, y = currentTarget.position.y })
    targetsHit[currentTarget.id] = currentTarget
    excludedIDs[currentTarget.id] = true

    -- 2. Encontra alvos subsequentes (saltos)
    local jumpsRemaining = self.baseChainCount
    while jumpsRemaining > 0 do
        local lastHitPosition = currentTarget.position
        local nextTarget = self:findClosestEnemy(lastHitPosition.x, lastHitPosition.y, self.currentJumpRange, excludedIDs)

        if nextTarget then
            -- Encontrou o próximo alvo
            currentTarget = nextTarget
            table.insert(hitPositions, { x = currentTarget.position.x, y = currentTarget.position.y })
            targetsHit[currentTarget.id] = currentTarget
            excludedIDs[currentTarget.id] = true
            jumpsRemaining = jumpsRemaining - 1
        else
            -- Não encontrou mais alvos no alcance do salto
            break -- Interrompe a corrente
        end
    end

    -- 3. Aplica o dano a todos os alvos atingidos
    for id, enemy in pairs(targetsHit) do
        local isCritical = math.random() * 100 <= criticalChance
        local finalDamage = damagePerHit
        if isCritical then
            finalDamage = math.floor(finalDamage * criticalMultiplier)
        end
        enemy:takeDamage(finalDamage, isCritical)
    end

    -- 4. Adiciona a informação da corrente para desenho
    if #hitPositions > 1 then -- Só adiciona se atingiu pelo menos um inimigo
        table.insert(self.activeChains, {
            points = hitPositions,
            duration = self.visual.attack.segmentDuration,
            color = self.visual.attack.color,
            thickness = self.currentThickness -- Usa a espessura atual calculada
        })
    end

    -- print(string.format("ChainLightning: Atingiu %d alvos.", #hitPositions - 1))
    return true
end

function ChainLightning:draw()
    -- Desenha a prévia (um círculo de range inicial?)
    if self.visual.preview.active then
        self:drawPreviewCircle(self.visual.preview.color)
        -- Poderia desenhar um círculo menor para o jumpRange também
    end

    -- Desenha as correntes de raios ativas
    for _, chain in ipairs(self.activeChains) do
        love.graphics.setColor(chain.color)
        love.graphics.setLineWidth(chain.thickness)
        -- Desenha linhas conectando os pontos da corrente
        for i = 1, #chain.points - 1 do
            local p1 = chain.points[i]
            local p2 = chain.points[i + 1]
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
        end
    end
    love.graphics.setLineWidth(1)      -- Reseta a espessura da linha
    love.graphics.setColor(1, 1, 1, 1) -- Reseta a cor
end

function ChainLightning:drawPreviewCircle(color)
    love.graphics.setColor(color)
    love.graphics.circle("line", self.currentPosition.x, self.currentPosition.y, self.currentRange)
    -- Desenha círculo menor para jump range (a partir do jogador, só como referência)
    -- love.graphics.circle("line", self.currentPosition.x, self.currentPosition.y, self.currentJumpRange)
end

function ChainLightning:getCooldownRemaining()
    return self.cooldownRemaining or 0
end

function ChainLightning:togglePreview()
    self.visual.preview.active = not self.visual.preview.active
end

function ChainLightning:getPreview()
    return self.visual.preview.active
end

return ChainLightning -- GARANTIR QUE ESTA LINHA ESTEJA PRESENTE E CORRETA
