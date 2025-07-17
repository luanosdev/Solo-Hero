-------------------------------------------------------------------------
-- Controlador para gerenciar movimento do jogador.
-- Responsável por movimento, posição, velocidade e coordenação com animações.
-------------------------------------------------------------------------

local SpritePlayer = require('src.animations.sprite_player')
local Constants = require("src.config.constants")

---@class LogicalPosition
---@field patchX number
---@field patchY number
---@field tileX number
---@field tileY number

---@class MovementController
---@field playerManager PlayerManager Referência ao PlayerManager
---@field inputManager InputManager Referência ao InputManager
---@field player PlayerSprite|nil Referência ao sprite do jogador
---@field radius number Raio de colisão do jogador
---@field mapManager InfinityWrapMapManager|nil Referência ao gerenciador do mapa
---@field logicalPosition LogicalPosition Posição lógica no mapa
local MovementController = {}
MovementController.__index = MovementController

--- Cria uma nova instância do MovementController.
---@param playerManager PlayerManager A instância do PlayerManager
---@param mapManager InfinityWrapMapManager A instância do InfinityWrapMapManager
---@param inputManager InputManager A instância do InputManager
---@return MovementController
function MovementController:new(playerManager, mapManager, inputManager)
    Logger.debug(
        "movement_controller.new",
        "[MovementController:new] Inicializando controlador de movimento"
    )

    local instance = setmetatable({}, MovementController)

    instance.playerManager = playerManager
    instance.inputManager = inputManager
    instance.player = nil
    instance.radius = 15 -- Tamanho padrão do círculo de colisão
    instance.mapManager = mapManager
    -- Posição lógica inicial no mapa
    instance.logicalPosition = {
        patchX = 0,
        patchY = 0,
        tileX = 12.0, -- Centro do patch inicial
        tileY = 12.0,
    }

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
---@param targetPosition Vector2D Posição do jogador
---@param isPaused boolean Se a animação está pausada
---@return number|nil distanceMoved Distância movida neste frame
function MovementController:update(dt, targetPosition, isPaused)
    if not self.playerManager:isAlive() then return nil end

    -- Não move se estiver em dash ou UI bloqueando
    if (self.playerManager.dashController and self.playerManager.dashController:isOnDash()) or isPaused then
        if self.player then self.player.velocity = { x = 0, y = 0 } end
        return nil
    end

    -- Atualiza o sprite do player apenas se a animação não estiver pausada
    if not self.player.animationPaused then
        -- Obtém a velocidade atual do jogador baseada nos stats finais
        local finalStats = self.playerManager:getCurrentFinalStats()
        local moveSpeedInTiles = Constants.moveSpeedToPixels(finalStats.moveSpeed) -- Velocidade em m/s agora é tiles/s

        local moveVector = self.inputManager:getMovementVector()

        -- O vetor para animação é o input bruto, para capturar as direções cardinais/diagonais puras
        self.player.velocity = {
            x = moveVector.x,
            y = moveVector.y
        }

        local distanceMovedInTiles = 0
        local magnitude = math.sqrt(moveVector.x * moveVector.x + moveVector.y * moveVector.y)
        if magnitude > 0 then
            local normalizedInputX = moveVector.x / magnitude
            local normalizedInputY = moveVector.y / magnitude

            -- Rotaciona o vetor de input em -45 graus para alinhar com o grid isométrico
            local angle = -math.pi / 4 -- -45 graus em radianos
            local cosAngle = math.cos(angle)
            local sinAngle = math.sin(angle)

            local rotatedX = normalizedInputX * cosAngle - normalizedInputY * sinAngle
            local rotatedY = normalizedInputX * sinAngle + normalizedInputY * cosAngle

            local moveAmount = moveSpeedInTiles * dt

            -- Atualiza a posição lógica usando o vetor rotacionado
            self.logicalPosition.tileX = self.logicalPosition.tileX + rotatedX * moveAmount
            self.logicalPosition.tileY = self.logicalPosition.tileY + rotatedY * moveAmount

            distanceMovedInTiles = moveAmount
        end

        -- Lida com o wrapping do mapa
        if self.mapManager then
            self.logicalPosition = self.mapManager:handleWrapping(self.logicalPosition)
        end

        -- Atualiza animação do sprite
        SpritePlayer.update(self.player, dt, targetPosition, moveSpeedInTiles)

        if self.playerManager.gameStatisticsManager then
            self.playerManager.gameStatisticsManager:registerMovement(distanceMovedInTiles)
        end

        return distanceMovedInTiles
    end

    return nil
end

--- Obtém a posição ATUAL do jogador (lógica, não em pixels)
---@return LogicalPosition
function MovementController:getPosition()
    return self.logicalPosition
end

--- Define a posição LÓGICA do jogador
---@param patchX number
---@param patchY number
---@param tileX number
---@param tileY number
function MovementController:setPosition(patchX, patchY, tileX, tileY)
    self.logicalPosition.patchX = patchX
    self.logicalPosition.patchY = patchY
    self.logicalPosition.tileX = tileX
    self.logicalPosition.tileY = tileY
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
