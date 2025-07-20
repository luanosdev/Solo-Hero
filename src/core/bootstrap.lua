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
local CullingManager = require("src.managers.culling_manager")

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

    -- 1. Obter managers persistentes
    local itemDataManager = ManagerRegistry:get("itemDataManager")
    local hunterManager = ManagerRegistry:get("hunterManager")
    if not itemDataManager then error("ERRO CRÍTICO [Bootstrap.initialize]: Falha ao obter ItemDataManager do Registry!") end

    -- 2. Criar/Inicializar/Registrar managers de GAMEPLAY
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

    if not ManagerRegistry:tryGet("cullingManager") then
        Logger.debug("Bootstrap", "Criando/Registrando CullingManager...")
        local cullingManager = CullingManager:new()
        ManagerRegistry:register("cullingManager", cullingManager, false)
        Logger.debug("Bootstrap", "CullingManager registrado.")
    else
        Logger.debug("Bootstrap", "CullingManager já existe, pulando criação")
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

    -- PlayerManager (Cria instância)
    if not ManagerRegistry:tryGet("playerManager") then
        Logger.debug("Bootstrap", "Criando/Registrando PlayerManager...")
        local playerMgr = PlayerManager:new()
        ManagerRegistry:register("playerManager", playerMgr, false)
        Logger.debug("Bootstrap", "PlayerManager registrado.")
    else
        Logger.debug("Bootstrap", "PlayerManager já existe, pulando criação")
    end

    -- RuneManager (Dependência do DropManager)
    if not ManagerRegistry:tryGet("runeManager") then
        Logger.debug("Bootstrap", "Inicializando/Registrando RuneManager...")
        ManagerRegistry:register("runeManager", RuneManager, true)
        Logger.debug("Bootstrap", "RuneManager registrado.")
    else
        Logger.debug("Bootstrap", "RuneManager já existe, pulando criação")
    end

    -- DropManager (Dependência do EnemyManager)
    if not ManagerRegistry:tryGet("dropManager") then
        Logger.debug("Bootstrap", "Inicializando/Registrando DropManager...")
        local dropManagerConfig = {
            playerManager = ManagerRegistry:get("playerManager"),
            enemyManager = nil, -- Será injetado depois se necessário, ou removido como dependência
            runeManager = ManagerRegistry:get("runeManager"),
            floatingTextManager = ManagerRegistry:get("floatingTextManager"),
            itemDataManager = itemDataManager
        }
        DropManager:init(dropManagerConfig)
        ManagerRegistry:register("dropManager", DropManager, true)
        Logger.debug("Bootstrap", "DropManager registrado e inicializado.")
    else
        Logger.debug("Bootstrap", "DropManager já existe, pulando criação")
    end

    -- EnemyManager (Agora é uma instância, criado depois de suas dependências)
    if not ManagerRegistry:tryGet("enemyManager") then
        Logger.debug("Bootstrap", "Criando/Registrando instância do EnemyManager...")
        local playerManager = ManagerRegistry:get("playerManager")
        local dropManager = ManagerRegistry:get("dropManager")
        local enemyManagerInstance = EnemyManager:new(playerManager, dropManager)
        ManagerRegistry:register("enemyManager", enemyManagerInstance, false)
        Logger.debug("Bootstrap", "Instância do EnemyManager registrada.")
    else
        Logger.debug("Bootstrap", "Instância do EnemyManager já existe, pulando criação")
    end

    -- HUDGameplayManager
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

    Logger.info("Bootstrap", "Inicialização dos Managers de GAMEPLAY Concluída")
end

return Bootstrap
