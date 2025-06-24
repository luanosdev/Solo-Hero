------------------------------------------------------------------------------------------------
-- Componente UI para Exibição dos Frascos de Poção
--
-- Mostra frascos de poção com progresso de preenchimento visual,
-- estado pronto/não pronto, e animações sutis.
------------------------------------------------------------------------------------------------

local fonts = require("src.ui.fonts")
local Colors = require("src.ui.colors")

---@class PotionFlasksDisplay
---@field x number Posição X
---@field y number Posição Y
---@field width number Largura total do componente
---@field height number Altura total do componente
---@field flaskWidth number Largura de cada frasco individual
---@field flaskHeight number Altura de cada frasco individual
---@field spacing number Espaçamento entre frascos
---@field animationTimer number Timer para animações
---@field lastReadyCount number Último número de frascos prontos (para detectar mudanças)
---@field readyFlashTimer number Timer para flash quando frasco fica pronto
local PotionFlasksDisplay = {}
PotionFlasksDisplay.__index = PotionFlasksDisplay

---@class PotionFlasksDisplayConfig
---@field x? number Posição X
---@field y? number Posição Y
---@field flaskWidth number Largura de cada frasco individual
---@field flaskHeight number Altura de cada frasco individual
---@field spacing number Espaçamento entre frascos

--- Cria uma nova instância do display de frascos
---@param config PotionFlasksDisplayConfig Configuração inicial
---@return PotionFlasksDisplay
function PotionFlasksDisplay:new(config)
    config = config or {}

    local instance = setmetatable({}, PotionFlasksDisplay)
    instance.x = config.x or 0
    instance.y = config.y or 0
    instance.flaskWidth = config.flaskWidth or 32
    instance.flaskHeight = config.flaskHeight or 48
    instance.spacing = config.spacing or 8
    instance.width = 0 -- Será calculado dinamicamente
    instance.height = instance.flaskHeight
    instance.animationTimer = 0
    instance.lastReadyCount = 0
    instance.readyFlashTimer = 0

    return instance
end

--- Define a posição do componente
---@param x number Nova posição X
---@param y number Nova posição Y
function PotionFlasksDisplay:setPosition(x, y)
    self.x = x
    self.y = y
end

--- Atualiza o componente
---@param dt number Delta time
---@param readyFlasks number Número de frascos prontos
---@param totalFlasks number Número total de frascos
---@param flasksInfo table Informações detalhadas de cada frasco
function PotionFlasksDisplay:update(dt, readyFlasks, totalFlasks, flasksInfo)
    self.animationTimer = self.animationTimer + dt

    -- Detecta quando um frasco fica pronto para fazer flash
    if readyFlasks > self.lastReadyCount then
        self.readyFlashTimer = 0.5 -- Flash por 0.5 segundos
    end
    self.lastReadyCount = readyFlasks

    if self.readyFlashTimer > 0 then
        self.readyFlashTimer = self.readyFlashTimer - dt
    end

    -- Calcula largura total baseada no número de frascos
    self.width = totalFlasks * self.flaskWidth + (totalFlasks - 1) * self.spacing
end

--- Desenha o componente
---@param readyFlasks number Número de frascos prontos
---@param totalFlasks number Número total de frascos
---@param flasksInfo PotionFlask[] Informações detalhadas de cada frasco
function PotionFlasksDisplay:draw(readyFlasks, totalFlasks, flasksInfo)
    if totalFlasks <= 0 then return end

    love.graphics.push()
    love.graphics.translate(self.x, self.y)

    -- Desenha cada frasco individualmente respeitando a fila
    for i = 1, totalFlasks do
        local flaskX = (i - 1) * (self.flaskWidth + self.spacing)
        local flaskInfo = flasksInfo[i] or { progress = 0, isReady = false }

        self:drawSingleFlask(flaskX, 0, flaskInfo, i)
    end

    love.graphics.pop()
end

--- Desenha um frasco individual
---@param x number Posição X do frasco
---@param y number Posição Y do frasco
---@param flaskInfo PotionFlask Informações do frasco
---@param flaskIndex number Índice do frasco (para animações individuais)
function PotionFlasksDisplay:drawSingleFlask(x, y, flaskInfo, flaskIndex)
    local progress = flaskInfo.progress or 0
    local isReady = flaskInfo.isReady or false

    -- Flash effect quando frasco fica pronto
    local flashIntensity = 0
    if self.readyFlashTimer > 0 and isReady then
        flashIntensity = math.sin(self.readyFlashTimer * 15) * 0.3 + 0.3
    end

    -- Desenha o contorno do frasco
    love.graphics.setLineWidth(2)
    if isReady then
        -- Verde quando pronto, com possível flash
        if flashIntensity > 0 then
            love.graphics.setColor(Colors.potion.flask_border_ready_flash)
        else
            love.graphics.setColor(Colors.potion.flask_border_ready)
        end
    else
        -- Cinza quando não pronto
        if progress > 0 then
            love.graphics.setColor(Colors.potion.flask_border_filling)
        else
            love.graphics.setColor(Colors.potion.flask_border_empty)
        end
    end

    -- Forma do frasco (retângulo arredondado simulando uma garrafa)
    local flaskBodyWidth = self.flaskWidth - 6
    local flaskBodyHeight = self.flaskHeight - 10
    local flaskBodyX = x + 3
    local flaskBodyY = y + 8

    -- Corpo do frasco
    love.graphics.rectangle("line", flaskBodyX, flaskBodyY, flaskBodyWidth, flaskBodyHeight, 4, 4)

    -- Gargalo do frasco
    local neckWidth = flaskBodyWidth * 0.3
    local neckHeight = 8
    local neckX = flaskBodyX + (flaskBodyWidth - neckWidth) / 2
    local neckY = y
    love.graphics.rectangle("line", neckX, neckY, neckWidth, neckHeight, 2, 2)

    -- Preenchimento do líquido
    if progress > 0 then
        local liquidHeight = (flaskBodyHeight - 4) * progress
        local liquidY = flaskBodyY + flaskBodyHeight - liquidHeight - 2

        if isReady then
            -- Líquido verde quando pronto
            if flashIntensity > 0 then
                love.graphics.setColor(Colors.potion.liquid_ready_flash)
            else
                love.graphics.setColor(Colors.potion.liquid_ready)
            end
        else
            -- Líquido vermelho gradual quando enchendo
            if progress < 0.5 then
                love.graphics.setColor(Colors.potion.liquid_healing)
            else
                love.graphics.setColor(Colors.potion.liquid_healing_bright)
            end
        end

        love.graphics.rectangle("fill", flaskBodyX + 2, liquidY, flaskBodyWidth - 4, liquidHeight, 2, 2)

        -- Efeito de brilho no líquido
        if isReady then
            love.graphics.setColor(Colors.potion.liquid_ready_glow)
            love.graphics.rectangle("fill", flaskBodyX + 2, liquidY, flaskBodyWidth - 4, 3, 2, 2)
        end
    end

    -- Efeito de sombra animada para frascos prontos (intercala opacidade simulando brilho)
    if isReady then
        local glowTime = self.animationTimer * 2 + (flaskIndex - 1) * 0.3 -- Offset por frasco
        local glowIntensity = (math.sin(glowTime) + 1) * 0.5              -- 0 a 1

        -- Sombra interna com opacidade variável
        local shadowOpacity = 0.3 + glowIntensity * 0.4
        love.graphics.setColor(Colors.potion.liquid_ready_glow[1],
            Colors.potion.liquid_ready_glow[2],
            Colors.potion.liquid_ready_glow[3],
            shadowOpacity)

        -- Desenha sombra cobrindo toda a área do líquido
        if progress > 0 then
            local liquidHeight = (flaskBodyHeight - 4) * progress
            local liquidY = flaskBodyY + flaskBodyHeight - liquidHeight - 2
            love.graphics.rectangle("fill", flaskBodyX + 2, liquidY, flaskBodyWidth - 4, liquidHeight, 2, 2)
        end
    end

    -- Ícone de "pronto" quando disponível (sem porcentagem)
    if isReady then
        love.graphics.setFont(fonts.main_small)
        love.graphics.setColor(Colors.potion.ready_icon)
        local readyText = "✓"
        local textWidth = fonts.main_small:getWidth(readyText)
        love.graphics.print(readyText, x + (self.flaskWidth - textWidth) / 2, y + self.flaskHeight / 2 - 4)
    end
end

--- Retorna as dimensões atuais do componente
---@return number width Largura atual
---@return number height Altura atual
function PotionFlasksDisplay:getDimensions()
    return self.width, self.height
end

return PotionFlasksDisplay
