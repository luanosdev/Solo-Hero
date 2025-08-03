local Constants = require("src.config.constants")
local ActionTypes = require("src.types.action_types")
local Camera = require("src.config.camera")
local ManagerRegistry = require("src.managers.manager_registry")

local PlayerStateController = require("src.scenes.gameplay.controllers.player_state_controller")
local ArchetypeGameplayController = require("src.scenes.gameplay.controllers.archetype_gameplay_controller")
local EquipmentGameplayController = require("src.scenes.gameplay.controllers.equipment_gameplay_controller")
local MovementController = require("src.scenes.gameplay.controllers.movement_controller")
local PlayerSpriteController = require("src.scenes.gameplay.controllers.player_sprite_controller")
local TargetingController = require("src.scenes.gameplay.controllers.targeting_controller")
local AutoAttackController = require("src.scenes.gameplay.controllers.auto_attack_controller")
local AreaOfEffectController = require("src.scenes.gameplay.controllers.area_of_effect_controller")
local ExperienceController = require("src.scenes.gameplay.controllers.experience_controller")
local HealthController = require("src.scenes.gameplay.controllers.health_controller")
local CollisionResolutionController = require("src.scenes.gameplay.controllers.collision_resolution_controller")

local CombatGeometry = require("src.utils.combat_geometry")
local TablePool = require("src.utils.table_pool")

---@class PlayerManager
---@description Gerencia o estado e o comportamento do jogador, atuando como um orquestrador
-- para um conjunto de controllers especializados.
---@field context GameplaySceneContext
---@field stateController PlayerStateController
---@field archetypeGameplayController ArchetypeGameplayController
---@field equipmentGameplayController EquipmentGameplayController
---@field playerAppearanceController PlayerAppearanceController
---@field healthController HealthController
---@field experienceController ExperienceController
---@field floatingTextController FloatingTextController
---@field autoAttackController AutoAttackController
---@field runeController RuneController
---@field movementController MovementControllerV2
---@field playerSpriteController PlayerSpriteController
---@field targetingController TargetingController
---@field attackController BaseAttackController
---@field areaOfEffectController AreaOfEffectController
---@field collisionResolutionController CollisionResolutionController
---@field eventListeners table<string, function>
---@field attackContext AttackContext
local PlayerManager = {}
PlayerManager.__index = PlayerManager

PlayerManager.PLAYER_RADIUS = 10

--- Cria uma nova instância do PlayerManager.
--- O construtor é leve e apenas inicializa a estrutura da tabela.
--- A lógica de configuração pesada acontece no :init().
--- @param context GameplaySceneContext
--- @return PlayerManager
function PlayerManager:new(context)
    assert(context, "[PlayerManager] missing a GameplayContext")
    assert(context.args and context.args.hunterId, "PlayerManager:init() requires hunterId.")
    assert(context.args and context.args.preloadedAssets, "PlayerManager:init() requires preloadedAssets.")

    local instance = setmetatable({}, PlayerManager)
    instance.context = context

    -- Inicializa controllers como nil.
    instance.stateController = nil
    instance.archetypeGameplayController = nil
    instance.equipmentGameplayController = nil
    instance.movementController = nil
    instance.playerSpriteController = nil
    instance.targetingController = nil
    instance.autoAttackController = nil
    instance.attackController = nil
    instance.areaOfEffectController = nil
    instance.experienceController = nil
    instance.healthController = nil
    instance.collisionResolutionController = nil

    instance.attackContext = nil
    instance.eventListeners = {}

    return instance
end

--- Inicializa o manager e todos os seus controllers.
--- Este método é chamado pelo GameplayBootstrap depois que TODOS os managers
--- foram construídos e registrados, garantindo que as dependências estejam disponíveis.
function PlayerManager:init()
    Logger.info("player_manager_v2.init.start", "[PlayerManager:init] Initializing for gameplay...")

    self:_startEventListeners()

    local eventService = self.context.serviceLocator.getEventService()
    local itemDataService = self.context.serviceLocator.getItemDataService()
    local inputService = self.context.serviceLocator.getInputService()
    local enemyManager = self.context.registry:get("enemyManager")
    local camera = Camera

    --- TODO: transformar o hunterManager em um service
    ---@type HunterManager
    local hunterManager = ManagerRegistry:get("hunterManager")
    local hunterId = self.context.args.hunterId

    local hunterData = hunterManager.hunters[hunterId]
    local hunterStats = hunterManager:getHunterFinalStats(hunterId)
    local hunterEquipment = hunterManager:getEquippedItems(hunterId)

    ---@type GameplayControllerContext
    local context = {
        services = {
            eventService = self.context.serviceLocator.getEventService(),
            itemDataService = self.context.serviceLocator.getItemDataService(),
            inputService = self.context.serviceLocator.getInputService(),
            assetService = self.context.serviceLocator.getAssetService(),
            gameStatisticsService = self.context.serviceLocator.getGameStatisticsService(),
            gameTimerService = self.context.serviceLocator.getGameTimerService(),
        }
    }

    self.stateController = PlayerStateController:new(context.services.eventService)
    self.stateController:init()

    self.archetypeGameplayController = ArchetypeGameplayController:new(self.context.args.hunterId)
    self.archetypeGameplayController:init()

    self.playerSpriteController = PlayerSpriteController:new(eventService, itemDataService)
    self.playerSpriteController:init(hunterData.skinTone)

    -- O EquipmentGameplayController precisa dos itens iniciais.
    self.equipmentGameplayController = EquipmentGameplayController:new(eventService, itemDataService)
    self.equipmentGameplayController:init(hunterEquipment)

    self.movementController = MovementController:new()
    self.movementController:init()

    self.experienceController = ExperienceController:new(eventService)
    self.experienceController:init()

    self.healthController = HealthController:new(context)
    self.healthController:init(
        self.stateController:getStat("maxHealth"),
        self.stateController:getStat("healthRegen")
    )

    self.targetingController = TargetingController:new(context)
    self.targetingController:init()

    self.autoAttackController = AutoAttackController:new(context)
    self.autoAttackController:init()

    self.areaOfEffectController = AreaOfEffectController:new()
    self.areaOfEffectController:init()

    self.collisionResolutionController = CollisionResolutionController:new(context)
    self.collisionResolutionController:init()

    self.attackContext = {
        finalStats = self.stateController:getAllStats(),
        playerPosition = self.movementController:getPosition(),
        playerAngle = 0,
        isMoving = self.movementController:isMoving(),
        playerRadius = PlayerManager.PLAYER_RADIUS,
        targetPosition = { x = 0, y = 0 },
    }

    Logger.info("player_manager_v2.init.success", "[PlayerManager:init] Successfully initialized.")
end

--- Atualiza todos os controllers do jogador.
---@param dt number O tempo delta desde o último frame.
function PlayerManager:update(dt)
    local inputService = self.context.serviceLocator.getInputService()
    local enemyManager = self.context.registry:getEnemyManager()

    if not self.stateController or not self.movementController or not self.targetingController then return end

    -- Orquestração do Movimento e Animação
    local moveSpeed = self.stateController:getStat("moveSpeed")

    local moveSpeedInPixels = Constants.moveSpeedToPixels(moveSpeed)
    local moveVector = inputService:getMovementVector()
    self.movementController:update(dt, moveSpeedInPixels, moveVector)

    -- Orquestração da Mira
    local playerPosition = self.movementController:getPosition()
    local isHoldingAttack = inputService:isActionDown(ActionTypes.ATTACK)

    -- Força a mira no mouse se o jogador estiver segurando o botão de ataque.
    local targetPosition = self.targetingController:getTargetPosition(
        playerPosition,
        enemyManager.spatialGrid,
        isHoldingAttack
    )

    local dx = targetPosition.x - playerPosition.x
    local dy = targetPosition.y - playerPosition.y
    local angle = math.atan2(dy, dx)

    -- Atualiza o contexto de ataque com os dados mais recentes
    self.attackContext.finalStats = self.stateController:getAllStats()
    self.attackContext.playerPosition = playerPosition
    self.attackContext.playerAngle = angle

    self.attackContext.isMoving = self.movementController:isMoving()

    -- Atualiza os controllers com os dados orquestrados
    self.playerSpriteController:update(dt, moveSpeedInPixels, moveVector, playerPosition, angle)
    if self.autoAttackController then self.autoAttackController:update() end
    if self.targetingController then self.targetingController:update() end
    if self.attackController then self.attackController:update(dt, self.attackContext) end

    -- Lógica de orquestração de ataque.
    -- Para uma explicação detalhada das regras, consulte: docs/SISTEMA_DE_ATAQUE.md
    local attackDescriptors = nil

    if self.autoAttackController and self.attackController then
        -- Ao PRESSIONAR o botão de ataque:
        if inputService:wasActionPressed(ActionTypes.ATTACK) then
            -- 1. Ativa a sobreposição do auto-ataque
            self.autoAttackController:overrideAutoAttack(true)
            -- 2. Tenta um ataque imediato para dar resposta ao clique
            attackDescriptors = self.attackController:tryAttack(self.attackContext)
        end

        -- Ao SOLTAR o botão de ataque:
        if inputService:wasActionReleased(ActionTypes.ATTACK) then
            -- 1. Remove a sobreposição do auto-ataque
            self.autoAttackController:overrideAutoAttack(false)
        end

        -- Tenta executar o ataque contínuo (se o auto-ataque estiver ativo por 'X' ou por segurar o botão)
        -- Só executa se um ataque já não tiver sido disparado pelo clique inicial
        if not attackDescriptors and self.autoAttackController:isAutoAttackEnabled() then
            attackDescriptors = self.attackController:tryAttack(self.attackContext)
        end
    end


    if attackDescriptors and #attackDescriptors > 0 then
        -- Processa os descritores para encontrar alvos e aplicar efeitos
        self:_processAttackDescriptors(attackDescriptors)

        -- Dispara a animação de ataque correspondente
        local animationType = self.attackController.cachedBaseData.animationType
        self.playerSpriteController:updateAttackAnimation({ animation = animationType })

        -- Libera a tabela de descritores de volta para o pool
        TablePool.releaseArray(attackDescriptors)
    end
end

--- Coleta os renderizáveis do jogador e seus efeitos para o RenderPipeline.
---@param renderPipeline RenderPipeline A instância do pipeline de renderização.
function PlayerManager:collectRenderables(renderPipeline)
    if self.playerSpriteController and self.movementController then
        local worldPosition = self.movementController:getPosition()
        self.playerSpriteController:collectRenderables(
            renderPipeline,
            worldPosition
        )
    end
    if self.attackController then
        self.attackController:collectRenderables(renderPipeline, self.attackContext)
    end
end

--- Retorna a posição atual do jogador no mundo.
--- Utilizado pela câmera e outros sistemas para saber onde o jogador está.
---@return Vector2D
function PlayerManager:getPosition()
    if self.movementController then
        return self.movementController:getPosition()
    end

    Logger.error("player_manager_v2.getPosition.error",
        "[PlayerManager:getPosition] MovementController não encontrado.")
    -- Retorna uma posição padrão segura se o controller não existir.
    return { x = 0, y = 0 }
end

---@public Adiciona experiência ao jogador.
---@param amount number Quantidade de experiência a ser adicionada
---@return number levelsGained Quantidade de levels ganhos
function PlayerManager:addExperience(amount)
    local expBonus = self.stateController:getStat("expBonus")
    return self.experienceController:addExperience(amount, expBonus)
end

--- Lida com a detecção de colisão entre o jogador e um inimigo.
--- Este método atua como um orquestrador, coletando os dados necessários (estatísticas do jogador)
--- e delegando a lógica de resolução da colisão para o controller especializado.
---@param enemy BaseEnemy O inimigo que colidiu com o jogador.
function PlayerManager:handleEnemyCollision(enemy)
    if not self.collisionResolutionController then return end

    local playerStats = self.stateController:getAllStats()
    self.collisionResolutionController:processCollision(enemy, playerStats)
end

---@private Orquestra a execução de uma lista de descritores de ataque.
---@description Para cada descritor, busca os inimigos candidatos, filtra os alvos
---@description com o AreaOfEffectController e aplica dano e efeitos.
---@param attackDescriptors AttackDescriptor[] A lista de ataques a serem processados.
function PlayerManager:_processAttackDescriptors(attackDescriptors)
    local enemyManager = self.context.registry:getEnemyManager()
    local gameStatsService = self.context.serviceLocator.getGameStatisticsService()
    if not enemyManager or not gameStatsService then return end

    local finalStats = self.attackContext.finalStats
    local weaponInstance = self.attackController.weaponInstance

    for _, descriptor in ipairs(attackDescriptors) do
        local candidates = nil
        local enemiesHit = nil

        -- A busca de candidatos (getNearbyEnemies) é feita por shape,
        -- pois cada um pode ter uma forma diferente de definir sua área de busca.
        if descriptor.shape == "cone" then
            candidates = enemyManager:getNearbyEnemies(descriptor.origin, descriptor.range)
            enemiesHit = self.areaOfEffectController:findEntitiesInCone(
                candidates,
                descriptor.origin,
                descriptor.angle,
                descriptor.range,
                descriptor.halfWidth
            )
        elseif descriptor.shape == "circle" then
            -- Assumimos que o descritor de círculo tem 'radius' e o usamos para a busca.
            candidates = enemyManager:getNearbyEnemies(descriptor.origin, descriptor.radius)
            enemiesHit = self.areaOfEffectController:findEntitiesInCircle(
                candidates,
                descriptor.origin,
                descriptor.radius
            )
        elseif descriptor.shape == "line" then
            -- Para linhas, o range é o comprimento. Precisamos pegá-lo da descriptor.
            local lineLength = math.sqrt((descriptor.endPos.x - descriptor.startPos.x) ^ 2 +
                (descriptor.endPos.y - descriptor.startPos.y) ^ 2)
            candidates = enemyManager:getNearbyEnemies(descriptor.startPos, lineLength)
            enemiesHit = self.areaOfEffectController:findEntitiesInLine(
                candidates,
                descriptor.startPos,
                descriptor.endPos,
                descriptor.width
            )
        elseif descriptor.shape == "polygon" then
            candidates = enemyManager:getNearbyEnemies(descriptor.origin, descriptor.range)
            -- A função findEntitiesInPolygon será implementada no AreaOfEffectController
            enemiesHit = self.areaOfEffectController:findEntitiesInPolygon(
                candidates,
                descriptor.vertices
            )
        end

        if candidates then
            Logger.debug("player_manager.process_attack.candidates",
                string.format("[PlayerManager:_processAttackDescriptors] %d candidatos para ataque %s",
                    #candidates, descriptor.shape))
        end


        if enemiesHit and #enemiesHit > 0 then
            Logger.debug("player_manager.process_attack.hits",
                string.format("[PlayerManager:_processAttackDescriptors] %d inimigos atingidos de %d candidatos",
                    #enemiesHit, candidates and #candidates or 0))
            gameStatsService:registerEnemiesHit(#enemiesHit)

            for _, enemy in ipairs(enemiesHit) do
                if enemy and enemy.isAlive then
                    -- 1. Calcula o dano
                    local damageToApply, isCritical, isSuperCritical = CombatGeometry.calculateSuperCriticalDamage(
                        finalStats.damage,
                        finalStats.criticalChance,
                        finalStats.criticalDamage - 1
                    )

                    -- 2. Aplica o dano à entidade
                    enemy:takeDamage(damageToApply, isCritical, isSuperCritical)

                    -- 3. Registra estatísticas
                    gameStatsService:registerDamageDealt(damageToApply, isCritical,
                        { weaponId = weaponInstance.itemBaseId }, isSuperCritical)

                    -- 4. Aplica Knockback (se houver)
                    -- A lógica de knockback deve ser movida para a entidade inimiga no futuro.
                    -- Por enquanto, replicamos a lógica do antigo CombatHelpers.
                    local knockbackData = self.attackController.cachedBaseData
                    if knockbackData.knockbackPower and knockbackData.knockbackPower > 0 then
                        local dirX = enemy.position.x - descriptor.origin.x
                        local dirY = enemy.position.y - descriptor.origin.y
                        local dist = math.sqrt(dirX * dirX + dirY * dirY)
                        if dist > 0 then
                            dirX = dirX / dist
                            dirY = dirY / dist
                            local knockbackVelocity = (finalStats.strength + (knockbackData.knockbackForce or 0))
                            enemy:applyKnockback(dirX, dirY, knockbackVelocity)
                        end
                    end
                end
            end
        end

        if candidates then
            TablePool.releaseArray(candidates)
        end
        if enemiesHit then
            TablePool.releaseArray(enemiesHit)
        end
    end
end

---@private Inicia as instancias de eventos
function PlayerManager:_startEventListeners()
    local eventService = self.context.serviceLocator.getEventService()
    self:_listen(eventService.EVENTS.EQUIPMENT_CHANGED, self._setCurrentAttack)
end

---@private Registra um listener de eventos.
---@param event string
---@param handler function
function PlayerManager:_listen(event, handler)
    local eventService = self.context.serviceLocator.getEventService()
    local listener = eventService:on(event, function(data) handler(self, data) end)
    table.insert(self.eventListeners, listener)
end

---@private Ouvinte de eventos para o evento EQUIPMENT_CHANGED
function PlayerManager:_setCurrentAttack(eventData)
    Logger.info(
        "gameplay.player_manager._setCurrentAttack",
        string.format("[PlayerManager:_setCurrentAttack] Event details - slotId: %s, newItem: %s, allEquipped: %s ",
            eventData.slotId,
            eventData.newItem and eventData.newItem.itemBaseId or "nil",
            eventData.allEquipped and eventData.allEquipped[Constants.SLOT_IDS.WEAPON] and
            eventData.allEquipped[Constants.SLOT_IDS.WEAPON].itemBaseId or "nil"
        )
    )


    if eventData.slotId and eventData.slotId ~= Constants.SLOT_IDS.WEAPON then
        return
    end

    self:_clearCurrentAttackInstance()

    if (not eventData.slotId and eventData.allEquipped) or (eventData.slotId and eventData.slotId == Constants.SLOT_IDS.WEAPON) then
        local weapon = eventData.allEquipped[Constants.SLOT_IDS.WEAPON]
        if weapon then
            self:_setCurrentAttackInstance(weapon)
        end
    end
end

---@private Define a instância de ataque atual.
function PlayerManager:_setCurrentAttackInstance(weapon)
    local itemDataService = self.context.serviceLocator.getItemDataService()
    local itemData = itemDataService:getBaseItemData(weapon.itemBaseId)

    local weaponClassPath = "src.entities.equipments.weapons." .. itemData.weaponClass
    local requireWeaponClassAsSuccess, WeaponClass = pcall(require, weaponClassPath)

    if not requireWeaponClassAsSuccess or not WeaponClass then
        error(string.format("[PlayerManager:_setCurrentAttackInstance] Weapon class not found for item: %s",
            weapon.itemBaseId))
    end

    local weaponInstance = WeaponClass:new({ itemBaseId = weapon.itemBaseId })

    local attackControllerClassPath = "src.scenes.gameplay.controllers.attacks." .. itemData.attackClass .. "_controller"
    local success, AttackControllerClass = pcall(require, attackControllerClassPath)

    if not success or not AttackControllerClass then
        error(string.format(
            "[PlayerManager:_setCurrentAttackInstance] Attack controller not found: %s",
            attackControllerClassPath))
    end

    self.attackController = AttackControllerClass:new(weaponInstance)
end

---@private Limpa a instância de ataque atual.
function PlayerManager:_clearCurrentAttackInstance()
    if self.attackController then
        self.attackController:destroy()
    end
end

--- Limpa os recursos e se desregistra de eventos.
--- Chamado pelo GameplayBootstrap quando a cena é descarregada.
function PlayerManager:destroy()
    Logger.info("player_manager_v2.destroy", "[PlayerManager:destroy] Destroying...")
    if self.stateController then self.stateController:destroy() end
    if self.archetypeGameplayController then self.archetypeGameplayController:destroy() end
    if self.equipmentGameplayController then self.equipmentGameplayController:destroy() end
    if self.attackController then self.attackController:destroy() end
    if self.movementController then self.movementController:destroy() end
    if self.playerSpriteController then self.playerSpriteController:destroy() end
    if self.targetingController then self.targetingController:destroy() end
    if self.autoAttackController then self.autoAttackController:destroy() end
    if self.collisionResolutionController then self.collisionResolutionController:destroy() end
end

return PlayerManager
