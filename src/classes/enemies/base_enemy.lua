--[[
    Base Enemy
    Classe base para todos os tipos de inimigos
]]

local ManagerRegistry = require("src.managers.manager_registry")
local FloatingText = require("src.entities.floating_text")
local Colors = require("src.ui.colors")

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
    className = "BaseEnemy" -- Adicionado para identificação no pool
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
    enemy.radius = self.radius
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

    -- Define o className para a instância. Se uma subclasse definir className em sua própria tabela,
    -- o metatable fará com que self.className na instância já seja o correto.
    -- Mas para garantir, especialmente se a instância for criada diretamente, podemos atribuir aqui.
    enemy.className = self.className

    print(string.format("BaseEnemy criado com ID: %d, Classe: %s", enemy.id, enemy.className)) -- Log para debug

    return enemy
end

function BaseEnemy:update(dt, playerManager, enemies)
    if not self.isAlive then return end

    local playerCollision = playerManager:getCollisionPosition()
    if not playerCollision or not playerCollision.position then -- Verifica se a posição existe
        print("BaseEnemy:update - AVISO: Posição de colisão do jogador não encontrada!")
        return                                                  -- Não pode atualizar sem a posição
    end
    local dx = playerCollision.position.x - self.position.x
    local dy = (playerCollision.position.y - self.position.y) * 2 -- Ajusta para o modo isométrico

    -- Normaliza o vetor de direção
    local length = math.sqrt(dx * dx + dy * dy)
    if length > 0 then
        dx = dx / length
        dy = dy / length
    end

    -- Calcula a posição alvo inicial baseada na direção do jogador
    local targetX = self.position.x + dx * self.speed * dt
    local targetY = self.position.y + dy * self.speed * dt

    -- Calcula a força de separação total devido a outros inimigos
    local totalSeparationX = 0
    local totalSeparationY = 0
    local separationStrength = 10.0 -- Fator de força da separação (AUMENTADO SIGNIFICATIVAMENTE)

    -- Verifica colisão com outros inimigos e calcula separação
    for _, other in ipairs(enemies) do
        if other ~= self and other.isAlive then
            -- Usa a posição atual para verificar a colisão, não a posição alvo
            local distSq = (other.position.x - self.position.x) ^ 2 +
                ((other.position.y - self.position.y) * 2) ^
                2 -- Ajuste isométrico na distância Y
            local minDist = self.radius + other.radius

            if distSq < minDist * minDist and distSq > 0 then -- Evita divisão por zero se distSq for 0
                local distance = math.sqrt(distSq)
                local overlap = minDist - distance

                -- Calcula vetor de separação normalizado (de other para self)
                local sepX = self.position.x - other.position.x
                local sepY = (self.position.y - other.position.y) * 2 -- Ajuste isométrico

                -- Normaliza
                sepX = sepX / distance
                sepY = sepY / distance

                -- Adiciona força de separação proporcional ao overlap
                -- A força é maior quanto maior o overlap
                totalSeparationX = totalSeparationX + sepX * overlap * separationStrength
                totalSeparationY = totalSeparationY + sepY * overlap * separationStrength
            elseif distSq == 0 then -- Exatamente na mesma posição
                -- Empurra em uma direção aleatória para separá-los
                local angle = math.random() * 2 * math.pi
                totalSeparationX = totalSeparationX + math.cos(angle) * self.radius * separationStrength
                totalSeparationY = totalSeparationY +
                    math.sin(angle) * self.radius * separationStrength *
                    0.5 -- Menos força no Y devido à isometria
            end
        end
    end

    -- Adiciona a força de separação ao movimento alvo
    -- A separação pode temporariamente mover o inimigo "para trás" se for forte o suficiente
    targetX = targetX + totalSeparationX * dt -- Escala por dt para movimento mais suave
    targetY = targetY + totalSeparationY * dt

    -- Atualiza a posição do inimigo
    self.position.x = targetX
    self.position.y = targetY

    -- Verifica colisão com o jogador usando a posição de colisão
    self:checkPlayerCollision(dt, playerManager)

    self:updateFloatingTexts(dt)
end

---@param dt number Delta time.
---@param playerManager PlayerManager
function BaseEnemy:checkPlayerCollision(dt, playerManager)
    -- Obtém a posição de colisão do jogador
    local playerCollision = playerManager:getCollisionPosition()

    -- Atualiza o tempo do último dano
    self.lastDamageTime = self.lastDamageTime + dt

    -- Calcula a distância entre a colisão do jogador e o inimigo
    -- Obtém a posição de colisão do inimigo
    local enemyCollision = self:getCollisionPosition()
    local dx = playerCollision.position.x - enemyCollision.position.x
    local dy = (playerCollision.position.y - enemyCollision.position.y) * 2 -- Ajusta para o modo isométrico

    local distance = math.sqrt(dx * dx + dy * dy)

    -- Se houver colisão (distância menor que a soma dos raios)
    if distance <= (self.radius + playerCollision.radius) then
        -- Verifica se pode causar dano (cooldown)
        if self.lastDamageTime >= self.damageCooldown then
            -- Causa dano ao jogador usando o PlayerManager
            if playerManager:receiveDamage(self.damage) then
                -- Se o jogador morreu, remove o inimigo
                self.isAlive = false
            end
            -- Reseta o cooldown
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
    local textBatch = spriteBatches and spriteBatches.textBatch -- Supondo uma chave "textBatch"
    self:drawFloatingTexts(textBatch)
end

--- Aplica dano ao inimigo.
---@param damage number Dano a ser aplicado
---@param isCritical boolean Se o dano é crítico
---@return boolean True se o inimigo morreu, false caso contrário
function BaseEnemy:takeDamage(damage, isCritical)
    if not self.isAlive then return false end -- Não pode tomar dano se já não estiver vivo

    self.currentHealth = self.currentHealth - damage
    -- print(string.format("Inimigo ID: %d (%s), Dano: %d, Vida: %d/%d", self.id, self.name, damage, self.currentHealth, self.maxHealth))

    if damage > 0 then
        local props = {
            textColor = isCritical and Colors.damage_crit or Colors.damage_enemy,
            scale = isCritical and 1.3 or 1,
            velocityY = isCritical and -55 or -45,
            lifetime = isCritical and 1.1 or 0.8,
            isCritical = isCritical or false,
            baseOffsetY = -(self.radius + 20), -- Ajustado para ser relativo ao raio
            baseOffsetX = 0
        }

        local stackOffsetY = #self.activeFloatingTexts * -15
        local textInstance = FloatingText:new(
            self.position,
            tostring(damage),
            props,
            0,
            stackOffsetY
        )
        table.insert(self.activeFloatingTexts, textInstance)
    end

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
---@param dt number Delta time.
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
    if self.activeFloatingTexts then
        for i = #self.activeFloatingTexts, 1, -1 do
            table.remove(self.activeFloatingTexts, i)
        end
    else
        self.activeFloatingTexts = {}
    end

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
end

return BaseEnemy
