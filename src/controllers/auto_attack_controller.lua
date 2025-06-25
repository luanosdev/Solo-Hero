-------------------------------------------------------------------------
-- Controlador para gerenciar auto-attack e auto-aim do jogador.
-- Responsável por mira automática, encontrar alvos e controlar ataques.
-------------------------------------------------------------------------

local TablePool = require("src.utils.table_pool")

---@class AutoAttackController
---@field playerManager PlayerManager Referência ao PlayerManager
---@field autoAttack boolean Estado atual do auto-attack
---@field autoAttackEnabled boolean Configuração de auto-attack habilitado
---@field autoAim boolean Estado atual do auto-aim
---@field autoAimEnabled boolean Configuração de auto-aim habilitado
---@field originalAutoAttackState boolean Estado original do auto-attack
---@field originalAutoAimState boolean Estado original do auto-aim
---@field previousLeftButtonState boolean Estado do botão esquerdo no frame anterior
---@field lastMouseX number Última posição X do mouse
---@field lastMouseY number Última posição Y do mouse
local AutoAttackController = {}
AutoAttackController.__index = AutoAttackController

--- Cria uma nova instância do AutoAttackController.
---@param playerManager PlayerManager A instância do PlayerManager
---@return AutoAttackController
function AutoAttackController:new(playerManager)
    Logger.debug(
        "auto_attack_controller.new",
        "[AutoAttackController:new] Inicializando controlador de auto-attack"
    )

    local instance = setmetatable({}, AutoAttackController)

    instance.playerManager = playerManager
    instance.autoAttack = false
    instance.autoAttackEnabled = false
    instance.autoAim = false
    instance.autoAimEnabled = false
    instance.originalAutoAttackState = false
    instance.originalAutoAimState = false
    instance.previousLeftButtonState = false
    instance.lastMouseX = 0
    instance.lastMouseY = 0

    return instance
end

--- Atualiza o sistema de auto-attack e controle de mouse
---@param currentAngle number Ângulo atual de ataque (opcional)
function AutoAttackController:update(currentAngle)
    if not self.playerManager:isAlive() then
        return
    end

    self:updateMouseTracking()
    self:updateMouseButtonState()

    -- Atualiza o auto attack, passando o ângulo calculado
    self:updateAutoAttack(currentAngle)
end

--- Atualiza o rastreamento da posição do mouse
function AutoAttackController:updateMouseTracking()
    if self.playerManager.inputManager then
        local mouseWorldPos = self.playerManager.inputManager:getMouseWorldPosition()
        self.lastMouseX = mouseWorldPos.x
        self.lastMouseY = mouseWorldPos.y
    end
end

--- Atualiza o estado do botão esquerdo do mouse e gerencia auto-attack/aim
function AutoAttackController:updateMouseButtonState()
    if not self.playerManager.inputManager then return end

    local currentLeftButtonState = self.playerManager.inputManager.mouse.isLeftButtonDown

    -- Botão foi pressionado neste frame?
    if currentLeftButtonState and not self.previousLeftButtonState then
        -- Salva o estado atual das opções de toggle
        self.originalAutoAttackState = self.autoAttackEnabled
        self.originalAutoAimState = self.autoAimEnabled

        Logger.debug(
            "auto_attack_controller.mouse.pressed",
            "[AutoAttackController:updateMouseButtonState] Botão esquerdo pressionado"
        )
    end

    -- Botão está sendo segurado?
    if currentLeftButtonState then
        -- Força ataque contínuo e mira no mouse
        self.autoAttack = true
        self.autoAim = false
    else
        -- Botão não está pressionado, usa as configurações de toggle
        self.autoAttack = self.autoAttackEnabled
        self.autoAim = self.autoAimEnabled

        -- Botão foi solto neste frame?
        if not currentLeftButtonState and self.previousLeftButtonState then
            Logger.debug(
                "auto_attack_controller.mouse.released",
                "[AutoAttackController:updateMouseButtonState] Botão esquerdo liberado"
            )
        end
    end

    -- Atualiza o estado anterior do botão para o próximo frame
    self.previousLeftButtonState = currentLeftButtonState
end

--- Atualiza a lógica de auto-attack
---@param currentAngle number Ângulo atual de ataque
function AutoAttackController:updateAutoAttack(currentAngle)
    if not self.playerManager.stateController then return end
    if not self.playerManager.weaponController then return end

    local equippedWeapon = self.playerManager.weaponController:getEquippedWeapon()
    if self.autoAttack and equippedWeapon and equippedWeapon.attackInstance then
        local args = TablePool.get()
        args.angle = currentAngle
        equippedWeapon.attackInstance:cast(args)
        TablePool.release(args)
    elseif self.autoAttack then
        if (equippedWeapon and not equippedWeapon.attackInstance) then
            Logger.warn(
                "auto_attack_controller.weapon.missing_instance",
                string.format(
                    "[AutoAttackController:updateAutoAttack] Auto-attack ativo mas arma/instância ausente. Arma: %s, Instância: %s",
                    tostring(equippedWeapon),
                    tostring(equippedWeapon and equippedWeapon.attackInstance))
            )
        end
    end
end

--- Obtém a posição do alvo baseado no auto-aim ou posição do mouse
---@return Vector2D
function AutoAttackController:getTargetPosition()
    local playerPos = self.playerManager:getPlayerPosition()
    if self.autoAim and self.playerManager.enemyManager and playerPos then
        local closestEnemy = self:findClosestEnemy(
            playerPos,
            self.playerManager.enemyManager:getEnemies()
        )
        if closestEnemy then
            return closestEnemy.position
        end
    end

    -- Se autoAim desativado, mira não encontrada, ou managers/player não disponíveis, usa o mouse
    if self.playerManager.inputManager then
        return self.playerManager.inputManager:getMouseWorldPosition()
    else
        -- Fallback muito básico se InputManager não estiver pronto
        Logger.warn(
            "auto_attack_controller.target.fallback",
            "[AutoAttackController:getTargetPosition] InputManager não disponível, usando posição padrão (0,0)"
        )
        return { x = 0, y = 0 }
    end
end

--- Encontra o inimigo mais próximo da posição dada
---@param position Vector2D Posição de referência
---@param enemies BaseEnemy[] Lista de inimigos a verificar
---@return BaseEnemy|nil enemy O inimigo mais próximo, ou nil se a lista estiver vazia
function AutoAttackController:findClosestEnemy(position, enemies)
    local closestEnemy = nil
    local minDistanceSq = math.huge

    if not enemies or #enemies == 0 then
        return nil
    end

    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            local dx = enemy.position.x - position.x
            local dy = enemy.position.y - position.y
            local distanceSq = dx * dx + dy * dy
            if distanceSq < minDistanceSq then
                minDistanceSq = distanceSq
                closestEnemy = enemy
            end
        end
    end

    return closestEnemy
end

--- Alterna o estado do auto-attack
function AutoAttackController:toggleAutoAttack()
    self.autoAttackEnabled = not self.autoAttackEnabled
    self.autoAttack = self.autoAttackEnabled

    Logger.info(
        "auto_attack_controller.toggle.attack",
        string.format("[AutoAttackController:toggleAutoAttack] Auto-attack %s",
            self.autoAttackEnabled and "HABILITADO" or "DESABILITADO")
    )
end

--- Alterna o estado do auto-aim
function AutoAttackController:toggleAutoAim()
    self.autoAimEnabled = not self.autoAimEnabled
    self.autoAim = self.autoAimEnabled

    Logger.info(
        "auto_attack_controller.toggle.aim",
        string.format("[AutoAttackController:toggleAutoAim] Auto-aim %s",
            self.autoAimEnabled and "HABILITADO" or "DESABILITADO")
    )
end

--- Alterna a visualização de preview de ataques
function AutoAttackController:toggleAttackPreview()
    local equippedWeapon = self.playerManager.weaponController:getEquippedWeapon()
    if equippedWeapon and equippedWeapon.attackInstance then
        equippedWeapon.attackInstance:togglePreview()
        Logger.debug(
            "auto_attack_controller.toggle.preview",
            "[AutoAttackController:toggleAttackPreview] Preview de ataque alternado"
        )
    else
        Logger.warn(
            "auto_attack_controller.toggle.preview_failed",
            "[AutoAttackController:toggleAttackPreview] Não é possível alternar preview - arma/instância não disponível"
        )
    end
end

--- Manipula clique do mouse esquerdo
---@param x number Posição X do clique
---@param y number Posição Y do clique
function AutoAttackController:leftMouseClicked(x, y)
    Logger.debug(
        "auto_attack_controller.mouse.clicked",
        string.format("[AutoAttackController:leftMouseClicked] Clique em (%.1f, %.1f)", x, y)
    )
    -- A lógica principal é tratada em updateMouseButtonState
end

--- Manipula liberação do mouse esquerdo
---@param x number Posição X da liberação
---@param y number Posição Y da liberação
function AutoAttackController:leftMouseReleased(x, y)
    Logger.debug(
        "auto_attack_controller.mouse.released_event",
        string.format("[AutoAttackController:leftMouseReleased] Liberação em (%.1f, %.1f)", x, y)
    )
    -- A lógica principal é tratada em updateMouseButtonState
end

--- Obtém informações sobre o estado atual do controlador
---@return table
function AutoAttackController:getStatus()
    return {
        autoAttack = self.autoAttack,
        autoAttackEnabled = self.autoAttackEnabled,
        autoAim = self.autoAim,
        autoAimEnabled = self.autoAimEnabled,
        mousePressed = self.previousLeftButtonState,
        lastMousePosition = { x = self.lastMouseX, y = self.lastMouseY }
    }
end

--- Define o estado do auto-attack (útil para scripts/comandos)
---@param enabled boolean Estado desejado
function AutoAttackController:setAutoAttackEnabled(enabled)
    self.autoAttackEnabled = enabled
    if not self.previousLeftButtonState then -- Só aplica se não estiver segurando o mouse
        self.autoAttack = enabled
    end

    Logger.info(
        "auto_attack_controller.set.attack",
        string.format("[AutoAttackController:setAutoAttackEnabled] Auto-attack definido para: %s", tostring(enabled))
    )
end

--- Define o estado do auto-aim (útil para scripts/comandos)
---@param enabled boolean Estado desejado
function AutoAttackController:setAutoAimEnabled(enabled)
    self.autoAimEnabled = enabled
    if not self.previousLeftButtonState then -- Só aplica se não estiver segurando o mouse
        self.autoAim = enabled
    end

    Logger.info(
        "auto_attack_controller.set.aim",
        string.format("[AutoAttackController:setAutoAimEnabled] Auto-aim definido para: %s", tostring(enabled))
    )
end

return AutoAttackController
