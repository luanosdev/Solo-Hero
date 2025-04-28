-- src/ui/components/button.lua
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")

---@class Button
---@field rect table {x, y, w, h} O retângulo do botão.
---@field text string O texto exibido no botão.
---@field onClick function|nil A função callback chamada quando o botão é clicado.
---@field variant string Nome da variante de cor (ex: "default", "primary").
---@field colors table Tabela de cores ATUALMENTE usada, baseada na variant.
---@field font userdata A fonte usada para o texto.
---@field isHovering boolean Estado interno de hover.
---@field isPressed boolean Estado interno de pressionado (para feedback visual futuro).
---@field isEnabled boolean Se o botão está ativo e pode ser interagido.
local Button = {}
Button.__index = Button

--- Cria uma nova instância de Botão.
---@param config table Tabela de configuração contendo:
---@param rect table {x, y, w, h} - Obrigatório
---@param text string - Obrigatório
---@param variant string|nil - Opcional, nome da variante (ex: "primary", "secondary"). Usa "default" se nil.
---@param onClick function|nil - Opcional, callback para clique.
---@param font love.Font|nil - Opcional, usa fonts.main se não fornecido.
---@param enabled boolean|nil - Opcional, padrão é true.
---@return Button
function Button:new(config)
    if not config or not config.rect or not config.text then
        error("Button:new - Configuração inválida. 'rect' e 'text' são obrigatórios.", 2)
    end

    local instance = setmetatable({}, Button)
    instance.rect = config.rect
    instance.text = config.text
    instance.variant = config.variant or "default" -- Padrão para "default"
    instance.onClick = config.onClick
    instance.font = config.font or fonts.main
    instance.isHovering = false
    instance.isPressed = false
    instance.isEnabled = config.enabled ~= false -- Padrão true se não for explicitamente false

    -- Busca as cores baseadas na variante
    instance.colors = colors["button_" .. instance.variant] or colors.button_default
    if not instance.colors then
        print(string.format("AVISO (Button:new): Variante '%s' não encontrada. Usando fallback.", instance.variant))
        -- Fallback extremo se nem default existir
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

    -- Valida se as cores *necessárias* existem no conjunto selecionado
    if not instance.colors.bgColor or not instance.colors.hoverColor or not instance.colors.textColor or not instance.colors.pressedColor or not instance.colors.disabledBgColor then
        print(string.format("AVISO (Button:new): Conjunto de cores para '%s' incompleto.", instance.variant))
        -- Poderia tentar mesclar com default aqui para garantir que todas as chaves existam
    end

    return instance
end

--- Atualiza o estado do botão (principalmente hover).
---@param dt number Delta time (não usado atualmente).
---@param mx number Posição X do mouse.
---@param my number Posição Y do mouse.
---@param allowHover boolean Se o hover é permitido neste contexto (ex: modal ativo).
function Button:update(dt, mx, my, allowHover)
    if not self.isEnabled then
        self.isHovering = false
        self.isPressed = false -- Garante que não fique pressionado se desabilitado
        return
    end

    local wasHovering = self.isHovering
    if allowHover then
        self.isHovering = mx >= self.rect.x and mx < self.rect.x + self.rect.w and
            my >= self.rect.y and my < self.rect.y + self.rect.h
    else
        self.isHovering = false
    end

    -- Resetar isPressed se o mouse não estiver mais pressionando (botão 1)
    -- ou se o mouse sair da área do botão enquanto pressionado.
    if self.isPressed and (not love.mouse.isDown(1) or not self.isHovering) then
        self.isPressed = false
    end
end

--- Desenha o botão.
function Button:draw()
    -- Define as cores a serem usadas baseadas no estado (para drawButton saber qual usar)
    -- Nota: elements.drawButton só usa hoverColor vs bgColor por enquanto.
    -- Precisamos adaptar elements.drawButton para usar pressed/disabled ou fazer a lógica aqui.
    -- ADAPTANDO elements.drawButton é melhor para manter consistência.
    -- POR AGORA, vamos adaptar Button:draw para passar as cores certas para a elements.drawButton ATUAL

    local effectiveColors = {}
    if not self.isEnabled then
        effectiveColors.bgColor = self.colors.disabledBgColor or self.colors.bgColor
        effectiveColors.hoverColor = effectiveColors.bgColor -- Sem hover quando desabilitado
        effectiveColors.textColor = self.colors.disabledTextColor or self.colors.textColor
        effectiveColors.borderColor = self.colors.disabledBorderColor or self.colors.borderColor
    elseif self.isPressed then
        -- elements.drawButton não tem estado 'pressed', vamos simular usando bgColor
        effectiveColors.bgColor = self.colors.pressedColor or self.colors.bgColor
        effectiveColors.hoverColor = effectiveColors.bgColor -- Sem hover quando pressionado
        effectiveColors.textColor = self.colors.textColor
        effectiveColors.borderColor = self.colors.borderColor
    else                                                    -- Botão habilitado e não pressionado
        effectiveColors.bgColor = self.colors.bgColor
        effectiveColors.hoverColor = self.colors.hoverColor -- Cor de hover normal
        effectiveColors.textColor = self.colors.textColor
        effectiveColors.borderColor = self.colors.borderColor
    end

    elements.drawButton({
        rect = self.rect,
        text = self.text,
        isHovering = self.isHovering and self.isEnabled and not self.isPressed, -- Só tem hover visual se habilitado e não pressionado
        font = self.font,
        colors =
            effectiveColors -- Passa a tabela de cores efetivas para o estado atual
    })
end

--- Processa cliques do mouse.
---@param x number Posição X do clique.
---@param y number Posição Y do clique.
---@param button number Índice do botão do mouse (1 para esquerdo).
---@return boolean consumed True se o clique foi dentro deste botão e tratado.
function Button:handleMousePress(x, y, button)
    if not self.isEnabled or not self.isHovering then
        return false -- Não consome se desabilitado ou se o clique não começou aqui
    end

    if button == 1 then
        self.isPressed = true -- Marca como pressionado para feedback visual
        -- O onClick será chamado no mouseRelease para comportamento mais padrão
        return true           -- Consome o clique, pois foi no botão
    end

    return false
end

--- Processa o soltar do mouse (para disparar o onClick).
---@param x number Posição X do clique.
---@param y number Posição Y do clique.
---@param button number Índice do botão do mouse (1 para esquerdo).
---@return boolean consumed True se o release foi dentro deste botão e o onClick foi chamado.
function Button:handleMouseRelease(x, y, button)
    if not self.isEnabled or not self.isPressed then
        -- Reset isPressed just in case, even if disabled
        if button == 1 then self.isPressed = false end
        return false -- Não estava pressionado ou está desabilitado
    end

    local wasConsumed = false
    if button == 1 then
        local wasPressed = self.isPressed -- Guarda estado antes de resetar
        self.isPressed = false            -- Soltou o botão

        -- Verifica se o mouse AINDA está sobre o botão ao soltar
        local isStillHovering = x >= self.rect.x and x < self.rect.x + self.rect.w and
            y >= self.rect.y and y < self.rect.y + self.rect.h

        -- Só chama onClick se estava pressionado E soltou dentro do botão
        if wasPressed and isStillHovering and self.onClick then
            print(string.format("Button [%s]: onClick triggered.", self.text))
            self.onClick() -- Chama o callback
            wasConsumed = true
        else
            -- Não chama onClick se soltou fora ou não tinha callback
            print(string.format("Button [%s]: Released outside, no onClick, or was not pressed.", self.text))
        end
    end
    return wasConsumed
end

return Button
