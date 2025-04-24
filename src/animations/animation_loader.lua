-- Módulo centralizado para carregar animações de inimigos e bosses
local AnimatedSkeleton = require("src.animations.animated_skeleton")
-- Adiciona requires para o módulo genérico e as classes com as configs
local AnimatedCharacter = require("src.animations.animated_character")
local Zombie = require("src.classes.enemies.zombie")
local Spider = require("src.classes.bosses.spider")

local AnimationLoader = {}

function AnimationLoader.loadAll()
    AnimatedSkeleton.load()
    -- Carrega animações genéricas usando as configs das classes
    if Zombie and Zombie.animationConfig then
        AnimatedCharacter.load("Zombie", Zombie.animationConfig)
    else
        print("ERRO [AnimationLoader]: Falha ao carregar config de animação do Zumbi.")
    end

    if Spider and Spider.animationConfig then
         AnimatedCharacter.load("Spider", Spider.animationConfig)
    else
         print("ERRO [AnimationLoader]: Falha ao carregar config de animação da Aranha.")
    end

    -- Adicione outras animações aqui se necessário
end

return AnimationLoader 