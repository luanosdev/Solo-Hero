-------------------------------------------------------------------------
-- Controlador para gerenciar armas equipadas do jogador.
-- Responsável por equipar armas, atualizar ataques de arma e mudanças de equipamento.
-------------------------------------------------------------------------

local Constants = require("src.config.constants")

---@class WeaponController
---@field playerManager PlayerManager Referência ao PlayerManager
---@field equippedWeapon BaseWeapon|nil Arma atualmente equipada
local WeaponController = {}
WeaponController.__index = WeaponController

--- Cria uma nova instância do WeaponController.
---@param playerManager PlayerManager A instância do PlayerManager
---@return WeaponController
function WeaponController:new(playerManager)
    Logger.debug(
        "weapon_controller.new",
        "[WeaponController:new] Inicializando controlador de armas"
    )

    local instance = setmetatable({}, WeaponController)

    instance.playerManager = playerManager
    instance.equippedWeapon = nil

    return instance
end

--- Atualiza a arma equipada e seus ataques
---@param dt number Delta time
---@param currentAngle number|nil Ângulo atual de ataque (opcional)
function WeaponController:update(dt, currentAngle)
    if not self.playerManager:isAlive() then
        return
    end

    -- Atualiza o ataque da arma se estiver equipada
    if self.equippedWeapon and self.equippedWeapon.attackInstance then
        if currentAngle then
            self.equippedWeapon.attackInstance:update(dt, currentAngle)
        else
            self.equippedWeapon.attackInstance:update(dt)
        end
    end
end

--- Equipa uma nova arma baseada nos dados fornecidos
---@param weaponItemInstance table|nil Dados da instância da arma, ou nil para desequipar
function WeaponController:setActiveWeapon(weaponItemInstance)
    -- Limpa a arma anterior (se houver)
    self:clearCurrentWeapon()

    -- Se estamos equipando uma nova arma (não nil)
    if weaponItemInstance and weaponItemInstance.itemBaseId then
        Logger.info(
            "weapon_controller.equip",
            string.format("[WeaponController:setActiveWeapon] Equipando arma: %s", weaponItemInstance.itemBaseId)
        )

        local itemData = self.playerManager.itemDataManager:getBaseItemData(weaponItemInstance.itemBaseId)
        if not itemData then
            error(string.format(
                "[WeaponController:setActiveWeapon] - Não foi possível carregar os dados da arma: %s",
                weaponItemInstance.itemBaseId))
        end

        if not itemData.weaponClass then
            error(string.format(
                "[WeaponController:setActiveWeapon] - Arma '%s' não possui 'weaponClass' definida",
                weaponItemInstance.itemBaseId))
        end

        local weaponClassPath = string.format("src.entities.equipments.weapons.%s", itemData.weaponClass)
        local success, WeaponClass = pcall(require, weaponClassPath)

        if success and WeaponClass then
            -- Cria uma nova instância da CLASSE da arma
            local classInstance = WeaponClass:new({ itemBaseId = weaponItemInstance.itemBaseId })

            if classInstance then
                -- Armazena a INSTÂNCIA DA CLASSE
                self.equippedWeapon = classInstance

                -- Chama o método :equip da INSTÂNCIA DA CLASSE, passando os DADOS do item
                if self.equippedWeapon.equip then
                    Logger.debug(
                        "weapon_controller.equip.call",
                        string.format(
                            "[WeaponController:setActiveWeapon] Chamando :equip na instância da classe da arma")
                    )
                    self.equippedWeapon:equip(self.playerManager, weaponItemInstance)

                    Logger.info(
                        "weapon_controller.equip.success",
                        string.format("[WeaponController:setActiveWeapon] Arma '%s' equipada com sucesso",
                            weaponItemInstance.itemBaseId)
                    )
                else
                    error(string.format(
                        "[WeaponController:setActiveWeapon] - O método :equip não foi encontrado na classe da arma '%s'!",
                        weaponClassPath))
                end
            else
                error(string.format(
                    "[WeaponController:setActiveWeapon] - Falha ao criar a instância da CLASSE da arma '%s' usando :new().",
                    weaponClassPath))
            end
        else
            error(string.format(
                "[WeaponController:setActiveWeapon] - Não foi possível carregar a classe da arma: %s. Detalhe: %s",
                weaponClassPath, tostring(WeaponClass)))
        end
    else
        Logger.info(
            "weapon_controller.unequip",
            "[WeaponController:setActiveWeapon] Nenhuma arma equipada (desequipando)"
        )
    end

    -- Invalida o cache de stats devido à mudança de equipamento
    self.playerManager:invalidateStatsCache()
end

--- Remove a arma atualmente equipada
function WeaponController:clearCurrentWeapon()
    if self.equippedWeapon then
        Logger.debug(
            "weapon_controller.clear",
            "[WeaponController:clearCurrentWeapon] Removendo arma equipada"
        )

        -- Se a arma tem um método de limpeza, chama-o
        if self.equippedWeapon.unequip then
            self.equippedWeapon:unequip()
        elseif self.equippedWeapon.destroy then
            self.equippedWeapon:destroy()
        end

        self.equippedWeapon = nil
    end
end

--- Configura a arma inicial durante o setup do gameplay
---@param equippedItems table Itens equipados do hunter
function WeaponController:setupInitialWeapon(equippedItems)
    Logger.debug(
        "weapon_controller.setup",
        "[WeaponController:setupInitialWeapon] Configurando arma inicial"
    )

    local weaponItem = equippedItems[Constants.SLOT_IDS.WEAPON]
    if weaponItem then
        self:setActiveWeapon(weaponItem)
    else
        Logger.warn(
            "weapon_controller.setup.no_weapon",
            "[WeaponController:setupInitialWeapon] Nenhuma arma encontrada nos itens equipados"
        )
    end
end

--- Verifica se uma arma está atualmente equipada
---@return boolean
function WeaponController:hasEquippedWeapon()
    return self.equippedWeapon ~= nil
end

--- Obtém a arma atualmente equipada
---@return BaseWeapon|nil
function WeaponController:getEquippedWeapon()
    return self.equippedWeapon
end

--- Verifica se a arma equipada tem uma instância de ataque válida
---@return boolean|nil
function WeaponController:hasValidAttackInstance()
    return self.equippedWeapon and self.equippedWeapon.attackInstance ~= nil
end

--- Obtém informações sobre a arma equipada
---@return table|nil
function WeaponController:getWeaponInfo()
    if not self.equippedWeapon then
        return nil
    end

    local info = {
        hasWeapon = true,
        hasAttackInstance = self.equippedWeapon.attackInstance ~= nil,
        weaponType = type(self.equippedWeapon)
    }

    -- Adiciona informações do item se disponível
    if self.equippedWeapon.itemInstance then
        info.itemBaseId = self.equippedWeapon.itemInstance.itemBaseId
        info.itemData = self.equippedWeapon.itemInstance
    end

    return info
end

--- Força uma atualização da arma (útil quando os stats do jogador mudam)
function WeaponController:refreshWeapon()
    if self.equippedWeapon and self.equippedWeapon.refresh then
        Logger.debug(
            "weapon_controller.refresh",
            "[WeaponController:refreshWeapon] Atualizando arma equipada"
        )
        self.equippedWeapon:refresh()
    end
end

--- Desenha elementos visuais da arma (se necessário)
function WeaponController:draw()
    if self.equippedWeapon and self.equippedWeapon.attackInstance and self.equippedWeapon.attackInstance.draw then
        self.equippedWeapon.attackInstance:draw()
    end
end

--- Coleta renderáveis da arma para o pipeline de renderização
---@param renderPipeline RenderPipeline Pipeline de renderização
function WeaponController:collectRenderables(renderPipeline)
    if self.equippedWeapon and self.equippedWeapon.attackInstance and self.equippedWeapon.attackInstance.collectRenderables then
        self.equippedWeapon.attackInstance:collectRenderables(renderPipeline)
    end
end

--- Executa um ataque com a arma equipada
---@param attackArgs table|nil Argumentos para o ataque (ângulo, etc.)
---@return boolean success True se o ataque foi executado com sucesso
function WeaponController:performAttack(attackArgs)
    if not self:hasValidAttackInstance() then
        return false
    end

    if self.equippedWeapon.attackInstance.cast then
        self.equippedWeapon.attackInstance:cast(attackArgs)
        return true
    end

    return false
end

--- Alterna o preview de ataque da arma
function WeaponController:toggleAttackPreview()
    if self:hasValidAttackInstance() and self.equippedWeapon.attackInstance.togglePreview then
        self.equippedWeapon.attackInstance:togglePreview()
        Logger.debug(
            "weapon_controller.preview.toggle",
            "[WeaponController:toggleAttackPreview] Preview de ataque alternado"
        )
    end
end

--- Obtém estatísticas da arma atual
---@return table|nil
function WeaponController:getWeaponStats()
    if not self.equippedWeapon then
        return nil
    end

    -- Tenta obter stats da instância do item
    if self.equippedWeapon.itemInstance and self.equippedWeapon.itemInstance.itemBaseId then
        local itemData = self.playerManager.itemDataManager:getBaseItemData(self.equippedWeapon.itemInstance.itemBaseId)
        if itemData then
            return {
                damage = itemData.damage or 0,
                attackSpeed = itemData.attackSpeed or 1.0,
                range = itemData.range or 1.0,
                modifiers = itemData.modifiers or {}
            }
        end
    end

    return {}
end

return WeaponController
