-- src/config/hordes/default_hordes.lua
-- Este arquivo define a progressão de spawns de inimigos ao longo do jogo,
-- organizada em ciclos sequenciais. O EnemyManager carrega esta configuração.

-- Requer as classes de inimigos que serão usadas nas configurações abaixo.
local CommonEnemy = require("src.classes.enemies.common_enemy")
local FastEnemy = require("src.classes.enemies.fast_enemy")
local TankEnemy = require("src.classes.enemies.tank_enemy")
local RangedEnemy = require("src.classes.enemies.ranged_enemy")
local DiagonalEnemy = require("src.classes.enemies.diagonal_enemy")
local PuddleEnemy = require("src.classes.enemies.puddle_enemy")
local ExampleBoss = require("src.classes.bosses.example_boss")

-- Estrutura principal que contém a configuração dos ciclos para um "mundo" específico.
local worldCycles = {
    -- Configurações globais do mundo
    mvpConfig = {
        spawnInterval = 30,      -- Intervalo entre spawns de MVPs (em segundos)
        statusMultiplier = 20,   -- Multiplicador de status para MVPs
        speedMultiplier = 1.2,   -- Multiplicador de velocidade para MVPs
        sizeMultiplier = 1.3,    -- Multiplicador de tamanho para MVPs
        experienceMultiplier = 20 -- Multiplicador de experiência para MVPs
    },

    -- Configurações de bosses
    bossConfig = {
        spawnTimes = { -- Tempos em segundos para spawnar cada boss
            {time = 30, boss = ExampleBoss, powerLevel = 4} -- Primeiro boss após 5 minutos
        },
        
        -- Configuração de drops para cada boss
        drops = {
            -- Drops do ExampleBoss
            [ExampleBoss] = {
                -- Lista de drops possíveis com suas probabilidades
                drops = {
                    {
                        type = "rune", -- Tipo de drop (rune, item, etc)
                        rarity = "epic", -- Raridade do drop (opcional)
                        weight = 1, -- Peso para cálculo de probabilidade
                        guaranteed = true -- Se o drop é garantido
                    },
                    {
                        type = "gold",
                        amount = {min = 50, max = 100}, -- Quantidade de ouro
                        weight = 1,
                        guaranteed = true
                    }
                }
            }
        }
    },

    -- Tabela contendo a sequência de ciclos de spawn.
    cycles = {
        -- Cada tabela interna representa um ciclo ou fase do jogo.
        
        -- === Ciclo 1: Primeiros 3 Minutos (Apenas CommonEnemy)
        {
            -- Duração deste ciclo em segundos.
            duration = 60 * 3, 
            
            -- Lista de inimigos permitidos neste ciclo e seus pesos relativos para spawn.
            -- Usado tanto para Major Spawns quanto para Minor Spawns.
            -- 'weight' maior significa maior chance de ser escolhido.
            allowedEnemies = { 
                {class = CommonEnemy, weight = 1} 
            },
            
            -- Configuração para os spawns grandes e cronometrados ("Major Spawns").
            majorSpawn = {
                -- Intervalo (em segundos) entre cada Major Spawn durante este ciclo.
                interval = 60,      
                -- Quantidade base de inimigos que aparecem em cada Major Spawn no início do jogo.
                baseCount = 20,      
                -- Porcentagem (em decimal) do baseCount a ser adicionada como inimigos extras para cada minuto de jogo decorrido.
                -- Ex: 0.1 = +10% do baseCount por minuto.
                countScalePerMin = 0.20
            },
            
            -- Configuração para os spawns pequenos e contínuos ("Minor Spawns").
            minorSpawn = {
                -- Intervalo inicial (em segundos) entre cada Minor Spawn no início do jogo.
                baseInterval = 2.7,     
                -- Quanto o intervalo entre Minor Spawns diminui (em segundos) para cada minuto de jogo decorrido.
                -- Controla o escalonamento da frequência dos Minor Spawns.
                intervalReductionPerMin = 0.45, 
                -- O intervalo mínimo (em segundos) que os Minor Spawns podem atingir, para evitar spawns muito rápidos.
                minInterval = 0.7,      
                -- Quantos inimigos são spawnados a cada evento de Minor Spawn (geralmente 1).
                count = 1
            }
        },
        
        -- === Ciclo 2: Próximos 3 Minutos (Introduz FastEnemy) [~+50% density] ===
        {
            duration = 60 * 3, 
            allowedEnemies = { 
                {class = CommonEnemy, weight = 3}, -- CommonEnemy ainda é mais provável
                {class = FastEnemy, weight = 1}  -- FastEnemy começa a aparecer
            },
            majorSpawn = {
                interval = 60,      
                baseCount = 12,     
                -- Porcentagem (em decimal) do baseCount a ser adicionada como inimigos extras por minuto.
                countScalePerMin = 0.25,
            },
            minorSpawn = {
                baseInterval = 2.0,     
                intervalReductionPerMin = 0.6, 
                minInterval = 0.5,      
                count = 1
            }
        },

        -- === Ciclo 3: Exemplo (Introduz Tank, Ranged, Diagonal e Puddle) [~+50% density] ===
        {
            duration = 600, -- Este ciclo dura 10 minutos
            allowedEnemies = { 
                {class = CommonEnemy, weight = 3}, -- Ajuste de peso
                {class = FastEnemy, weight = 3},
                {class = TankEnemy, weight = 1},
                {class = RangedEnemy, weight = 2},
                {class = DiagonalEnemy, weight = 2},
                {class = PuddleEnemy, weight = 2} -- Adicionado PuddleEnemy
            },
            majorSpawn = {
                interval = 45,      -- Spawns grandes mais frequentes neste ciclo
                baseCount = 23,     
                -- Porcentagem (em decimal) do baseCount a ser adicionada como inimigos extras por minuto.
                countScalePerMin = 0.30,
            },
            minorSpawn = {
                baseInterval = 1.7,     
                intervalReductionPerMin = 0.45, -- Escalonamento da frequência pode diminuir em ciclos tardios se desejado
                minInterval = 0.3,      
                count = 1 
            }
        }
        -- Adicione mais ciclos aqui para estender a duração e a progressão do jogo.
        -- O jogo para de spawnar novos inimigos (exceto os já em tela) após o último ciclo definido.
    }
}

-- Retorna a tabela de configuração completa para ser usada pelo HordeConfigManager.
return worldCycles