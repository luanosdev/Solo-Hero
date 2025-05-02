-- src/core/bootstrap.lua
local ManagerRegistry = require("src.managers.manager_registry")

-- Requires dos managers
local InputManager = require("src.managers.input_manager")
local ItemDataManager = require("src.managers.item_data_manager")
local InventoryManager = require("src.managers.inventory_manager")
local PlayerManager = require("src.managers.player_manager")
local EnemyManager = require("src.managers.enemy_manager")
local FloatingTextManager = require("src.managers.floating_text_manager")
local ExperienceOrbManager = require("src.managers.experience_orb_manager")
local DropManager = require("src.managers.drop_manager")
local RuneManager = require("src.managers.rune_manager")
local HunterManager = require("src.managers.hunter_manager")
local LoadoutManager = require("src.managers.loadout_manager")
local ArchetypeManager = require("src.managers.archetype_manager")
local ItemDataManager = require("src.managers.item_data_manager")

local Bootstrap = {}

function Bootstrap.initialize()
    -- Cria instâncias dos Managers na ordem correta de dependência
    print("--- [Bootstrap] Criando Instâncias dos Managers com DI ---")
    -- InputManager é um singleton/módulo, usamos diretamente
    local inputMgr = InputManager
    local itemDataMgr = ItemDataManager:new()
    local floatingTextMgr = FloatingTextManager
    local expOrbMgr = ExperienceOrbManager
    local playerMgr = PlayerManager -- Singleton, referência direta
    local enemyMgr = EnemyManager
    local runeMgr = RuneManager
    local dropMgr = DropManager -- Singleton, referência direta
    local archMgr = ArchetypeManager:new()
    local loadoutMgr = LoadoutManager:new(itemDataMgr)
    local inventoryMgr = InventoryManager:new({
        itemDataManager = itemDataMgr
    })
    local hunterMgr = HunterManager:new(loadoutMgr, itemDataMgr, archMgr)

    print("--- [Bootstrap] Registrando Managers (Instâncias) ---")
    ManagerRegistry:register("inputManager", inputMgr, false)
    ManagerRegistry:register("itemDataManager", itemDataMgr, false)
    ManagerRegistry:register("inventoryManager", inventoryMgr, false)
    ManagerRegistry:register("playerManager", playerMgr, false)
    ManagerRegistry:register("enemyManager", enemyMgr, true)
    ManagerRegistry:register("floatingTextManager", floatingTextMgr, true)
    ManagerRegistry:register("experienceOrbManager", expOrbMgr, true)
    ManagerRegistry:register("dropManager", dropMgr, true)
    ManagerRegistry:register("runeManager", runeMgr, true)
    ManagerRegistry:register("archetypeManager", archMgr, false)
    ManagerRegistry:register("loadoutManager", loadoutMgr, false)
    ManagerRegistry:register("hunterManager", hunterMgr, false)

    -- Configuração para métodos :init que precisam de injeção pós-registro
    local initConfigs = {
        playerManager = {
            inputManager = inputMgr,
            enemyManager = enemyMgr,
            floatingTextManager = floatingTextMgr,
            inventoryManager = inventoryMgr
        },
        dropManager = {
            playerManager = playerMgr,
            enemyManager = enemyMgr,
            runeManager = runeMgr,
            floatingTextManager = floatingTextMgr,
            itemDataManager = itemDataMgr,
            mapRank = "E" -- TODO: Obter rank do mapa de forma dinâmica
        }
        -- Adicione configs para outros inits aqui
    }

    print("--- [Bootstrap] Inicializando Managers (via Registry) ---")
    ManagerRegistry:init(initConfigs)
    print("--- [Bootstrap] Inicialização Concluída ---")

    -- Retorna o registry configurado, se necessário (opcional)
    -- return ManagerRegistry
end

return Bootstrap
