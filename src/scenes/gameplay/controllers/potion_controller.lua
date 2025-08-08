local BaseController = require("src.controllers.base_controller")
local Constants = require("src.config.constants")

---@class PotionFlask
---@field progress number Progresso do frasco (0-1)
---@field isReady boolean Indica se o frasco está pronto para uso

---@class PotionController : BaseController
---@field flasks PotionFlask[] Array de frascos
---@field totalFlasks number Número total de frascos
local PotionController = setmetatable({}, { __index = BaseController })
PotionController.__index = PotionController

---@public Cria uma nova instância do PotionController.
---@param context GameplayControllerContext
---@return PotionController
function PotionController:new(context)
    assert(context, "[PotionController:new] 'context' dependency is missing.")
    ---@type PotionController
    local instance = BaseController.new(self, context)

    return instance
end

---@public Inicializa o controller.
---@param initialTotalFlasks number Número total de frascos
---@param initialFillRate number Taxa de preenchimento
function PotionController:init(initialTotalFlasks, initialFillRate)
    assert(initialTotalFlasks, "[PotionController:init] 'initialTotalFlasks' is required.")
    assert(initialFillRate, "[PotionController:init] 'initialFillRate' is required.")

    self.flasks = {}
    self.totalFlasks = initialTotalFlasks
    for i = 1, self.totalFlasks do
        self.flasks[i] = {
            progress = 0.0,
            isReady = false
        }
    end

    self.currentFillRate = initialFillRate

    self:_startEventListeners()

    Logger.debug(
        "potion_controller.init",
        "[PotionController:init] Inicializando controlador de poções"
    )
end

---@public Atualiza o controller.
---@param dt number Delta time
function PotionController:update(dt)
    self:_updateFlaskProgressByTimer(dt)
end

---@private Atualiza a configuração dos frascos baseado nos stats atuais do jogador
---@param totalFlasks number Número total de frascos
---@param fillRate number Taxa de preenchimento
function PotionController:_updateFlaskConfiguration(totalFlasks, fillRate)
    local newTotalFlasks = math.max(1, math.floor(totalFlasks))
    local newFillRate = math.max(
        Constants.POTION_SYSTEM.MIN_FILL_RATE,
        math.min(Constants.POTION_SYSTEM.MAX_FILL_RATE, fillRate)
    )

    -- Se o número de frascos aumentou, adiciona novos frascos vazios
    if newTotalFlasks > self.totalFlasks then
        for i = self.totalFlasks + 1, newTotalFlasks do
            self.flasks[i] = {
                progress = 0.0,
                isReady = false
            }
        end

        Logger.debug(
            "potion_controller.flasks.added",
            string.format("[PotionController:_updateFlaskConfiguration] Adicionados %d frascos (total: %d)",
                newTotalFlasks - self.totalFlasks, newTotalFlasks)
        )
    elseif newTotalFlasks < self.totalFlasks then
        -- Remove primeiro os frascos vazios, depois os parcialmente cheios
        table.sort(self.flasks, function(a, b) return a.progress < b.progress end)
        for i = newTotalFlasks + 1, self.totalFlasks do
            self.flasks[i] = nil
        end

        Logger.debug(
            "potion_controller.flasks.removed",
            string.format("[PotionController:_updateFlaskConfiguration] Removidos %d frascos (total: %d)",
                self.totalFlasks - newTotalFlasks, newTotalFlasks)
        )
    end

    self.totalFlasks = newTotalFlasks
    self.currentFillRate = newFillRate
    self:_emitStateUpdate()
end

---@private Atuliza o preenchimento dos frascos com base no tempo decorrido
---@param dt number Delta time
function PotionController:_updateFlaskProgressByTimer(dt)
    local timeProgress = Constants.POTION_SYSTEM.TIME_FILL_RATE * self.currentFillRate * dt
    self:_updateFlaskProgress(timeProgress)
end

---@private Atualiza o preenchimento dos frascos com base na eliminação de inimigos
---@description com base no evento de eliminação de inimigos
---@param data EnemyKilledEventData
function PotionController:_onEnemyKilled(data)
    assert(data, "[PotionController:_updateFlaskProgressByKill] 'data' is required.")
    assert(data.enemy, "[PotionController:_updateFlaskProgressByKill] 'data.enemy' is required.")

    local enemyBonus = 1
    if data.enemy:getEnemyType() == "boss" then
        enemyBonus = Constants.POTION_SYSTEM.BOSS_KILL_BONUS
    elseif data.enemy:getEnemyType() == "mvp" then
        enemyBonus = Constants.POTION_SYSTEM.MVP_KILL_BONUS
    else
        enemyBonus = Constants.POTION_SYSTEM.NORMAL_KILL_BONUS
    end

    local killProgress = Constants.POTION_SYSTEM.ENEMY_KILL_PROGRESS * self.currentFillRate * enemyBonus
    self:_updateFlaskProgress(killProgress)
end

---@private Atualiza o preenchimento dos frascos
---@description Atualiza o progresso dos frascos e emite um evento se um deles ficar pronto.
---@param progress number Progresso a ser adicionado
function PotionController:_updateFlaskProgress(progress)
    local anyFlaskBecameReady = false
    for i = 1, self.totalFlasks do
        if self.flasks[i] and not self.flasks[i].isReady then
            self.flasks[i].progress = self.flasks[i].progress + progress

            if self.flasks[i].progress >= 1.0 then
                self.flasks[i].progress = 1.0
                if not self.flasks[i].isReady then
                    anyFlaskBecameReady = true
                end
                self.flasks[i].isReady = true
            end

            break
        end
    end

    if anyFlaskBecameReady then
        self:_emitStateUpdate()
    end
end

---@private Emite o evento de atualização de estado dos frascos.
function PotionController:_emitStateUpdate()
    self.context.services.eventService:emit(
        self.context.services.eventService.EVENTS.POTION_STATE_UPDATED,
        {
            flasks = self.flasks,
            totalFlasks = self.totalFlasks
        }
    )
    Logger.debug(
        "potion_controller.state_updated",
        "[EVENT] [PotionController:_emitStateUpdate] Emitindo evento de atualização de estado dos frascos"
    )
end

---@private Emite o evento de uso de poção.
function PotionController:_emitPotionUsed()
    self.context.services.eventService:emit(self.context.services.eventService.EVENTS.POTION_USED)
    Logger.debug(
        "potion_controller.used",
        "[EVENT] [PotionController:_emitPotionUsed] Emitindo evento de uso de poção"
    )
end

---@public Tenta consumir o último frasco de poção pronto e emite uma atualização.
---@return boolean hasUsedPotion true se uma poção foi usada com sucesso
function PotionController:tryUsePotion()
    local consumed = false
    -- Itera de trás para frente para encontrar o último frasco pronto
    for i = self.totalFlasks, 1, -1 do
        if self.flasks[i] and self.flasks[i].isReady then
            self.flasks[i].progress = 0.0
            self.flasks[i].isReady = false
            consumed = true
            break -- Consome apenas um frasco
        end
    end

    if consumed then
        self:_emitStateUpdate()
        self:_emitPotionUsed()
    end

    return consumed
end

---@private Usa a poção
---@param data PlayerStatUpdatedEventData
function PotionController:_onPlayerStatUpdated(data)
    assert(data, "[PotionController:_onPlayerStatUpdated] 'data' is required.")
    assert(data.stat, "[PotionController:_onPlayerStatUpdated] 'data.stat' is required.")
    assert(data.newValue, "[PotionController:_onPlayerStatUpdated] 'data.newValue' is required.")

    if data.stat == "potionFlasks" then
        self:_updateFlaskConfiguration(data.newValue, self.currentFillRate)
    elseif data.stat == "potionFillRate" then
        self:_updateFlaskConfiguration(self.totalFlasks, data.newValue)
    end
end

---@private Inicia as instancias de eventos
function PotionController:_startEventListeners()
    self:_listen(self.context.services.eventService.EVENTS.ENEMY_KILLED, self._onEnemyKilled)
    self:_listen(self.context.services.eventService.EVENTS.PLAYER_STAT_UPDATED, self._onPlayerStatUpdated)
end

return PotionController
