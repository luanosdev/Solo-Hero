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
    self.playerManager = ManagerRegistry:get("playerManager")
    self.floatingTextManager = ManagerRegistry:get("floatingTextManager")
    self.inputManager = ManagerRegistry:get("inputManager")
    RuneChoiceModal:init(self.playerManager, self.inputManager, self.floatingTextManager)
    print("RuneManager inicializado.")
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
        self.playerManager.player.position.x,
        self.playerManager.player.position.y -  - 30,
        "Nova Runa: " .. rune.name,
        true,
        self.playerManager.player.position,
        {1, 0.5, 0} -- Cor laranja para runas
    )
end

--[[
    Aplica uma habilidade específica (instância) originada de uma runa ao jogador.
    Chamado pelo RuneChoiceModal após o jogador fazer uma escolha.
    @param abilityInstance (table): A instância da habilidade a ser aplicada.
]]
function RuneManager:applyRuneAbility(abilityInstance)
    if not abilityInstance then
        print("ERRO [RuneManager]: Tentativa de aplicar habilidade de runa nula.")
        return
    end

    -- Verifica se o PlayerManager e seu método addAbility existem
    if self.playerManager and self.playerManager.addAbility then
        print(string.format("[RuneManager] Adicionando habilidade '%s' ao PlayerManager...", abilityInstance.name or "Desconhecida"))
        self.playerManager:addAbility(abilityInstance)
    else
        if not self.playerManager then
            print("ERRO [RuneManager]: Referência para PlayerManager não encontrada!")
        else
            print("ERRO [RuneManager]: Função PlayerManager:addAbility não encontrada!")
        end
        -- A habilidade não foi adicionada
    end
end

--[[
    Atualiza o estado do gerenciador
    @param dt Delta time
]]
function RuneManager:update()
    RuneChoiceModal:update()
end

--[[
    Lida com pressionamento de teclas
    @param key Tecla pressionada
]]
function RuneManager:keypressed(key)
    RuneChoiceModal:keypressed(key)
end

return RuneManager 