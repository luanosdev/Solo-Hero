-- src/ui/components/button.lua
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local Component = require("src.ui.components.Component")

---@class Button : Component
---@field text string O texto exibido no botão.
---@field onClick function|nil A função callback chamada quando o botão é clicado.
---@field variant string Nome da variante de cor (ex: "default", "primary").
---@field colors table Tabela de cores ATUALMENTE usada, baseada na variant.
---@field font userdata A fonte usada para o texto.
---@field isHovering boolean Estado interno de hover.
---@field isPressed boolean Estado interno de pressionado (para feedback visual futuro).
---@field isEnabled boolean Se o botão está ativo e pode ser interagido.
local Button = setmetatable({}, { __index = Component })
Button.__index = Button

--- Cria uma nova instância de Botão.
---@param config table Tabela de configuração contendo:
---@return Button
function Button:new(config)
    if not config or not config.rect or not config.text then
        error("Button:new - Configuração inválida. 'rect' e 'text' são obrigatórios.", 2)
    end
    -- Chama construtor base (já inicializa rect, needsLayout, debug)
    local instance = Component:new(config)
    setmetatable(instance, Button)

    instance.text = config.text
    instance.variant = config.variant or "default"
    instance.onClick = config.onClick
    instance.font = config.font or fonts.main
    instance.isHovering = false
    instance.isPressed = false
    instance.isEnabled = config.enabled ~= false

    instance.colors = colors["button_" .. instance.variant] or colors.button_default
    if not instance.colors then
        print(string.format("AVISO (Button:new): Variante '%s' não encontrada. Usando fallback.", instance.variant))
        instance.colors = {
            bgColor = { 0.3, 0.3, 0.3 },
            hoverColor = { 0.4, 0.4, 0.4 },
            pressedColor = { 0.2, 0.2, 0.2 },
            textColor = { 1, 1, 1 },
            borderColor = { 0.5, 0.5, 0.5 },
            disabledBgColor = { 0.2, 0.2, 0.2, 0.7 },
            disabledTextColor = { 0.5, 0.5, 0.5, 0.8 },
            disabledBorderColor = { 0.3, 0.3, 0.3, 0.7 }
        }
    end
    if not instance.colors.bgColor or not instance.colors.hoverColor or not instance.colors.textColor or not instance.colors.pressedColor or not instance.colors.disabledBgColor then
        print(string.format("AVISO (Button:new): Conjunto de cores para '%s' incompleto.", instance.variant))
    end

    -- Botões simples geralmente não precisam de recálculo de layout interno
    instance.needsLayout = false

    return instance
end

--- Atualiza o estado do botão (hover, pressed).
--- Sobrescreve Component:update.
---@param dt number Delta time (não usado atualmente).
---@param mx number Posição X do mouse.
---@param my number Posição Y do mouse.
---@param allowHover boolean Se o hover é permitido neste contexto (ex: modal ativo).
function Button:update(dt, mx, my, allowHover)
    if not self.isEnabled then
        self.isHovering = false
        self.isPressed = false
        return
    end

    local wasHovering = self.isHovering
    if allowHover then
        self.isHovering = mx >= self.rect.x and mx < self.rect.x + self.rect.w and
            my >= self.rect.y and my < self.rect.y + self.rect.h
    else
        self.isHovering = false
    end

    if self.isPressed and (not love.mouse.isDown(1) or not self.isHovering) then
        self.isPressed = false
    end
end

--- Desenha o botão.
--- Sobrescreve Component:draw.
function Button:draw()
    local effectiveColors = {}
    if not self.isEnabled then
        effectiveColors.bgColor = self.colors.disabledBgColor or self.colors.bgColor
        effectiveColors.hoverColor = effectiveColors.bgColor
        effectiveColors.textColor = self.colors.disabledTextColor or self.colors.textColor
        effectiveColors.borderColor = self.colors.disabledBorderColor or self.colors.borderColor
    elseif self.isPressed then
        effectiveColors.bgColor = self.colors.pressedColor or self.colors.bgColor
        effectiveColors.hoverColor = effectiveColors.bgColor
        effectiveColors.textColor = self.colors.textColor
        effectiveColors.borderColor = self.colors.borderColor
    else
        effectiveColors.bgColor = self.colors.bgColor
        effectiveColors.hoverColor = self.colors.hoverColor
        effectiveColors.textColor = self.colors.textColor
        effectiveColors.borderColor = self.colors.borderColor
    end

    elements.drawButton({
        rect = self.rect,
        text = self.text,
        isHovering = self.isHovering and self.isEnabled and not self.isPressed,
        font = self.font,
        colors = effectiveColors
    })

    -- Chama o draw base para desenhar o debug se necessário
    Component.draw(self)
end

--- Processa cliques do mouse.
--- Sobrescreve Component:handleMousePress.
---@param x number Posição X do clique.
---@param y number Posição Y do clique.
---@param button number Índice do botão do mouse (1 para esquerdo).
---@return boolean consumed True se o clique foi dentro deste botão e tratado.
function Button:handleMousePress(x, y, button)
    if not self.isEnabled or not self.isHovering then return false end
    if button == 1 then
        self.isPressed = true
        return true -- Consome o clique
    end
    return false
end

--- Processa o soltar do mouse.
--- Sobrescreve Component:handleMouseRelease.
---@param x number Posição X do clique.
---@param y number Posição Y do clique.
---@param button number Índice do botão do mouse (1 para esquerdo).
---@return boolean consumed True se o release foi dentro deste botão e o onClick foi chamado.
function Button:handleMouseRelease(x, y, button)
    if not self.isEnabled then
        if button == 1 then self.isPressed = false end -- Garante reset mesmo desabilitado
        return false
    end

    -- Só trata o release se o botão ESTAVA pressionado
    if not self.isPressed then return false end

    local wasConsumed = false
    if button == 1 then
        local wasPressed = self.isPressed
        self.isPressed = false

        local isStillHovering = x >= self.rect.x and x < self.rect.x + self.rect.w and
            y >= self.rect.y and y < self.rect.y + self.rect.h

        if wasPressed and isStillHovering and self.onClick then
            print(string.format("Button [%s]: onClick triggered.", self.text))
            self.onClick()
            wasConsumed = true
        else
            print(string.format("Button [%s]: Released outside, no onClick, or was not pressed.", self.text))
        end
    end
    return wasConsumed
end

return Button
