-------------------------------------------------------------------------
-- Controlador para gerenciar habilidades de runas ativas do jogador.
-- Responsável por ativar, desativar e atualizar runas equipadas.
-------------------------------------------------------------------------

local Constants = require("src.config.constants")
local TablePool = require("src.utils.table_pool")
local RenderPipeline = require("src.core.render_pipeline")
local RuneUpgradesData = require("src.data.rune_upgrades_data")

---@class RuneAbilityInstance : BaseRuneInstance
---@field update fun(self, dt: number, enemies: any[], finalStats: any)
---@field draw fun(self)
---@field cast fun(self, x: number, y: number)
---@field applyUpgrade fun(self, upgrade: RuneUpgrade, level: number)
---@field cooldownRemaining number|nil
---@field defaultDepth number

---@class RuneController
---@field playerManager PlayerManager Referência ao PlayerManager
---@field activeRuneAbilities table<ItemSlotId, RuneAbilityInstance> Tabela de habilidades de runas ativas por slot
---@field runeUpgrades table<string, table> Tabela de melhorias por runa (runeId -> upgradeId -> level)
---@field usedRuneUpgrades table<string, number> Tabela de melhorias usadas por ID (upgradeId -> timesUsed)
---@field runeLevels table<string, number> Tabela de níveis atuais por runa (runeId -> currentLevel)
local RuneController = {}
RuneController.__index = RuneController

--- Cria uma nova instância do RuneController.
---@param playerManager PlayerManager A instância do PlayerManager
---@return RuneController
function RuneController:new(playerManager)
    Logger.debug(
        "rune_controller.new",
        "[RuneController:new] Inicializando controlador de runas"
    )

    local instance = setmetatable({}, RuneController)

    instance.playerManager = playerManager
    instance.activeRuneAbilities = {}
    instance.runeUpgrades = {}
    instance.usedRuneUpgrades = {}
    instance.runeLevels = {}

    return instance
end

--- Obtém o nível atual de uma runa específica
---@param runeId string ID da runa
---@return number currentLevel
function RuneController:getRuneLevel(runeId)
    return self.runeLevels[runeId] or 1
end

--- Obtém o nível máximo de uma runa baseado na raridade
---@param runeId string ID da runa
---@return number maxLevel
function RuneController:getRuneMaxLevel(runeId)
    -- Encontra a runa ativa para obter a raridade
    for slotId, abilityInstance in pairs(self.activeRuneAbilities) do
        if abilityInstance and abilityInstance.item and
            abilityInstance.item.itemBaseId == runeId then
            local baseData = self.playerManager.itemDataManager:getBaseItemData(runeId)
            if baseData and baseData.rarity then
                return RuneUpgradesData.GetMaxLevelByRarity(baseData.rarity)
            end
        end
    end

    -- Fallback para rank E se não encontrar
    return RuneUpgradesData.GetMaxLevelByRarity("E")
end

--- Incrementa o nível de uma runa
---@param runeId string ID da runa
function RuneController:incrementRuneLevel(runeId)
    local currentLevel = self:getRuneLevel(runeId)
    local maxLevel = self:getRuneMaxLevel(runeId)

    if currentLevel < maxLevel then
        self.runeLevels[runeId] = currentLevel + 1
        Logger.info(
            "rune_controller.level_up",
            string.format("[RuneController:incrementRuneLevel] Runa %s subiu para nível %d/%d",
                runeId, self.runeLevels[runeId], maxLevel)
        )
    end
end

--- Atualiza todas as habilidades de runas ativas
---@param dt number Delta time
function RuneController:update(dt)
    if not self.playerManager:isAlive() then
        return
    end

    -- Obtém os stats finais uma vez para passar para as habilidades
    local finalStats = self.playerManager:getCurrentFinalStats()

    local playerPosition = self.playerManager:getPlayerPosition()
    -- Atualiza habilidades ativas das runas equipadas
    for slotId, abilityInstance in pairs(self.activeRuneAbilities) do
        if abilityInstance and abilityInstance.update then
            abilityInstance:update(dt, self.playerManager.enemyManager.enemies, finalStats)

            -- Executa a runa automaticamente se o cooldown zerar
            if abilityInstance.cooldownRemaining and abilityInstance.cooldownRemaining <= 0 then
                if abilityInstance.cast and playerPosition then
                    abilityInstance:cast(playerPosition.x, playerPosition.y)
                end
            end
        end
    end
end

--- Inicializa as runas equipadas durante o setup do gameplay
---@param equippedItems table Itens equipados do hunter
function RuneController:setupInitialRunes(equippedItems)
    Logger.debug(
        "rune_controller.setup",
        "[RuneController:setupInitialRunes] Configurando runas iniciais"
    )

    -- Limpa habilidades anteriores
    self:clearAllRunes()

    local finalStats = self.playerManager:getCurrentFinalStats()
    local maxRuneSlots = finalStats.runeSlots or 0

    for i = 1, maxRuneSlots do
        local slotId = Constants.SLOT_IDS.RUNE .. i -- Ex: "rune_1"
        local runeItem = equippedItems[slotId]
        if runeItem then
            self:activateRuneAbility(slotId, runeItem)

            -- Inicializa o nível da runa se não existir
            if not self.runeLevels[runeItem.itemBaseId] then
                self.runeLevels[runeItem.itemBaseId] = 1
            end
        end
    end

    Logger.info(
        "rune_controller.setup.complete",
        string.format("[RuneController:setupInitialRunes] Ativação completa. %d habilidades de runa ativas.",
            self:getActiveRuneCount())
    )
end

--- Ativa a habilidade de uma runa equipada
---@param slotId string O ID do slot onde a runa foi equipada
---@param runeItemInstance table A instância do item da runa
function RuneController:activateRuneAbility(slotId, runeItemInstance)
    if not runeItemInstance or not runeItemInstance.itemBaseId then
        Logger.warn(
            "rune_controller.activate.invalid_data",
            string.format("[RuneController:activateRuneAbility] Dados inválidos para item da runa no slot %s", slotId)
        )
        return
    end

    -- Desativa qualquer habilidade anterior no mesmo slot
    self:deactivateRuneAbility(slotId)

    local runeBaseData = self.playerManager.itemDataManager:getBaseItemData(runeItemInstance.itemBaseId)

    if runeBaseData and runeBaseData.abilityClass then
        Logger.info(
            "rune_controller.activate",
            string.format("[RuneController:activateRuneAbility] Ativando runa '%s' no slot %s. Classe: %s",
                runeItemInstance.itemBaseId, slotId, runeBaseData.abilityClass)
        )

        local success, AbilityClass = pcall(require, runeBaseData.abilityClass)
        if success and AbilityClass and AbilityClass.new then
            local abilityInstance = AbilityClass:new(self.playerManager, runeItemInstance)
            if abilityInstance then
                self.activeRuneAbilities[slotId] = abilityInstance

                -- Inicializa o nível da runa se não existir
                if not self.runeLevels[runeItemInstance.itemBaseId] then
                    self.runeLevels[runeItemInstance.itemBaseId] = 1
                end

                Logger.info(
                    "rune_controller.activate.success",
                    string.format("[RuneController:activateRuneAbility] Habilidade da runa '%s' ativada para o slot %s.",
                        runeItemInstance.itemBaseId, slotId)
                )
            else
                Logger.error(
                    "rune_controller.activate.instance_failed",
                    string.format(
                        "[RuneController:activateRuneAbility] Falha ao criar instância de habilidade para runa '%s'",
                        runeItemInstance.itemBaseId)
                )
            end
        else
            Logger.error(
                "rune_controller.activate.class_failed",
                string.format(
                    "[RuneController:activateRuneAbility] Não foi possível carregar/instanciar classe '%s' para runa '%s'. Erro: %s",
                    runeBaseData.abilityClass, runeItemInstance.itemBaseId,
                    success and "Classe ou :new ausente" or tostring(AbilityClass))
            )
        end
    else
        Logger.warn(
            "rune_controller.activate.no_ability",
            string.format(
                "[RuneController:activateRuneAbility] Runa '%s' no slot %s não possui 'abilityClass' ou dados base.",
                runeItemInstance.itemBaseId or "ID Desconhecido", slotId)
        )
    end
end

--- Desativa a habilidade de uma runa desequipada
---@param slotId string O ID do slot da runa a ser desativada
function RuneController:deactivateRuneAbility(slotId)
    if self.activeRuneAbilities[slotId] then
        local abilityInstance = self.activeRuneAbilities[slotId]
        local runeName = (abilityInstance.item and abilityInstance.item.name) or slotId

        Logger.info(
            "rune_controller.deactivate",
            string.format("[RuneController:deactivateRuneAbility] Desativando habilidade da runa no slot %s (%s).",
                slotId, runeName)
        )

        -- Se a instância da habilidade tiver um método de limpeza, chama-o
        if abilityInstance.destroy then
            abilityInstance:destroy()
        elseif abilityInstance.onUnequip then
            abilityInstance:onUnequip()
        elseif abilityInstance.cleanup then
            abilityInstance:cleanup()
        end

        self.activeRuneAbilities[slotId] = nil
        Logger.debug(
            "rune_controller.deactivate.success",
            string.format("[RuneController:deactivateRuneAbility] Habilidade do slot %s removida.", slotId)
        )
    end
end

--- Remove todas as runas ativas
function RuneController:clearAllRunes()
    Logger.debug(
        "rune_controller.clear_all",
        string.format("[RuneController:clearAllRunes] Limpando %d habilidades de runa ativas",
            self:getActiveRuneCount())
    )

    for slotId in pairs(self.activeRuneAbilities) do
        self:deactivateRuneAbility(slotId)
    end

    self.activeRuneAbilities = {}
end

--- Coleta renderáveis das runas para o pipeline de renderização
---@param renderPipeline RenderPipeline Pipeline de renderização
---@param sortY number Y base para ordenação
function RuneController:collectRenderables(renderPipeline, sortY)
    for slotId, abilityInstance in pairs(self.activeRuneAbilities) do
        if abilityInstance and abilityInstance.draw then
            local renderableItem = TablePool.get()
            renderableItem.type = "rune_ability"
            renderableItem.sortY = sortY
            renderableItem.depth = abilityInstance.defaultDepth or RenderPipeline.DEPTH_ENTITIES
            renderableItem.drawFunction = function()
                abilityInstance:draw()
            end
            renderPipeline:add(renderableItem)
        end
    end
end

--- Força a execução de uma runa específica (útil para debug/comandos)
---@param slotId string ID do slot da runa
---@return boolean success True se a runa foi executada com sucesso
function RuneController:forceExecuteRune(slotId)
    local abilityInstance = self.activeRuneAbilities[slotId]
    local playerPosition = self.playerManager:getPlayerPosition()
    if abilityInstance and abilityInstance.cast and playerPosition then
        abilityInstance:cast(playerPosition.x, playerPosition.y)
        Logger.debug(
            "rune_controller.force_execute",
            string.format("[RuneController:forceExecuteRune] Runa no slot %s executada forçadamente", slotId)
        )
        return true
    end
    return false
end

--- Obtém o número de runas ativas
---@return number
function RuneController:getActiveRuneCount()
    local count = 0
    for _ in pairs(self.activeRuneAbilities) do
        count = count + 1
    end
    return count
end

--- Verifica se uma runa está ativa em um slot específico
---@param slotId string ID do slot
---@return boolean
function RuneController:isRuneActiveInSlot(slotId)
    return self.activeRuneAbilities[slotId] ~= nil
end

--- Obtém informações sobre todas as runas ativas
---@return table
function RuneController:getActiveRunesInfo()
    local info = {}
    for slotId, abilityInstance in pairs(self.activeRuneAbilities) do
        info[slotId] = {
            hasAbility = true,
            cooldownRemaining = abilityInstance.cooldownRemaining or 0,
            isReady = (abilityInstance.cooldownRemaining or 0) <= 0,
            abilityType = type(abilityInstance)
        }

        -- Adiciona informações do item se disponível
        if abilityInstance.item then
            info[slotId].runeItemData = abilityInstance.item
        end
    end
    return info
end

--- Obtém informações de debug sobre o controlador
---@return table
function RuneController:getDebugInfo()
    local slotCount = {}
    local totalCooldowns = 0
    local readyAbilities = 0

    for slotId, abilityInstance in pairs(self.activeRuneAbilities) do
        slotCount[slotId] = true
        if abilityInstance.cooldownRemaining then
            totalCooldowns = totalCooldowns + abilityInstance.cooldownRemaining
            if abilityInstance.cooldownRemaining <= 0 then
                readyAbilities = readyAbilities + 1
            end
        end
    end

    return {
        activeCount = self:getActiveRuneCount(),
        slotsUsed = slotCount,
        totalCooldowns = totalCooldowns,
        readyAbilities = readyAbilities
    }
end

--- Atualiza uma runa específica quando o equipamento muda
---@param slotId string ID do slot
---@param newRuneItem table|nil Nova runa (nil para remover)
function RuneController:updateRuneInSlot(slotId, newRuneItem)
    Logger.debug(
        "rune_controller.update_slot",
        string.format("[RuneController:updateRuneInSlot] Atualizando slot %s", slotId)
    )

    -- Remove a runa atual se existir
    self:deactivateRuneAbility(slotId)

    -- Adiciona a nova runa se fornecida
    if newRuneItem then
        self:activateRuneAbility(slotId, newRuneItem)
    end
end

--- Obtém as melhorias de runas disponíveis para runas equipadas
---@return RuneUpgrade[]
function RuneController:getAvailableRuneUpgrades()
    Logger.info("rune_controller.debug.start",
        "[RuneController:getAvailableRuneUpgrades] Iniciando busca por melhorias de runa...")
    local availableUpgrades = {}

    local activeCount = self:getActiveRuneCount()
    Logger.info("rune_controller.debug.count",
        string.format("[RuneController:getAvailableRuneUpgrades] Encontradas %d runas ativas.", activeCount))

    -- Verifica todas as runas equipadas
    for slotId, abilityInstance in pairs(self.activeRuneAbilities) do
        if abilityInstance and abilityInstance.item and abilityInstance.item.itemBaseId then
            local fullRuneId = abilityInstance.item.itemBaseId

            -- Pega os dados base do item para garantir que temos o runeFamilyId
            local runeBaseData = self.playerManager.itemDataManager:getBaseItemData(fullRuneId)

            if not runeBaseData or not runeBaseData.runeFamilyId then
                Logger.warn("rune_controller.debug.invalid_rune_data",
                    string.format(
                        "[RuneController:getAvailableRuneUpgrades] Runa %s não tem runeFamilyId em seus dados base.",
                        fullRuneId))
                goto continue
            end

            local runeFamilyId = runeBaseData.runeFamilyId
            local runeLevel = self:getRuneLevel(runeFamilyId)
            local maxLevel = self:getRuneMaxLevel(fullRuneId) -- Max level ainda depende da raridade do item

            Logger.info("rune_controller.debug.rune_info",
                string.format(
                "[RuneController:getAvailableRuneUpgrades] Verificando Runa: %s (Família: %s) | Nível: %d/%d",
                    fullRuneId, runeFamilyId, runeLevel, maxLevel))

            -- A lógica de filtragem (incluindo nível máximo e ultras) agora é tratada pelo RuneUpgradesData
            local upgradesForRune = RuneUpgradesData.GetAvailableUpgrades(runeFamilyId, runeLevel, self.usedRuneUpgrades)
            Logger.info("rune_controller.debug.upgrades_found",
                string.format("[RuneController:getAvailableRuneUpgrades] Encontradas %d melhorias para %s.",
                    #upgradesForRune, runeFamilyId))

            for _, upgrade in ipairs(upgradesForRune) do
                -- Adiciona informações de nível para o modal
                upgrade.current_level_for_display = runeLevel
                upgrade.max_level = maxLevel
                -- Garante que a melhoria está associada ao ID da família correto
                upgrade.rune_id = runeFamilyId
                table.insert(availableUpgrades, upgrade)
            end
        else
            Logger.warn("rune_controller.debug.invalid_rune",
                string.format(
                    "[RuneController:getAvailableRuneUpgrades] Runa no slot %s é inválida ou não possui itemBaseId.",
                    slotId))
        end
        ::continue::
    end

    Logger.info("rune_controller.debug.finish",
        string.format("[RuneController:getAvailableRuneUpgrades] Retornando %d melhorias disponíveis.",
            #availableUpgrades))
    return availableUpgrades
end

--- Obtém as melhorias de runas já utilizadas
---@return table<string, number>
function RuneController:getUsedRuneUpgrades()
    return self.usedRuneUpgrades
end

--- Retorna as melhorias de uma runa específica
---@param runeId string ID da runa
---@return table<string, number>
function RuneController:getRuneUpgrades(runeId)
    return self.runeUpgrades[runeId]
end

--- Aplica uma melhoria de runa
---@param upgradeId string ID da melhoria
---@return boolean success
function RuneController:applyRuneUpgrade(upgradeId)
    local upgrade = RuneUpgradesData.Upgrades[upgradeId]
    if not upgrade then
        Logger.error(
            "rune_controller.apply_upgrade.not_found",
            string.format("[RuneController:applyRuneUpgrade] Melhoria '%s' não encontrada", upgradeId)
        )
        return false
    end

    local runeFamilyId = upgrade.rune_id
    -- Encontra a instância da runa correspondente
    local runeInstance = nil
    for slotId, abilityInstance in pairs(self.activeRuneAbilities) do
        if abilityInstance and abilityInstance.item and abilityInstance.item.itemBaseId then
            local runeBaseData = self.playerManager.itemDataManager:getBaseItemData(abilityInstance.item.itemBaseId)
            if runeBaseData and runeBaseData.runeFamilyId == runeFamilyId then
                runeInstance = abilityInstance
                break
            end
        end
    end

    if not runeInstance then
        Logger.error(
            "rune_controller.apply_upgrade.rune_not_found",
            string.format("[RuneController:applyRuneUpgrade] Runa da família '%s' não encontrada entre as runas ativas.",
                runeFamilyId)
        )
        return false
    end

    -- Aplica a melhoria
    RuneUpgradesData.ApplyRuneUpgrade(runeInstance, upgradeId)

    -- Atualiza o contador de uso
    self.usedRuneUpgrades[upgradeId] = (self.usedRuneUpgrades[upgradeId] or 0) + 1

    -- Registra o upgrade para a runa
    if not self.runeUpgrades[runeFamilyId] then
        self.runeUpgrades[runeFamilyId] = {}
    end
    self.runeUpgrades[runeFamilyId][upgradeId] = (self.runeUpgrades[runeFamilyId][upgradeId] or 0) + 1

    -- Incrementa o nível da runa
    self:incrementRuneLevel(runeFamilyId)

    Logger.info(
        "rune_controller.apply_upgrade.success",
        string.format("[RuneController:applyRuneUpgrade] Melhoria '%s' aplicada à runa '%s'. Nível atual: %d/%d",
            upgrade.name, runeFamilyId, self:getRuneLevel(runeFamilyId),
            self:getRuneMaxLevel(runeInstance.item.itemBaseId))
    )

    return true
end

return RuneController
