-------------------------------------------------------------------------
-- Controlador para gerenciar weapon traits aprendidos do jogador.
-- Sistema similar ao Halls of Torment onde cada tipo de ataque tem
-- 2 caminhos, cada um com 2 variações, 5 níveis + 1 ultimate.
-------------------------------------------------------------------------

local WeaponTraitsData = require("src.data.weapon_traits_data")

---@class WeaponTraitsController
---@field playerManager PlayerManager Referência ao PlayerManager
---@field learnedWeaponTraits table<string, number> Weapon traits aprendidos (ID -> nível)
local WeaponTraitsController = {}
WeaponTraitsController.__index = WeaponTraitsController

--- Cria uma nova instância do WeaponTraitsController.
---@param playerManager PlayerManager A instância do PlayerManager
---@return WeaponTraitsController
function WeaponTraitsController:new(playerManager)
    Logger.debug(
        "weapon_traits_controller.new",
        "[WeaponTraitsController:new] Inicializando controlador de weapon traits"
    )

    local instance = setmetatable({}, WeaponTraitsController)

    instance.playerManager = playerManager
    instance.learnedWeaponTraits = {}

    return instance
end

--- Retorna os weapon traits aprendidos
---@return table<string, number>
function WeaponTraitsController:getLearnedWeaponTraits()
    return self.learnedWeaponTraits or {}
end

--- Obtém o tipo de ataque da arma equipada
---@return string|nil
function WeaponTraitsController:getEquippedWeaponAttackClass()
    if not self.playerManager.weaponController or not self.playerManager.weaponController.equippedWeapon then
        return nil
    end

    local weapon = self.playerManager.weaponController.equippedWeapon
    if not weapon then
        return nil
    end

    -- Obtém dados base da arma
    local baseData = weapon:getBaseData()
    if not baseData then
        return nil
    end

    return baseData.attackClass
end

--- Obtém weapon traits disponíveis para aprender baseado na arma equipada
---@return WeaponTrait[]
function WeaponTraitsController:getAvailableTraitsForEquippedWeapon()
    local attackClass = self:getEquippedWeaponAttackClass()
    if not attackClass then
        return {}
    end

    return self:getAvailableTraitsForAttackClass(attackClass)
end

--- Obtém weapon traits disponíveis para aprender para uma classe de ataque específica
---@param attackClass string Classe de ataque (e.g., "cone_slash", "arrow_projectile")
---@return WeaponTrait[]
function WeaponTraitsController:getAvailableTraitsForAttackClass(attackClass)
    local availableTraits = {}
    local allTraits = WeaponTraitsData.GetTraitsByAttackClass(attackClass)

    for _, trait in ipairs(allTraits) do
        local currentLevel = self.learnedWeaponTraits[trait.id] or 0
        local canLearn = false

        if trait.is_ultimate then
            -- Ultimate pode aparecer se qualquer variação do mesmo caminho atingir nível 4
            -- E se nenhum outro ultimate do mesmo caminho já foi aprendido
            if self:canLearnUltimate(trait) and not self:_isUltimateLearnedForPath(trait.path_id) then
                canLearn = true
            end
        else
            -- Trait normal pode ser aprendido se não chegou no máximo
            if currentLevel < trait.max_level then
                canLearn = self:canLearnTrait(trait)
            end
        end

        if canLearn then
            table.insert(availableTraits, trait)
        end
    end

    return availableTraits
end

--- Verifica se pode aprender um trait baseado nas regras de progressão
---@param trait WeaponTrait
---@return boolean
function WeaponTraitsController:canLearnTrait(trait)
    -- Regra: Não pode misturar variações no mesmo nível
    -- Se já aprendeu uma variação em um nível, deve continuar com ela ou mudar no mesmo nível

    local currentLevel = self.learnedWeaponTraits[trait.id] or 0
    local nextLevel = currentLevel + 1

    -- Se já tem nível neste trait, pode continuar
    if currentLevel > 0 then
        return true
    end

    -- Se é o primeiro nível, verifica se pode começar esta variação
    return self:canStartVariation(trait, nextLevel)
end

--- Verifica se pode começar uma nova variação
---@param trait WeaponTrait
---@param level number
---@return boolean
function WeaponTraitsController:canStartVariation(trait, level)
    -- Encontra a variação alternativa no mesmo caminho
    local otherVariationId = trait.variation_id == "variation1" and "variation2" or "variation1"
    local otherTraitId = trait.attack_class .. "_" .. trait.path_id .. "_var" .. otherVariationId:sub(-1)

    -- Se a outra variação foi aprendida, não pode começar esta
    local otherTraitLevel = self.learnedWeaponTraits[otherTraitId] or 0
    if otherTraitLevel > 0 then
        return false
    end

    return true
end

--- Verifica se um ultimate pode ser aprendido
--- Ultimates podem aparecer quando qualquer variação do mesmo caminho atingir nível 4
---@param trait WeaponTrait
---@return boolean
function WeaponTraitsController:canLearnUltimate(trait)
    local currentLevel = self.learnedWeaponTraits[trait.id] or 0
    if currentLevel >= trait.max_level then
        return false
    end

    -- Verifica se qualquer variação do mesmo caminho atingiu nível 4
    local attackClass = trait.attack_class
    local pathId = trait.path_id

    -- Procura por traits do mesmo caminho que atingiram nível 4
    local var1TraitId = attackClass .. "_" .. pathId .. "_var1"
    local var2TraitId = attackClass .. "_" .. pathId .. "_var2"

    local var1Level = self.learnedWeaponTraits[var1TraitId] or 0
    local var2Level = self.learnedWeaponTraits[var2TraitId] or 0

    return var1Level >= 4 or var2Level >= 4
end

--- Verifica se um ultimate de um determinado caminho já foi aprendido
---@param pathId string ID do caminho
---@return boolean
function WeaponTraitsController:_isUltimateLearnedForPath(pathId)
    local attackClass = self:getEquippedWeaponAttackClass()
    if not attackClass then
        return false
    end

    for learnedTraitId, _ in pairs(self.learnedWeaponTraits) do
        local learnedTrait = WeaponTraitsData.Traits[learnedTraitId]
        if learnedTrait and learnedTrait.is_ultimate and learnedTrait.attack_class == attackClass and learnedTrait.path_id == pathId then
            return true
        end
    end

    return false
end

--- Aplica um weapon trait
---@param traitId string ID do trait
---@return boolean success
function WeaponTraitsController:applyTrait(traitId)
    local trait = WeaponTraitsData.Traits[traitId]
    if not trait then
        Logger.error(
            "weapon_traits_controller.apply_trait.not_found",
            "[WeaponTraitsController:applyTrait] Trait não encontrado: " .. tostring(traitId)
        )
        return false
    end

    -- Verifica se pode aprender este trait
    if trait.is_ultimate then
        if self:_isUltimateLearnedForPath(trait.path_id) then
            Logger.error(
                "weapon_traits_controller.apply_trait.ultimate_already_learned",
                "[WeaponTraitsController:applyTrait] Ultimate para este caminho já foi aprendido."
            )
            return false
        end
    end
    local currentLevel = self.learnedWeaponTraits[traitId] or 0

    if trait.is_ultimate then
        -- Verifica se pode aprender este ultimate
        if not self:canLearnUltimate(trait) then
            Logger.error(
                "weapon_traits_controller.apply_trait.ultimate_requirements",
                "[WeaponTraitsController:applyTrait] Ultimate não pode ser aprendido - nenhum trait do caminho atingiu nível 4"
            )
            return false
        end
    else
        -- Trait normal
        if currentLevel >= trait.max_level then
            Logger.error(
                "weapon_traits_controller.apply_trait.max_level",
                "[WeaponTraitsController:applyTrait] Trait já está no nível máximo"
            )
            return false
        end

        if not self:canLearnTrait(trait) then
            Logger.error(
                "weapon_traits_controller.apply_trait.cannot_learn",
                "[WeaponTraitsController:applyTrait] Não pode aprender este trait devido às regras de progressão"
            )
            return false
        end
    end

    -- Aplica o trait
    local newLevel = currentLevel + 1
    self.learnedWeaponTraits[traitId] = newLevel

    -- Aplica os modificadores no PlayerStateController
    if self.playerManager.stateController then
        WeaponTraitsData.ApplyWeaponTrait(self.playerManager.stateController, traitId)
    end

    Logger.info(
        "weapon_traits_controller.apply_trait.success",
        string.format("[WeaponTraitsController:applyTrait] Trait aplicado: %s (nível %d)", trait.name, newLevel)
    )

    return true
end

--- Obtém o nível de um trait específico
---@param traitId string
---@return number
function WeaponTraitsController:getTraitLevel(traitId)
    return self.learnedWeaponTraits[traitId] or 0
end

--- Verifica se um trait foi aprendido
---@param traitId string
---@return boolean
function WeaponTraitsController:hasLearned(traitId)
    return (self.learnedWeaponTraits[traitId] or 0) > 0
end

--- Reaplica todos os weapon traits aprendidos (usado ao carregar save)
function WeaponTraitsController:reapplyAllTraits()
    if not self.playerManager.stateController then
        return
    end

    local traitsApplied = 0
    for traitId, level in pairs(self.learnedWeaponTraits) do
        for i = 1, level do
            WeaponTraitsData.ApplyWeaponTrait(self.playerManager.stateController, traitId)
            traitsApplied = traitsApplied + 1
        end
    end

    Logger.info(
        "weapon_traits_controller.reapply_all",
        string.format("[WeaponTraitsController:reapplyAllTraits] Reaplicados %d níveis de weapon traits", traitsApplied)
    )
end

--- Limpa todos os weapon traits aprendidos
function WeaponTraitsController:clearAllTraits()
    self.learnedWeaponTraits = {}

    Logger.info(
        "weapon_traits_controller.clear_all",
        "[WeaponTraitsController:clearAllTraits] Todos os weapon traits foram limpos"
    )
end

--- Salva o estado dos weapon traits
---@return table
function WeaponTraitsController:saveData()
    return {
        learnedWeaponTraits = self.learnedWeaponTraits or {}
    }
end

return WeaponTraitsController
