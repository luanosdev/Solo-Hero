local PlayerStateController = require("src.scenes.gameplay.controllers.player_state_controller")
local ArchetypeGameplayController = require("src.scenes.gameplay.controllers.archetype_gameplay_controller")
local EquipmentGameplayController = require("src.scenes.gameplay.controllers.equipment_gameplay_controller")
local WeaponAttackController = require("src.scenes.gameplay.controllers.weapon_attack_controller")
local PlayerAppearanceController = require("src.scenes.gameplay.controllers.player_appearance_controller")

---@class PlayerManagerV2
---@description Gerencia o estado e o comportamento do jogador, atuando como um orquestrador
-- para um conjunto de controllers especializados.
---@field registry SceneManagerRegistry A referência ao registro de managers da cena.
---@field renderPipeline RenderPipeline
---@field stateController PlayerStateControllerV2
---@field archetypeGameplayController ArchetypeGameplayController
---@field equipmentGameplayController EquipmentGameplayController
---@field weaponAttackController WeaponAttackController
---@field playerAppearanceController PlayerAppearanceController
---@field healthController HealthController
---@field experienceController ExperienceController
---@field floatingTextController FloatingTextController
---@field autoAttackController AutoAttackController
---@field runeController RuneController
---@field movementController MovementController
---@field dashController DashController
---@field levelUpEffectController LevelUpEffectController
---@field potionController PotionController
local PlayerManager = {}
PlayerManager.__index = PlayerManager

--- Cria uma nova instância do PlayerManager.
--- O construtor é leve e apenas inicializa a estrutura da tabela.
--- A lógica de configuração pesada acontece no :init().
--- @param registry SceneManagerRegistry A instância do registro de managers da cena.
--- @param renderPipeline RenderPipeline A instância do pipeline de renderização.
--- @return PlayerManagerV2
function PlayerManager:new(registry, renderPipeline)
    assert(registry, "[PlayerManager] missing a ManagerRegistry")
    assert(renderPipeline, "[PlayerManager] missing a RenderPipeline")

    local instance = setmetatable({}, PlayerManager)
    instance.registry = registry
    instance.renderPipeline = renderPipeline

    -- Inicializa controllers como nil.
    instance.stateController = nil
    instance.archetypeGameplayController = nil
    instance.equipmentGameplayController = nil
    instance.weaponAttackController = nil
    instance.playerAppearanceController = nil
    -- ... outros controllers
    return instance
end

--- Inicializa o manager e todos os seus controllers.
--- Este método é chamado pelo GameplayBootstrap depois que TODOS os managers
--- foram construídos e registrados, garantindo que as dependências estejam disponíveis.
--- @param args GameplaySceneArgs Argumentos da cena, contendo hunterId, etc.
function PlayerManager:init(args)
    Logger.info("player_manager_v2.init.start", "[PlayerManager:init] Initializing for gameplay...")
    assert(args and args.hunterId, "PlayerManager:init() requires hunterId.")
    assert(args and args.preloadedAssets, "PlayerManager:init() requires preloadedAssets.")

    self.stateController = PlayerStateController:new()
    self.stateController:init()

    self.archetypeGameplayController = ArchetypeGameplayController:new(args.hunterId)
    self.archetypeGameplayController:init()

    -- O EquipmentGameplayController precisa dos itens iniciais.
    -- TODO: Obter `initialItems` dos dados do caçador. Por enquanto, uma tabela vazia.
    local initialItems = {}
    self.equipmentGameplayController = EquipmentGameplayController:new()
    self.equipmentGameplayController:init(initialItems)

    -- Controllers de Ação e Aparência (podem ter dependências)
    self.weaponAttackController = WeaponAttackController:new()
    self.weaponAttackController:init()

    -- O PlayerAppearanceController precisa da entidade do jogador.
    -- Vamos assumir que o MovementController a cria e a expõe.
    -- self.movementController = MovementController:new(...)
    -- self.movementController:init()
    -- local playerEntity = self.movementController.player
    -- self.playerAppearanceController = PlayerAppearanceController:new(playerEntity)
    -- self.playerAppearanceController:init()

    Logger.info("player_manager_v2.init.success", "[PlayerManager:init] Successfully initialized.")
end

--- Atualiza todos os controllers do jogador.
---@param dt number O tempo delta desde o último frame.
function PlayerManager:update(dt)
    if self.weaponAttackController then
        self.weaponAttackController:update(dt)
    end
end

--- Coleta os renderizáveis do jogador e seus efeitos para o RenderPipeline.
---@param renderPipeline RenderPipeline A instância do pipeline de renderização.
function PlayerManager:collectRenderables(renderPipeline)
    if self.weaponAttackController then
        self.weaponAttackController:collectRenderables(renderPipeline)
    end
end

--- Limpa os recursos e se desregistra de eventos.
--- Chamado pelo GameplayBootstrap quando a cena é descarregada.
function PlayerManager:destroy()
    Logger.info("player_manager_v2.destroy", "[PlayerManager:destroy] Destroying...")
    if self.stateController then self.stateController:destroy() end
    if self.archetypeGameplayController then self.archetypeGameplayController:destroy() end
    if self.equipmentGameplayController then self.equipmentGameplayController:destroy() end
    if self.weaponAttackController then self.weaponAttackController:destroy() end
    if self.playerAppearanceController then self.playerAppearanceController:destroy() end
end

return PlayerManager
