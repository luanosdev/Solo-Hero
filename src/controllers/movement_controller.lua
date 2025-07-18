-------------------------------------------------------------------------
-- Controlador para gerenciar movimento do jogador.
-- Responsável por movimento, posição, velocidade e coordenação com animações.
-------------------------------------------------------------------------

local SpritePlayer = require('src.animations.sprite_player')
local Camera = require("src.config.camera")
local Constants = require("src.config.constants")

---@class MovementController
---@field playerManager PlayerManager Referência ao PlayerManager
---@field player PlayerSprite|nil Referência ao sprite do jogador
---@field radius number Raio de colisão do jogador
local MovementController = {}
MovementController.__index = MovementController

--- Cria uma nova instância do MovementController.
---@param playerManager PlayerManager A instância do PlayerManager
---@return MovementController
function MovementController:new(playerManager)
    Logger.debug(
        "movement_controller.new",
        "[MovementController:new] Inicializando controlador de movimento"
    )

    local instance = setmetatable({}, MovementController)

    instance.playerManager = playerManager
    instance.player = nil
    instance.radius = 15 -- Tamanho padrão do círculo de colisão

    return instance
end

--- Inicializa o sprite do jogador durante o setup do gameplay
---@param finalStats FinalStats Stats finais calculados do jogador
function MovementController:setupPlayerSprite(finalStats)
    Logger.debug(
        "movement_controller.setup",
        "[MovementController:setupPlayerSprite] Configurando sprite do jogador"
    )

    -- Carrega recursos do player sprite se ainda não foram carregados
    SpritePlayer.load()

    local finalSpeed = Constants.moveSpeedToPixels(finalStats.moveSpeed)
    Logger.info(
        "movement_controller.setup.speed",
        string.format("[MovementController:setupPlayerSprite] Velocidade final do sprite: %.2f pixels/s (%.2f m/s)",
            finalSpeed, finalStats.moveSpeed)
    )

    -- Obtém dados do caçador atual para configurar aparência
    local hunterId = self.playerManager:getCurrentHunterId()
    local hunterData = nil
    if hunterId and self.playerManager.hunterManager then
        hunterData = self.playerManager.hunterManager.hunters[hunterId]
    end

    -- Configura aparência baseada nos dados do caçador
    local appearance = {
        skinTone = (hunterData and hunterData.skinTone) or "medium",
        equipment = {
            bag = nil,
            belt = nil,
            chest = nil,
            head = nil,
            leg = nil,
            shoe = nil
        },
        weapon = {
            folderPath = nil,
            animationType = nil
        }
    }

    -- Cria a instância do sprite do jogador
    self.player = SpritePlayer.newConfig({
        position = {
            x = ResolutionUtils.getGameWidth() / 2,
            y = ResolutionUtils.getGameHeight() / 2
        },
        scale = 1.4,
        appearance = appearance
    })

    -- Inicializa vetor de velocidade
    self.player.velocity = { x = 0, y = 0 }

    Logger.info(
        "movement_controller.setup.success",
        string.format(
            "[MovementController:setupPlayerSprite] Sprite criado com skinTone: %s",
            appearance.skinTone
        )
    )

    -- Atualiza aparência da arma se já houver uma equipada
    if self.playerManager.weaponController then
        self.playerManager.weaponController:_updateWeaponAppearance()
    end
end

--- Atualiza o movimento do jogador
---@param dt number Delta time
---@param targetPosition Vector2D Posição alvo para movimento
---@return number|nil distanceMoved Distância movida neste frame
function MovementController:update(dt, targetPosition)
    if not self.playerManager:isAlive() then
        return nil
    end

    self:updateCamera(dt)

    -- Verifica se não está em dash
    if self.playerManager.dashController and self.playerManager.dashController:isOnDash() then
        return nil -- Dash controller gerencia o movimento durante dash
    end

    -- Atualiza o sprite do player apenas se a animação não estiver pausada
    if not self.player.animationPaused then
        -- Obtém a velocidade atual do jogador baseada nos stats finais
        local finalStats = self.playerManager:getCurrentFinalStats()
        local currentSpeed = finalStats and Constants.moveSpeedToPixels(finalStats.moveSpeed) or
            Constants.moveSpeedToPixels(Constants.HUNTER_DEFAULT_STATS.moveSpeed)

        local distanceMoved = SpritePlayer.update(self.player, dt, targetPosition, currentSpeed)

        -- Registra movimento nas estatísticas se houve movimento
        if distanceMoved and distanceMoved > 0 and self.playerManager.gameStatisticsManager then
            self.playerManager.gameStatisticsManager:registerMovement(distanceMoved)
        end

        return distanceMoved
    end

    return nil
end

--- Atualiza a câmera para seguir o jogador
---@param dt number Delta time
function MovementController:updateCamera(dt)
    if self.player and self.player.position then
        Camera:follow(self.player.position, dt)
    end
end

--- Obtém a posição atual do jogador
---@return Vector2D|nil
function MovementController:getPosition()
    if self.player and self.player.position then
        return self.player.position
    end
    return nil
end

--- Define a posição do jogador
---@param x number Coordenada X
---@param y number Coordenada Y
function MovementController:setPosition(x, y)
    if self.player and self.player.position then
        self.player.position.x = x
        self.player.position.y = y
    end
end

--- Obtém a posição de colisão do jogador (nos pés do sprite)
---@return table Tabela com position e radius
function MovementController:getCollisionPosition()
    if not self.player or not self.player.position then
        Logger.warn(
            "movement_controller.collision.no_player",
            "[MovementController:getCollisionPosition] Player não inicializado, retornando posição padrão"
        )
        return {
            position = { x = 0, y = 0 },
            radius = self.radius
        }
    end

    return {
        position = {
            x = self.player.position.x,
            y = self.player.position.y + 25, -- Offset para os pés
        },
        radius = self.radius
    }
end

--- Para o movimento do jogador (usado quando morre)
function MovementController:stopMovement()
    if self.player then
        if self.player.velocity then
            self.player.velocity.x = 0
            self.player.velocity.y = 0
        end

        if self.player.stopMovement then
            self.player:stopMovement()
        end

        Logger.debug(
            "movement_controller.stop",
            "[MovementController:stopMovement] Movimento do jogador parado"
        )
    end
end

--- Pausa ou retoma a animação do sprite
---@param paused boolean Estado de pausa desejado
function MovementController:setAnimationPaused(paused)
    if self.player then
        self.player.animationPaused = paused

        Logger.debug(
            "movement_controller.animation.pause",
            string.format("[MovementController:setAnimationPaused] Animação %s",
                paused and "PAUSADA" or "RETOMADA")
        )
    end
end

--- Verifica se a animação está pausada
---@return boolean
function MovementController:isAnimationPaused()
    return self.player and self.player.animationPaused or false
end

--- Desenha o sprite do jogador
function MovementController:draw()
    if self.player then
        SpritePlayer.draw(self.player)
    end
end

--- Obtém informações de debug sobre movimento
---@return table
function MovementController:getDebugInfo()
    local info = {
        hasPlayer = self.player ~= nil,
        animationPaused = self:isAnimationPaused(),
        collisionRadius = self.radius
    }

    if self.player then
        info.position = self.player.position and {
            x = self.player.position.x,
            y = self.player.position.y
        } or nil
        info.velocity = self.player.velocity and {
            x = self.player.velocity.x,
            y = self.player.velocity.y
        } or nil
        info.scale = self.player.scale
    end

    return info
end

--- Teleporta o jogador para uma posição específica
---@param x number Coordenada X de destino
---@param y number Coordenada Y de destino
function MovementController:teleportTo(x, y)
    self:setPosition(x, y)

    -- Para qualquer movimento em andamento
    if self.player and self.player.velocity then
        self.player.velocity.x = 0
        self.player.velocity.y = 0
    end

    Logger.info(
        "movement_controller.teleport",
        string.format("[MovementController:teleportTo] Jogador teleportado para (%.1f, %.1f)", x, y)
    )
end

--- Move o jogador em uma direção específica por uma distância
---@param directionX number Direção X normalizada
---@param directionY number Direção Y normalizada
---@param distance number Distância a mover
function MovementController:moveInDirection(directionX, directionY, distance)
    if not self.player or not self.player.position then return end

    local newX = self.player.position.x + (directionX * distance)
    local newY = self.player.position.y + (directionY * distance)

    self:setPosition(newX, newY)

    Logger.debug(
        "movement_controller.move_direction",
        string.format("[MovementController:moveInDirection] Movido %.1f pixels na direção (%.2f, %.2f)",
            distance, directionX, directionY)
    )
end

--- Verifica se o jogador está próximo a uma posição
---@param targetX number Coordenada X do alvo
---@param targetY number Coordenada Y do alvo
---@param threshold number Distância mínima para considerar "próximo"
---@return boolean
function MovementController:isNearPosition(targetX, targetY, threshold)
    if not self.player or not self.player.position then
        return false
    end

    local dx = self.player.position.x - targetX
    local dy = self.player.position.y - targetY
    local distance = math.sqrt(dx * dx + dy * dy)

    return distance <= threshold
end

--- Obtém a velocidade atual do jogador
---@return Vector2D
function MovementController:getVelocity()
    if self.player and self.player.velocity then
        return {
            x = self.player.velocity.x,
            y = self.player.velocity.y
        }
    end
    return { x = 0, y = 0 }
end

return MovementController
