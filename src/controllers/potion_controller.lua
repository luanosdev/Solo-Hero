------------------------------------------------------------------------------------------------
-- Controlador do Sistema de Poções
--
-- Gerencia frascos de poção, preenchimento baseado em eliminações de inimigos
-- e tempo decorrido, e uso das poções para recuperar vida.
------------------------------------------------------------------------------------------------

local Constants = require("src.config.constants")
local Colors = require("src.ui.colors")
local TablePool = require("src.utils.table_pool")

---@class PotionFlask
---@field progress number Progresso do frasco (0-1)
---@field isReady boolean Indica se o frasco está pronto para uso

---@class PotionController
---@field playerManager PlayerManager Referência ao PlayerManager
---@field flasks PotionFlask[] Array de frascos
---@field totalFlasks number Número total de frascos disponíveis
---@field currentFillRate number Taxa atual de preenchimento (modificada pelos stats)
local PotionController = {}
PotionController.__index = PotionController

---@param playerManager PlayerManager
---@return PotionController
function PotionController:new(playerManager)
    Logger.debug(
        "potion_controller.new",
        "[PotionController:new] Inicializando controlador de poções"
    )

    local instance = setmetatable({}, PotionController)
    instance.playerManager = playerManager
    instance.flasks = {}
    instance.totalFlasks = 0
    instance.currentFillRate = 1.0

    -- Inicializa os frascos baseado nos stats do jogador
    instance:updateFlaskConfiguration()

    return instance
end

--- Atualiza a configuração dos frascos baseado nos stats atuais do jogador
function PotionController:updateFlaskConfiguration()
    local finalStats = self.playerManager:getCurrentFinalStats()
    local newTotalFlasks = math.max(1, math.floor(finalStats.potionFlasks))
    local newFillRate = math.max(
        Constants.POTION_SYSTEM.MIN_FILL_RATE,
        math.min(Constants.POTION_SYSTEM.MAX_FILL_RATE, finalStats.potionFillRate)
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
            string.format("[PotionController:updateFlaskConfiguration] Adicionados %d frascos (total: %d)",
                newTotalFlasks - self.totalFlasks, newTotalFlasks)
        )
        -- Se diminuiu, remove os frascos extras (começando pelos vazios)
    elseif newTotalFlasks < self.totalFlasks then
        -- Remove primeiro os frascos vazios, depois os parcialmente cheios
        table.sort(self.flasks, function(a, b) return a.progress < b.progress end)
        for i = newTotalFlasks + 1, self.totalFlasks do
            self.flasks[i] = nil
        end
        Logger.debug(
            "potion_controller.flasks.removed",
            string.format("[PotionController:updateFlaskConfiguration] Removidos %d frascos (total: %d)",
                self.totalFlasks - newTotalFlasks, newTotalFlasks)
        )
    end

    self.totalFlasks = newTotalFlasks
    self.currentFillRate = newFillRate
end

--- Atualiza o sistema de poções
---@param dt number Delta time
function PotionController:update(dt)
    -- Atualiza configuração se os stats mudaram
    self:updateFlaskConfiguration()

    -- Preenchimento baseado em tempo
    local timeProgress = Constants.POTION_SYSTEM.TIME_FILL_RATE * self.currentFillRate * dt

    -- Preenche o primeiro frasco que não está pronto (sistema de fila)
    for i = 1, self.totalFlasks do
        if self.flasks[i] and not self.flasks[i].isReady then
            self.flasks[i].progress = self.flasks[i].progress + timeProgress

            if self.flasks[i].progress >= 1.0 then
                self.flasks[i].progress = 1.0
                self.flasks[i].isReady = true
                Logger.info(
                    "potion_controller.flask.ready",
                    string.format("[PotionController:update] Frasco %d está pronto para uso", i)
                )
            end
            break -- Só preenche um frasco por vez (fila)
        end
    end
end

--- Registra a eliminação de um inimigo para acelerar o preenchimento
function PotionController:onEnemyKilled()
    local killProgress = Constants.POTION_SYSTEM.ENEMY_KILL_PROGRESS * self.currentFillRate

    -- Adiciona progresso aos frascos que não estão prontos
    for i = 1, self.totalFlasks do
        if self.flasks[i] and not self.flasks[i].isReady then
            self.flasks[i].progress = self.flasks[i].progress + killProgress

            if self.flasks[i].progress >= 1.0 then
                self.flasks[i].progress = 1.0
                self.flasks[i].isReady = true
                Logger.info(
                    "potion_controller.flask.ready_by_kill",
                    string.format("[PotionController:onEnemyKilled] Frasco %d pronto após eliminação", i)
                )
            end
            break -- Só preenche um frasco por vez
        end
    end
end

--- Tenta usar uma poção
---@return boolean hasUsedPotion true se uma poção foi usada com sucesso
function PotionController:usePotion()
    -- Usa o primeiro frasco pronto na fila
    for i = 1, self.totalFlasks do
        if self.flasks[i] and self.flasks[i].isReady then
            local finalStats = self.playerManager:getCurrentFinalStats()

            -- Aplica a cura
            local actualHealAmount = self.playerManager.stateController:heal(finalStats.potionHealAmount)

            -- Registra estatísticas
            if self.playerManager.gameStatisticsManager then
                self.playerManager.gameStatisticsManager:registerHealthRecovered(actualHealAmount)
            end

            -- Adiciona texto flutuante se houve cura
            if actualHealAmount > 0 then
                local props = TablePool.get()
                props.textColor = Colors.heal
                props.scale = 1.3
                props.velocityY = -40
                props.lifetime = 1.2
                props.baseOffsetY = -50
                props.baseOffsetX = 0
                self.playerManager:addFloatingText("+" .. actualHealAmount .. " HP (Poção)", props)
                TablePool.release(props)
            end

            -- Remove o frasco usado e reorganiza a fila
            table.remove(self.flasks, i)
            -- Adiciona um novo frasco vazio no final
            table.insert(self.flasks, {
                progress = 0.0,
                isReady = false
            })

            Logger.info(
                "potion_controller.use",
                string.format("[PotionController:usePotion] Poção %d usada, curou %d HP", i, actualHealAmount)
            )

            return true
        end
    end

    Logger.debug(
        "potion_controller.use.no_ready",
        "[PotionController:usePotion] Nenhuma poção pronta para uso"
    )
    return false
end

--- Retorna informações sobre o estado dos frascos
---@return number readyFlasks Número de frascos prontos
---@return number totalFlasks Número total de frascos
---@return table flasksInfo Array com informações de cada frasco {progress, isReady}
function PotionController:getFlaskStatus()
    local readyCount = 0
    local flasksInfo = {}

    for i = 1, self.totalFlasks do
        if self.flasks[i] then
            flasksInfo[i] = {
                progress = self.flasks[i].progress,
                isReady = self.flasks[i].isReady
            }
            if self.flasks[i].isReady then
                readyCount = readyCount + 1
            end
        else
            flasksInfo[i] = {
                progress = 0.0,
                isReady = false
            }
        end
    end

    return readyCount, self.totalFlasks, flasksInfo
end

--- Verifica se há pelo menos uma poção pronta para uso
---@return boolean
function PotionController:hasReadyPotion()
    for i = 1, self.totalFlasks do
        if self.flasks[i] and self.flasks[i].isReady then
            return true
        end
    end
    return false
end

return PotionController
