local Colors = require("src.ui.colors")
local RenderPipeline = require("src.core.render_pipeline")
local TablePool = require("src.utils.table_pool")

---@class DamageNumberManagerShowParams
---@field position Vector2D
---@field amount number
---@field isCritical boolean
---@field isSuperCritical? boolean

---@class DamageNumberManager
---@field activeAnimations table[]
---@field animationPool table[]
---@field spriteSheet love.Image
---@field quads table<string, love.Quad>
---@field renderPipeline RenderPipeline
---@field normalBatch love.SpriteBatch
---@field criticalBatch love.SpriteBatch
---@field superCriticalBatch love.SpriteBatch
---@field damageQueue DamageNumberManagerShowParams[]
local DamageNumberManager = {}
DamageNumberManager.__index = DamageNumberManager

-- Constantes de Animação
local STAY_DURATION = 0.1
local ANIMATION_DURATION = 0.3
local MOVE_UP_DISTANCE = 5
local SUPER_CRITICAL_MOVE_UP_DISTANCE = 10

-- Escalas
local INITIAL_SCALE_NORMAL = 0.4
local INITIAL_SCALE_CRITICAL = 0.8
local INITIAL_SCALE_SUPER_CRITICAL = 1.2
local END_SCALE_NORMAL = 0.8
local END_SCALE_CRITICAL = 1.2
local END_SCALE_SUPER_CRITICAL = 1.6

-- Configurações de efeitos especiais
local PULSE_FREQUENCY = 8
local PULSE_INTENSITY = 0.3

-- Larguras da fonte
local DIGIT_CELL_WIDTH = 24
local CHAR_WIDTH = 23
local DIGIT_HEIGHT = 30

---@param context GameplaySceneContext
---@return DamageNumberManager
function DamageNumberManager:new(context)
    local instance = setmetatable({}, DamageNumberManager)

    instance.renderPipeline = context.renderPipeline
    instance.activeAnimations = {}
    instance.animationPool = {}
    instance.quads = {}
    instance.spriteSheet = nil
    instance.normalBatch = nil
    instance.criticalBatch = nil
    instance.superCriticalBatch = nil
    instance.damageQueue = {}

    return instance
end

function DamageNumberManager:init()
    self.spriteSheet = love.graphics.newImage("assets/fonts/damage.png")
    local capacity = 500 -- Capacidade por batch
    self.normalBatch = love.graphics.newSpriteBatch(self.spriteSheet, capacity)
    self.criticalBatch = love.graphics.newSpriteBatch(self.spriteSheet, capacity)
    self.superCriticalBatch = love.graphics.newSpriteBatch(self.spriteSheet, capacity)

    local sheet_width, sheet_height = self.spriteSheet:getDimensions()

    local current_x = 0
    for i = 0, 9 do
        self.quads[tostring(i)] = love.graphics.newQuad(
            current_x,
            0,
            CHAR_WIDTH,
            sheet_height,
            sheet_width,
            sheet_height
        )
        current_x = current_x + DIGIT_CELL_WIDTH
    end

    self.quads["+"] = love.graphics.newQuad(
        current_x,
        0,
        CHAR_WIDTH,
        sheet_height,
        sheet_width,
        sheet_height
    )
end

--- Mostra um novo número de dano na tela.
---@param params DamageNumberManagerShowParams
function DamageNumberManager:show(params)
    local anim = self:getAnimationFromPool()
    self:initializeAnimation(anim, params)
    table.insert(self.activeAnimations, anim)
end

function DamageNumberManager:update(dt)
    -- Processa a fila de novos números de dano
    if #self.damageQueue > 0 then
        for _, params in ipairs(self.damageQueue) do
            self:show(params)
        end
        -- Limpa a fila, devolvendo os dados para o pool
        for i = #self.damageQueue, 1, -1 do
            local data = table.remove(self.damageQueue, i)
            TablePool.releaseGeneric(data)
        end
    end

    -- Atualiza as animações ativas
    for i = #self.activeAnimations, 1, -1 do
        local anim = self.activeAnimations[i]
        if not self:updateAnimation(anim, dt) then
            table.remove(self.activeAnimations, i)
            self:returnAnimationToPool(anim)
        end
    end
end

function DamageNumberManager:collectRenderables()
    if #self.activeAnimations == 0 then return end

    self.normalBatch:clear()
    self.criticalBatch:clear()
    self.superCriticalBatch:clear()

    for _, anim in ipairs(self.activeAnimations) do
        self:drawAnimationText(anim)
    end

    local function addBatchToPipeline(batch, color)
        if batch:getCount() > 0 then
            local renderable = TablePool.getGeneric()
            renderable.type = "drawFunction"
            renderable.depth = RenderPipeline.DEPTH_EFFECTS_WORLD_UI
            renderable.sortY = 99999
            renderable.drawFunction = function()
                local prev_r, prev_g, prev_b, prev_a = love.graphics.getColor()
                love.graphics.setColor(color)
                love.graphics.draw(batch, 0, 0)
                love.graphics.setColor(prev_r, prev_g, prev_b, prev_a)
            end

            self.renderPipeline:add(renderable)
        end
    end

    addBatchToPipeline(self.normalBatch, Colors.damage_number.normal)
    addBatchToPipeline(self.criticalBatch, Colors.damage_number.critical)
    addBatchToPipeline(self.superCriticalBatch, Colors.damage_number.super_critical)
end

function DamageNumberManager:destroy()
    self.activeAnimations = {}
    self.animationPool = {}
    if self.spriteSheet then
        self.spriteSheet:release()
        self.spriteSheet = nil
    end
    if self.normalBatch then self.normalBatch:release() end
    if self.criticalBatch then self.criticalBatch:release() end
    if self.superCriticalBatch then self.superCriticalBatch:release() end
end

-- Funções auxiliares de animação (não fazem parte da interface pública)

function DamageNumberManager:getAnimationFromPool()
    if #self.animationPool > 0 then
        return table.remove(self.animationPool)
    else
        return {}
    end
end

function DamageNumberManager:returnAnimationToPool(anim)
    table.insert(self.animationPool, anim)
end

---@param anim table
---@param params DamageNumberManagerShowParams
function DamageNumberManager:initializeAnimation(anim, params)
    anim.amount_str = tostring(math.floor(params.amount))
    anim.isCritical = params.isCritical
    anim.isSuperCritical = params.isSuperCritical or false
    anim.position = { x = params.position.x, y = params.position.y - 40 }
    anim.timer = 0
    anim.pulseTimer = 0
    anim.alpha = 1.0
    anim.phase = "stay"
    anim.active = true

    if anim.isSuperCritical then
        anim.scale = INITIAL_SCALE_SUPER_CRITICAL
        anim.moveUpDistance = SUPER_CRITICAL_MOVE_UP_DISTANCE
    elseif anim.isCritical then
        anim.scale = INITIAL_SCALE_CRITICAL
        anim.moveUpDistance = MOVE_UP_DISTANCE
    else
        anim.scale = INITIAL_SCALE_NORMAL
        anim.moveUpDistance = MOVE_UP_DISTANCE
    end

    local offsetX = (math.random() - 0.5) * 30
    local offsetY = (math.random() - 0.5) * 15
    anim.position.x = anim.position.x + offsetX
    anim.initialY = anim.position.y + offsetY
end

---@param anim table
---@param dt number
---@return boolean
function DamageNumberManager:updateAnimation(anim, dt)
    anim.timer = anim.timer + dt

    if anim.isSuperCritical then
        anim.pulseTimer = anim.pulseTimer + dt
    end

    if anim.phase == "stay" then
        if anim.timer >= STAY_DURATION then
            anim.phase = "animate"
            anim.timer = anim.timer - STAY_DURATION
        end
    end

    if anim.phase == "animate" then
        local progress = math.min(1, anim.timer / ANIMATION_DURATION)

        local startScale, endScale
        if anim.isSuperCritical then
            startScale = INITIAL_SCALE_SUPER_CRITICAL
            endScale = END_SCALE_SUPER_CRITICAL
        elseif anim.isCritical then
            startScale = INITIAL_SCALE_CRITICAL
            endScale = END_SCALE_CRITICAL
        else
            startScale = INITIAL_SCALE_NORMAL
            endScale = END_SCALE_NORMAL
        end

        anim.scale = startScale + (endScale - startScale) * progress

        if anim.isSuperCritical then
            local pulseOffset = math.sin(anim.pulseTimer * PULSE_FREQUENCY) * PULSE_INTENSITY
            anim.scale = anim.scale + (anim.scale * pulseOffset)
        end

        anim.alpha = 1.0 - progress
        anim.position.y = anim.initialY - (anim.moveUpDistance * progress)

        if progress >= 1 then
            anim.active = false
        end
    end

    return anim.active
end

---@param anim table
function DamageNumberManager:drawAnimationText(anim)
    local targetBatch
    if anim.isSuperCritical then
        targetBatch = self.superCriticalBatch
    elseif anim.isCritical then
        targetBatch = self.criticalBatch
    else
        targetBatch = self.normalBatch
    end

    local num_chars = #anim.amount_str
    local total_width = num_chars * DIGIT_CELL_WIDTH * anim.scale
    local current_x = anim.position.x - (total_width / 2)

    -- A cor e alpha são aplicados no batch inteiro, mas o alpha da animação ainda é útil para a lógica
    -- Aqui, poderiamos passar o alpha para o batch, mas a cor global já controla isso.
    -- O setColor no drawFunction de collectRenderables já vai usar o alpha da cor definida em colors.lua
    -- Se quisermos um fade-out individual, teríamos que usar love.math.colorToBytes, o que é mais complexo.
    -- Por simplicidade, vamos manter a cor do batch. O alpha na animação pode ser usado para um fade-out global no futuro se necessário.

    for i = 1, num_chars do
        local char = string.sub(anim.amount_str, i, i)
        local quad = self.quads[char]
        if quad then
            local _, _, w, h = quad:getViewport()
            local ox = w / 2
            local oy = h / 2
            local cell_center_x = current_x + (DIGIT_CELL_WIDTH * anim.scale / 2)

            targetBatch:add(
                quad,
                cell_center_x,
                anim.position.y,
                0,
                anim.scale,
                anim.scale,
                ox,
                oy
            )
        end
        current_x = current_x + DIGIT_CELL_WIDTH * anim.scale
    end
end

return DamageNumberManager
