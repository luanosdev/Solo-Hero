local Colors = require("src.ui.colors")

---@class PotionFlasksDisplay
---@field x number Posição X
---@field y number Posição Y
---@field flasks PotionFlask[] Informações atuais dos frascos
---@field totalFlasks number Número total de frascos
---@field flaskImageEmpty love.Image Imagem do frasco vazio
---@field flaskImageFull love.Image Imagem do frasco cheio
---@field auraImage love.Image Imagem para a aura de carregamento
---@field glowImage love.Image Imagem para o brilho do frasco pronto
---@field flaskWidth number Largura de uma imagem de frasco
---@field flaskHeight number Largura de uma imagem de frasco
---@field spacing number Espaçamento entre os frascos
---@field animationTimer number Timer para as animações de pulsação
local PotionFlasksDisplay = {}
PotionFlasksDisplay.__index = PotionFlasksDisplay

PotionFlasksDisplay.SPACE_BETWEEN_FLASKS = ResolutionUtils.scaleSpacing(2)
PotionFlasksDisplay.FLASK_STATES = {
    EMPTY = "empty",
    FILLING = "filling",
    READY = "ready"
}

PotionFlasksDisplay.FLASK_SCALE = 0.2
PotionFlasksDisplay.FLASK_SCALE_GLOW = 0.3

---@class PotionFlasksDisplayConfig
---@field x? number Posição X
---@field y? number Posição Y
---@field flaskImageEmpty love.Image|nil Imagem do frasco vazio
---@field flaskImageFull love.Image|nil Imagem do frasco cheio
---@field auraImage love.Image|nil Imagem para a aura de carregamento
---@field glowImage love.Image|nil Imagem para o brilho do frasco pronto

---@public Cria uma nova instância do display de frascos
---@param config PotionFlasksDisplayConfig Configuração inicial
---@return PotionFlasksDisplay
function PotionFlasksDisplay:new(config)
    local instance = setmetatable({}, PotionFlasksDisplay)
    instance.x = config.x or 0
    instance.y = config.y or 0
    instance.flasks = {}
    instance.totalFlasks = 0

    -- Carrega as imagens
    instance.flaskImageEmpty = config.flaskImageEmpty
    instance.flaskImageFull = config.flaskImageFull
    instance.auraImage = config.auraImage
    instance.glowImage = config.glowImage

    assert(instance.flaskImageEmpty, "Imagem do frasco vazio não encontrada.")
    assert(instance.flaskImageFull, "Imagem do frasco cheio não encontrada.")
    assert(instance.auraImage, "Imagem da aura não encontrada.")
    assert(instance.glowImage, "Imagem do brilho não encontrada.")

    instance.flaskWidth = instance.flaskImageEmpty:getWidth()
    instance.flaskHeight = instance.flaskImageEmpty:getHeight()
    instance.spacing = PotionFlasksDisplay.SPACE_BETWEEN_FLASKS
    instance.animationTimer = 0

    return instance
end

---@public Atualiza o estado do componente (principalmente para animações)
---@param dt number Delta time
function PotionFlasksDisplay:update(dt)
    self.animationTimer = self.animationTimer + dt
end

---@public Define a posição do componente na tela
---@param x number Posição X
---@param y number Posição Y
function PotionFlasksDisplay:setPosition(x, y)
    self.x = x
    self.y = y
end

---@public Atualiza os dados dos frascos a serem exibidos.
---@param flasksData PotionFlask[] Tabela com o estado atual de todos os frascos.
function PotionFlasksDisplay:setFlasks(flasksData)
    self.flasks = flasksData or {}
    self.totalFlasks = #self.flasks
end

---@public Desenha o componente
function PotionFlasksDisplay:draw()
    if self.totalFlasks <= 0 then
        return
    end

    love.graphics.push()
    love.graphics.translate(self.x, self.y)

    for i = 1, self.totalFlasks do
        local flaskX = (i - 1) * (self.flaskWidth + self.spacing)
        local flaskInfo = self.flasks[i]

        if flaskInfo then
            self:_drawSingleFlask(flaskX, 0, flaskInfo)
        end
    end

    love.graphics.pop()
end

---@public Retorna as dimensões totais do componente
---@return number width Largura atual
---@return number height Altura atual
function PotionFlasksDisplay:getDimensions()
    local scaledWidth = self.flaskWidth * PotionFlasksDisplay.FLASK_SCALE
    local scaledHeight = self.flaskHeight * PotionFlasksDisplay.FLASK_SCALE
    local totalWidth = self.totalFlasks * scaledWidth + math.max(0, self.totalFlasks - 1) * self.spacing
    return totalWidth, scaledHeight
end

---@private Desenha um único frasco com base no seu estado
---@param x number Posição X do frasco
---@param y number Posição Y do frasco
---@param flaskInfo PotionFlask Informação do frasco
function PotionFlasksDisplay:_drawSingleFlask(x, y, flaskInfo)
    local flaskImage = self.flaskImageEmpty
    local state = PotionFlasksDisplay.FLASK_STATES.EMPTY

    if flaskInfo.isReady then
        flaskImage = self.flaskImageFull
        state = PotionFlasksDisplay.FLASK_STATES.READY
    elseif flaskInfo.progress > 0 then
        state = PotionFlasksDisplay.FLASK_STATES.FILLING
    end

    -- Calcula as dimensões e centro do frasco escalado
    local scaledFlaskWidth = self.flaskWidth * PotionFlasksDisplay.FLASK_SCALE
    local scaledFlaskHeight = self.flaskHeight * PotionFlasksDisplay.FLASK_SCALE
    local centerX = x + scaledFlaskWidth / 2
    local centerY = y + scaledFlaskHeight / 2

    -- Desenha a aura/brilho por trás
    local pulse = (math.sin(self.animationTimer * 4) + 1) / 2 -- Varia de 0 a 1
    local effectScale = PotionFlasksDisplay.FLASK_SCALE_GLOW + pulse * 0.15
    local effectAlpha = pulse * 0.8

    love.graphics.setColor(1, 1, 1, 1)

    if state == PotionFlasksDisplay.FLASK_STATES.READY then
        -- Desenha brilho vermelho pulsante
        love.graphics.setColor(Colors.red[1], Colors.red[2], Colors.red[3], effectAlpha)
        love.graphics.draw(
            self.glowImage,
            centerX,
            centerY,
            0,
            effectScale,
            effectScale,
            self.glowImage:getWidth() / 2,
            self.glowImage:getHeight() / 2
        )
    elseif state == PotionFlasksDisplay.FLASK_STATES.FILLING then
        -- Desenha aura cinza pulsante
        love.graphics.setColor(Colors.gray[1], Colors.gray[2], Colors.gray[3], effectAlpha)
        love.graphics.draw(
            self.auraImage,
            centerX,
            centerY,
            0,
            effectScale,
            effectScale,
            self.auraImage:getWidth() / 2,
            self.auraImage:getHeight() / 2
        )
    end

    -- Desenha a imagem do frasco por cima
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(flaskImage, x, y, 0, PotionFlasksDisplay.FLASK_SCALE, PotionFlasksDisplay.FLASK_SCALE)
end

return PotionFlasksDisplay
