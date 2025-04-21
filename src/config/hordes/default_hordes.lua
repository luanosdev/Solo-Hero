-- src/config/hordes/default_hordes.lua
-- Este arquivo define a progressão de spawns de inimigos ao longo do jogo,
-- organizada em ciclos sequenciais. O EnemyManager carrega esta configuração.

-- Requer as classes de inimigos que serão usadas nas configurações abaixo.
local Skeleton = require("src.classes.enemies.skeleton")
local Zombie = require("src.classes.enemies.zombie")
local SpiderBoss = require("src.classes.bosses.spider")

-- Estrutura principal que contém a configuração dos ciclos para um "mundo" específico.
local worldCycles = {
    mapRank = "E", -- Define o rank base do mapa aqui

    -- Configurações globais do mundo
    mvpConfig = {
        spawnInterval = 60,      -- Intervalo entre spawns de MVPs (em segundos)
        statusMultiplier = 20,   -- Multiplicador de status para MVPs
        speedMultiplier = 1.2,   -- Multiplicador de velocidade para MVPs
        sizeMultiplier = 1.3,    -- Multiplicador de tamanho para MVPs
        experienceMultiplier = 20 -- Multiplicador de experiência para MVPs
    },

    -- Configurações de bosses
    bossConfig = {
        spawnTimes = {
            -- Spawna o SpiderBoss aos 30 segundos (para teste rápido)
            {time = 30, class = SpiderBoss}
        },
        drops = {
            -- Drops específicos para o SpiderBoss
            [SpiderBoss] = {
                -- Drops garantidos (além da joia Rank+2 padrão adicionada pelo DropManager)
                guaranteed = {
                    { type = "rune", rarity = "D" }, -- Mantém a runa garantida
                    { type = "gold", amount = { min = 100, max = 200 } } -- Ouro garantido
                },
                -- Drops com chance (além das joias Rank+1 padrão adicionadas pelo DropManager)
                chance = {
                    -- Exemplo: chance adicional de outra runa
                    { type = "rune", rarity = "D", chance = 25 } -- 25% de chance
                    -- Você pode adicionar outros drops específicos do boss aqui (itens, equipamentos etc.).
                }
                -- NOTA: As joias Rank+2 (garantida) e Rank+1 (chance) são tratadas
                -- automaticamente pelo DropManager:processBossDrops com base no mapRank.
            }
            -- Adicione configurações para outros bosses aqui...
            -- [OutroBoss] = { ... }
        }
    },

    -- Tabela contendo a sequência de ciclos de spawn.
    cycles = {
        -- Cada tabela interna representa um ciclo ou fase do jogo.

        -- === Ciclo 1: Primeiros 30 Segundos (Apenas Skeleton) ===
        {
            -- Duração deste ciclo em segundos.
            duration = 30,

            -- Lista de inimigos permitidos neste ciclo e seus pesos relativos para spawn.
            allowedEnemies = {
                {class = Skeleton, weight = 1},
            },

            -- Configuração para os spawns grandes e cronometrados ("Major Spawns").
            majorSpawn = {
                -- Intervalo (em segundos) entre cada Major Spawn durante este ciclo.
                interval = 10,      
                -- Quantidade base de inimigos que aparecem em cada Major Spawn no início do jogo.
                baseCount = 20,      
                -- Porcentagem (em decimal) do baseCount a ser adicionada como inimigos extras para cada minuto de jogo decorrido.
                -- Ex: 0.1 = +10% do baseCount por minuto.
                countScalePerMin = 0.20
            },

            -- Configuração para os spawns pequenos e contínuos ("Minor Spawns").
            minorSpawn = {
                -- Intervalo inicial (em segundos) entre cada Minor Spawn no início do jogo.
                baseInterval = 2,     
                -- Quanto o intervalo entre Minor Spawns diminui (em segundos) para cada minuto de jogo decorrido.
                -- Controla o escalonamento da frequência dos Minor Spawns.
                intervalReductionPerMin = 0.45, 
                -- O intervalo mínimo (em segundos) que os Minor Spawns podem atingir, para evitar spawns muito rápidos.
                minInterval = 5,      
                -- Quantos inimigos são spawnados a cada evento de Minor Spawn (geralmente 1).
                count = 1
            }
        },

        -- === Ciclo 2: Próximos 30 Segundos (Apenas Zombie) [~+50% density] ===
        {
            duration = 30,
            allowedEnemies = {
                {class = Zombie, weight = 1}
            },
            majorSpawn = {
                interval = 10,
                baseCount = 12,
                countScalePerMin = 0.25,
            },
            minorSpawn = {
                baseInterval = 2.0,     
                intervalReductionPerMin = 0.6, 
                minInterval = 0.5,      
                count = 1
            }
        },

        -- === Ciclo 3: Restante (Skeleton e Zombie) [~+50% density] ===
        {
            duration = 600, -- Este ciclo dura 10 minutos (ou até o fim)
            allowedEnemies = {
                {class = Skeleton, weight = 1},
                {class = Zombie, weight = 1}
            },
            majorSpawn = {
                interval = 15,      -- Spawns grandes mais frequentes
                baseCount = 25,     -- Aumentado
                countScalePerMin = 0.30,
            },
            minorSpawn = {
                baseInterval = 1.0, -- Reduzido
                intervalReductionPerMin = 0.30, -- Redução menor, mas começa mais rápido
                minInterval = 0.25, -- Mínimo bem baixo
                count = 1
            }
        }
        -- Adicione mais ciclos aqui para estender a duração e a progressão do jogo.
    }
}

-- Retorna a tabela de configuração completa para ser usada pelo HordeConfigManager.
return worldCycles