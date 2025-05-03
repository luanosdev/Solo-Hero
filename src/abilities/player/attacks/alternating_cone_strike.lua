--[[----------------------------------------------------------------------------
    Alternating Cone Strike Ability
    Um ataque em cone rápido que atinge alternadamente a metade esquerda ou direita.
    Refatorado para receber weaponInstance e buscar stats dinamicamente.
----------------------------------------------------------------------------]] --

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

-- Função auxiliar para normalizar ângulos para [-pi, pi]
local function normalizeAngle(angle)
    return (angle + math.pi) % (2 * math.pi) - math.pi
end

--- Cria uma nova instância da habilidade AlternatingConeStrike.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param weaponInstance BaseWeapon Instância da arma que está usando esta habilidade.
function AlternatingConeStrike:new(playerManager, weaponInstance)
    local o = setmetatable({}, self)
    print("[AlternatingConeStrike:new] Creating instance...")

    if not playerManager or not weaponInstance then
        error("AlternatingConeStrike:new - playerManager e weaponInstance são obrigatórios.")
        return nil
    end

    o.playerManager = playerManager
    o.weaponInstance = weaponInstance -- Armazena a instância da arma

    o.cooldownRemaining = 0
    o.isAttacking = false
    o.attackProgress = 0
    o.hitLeftNext = true        -- Começa atacando pela esquerda
    o.lastAttackWasLeft = false -- Para saber qual metade desenhar

    -- Busca cores da weaponInstance (sobrescreve os padrões)
    o.visual.preview.color = weaponInstance.previewColor or o.visual.preview.color
    o.visual.attack.color = weaponInstance.attackColor or o.visual.attack.color
    print("  - Preview/Attack colors set (using weaponInstance if available).")

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
        print("  - WARN: Player sprite not yet available for initial position.")
    end

    -- REMOVIDO: Stats não são mais armazenados aqui
    -- o.baseDamage = weapon.damage
    -- o.baseCooldown = weapon.cooldown

    print("[AlternatingConeStrike:new] Instance created successfully.")
    return o
end

-- REMOVIDO: :init não é mais necessário, lógica movida para :new
-- function AlternatingConeStrike:init(playerManager) ... end

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

        -- !!! CALCULA PARÂMETROS DA ÁREA AQUI, UMA VEZ POR FRAME !!!
        local baseData = self.weaponInstance:getBaseData()
        local weaponBaseRange = (baseData and baseData.range) or 50
        local weaponBaseAngle = (baseData and baseData.angle) or (math.pi / 3)
        local rangeBonusPercent = self.playerManager.state:getTotalRange()
        local areaBonusPercent = self.playerManager.state:getTotalArea()
        local newRange = weaponBaseRange * (1 + rangeBonusPercent)
        local newAngleWidth = weaponBaseAngle * (1 + areaBonusPercent)

        -- Atualiza apenas se mudou (otimização)
        if newRange ~= self.area.range or newAngleWidth ~= self.area.angleWidth then
            self.area.range = newRange
            self.area.angleWidth = newAngleWidth
            self.area.halfWidth = self.area.angleWidth / 2
            print(string.format("  [UPDATE] Area Recalculated. Range: %.1f | AngleWidth: %.2f", self.area.range,
                self.area.angleWidth)) -- Log na atualização
        end
    end

    -- Atualiza animação do ataque
    if self.isAttacking then
        self.attackProgress = self.attackProgress + (dt / self.visual.attack.animationDuration)
        if self.attackProgress >= 1 then
            self.isAttacking = false
            self.attackProgress = 0
        end
    end
end

--- Tenta executar o ataque.
---@param args table Argumentos opcionais (não usado atualmente).
---@return boolean True se o ataque foi iniciado (mesmo que não acerte), False se estava em cooldown.
function AlternatingConeStrike:cast(args)
    args = args or {}

    if self.cooldownRemaining > 0 then
        return false -- Em cooldown
    end
    print("[AlternatingConeStrike:cast] Casting attack.")

    -- Determina qual lado atacar NESTE cast
    local attackLeftThisCast = self.hitLeftNext

    -- Inicia a animação (sempre mostra a animação do PRIMEIRO golpe do cast)
    self.isAttacking = true
    self.attackProgress = 0
    self.lastAttackWasLeft = attackLeftThisCast -- Para o draw
    print(string.format("  - Attacking %s side first.", attackLeftThisCast and "LEFT" or "RIGHT"))

    -- Aplica o cooldown baseado no attackSpeed TOTAL do jogador
    local totalAttackSpeed = self.playerManager.state:getTotalAttackSpeed()
    local baseData = self.weaponInstance:getBaseData()
    local baseCooldown = (baseData and baseData.cooldown) or 1.0 -- Padrão 1s
    if totalAttackSpeed <= 0 then totalAttackSpeed = 1 end       -- Evita divisão por zero
    self.cooldownRemaining = baseCooldown / totalAttackSpeed
    print(string.format("  - Cooldown set to %.2fs (Base: %.2f / TotalAS: %.2f)", self.cooldownRemaining, baseCooldown,
        totalAttackSpeed))

    -- Calcula ataques extras
    local multiAttackChance = self.playerManager.state:getTotalMultiAttackChance()
    local extraAttacks = math.floor(multiAttackChance)
    local decimalChance = multiAttackChance - extraAttacks
    print(string.format("  - Multi-Attack Chance: %.2f (Extra: %d + %.2f%%)", multiAttackChance, extraAttacks,
        decimalChance * 100))

    -- Executa o PRIMEIRO ataque
    local success = self:executeAttack(attackLeftThisCast)
    local currentHitIsLeft = attackLeftThisCast -- Variável para alternar nos extras

    -- Executa ataques extras inteiros, alternando a CADA extra
    for i = 1, extraAttacks do
        if success then                             -- Só continua se o anterior (hipoteticamente) teve sucesso
            currentHitIsLeft = not currentHitIsLeft -- Alterna para o próximo extra
            print(string.format("    - Executing extra attack #%d (%s side)", i, currentHitIsLeft and "LEFT" or "RIGHT"))
            success = self:executeAttack(currentHitIsLeft)
        else
            print("    - Stopping extra attacks due to previous failure.")
            break
        end
    end

    -- Chance de ataque extra decimal, também alterna
    if success and decimalChance > 0 and math.random() < decimalChance then
        currentHitIsLeft = not currentHitIsLeft -- Alterna para este extra
        print(string.format("    - Executing decimal chance extra attack (%s side)",
            currentHitIsLeft and "LEFT" or "RIGHT"))
        self:executeAttack(currentHitIsLeft)
    end

    -- IMPORTANTE: Alterna o estado APENAS UMA VEZ no final, preparando o PRÓXIMO cast
    self.hitLeftNext = not self.hitLeftNext
    print(string.format("  - Next cast will start on %s side.", self.hitLeftNext and "LEFT" or "RIGHT"))

    return true -- Retorna true porque o cast foi iniciado
end

--- Executa a lógica de um único golpe em uma metade específica.
---@param hitLeft boolean True para atacar a metade esquerda, False para a direita.
---@return boolean Sempre retorna true (indica que a tentativa de ataque foi feita).
function AlternatingConeStrike:executeAttack(hitLeft)
    local enemies = self.playerManager.enemyManager:getEnemies()
    local enemiesHitCount = 0
    local side = hitLeft and "LEFT" or "RIGHT"
    -- print(string.format("    [executeAttack - %s] Checking %d enemies.", side, #enemies))

    for i, enemy in ipairs(enemies) do
        if enemy.isAlive then
            -- Verifica se o inimigo está na metade correta do cone
            if self:isPointInCorrectHalf(enemy.position, hitLeft) then
                enemiesHitCount = enemiesHitCount + 1
                -- print(string.format("      - Hitting enemy #%d at (%.1f, %.1f) on %s side.", i, enemy.position.x, enemy.position.y, side))
                self:applyDamage(enemy) -- Aplica o dano (a checagem de área já foi feita)
                -- else
                -- local dx = enemy.position.x - self.area.position.x
                -- local dy = enemy.position.y - self.area.position.y
                -- local dist = math.sqrt(dx*dx+dy*dy)
                -- local pAng = math.atan2(dy, dx)
                -- local relAng = normalizeAngle(pAng - self.area.angle)
                -- print(string.format("      - Enemy #%d MISSED %s side. Dist: %.1f, RelAngle: %.2f (Limit: %.2f)", i, side, dist, relAng, self.area.halfWidth))
            end
        end
    end
    if enemiesHitCount > 0 then
        print(string.format("    [executeAttack - %s] Hit %d enemies.", side, enemiesHitCount))
    end

    return true -- Retorna true mesmo se não atingiu ninguém
end

--- Verifica se um ponto está DENTRO do cone TOTAL.
---@param position table Posição {x, y} a verificar.
---@return boolean True se o ponto está na área total.
function AlternatingConeStrike:isPointInArea(position)
    if not self.area then return false end
    -- REMOVIDO: self:updateAreaIfNeeded() -- Usa valores já calculados em update

    local dx = position.x - self.area.position.x
    local dy = position.y - self.area.position.y
    local distanceSq = dx * dx + dy * dy -- Usa quadrado para evitar sqrt

    -- Verifica distância (mais rápido)
    if distanceSq == 0 or distanceSq > (self.area.range * self.area.range) then return false end

    -- Verifica ângulo
    local pointAngle = math.atan2(dy, dx)
    local relativeAngle = normalizeAngle(pointAngle - self.area.angle)

    return math.abs(relativeAngle) <= self.area.halfWidth
end

--- Verifica se um ponto está na METADE ESPECÍFICA do cone.
---@param position table Posição {x, y} a verificar.
---@param checkLeft boolean True para verificar a metade esquerda, False para a direita.
---@return boolean True se o ponto está na metade correta.
function AlternatingConeStrike:isPointInCorrectHalf(position, checkLeft)
    if not self.area then return false end
    -- REMOVIDO: self:updateAreaIfNeeded() -- Usa valores já calculados em update

    local dx = position.x - self.area.position.x
    local dy = position.y - self.area.position.y
    local distanceSq = dx * dx + dy * dy -- Usa quadrado

    -- Verifica distância (mais rápido)
    if distanceSq == 0 or distanceSq > (self.area.range * self.area.range) then return false end

    -- Verifica ângulo
    local pointAngle = math.atan2(dy, dx)
    local relativeAngle = normalizeAngle(pointAngle - self.area.angle)

    if checkLeft then -- Checa metade esquerda (ângulo relativo entre -halfWidth e 0)
        return relativeAngle >= -self.area.halfWidth and relativeAngle <= 0
    else              -- Checa metade direita (ângulo relativo entre 0 e +halfWidth)
        return relativeAngle > 0 and relativeAngle <= self.area.halfWidth
    end
end

--- Aplica dano a um alvo.
---@param target BaseEnemy Instância do inimigo a ser atingido.
---@return boolean Resultado de target:takeDamage.
function AlternatingConeStrike:applyDamage(target)
    -- Busca o dano base da arma ATUALMENTE
    local baseData = self.weaponInstance:getBaseData()
    local weaponBaseDamage = (baseData and baseData.damage) or 0

    -- Calcula o dano total usando o estado ATUAL do jogador
    local totalDamage = self.playerManager.state:getTotalDamage(weaponBaseDamage) -- Passa o base da arma

    -- Calcula se o dano é crítico
    local isCritical = math.random() <= self.playerManager.state:getTotalCritChance() / 100
    if isCritical then
        totalDamage = math.floor(totalDamage * self.playerManager.state:getTotalCritDamage())
    end

    -- Aplica o dano
    -- print(string.format("      Applying %d damage (%s) to target.", totalDamage, isCritical and "CRIT" or "normal"))
    return target:takeDamage(totalDamage, isCritical)
end

--- Desenha os elementos visuais da habilidade.
function AlternatingConeStrike:draw()
    if not self.area then return end

    -- Desenha a prévia da linha se ativa (mostra o cone inteiro)
    if self.visual.preview.active then
        self:drawConeOutline(self.visual.preview.color) -- Usa cor da instância
    end

    -- Desenha a animação do ataque (apenas a metade ativa)
    if self.isAttacking then
        -- USA A VERSÃO *SEM* innerRange por enquanto, até restaurarmos no próximo passo
        self:drawHalfConeFill(self.visual.attack.color, self.attackProgress, self.lastAttackWasLeft)
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

--- Desenha o PREENCHIMENTO de METADE do cone (para ataque).
--- RESTAURADO: Usa innerRange novamente.
---@param color table Cor RGBA a ser usada.
---@param progress number Progresso da animação (0 a 1), pode ser usado para fade in/out.
---@param drawLeft boolean True para desenhar a metade esquerda, False para a direita.
function AlternatingConeStrike:drawHalfConeFill(color, progress, drawLeft)
    if not self.area or self.area.range <= 0 then return end
    -- Não chama mais updateAreaIfNeeded()
    local segments = 16
    -- RESTAURADO: Define o raio interno para desenhar um anel de setor
    local innerRange = (self.playerManager.player and self.playerManager.player.radius or 10) * 1.5

    local alpha = color[4] or 1.0
    local currentAlpha = alpha * (1 - progress)
    love.graphics.setColor(color[1], color[2], color[3], currentAlpha)

    local cx, cy = self.area.position.x, self.area.position.y
    local range = self.area.range

    local startAngle, endAngle
    if drawLeft then
        startAngle = self.area.angle - self.area.halfWidth
        endAngle = self.area.angle
    else
        startAngle = self.area.angle
        endAngle = self.area.angle + self.area.halfWidth
    end

    -- Cria os vértices para o polígono preenchido (formato de ANEL DE SETOR)
    local vertices = {}

    -- Vértices do arco externo (do início ao fim)
    for i = 0, segments do
        local angle = startAngle + (endAngle - startAngle) * (i / segments)
        table.insert(vertices, cx + range * math.cos(angle)) -- Insere X externo
        table.insert(vertices, cy + range * math.sin(angle)) -- Insere Y externo
    end
    -- Vértices do arco interno (do fim para o início)
    for i = segments, 0, -1 do
        local angle = startAngle + (endAngle - startAngle) * (i / segments)
        table.insert(vertices, cx + innerRange * math.cos(angle)) -- Insere X interno
        table.insert(vertices, cy + innerRange * math.sin(angle)) -- Insere Y interno
    end

    -- Desenha o polígono preenchido se tivermos pelo menos 3 pontos (6 coordenadas)
    if #vertices >= 6 then
        love.graphics.polygon("fill", unpack(vertices))
    end
    love.graphics.setColor(1, 1, 1, 1) -- Reseta cor
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

-- return setmetatable(AlternatingConeStrike, {__index = require("src.abilities.player.attacks.cone_slash")}) -- Herda de ConeSlash? Não, melhor não herdar diretamente.
return AlternatingConeStrike
