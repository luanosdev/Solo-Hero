-------------------------------------------------------------------------
-- Controlador para a mecânica de dash do jogador.
-- Gerencia o estado, cooldowns, movimento e efeitos visuais do dash.
-------------------------------------------------------------------------

local TablePool = require("src.utils.table_pool")
local RenderPipeline = require("src.core.render_pipeline")
local SpritePlayer = require('src.animations.sprite_player')

---@class DashController
---@field playerManager PlayerManager
---@field isDashing boolean
---@field dashCooldowns table
---@field dashDirection table
---@field dashSpeed number
---@field dashTimer number
---@field dashTrail table
local DashController = {}
DashController.__index = DashController

---Cria uma nova instância do DashController.
---@param playerManager PlayerManager A instância do PlayerManager que este controlador servirá.
---@return DashController
function DashController:new(playerManager)
    local instance = setmetatable({}, DashController)

    instance.playerManager = playerManager
    instance.isDashing = false
    instance.dashCooldowns = {}
    instance.dashDirection = { x = 0, y = 0 }
    instance.dashSpeed = 0
    instance.dashTimer = 0
    instance.dashTrail = {}
    instance.dashTrailTimer = 0

    return instance
end

---Verifica se o jogador está atualmente em um dash.
---@return boolean
function DashController:isOnDash()
    return self.isDashing
end

---Atualiza toda a lógica de dash, incluindo cooldowns e movimento.
---@param dt number Delta time.
function DashController:update(dt)
    self:updateDashCooldowns(dt)
    self:updateDashTrail(dt)

    if self.isDashing then
        self:updateDashMovement(dt)
    end
end

---Tenta iniciar um dash se houver cargas disponíveis.
function DashController:tryDash()
    Logger.debug("DashController.tryDash", "Tentando iniciar um dash.")
    local finalStats = self.playerManager:getCurrentFinalStats()
    local availableCharges = math.floor(finalStats.dashCharges or 1) - #self.dashCooldowns

    if not self.isDashing and availableCharges > 0 then
        self.isDashing = true
        self.playerManager:setInvincible(true)

        local moveVec = self.playerManager.inputManager:getMovementVector()
        if moveVec.x == 0 and moveVec.y == 0 then
            local targetPos = self.playerManager:getTargetPosition()
            local dx = targetPos.x - self.playerManager.player.position.x
            local dy = targetPos.y - self.playerManager.player.position.y
            local mag = math.sqrt(dx * dx + dy * dy)
            if mag > 0 then
                self.dashDirection = { x = dx / mag, y = dy / mag }
            else
                self.dashDirection = { x = 0, y = -1 }
            end
        else
            self.dashDirection = { x = moveVec.x, y = moveVec.y }
        end

        self.dashSpeed = finalStats.dashDistance / finalStats.dashDuration
        self.dashTimer = finalStats.dashDuration
        if self.playerManager.player then
            self.playerManager.player.animationPaused = true
        end

        table.insert(self.dashCooldowns, finalStats.dashCooldown)
    end
end

---Atualiza o movimento do jogador durante o dash.
---@param dt number Delta time.
function DashController:updateDashMovement(dt)
    self.dashTimer = self.dashTimer - dt

    self.dashTrailTimer = self.dashTrailTimer - dt
    if self.dashTrailTimer <= 0 then
        self:addDashTrailPart()
        self.dashTrailTimer = 0.04
    end

    if self.dashTimer <= 0 then
        self.isDashing = false
        self.playerManager:setInvincible(false)
        if self.playerManager.player then
            self.playerManager.player.animationPaused = false
        end
    else
        local moveX = self.dashDirection.x * self.dashSpeed * dt
        local moveY = self.dashDirection.y * self.dashSpeed * dt
        self.playerManager.player.position.x = self.playerManager.player.position.x + moveX
        self.playerManager.player.position.y = self.playerManager.player.position.y + moveY
    end
end

---Atualiza os cooldowns das cargas de dash.
---@param dt number Delta time.
function DashController:updateDashCooldowns(dt)
    for i = #self.dashCooldowns, 1, -1 do
        self.dashCooldowns[i] = self.dashCooldowns[i] - dt
        if self.dashCooldowns[i] <= 0 then
            table.remove(self.dashCooldowns, i)
        end
    end
end

---Adiciona uma parte do rastro do dash na posição atual do jogador.
function DashController:addDashTrailPart()
    if not self.playerManager.player then return end

    local trailPart = {
        position = { x = self.playerManager.player.position.x, y = self.playerManager.player.position.y },
        angle = self.playerManager.player.angle,
        lifetime = 0.3,
        maxLifetime = 0.3,
        alpha = 0.5,
    }
    table.insert(self.dashTrail, trailPart)
end

---Atualiza o tempo de vida e a transparência dos rastros.
---@param dt number Delta time.
function DashController:updateDashTrail(dt)
    for i = #self.dashTrail, 1, -1 do
        local part = self.dashTrail[i]
        part.lifetime = part.lifetime - dt
        part.alpha = 0.5 * (part.lifetime / part.maxLifetime)
        if part.lifetime <= 0 then
            table.remove(self.dashTrail, i)
        end
    end
end

---Coleta os rastros do dash para renderização.
---@param renderPipeline RenderPipeline O pipeline de renderização.
---@param sortY number O valor de Y para ordenação.
function DashController:collectRenderables(renderPipeline, sortY)
    if not self.playerManager or not self.playerManager.player then return end

    for _, trailPart in ipairs(self.dashTrail) do
        local trailRenderable = TablePool.get()
        trailRenderable.type = "dash_trail"
        trailRenderable.sortY = sortY - 1
        trailRenderable.depth = RenderPipeline.DEPTH_ENTITIES
        trailRenderable.drawFunction = function()
            -- Salva estado original
            local originalPos = { x = self.playerManager.player.position.x, y = self.playerManager.player.position.y }
            local originalAlpha = self.playerManager.player.alpha or 1.0
            local originalAngle = self.playerManager.player.angle

            -- Define estado para o rastro
            self.playerManager.player.position = trailPart.position
            self.playerManager.player.alpha = trailPart.alpha
            self.playerManager.player.angle = trailPart.angle

            SpritePlayer.draw(self.playerManager.player)

            -- Restaura estado
            self.playerManager.player.position = originalPos
            self.playerManager.player.alpha = originalAlpha
            self.playerManager.player.angle = originalAngle
        end
        renderPipeline:add(trailRenderable)
    end
end

--- Retorna o estado atual do cooldown do dash.
---@return number availableCharges O número de cargas prontas.
---@return number totalCharges O número total de cargas.
---@return number progress O progresso (0-1) da recarga da próxima carga.
function DashController:getDashStatus()
    local finalStats = self.playerManager:getCurrentFinalStats()
    local totalCharges = math.floor(finalStats.dashCharges or 1)
    local chargesInCooldown = #self.dashCooldowns
    local availableCharges = totalCharges - chargesInCooldown

    if availableCharges > 0 then
        return availableCharges, totalCharges, 1.0 -- Pelo menos uma carga pronta. Progresso é 1.
    end

    if chargesInCooldown == 0 then
        -- Sem cargas disponíveis e sem cargas recarregando (pode acontecer se totalCharges for 0)
        return 0, totalCharges, 1.0
    end

    -- Encontra o cooldown que terminará primeiro (o que tem menos tempo restante)
    local maxCooldownTime = finalStats.dashCooldown
    local firstCooldownToEnd = maxCooldownTime
    for _, cooldown in ipairs(self.dashCooldowns) do
        if cooldown < firstCooldownToEnd then
            firstCooldownToEnd = cooldown
        end
    end

    local progress = 1.0 - (firstCooldownToEnd / maxCooldownTime)
    return 0, totalCharges, progress
end

return DashController
