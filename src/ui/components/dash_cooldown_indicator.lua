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
---@field chargeFrames table
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
    instance.chargeFrames = {}

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
---@param cooldownProgresses table O progresso (0-1) de cada carga em recarga.
function DashCooldownIndicator:update(availableCharges, totalCharges, cooldownProgresses)
    if totalCharges <= 0 then
        self.shouldDraw = false
        return
    end
    self.shouldDraw = true
    cooldownProgresses = cooldownProgresses or {}

    -- Limpa os frames anteriores
    for i = #self.chargeFrames, 1, -1 do
        table.remove(self.chargeFrames, i)
    end

    -- Adiciona um frame "cheio" para cada carga disponível
    for i = 1, availableCharges do
        table.insert(self.chargeFrames, 1)
    end

    -- Adiciona um frame de recarga para cada carga em cooldown
    for _, progress in ipairs(cooldownProgresses) do
        local frameIndex = 7 - math.floor(progress * 6)
        local frame = math.max(2, math.min(7, frameIndex))
        table.insert(self.chargeFrames, frame)
    end

    -- Adiciona frames vazios se o total de cargas não for atingido
    -- (Isso pode acontecer se totalCharges for > available + em cooldown)
    local drawnCharges = #self.chargeFrames
    for i = drawnCharges + 1, totalCharges do
        table.insert(self.chargeFrames, 7) -- Frame 7 é "vazio"
    end
end

---Desenha o indicador na tela, posicionado abaixo do jogador.
---@param playerScreenX number Posição X do jogador na tela.
---@param playerScreenY number Posição Y do jogador na tela.
function DashCooldownIndicator:draw(playerScreenX, playerScreenY)
    if not self.shouldDraw or #self.chargeFrames == 0 then return end

    -- Calcula a largura total de todos os indicadores para centralizar o grupo
    local totalWidth = #self.chargeFrames * (self.frameWidth * self.IMAGE_SCALE)
    local startX = playerScreenX - totalWidth / 2

    for i, frameNumber in ipairs(self.chargeFrames) do
        local quad = self.quads[frameNumber]
        if quad then
            -- Calcula a posição X de cada indicador individualmente
            local offsetX = startX + (i - 1) * (self.frameWidth * self.IMAGE_SCALE)
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.draw(
                self.image,
                quad,
                offsetX,
                playerScreenY + 40,
                0,
                self.IMAGE_SCALE,
                self.IMAGE_SCALE
            )
        end
    end
    -- Reseta a cor uma vez no final
    love.graphics.setColor(1, 1, 1, 1)
end

return DashCooldownIndicator
