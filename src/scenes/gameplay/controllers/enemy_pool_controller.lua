---@class EnemyPoolController
---@description Gerencia a reutilização de instâncias de inimigos para otimização.
---@field pools table<string, BaseEnemy[]> Um mapa de pools, onde cada chave é o nome da classe do inimigo.
local EnemyPoolController = {}
EnemyPoolController.__index = EnemyPoolController

---@return EnemyPoolController
function EnemyPoolController:new()
    local instance = setmetatable({}, EnemyPoolController)
    instance.pools = {}

    return instance
end

function EnemyPoolController:init()
    Logger.info("enemy_pool_controller.init.success", "[EnemyPoolController:init] Enemy Pool Controller initialized.")
end

--- Pré-aquece o pool com um número de instâncias de inimigo para evitar alocações durante o jogo.
---@param enemyClass table A classe do inimigo a ser pré-carregada.
---@param count number O número de instâncias a serem criadas.
function EnemyPoolController:preloadEnemies(enemyClass, count)
    local className = enemyClass.className
    if not className then
        Logger.error("EnemyPoolController:preloadEnemies",
            "Attempted to preload an enemy class without a className property.")
        return
    end

    if not self.pools[className] then
        self.pools[className] = {}
    end

    for i = 1, count do
        local enemy = enemyClass:new({ x = -1000, y = -1000 }, -1) -- Cria fora da tela com ID inválido
        table.insert(self.pools[className], enemy)
    end

    Logger.info("EnemyPoolController:preloadEnemies", string.format("Preloaded %d instances of %s.", count, className))
end

--- Obtém um inimigo do pool. Se o pool estiver vazio, retorna nil.
---@param className string O nome da classe do inimigo a ser obtido.
---@return BaseEnemy|nil
function EnemyPoolController:get(className)
    if self.pools[className] and #self.pools[className] > 0 then
        -- Remove o último inimigo do pool e o retorna.
        return table.remove(self.pools[className])
    end
    -- Retorna nil se o pool para esta classe estiver vazio.
    return nil
end

--- Retorna um inimigo ao pool para ser reutilizado.
---@param enemy BaseEnemy A instância do inimigo a ser retornada.
function EnemyPoolController:returnToPool(enemy)
    if not enemy or not enemy.className then
        Logger.warn("EnemyPoolController:returnToPool", "Attempted to return an invalid enemy to the pool.")
        return
    end

    -- Limpa o estado do inimigo antes de guardá-lo.
    enemy:resetStateForPooling()

    local className = enemy.className
    if not self.pools[className] then
        self.pools[className] = {}
    end

    table.insert(self.pools[className], enemy)
end

function EnemyPoolController:destroy()
    for className, pool in pairs(self.pools) do
        for _, enemy in ipairs(pool) do
            -- Chama o método destroy de cada inimigo para liberar quaisquer recursos que o TablePool possa ter alocado.
            if enemy.destroy then
                enemy:destroy()
            end
        end
    end
    self.pools = {}
    Logger.info("enemy_pool_controller.destroy.success",
        "[EnemyPoolController:destroy] Enemy Pool Controller destroyed and all pooled enemies cleaned up.")
end

return EnemyPoolController
