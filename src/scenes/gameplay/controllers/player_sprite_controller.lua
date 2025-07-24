local SpritePlayer = require('src.animations.sprite_player')
local Constants = require("src.config.constants")
local RenderPipeline = require("src.core.render_pipeline")
local TablePool = require("src.utils.table_pool")

---@class PlayerSpriteController
---@description Gerencia a criação, atualização e renderização do sprite do jogador.
--- Este controller é o "dono" da instância do `SpritePlayer` e o conecta
--- com o resto dos sistemas (movimento, stats, equipamento).
---@field playerSprite SpritePlayer|nil A instância do sprite do jogador.
local PlayerSpriteController = {}
PlayerSpriteController.__index = PlayerSpriteController

---@return PlayerSpriteController
function PlayerSpriteController:new()
    local instance = setmetatable({}, PlayerSpriteController)
    instance.playerSprite = nil
    return instance
end

function PlayerSpriteController:init()
    -- Carrega os assets do sprite do jogador (operação idempotente)
    -- SpritePlayer.load() -- REMOVIDO
end

--- Cria a instância do sprite do jogador com base na aparência fornecida.
--- Chamado pelo PlayerManager durante a inicialização.
---@param appearance table A configuração de aparência do caçador.
function PlayerSpriteController:setupSprite(appearance)
    assert(appearance, "PlayerSpriteController:setupSprite requer uma tabela de 'appearance'")

    -- O sprite é criado na origem do mundo (0,0).
    -- A posição real será definida pelo MovementController.
    local spritePosition = {
        x = 0,
        y = 0
    }

    self.playerSprite = SpritePlayer.newConfig({
        position = spritePosition,
        scale = Constants.PLAYER_SCALE,
        appearance = appearance
    })

    self.playerSprite.velocity = { x = 0, y = 0 }

    Logger.info(
        "PlayerSpriteController:setupSprite",
        "Sprite do jogador criado com sucesso. Posição inicial: (" ..
        string.format("%.1f,%.1f", spritePosition.x, spritePosition.y) ..
        ") | Escala: " .. Constants.PLAYER_SCALE,
        true -- Mostra na tela
    )
end

--- Atualiza a animação e o estado do sprite.
---@param dt number
---@param moveSpeedInPixels number
---@param moveVector Vector2D
---@param position Vector2D Posição do jogador em coordenadas de mundo.
function PlayerSpriteController:update(dt, moveSpeedInPixels, moveVector, position)
    if not self.playerSprite then return end
    -- TODO: Adicionar checagem de dash e UI lock

    self.playerSprite.velocity = moveVector
    self.playerSprite.position = position

    -- Atualiza o sprite com a posição de mundo. A câmera cuidará da centralização.
    SpritePlayer.update(self.playerSprite, dt, position, moveSpeedInPixels)
end

--- Adiciona o sprite do jogador ao pipeline de renderização.
--- Este método cria um item renderizável com uma função de desenho,
--- seguindo o padrão da arquitetura antiga para desacoplar o sprite do pipeline.
---@param renderPipeline RenderPipeline
---@param worldPosition Vector2D A posição atual do jogador no mundo para o cálculo do sortY.
function PlayerSpriteController:collectRenderables(renderPipeline, worldPosition)
    if not self.playerSprite then
        Logger.warn("player_sprite_controller.collect",
            "[PlayerSpriteController] Tentou coletar, mas self.playerSprite é nil.")
        return
    end

    -- Calcula o sortY para a profundidade 2.5D
    local playerBaseY = worldPosition.y + 25 -- Pés do sprite
    local worldX_eq = worldPosition.x / Constants.TILE_WIDTH
    local worldY_eq = playerBaseY / Constants.TILE_HEIGHT
    local isoY_ref_top = (worldX_eq + worldY_eq) * (Constants.TILE_HEIGHT / 2)
    local sortY = isoY_ref_top + Constants.TILE_HEIGHT

    -- Cria o item renderizável
    local renderableItem = TablePool.getGeneric()
    renderableItem.type = "player"
    renderableItem.sortY = sortY
    renderableItem.depth = RenderPipeline.DEPTH_ENTITIES
    renderableItem.x = worldPosition.x
    renderableItem.y = worldPosition.y
    renderableItem.drawFunction = function()
        -- Aplica a translação para a posição de mundo antes de desenhar
        love.graphics.push()
        love.graphics.translate(worldPosition.x, worldPosition.y)
        SpritePlayer.draw(self.playerSprite)
        love.graphics.pop()
    end

    renderPipeline:add(renderableItem)
end

function PlayerSpriteController:destroy()
    self.playerSprite = nil
end

return PlayerSpriteController
