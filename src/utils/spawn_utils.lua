---@class SpawnUtils
---@description Funções utilitárias para cálculos relacionados ao spawn de entidades.
local SpawnUtils = {}

local ResolutionUtils = require("src.utils.resolution_utils")

--- Distância em pixels da borda da tela para o spawn.
local SPAWN_BORDER_OFFSET = 64

---
--- Calcula uma posição de spawn aleatória fora da tela, mas perto das bordas da câmera.
--- A lógica seleciona aleatoriamente uma das quatro bordas (superior, inferior, esquerda, direita)
--- e, em seguida, um ponto ao longo dessa borda para o spawn.
---
---@param playerPosition Vector2D A posição atual do jogador, usada como centro da câmera.
---@return number, number As coordenadas x e y para o spawn.
function SpawnUtils.calculateOffScreenSpawnPosition(playerPosition)
    local screenW, screenH = ResolutionUtils.getGameDimensions()

    -- Representa a view da câmera
    local cameraLeft = playerPosition.x - screenW / 2
    local cameraRight = playerPosition.x + screenW / 2
    local cameraTop = playerPosition.y - screenH / 2
    local cameraBottom = playerPosition.y + screenH / 2

    -- Sorteia uma das 4 bordas (1: Cima, 2: Baixo, 3: Esquerda, 4: Direita)
    local edge = math.random(1, 4)
    local spawnX, spawnY

    if edge == 1 then -- Cima
        spawnX = cameraLeft + math.random() * screenW
        spawnY = cameraTop - SPAWN_BORDER_OFFSET
    elseif edge == 2 then -- Baixo
        spawnX = cameraLeft + math.random() * screenW
        spawnY = cameraBottom + SPAWN_BORDER_OFFSET
    elseif edge == 3 then -- Esquerda
        spawnX = cameraLeft - SPAWN_BORDER_OFFSET
        spawnY = cameraTop + math.random() * screenH
    else -- Direita
        spawnX = cameraRight + SPAWN_BORDER_OFFSET
        spawnY = cameraTop + math.random() * screenH
    end

    return spawnX, spawnY
end

return SpawnUtils
