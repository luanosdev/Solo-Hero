local BaseController = require("src.controllers.base_controller")
local LevelUpBonusesData = require("src.data.level_up_bonuses_data")

---@class LevelUpBonusController : BaseController
---@description Controller especializado na lógica de geração de opções de bônus
---@description para o level up do jogador.
---@field learnedBonuses table<string, number> Tabela de bônus genéricos aprendidos e seus níveis.
local LevelUpBonusController = setmetatable({}, { __index = BaseController })
LevelUpBonusController.__index = LevelUpBonusController

---@public Cria uma nova instância do LevelUpBonusController.
---@param context GameplayControllerContext
---@return LevelUpBonusController
function LevelUpBonusController:new(context)
    local instance = BaseController:new(context)
    setmetatable(instance, LevelUpBonusController)

    ---@type table<string, number>
    instance.learnedBonuses = {}

    return instance
end

---@class ContextualBonusContext
---@field availableWeaponTraits table[]|nil Lista de traits de arma disponíveis.
---@field learnedWeaponTraits table<string, number>|nil Tabela de traits de arma já aprendidos.
---@field availableRuneUpgrades table[]|nil Lista de upgrades de runa disponíveis.
---@field learnedRuneUpgrades table<string, number>|nil Tabela de upgrades de runa já aprendidos.

---@public Gera um conjunto de opções de bônus para o jogador escolher.
---@description Combina bônus genéricos (gerenciados internamente) com bônus contextuais (de armas, runas) recebidos por parâmetro.
---@param contextualBonusContext ContextualBonusContext|nil Os dados contextuais para gerar as opções.
---@return LevelUpBonus[]
function LevelUpBonusController:generateOptions(contextualBonusContext)
    contextualBonusContext = contextualBonusContext or {}

    local generatedOptions = {}
    local availableBonuses = {}
    local availableUltimates = {}
    local collectedWeaponTraits = {}
    local collectedRuneUpgrades = {}

    local learned = self.learnedBonuses

    -- Coleta traits de arma disponíveis (contextual)
    if contextualBonusContext.availableWeaponTraits and contextualBonusContext.learnedWeaponTraits then
        for _, trait in ipairs(contextualBonusContext.availableWeaponTraits) do
            local currentLevel = contextualBonusContext.learnedWeaponTraits[trait.id] or 0

            local optionData = {}
            for k, v in pairs(trait) do optionData[k] = v end
            optionData.current_level_for_display = currentLevel
            optionData.is_weapon_trait = true

            if trait.is_ultimate then
                table.insert(availableUltimates, optionData)
            else
                table.insert(collectedWeaponTraits, optionData)
            end
        end
    end

    -- Coleta melhorias de runas disponíveis (contextual)
    if contextualBonusContext.availableRuneUpgrades then
        for _, upgrade in ipairs(contextualBonusContext.availableRuneUpgrades) do
            local optionData = {}
            for k, v in pairs(upgrade) do optionData[k] = v end
            optionData.is_rune_upgrade = true

            if upgrade.is_ultra then
                table.insert(availableUltimates, optionData)
            else
                table.insert(collectedRuneUpgrades, optionData)
            end
        end
    end

    -- Coleta melhorias normais disponíveis
    for bonusId, bonusData in pairs(LevelUpBonusesData.Bonuses) do
        if not bonusData.is_ultimate then
            local currentLevel = learned[bonusId] or 0
            if currentLevel < bonusData.max_level then
                local optionData = {}
                for k, v in pairs(bonusData) do optionData[k] = v end
                optionData.current_level_for_display = currentLevel
                optionData.is_weapon_trait = false
                table.insert(availableBonuses, optionData)
            end
        end
    end

    -- Verifica se há melhorias ultimate disponíveis
    for bonusId, bonusData in pairs(LevelUpBonusesData.Bonuses) do
        if bonusData.is_ultimate then
            local currentLevel = learned[bonusId] or 0
            if currentLevel < bonusData.max_level then
                local hasMaxedBaseBonuses = false
                if bonusData.base_bonuses and #bonusData.base_bonuses == 1 then
                    local baseBonusId = bonusData.base_bonuses[1]
                    local baseBonusData = LevelUpBonusesData.Bonuses[baseBonusId]
                    if baseBonusData then
                        local baseBonusLevel = learned[baseBonusId] or 0
                        if baseBonusLevel >= baseBonusData.max_level then
                            hasMaxedBaseBonuses = true
                        end
                    end
                end

                if hasMaxedBaseBonuses then
                    local optionData = {}
                    for k, v in pairs(bonusData) do optionData[k] = v end
                    optionData.current_level_for_display = currentLevel
                    table.insert(availableUltimates, optionData)
                end
            end
        end
    end

    local numUltimateSlots = 0
    if #availableUltimates > 0 then
        numUltimateSlots = 1
        local randomUltimateIndex = love.math.random(1, #availableUltimates)
        table.insert(generatedOptions, availableUltimates[randomUltimateIndex])
    end

    local allAvailableOptions = {}
    for _, weaponTrait in ipairs(collectedWeaponTraits) do table.insert(allAvailableOptions, weaponTrait) end
    for _, bonus in ipairs(availableBonuses) do table.insert(allAvailableOptions, bonus) end
    for _, runeUpgrade in ipairs(collectedRuneUpgrades) do table.insert(allAvailableOptions, runeUpgrade) end

    local remainingSlots = 4 - numUltimateSlots
    for i = 1, remainingSlots do
        if #allAvailableOptions > 0 then
            local randomIndex = love.math.random(1, #allAvailableOptions)
            table.insert(generatedOptions, allAvailableOptions[randomIndex])
            table.remove(allAvailableOptions, randomIndex)
        else
            break
        end
    end

    if #generatedOptions == 0 then
        Logger.warn("LevelUpBonusController:generateOptions", "Nenhuma opção de bônus disponível para gerar.")
    end

    return generatedOptions
end

---@public Aplica um bônus de level up escolhido.
---@description Atualiza o estado interno de bônus aprendidos. Futuramente, irá
---@description disparar um evento para notificar o PlayerStateController.
---@param chosenBonus LevelUpBonusOption O bônus que foi escolhido pelo jogador.
function LevelUpBonusController:applyLevelUpBonus(chosenBonus)
    assert(chosenBonus, "[LevelUpBonusController:applyLevelUpBonus] chosenBonus is required.")
    assert(chosenBonus.id, "[LevelUpBonusController:applyLevelUpBonus] chosenBonus.id is required.")

    -- Por enquanto, esta função só se aplica a bônus genéricos.
    -- A lógica para traits de arma e runas será diferente.
    if chosenBonus.is_weapon_trait or chosenBonus.is_rune_upgrade then
        Logger.warn("LevelUpBonusController:applyLevelUpBonus",
            "A aplicação de traits de arma e runas ainda não foi implementada.")
        return
    end

    local bonusId = chosenBonus.id
    local currentLevel = self.learnedBonuses[bonusId] or 0
    self.learnedBonuses[bonusId] = currentLevel + 1

    Logger.info("LevelUpBonusController:applyLevelUpBonus",
        string.format("Bônus '%s' aplicado. Novo nível: %d", bonusId, self.learnedBonuses[bonusId]))

    -- TODO: Próximo passo é converter todos os bônus aprendidos em StatModifiers
    -- e disparar o evento "LEVEL_UP_BONUSES_UPDATED".
end

function LevelUpBonusController:destroy()
    self.learnedBonuses = {}
    Logger.info("level_up_bonus_controller.destroy", "[LevelUpBonusController] Destroyed.")
end

return LevelUpBonusController
