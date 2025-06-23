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

function Bootstrap.initialize()
    print("--- [Bootstrap] Criando Instâncias dos Managers de GAMEPLAY com DI ---")

    -- 1. Obter managers PERSISTENTES do Registry
    local itemDataManager = ManagerRegistry:get("itemDataManager")
    local hunterManager = ManagerRegistry:get("hunterManager")
    if not itemDataManager then error("ERRO CRÍTICO [Bootstrap.initialize]: Falha ao obter ItemDataManager do Registry!") end

    -- 2. Criar/Inicializar/Registrar managers de GAMEPLAY (Ordem ajustada)

    -- InputManager
    print("  - Criando/Registrando InputManager...")
    ManagerRegistry:register("inputManager", InputManager)
    print("    > InputManager registrado.")

    -- InventoryManager
    print("  - Criando/Registrando InventoryManager...")
    local inventoryManager = InventoryManager:new({ itemDataManager = itemDataManager })
    ManagerRegistry:register("inventoryManager", inventoryManager)
    print("    > InventoryManager registrado.")

    -- FloatingTextManager
    print("  - Inicializando/Registrando FloatingTextManager...")
    ManagerRegistry:register("floatingTextManager", FloatingTextManager, false)
    print("    > FloatingTextManager registrado.")

    -- ExperienceOrbManager
    print("  - Inicializando/Registrando ExperienceOrbManager...")
    ManagerRegistry:register("experienceOrbManager", ExperienceOrbManager, true)
    print("    > ExperienceOrbManager registrado.")

    -- PlayerManager (Cria instância)
    print("  - Criando/Registrando PlayerManager...")
    local playerMgr = PlayerManager:new()
    ManagerRegistry:register("playerManager", playerMgr, false)
    print("    > PlayerManager registrado (aguardando setupGameplay).")

    -- EnemyManager (Registra ANTES de DropManager)
    print("  - Criando/Registrando EnemyManager...")
    local enemyManager =
        EnemyManager                                             -- Assume Singleton. Se não for: local enemyManager = EnemyManager:new()
    -- Chamar :init se necessário: if enemyManager.init then enemyManager:init({...}) end
    ManagerRegistry:register("enemyManager", enemyManager, true) -- Registra a tabela/instância
    print("    > EnemyManager registrado (aguardando setupGameplay).")

    -- RuneManager (Registra ANTES de DropManager)
    print("  - Inicializando/Registrando RuneManager...")
    local runeManager = RuneManager -- Assume Singleton.
    -- Chamar :init se necessário: if runeManager.init then runeManager:init({...}) end
    ManagerRegistry:register("runeManager", runeManager, true)
    print("    > RuneManager registrado.")

    -- DropManager (Agora recebe EnemyManager)
    print("  - Inicializando/Registrando DropManager...")
    local dropManagerConfig = {
        playerManager = playerMgr,                 -- Instância
        enemyManager = enemyManager,               -- <<< Referência ao EnemyManager (singleton/instância)
        runeManager = runeManager,                 -- Tabela/Singleton
        floatingTextManager = FloatingTextManager, -- Tabela/Singleton
        itemDataManager = itemDataManager          -- Tabela/Singleton
    }
    -- Validação
    if not dropManagerConfig.playerManager or not dropManagerConfig.enemyManager or not dropManagerConfig.runeManager or not dropManagerConfig.floatingTextManager or not dropManagerConfig.itemDataManager then
        print("AVISO [Bootstrap]: Uma ou mais dependências para DropManager:init estão faltando!")
        -- Considere error() se forem críticas
    end
    DropManager:init(dropManagerConfig)
    ManagerRegistry:register("dropManager", DropManager, true)
    print("    > DropManager registrado e inicializado.")

    -- HUDGameplayManager (Depois do PlayerManager)
    print("  - Inicializando/Registrando HUDGameplayManager...")
    ManagerRegistry:register("hudGameplayManager", HUDGameplayManager, true)
    print("    > HUDGameplayManager registrado e inicializado.")

    -- ExtractionPortalManager
    print("  - Criando/Registrando ExtractionPortalManager...")
    local extractionPortalManager = ExtractionPortalManager:new()
    ManagerRegistry:register("extractionPortalManager", extractionPortalManager, true)
    print("    > ExtractionPortalManager registrado.")

    -- ExtractionManager
    print("  - Inicializando/Registrando ExtractionManager...")
    local extractionManager = ExtractionManager:new()
    ManagerRegistry:register("extractionManager", extractionManager, true)
    print("    > ExtractionManager registrado.")

    -- 3. Inicialização específica (setupGameplay) é feita na cena
    print("--- [Bootstrap] Inicialização dos Managers de GAMEPLAY Concluída ---")
end

return Bootstrap
