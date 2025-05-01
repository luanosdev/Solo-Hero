local SceneManager = require("src.core.scene_manager")

-- <<< NOVOS REQUIRES >>>
local Camera = require("src.config.camera")
local AnimationLoader = require("src.animations.animation_loader") -- Embora loadAll seja chamado aqui, pode ser necessário em outros lugares
local LevelUpModal = require("src.ui.level_up_modal")
local RuneChoiceModal = require("src.ui.rune_choice_modal")
local HUD = require("src.ui.hud")
local fonts = require("src.ui.fonts") -- Já era usado no loading, mas essencial aqui
local elements = require("src.ui.ui_elements")
local InventoryScreen = require("src.ui.screens.inventory_screen")
local ItemDetailsModal = require("src.ui.item_details_modal")
local ManagerRegistry = require("src.managers.manager_registry")
local Bootstrap = require("src.core.bootstrap")

local GameplayScene = {}
GameplayScene.__index = GameplayScene -- <<< ADICIONADO __index >>>

function GameplayScene:load(args)
    print("GameplayScene:load - Inicializando sistemas de gameplay...")
    self.portalId = args and args.portalId or "unknown_portal" -- Guarda ID para referência
    self.hordeConfig = args and args.hordeConfig or nil        -- <<< ADICIONADO: Guarda a hordeConfig
    self.hunterId = args and args.hunterId or nil

    if not self.hordeConfig then
        error("ERRO CRÍTICO [GameplayScene:load]: Nenhuma hordeConfig fornecida para iniciar a cena!")
    end
    if not self.hunterId then
        error("ERRO CRÍTICO [GameplayScene:load]: Nenhum hunterId fornecido para iniciar a cena!")
    end
    print(string.format("  - Carregando portal ID: %s, Hunter ID: %s", self.portalId, self.hunterId))

    -- Estado da cena
    self.isPaused = false
    self.camera = nil
    self.groundTexture = nil
    self.grid = nil

    -- Carrega as fontes (caso ainda não tenham sido carregadas ou precise de reload)
    -- NOTA: Idealmente, fontes são carregadas uma vez globalmente, mas garantimos aqui.
    if not fonts.main then fonts.load() end

    -- Carrega o shader de brilho (transferido de main.lua)
    -- TODO: Considerar se o shader deve ser global ou gerenciado pela cena/renderer
    local success, shaderOrErr = pcall(love.graphics.newShader, "assets/shaders/glow.fs")
    if success then
        elements.setGlowShader(shaderOrErr)
        InventoryScreen.setGlowShader(shaderOrErr) -- InventoryScreen precisa do shader
        print("GameplayScene: Glow shader carregado.")
    else
        print("GameplayScene: Aviso - Falha ao carregar glow shader.", shaderOrErr)
    end

    -- Carrega a textura do terreno (transferido de main.lua)
    local texSuccess, texErr = pcall(function()
        self.groundTexture = love.graphics.newImage("assets/ground.png")
        self.groundTexture:setWrap("repeat", "repeat")
    end)
    if not texSuccess then
        print("GameplayScene: ERRO ao carregar groundTexture!", texErr)
        -- Tratar erro como apropriado (ex: usar cor sólida)
    end

    -- Inicializa todos os managers e suas dependências (transferido de main.lua)
    -- IMPORTANTE: Bootstrap provavelmente inicializa o ManagerRegistry globalmente.
    -- Se Bootstrap criar instâncias *novas* a cada chamada, isso precisa ser ajustado.
    -- Assumindo que Bootstrap configura um Registry singleton ou retorna as instâncias.
    print("GameplayScene: Chamando Bootstrap.initialize()...")
    Bootstrap.initialize()
    print("GameplayScene: Bootstrap.initialize() concluído.")

    -- Isometric grid configuration (transferido de main.lua)
    self.grid = {
        size = 128,
        rows = 100, -- Tamanho do mundo (pode vir do portalData no futuro)
        columns = 100,
        color = { 0.3, 0.3, 0.3, 0.2 }
    }

    -- Inicializa a câmera (transferido de main.lua)
    self.camera = Camera:new()
    self.camera:init()

    -- Carrega animações (transferido de main.lua)
    -- NOTA: Isso também pode ser feito globalmente uma vez, mas garantimos aqui.
    print("GameplayScene: Chamando AnimationLoader.loadAll()...")
    AnimationLoader.loadAll()
    print("GameplayScene: AnimationLoader.loadAll() concluído.")

    -- Obtém referência ao player para posicionar câmera ou outras lógicas
    local playerMgr = ManagerRegistry:get("playerManager")
    local enemyMgr = ManagerRegistry:get("enemyManager")
    local dropMgr = ManagerRegistry:get("dropManager")
    if playerMgr and playerMgr.player then
        print(string.format("GameplayScene: Jogador encontrado. Posição inicial: %.1f, %.1f",
            playerMgr.player.position.x, playerMgr.player.position.y))
        -- Ex: Centralizar câmera no jogador inicialmente
        -- self.camera:setPosition(playerMgr.player.position.x, playerMgr.player.position.y)
    else
        print("GameplayScene: AVISO - PlayerManager ou player não encontrado após bootstrap!")
    end

    if not playerMgr or not enemyMgr or not dropMgr then
        error("ERRO CRÍTICO [GameplayScene:load]: Falha ao obter managers essenciais do Registry!")
    end

    -- Configura o PlayerManager com o hunterId
    playerMgr:setupGameplay(ManagerRegistry, self.hunterId)

    -- <<< INÍCIO: Inicialização do EnemyManager com hordeConfig >>>
    local enemyManagerConfig = {
        hordeConfig = self.hordeConfig, -- Passa a configuração recebida
        playerManager = playerMgr,      -- Passa a dependência
        dropManager = dropMgr           -- Passa a dependência
        -- Adicionar outras dependências se EnemyManager:init precisar
    }
    enemyMgr:init(enemyManagerConfig)
    -- <<< FIM: Inicialização do EnemyManager >>>

    -- Posiciona câmera (opcional, pode ser feito no update)
    if playerMgr.player then
        -- self.camera:setPosition(playerMgr.player.position.x, playerMgr.player.position.y)
    end

    print("GameplayScene:load concluído.")
end

function GameplayScene:update(dt)
    -- Permite atualizar UIs que funcionam mesmo pausadas (transferido de main.lua)
    InventoryScreen.update(dt)
    ItemDetailsModal:update(dt)

    -- Verifica se alguma UI principal (modal ou inventário) está ativa
    local hasActiveModalOrInventory = LevelUpModal.visible or RuneChoiceModal.visible or InventoryScreen.isVisible or
        ItemDetailsModal.isVisible

    -- Atualiza o InputManager (lógica transferida)
    -- Passamos o estado de pausa da cena e se UI está ativa
    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then
        -- Nota: A pausa do InputManager pode precisar ser ajustada. A cena gerencia self.isPaused
        -- mas talvez InputManager deva saber apenas se modais/inventário estão ativos.
        inputMgr:update(dt, hasActiveModalOrInventory, self.isPaused)
    else
        print("GameplayScene: AVISO - InputManager não encontrado no Registry para update")
    end

    -- Pula a lógica principal se a cena está pausada OU se alguma UI principal está visível
    if self.isPaused or hasActiveModalOrInventory then
        -- Permite que modais de Level Up/Rune se atualizem se visíveis
        if LevelUpModal.visible then LevelUpModal:update() end
        if RuneChoiceModal.visible then RuneChoiceModal:update() end
        -- ItemDetailsModal já foi atualizado no início
        return -- Interrompe aqui se pausado ou modal ativo
    end

    -- Atualiza todos os managers do jogo (lógica principal transferida)
    ManagerRegistry:update(dt)

    -- Exemplo: Voltar para o Lobby ao pressionar ESC (mantido)
    if love.keyboard.isDown("escape") then
        print("GameplayScene: ESC pressionado, voltando para LobbyScene")
        SceneManager.switchScene("lobby_scene")
    end
end

--- Desenha o grid isométrico com base na posição do jogador e câmera.
-- (Função movida de main.lua e adaptada para ser método da cena)
function GameplayScene:drawIsometricGrid()
    if not self.grid or not self.groundTexture or not self.camera then
        print("GameplayScene:drawIsometricGrid - Aviso: grid, groundTexture ou camera não inicializados.")
        return
    end

    local iso_scale = 0.5 -- Isometric perspective scale
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local grid = self.grid
    local groundTexture = self.groundTexture
    local camera = self.camera

    -- Calcula o tamanho do chunk baseado no tamanho da tela
    local chunkSize = 32 -- número de células por chunk
    -- Adiciona o zoom da câmera ao cálculo de chunks visíveis
    local visibleCellsX = screenWidth / (grid.size / 2)
    local visibleCellsY = screenHeight / (grid.size / 2 * iso_scale)
    local visibleChunksX = math.ceil(visibleCellsX / chunkSize) + 4 -- chunks visíveis + buffer
    local visibleChunksY = math.ceil(visibleCellsY / chunkSize) + 4

    -- Obtém o PlayerManager do Registry
    local playerMgr = ManagerRegistry:get("playerManager")
    local playerX, playerY = 0, 0
    if playerMgr and playerMgr.player and playerMgr.player.position then -- <<< ADICIONADO: Checa player.position
        playerX = playerMgr.player.position.x
        playerY = playerMgr.player.position.y
    else
        -- Se player não existe ou não tem posição ainda, usa centro da câmera
        playerX, playerY = camera:getPosition()
        -- print("GameplayScene:drawIsometricGrid - AVISO: Player/Posição não encontrado, usando centro da câmera.")
    end

    -- Converte a posição central (jogador/câmera) para coordenadas do grid
    local centerGridX = math.floor(playerX / (grid.size / 2))
    local centerGridY = math.floor(playerY / (grid.size / 2 * iso_scale))

    -- Calcula o chunk central
    local currentChunkX = math.floor(centerGridX / chunkSize)
    local currentChunkY = math.floor(centerGridY / chunkSize)

    -- Define a área de chunks a ser renderizada em volta do centro
    local startChunkX = currentChunkX - math.ceil(visibleChunksX / 2)
    local endChunkX = currentChunkX + math.ceil(visibleChunksX / 2)
    local startChunkY = currentChunkY - math.ceil(visibleChunksY / 2)
    local endChunkY = currentChunkY + math.ceil(visibleChunksY / 2)

    -- Apply camera transformation (já deve estar ativa no draw principal)
    -- Camera:attach()

    -- Define a cor branca para não afetar a textura
    love.graphics.setColor(1, 1, 1, 1)

    -- Renderiza os chunks visíveis
    for chunkX = startChunkX, endChunkX do
        for chunkY = startChunkY, endChunkY do
            -- Renderiza as células dentro do chunk
            local startX = chunkX * chunkSize
            local startY = chunkY * chunkSize
            local endX = startX + chunkSize
            local endY = startY + chunkSize

            for i = startX, endX do
                for j = startY, endY do
                    -- Calcula posição isométrica do ponto do grid
                    local isoX = (i - j) * (grid.size / 2)
                    local isoY = (i + j) * (grid.size / 2 * iso_scale)

                    -- Desenha a textura do terreno no tile
                    love.graphics.draw(
                        groundTexture,
                        isoX - grid.size / 2,                 -- Ajusta para desenhar tile centrado no ponto
                        isoY - grid.size / 2,
                        0,                                    -- rotação
                        grid.size / groundTexture:getWidth(), -- escala X
                        grid.size / groundTexture:getHeight() -- escala Y
                    )
                end
            end
        end
    end

    -- Camera:detach() -- Deve ser feito no draw principal
    love.graphics.setColor(1, 1, 1, 1) -- Garante reset da cor
end

function GameplayScene:draw()
    if not self.camera then
        love.graphics.printf("ERRO: Câmera não inicializada!", 0, love.graphics.getHeight() / 2, love.graphics.getWidth(),
            "center")
        return
    end

    -- Clear screen (opcional, pode sobrepor com fundo do grid)
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1) -- <<< MUDADO: Cor de fundo mais escura >>>
    love.graphics.clear(0.1, 0.1, 0.1, 1)           -- <<< MUDADO: Limpa com a mesma cor >>>

    -- Aplica transformação da câmera para o mundo
    self.camera:attach()

    -- Desenha o grid isométrico e o chão
    self:drawIsometricGrid()

    -- Desenha elementos do jogo que ficam sob a câmera
    ManagerRegistry:CameraDraw() -- Assumindo que isso desenha player, inimigos, projéteis, etc.

    -- Desfaz transformação da câmera
    self.camera:detach()

    -- Desenha elementos da UI que ficam por cima de tudo
    ManagerRegistry:draw() -- Assumindo que isso desenha UI como FloatingText

    -- Desenha Modais e Telas de UI
    LevelUpModal:draw()
    RuneChoiceModal:draw()
    InventoryScreen.draw()  -- Assumindo que verifica internamente se está visível
    ItemDetailsModal:draw() -- Assumindo que verifica internamente se está visível
    HUD:draw()

    -- Desenha informações de Debug (opcional)
    local enemyMgr = ManagerRegistry:get("enemyManager")
    if enemyMgr then
        local enemies = enemyMgr:getEnemies()
        if enemies and #enemies > 0 then -- <<< ADICIONADO: Verifica se enemies existe
            -- Código de debug dos inimigos (transferido e adaptado)
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle('fill', love.graphics.getWidth() - 210, 5, 205, 150)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(fonts.debug or fonts.main_small)
            local debugText = string.format(
                "Enemy Info:\nTotal: %d | Ciclo: %d | Timer: %.1f",
                #enemies,
                enemyMgr.currentCycleIndex or 0, -- <<< ADICIONADO: Default 0 se nil
                enemyMgr.gameTimer or 0          -- <<< ADICIONADO: Default 0 se nil
            )
            local bossCount = 0
            local bossLines = {}
            for _, enemy in ipairs(enemies) do
                if enemy.isBoss and enemy.isAlive then
                    bossCount = bossCount + 1
                    table.insert(bossLines, string.format(
                        "B%d: %s H:%.0f (%.0f,%.0f)",
                        bossCount, enemy.name or "?", enemy.currentHealth or 0, enemy.position.x, enemy.position.y
                    ))
                end
            end
            if bossCount > 0 then
                debugText = debugText .. "\nBosses Vivos:\n" .. table.concat(bossLines, "\n")
            end
            love.graphics.print(debugText, love.graphics.getWidth() - 200, 10)
        end
    end
    love.graphics.setFont(fonts.main) -- Reseta fonte
end

function GameplayScene:keypressed(key, scancode, isrepeat)
    -- print(string.format("GameplayScene: Tecla pressionada: %s", key))

    -- Trata TAB para inventário ANTES de delegar para InputManager
    if key == "tab" then
        print("GameplayScene: TAB pressionado! Alternando inventário...")
        self.isPaused = InventoryScreen.toggle() -- Alterna visibilidade e pausa da cena
        print(string.format("GameplayScene: Estado de pausa: %s", tostring(self.isPaused)))
        return                                   -- Input tratado aqui
    end

    -- Delega o restante para o InputManager (lógica transferida)
    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then
        inputMgr:keypressed(key, self.isPaused) -- Passa o estado de pausa da cena
    else
        print("GameplayScene: AVISO - InputManager não encontrado no Registry para keypressed")
    end
end

function GameplayScene:keyreleased(key, scancode)
    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then
        inputMgr:keyreleased(key, self.isPaused)
    else
        print("GameplayScene: AVISO - InputManager não encontrado no Registry para keyreleased")
    end
end

function GameplayScene:mousepressed(x, y, button, istouch, presses)
    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then
        inputMgr:mousepressed(x, y, button, self.isPaused)
    else
        print("GameplayScene: AVISO - InputManager não encontrado no Registry para mousepressed")
    end
    -- Nota: O InputManager deve internamente verificar cliques em Modais/Inventário primeiro
end

function GameplayScene:mousemoved(x, y, dx, dy, istouch)
    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then
        inputMgr:mousemoved(x, y, dx, dy)
    else
        print("GameplayScene: AVISO - InputManager não encontrado no Registry para mousemoved")
    end
end

function GameplayScene:mousereleased(x, y, button, istouch, presses)
    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then
        inputMgr:mousereleased(x, y, button, self.isPaused)
    else
        print("GameplayScene: AVISO - InputManager não encontrado no Registry para mousereleased")
    end
end

-- Adicionar outros handlers de input (keyreleased, mousepressed, etc.) conforme necessário

function GameplayScene:unload()
    print("GameplayScene:unload - Descarregando recursos do gameplay...")
    -- TODO: Limpar recursos específicos da cena de gameplay (inimigos, etc.)
    -- <<< ADICIONADO: Resetar estados estáticos de UI/Modals >>>
    LevelUpModal.visible = false
    RuneChoiceModal.visible = false
    InventoryScreen.isVisible = false
    ItemDetailsModal.isVisible = false
    if HUD.reset then HUD:reset() end -- Chama reset se existir

    -- <<< ADICIONADO: Parar/Limpar managers se necessário >>>
    -- Exemplo: Parar timers ou limpar listas
    local enemyMgr = ManagerRegistry:get("enemyManager")
    if enemyMgr and enemyMgr.reset then enemyMgr:reset() end
    -- Limpar outros managers se relevante
end

return GameplayScene
