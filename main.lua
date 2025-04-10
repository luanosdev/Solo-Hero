---@diagnostic disable-next-line: undefined-global
local love = love

-- Import required modules (Gerenciadores, Entidades, UI, Configurações)
local Warrior = require("src.classes.player.warrior")
local Player = require("src.entities.player")
local HUD = require("src.ui.hud")
local Camera = require("src.config.camera")
local GameConfig = require("src.config.game")
local EnemyManager = require("src.managers.enemy_manager")
local FloatingTextManager = require("src.managers.floating_text_manager")
local PrismManager = require("src.managers.prism_manager")
local PuddleManager = require("src.managers.puddle_manager")
local LevelUpModal = require("src.ui.level_up_modal")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")

--[[ 
    Função principal de inicialização do LÖVE.
    Chamada uma única vez quando o jogo começa.
]]
function love.load()   
    -- Configura a janela do jogo (tela cheia inicial)
    love.window.setFullscreen(true, "desktop")
    
    -- Carrega as fontes usadas no jogo
    fonts.load()
    
    -- Tenta carregar o shader de "glow" (se existir)
    local success, err = pcall(function()
        -- Nota: Esta linha ainda tenta carregar um shader que estava causando problemas.
        -- Pode ser necessário remover ou ajustar se o shader não estiver funcional.
        local glowShader = love.graphics.newShader("src/ui/shaders/simple_glow.fs") 
        elements.setGlowShader(glowShader)
    end)
    if not success then
        print("Aviso: Não foi possível carregar o shader 'simple_glow.fs'. Erro:", err) 
        -- O jogo continuará sem o shader de glow.
    end

    -- Inicializa a entidade Player usando a classe Warrior
    Player:init(Warrior)

    -- Inicializa a câmera que segue o jogador
    camera = Camera:new()
    
    -- Inicializa os diferentes gerenciadores do jogo
    EnemyManager:init() -- Inicializa com a configuração de mundo "default"
    FloatingTextManager:init()
    PrismManager:init()
    PuddleManager:init()
    
    -- Inicializa o modal de Level Up (passando a referência do Player)
    LevelUpModal:init(Player)
end

--[[ 
    Função principal de atualização do LÖVE.
    Chamada a cada frame antes do desenho.
    @param dt Tempo (em segundos) desde o último frame (delta time).
]]
function love.update(dt)
    -- Pausa a lógica principal do jogo se o modal de level up estiver ativo
    if LevelUpModal.visible then
        LevelUpModal:update(dt) -- Atualiza apenas o modal
        return -- Interrompe a atualização do resto do jogo
    end
    
    -- Atualiza a lógica do jogador (movimento, ataques, etc.)
    Player:update(dt)
    -- Faz a câmera seguir suavemente o jogador
    camera:follow(Player, dt)
    
    -- Atualiza os gerenciadores
    EnemyManager:update(dt, Player) -- Atualiza inimigos e lógica de spawn
    FloatingTextManager:update(dt) -- Atualiza textos flutuantes (dano, etc.)
    PrismManager:update(dt, Player) -- Atualiza prismas de experiência e coleta
    PuddleManager:update(dt, Player)
end

--[[ 
    Função principal de desenho do LÖVE.
    Chamada a cada frame após a atualização.
]]
function love.draw()
    -- Limpa a tela com a cor de fundo definida em GameConfig
    love.graphics.setColor(GameConfig.colors.background)
    love.graphics.clear(GameConfig.colors.background)
    
    -- Aplica a transformação da câmera para desenhar o mundo do jogo
    camera:attach()
    -- Desenha os elementos do mundo (afetados pela câmera)
    PuddleManager:draw()
    Player:draw()
    EnemyManager:draw()
    PrismManager:draw()
    FloatingTextManager:draw()
    -- Libera a transformação da câmera
    camera:detach()

    -- Desenha a Interface do Usuário (HUD) por cima, sem transformação da câmera
    HUD:draw(Player)
    
    -- Desenha o modal de level up se estiver visível
    LevelUpModal:draw()
end

--[[ 
    Callback do LÖVE para teclas pressionadas.
    @param key String identificando a tecla pressionada.
]]
function love.keypressed(key)
    -- Fecha o jogo ao pressionar Escape
    if key == "escape" then
        love.event.quit() 
    -- Alterna tela cheia com F11
    elseif key == "f11" then
        love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
    -- Passa outras teclas para o handler do Player
    else
        Player:keypressed(key)
    end
end

--[[ 
    Callback do LÖVE para cliques do mouse.
    @param x Posição X do mouse.
    @param y Posição Y do mouse.
    @param button Número do botão do mouse (1 = esquerdo, 2 = direito, etc.).
]]
function love.mousepressed(x, y, button)
    -- Se o modal de level up estiver visível, ele recebe o clique
    if LevelUpModal.visible then
        LevelUpModal:mousepressed(x, y, button)
        return -- Impede que o clique afete outros elementos
    end
    
    -- Caso contrário, passa o clique para o handler do Player
    Player:mousepressed(x, y, button)
end
