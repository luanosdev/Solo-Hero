-------------------------------------------------------------------------
-- Controlador para gerenciar movimento do jogador.
-- Responsável por movimento, posição, velocidade e coordenação com animações.
-------------------------------------------------------------------------

local SpritePlayer = require('src.animations.sprite_player')
local Constants = require("src.config.constants")

---@class MovementController
---@field playerManager PlayerManager Referência ao PlayerManager
---@field inputManager InputManager Referência ao InputManager
---@field player PlayerSprite|nil Referência ao sprite do jogador
---@field radius number Raio de colisão do jogador
---@field mapManager InfinityWrapMapManager Referência ao gerenciador do mapa
---@field worldPosition Vector2D Posição no mundo em pixels.
---@field mapPixelWidth number Largura total do mapa em pixels.
---@field mapPixelHeight number Altura total do mapa em pixels.
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

    -- Calcula as dimensões do mapa em pixels para o wrapping
    if instance.mapManager then
        local totalWorldTiles = instance.mapManager.patchSize * instance.mapManager.tilesPerPatch

        local isoTopLeft = instance.mapManager:cartesianToIsometric(totalWorldTiles, 0)
        local isoBottomRight = instance.mapManager:cartesianToIsometric(0, totalWorldTiles)
        instance.mapPixelWidth = isoTopLeft.x - isoBottomRight.x
        instance.mapPixelHeight = instance.mapManager:cartesianToIsometric(totalWorldTiles, totalWorldTiles).y
    else
        instance.mapPixelWidth = 0
        instance.mapPixelHeight = 0
    end


    -- Posição inicial no mundo (em pixels)
    -- Começa no centro do mundo para dar espaço para o wrap em todas as direções.
    instance.worldPosition = {
        x = 0,
        y = 0,
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
        scale = 1,
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
        -- Mesmo parado, a animação do sprite (como idle) precisa ser atualizada
        if self.player and not self.player.animationPaused then
            SpritePlayer.update(self.player, dt, targetPosition, 0)
        end
        return nil
    end

    -- Atualiza o sprite do player apenas se a animação não estiver pausada
    if self.player and not self.player.animationPaused then
        -- Obtém a velocidade atual do jogador baseada nos stats finais
        local finalStats = self.playerManager:getCurrentFinalStats()
        local moveSpeedInPixels = Constants.moveSpeedToPixels(finalStats.moveSpeed)

        local moveVector = self.inputManager:getMovementVector()

        -- O vetor para animação é o input bruto, para capturar as direções cardinais/diagonais puras
        self.player.velocity = {
            x = moveVector.x,
            y = moveVector.y
        }

        local distanceMovedInPixels = 0
        local magnitude = math.sqrt(moveVector.x * moveVector.x + moveVector.y * moveVector.y)
        if magnitude > 0 then
            local normalizedInputX = moveVector.x / magnitude
            local normalizedInputY = moveVector.y / magnitude

            local moveAmount = moveSpeedInPixels * dt

            -- Atualiza as coordenadas do mundo em pixels
            self.worldPosition.x = self.worldPosition.x + normalizedInputX * moveAmount
            self.worldPosition.y = self.worldPosition.y + normalizedInputY * moveAmount

            -- Lida com o "wrapping" para manter o mundo infinito
            self:_handleWrapping()

            distanceMovedInPixels = moveAmount
        end

        -- Atualiza animação do sprite com os dados corretos
        SpritePlayer.update(self.player, dt, targetPosition, moveSpeedInPixels)

        if self.playerManager.gameStatisticsManager then
            self.playerManager.gameStatisticsManager:registerMovement(Constants.pixelsToMeters(distanceMovedInPixels))
        end

        return distanceMovedInPixels
    end

    return nil
end

--- Lida com o wrapping do jogador no mapa infinito, ajustando as coordenadas do mundo.
function MovementController:_handleWrapping()
    local wrapped = false
    local mapW = self.mapPixelWidth
    local mapH = self.mapPixelHeight
    local halfW = mapW / 2
    local halfH = mapH / 2

    if self.worldPosition.x > halfW then
        self.worldPosition.x = self.worldPosition.x - mapW
        wrapped = true
    elseif self.worldPosition.x < -halfW then
        self.worldPosition.x = self.worldPosition.x + mapW
        wrapped = true
    end

    if self.worldPosition.y > halfH then
        self.worldPosition.y = self.worldPosition.y - mapH
        wrapped = true
    elseif self.worldPosition.y < -halfH then
        self.worldPosition.y = self.worldPosition.y + mapH
        wrapped = true
    end

    if wrapped then
        EventManager:emit(EventManager.EVENTS.PLAYER_WRAPPED)
    end
end

--- Obtém a posição ATUAL do jogador no mundo (em pixels)
---@return Vector2D
function MovementController:getPosition()
    return self.worldPosition
end

--- Define a posição do jogador no MUNDO (em pixels)
---@param worldPosition Vector2D
function MovementController:setPosition(worldPosition)
    self.worldPosition = worldPosition
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
