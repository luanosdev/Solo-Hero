-------------------------------------------------------------------------
-- Controlador para gerenciar experiência e level ups do jogador.
-- Responsável por adicionar XP, calcular level ups e exibir modais.
-------------------------------------------------------------------------

local TablePool = require("src.utils.table_pool")
local LevelUpModal = require("src.ui.level_up_modal")

---@class ExperienceController
---@field playerManager PlayerManager Referência ao PlayerManager
---@field pendingLevelUps number Contador para level ups pendentes
local ExperienceController = {}
ExperienceController.__index = ExperienceController

--- Cria uma nova instância do ExperienceController.
---@param playerManager PlayerManager A instância do PlayerManager
---@return ExperienceController
function ExperienceController:new(playerManager)
    Logger.debug(
        "experience_controller.new",
        "[ExperienceController:new] Inicializando controlador de experiência"
    )

    local instance = setmetatable({}, ExperienceController)

    instance.playerManager = playerManager
    instance.pendingLevelUps = 0

    return instance
end

--- Adiciona experiência ao jogador
---@param amount number Quantidade de experiência a ser adicionada
function ExperienceController:addExperience(amount)
    if not self.playerManager.stateController then return end

    local totalStats = self.playerManager.stateController:getCurrentFinalStats()
    local levelsGained = self.playerManager.stateController:addExperience(amount, totalStats.expBonus)

    -- Registra o XP coletado
    if self.playerManager.gameStatisticsManager then
        self.playerManager.gameStatisticsManager:registerXpCollected(amount)
    end

    if levelsGained > 0 then
        Logger.info(
            "experience_controller.level_gained",
            string.format(
                "[ExperienceController:addExperience] Ganhou %d nível(eis)! Agora nível %d. Próximo nível em %d XP.",
                levelsGained, self.playerManager.stateController.level,
                self.playerManager.stateController.experienceToNextLevel
            )
        )

        self.pendingLevelUps = self.pendingLevelUps + levelsGained
        self.playerManager:invalidateStatsCache()

        -- Registra os níveis ganhos
        if self.playerManager.gameStatisticsManager then
            for i = 1, levelsGained do
                self.playerManager.gameStatisticsManager:registerLevelGained()
            end
        end

        -- Adiciona textos flutuantes de level up
        for i = 1, levelsGained do
            local props = TablePool.get()
            props.color = { 1, 1, 1 }
            props.scale = 1.5
            props.velocityY = -30
            props.lifetime = 1.0
            props.baseOffsetY = -40
            self.playerManager:addFloatingText("LEVEL UP!", props)
            TablePool.release(props)
        end

        -- Dispara o efeito visual de level up com knockback
        if self.playerManager.levelUpEffectController then
            self.playerManager.levelUpEffectController:triggerLevelUpEffect(function(onModalClosedCallback)
                -- Callback chamado quando o efeito terminar - mostra o modal
                self:showLevelUpModalWithCallback(onModalClosedCallback)
            end)
        else
            -- Fallback se o controller não existir
            self:tryShowLevelUpModal()
        end
    end
end

--- Tenta mostrar o modal de level up se houver níveis pendentes
function ExperienceController:tryShowLevelUpModal()
    if self.pendingLevelUps > 0 and LevelUpModal and not LevelUpModal.visible then
        -- Verifica se o efeito de level up está ativo; se estiver, não mostra o modal ainda
        if self.playerManager.levelUpEffectController and self.playerManager.levelUpEffectController:isEffectActive() then
            return -- Aguarda o efeito terminar
        end

        self.pendingLevelUps = self.pendingLevelUps - 1
        LevelUpModal:show()

        Logger.info(
            "experience_controller.modal.show",
            string.format("[ExperienceController:tryShowLevelUpModal] Mostrando Modal de Level Up. Níveis pendentes: %d",
                self.pendingLevelUps)
        )
    end
end

--- Mostra o modal de level up com callback de fechamento
---@param onModalClosedCallback function|nil Callback chamado quando o modal for fechado
function ExperienceController:showLevelUpModalWithCallback(onModalClosedCallback)
    if self.pendingLevelUps > 0 and LevelUpModal and not LevelUpModal.visible then
        self.pendingLevelUps = self.pendingLevelUps - 1
        LevelUpModal:show(onModalClosedCallback)

        Logger.info(
            "experience_controller.modal.show_with_callback",
            string.format("[ExperienceController:showLevelUpModalWithCallback] Modal mostrado. Níveis restantes: %d",
                self.pendingLevelUps)
        )
    else
        -- Se não há níveis pendentes ou modal já está visível, chama o callback imediatamente
        if onModalClosedCallback then
            Logger.debug(
                "experience_controller.modal.skip",
                "[ExperienceController:showLevelUpModalWithCallback] Nenhum modal para mostrar, chamando callback imediatamente"
            )
            onModalClosedCallback()
        end
    end
end

--- Retorna a quantidade de XP necessária para completar um determinado nível
---@param levelNumber number O nível para o qual se deseja saber o XP necessário
---@return number xpToNextLevel A quantidade de XP para completar o nível especificado
function ExperienceController:getExperienceRequiredForLevel(levelNumber)
    if levelNumber == self.playerManager.stateController.level then
        -- Para o nível atual, o PlayerState já tem o valor correto de XP para o próximo nível
        return self.playerManager.stateController.experienceToNextLevel
    else
        -- Para qualquer outro nível, calcula usando a fórmula
        if levelNumber <= 0 then levelNumber = 1 end
        return math.floor(30 * levelNumber ^ 1.5)
    end
end

--- Obtém o número de level ups pendentes
---@return number
function ExperienceController:getPendingLevelUps()
    return self.pendingLevelUps
end

--- Define o número de level ups pendentes (útil para testes ou situações especiais)
---@param count number Número de level ups pendentes
function ExperienceController:setPendingLevelUps(count)
    self.pendingLevelUps = math.max(0, count)
    Logger.debug(
        "experience_controller.pending.set",
        string.format("[ExperienceController:setPendingLevelUps] Level ups pendentes definidos para: %d",
            self.pendingLevelUps)
    )
end

--- Verifica se há level ups pendentes
---@return boolean
function ExperienceController:hasPendingLevelUps()
    return self.pendingLevelUps > 0
end

--- Força a exibição do próximo modal de level up (útil para debug)
function ExperienceController:forceShowNextModal()
    if self.pendingLevelUps > 0 then
        self:tryShowLevelUpModal()
        Logger.debug(
            "experience_controller.force.modal",
            "[ExperienceController:forceShowNextModal] Forçando exibição do modal de level up"
        )
    end
end

return ExperienceController
