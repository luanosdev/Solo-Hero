--[[
    Base Enemy
    Classe base para todos os tipos de inimigos
]]

local ManagerRegistry = require("src.managers.manager_registry")
local FloatingText = require("src.entities.floating_text")
local Colors = require("src.ui.colors")
local TablePool = require("src.utils.table_pool")
local Constants = require("src.config.constants")

---@class BaseEnemy
---@field position {x: number, y: number} Posição do inimigo
---@field radius number Raio do inimigo
---@field speed number Velocidade de movimento do inimigo
---@field maxHealth number Vida máxima do inimigo
---@field currentHealth number Vida atual do inimigo
---@field isAlive boolean Se o inimigo está vivo
---@field damage number Dano base do inimigo
---@field lastDamageTime number Tempo do último dano causado
---@field damageCooldown number Cooldown entre danos em segundos
---@field attackSpeed number Velocidade de ataque do inimigo
---@field activeFloatingTexts table Array para armazenar instâncias de FloatingText ativas.
---@field className string Nome da classe do inimigo, usado para pooling.
local BaseEnemy = {
    position = {
        x = 0,
        y = 0,
    },
    radius = 8,
    speed = 30,
    maxHealth = 50,
    currentHealth = 50,
    isAlive = true,
    damage = 10,          -- Dano base do inimigo
    lastDamageTime = 0,   -- Tempo do último dano causado
    damageCooldown = 1,   -- Cooldown entre danos em segundos
    attackSpeed = 1,
    color = { 1, 0, 0 },  -- Cor padrão vermelha
    name = "BaseEnemy",
    experienceValue = 10, -- Experiência base para todos os inimigos
    healthBarWidth = 30,  -- Largura padrão da barra de vida
    id = 0,               -- ID único do inimigo
    isDying = false,
    isDeathAnimationComplete = false,
    deathTimer = 0,
    deathDuration = 2.0,
    className = "BaseEnemy", -- Adicionado para identificação no pool

    -- Controle de frequência de atualização
    updateInterval = 0.1,        -- Intervalo para atualização principal (10 Hz)
    updateTimer = 0,             -- Timer para atualização principal
    floatingTextUpdateInterval = 1/15, -- Intervalo para atualização de textos flutuantes (~15 Hz)
    floatingTextUpdateTimer = 0,  -- Timer para atualização de textos flutuantes
    slowUpdateTimer = 0,         -- Timer para update lento

    -- Para SpatialGridIncremental
    lastGridCol = nil,
    lastGridRow = nil,
    currentGridCells = nil,

    -- Callbacks
    collisionType = "enemy",
}

function BaseEnemy:new(position, id)
    local enemy = {}
    setmetatable(enemy, { __index = self })
    enemy.activeFloatingTexts = {}

    -- Copia todas as propriedades base
    enemy.position = {
        x = position.x or 0,
        y = position.y or 0
    }
    enemy.radius = (Constants.ENEMY_SPRITE_SIZES.MEDIUM / 2) * 0.9
    enemy.speed = self.speed
    enemy.maxHealth = self.maxHealth
    enemy.currentHealth = self.maxHealth
    enemy.isAlive = true
    enemy.damage = self.damage
    enemy.lastDamageTime = 0
    enemy.damageCooldown = self.damageCooldown
    enemy.attackSpeed = self.attackSpeed
    enemy.color = self.color
    enemy.name = self.name
    enemy.id = id or 0 -- Atribui o ID fornecido ou usa 0 como fallback
    enemy.experienceValue = self.experienceValue
    enemy.healthBarWidth = self.healthBarWidth

    enemy.isDying = self.isDying
    enemy.isDeathAnimationComplete = self.isDeathAnimationComplete
    enemy.deathTimer = self.deathTimer
    enemy.deathDuration = self.deathDuration

    -- Inicializa timers de controle de update
    enemy.updateInterval = self.updateInterval
    enemy.updateTimer = math.random() * enemy.updateInterval -- Espalha o primeiro update
    enemy.floatingTextUpdateInterval = self.floatingTextUpdateInterval
    enemy.floatingTextUpdateTimer = math.random() * enemy.floatingTextUpdateInterval -- Espalha o primeiro update
    enemy.slowUpdateTimer = 0

    -- Para SpatialGridIncremental
    enemy.lastGridCol = nil
    enemy.lastGridRow = nil
    enemy.currentGridCells = nil -- Começa como nil, o grid vai popular com uma tabela do pool

    -- Define o className para a instância. Se uma subclasse definir className em sua própria tabela,
    -- o metatable fará com que self.className na instância já seja o correto.
    -- Mas para garantir, especialmente se a instância for criada diretamente, podemos atribuir aqui.
    enemy.className = self.className

    enemy.collisionType = self.collisionType or "enemy"

    Logger.debug("BaseEnemy", "BaseEnemy criado com ID: " .. enemy.id .. ", Classe: " .. enemy.className)

    return enemy
end

function BaseEnemy:update(dt, playerManager, enemyManager, isSlowUpdate)
    if not self.isAlive then return end

    -- Controle de update lento para inimigos fora da tela
    if isSlowUpdate then
        self.slowUpdateTimer = (self.slowUpdateTimer or 0) + dt
        if self.slowUpdateTimer < 1.0 then
            -- Só atualiza floating texts normalmente
            self.floatingTextUpdateTimer = self.floatingTextUpdateTimer + dt
            if self.floatingTextUpdateTimer >= self.floatingTextUpdateInterval then
                local effectiveFloatingTextDt = self.floatingTextUpdateTimer
                self:updateFloatingTexts(effectiveFloatingTextDt)
                self.floatingTextUpdateTimer = 0
            end
            return
        end
        dt = self.slowUpdateTimer -- Usa o tempo acumulado para o movimento
        self.slowUpdateTimer = 0
    end

    -- Incrementa timers
    self.updateTimer = self.updateTimer + dt
    self.floatingTextUpdateTimer = self.floatingTextUpdateTimer + dt

    -- Controle de frequência para a lógica principal do inimigo
    if self.updateTimer >= self.updateInterval then
        self.updateTimer = self.updateTimer - self.updateInterval

        local playerCollisionPosData = playerManager:getCollisionPosition()
        if not playerCollisionPosData or not playerCollisionPosData.position then
            Logger.warning("BaseEnemy", "BaseEnemy:update - AVISO: Posição de colisão do jogador não encontrada!")
            return
        end
        local dx = playerCollisionPosData.position.x - self.position.x
        local dy = (playerCollisionPosData.position.y - self.position.y) * 2

        local lengthSq = dx * dx + dy * dy
        if lengthSq > 0 then
            local length = math.sqrt(lengthSq)
            dx = dx / length
            dy = dy / length
        end

        local effectiveDt = isSlowUpdate and dt or self.updateInterval
        local targetX = self.position.x + dx * self.speed * effectiveDt
        local targetY = self.position.y + dy * self.speed * effectiveDt

        local totalSeparationX = 0
        local totalSeparationY = 0
        local separationStrength = 20.0

        if enemyManager and enemyManager.spatialGrid then
            local searchDepth = 1
            local nearbyEntities = enemyManager.spatialGrid:getNearbyEntities(self.position.x, self.position.y, searchDepth)

            for _, other in ipairs(nearbyEntities) do
                if other ~= self then
                    if other and other.isAlive then
                        local dx = self.position.x - other.position.x
                        local dy = (self.position.y - other.position.y) * 2
                        local distSq = dx * dx + dy * dy

                        if distSq > 0 then
                            local dist = math.sqrt(distSq)
                            local desiredDist = (self.radius + other.radius) * 1.5
                            local force = math.max(0, (desiredDist - dist) / desiredDist)

                            local sepX = (dx / dist) * force
                            local sepY = (dy / dist) * force

                            totalSeparationX = totalSeparationX + sepX * separationStrength
                            totalSeparationY = totalSeparationY + sepY * separationStrength
                        end
                    end
                end
            end
        end

        targetX = targetX + totalSeparationX * effectiveDt
        targetY = targetY + totalSeparationY * effectiveDt

        self.position.x = targetX
        self.position.y = targetY

        self:checkPlayerCollision(effectiveDt, playerManager)
    end

    -- if self.floatingTextUpdateTimer >= self.floatingTextUpdateInterval then
    --    local effectiveFloatingTextDt = self.floatingTextUpdateTimer
    --    self:updateFloatingTexts(effectiveFloatingTextDt)
    --    self.floatingTextUpdateTimer = 0
    --end
end

---@param dt number Delta time (agora pode ser o effectiveDt do intervalo de update)
---@param playerManager PlayerManager
function BaseEnemy:checkPlayerCollision(dt, playerManager)
    if not playerManager or not playerManager.player or not playerManager.player.position or not playerManager.state or not playerManager.state.isAlive then
        -- print("AVISO [BaseEnemy:checkPlayerCollision]: PlayerManager ou jogador inválido/morto.")
        return
    end

    self.lastDamageTime = self.lastDamageTime + dt

    -- Posição de colisão do inimigo (lógica que estava em self:getCollisionPosition())
    local enemyCollisionX = self.position.x
    local enemyCollisionY = self.position.y + 10 -- Ajuste isométrico para os "pés" do inimigo
    local enemyRadius = self.radius

    -- Dados de colisão do jogador (acessados diretamente e y ajustado)
    local playerPosX = playerManager.player.position.x
    local playerPosY = playerManager.player.position.y + 25 -- Ajuste isométrico para os "pés" do jogador
    local playerRadius = playerManager.radius

    -- Calcula a distância entre os pontos de colisão ajustados
    local dx = playerPosX - enemyCollisionX
    -- Para a colisão isométrica entre "pés", a diferença direta em Y (após ajustes) é usada.
    -- O fator *2 da perspectiva não é aplicado aqui se os ajustes já colocam os pontos no mesmo plano de colisão.
    local dy = playerPosY - enemyCollisionY 

    local distSq = dx * dx + dy * dy
    local combinedRadius = enemyRadius + playerRadius
    local combinedRadiusSq = combinedRadius * combinedRadius

    if distSq <= combinedRadiusSq then
        if self.lastDamageTime >= self.damageCooldown then
            if playerManager:receiveDamage(self.damage) then -- receiveDamage deve retornar true se o jogador morreu
                -- Opcional: Lógica se o jogador morrer por este ataque (ex: inimigo para)
                -- self.isAlive = false -- Isso faria o inimigo morrer, o que não parece ser a intenção aqui.
            end
            self.lastDamageTime = 0
        end
    end
end

--- Desenha elementos base do inimigo, como a barra de vida e textos flutuantes.
-- @param spriteBatches Table (opcional): Tabela contendo SpriteBatches, incluindo um para texto (ex: spriteBatches.textBatch).
function BaseEnemy:draw(spriteBatches)            -- Modificado para aceitar spriteBatches
    if not self.isAlive and not self.isDying then -- Se morto e animação de morte não iniciada/completa, não desenha nada.
        return
    end

    -- Desenha textos flutuantes, passando o batch de texto se disponível
    -- local textBatch = spriteBatches and spriteBatches.textBatch -- Supondo uma chave "textBatch"
    --self:drawFloatingTexts(textBatch)
end

--- Aplica dano ao inimigo.
---@param damage number Dano a ser aplicado
---@param isCritical boolean Se o dano é crítico
---@return boolean True se o inimigo morreu, false caso contrário
function BaseEnemy:takeDamage(damage, isCritical)
    if not self.isAlive then return false end -- Não pode tomar dano se já não estiver vivo

    self.currentHealth = self.currentHealth - damage
    -- print(string.format("Inimigo ID: %d (%s), Dano: %d, Vida: %d/%d", self.id, self.name, damage, self.currentHealth, self.maxHealth))

    -- if damage > 0 then
    --    local props = {
    --        textColor = isCritical and Colors.damage_crit or Colors.damage_enemy,
    --        scale = isCritical and 1.3 or 1,
    --        velocityY = isCritical and -55 or -45,
    --        lifetime = isCritical and 1.1 or 0.8,
    --        isCritical = isCritical or false,
    --        baseOffsetY = -(self.radius + 20), -- Ajustado para ser relativo ao raio
    --        baseOffsetX = 0
    --    }

    --    local stackOffsetY = #self.activeFloatingTexts * -15
    --    local textInstance = FloatingText:new(
    --        self.position,
    --        tostring(damage),
    --        props,
    --        0,
    --        stackOffsetY
    --    )
    --    table.insert(self.activeFloatingTexts, textInstance)
    --end

    if self.currentHealth <= 0 then
        self.currentHealth = 0
        self.isAlive = false -- Marca como não vivo (para lógica de update, etc.)
        self.isDying = true  -- Inicia o estado de "morrendo" para animações
        self.deathTimer = 0  -- Reseta o timer de morte

        local experienceOrbManager = ManagerRegistry:get("experienceOrbManager")
        if experienceOrbManager then
            experienceOrbManager:addOrb(self.position.x, self.position.y, self.experienceValue)
        end
        -- print(string.format("Inimigo ID: %d (%s) morreu.", self.id, self.name))
        return true -- Morreu com este golpe
    end

    return false -- Ainda vivo
end

function BaseEnemy:getCollisionPosition()
    return {
        position = {
            x = self.position.x,
            y = self.position.y + 10, -- Ajuste para melhor colisão visual isométrica
        },
        radius = self.radius
    }
end

--- Atualiza todos os textos flutuantes ativos para este inimigo.
---@param dt number Delta time (agora é o tempo acumulado desde o último update de floating texts).
function BaseEnemy:updateFloatingTexts(dt)
    if not self.activeFloatingTexts then return end
    for i = #self.activeFloatingTexts, 1, -1 do
        local textInstance = self.activeFloatingTexts[i]
        --  A função update do FloatingText precisa retornar false quando deve ser removido
        if not textInstance:update(dt) then
            table.remove(self.activeFloatingTexts, i)
        end
    end
end

--- Desenha os textos flutuantes ativos para este inimigo.
-- @param textBatch love.SpriteBatch (opcional): O SpriteBatch para adicionar os textos.
function BaseEnemy:drawFloatingTexts(textBatch) -- Modificado para aceitar textBatch
    if not self.activeFloatingTexts then return end
    for _, textInstance in ipairs(self.activeFloatingTexts) do
        -- A instância de FloatingText:draw() precisará ser modificada para usar o textBatch
        textInstance:draw(textBatch)
    end
end

-- Reseta o estado do inimigo para ser devolvido ao pool.
function BaseEnemy:resetStateForPooling()
    self.isAlive = false
    self.isDying = false
    self.isDeathAnimationComplete = false
    self.shouldRemove = false -- Flag do EnemyManager, mas bom resetar
    self.isMVP = false        -- Resetar flags de estado especiais
    self.isBoss = false

    self.currentHealth = 0
    self.deathTimer = 0
    self.lastDamageTime = 0

    -- Limpa quaisquer textos flutuantes ativos
    -- if self.activeFloatingTexts then
    --    for i = #self.activeFloatingTexts, 1, -1 do
    --        table.remove(self.activeFloatingTexts, i)
    --    end
    --else
    --    self.activeFloatingTexts = {}
    --end

    -- Resetar outros estados específicos se necessário (ex: buffs, debuffs, target)
    self.target = nil -- Exemplo, se BaseEnemy tivesse um campo target

    -- Importante: Não resetar position aqui, pois o inimigo ainda está "no mundo"
    -- até ser efetivamente pego do pool e ter sua posição redefinida.
    -- Não resetar ID aqui, o EnemyManager atribuirá um novo ao reutilizar, ou o ID original pode ser útil para debug do pool.

    -- print(string.format("Inimigo ID %s (Classe: %s) resetado para pooling.", tostring(self.id), self.className))
end

-- Reinicializa um inimigo pego do pool com novos dados.
-- @param position table {x: number, y: number} Nova posição inicial.
-- @param id number Novo ID para o inimigo.
function BaseEnemy:reset(position, id)
    -- O metatable __index deve apontar para o protótipo da classe correta (ex: Zombie, Skeleton)
    -- Portanto, self.__index terá os valores base corretos para essa classe.
    local prototype = getmetatable(self).__index

    self.position.x = position.x or 0
    self.position.y = position.y or 0
    self.id = id or 0

    -- Restaura atributos base a partir do protótipo da classe específica
    self.radius = prototype.radius
    self.speed = prototype.speed
    self.maxHealth = prototype.maxHealth
    self.currentHealth = prototype.maxHealth -- Vida cheia ao resetar
    self.damage = prototype.damage
    self.damageCooldown = prototype.damageCooldown
    self.attackSpeed = prototype.attackSpeed
    self.color = prototype.color -- Se for uma tabela, copiar para evitar referência compartilhada
    if type(prototype.color) == "table" then
        self.color = { unpack(prototype.color) }
    else
        self.color = prototype.color
    end
    self.name = prototype.name -- O nome é geralmente específico da subclasse
    self.experienceValue = prototype.experienceValue
    self.healthBarWidth = prototype.healthBarWidth
    self.deathDuration = prototype.deathDuration
    
    -- Reseta timers de controle de update para o estado inicial do protótipo
    -- E também espalha o primeiro update para evitar picos
    self.updateInterval = prototype.updateInterval
    self.updateTimer = math.random() * self.updateInterval 
    self.floatingTextUpdateInterval = prototype.floatingTextUpdateInterval
    self.floatingTextUpdateTimer = math.random() * self.floatingTextUpdateInterval
    self.slowUpdateTimer = 0

    -- Estado inicial
    self.isAlive = true
    self.isDying = false
    self.isDeathAnimationComplete = false
    self.shouldRemove = false
    self.isMVP = false
    self.isBoss = false

    self.deathTimer = 0
    self.lastDamageTime = 0 -- Pronto para atacar (ou esperar cooldown inicial, se aplicável)

    -- Limpa e reinicializa a tabela de textos flutuantes
    if self.activeFloatingTexts then
        for i = #self.activeFloatingTexts, 1, -1 do
            table.remove(self.activeFloatingTexts, i)
        end
    else
        self.activeFloatingTexts = {}
    end

    -- Chamada para um método de setup específico da subclasse, se existir.
    -- Isso permite que subclasses façam sua própria configuração adicional.
    --if self.setup then
    --    self:setup()
    --end

    -- print(string.format("Inimigo ID %s (Classe: %s) resetado e reutilizado.", tostring(self.id), self.className))

    self.currentGridCells = nil -- Reseta ao reutilizar do pool
end

return BaseEnemy
