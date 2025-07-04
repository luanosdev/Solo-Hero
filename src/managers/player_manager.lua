-------------------------------------------------------------------------
--    Módulo de gerenciamento do player
-------------------------------------------------------------------------

local SpritePlayer = require('src.animations.sprite_player')
local LevelUpModal = require("src.ui.level_up_modal")
local Camera = require("src.config.camera")
local LevelUpAnimation = require("src.animations.level_up_animation")
local Constants = require("src.config.constants")
local RenderPipeline = require("src.core.render_pipeline")
local TablePool = require("src.utils.table_pool")

-- Controllers
local DashController = require('src.controllers.dash_controller')
local LevelUpEffectController = require('src.controllers.level_up_effect_controller')
local PotionController = require('src.controllers.potion_controller')
local PlayerStateController = require('src.controllers.player_state_controller')
local HealthController = require('src.controllers.health_controller')
local ExperienceController = require('src.controllers.experience_controller')
local FloatingTextController = require('src.controllers.floating_text_controller')
local AutoAttackController = require('src.controllers.auto_attack_controller')
local WeaponController = require('src.controllers.weapon_controller')
local RuneController = require('src.controllers.rune_controller')
local MovementController = require('src.controllers.movement_controller')

---@class PlayerSprite
---@field position Vector2D Posição do sprite do jogador
---@field velocity Vector2D Velocidade atual do jogador
---@field animationPaused boolean Se a animação está pausada
---@field [string] any Outras propriedades do sprite

---@class PlayerManager
local PlayerManager = {
    -- Referência ao player sprite
    ---@deprecated Use getPlayerPosition em vez disso
    player = nil, ---@type PlayerSprite|nil

    -- Controllers
    stateController = nil, ---@type PlayerStateController
    healthController = nil, ---@type HealthController
    experienceController = nil, ---@type ExperienceController
    floatingTextController = nil, ---@type FloatingTextController
    autoAttackController = nil, ---@type AutoAttackController
    weaponController = nil, ---@type WeaponController
    runeController = nil, ---@type RuneController
    movementController = nil, ---@type MovementController
    dashController = nil, ---@type DashController
    levelUpEffectController = nil, ---@type LevelUpEffectController
    potionController = nil, ---@type PotionController

    -- Game Stats
    gameTime = 0,

    -- Tamanho do círculo de colisão
    radius = 15,

    -- Level Up Animation
    isLevelingUp = false,
    levelUpAnimation = nil,

    -- Level Up Modal Management
    pendingLevelUps = 0,

    -- Managers injetados
    inputManager = nil, ---@type InputManager
    enemyManager = nil, ---@type EnemyManager
    floatingTextManager = nil, ---@type FloatingTextManager
    inventoryManager = nil, ---@type InventoryManager
    hunterManager = nil, ---@type HunterManager
    itemDataManager = nil, ---@type ItemDataManager
    archetypeManager = nil, ---@type ArchetypeManager
    gameStatisticsManager = nil, ---@type GameStatisticsManager

    currentHunterId = nil, ---@type string|nil ID do caçador atual
    onPlayerDiedCallback = nil, ---@type function|nil Callback chamado quando o jogador morre
}
PlayerManager.__index = PlayerManager

--- Cria uma nova instância BÁSICA do PlayerManager.
--- A configuração real do jogador acontece em setupGameplay.
--- @return PlayerManager
function PlayerManager:new()
    Logger.info("player_manager.new", "[PlayerManager] Criando nova instância...")
    local instance = setmetatable({}, PlayerManager)

    -- Inicializa propriedades básicas com valores padrão/vazios
    instance.player = nil
    instance.gameTime = 0
    instance.radius = 25
    instance.isLevelingUp = false
    instance.levelUpAnimation = LevelUpAnimation:new()

    -- Inicializa controllers como nil (serão criados em setupGameplay)
    instance.stateController = nil
    instance.healthController = nil
    instance.experienceController = nil
    instance.floatingTextController = nil
    instance.autoAttackController = nil
    instance.weaponController = nil
    instance.runeController = nil
    instance.movementController = nil
    instance.dashController = nil
    instance.levelUpEffectController = nil
    instance.potionController = nil

    -- Carrega recursos do player sprite
    SpritePlayer.load()

    -- Injeta managers vazios inicialmente
    instance.inputManager = nil
    instance.enemyManager = nil
    instance.floatingTextManager = nil
    instance.inventoryManager = nil
    instance.hunterManager = nil
    instance.itemDataManager = nil
    instance.archetypeManager = nil
    instance.gameStatisticsManager = nil

    instance.pendingLevelUps = 0
    instance.onPlayerDiedCallback = nil

    Logger.info("player_manager.new", "[PlayerManager] Instância criada (aguardando setupGameplay).")
    return instance
end

--- Configura o jogador para o gameplay com base nos dados de um caçador específico.
--- Chamado pela GameplayScene após a inicialização dos managers.
--- @param registry ManagerRegistry Instância do registro de managers.
--- @param hunterId string ID do caçador a ser configurado.
function PlayerManager:setupGameplay(registry, hunterId)
    Logger.info(
        "player_manager.setup",
        string.format("[PlayerManager:setupGameplay] Configurando gameplay para hunter ID: %s", hunterId)
    )

    -- Armazena o ID do caçador atual
    self.currentHunterId = hunterId
    self.onPlayerDiedCallback = nil

    -- 1. Obtém os managers necessários do Registry
    self.inputManager = registry:get("inputManager")
    self.enemyManager = registry:get("enemyManager")
    self.floatingTextManager = registry:get("floatingTextManager")
    self.inventoryManager = registry:get("inventoryManager")
    self.hunterManager = registry:get("hunterManager")
    self.itemDataManager = registry:get("itemDataManager")
    self.archetypeManager = registry:get("archetypeManager")
    self.gameStatisticsManager = registry:get("gameStatisticsManager")

    -- Validação crucial das dependências
    if not self.inputManager or not self.enemyManager or not self.floatingTextManager or
        not self.hunterManager or not self.itemDataManager then
        error("ERRO CRÍTICO [PlayerManager:setupGameplay]: Falha ao obter um ou mais managers do Registry!")
    end

    -- 2. Obtém dados do Caçador
    local hunterData = self.hunterManager.hunters and self.hunterManager.hunters[hunterId]
    local equippedItems = self.hunterManager:getEquippedItems(hunterId)
    local hunterStats = self.hunterManager:getHunterFinalStats(hunterId)

    if not hunterData or not equippedItems or not hunterStats or not next(hunterStats) then
        error(string.format("[PlayerManager:setupGameplay]: Falha ao obter dados para hunter ID: %s", hunterId))
    end

    -- Corrige hunterStats para incluir as instâncias completas dos itens equipados
    hunterStats.equippedItems = equippedItems

    -- 3. Inicializa PlayerStateController
    self.stateController = PlayerStateController:new(self, hunterStats)

    if not self.stateController then
        error(string.format("[PlayerManager:setupGameplay]: Falha ao criar PlayerStateController HID: %s", hunterId))
    end

    local finalStats = self.stateController:getCurrentFinalStats()

    self.healthController = HealthController:new(self)
    self.experienceController = ExperienceController:new(self)
    self.floatingTextController = FloatingTextController:new(self)
    self.autoAttackController = AutoAttackController:new(self)
    self.weaponController = WeaponController:new(self)
    self.runeController = RuneController:new(self)
    self.movementController = MovementController:new(self)
    self.dashController = DashController:new(self)
    self.levelUpEffectController = LevelUpEffectController:new(self)
    self.potionController = PotionController:new(self)

    -- 5. Configura o sprite do jogador
    self.movementController:setupPlayerSprite(finalStats)

    -- 6. Configura arma inicial
    self.weaponController:setupInitialWeapon(equippedItems)

    -- 7. Configura runas iniciais
    self.runeController:setupInitialRunes(equippedItems)

    -- 8. Inicializa outros componentes
    LevelUpModal:init(self, self.inputManager)

    Logger.info(
        "player_manager.setup",
        string.format("[PlayerManager:setupGameplay] Configuração do gameplay para hunter '%s' completa.",
            hunterData.name)
    )

    -- Preenche a vida do player com o valor final de health
    local currentFinalStats = self.stateController:getCurrentFinalStats()
    self.stateController:heal(currentFinalStats.maxHealth)
end

-- Atualiza o estado do player e da câmera
function PlayerManager:update(dt)
    if not self:isAlive() then
        return
    end

    self.player = self.movementController.player

    self.gameTime = self.gameTime + dt

    -- Atualiza todos os controllers
    if self.dashController then
        self.dashController:update(dt)
    end

    if self.levelUpEffectController then
        self.levelUpEffectController:update(dt)
    end

    if self.potionController then
        self.potionController:update(dt)
    end

    if self.healthController then
        self.healthController:update(dt)
    end

    if self.floatingTextController then
        self.floatingTextController:update(dt)
    end
    local targetPosition = self:getTargetPosition()
    local angle = math.atan2(targetPosition.y - self.player.position.y, targetPosition.x - self.player.position.x)

    if self.autoAttackController then
        self.autoAttackController:update(angle)
    end

    if self.weaponController then
        self.weaponController:update(dt, angle)
    end

    if self.runeController then
        self.runeController:update(dt)
    end

    if self.movementController then
        self.movementController:update(dt, targetPosition)
    end

    -- Atualiza o input manager
    if self.inputManager then
        self.inputManager:update(dt)
    end
end

-- Desenha o player e elementos relacionados
function PlayerManager:draw()
    if not self.player or not self.player.position then return end
    -- Desenho específico se necessário - a maioria é feita via collectRenderables
end

--- Coleta o jogador e seus componentes visuais principais para renderização.
---@param renderPipeline RenderPipeline RenderPipeline para adicionar os dados de renderização do jogador.
function PlayerManager:collectRenderables(renderPipeline)
    local player = self.movementController.player
    if not player then
        error("Jogador não inicializado para coleta de renderizáveis.")
    end
    local camX, camY, camWidth, camHeight = Camera:getViewPort()

    -- Culling básico no espaço do mundo
    local cullRadius = self.radius or Constants.TILE_WIDTH / 2
    if player.position.x + cullRadius > camX and
        player.position.x - cullRadius < camX + camWidth and
        player.position.y + cullRadius > camY and
        player.position.y - cullRadius < camY + camHeight then
        local playerBaseY = player.position.y + 25

        local worldX_eq = player.position.x / Constants.TILE_WIDTH
        local worldY_eq = playerBaseY / Constants.TILE_HEIGHT

        local isoY_ref_top = (worldX_eq + worldY_eq) * (Constants.TILE_HEIGHT / 2)
        local sortY = isoY_ref_top + Constants.TILE_HEIGHT

        -- Adiciona o rastro do dash
        if self.dashController then
            self.dashController:collectRenderables(renderPipeline, sortY)
        end

        -- Adiciona efeitos de level up
        if self.levelUpEffectController then
            self.levelUpEffectController:collectRenderables(renderPipeline)
        end

        -- Adiciona o jogador principal
        local renderableItem = TablePool.get()
        renderableItem.type = "player"
        renderableItem.sortY = sortY
        renderableItem.depth = RenderPipeline.DEPTH_ENTITIES
        renderableItem.drawFunction = function()
            local playerSprite = self:getPlayerSprite()
            if playerSprite then
                SpritePlayer.draw(playerSprite)
            end
            if self.weaponController then
                self.weaponController:draw()
            end
        end
        renderPipeline:add(renderableItem)

        -- Adiciona habilidades de runa ativas
        if self.runeController then
            self.runeController:collectRenderables(renderPipeline, sortY)
        end
    end
end

-- Funções de gerenciamento de vida
function PlayerManager:isAlive()
    return self.stateController and self.stateController.isAlive
end

---Funções de experiência e level
function PlayerManager:addExperience(amount)
    if self.experienceController then
        self.experienceController:addExperience(amount)
    end
end

--- Tenta mostrar o modal de level up se houver níveis pendentes e o modal não estiver visível.
function PlayerManager:tryShowLevelUpModal()
    if self.experienceController then
        self.experienceController:tryShowLevelUpModal()
    end
end

--- Mostra o modal de level up com callback de fechamento para o sistema de filas.
function PlayerManager:showLevelUpModalWithCallback(onModalClosedCallback)
    if self.experienceController then
        self.experienceController:showLevelUpModalWithCallback(onModalClosedCallback)
    end
end

--- Função para ativar/desativar o auto attack
function PlayerManager:toggleAbilityAutoAttack()
    if self.autoAttackController then
        self.autoAttackController:toggleAutoAttack()
    end
end

--- Função para ativar/desativar o visual do auto attack
function PlayerManager:toggleAttackPreview()
    if self.weaponController then
        self.weaponController:toggleAttackPreview()
    end
end

function PlayerManager:toggleAutoAim()
    if self.autoAttackController then
        self.autoAttackController:toggleAutoAim()
    end
end

--- Função para obter a posição do alvo
function PlayerManager:getTargetPosition()
    if self.autoAttackController then
        return self.autoAttackController:getTargetPosition()
    end
    -- Fallback
    if self.inputManager then
        return self.inputManager:getMouseWorldPosition()
    else
        Logger.error("player_manager.target_position", "InputManager não disponível, usando posição padrão (0,0).")
        return { x = 0, y = 0 }
    end
end

function PlayerManager:leftMouseClicked(x, y)
    -- Lógica movida para os controllers
end

function PlayerManager:leftMouseReleased(x, y)
    -- Lógica movida para os controllers
end

-- Retorna a posição de colisão do player (nos pés do sprite)
function PlayerManager:getCollisionPosition()
    local playerPos = self:getPlayerPosition()
    if not playerPos then
        Logger.warn("player_manager.collision_position", "Player não inicializado, retornando posição padrão.")
        return { position = { x = 0, y = 0 }, radius = self.radius }
    end
    return {
        position = {
            x = playerPos.x,
            y = playerPos.y + 25,
        },
        radius = self.radius
    }
end

--- Retorna a posição do jogador
---@return Vector2D
function PlayerManager:getPlayerPosition()
    if not self.movementController.player or not self.movementController.player.position then
        Logger.warn("player_manager.player_position", "Player não inicializado, retornando posição padrão.")
        return { x = 0, y = 0 }
    end
    return self.movementController.player.position
end

--- Retorna a velocidade atual do jogador
---@return Vector2D
function PlayerManager:getPlayerVelocity()
    return self.movementController:getVelocity()
end

-- Adiciona um item ao inventário do jogador.
---@param itemBaseId string ID do item base
---@param quantity number Quantidade de itens a adicionar
---@return number amount Quantidade de itens adicionados
function PlayerManager:addInventoryItem(itemBaseId, quantity)
    if not self.inventoryManager or not self.itemDataManager then
        Logger.error("player_manager.add_inventory_item", "InventoryManager ou ItemDataManager não inicializado!")
        return 0
    end

    local baseData = self.itemDataManager:getBaseItemData(itemBaseId)
    local itemName = (baseData and baseData.name) or itemBaseId

    local addedQuantity = self.inventoryManager:addItem(itemBaseId, quantity)

    if addedQuantity < quantity then
        local leftover = quantity - addedQuantity
        Logger.warn("player_manager.add_inventory_item",
            string.format("Inventário cheio para %s. %d não foram adicionados.", itemName, leftover))
    else
        Logger.info("player_manager.add_inventory_item",
            string.format("Adicionado %d %s ao inventário.", addedQuantity, itemName))
    end

    return addedQuantity
end

-- Encontra o inimigo mais próximo da posição dada
--- @param position Vector2D Posição de referência
--- @param enemies BaseEnemy[] Lista de inimigos a verificar
--- @return BaseEnemy|nil enemy O inimigo mais próximo, ou nil se a lista estiver vazia
function PlayerManager:findClosestEnemy(position, enemies)
    if self.autoAttackController then
        return self.autoAttackController:findClosestEnemy(position, enemies)
    end
    return nil
end

--- Retorna o sprite do jogador
---@return PlayerSprite
function PlayerManager:getPlayerSprite()
    return self.movementController.player
end

--- Retorna uma tabela contendo os valores finais dos atributos do jogador.
---@return FinalStats
function PlayerManager:getCurrentFinalStats()
    if self.stateController then
        return self.stateController:getCurrentFinalStats()
    end
    error("Error [PlayerManager:getCurrentFinalStats]: PlayerStateController não inicializado.")
end

--- Invalida o cache de stats, forçando recálculo na próxima chamada.
function PlayerManager:invalidateStatsCache()
    if self.stateController then
        self.stateController:invalidateStatsCache()
    end
end

--- Retorna o ID do caçador atualmente configurado para o gameplay.
--- @return string|nil O ID do caçador ou nil se não estiver configurado.
function PlayerManager:getCurrentHunterId()
    return self.currentHunterId
end

--- Define/Limpa a arma ativa e inicializa seu estado
--- Define a arma ativa no PlayerManager e chama seu método :equip.
--- Passar nil para limpar a arma ativa.
---@param weaponInstance table|nil A instância completa do item da arma (dados), ou nil.
function PlayerManager:setActiveWeapon(weaponInstance)
    if self.weaponController then
        self.weaponController:setActiveWeapon(weaponInstance)
    end
end

--- Aplica dano ao jogador
---@param amount number Dano a ser aplicado
---@param source BaseEnemy|nil Fonte do dano
---@return number amount Dano aplicado
function PlayerManager:receiveDamage(amount, source)
    if self.healthController then
        return self.healthController:receiveDamage(amount, source)
    end
    return 0
end

--- Adiciona um texto flutuante ao jogador.
---@param text string Texto a ser exibido.
---@param props table Propriedades do texto flutuante.
function PlayerManager:addFloatingText(text, props)
    if self.floatingTextController then
        self.floatingTextController:addFloatingText(text, props)
    end
end

--- Desenha os textos flutuantes ativos para o jogador.
function PlayerManager:drawFloatingTexts()
    if self.floatingTextController then
        self.floatingTextController:draw()
    end
end

function PlayerManager:onDeath()
    Logger.info("player_manager.death", "Player Morreu!")
    -- TODO: Lógica adicional de morte
end

--- Retorna os itens atualmente equipados pelo jogador durante a gameplay.
function PlayerManager:getCurrentEquipmentGameplay()
    return self.stateController.equippedItems
end

--- Define o callback a ser chamado quando o jogador morrer.
function PlayerManager:setOnPlayerDiedCallback(callback)
    self.onPlayerDiedCallback = callback
end

--- Registra o dano causado pelo jogador.
function PlayerManager:registerDamageDealt(amount, isCritical, source, isSuperCritical)
    if not self.gameStatisticsManager then return end

    local superCritical = isSuperCritical or false
    local weaponId = source and source.weaponId
    local abilityId = source and source.abilityId

    self.gameStatisticsManager:registerDamageDealt(
        amount,
        isCritical,
        superCritical,
        {
            weaponId = weaponId,
            abilityId = abilityId
        }
    )
end

function PlayerManager:setInvincible(isInvincible)
    if self.healthController then
        self.healthController:setInvincible(isInvincible)
    end
end

--- Tenta usar uma poção de cura se disponível
---@return boolean true se uma poção foi usada com sucesso
function PlayerManager:usePotion()
    if self.potionController then
        return self.potionController:usePotion()
    end
    return false
end

--- Registra a eliminação de um inimigo para acelerar o preenchimento das poções
function PlayerManager:onEnemyKilled()
    if self.potionController then
        self.potionController:onEnemyKilled()
    end
end

--- Retorna o status dos frascos de poção
function PlayerManager:getPotionStatus()
    if self.potionController then
        return self.potionController:getFlaskStatus()
    end
    return 0, 0, {}
end

--- Verifica se há pelo menos uma poção pronta para uso
---@return boolean
function PlayerManager:hasReadyPotion()
    if self.potionController then
        return self.potionController:hasReadyPotion()
    end
    return false
end

return PlayerManager
