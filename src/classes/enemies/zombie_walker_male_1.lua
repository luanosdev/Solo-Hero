local BaseEnemy = require("src.classes.enemies.base_enemy")
print("[ZombieWalkerMale1.lua] typeof(BaseEnemy) após require:", type(BaseEnemy))
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local EnemyData = require("src.data.enemies")
local data = EnemyData.zombie_walker_male_1

-- Define o protótipo do ZombieWalkerMale1, herdando de BaseEnemy
local ZombieWalkerMale1 = {}
ZombieWalkerMale1.className = "ZombieWalkerMale1" -- Adiciona o className
ZombieWalkerMale1.name = data.name                -- Nome padrão para esta classe
ZombieWalkerMale1.speed = data.defaultSpeed
ZombieWalkerMale1.maxHealth = data.health
ZombieWalkerMale1.damage = data.damage
ZombieWalkerMale1.experienceValue = data.experienceValue
ZombieWalkerMale1.radius = data.radius
ZombieWalkerMale1.dropTable = data.dropTable
-- Outros valores padrão que seriam restaurados por BaseEnemy:reset
-- podem ser definidos aqui se forem diferentes dos de BaseEnemy

setmetatable(ZombieWalkerMale1, { __index = BaseEnemy }) -- Herança

--- Cria uma nova instância do ZombieWalkerMale1.
--- @param position table: Posição inicial (x, y).
--- @param id string|number: ID único para o inimigo.
--- @return table: A instância do ZombieWalkerMale1.
function ZombieWalkerMale1:new(position, id)
    -- Chama o construtor da classe base (BaseEnemy.new).
    -- self aqui se refere à tabela ZombieWalkerMale1 (o protótipo), então BaseEnemy.new
    -- usará ZombieWalkerMale1.className, ZombieWalkerMale1.maxHealth etc. como padrões se não sobrescritos.
    local instance = BaseEnemy.new(self, position, id)

    -- A metatabela da instância é configurada para apontar para ZombieWalkerMale1,
    -- permitindo que métodos como :update, :draw sejam chamados na instância.
    setmetatable(instance, { __index = self })

    -- Atributos específicos que são configurados no new e podem não ser cobertos
    -- pelo BaseEnemy:reset (que usa o protótipo) ou precisam de lógica especial.
    -- No caso do sprite, ele é um objeto complexo e precisa ser recriado ou resetado.
    instance.sprite = AnimatedSpritesheet.newConfig(data.unitType, {
        position = instance.position, -- Usa a posição da instância já definida
        scale = data.instanceDefaults.scale,
        speed = data.instanceDefaults.speed,
        animation = data.instanceDefaults.animation
    })
    instance.sprite.unitType = data.unitType -- Garante que unitType está no sprite

    -- Se BaseEnemy.new atribuiu valores base e precisamos que eles sejam os de 'data' especificamente,
    -- reatribuímos aqui. No entanto, BaseEnemy:reset fará isso usando o protótipo de ZombieWalkerMale1.
    -- A chamada a BaseEnemy.new(self, ...) já deve ter usado os valores de ZombieWalkerMale1 como base.
    -- Ex: instance.name já será data.name porque ZombieWalkerMale1.name é data.name.

    return instance
end

-- Sobrescreve reset para lidar com o sprite e outros estados específicos do ZombieWalkerMale1
function ZombieWalkerMale1:reset(position, id)
    -- Chama o reset da classe base primeiro para restaurar atributos comuns
    BaseEnemy.reset(self, position, id)

    -- Reinicializa o sprite. É crucial que o sprite seja configurado para o novo estado.
    -- Se AnimatedSpritesheet.newConfig cria um novo objeto de configuração de sprite,
    -- então atribuí-lo novamente é o correto.
    -- Se o sprite tivesse uma função :reset própria, poderíamos chamá-la.
    self.sprite = AnimatedSpritesheet.newConfig(data.unitType, {
        position = self.position, -- Usa a posição já resetada pela classe base
        scale = data.instanceDefaults.scale,
        speed = data.instanceDefaults.speed,
        animation = data.instanceDefaults.animation -- Pode precisar de um estado de animação padrão
    })
    self.sprite.unitType = data.unitType

    -- Qualquer outra reinicialização específica do ZombieWalkerMale1 viria aqui.
    -- Por exemplo, resetar estados de animação ou lógica específica.
    -- print(string.format("ZombieWalkerMale1 ID %s resetado.", tostring(self.id)))
end

-- Não há necessidade de sobrescrever resetStateForPooling a menos que ZombieWalkerMale1
-- tenha estados muito específicos não cobertos por BaseEnemy:resetStateForPooling.
-- A limpeza do sprite (se necessária ao ir para o pool) poderia ser feita lá.

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
