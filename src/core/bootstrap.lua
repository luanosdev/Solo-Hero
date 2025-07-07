-- src/core/bootstrap.lua

-- Este módulo agora é responsável por inicializar os managers
-- ESPECÍFICOS de uma SESSÃO DE GAMEPLAY.
-- Ele OBTÉM os managers persistentes (ItemData, Hunter, Loadout, etc.)
-- do ManagerRegistry (que foram carregados em main.lua).

local ManagerRegistry = require("src.managers.manager_registry")

-- Managers de Gameplay
local InputManager = require("src.managers.input_manager")
local PlayerManager = require("src.managers.player_manager")
local EnemyManager = require("src.managers.enemy_manager")
local DropManager = require("src.managers.drop_manager")
local ExperienceOrbManager = require("src.managers.experience_orb_manager")
local FloatingTextManager = require("src.managers.floating_text_manager")
local RuneManager = require("src.managers.rune_manager")
local InventoryManager = require("src.managers.inventory_manager")
local HUDGameplayManager = require("src.managers.hud_gameplay_manager")
local ExtractionPortalManager = require("src.managers.extraction_portal_manager")
local ExtractionManager = require("src.managers.extraction_manager")

local Bootstrap = {}

--- Inicialização apenas do núcleo essencial para performance
function Bootstrap.initializeCore()
    Logger.debug("Bootstrap", "Iniciando core essencial...")

    -- 1. Obter managers PERSISTENTES do Registry
    local itemDataManager = ManagerRegistry:get("itemDataManager")
    local hunterManager = ManagerRegistry:get("hunterManager")
    if not itemDataManager then
        error("ERRO CRÍTICO [Bootstrap.initializeCore]: Falha ao obter ItemDataManager do Registry!")
    end

    -- 2. Apenas managers mais essenciais primeiro - DEFENSIVO: só cria se não existir

    -- InputManager
    if not ManagerRegistry:tryGet("inputManager") then
        ManagerRegistry:register("inputManager", InputManager, true) -- true para singleton
        Logger.debug("Bootstrap", "InputManager registrado")
    else
        Logger.debug("Bootstrap", "InputManager já existe, pulando")
    end

    -- PlayerManager (essencial para gameplay)
    if not ManagerRegistry:tryGet("playerManager") then
        local playerMgr = PlayerManager:new()
        ManagerRegistry:register("playerManager", playerMgr, false)
        Logger.debug("Bootstrap", "PlayerManager registrado")
    else
        Logger.debug("Bootstrap", "PlayerManager já existe, pulando")
    end

    -- EnemyManager (essencial para gameplay)
    if not ManagerRegistry:tryGet("enemyManager") then
        local enemyManager = EnemyManager
        ManagerRegistry:register("enemyManager", enemyManager, true)
        Logger.debug("Bootstrap", "EnemyManager registrado")
    else
        Logger.debug("Bootstrap", "EnemyManager já existe, pulando")
    end

    Logger.info("Bootstrap", "Core essencial inicializado com sucesso")
end

function Bootstrap.initialize()
    Logger.info("Bootstrap", "Criando Instâncias dos Managers de GAMEPLAY com DI")

    -- 1. Obter managers PERSISTENTES do Registry
    local itemDataManager = ManagerRegistry:get("itemDataManager")
    local hunterManager = ManagerRegistry:get("hunterManager")
    if not itemDataManager then error("ERRO CRÍTICO [Bootstrap.initialize]: Falha ao obter ItemDataManager do Registry!") end

    -- 2. Criar/Inicializar/Registrar managers de GAMEPLAY (Ordem ajustada)

    -- InputManager
    if not ManagerRegistry:tryGet("inputManager") then
        Logger.debug("Bootstrap", "Criando/Registrando InputManager...")
        ManagerRegistry:register("inputManager", InputManager, true)
        Logger.debug("Bootstrap", "InputManager registrado.")
    else
        Logger.debug("Bootstrap", "InputManager já existe, pulando criação")
    end

    -- InventoryManager
    if not ManagerRegistry:tryGet("inventoryManager") then
        Logger.debug("Bootstrap", "Criando/Registrando InventoryManager...")
        local inventoryManager = InventoryManager:new({ itemDataManager = itemDataManager })
        ManagerRegistry:register("inventoryManager", inventoryManager)
        Logger.debug("Bootstrap", "InventoryManager registrado.")
    else
        Logger.debug("Bootstrap", "InventoryManager já existe, pulando criação")
    end

    -- FloatingTextManager
    if not ManagerRegistry:tryGet("floatingTextManager") then
        Logger.debug("Bootstrap", "Inicializando/Registrando FloatingTextManager...")
        ManagerRegistry:register("floatingTextManager", FloatingTextManager, false)
        Logger.debug("Bootstrap", "FloatingTextManager registrado.")
    else
        Logger.debug("Bootstrap", "FloatingTextManager já existe, pulando criação")
    end

    -- ExperienceOrbManager
    if not ManagerRegistry:tryGet("experienceOrbManager") then
        Logger.debug("Bootstrap", "Inicializando/Registrando ExperienceOrbManager...")
        ExperienceOrbManager:init()
        ManagerRegistry:register("experienceOrbManager", ExperienceOrbManager, true)
        Logger.debug("Bootstrap", "ExperienceOrbManager registrado.")
    else
        Logger.debug("Bootstrap", "ExperienceOrbManager já existe, pulando criação")
    end

    -- PlayerManager (Cria instância) - CRÍTICO: não recriar se já existe!
    if not ManagerRegistry:tryGet("playerManager") then
        Logger.debug("Bootstrap", "Criando/Registrando PlayerManager...")
        local playerMgr = PlayerManager:new()
        ManagerRegistry:register("playerManager", playerMgr, false)
        Logger.debug("Bootstrap", "PlayerManager registrado (aguardando setupGameplay).")
    else
        Logger.debug("Bootstrap", "PlayerManager já existe, pulando criação (PRESERVANDO configuração)")
    end

    -- EnemyManager (Registra ANTES de DropManager)
    if not ManagerRegistry:tryGet("enemyManager") then
        Logger.debug("Bootstrap", "Criando/Registrando EnemyManager...")
        local enemyManager =
            EnemyManager                                             -- Assume Singleton. Se não for: local enemyManager = EnemyManager:new()
        -- Chamar :init se necessário: if enemyManager.init then enemyManager:init({...}) end
        ManagerRegistry:register("enemyManager", enemyManager, true) -- Registra a tabela/instância
        Logger.debug("Bootstrap", "EnemyManager registrado (aguardando setupGameplay).")
    else
        Logger.debug("Bootstrap", "EnemyManager já existe, pulando criação")
    end

    -- RuneManager (Registra ANTES de DropManager)
    if not ManagerRegistry:tryGet("runeManager") then
        Logger.debug("Bootstrap", "Inicializando/Registrando RuneManager...")
        local runeManager = RuneManager -- Assume Singleton.
        -- Chamar :init se necessário: if runeManager.init then runeManager:init({...}) end
        ManagerRegistry:register("runeManager", runeManager, true)
        Logger.debug("Bootstrap", "RuneManager registrado.")
    else
        Logger.debug("Bootstrap", "RuneManager já existe, pulando criação")
    end

    -- DropManager (Agora recebe EnemyManager) - CUIDADO: precisa das dependências corretas
    if not ManagerRegistry:tryGet("dropManager") then
        Logger.debug("Bootstrap", "Inicializando/Registrando DropManager...")

        -- Obtém dependências (podem ter sido criadas acima ou já existir)
        ---@type PlayerManager
        local currentPlayerMgr = ManagerRegistry:get("playerManager")
        ---@type EnemyManager
        local currentEnemyManager = ManagerRegistry:get("enemyManager")
        ---@type RuneManager
        local currentRuneManager = ManagerRegistry:get("runeManager")
        ---@type FloatingTextManager
        local currentFloatingTextManager = ManagerRegistry:get("floatingTextManager")

        local dropManagerConfig = {
            playerManager = currentPlayerMgr,                 -- Instância atual
            enemyManager = currentEnemyManager,               -- Referência ao EnemyManager atual
            runeManager = currentRuneManager,                 -- Tabela/Singleton atual
            floatingTextManager = currentFloatingTextManager, -- Tabela/Singleton atual
            itemDataManager = itemDataManager                 -- Tabela/Singleton
        }

        -- Validação
        if not dropManagerConfig.playerManager or not dropManagerConfig.enemyManager or not dropManagerConfig.runeManager or not dropManagerConfig.floatingTextManager or not dropManagerConfig.itemDataManager then
            Logger.warn("Bootstrap", "Uma ou mais dependências para DropManager:init estão faltando!")
            -- Considere error() se forem críticas
        end

        DropManager:init(dropManagerConfig)
        ManagerRegistry:register("dropManager", DropManager, true)
        Logger.debug("Bootstrap", "DropManager registrado e inicializado.")
    else
        Logger.debug("Bootstrap", "DropManager já existe, pulando criação")
    end

    -- HUDGameplayManager (Depois do PlayerManager)
    if not ManagerRegistry:tryGet("hudGameplayManager") then
        Logger.debug("Bootstrap", "Inicializando/Registrando HUDGameplayManager...")
        ManagerRegistry:register("hudGameplayManager", HUDGameplayManager, true)
        Logger.debug("Bootstrap", "HUDGameplayManager registrado e inicializado.")
    else
        Logger.debug("Bootstrap", "HUDGameplayManager já existe, pulando criação")
    end

    -- ExtractionPortalManager
    if not ManagerRegistry:tryGet("extractionPortalManager") then
        Logger.debug("Bootstrap", "Criando/Registrando ExtractionPortalManager...")
        local extractionPortalManager = ExtractionPortalManager:new()
        ManagerRegistry:register("extractionPortalManager", extractionPortalManager, true)
        Logger.debug("Bootstrap", "ExtractionPortalManager registrado.")
    else
        Logger.debug("Bootstrap", "ExtractionPortalManager já existe, pulando criação")
    end

    -- ExtractionManager
    if not ManagerRegistry:tryGet("extractionManager") then
        Logger.debug("Bootstrap", "Inicializando/Registrando ExtractionManager...")
        local extractionManager = ExtractionManager:new()
        ManagerRegistry:register("extractionManager", extractionManager, true)
        Logger.debug("Bootstrap", "ExtractionManager registrado.")
    else
        Logger.debug("Bootstrap", "ExtractionManager já existe, pulando criação")
    end

    -- 3. Inicialização específica (setupGameplay) é feita na cena
    Logger.info("Bootstrap", "Inicialização dos Managers de GAMEPLAY Concluída")
end

return Bootstrap
