-- Módulo centralizado para carregar animações de inimigos e bosses
local AnimatedSkeleton = require("src.animations.animated_skeleton")
local AnimatedSpider = require("src.animations.animated_spider")
-- Adicione outros módulos de animação aqui se necessário

local AnimationLoader = {}

function AnimationLoader.loadAll()
    AnimatedSkeleton.load()
    AnimatedSpider.load()
    -- Adicione outras animações aqui se necessário
end

return AnimationLoader 