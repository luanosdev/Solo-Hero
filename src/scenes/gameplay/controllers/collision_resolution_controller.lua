local Constants = require("src.config.constants")
local BaseController = require("src.controllers.base_controller")

---@class CollisionResolutionController
---@description Gerencia as consequências de uma colisão entre o jogador e um inimigo.
---@description Este controller é responsável por aplicar cooldowns de dano, calcular a
---@description mitigação de dano com base nas estatísticas do jogador e disparar
---@description eventos quando o dano é efetivamente sofrido.
---@field context GameplayControllerContext Contexto com serviços essenciais.
---@field enemyCollisionCooldowns table<number, number> Tabela que armazena o tempo do último hit para cada inimigo (ID).
---@field damageCooldown number O tempo mínimo em segundos entre hits do mesmo inimigo.
local CollisionResolutionController = {}
CollisionResolutionController.__index = CollisionResolutionController

---@public Cria uma nova instância do CollisionResolutionController.
---@param context GameplayControllerContext Um contexto contendo os serviços necessários (eventService, gameTimerService).
---@return CollisionResolutionController
function CollisionResolutionController:new(context)
    assert(context, "[CollisionResolutionController:new] Context is required.")
    assert(context.services.eventService, "[CollisionResolutionController:new] EventService is required in context.")
    assert(context.services.gameTimerService,
        "[CollisionResolutionController:new] GameTimerService is required in context.")

    local instance = BaseController.new(self, context)

    instance.enemyCollisionCooldowns = {}
    -- Define um cooldown padrão para dano de colisão, para evitar dano em todos os frames.
    instance.damageCooldown = Constants.GAMEPLAY_CONFIG.PLAYER_DAMAGE_COOLDOWN_SECONDS

    return instance
end

---@public Inicializa o controller.
function CollisionResolutionController:init()
    -- Nenhuma inicialização complexa necessária por enquanto.
    Logger.info("CollisionResolutionController:init", "[CollisionResolutionController] Initialized.")
end

---@public Processa uma colisão com um inimigo, decide se o dano deve ser aplicado e,
---@description em caso afirmativo, calcula o dano final e dispara um evento.
---@param enemy BaseEnemy O inimigo que colidiu com o jogador.
---@param playerStats table<StatKey, number> Estatísticas atuais do jogador para cálculo de mitigação.
function CollisionResolutionController:processCollision(enemy, playerStats)
    local gameTime = self.context.services.gameTimerService:getTime()
    local lastHitTime = self.enemyCollisionCooldowns[enemy.id]

    -- 1. Verifica o cooldown de dano para este inimigo específico.
    if lastHitTime and (gameTime - lastHitTime < self.damageCooldown) then
        -- Cooldown ativo, ignora o dano para evitar dano contínuo.
        return
    end

    -- Cooldown expirado ou primeiro hit, registra o tempo do hit atual.
    self.enemyCollisionCooldowns[enemy.id] = gameTime

    local K = Constants.GAMEPLAY_CONFIG.DEFENSE_DAMAGE_REDUCTION_K
    local damageReduction = playerStats.defense / (playerStats.defense + K)

    damageReduction = math.min(Constants.GAMEPLAY_CONFIG.MAX_DAMAGE_REDUCTION, damageReduction)
    local finalDamage = math.max(1, math.floor(enemy.damage * (1 - damageReduction)))

    -- Dispara o evento de CAUSA
    self.context.services.eventService:emit(
        self.context.services.eventService.EVENTS.PLAYER_TOOK_DAMAGE,
        {
            finalDamage = finalDamage,
            sourceEnemy = enemy
        }
    )

    Logger.debug(
        "CollisionResolutionController.damage",
        string.format(
            "[CollisionResolutionController] Player took %.2f final damage from enemy %d (incoming: %.2f, defense: %.2f)",
            finalDamage, enemy.id, enemy.damage, playerStats.defense)
    )
end

---@public Update do controller.
function CollisionResolutionController:update()
    self:_clearStaleCooldowns()
end

---@private Limpa a tabela de cooldowns para evitar crescimento indefinido
function CollisionResolutionController:_clearStaleCooldowns()
    local gameTime = self.context.services.gameTimerService:getTime()
    for enemyId, lastHitTime in pairs(self.enemyCollisionCooldowns) do
        if gameTime - lastHitTime > self.damageCooldown then
            self.enemyCollisionCooldowns[enemyId] = nil
        end
    end
end

--- Limpa os recursos do controller.
function CollisionResolutionController:destroy()
    BaseController.destroy(self)

    self.enemyCollisionCooldowns = {}
    Logger.info("CollisionResolutionController:destroy", "[CollisionResolutionController] Destroyed.")
end

return CollisionResolutionController
