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

local Bootstrap = {}

function Bootstrap.initialize()
    print("--- [Bootstrap] Criando Instâncias dos Managers de GAMEPLAY com DI ---")

    -- 1. Obter managers PERSISTENTES do Registry (essenciais como dependências)
    local itemDataManager = ManagerRegistry:get("itemDataManager")
    local hunterManager = ManagerRegistry:get("hunterManager")
    -- Adicione outros managers persistentes necessários como dependências aqui
    -- Ex: loadoutManager, archetypeManager, se forem necessários para os managers de gameplay

    -- Validação das dependências persistentes obtidas
    if not itemDataManager or not hunterManager then
        error("ERRO CRÍTICO [Bootstrap.initialize]: Falha ao obter ItemDataManager ou HunterManager do Registry!")
    end

    -- 2. Criar e Registrar managers de GAMEPLAY

    print("  - Criando InputManager...")
    local inputManager = InputManager -- :new não precisa de dependências persistentes?
    ManagerRegistry:register("inputManager", inputManager)
    print("    > InputManager registrado.")

    -- InventoryManager (depende de ItemDataManager)
    print("  - Criando InventoryManager...")
    -- CORRIGIDO: Passa explicitamente como parâmetro nomeado esperado pelo construtor do InventoryManager
    -- (Assumindo que InventoryManager:new espera uma tabela de config {itemDataManager = ...})
    local inventoryManager = InventoryManager:new({ itemDataManager = itemDataManager })
    ManagerRegistry:register("inventoryManager", inventoryManager)
    print("    > InventoryManager registrado.")

    -- FloatingTextManager (sem dependências diretas aqui?)
    print("  - Criando FloatingTextManager...")
    local floatingTextManager = FloatingTextManager
    ManagerRegistry:register("floatingTextManager", floatingTextManager, true)
    print("    > FloatingTextManager registrado.")

    -- ExperienceOrbManager (depende de FloatingTextManager?)
    print("  - Criando ExperienceOrbManager...")
    local experienceOrbManager = ExperienceOrbManager
    ManagerRegistry:register("experienceOrbManager", experienceOrbManager, true)
    print("    > ExperienceOrbManager registrado.")

    -- PlayerManager (será configurado depois pela GameplayScene, mas precisa ser criado)
    -- Suas dependências SÃO injetadas pelo setupGameplay via Registry
    print("  - Criando PlayerManager...")
    local playerMgr = PlayerManager:new()
    -- CORREÇÃO: Registra PlayerManager com drawInCamera = true
    ManagerRegistry:register("playerManager", playerMgr, true)
    print("    > PlayerManager registrado (aguardando setupGameplay).")

    -- DropManager (depende de ItemDataManager, FloatingTextManager, ExperienceOrbManager)
    print("  - Criando DropManager...")
    local dropManager = DropManager
    ManagerRegistry:register("dropManager", dropManager, true)
    print("    > DropManager registrado.")

    -- EnemyManager (será configurado depois pela GameplayScene, precisa ser criado)
    -- Depende de PlayerManager e DropManager (obtidos via Registry em setupGameplay)
    print("  - Criando EnemyManager...")
    local enemyManager = EnemyManager
    ManagerRegistry:register("enemyManager", enemyManager, true)
    print("    > EnemyManager registrado (aguardando setupGameplay).")

    -- RuneManager (depende de PlayerManager?, ItemDataManager?) - Verificar dependências
    print("  - Criando RuneManager...")
    -- Ajustar o :new se RuneManager precisar de dependências injetadas
    local runeManager = RuneManager
    ManagerRegistry:register("runeManager", runeManager, true)
    print("    > RuneManager registrado.")

    -- 3. Inicializar Managers (Opcional aqui, pode ser feito na GameplayScene ou nos :new)
    -- A inicialização específica de gameplay (como setupGameplay) será chamada pela GameplayScene.
    -- A inicialização genérica (:init) deve ser feita aqui se necessário.

    print("--- [Bootstrap] Inicialização dos Managers de GAMEPLAY Concluída ---")
end

return Bootstrap
