---------------------------------------------------------------------------
-- Componente visual para exibir o estado e o cooldown do dash do jogador.
-- Usa um spritesheet para mostrar se uma carga de dash está disponível ou
-- o progresso da recarga da próxima carga.
---------------------------------------------------------------------------

---@class DashCooldownIndicator
---@field image love.Image
---@field quads table
---@field frameWidth number
---@field frameHeight number
---@field currentFrame number
---@field shouldDraw boolean
---@field scale number
local DashCooldownIndicator = {}
DashCooldownIndicator.__index = DashCooldownIndicator
DashCooldownIndicator.IMAGE_SCALE = 0.05

---Cria uma nova instância do indicador de cooldown de dash.
---@return DashCooldownIndicator
function DashCooldownIndicator:new(config)
    local instance = setmetatable({}, DashCooldownIndicator)

    instance.image = love.graphics.newImage('assets/effects/lightmeter.png')
    instance.quads = {}
    local imgWidth = instance.image:getWidth()
    local imgHeight = instance.image:getHeight()
    instance.frameWidth = imgWidth / 4
    instance.frameHeight = imgHeight / 2
    instance.currentFrame = 1
    instance.shouldDraw = false

    -- O spritesheet tem 4x2, mas o último frame (8) é ignorado.
    local frameCount = 0
    for row = 0, 1 do
        for col = 0, 3 do
            frameCount = frameCount + 1
            if frameCount <= 7 then
                instance.quads[frameCount] = love.graphics.newQuad(
                    col * instance.frameWidth,
                    row * instance.frameHeight,
                    instance.frameWidth,
                    instance.frameHeight,
                    imgWidth,
                    imgHeight
                )
            end
        end
    end

    return instance
end

---Atualiza o estado do indicador com base nos dados do dash.
---@param availableCharges number O número de cargas de dash prontas.
---@param totalCharges number O número total de cargas de dash.
---@param cooldownProgress number O progresso (0-1) da recarga da próxima carga.
function DashCooldownIndicator:update(availableCharges, totalCharges, cooldownProgress)
    if totalCharges <= 0 then
        self.shouldDraw = false
        return
    end
    self.shouldDraw = true

    if availableCharges > 0 then
        -- Se há qualquer carga disponível, mostra o ícone de "cheio".
        self.currentFrame = 1
    else
        -- Se não há cargas, mostra o progresso da recarga.
        -- O progresso é mapeado para os frames 7 (vazio) a 2 (quase cheio).
        -- Progresso 0.0 -> frame 7. Progresso ~0.99 -> frame 2.
        local frameIndex = 7 - math.floor(cooldownProgress * 6)
        self.currentFrame = math.max(2, math.min(7, frameIndex))
    end
end

---Desenha o indicador na tela, posicionado abaixo do jogador.
---@param playerScreenX number Posição X do jogador na tela.
---@param playerScreenY number Posição Y do jogador na tela.
function DashCooldownIndicator:draw(playerScreenX, playerScreenY)
    if not self.shouldDraw then return end

    local quad = self.quads[self.currentFrame]
    if quad then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.draw(
            self.image,
            quad,
            playerScreenX - (self.frameWidth * self.IMAGE_SCALE) / 2,
            playerScreenY + 40,
            0,
            self.IMAGE_SCALE,
            self.IMAGE_SCALE
        )
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return DashCooldownIndicator
