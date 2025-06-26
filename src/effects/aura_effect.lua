-----------------------------------------------------------------------------
-- Efeito visual da Aura
-- Uma aura rotativa que aumenta a opacidade quando está prestes a causar dano
-----------------------------------------------------------------------------

local AssetManager = require("src.managers.asset_manager")
local TablePool = require("src.utils.table_pool")
local RenderPipeline = require("src.core.render_pipeline")

---@class AuraEffect
---@field position { x: number, y: number }
---@field image love.Image
---@field width number
---@field height number
---@field rotation number
---@field rotationSpeed number
---@field baseOpacity number
---@field currentOpacity number
---@field targetOpacity number
---@field opacityTransitionSpeed number
---@field scale number
---@field pulseEffect { active: boolean, intensity: number, timer: number, duration: number }
local AuraEffect = {}
AuraEffect.__index = AuraEffect

---@param position { x: number, y: number }
---@param config? { radius?: number, scale?: number, rotationSpeed?: number }
function AuraEffect:new(position, config)
    local instance = setmetatable({}, AuraEffect)

    config = config or {}

    instance.position = position

    -- Carrega a imagem da aura
    local image = AssetManager:getImage("assets/effects/aura.png")
    if not image then
        error("AuraEffect image not found: assets/effects/aura.png")
    end

    instance.image = image
    instance.width = instance.image:getWidth()
    instance.height = instance.image:getHeight()

    -- Configurações de rotação
    instance.rotation = 0
    instance.rotationSpeed = config.rotationSpeed or 0.5 -- radianos por segundo

    -- Configurações de opacidade
    instance.baseOpacity = 0.1 -- Opacidade baixa normal
    instance.currentOpacity = instance.baseOpacity
    instance.targetOpacity = instance.baseOpacity
    instance.opacityTransitionSpeed = 8.0 -- Velocidade de mudança de opacidade

    -- Calcula escala baseada no raio desejado vs tamanho da imagem
    if config.radius then
        -- Assume que a imagem representa um círculo e usa a maior dimensão como diâmetro
        local imageRadius = math.max(instance.width, instance.height) / 2
        instance.scale = config.radius / imageRadius

        Logger.debug(
            "aura_effect.new.scale_calculation",
            string.format("[AuraEffect:new] Raio desejado: %.1f, Raio da imagem: %.1f, Escala calculada: %.3f",
                config.radius, imageRadius, instance.scale)
        )
    else
        instance.scale = config.scale or 1.0
    end

    -- Efeito de pulso para quando o dano ocorre
    instance.pulseEffect = {
        active = false,
        intensity = 0.0,
        timer = 0.0,
        duration = 0.3 -- Duração do pulso em segundos
    }

    Logger.debug(
        "aura_effect.new.created",
        "[AuraEffect:new] Efeito de aura criado com opacidade base " .. instance.baseOpacity
    )

    return instance
end

function AuraEffect:update(dt)
    -- Atualiza rotação contínua
    self.rotation = self.rotation + self.rotationSpeed * dt
    if self.rotation > 2 * math.pi then
        self.rotation = self.rotation - 2 * math.pi
    end

    -- Transição suave de opacidade
    if math.abs(self.currentOpacity - self.targetOpacity) > 0.01 then
        local direction = self.targetOpacity > self.currentOpacity and 1 or -1
        self.currentOpacity = self.currentOpacity + direction * self.opacityTransitionSpeed * dt

        -- Clamp para evitar overshoot
        if direction > 0 and self.currentOpacity > self.targetOpacity then
            self.currentOpacity = self.targetOpacity
        elseif direction < 0 and self.currentOpacity < self.targetOpacity then
            self.currentOpacity = self.targetOpacity
        end
    end

    -- Atualiza efeito de pulso
    if self.pulseEffect.active then
        self.pulseEffect.timer = self.pulseEffect.timer + dt
        local progress = self.pulseEffect.timer / self.pulseEffect.duration

        if progress <= 1 then
            -- Curva de intensidade do pulso (sobe rápido, desce devagar)
            self.pulseEffect.intensity = math.sin(progress * math.pi) * 0.6
        else
            -- Termina o pulso
            self.pulseEffect.active = false
            self.pulseEffect.timer = 0
            self.pulseEffect.intensity = 0
        end
    end
end

--- Prepara a aura para causar dano (aumenta opacidade)
---@param timeUntilDamage number Tempo em segundos até o dano ocorrer
function AuraEffect:prepareDamage(timeUntilDamage)
    -- Aumenta gradativamente a opacidade baseado no tempo restante
    local intensity = math.max(0.3, 1.0 - (timeUntilDamage / 1.0)) -- Máximo de 1 segundo de preparação
    self.targetOpacity = self.baseOpacity + intensity * 0.7

    Logger.debug(
        "aura_effect.prepare_damage.opacity_change",
        string.format("[AuraEffect:prepareDamage] Preparando dano, opacidade alvo: %.2f", self.targetOpacity)
    )
end

--- Triggera o efeito de pulso quando o dano ocorre
function AuraEffect:triggerDamagePulse()
    self.pulseEffect.active = true
    self.pulseEffect.timer = 0
    self.targetOpacity = 0.9 -- Opacidade máxima no momento do dano

    Logger.debug(
        "aura_effect.trigger_pulse.damage_dealt",
        "[AuraEffect:triggerDamagePulse] Pulso de dano iniciado"
    )
end

--- Retorna a aura ao estado normal (opacidade baixa)
function AuraEffect:resetToNormal()
    self.targetOpacity = self.baseOpacity
end

---@param renderPipeline RenderPipeline
function AuraEffect:collectRenderables(renderPipeline)
    local item = TablePool.get()
    item.depth = RenderPipeline.DEPTH_EFFECTS_WORLD_UI
    item.type = "aura_effect"
    item.sortY = self.position.y
    item.drawFunction = function() self:draw() end
    renderPipeline:add(item)
end

function AuraEffect:draw()
    -- Calcula opacidade final com efeito de pulso
    local finalOpacity = math.min(1.0, self.currentOpacity + self.pulseEffect.intensity)

    -- Aplica cor com opacidade dinâmica
    love.graphics.setColor(
        1,
        1,
        1,
        finalOpacity
    )

    -- Calcula posição de desenho (centralizada)
    local drawX = self.position.x
    local drawY = self.position.y

    -- Desenha a aura rotacionada
    love.graphics.draw(
        self.image,
        drawX,
        drawY,
        self.rotation,
        self.scale,
        self.scale,
        self.width / 2, -- origem X (centro da imagem)
        self.height / 2 -- origem Y (centro da imagem)
    )

    -- Restaura cor padrão
    love.graphics.setColor(1, 1, 1, 1)
end

return AuraEffect
