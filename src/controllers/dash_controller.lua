-------------------------------------------------------------------------
-- Controlador para a mecânica de dash do jogador.
-- Gerencia o estado, cooldowns, movimento e efeitos visuais do dash.
-------------------------------------------------------------------------

local TablePool = require("src.utils.table_pool")
local RenderPipeline = require("src.core.render_pipeline")
local SpritePlayer = require('src.animations.sprite_player')
local Constants = require("src.config.constants")

---@class DashController
---@field playerManager PlayerManager
---@field isDashing boolean
---@field chargesUsed number
---@field rechargeTimer number
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
    instance.chargesUsed = 0   -- Quantidade de cargas em cooldown
    instance.rechargeTimer = 0 -- Timer para a carga ATUALMENTE recarregando
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
    self:updateRechargeQueue(dt)
    self:updateDashTrail(dt)

    if self.isDashing then
        self:updateDashMovement(dt)
    end
end

---Tenta iniciar um dash se houver cargas disponíveis.
function DashController:tryDash()
    Logger.debug("DashController.tryDash", "Tentando iniciar um dash.")
    local finalStats = self.playerManager:getCurrentFinalStats()
    local totalCharges = math.floor(finalStats.dashCharges or 1)
    local availableCharges = totalCharges - self.chargesUsed

    if not self.isDashing and availableCharges > 0 then
        self.isDashing = true
        self.playerManager:setInvincible(true)

        local moveVec = self.playerManager.inputManager:getMovementVector()
        if moveVec.x == 0 and moveVec.y == 0 then
            local playerPos = self.playerManager:getPlayerPosition()
            local targetPos = self.playerManager:getTargetPosition()
            local dx = targetPos.x - playerPos.x
            local dy = targetPos.y - playerPos.y
            local mag = math.sqrt(dx * dx + dy * dy)
            if mag > 0 then
                self.dashDirection = { x = dx / mag, y = dy / mag }
            else
                self.dashDirection = { x = 0, y = -1 }
            end
        else
            self.dashDirection = { x = moveVec.x, y = moveVec.y }
        end

        self.dashSpeed = Constants.metersToPixels(finalStats.dashDistance) / finalStats.dashDuration
        self.dashTimer = finalStats.dashDuration
        self.playerManager:getPlayerSprite().animationPaused = true

        self.chargesUsed = self.chargesUsed + 1
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
        self.playerManager:getPlayerSprite().animationPaused = false
    else
        local moveX = self.dashDirection.x * self.dashSpeed * dt
        local moveY = self.dashDirection.y * self.dashSpeed * dt
        local playerPos = self.playerManager:getPlayerPosition()
        self.playerManager.movementController:setPosition(playerPos.x + moveX, playerPos.y + moveY)
    end
end

---Atualiza a fila de recarga do dash.
---@param dt number Delta time.
function DashController:updateRechargeQueue(dt)
    -- Se temos cargas para recarregar
    if self.chargesUsed > 0 then
        -- Se nenhuma carga está recarregando no momento, inicia o timer
        if self.rechargeTimer <= 0 then
            local finalStats = self.playerManager:getCurrentFinalStats()
            self.rechargeTimer = finalStats.dashCooldown
        end

        -- Decrementa o timer
        self.rechargeTimer = self.rechargeTimer - dt

        -- Se o timer zerou, uma carga foi recarregada
        if self.rechargeTimer <= 0 then
            self.chargesUsed = self.chargesUsed - 1
            self.rechargeTimer = 0 -- Reseta para que a próxima carga comece no próximo frame (se houver)
        end
    end
end

---Adiciona uma parte do rastro do dash na posição atual do jogador.
function DashController:addDashTrailPart()
    if not self.playerManager:getPlayerSprite() then return end

    local trailPart = {
        position = { x = self.playerManager:getPlayerPosition().x, y = self.playerManager:getPlayerPosition().y },
        angle = self.playerManager:getPlayerSprite().angle,
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
    if not self.playerManager:getPlayerSprite() then return end
    local playerSprite = self.playerManager:getPlayerSprite()
    local playerPos = self.playerManager:getPlayerPosition()

    for _, trailPart in ipairs(self.dashTrail) do
        local trailRenderable = TablePool.get()
        trailRenderable.type = "dash_trail"
        trailRenderable.sortY = sortY - 1
        trailRenderable.depth = RenderPipeline.DEPTH_ENTITIES
        trailRenderable.drawFunction = function()
            -- Salva estado original
            local originalPos = { x = playerPos.x, y = playerPos.y }
            local originalAlpha = playerSprite.alpha or 1.0
            local originalAngle = playerSprite.angle

            -- Define estado para o rastro
            playerSprite.position = trailPart.position
            playerSprite.alpha = trailPart.alpha
            playerSprite.angle = trailPart.angle

            SpritePlayer.draw(playerSprite)

            -- Restaura estado
            playerSprite.position = originalPos
            playerSprite.alpha = originalAlpha
            playerSprite.angle = originalAngle
        end
        renderPipeline:add(trailRenderable)
    end
end

--- Retorna o estado atual do cooldown do dash.
---@return number availableCharges O número de cargas prontas.
---@return number totalCharges O número total de cargas.
---@return table cooldownProgresses Uma tabela com o progresso (0-1) de cada carga em recarga.
function DashController:getDashStatus()
    local finalStats = self.playerManager:getCurrentFinalStats()
    local totalCharges = math.floor(finalStats.dashCharges or 1)
    local availableCharges = totalCharges - self.chargesUsed

    local progresses = {}
    local maxCooldownTime = finalStats.dashCooldown

    if self.chargesUsed > 0 and maxCooldownTime > 0 then
        -- 1. Adiciona o progresso da carga ATIVA
        if self.rechargeTimer > 0 then
            local progress = 1.0 - (self.rechargeTimer / maxCooldownTime)
            table.insert(progresses, math.max(0, math.min(1, progress)))
        else
            -- Se o timer é 0 mas ainda há cargas, significa que a próxima começa neste frame.
            -- Mostramos como 0% para evitar um flash do ícone "cheio" por 1 frame.
            table.insert(progresses, 0)
        end

        -- 2. Adiciona as cargas que estão na FILA (progresso 0%)
        for i = 1, self.chargesUsed - 1 do
            table.insert(progresses, 0)
        end
    end

    return availableCharges, totalCharges, progresses
end

return DashController
