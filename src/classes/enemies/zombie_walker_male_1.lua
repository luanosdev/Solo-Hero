local BaseEnemy = require("src.classes.enemies.base_enemy")
print("[ZombieWalkerMale1.lua] typeof(BaseEnemy) após require:", type(BaseEnemy))
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local EnemyData = require("src.data.enemies")
local data = EnemyData.zombie_walker_male_1

local ZombieWalkerMale1 = setmetatable({}, { __index = BaseEnemy })


--- Cria uma nova instância do ZombieWalkerMale1.
--- @param position table: Posição inicial (x, y).
--- @param id string|number: ID único para o inimigo.
--- @return table: A instância do ZombieWalkerMale1.
function ZombieWalkerMale1:new(position, id)
    -- Chama o construtor da classe base
    local instance = BaseEnemy.new(self, position, id)

    -- Aplicar configurações específicas do ZombieWalkerMale1 a partir de 'data'
    instance.name = data.name
    instance.speed = data.defaultSpeed
    instance.maxHealth = data.health
    instance.currentHealth = instance.health
    instance.damage = data.damage
    instance.experienceValue = data.experienceValue
    instance.radius = data.radius
    instance.dropTable = data.dropTable or instance.dropTable

    instance.sprite = AnimatedSpritesheet.newConfig(data.unitType, {
        position = position,
        scale = data.instanceDefaults.scale,
        speed = data.instanceDefaults.speed,
        animation = data.instanceDefaults.animation
    })
    instance.sprite.unitType = data.unitType

    return setmetatable(instance, { __index = self })
end

--- Atualiza a lógica e animação do zumbi.
--- @param dt number: Delta time.
--- @param playerManager PlayerManager
--- @param allEnemies table
function ZombieWalkerMale1:update(dt, playerManager, allEnemies)
    -- Lida primeiro com o estado de morte e sua animação.
    if self.isDying then
        -- Atualiza a animação de morte.
        local deathAnimationFinished = AnimatedSpritesheet.update(data.unitType, self.sprite, dt, self.sprite.position)

        if deathAnimationFinished then
            self.isDeathAnimationComplete = true -- Sinaliza que a animação visual terminou.
            self.shouldRemove = true             -- Marca para remoção do jogo.
        end
        return                                   -- Não faz mais nada se está no processo de morrer ou se a animação de morte terminou.
    end

    -- A partir daqui, o inimigo não está no processo de morrer (self.isDying é false).
    -- No entanto, self.isAlive pode ainda ser false se algo mais o matou sem acionar self.isDying (improvável com a lógica atual).
    -- Uma verificação explícita de self.isAlive para a lógica de "vivo".
    if not self.isAlive then
        return -- Se não está vivo e não está morrendo (cenário de fallback/segurança), não faz nada.
    end

    -- Lógica para quando o inimigo está vivo e não está morrendo:
    -- Atualiza a animação de movimento/idle.
    AnimatedSpritesheet.update(data.unitType, self.sprite, dt, playerManager.player.position)

    -- Atualiza a posição da entidade com base na posição da animação (que pode ter sido alterada pelo AnimatedSpritesheet.update).
    self.position = self.sprite.position

    -- Chama a lógica de update da classe base (movimento, ataque, etc.).
    BaseEnemy.update(self, dt, playerManager, allEnemies)
end

--- Desenha o zumbi.
--- @param dt number: Delta time.
--- @param spriteBatches_map_by_texture table: Uma tabela mapeando TEXTURAS de animação para seus SpriteBatch correspondentes.
function ZombieWalkerMale1:draw(dt, spriteBatches_map_by_texture) -- Parâmetro renomeado para clareza
    if self.shouldRemove then
        return
    end

    local currentAnimationKey
    if self.sprite.animation.isDead then
        currentAnimationKey = self.sprite.animation.chosenDeathType
    else
        currentAnimationKey = self.sprite.animation.activeMovementType
    end

    if not currentAnimationKey then
        -- print(string.format("AVISO [%s]: Não há currentAnimationKey para desenhar.", data.unitType))
        return
    end

    -- Obter a textura correta para a animação atual
    local enemyTexture = AnimatedSpritesheet.assets[data.unitType] and
        AnimatedSpritesheet.assets[data.unitType].sheets and
        AnimatedSpritesheet.assets[data.unitType].sheets[currentAnimationKey]

    if not enemyTexture then
        print(string.format("AVISO [%s]: Textura para animação '%s' não encontrada em AnimatedSpritesheet.assets.",
            data.unitType, currentAnimationKey))
        return
    end

    -- Obter o SpriteBatch usando a textura como chave
    local targetBatch = spriteBatches_map_by_texture and spriteBatches_map_by_texture[enemyTexture]

    if not targetBatch then
        print(string.format(
            "AVISO [%s]: SpriteBatch para textura da animação '%s' (key: %s) não encontrado na tabela de batches fornecida.",
            data.unitType, currentAnimationKey, tostring(enemyTexture)))
        -- Fallback para desenho individual (não recomendado para produção se o batching é o objetivo):
        -- AnimatedSpritesheet.drawDirectly(data.unitType, self.sprite) -- Precisaria criar esta função em AnimatedSpritesheet
        return
    end

    AnimatedSpritesheet.addToBatch(data.unitType, self.sprite, targetBatch)
    BaseEnemy.draw(self)
end

--- Aplica dano ao zumbi.
-- @param damageDealt number: A quantidade de dano.
-- @param isCritical boolean (opcional): Se o dano foi crítico.
function ZombieWalkerMale1:takeDamage(damageDealt, isCritical)
    local died = BaseEnemy.takeDamage(self, damageDealt, isCritical)

    if died then
        self:startDeathAnimation()
    end

    return died
end

--- Inicia o processo de morte do zumbi (específico do ZombieWalkerMale1).
function ZombieWalkerMale1:startDeathAnimation()
    AnimatedSpritesheet.startDeath(data.unitType, self.sprite)
end

return ZombieWalkerMale1
