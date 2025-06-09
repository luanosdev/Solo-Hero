--- Responsável por gerenciar e renderizar os números de dano flutuantes que aparecem nos inimigos.
--- Utiliza pooling para reutilizar objetos de animação.
local TablePool = require("src.utils.table_pool")
local RenderPipeline = require("src.core.render_pipeline")

---@class DamageNumberAnimation
---@field target BaseEnemy
---@field amount_str string
---@field isCritical boolean
---@field position { x: number, y: number }
---@field timer number
---@field alpha number
---@field scale number
---@field phase string
---@field active boolean
---@field offset { x: number, y: number }
---@field initialY number
local DamageNumberAnimation = {}
DamageNumberAnimation.__index = DamageNumberAnimation

-- Constantes de Animação
DamageNumberAnimation.STAY_DURATION = 0.5
DamageNumberAnimation.ANIMATION_DURATION = 0.7
DamageNumberAnimation.MOVE_UP_DISTANCE = 50
DamageNumberAnimation.INITIAL_SCALE_NORMAL = 0.4
DamageNumberAnimation.INITIAL_SCALE_CRITICAL = 0.8
DamageNumberAnimation.END_SCALE_NORMAL = 0.8
DamageNumberAnimation.END_SCALE_CRITICAL = 1.2
DamageNumberAnimation.CRITICAL_COLOR = { 255, 200, 0, 255 } -- Laranja/Dourado para crítico
DamageNumberAnimation.NORMAL_COLOR = { 255, 255, 255, 255 } -- Branco para normal

--- Cria uma nova instância de DamageNumberAnimation.
function DamageNumberAnimation:new()
    local anim = setmetatable({}, DamageNumberAnimation)
    return anim
end

--- Inicializa ou reseta o estado da animação.
---@param target BaseEnemy O alvo que recebeu o dano.
---@param amount number A quantidade de dano.
---@param isCritical boolean Se o dano foi crítico.
function DamageNumberAnimation:init(target, amount, isCritical)
    self.target = target
    self.amount_str = tostring(math.floor(amount))
    self.isCritical = isCritical
    self.position = { x = target.position.x, y = target.position.y - 40 }
    self.timer = 0
    self.alpha = 255 -- Usando 0-255 para consistência com cores
    self.scale = isCritical and self.INITIAL_SCALE_CRITICAL or self.INITIAL_SCALE_NORMAL
    self.color = isCritical and self.CRITICAL_COLOR or self.NORMAL_COLOR
    self.phase = "stay"
    self.active = true
    -- Adiciona um pequeno desvio para que os números não se sobreponham perfeitamente
    self.offset = { x = (math.random() - 0.5) * 30, y = (math.random() - 0.5) * 15 }
    self.position.x = self.position.x + self.offset.x
    self.position.y = self.position.y + self.offset.y
    self.initialY = self.position.y
end

--- Atualiza a lógica da animação.
---@param dt number Delta time.
---@return boolean Retorna false se a animação terminou.
function DamageNumberAnimation:update(dt)
    if not self.active then return false end

    self.timer = self.timer + dt

    if self.phase == "stay" then
        if self.timer >= self.STAY_DURATION then
            self.phase = "animate"
            self.timer = self.timer - self.STAY_DURATION
        end
    end

    if self.phase == "animate" then
        local progress = math.min(1, self.timer / self.ANIMATION_DURATION)
        local startScale = self.isCritical and self.INITIAL_SCALE_CRITICAL or self.INITIAL_SCALE_NORMAL
        local endScale = self.isCritical and self.END_SCALE_NORMAL or self.END_SCALE_NORMAL
        self.scale = startScale + (endScale - startScale) * progress
        self.alpha = 255 * (1.0 - progress)
        self.position.y = self.initialY - (self.MOVE_UP_DISTANCE * progress)

        if progress >= 1 then
            self.active = false
        end
    end

    return self.active
end

---@class DamageNumberManager
---@field activeAnimations DamageNumberAnimation[]
---@field animationPool DamageNumberAnimation[]
---@field spriteSheet love.Image | nil
---@field quads love.Quad[]
---@field isInitialized boolean
---@field renderPipeline RenderPipeline | nil
---@field DIGIT_CELL_WIDTH number -- Largura da célula de cada dígito (largura + espaço)
---@field CHAR_WIDTH number -- Largura real do caractere do dígito
---@field DIGIT_HEIGHT number
local DamageNumberManager = {
    activeAnimations = {},
    animationPool = {},
    spriteSheet = nil,
    quads = {},
    isInitialized = false,
    renderPipeline = nil,
    DIGIT_CELL_WIDTH = 24, -- Largura da célula (23px do caractere + 1px de espaço)
    CHAR_WIDTH = 23,       -- Largura real do caractere
    DIGIT_HEIGHT = 30,     -- Altura fixa para cada dígito
}

--- Inicializa o manager, carregando assets e preparando os quads.
---@param renderPipelineInstance RenderPipeline Instância do RenderPipeline para registrar.
function DamageNumberManager:init(renderPipelineInstance)
    if self.isInitialized then return end

    self.renderPipeline = renderPipelineInstance
    self.spriteSheet = love.graphics.newImage("assets/fonts/damage.png")
    local sheet_width, sheet_height = self.spriteSheet:getDimensions()

    -- Gera os quads para os dígitos com base no padrão: 23px de largura, 1px de espaço.
    self.quads = {}
    local current_x = 0
    for i = 0, 9 do
        self.quads[tostring(i)] = love.graphics.newQuad(current_x, 0, self.CHAR_WIDTH, sheet_height, sheet_width,
            sheet_height)
        current_x = current_x + self.DIGIT_CELL_WIDTH
    end

    print("DamageNumberManager inicializado.")
    self.isInitialized = true
end

--- Mostra um novo número de dano na tela.
---@param target BaseEnemy O alvo que recebeu o dano.
---@param amount number A quantidade de dano.
---@param isCritical boolean Se o dano foi crítico.
function DamageNumberManager:show(target, amount, isCritical)
    if not self.isInitialized then
        print("AVISO: DamageNumberManager:show chamado antes da inicialização.")
        return
    end

    local anim
    if #self.animationPool > 0 then
        anim = table.remove(self.animationPool)
    else
        anim = DamageNumberAnimation:new()
    end

    anim:init(target, amount, isCritical)
    table.insert(self.activeAnimations, anim)
end

--- Atualiza todas as animações de dano ativas.
---@param dt number Delta time.
function DamageNumberManager:update(dt)
    if not self.isInitialized then return end

    for i = #self.activeAnimations, 1, -1 do
        local anim = self.activeAnimations[i]
        if not anim:update(dt) then
            -- Animação terminou, retorna para o pool
            table.remove(self.activeAnimations, i)
            table.insert(self.animationPool, anim)
        end
    end
end

--- Adiciona os números de dano ao pipeline de renderização.
function DamageNumberManager:collectRenderables()
    if not self.renderPipeline or #self.activeAnimations == 0 then return end

    for _, anim in ipairs(self.activeAnimations) do
        -- Adicionado um nil-check para segurança, embora a correção em :update deva prevenir isso.
        if anim and anim.position then
            local renderable = TablePool.get()
            renderable.depth = RenderPipeline.DEPTH_EFFECTS_WORLD_UI
            renderable.sortY = anim.position.y + 1000 -- Garante que os números fiquem sobre tudo na mesma profundidade
            renderable.type = "drawFunction"

            -- A função de desenho captura as variáveis necessárias do escopo atual
            local sheet = self.spriteSheet
            local quads = self.quads
            local anim_instance = anim
            local digit_width = self.DIGIT_CELL_WIDTH
            local digit_height = self.DIGIT_HEIGHT

            renderable.drawFunction = function()
                -- Guarda a cor atual para restaurá-la depois
                local prev_r, prev_g, prev_b, prev_a = love.graphics.getColor()

                local num_digits = #anim_instance.amount_str
                local total_width = num_digits * digit_width * anim_instance.scale

                local current_x = anim_instance.position.x - (total_width / 2)
                local r, g, b = unpack(anim_instance.color)
                love.graphics.setColor(r / 255, g / 255, b / 255, anim_instance.alpha / 255)

                for i = 1, num_digits do
                    local digit = string.sub(anim_instance.amount_str, i, i)
                    local quad = quads[digit]
                    if quad then
                        local _, _, w, h = quad:getViewport()
                        local ox = w / 2
                        local oy = h / 2

                        -- Desenha o dígito centralizado em sua célula de largura fixa
                        local cell_center_x = current_x + (digit_width * anim_instance.scale / 2)

                        love.graphics.draw(sheet, quad,
                            cell_center_x,
                            anim_instance.position.y,
                            0, anim_instance.scale, anim_instance.scale, ox, oy)

                        -- Avança para a próxima posição de célula
                        current_x = current_x + digit_width * anim_instance.scale
                    end
                end

                -- Restaura a cor original para não afetar outros desenhos
                love.graphics.setColor(prev_r, prev_g, prev_b, prev_a)
            end

            self.renderPipeline:add(renderable)
        end
    end
end

function DamageNumberManager:destroy()
    self.activeAnimations = {}
    self.animationPool = {}
    if self.spriteSheet then
        self.spriteSheet:release()
        self.spriteSheet = nil
    end
    self.isInitialized = false
    self.renderPipeline = nil
    print("DamageNumberManager destruído.")
end

return DamageNumberManager
