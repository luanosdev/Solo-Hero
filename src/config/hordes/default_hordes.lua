local CommonEnemy = require("src.classes.enemies.common_enemy")
local FastEnemy = require("src.classes.enemies.fast_enemy")
local TankEnemy = require("src.classes.enemies.tank_enemy")
local RangedEnemy = require("src.classes.enemies.ranged_enemy")

local hordeConfig = {
    -- Definição das Hordas que aparecem em tempos específicos
    hordes = {
        -- Hordas iniciais (primeiros 5 minutos) - Apenas CommonEnemy
        {time = 10, enemies = {{class = CommonEnemy, count = 5}}},
        {time = 30, enemies = {{class = CommonEnemy, count = 8}}},
        {time = 60, enemies = {{class = CommonEnemy, count = 10}}},
        {time = 90, enemies = {{class = CommonEnemy, count = 12}}},
        {time = 120, enemies = {{class = CommonEnemy, count = 15}}},
        {time = 150, enemies = {{class = CommonEnemy, count = 15}}},
        {time = 180, enemies = {{class = CommonEnemy, count = 18}}},
        {time = 210, enemies = {{class = CommonEnemy, count = 18}}},
        {time = 240, enemies = {{class = CommonEnemy, count = 20}}},
        {time = 270, enemies = {{class = CommonEnemy, count = 20}}},
        
        -- Hordas posteriores (após 5 minutos) - Mistura de inimigos (tempos ajustados)
        {time = 300, enemies = {{class = FastEnemy, count = 5}, {class = TankEnemy, count = 2}, {class = CommonEnemy, count = 10}}},
        {time = 360, enemies = {{class = FastEnemy, count = 10}, {class = RangedEnemy, count = 5}, {class = CommonEnemy, count = 15}}},
        {time = 420, enemies = {{class = FastEnemy, count = 15}, {class = TankEnemy, count = 5}, {class = RangedEnemy, count = 10}}},
        {time = 480, enemies = {{class = FastEnemy, count = 20}, {class = TankEnemy, count = 10}, {class = RangedEnemy, count = 15}}},
        {time = 540, enemies = {{class = FastEnemy, count = 25}, {class = TankEnemy, count = 15}, {class = RangedEnemy, count = 20}}},
        -- Adicione mais hordas conforme necessário
    },

    -- Definição dos inimigos que podem spawnar aleatoriamente entre as hordas
    randomSpawns = {
        {class = CommonEnemy, weight = 15}, -- Mais comum nos spawns aleatórios
        {class = FastEnemy, weight = 3},
        {class = TankEnemy, weight = 1},
        {class = RangedEnemy, weight = 2},
        -- Adicione ou remova inimigos/ajuste pesos para os spawns aleatórios deste "mundo"
    }
}

return hordeConfig