local Rune = require("src.items.rune")
local RuneChoiceModal = require("src.ui.rune_choice_modal")
local ManagerRegistry = require("src.managers.manager_registry")

--[[
    Rune Manager
    Gerencia a geração e aplicação de runas no jogo
]]


local RuneManager = {
    activeRunes = {}, -- Runas atualmente ativas no jogo
}

--[[
    Inicializa o gerenciador de runas
]]
function RuneManager:init()
    self.activeRunes = {}
    RuneChoiceModal:init()
    self.floatingTextManager = ManagerRegistry:get("floatingTextManager")
end

--[[
    Gera uma nova runa
    @param rarity Raridade da runa (opcional)
    @return Rune A runa gerada
]]
function RuneManager:generateRune(rarity)
    local rune = Rune:generateRandom(rarity)
    return rune
end

--[[
    Aplica uma runa ao jogador
    @param rune A runa a ser aplicada
]]
function RuneManager:applyRune(rune)
    if not rune then return end
    
    -- Mostra o modal de escolha de habilidade
    RuneChoiceModal:show(rune)
    
    -- Adiciona a runa à lista de runas ativas
    table.insert(self.activeRunes, rune)
    
    -- Mostra mensagem de runa obtida
    self.floatingTextManager:addText(
        self.player.position.x,
        self.player.position.y - self.player.radius - 30,
        "Nova Runa: " .. rune.name,
        true,
        self.player.positio,
        {1, 0.5, 0} -- Cor laranja para runas
    )
end

--[[
    Atualiza o estado do gerenciador
    @param dt Delta time
]]
function RuneManager:update()
    RuneChoiceModal:update()
end

--[[
    Desenha as runas ativas
]]
function RuneManager:draw()
    -- As habilidades são desenhadas pelo próprio jogador
    RuneChoiceModal:draw()
end

--[[
    Lida com pressionamento de teclas
    @param key Tecla pressionada
]]
function RuneManager:keypressed(key)
    RuneChoiceModal:keypressed(key)
end

return RuneManager 