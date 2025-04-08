local FastEnemy = require("src.classes.enemies.fast_enemy")
local TankEnemy = require("src.classes.enemies.tank_enemy")
local RangedEnemy = require("src.classes.enemies.ranged_enemy")
local CommonEnemy = require("src.classes.enemies.common_enemy")
local HordeConfigManager = require("src.managers.horde_config_manager")

local EnemyManager = {
    enemies = {},
    spawnTimer = 0,             -- Timer para spawns aleatórios
    spawnInterval = 2,          -- Intervalo entre spawns aleatórios (aumentado para dar mais espaço às hordas)
    maxEnemies = 100,
    -- Removido: enemyTypes hardcoded
    
    -- Estado das Hordas e Spawns Aleatórios
    currentHordeList = nil,     -- Lista de hordas do arquivo de config
    currentRandomSpawns = nil, -- Lista de spawns aleatórios do arquivo de config
    currentHordeIndex = 1,
    gameTimer = 0,              -- Timer global do jogo para hordas
}

function EnemyManager:init(worldId)
    worldId = worldId or "default"
    self.enemies = {}
    self.spawnTimer = 0
    self.gameTimer = 0
    
    -- Carrega a configuração completa (hordas e spawns aleatórios)
    local fullConfig = HordeConfigManager.loadHordes(worldId)
    if not fullConfig or not fullConfig.hordes or not fullConfig.randomSpawns then
        error("Erro: Configuração de hordas inválida ou incompleta para o mundo: " .. worldId)
    end
    
    self.currentHordeList = fullConfig.hordes
    self.currentRandomSpawns = fullConfig.randomSpawns
    self.currentHordeIndex = 1
    
    print(string.format("EnemyManager inicializado para '%s'. %d hordas e %d tipos de spawn aleatório carregados.", 
                       worldId, #self.currentHordeList, #self.currentRandomSpawns))
end

function EnemyManager:update(dt, player)
    -- Atualiza timer global
    self.gameTimer = self.gameTimer + dt
    
    -- 1. Verifica Spawns de Hordas
    local nextHordeData = self.currentHordeList and self.currentHordeList[self.currentHordeIndex]
    if nextHordeData and self.gameTimer >= nextHordeData.time then
        print(string.format("Disparando Horda %d no tempo %.2f", self.currentHordeIndex, self.gameTimer))
        local spawnedCount = 0
        for _, enemyInfo in ipairs(nextHordeData.enemies) do
            for i = 1, enemyInfo.count do
                if #self.enemies < self.maxEnemies then
                    self:spawnSpecificEnemy(enemyInfo.class, player)
                    spawnedCount = spawnedCount + 1
                else
                    print("Limite máximo de inimigos atingido durante spawn da horda.")
                    goto horde_spawn_limit_reached -- Sai dos loops aninhados se o limite for atingido
                end
            end
        end
        ::horde_spawn_limit_reached::
        print(string.format("Horda %d concluída. %d inimigos spawnados.", self.currentHordeIndex, spawnedCount))
        self.currentHordeIndex = self.currentHordeIndex + 1 -- Avança para a próxima horda
    end

    -- 2. Verifica Spawns Aleatórios (usando a lista carregada)
    self.spawnTimer = self.spawnTimer + dt
    if self.spawnTimer >= self.spawnInterval then
        if #self.enemies < self.maxEnemies and self.currentRandomSpawns and #self.currentRandomSpawns > 0 then
            self:spawnEnemy(player) -- Spawn aleatório usando a lista do config
        end
        self.spawnTimer = 0 -- Reinicia o timer de spawn aleatório independentemente de ter spawnado ou não
    end

    -- 3. Atualiza Inimigos Existentes
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]
        enemy:update(dt, player, self.enemies)
        if not enemy.isAlive then
            table.remove(self.enemies, i)
        end
    end
end

function EnemyManager:spawnEnemy(player)
    -- Define o raio mínimo de spawn (fora da tela)
    local minSpawnRadius = math.max(love.graphics.getWidth(), love.graphics.getHeight()) * 0.6
    
    -- Gera um ângulo aleatório em radianos
    local angle = math.random() * 2 * math.pi
    
    -- Calcula a posição de spawn baseada no ângulo e raio
    local spawnX = player.positionX + math.cos(angle) * minSpawnRadius
    local spawnY = player.positionY + math.sin(angle) * minSpawnRadius
    
    -- Escolhe o tipo de inimigo baseado nos pesos da lista currentRandomSpawns
    if not self.currentRandomSpawns or #self.currentRandomSpawns == 0 then
        print("Aviso: Tentando spawn aleatório, mas a lista currentRandomSpawns está vazia ou não definida.")
        return -- Não spawna nada se não houver tipos definidos
    end

    local totalWeight = 0
    for _, enemyType in ipairs(self.currentRandomSpawns) do
        totalWeight = totalWeight + enemyType.weight
    end
    
    local randomValue = math.random() * totalWeight
    local selectedEnemyType
    
    for _, enemyType in ipairs(self.currentRandomSpawns) do
        randomValue = randomValue - enemyType.weight
        if randomValue <= 0 then
            selectedEnemyType = enemyType.class
            break
        end
    end
    
    if selectedEnemyType then
        -- Cria o inimigo na posição calculada
        local enemy = selectedEnemyType:new(spawnX, spawnY)
        table.insert(self.enemies, enemy)
    else
        print("Aviso: Não foi possível selecionar um tipo de inimigo para spawn aleatório. Verifique os pesos em currentRandomSpawns.")
    end
end

function EnemyManager:draw()
    for _, enemy in ipairs(self.enemies) do
        enemy:draw()
    end
end

function EnemyManager:getEnemies()
    return self.enemies
end

function EnemyManager:spawnSpecificEnemy(enemyClass, player)
    local minSpawnRadius = math.max(love.graphics.getWidth(), love.graphics.getHeight()) * 0.6
    local angle = math.random() * 2 * math.pi
    local spawnX = player.positionX + math.cos(angle) * minSpawnRadius
    local spawnY = player.positionY + math.sin(angle) * minSpawnRadius
    local enemy = enemyClass:new(spawnX, spawnY)
    table.insert(self.enemies, enemy)
end

return EnemyManager