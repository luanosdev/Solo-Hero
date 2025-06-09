local TablePool = require("src.utils.table_pool")
local CombatHelpers = require("src.utils.combat_helpers")

-- Carrega o spritesheet e cria os Quads uma vez
local fireSheet = love.graphics.newImage("assets/attacks/fire_particle/fireSheet5x5.png")
local sheetWidth = fireSheet:getWidth()
local sheetHeight = fireSheet:getHeight()
local frameWidth = sheetWidth / 5
local frameHeight = sheetHeight / 5
local totalFrames = 25
local quads = {}
for row = 0, 4 do
    for col = 0, 4 do
        local frameIndex = row * 5 + col + 1
        quads[frameIndex] = love.graphics.newQuad(col * frameWidth, row * frameHeight, frameWidth, frameHeight,
            sheetWidth, sheetHeight)
    end
end

local animationFrameTime = 0.04 -- Tempo entre frames (ajuste para velocidade desejada)
local baseScale = 0.8           -- Fator de escala base padrão para a animação (se não fornecido pela arma/habilidade)

-- Novo fator de ajuste para o tamanho visual e de colisão da partícula.
-- Reduz o tamanho geral da partícula para melhor adequação à gameplay.
local PARTICLE_VISUAL_ADJUSTMENT_FACTOR = 0.6 -- Ex: 0.4 significa 40% do tamanho que teria antes.

-- Constantes para a nova lógica de colisão e crescimento
local BASE_HIT_LOSS = 0.8                 -- 80% de perda de vida base ao atingir
local PIERCING_REDUCTION_FACTOR = 0.01    -- Quanto cada ponto de piercing reduz a perda (ex: 1 piercing = 1% a menos de perda)
local MIN_HIT_LOSS = 0.2                  -- Perda mínima de vida ao atingir (20%)
local INITIAL_GROWTH_DURATION_RATIO = 0.1 -- 10% da vida inicial para crescimento
local INITIAL_SCALE_MULTIPLIER = 0.15     -- Nasce com 15% do tamanho final

local FireParticle = {}
FireParticle.__index = FireParticle

--- Constructor for FireParticle.
--- @param params table Table of parameters including:
---   x, y, angle, speed, lifetime, damage, isCritical, spatialGrid, color,
---   areaMultiplier, piercing, playerBaseScale, owner, playerManager, weaponInstance,
---   baseHitLoss, piercingReductionFactor, minHitLoss,
---   knockbackPower, knockbackForce, playerStrength
function FireParticle:new(params)
    local instance = setmetatable({}, FireParticle)

    instance.position = { x = params.x, y = params.y }
    instance.angle = params.angle
    instance.speed = params.speed
    instance.initialLifetime = params.lifetime -- Guarda o lifetime original para cálculos
    instance.lifetimeRemaining = params.lifetime
    instance.damage = params.damage
    instance.isCritical = params.isCritical
    instance.spatialGrid = params.spatialGrid
    instance.color = params.color or { 1, 1, 1, 1 }

    -- Novos atributos de colisão e arma
    instance.areaMultiplier = params.areaMultiplier or 1.0
    instance.piercing = params.piercing or 0
    instance.owner = params.owner
    instance.playerManager = params.playerManager
    instance.weaponInstance = params.weaponInstance
    instance.baseHitLoss = params.baseHitLoss or BASE_HIT_LOSS
    instance.piercingReductionFactor = params.piercingReductionFactor or PIERCING_REDUCTION_FACTOR
    instance.minHitLoss = params.minHitLoss or MIN_HIT_LOSS

    -- Knockback properties
    instance.knockbackPower = params.knockbackPower or 0
    instance.knockbackForce = params.knockbackForce or 0
    instance.playerStrength = params.playerStrength or 0

    -- Ajusta o playerBaseScale com o fator de ajuste visual global do módulo.
    -- Isso garante que as partículas de fogo tenham um tamanho base consistente com a gameplay,
    -- mesmo que a arma/habilidade forneça uma escala base.
    local effectivePlayerBaseScale = (params.playerBaseScale or baseScale) * PARTICLE_VISUAL_ADJUSTMENT_FACTOR
    instance.playerBaseScale = effectivePlayerBaseScale -- Armazena a escala base efetivamente usada

    -- Raio de colisão será dinâmico, calculado no update. Iniciamos com um valor pequeno.
    -- Usa effectivePlayerBaseScale para o cálculo inicial.
    instance.collisionRadius = (math.min(frameWidth, frameHeight) / 2) * INITIAL_SCALE_MULTIPLIER *
        instance.playerBaseScale * instance.areaMultiplier
    instance.currentScaleFactor = INITIAL_SCALE_MULTIPLIER -- Começa pequena

    instance.velocity = {
        x = math.cos(params.angle) * params.speed,
        y = math.sin(params.angle) * params.speed
    }

    instance.isActive = true
    instance.hitEnemies = {}

    -- Estado da Animação
    instance.animationTimer = 0
    instance.currentFrame = love.math.random(1, totalFrames)

    return instance
end

function FireParticle:update(dt)
    if not self.isActive then return end

    -- Atualiza tempo de vida ANTES de mover para ter o lifeRatio correto para o frame atual
    self.lifetimeRemaining = self.lifetimeRemaining - dt
    if self.lifetimeRemaining <= 0 then
        self.isActive = false
        return
    end

    -- Calcula o progresso da vida (0 = nova, 1 = morta)
    local lifeProgress = 1 - (self.lifetimeRemaining / self.initialLifetime)

    -- Lógica de crescimento inicial
    if lifeProgress <= INITIAL_GROWTH_DURATION_RATIO then
        -- Lerp de INITIAL_SCALE_MULTIPLIER para 1.0
        local growthProgress = lifeProgress / INITIAL_GROWTH_DURATION_RATIO
        self.currentScaleFactor = INITIAL_SCALE_MULTIPLIER + (1 - INITIAL_SCALE_MULTIPLIER) * growthProgress
    else
        self.currentScaleFactor = 1.0 -- Mantém o tamanho máximo após o crescimento inicial
    end

    -- Atualiza a escala visual e o raio de colisão
    -- O tamanho do sprite (frameWidth/Height) é a base, escalado por playerBaseScale,
    -- depois pelo areaMultiplier e finalmente pelo currentScaleFactor (crescimento/encolhimento).
    local dynamicScale = self.playerBaseScale * self.areaMultiplier * self.currentScaleFactor
    -- O raio de colisão deve corresponder à metade da menor dimensão do sprite escalado.
    -- Assumindo que frameWidth e frameHeight são representativos do "corpo" da partícula.
    self.collisionRadius = (math.min(frameWidth, frameHeight) / 2) * dynamicScale

    -- Move a partícula
    self.position.x = self.position.x + self.velocity.x * dt
    self.position.y = self.position.y + self.velocity.y * dt

    -- Atualiza Animação
    self.animationTimer = self.animationTimer + dt
    while self.animationTimer >= animationFrameTime do
        self.animationTimer = self.animationTimer - animationFrameTime
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > totalFrames then
            self.currentFrame = 1 -- Volta para o primeiro frame
        end
    end

    -- Verifica colisão com inimigos (e aplica dano)
    self:checkCollision()
end

function FireParticle:checkCollision()
    if not self.spatialGrid then
        -- print("AVISO [FireParticle:checkCollision]: spatialGrid não fornecido. Colisão não será verificada.")
        return
    end

    -- Define um raio de busca para o spatialGrid.
    -- Um pouco maior que o raio de colisão da partícula para garantir que inimigos próximos sejam capturados.
    local searchRadius = self.collisionRadius * 2.5 -- Exemplo: 2.5x o raio de colisão da partícula

    local nearbyEnemies = self.spatialGrid:getNearbyEntities(self.position.x, self.position.y, searchRadius, nil)

    -- for id, enemy in pairs(enemies) do -- ANTERIOR: iterava em todos os inimigos do enemyManager
    for _, enemy in ipairs(nearbyEnemies) do -- NOVO: itera sobre a lista do spatialGrid
        -- Garante que o inimigo tenha um ID (pode não ter em casos raros ou durante a criação)
        -- e que enemy.radius exista (importante para combinedRadius)
        if enemy and enemy.id and enemy.isAlive and enemy.radius then
            local dx = enemy.position.x - self.position.x
            local dy = enemy.position.y - self.position.y
            local distanceSq = dx * dx + dy * dy
            local combinedRadius = enemy.radius + self.collisionRadius -- Usa o collisionRadius atualizado

            -- Verifica colisão (círculo-círculo)
            if distanceSq <= combinedRadius * combinedRadius then
                -- Verifica se esta partícula já atingiu este inimigo
                if not self.hitEnemies[enemy.id] then
                    -- Aplicar Knockback ANTES de registrar o hit
                    if self.knockbackPower > 0 then
                        local dirX, dirY = 0, 0
                        local velocityMagnitude = math.sqrt(self.velocity.x ^ 2 + self.velocity.y ^ 2)
                        if velocityMagnitude > 0 then
                            dirX = self.velocity.x / velocityMagnitude
                            dirY = self.velocity.y / velocityMagnitude
                        else
                            -- Se a partícula está parada, calcula direção do centro da partícula para o inimigo
                            local dxP = enemy.position.x - self.position.x
                            local dyP = enemy.position.y - self.position.y
                            local distSqP = dxP * dxP + dyP * dyP
                            if distSqP > 0 then
                                local distP = math.sqrt(distSqP)
                                dirX = dxP / distP
                                dirY = dyP / distP
                            else -- Fallback para direção aleatória se sobrepostos
                                local randomAngle = math.random() * 2 * math.pi
                                dirX = math.cos(randomAngle)
                                dirY = math.sin(randomAngle)
                            end
                        end

                        CombatHelpers.applyKnockback(
                            enemy,                 -- targetEnemy
                            nil,                   -- attackerPosition (projétil usa override)
                            self.knockbackPower,   -- attackKnockbackPower
                            self.knockbackForce,   -- attackKnockbackForce
                            self.playerStrength,   -- playerStrength
                            { x = dirX, y = dirY } -- knockbackDirectionOverride
                        )
                        -- Não precisa mais marcar aqui, pois o helper não retorna se aplicou ou não para este caso
                    end

                    local killed = enemy:takeDamage(self.damage, self.isCritical)
                    self.hitEnemies[enemy.id] = true

                    -- Lógica de perda de vida da partícula devido à colisão
                    local effectiveHitLoss = math.max(MIN_HIT_LOSS,
                        self.baseHitLoss - (self.piercing * self.piercingReductionFactor))
                    local lifeToLose = self.lifetimeRemaining * effectiveHitLoss -- Perde % da vida RESTANTE
                    self.lifetimeRemaining = self.lifetimeRemaining - lifeToLose

                    if self.lifetimeRemaining <= 0 then
                        self.isActive = false
                        TablePool.release(nearbyEnemies) -- Libera a tabela antes de sair
                        return                           -- Partícula "morre" após esta colisão
                    end
                    -- A partícula continua (piercing), mas não atingirá este inimigo novamente.
                end
            end
        end
    end

    TablePool.release(nearbyEnemies) -- Libera a tabela do pool
end

function FireParticle:draw()
    if not self.isActive then return end

    -- Calcula a opacidade e escala baseado no tempo de vida restante e no crescimento
    local lifeRatio = math.max(0, self.lifetimeRemaining / self.initialLifetime)
    local currentAlpha = lifeRatio -- Fade out linear com a vida

    -- A escala agora é controlada por self.currentScaleFactor e self.areaMultiplier
    local finalVisualScale = self.playerBaseScale * self.areaMultiplier * self.currentScaleFactor

    -- Adiciona um pequeno encolhimento adicional no final da vida, se desejado,
    -- mas o crescimento/encolhimento principal é pelo currentScaleFactor.
    -- Ex: Se quiser que encolha mais agressivamente no final:
    -- if lifeRatio < 0.2 then finalVisualScale = finalVisualScale * (lifeRatio / 0.2) end

    if finalVisualScale > 0.05 and currentAlpha > 0.05 then -- Ajuste o threshold mínimo se necessário
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], currentAlpha)

        local previousBlendMode = love.graphics.getBlendMode()
        love.graphics.setBlendMode("add")

        love.graphics.draw(
            fireSheet,
            quads[self.currentFrame],
            self.position.x,
            self.position.y,
            0,                -- Rotação (0 para fogo normalmente)
            finalVisualScale, -- Escala X
            finalVisualScale, -- Escala Y
            frameWidth / 2,   -- Origem X (centro do frame)
            frameHeight / 2   -- Origem Y (centro do frame)
        )

        -- Restaura o modo de mesclagem anterior
        love.graphics.setBlendMode(previousBlendMode)
    end

    -- DEBUG: Desenhar o raio de colisão da partícula se a flag global estiver ativa
    if DEBUG_SHOW_PARTICLE_COLLISION_RADIUS then
        love.graphics.push()
        love.graphics.setShader()
        local r, gr, b, a = love.graphics.getColor()
        love.graphics.setColor(0, 1, 0, 0.6) -- Verde semi-transparente para o círculo de debug
        love.graphics.circle("line", self.position.x, self.position.y, self.collisionRadius)
        love.graphics.setColor(r, gr, b, a)  -- Restaura a cor anterior
        love.graphics.pop()
    end

    -- Reset color (já presente, mas garantindo que esteja após o debug draw se necessário)
    love.graphics.setColor(1, 1, 1, 1)
end

return FireParticle
