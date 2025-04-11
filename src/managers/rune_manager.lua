local FloatingTextManager = require("src.managers.floating_text_manager")

--[[
    Rune Manager
    Gerencia a geração e aplicação de runas no jogo
]]

local Rune = require("src.items.rune")
local RuneChoiceModal = require("src.ui.rune_choice_modal")

local RuneManager = {
    activeRunes = {}, -- Runas atualmente ativas no jogo
    player = nil -- Referência ao jogador
}

--[[
    Inicializa o gerenciador de runas
    @param player Referência ao jogador
]]
function RuneManager:init(player)
    self.player = player
    self.activeRunes = {}
    RuneChoiceModal:init(player)
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
    FloatingTextManager:addText(
        self.player.positionX,
        self.player.positionY - self.player.radius - 30,
        "Nova Runa: " .. rune.name,
        true,
        self.player,
        {1, 0.5, 0} -- Cor laranja para runas
    )
end

--[[
    Atualiza o estado do gerenciador
    @param dt Delta time
]]
function RuneManager:update(dt)
    RuneChoiceModal:update(dt)
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