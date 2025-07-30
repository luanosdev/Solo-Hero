local BaseAttackController = require("src.scenes.gameplay.controllers.attacks.base_attack_controller")
local AttackAnimationSystem = require("src.utils.attack_animation_system")
local CombatGeometry = require("src.utils.combat_geometry")
local Constants = require("src.config.constants")
local TablePool = require("src.utils.table_pool")
local RenderPipeline = require("src.core.render_pipeline")

---@class ConeSlashController : BaseAttackController
---@description Controller para a habilidade de ataque Cone Slash.
---@description Herda de BaseAttackController e implementa a lógica específica
---@description de ataque em cone, retornando comandos para o PlayerManager.
---@field activeAnimations AnimationInstance[] Animações de ataque ativas.
---@field area table Área de efeito calculada e reutilizada.
---@field visual table Configurações visuais específicas do ataque.
---@field attackTexture love.Image A textura para o ataque.
local ConeSlashController = setmetatable({}, { __index = BaseAttackController })
ConeSlashController.__index = ConeSlashController

ConeSlashController.OFFSET_FOR_SPAWN = 10

-- Configurações da habilidade
ConeSlashController.CONFIG = {
    name = _T("attack_types.cone_slash.name"),
    description = _T("attack_types.cone_slash.description"),
    constants = {
        DELAY_STEP = 0.1,
    }
}

-- Configurações visuais, separadas para clareza
ConeSlashController.VISUAL_CONFIG = {
    preview = {
        active = false,
        lineLength = 50,
        color = { 1, 1, 1, 0.2 }
    },
    attack = {
        animationDuration = 0.15, -- Duração curta para um efeito de "flash"
        color = { 1, 1, 1, 1 }
    }
}

--- Cria uma nova instância do ConeSlashController.
---@param weaponInstance BaseWeapon
---@return ConeSlashController
function ConeSlashController:new(weaponInstance)
    ---@class ConeSlashController
    local o = BaseAttackController.new(self, weaponInstance, ConeSlashController.CONFIG)
    setmetatable(o, self)

    o.activeAnimations = {}
    o.area = {
        position = { x = 0, y = 0 },
        angle = 0,
        range = 0,
        angleWidth = 0,
        halfWidth = 0
    }
    o.visual = ConeSlashController.VISUAL_CONFIG

    -- Carregar a textura de ataque
    o.attackTexture = love.graphics.newImage("assets/effects/attacks/background_diagonal.png")
    o.attackTexture:setWrap("repeat", "repeat")

    -- Sobrescreve cores padrão com as da arma, se existirem
    if weaponInstance.previewColor then
        o.visual.preview.color = weaponInstance.previewColor
    end
    if weaponInstance.attackColor then
        o.visual.attack.color = weaponInstance.attackColor
    end

    return o
end

--- Calcula a área de efeito com base nos stats atuais.
---@param context AttackContext
function ConeSlashController:recalculateArea(context)
    local baseData = self.cachedBaseData
    local stats = context.finalStats

    -- Para o Cone Slash, o bônus de área é um multiplicador de 1.0
    local bonusAreaMultiplier = stats.area
    -- E o bônus de ângulo é um aditivo
    local bonusAngle = stats.angle or 0

    local newAngleWidth = (baseData.angle + bonusAngle) * bonusAreaMultiplier
    local newRange = Constants.metersToPixels(baseData.range) * stats.range

    if newRange ~= self.area.range or newAngleWidth ~= self.area.angleWidth then
        self.area.range = newRange
        self.area.angleWidth = newAngleWidth
        self.area.halfWidth = newAngleWidth * 0.5
    end
end

--- Calcula a posição de spawn do ataque.
---@param context AttackContext
---@return Vector2D
function ConeSlashController:calculateSpawnPosition(context)
    local spawnDistance = (context.playerRadius or 1) + ConeSlashController.OFFSET_FOR_SPAWN
    local spawnX = context.playerPosition.x + math.cos(context.playerAngle) * spawnDistance
    local spawnY = context.playerPosition.y + math.sin(context.playerAngle) * spawnDistance
    return { x = spawnX, y = spawnY }
end

--- Hook de update específico para o Cone Slash.
---@param dt number
---@param context AttackContext
function ConeSlashController:updateSpecific(dt, context)
    self:recalculateArea(context)

    self.area.angle = context.playerAngle
    local spawnPos = self:calculateSpawnPosition(context)
    self.area.position.x = spawnPos.x
    self.area.position.y = spawnPos.y

    AttackAnimationSystem.updateBatch(self.activeAnimations, dt)
end

---@protected Hook para gerar as descrições de ataque em cone.
---@description Descreve um ou mais ataques em cone para serem executados pelo orquestrador.
---@param context AttackContext
---@return AttackDescriptor[] descriptions Uma lista contendo um ou mais ConeAttackDescriptor.
function ConeSlashController:castSpecific(context)
    local totalAttacks = CombatGeometry.calculateMultiAttacks(context.finalStats.multiAttackChance)
    local delays = self:calculateAttackDelays(
        totalAttacks,
        ConeSlashController.CONFIG.constants.DELAY_STEP
    )

    local descriptors = TablePool.getArray()

    for i = 1, totalAttacks do
        -- A área já foi calculada e posicionada no updateSpecific
        ---@type ConeAttackDescriptor
        local coneDescriptor = {
            shape = "cone",
            origin = { x = self.area.position.x, y = self.area.position.y },
            angle = self.area.angle,
            range = self.area.range,
            halfWidth = self.area.halfWidth,
        }
        table.insert(descriptors, coneDescriptor)

        -- A lógica de animação visual é apenas para controlar o tempo de vida do efeito.
        local animationData = AttackAnimationSystem.createConeData(self.area, false)
        local animation = AttackAnimationSystem.createInstance(
            "cone_slash",
            self.visual.attack.animationDuration,
            delays[i],
            animationData
        )
        table.insert(self.activeAnimations, animation)
    end

    return descriptors
end

--- Hook para desenhar os efeitos do controller.
---@param renderPipeline RenderPipeline
---@param context AttackContext
function ConeSlashController:collectRenderables(renderPipeline, context)
    -- Lógica de desenho vai aqui, possivelmente adicionando a um batch no renderPipeline.
    -- Por enquanto, desenhamos diretamente.
    if self.visual.preview.active then
        self:drawConeOutlineOptimized()
    end

    for _, animation in ipairs(self.activeAnimations) do
        if animation.delay <= 0 then
            -- auto-captura da animação para a closure
            local capturedAnimation = animation

            local renderable = TablePool.getArray()
            renderable.type = "drawFunction"
            renderable.depth = RenderPipeline.DEPTH_EFFECTS_WORLD_UI
            -- Usamos a posição do jogador para o sort, garantindo que o efeito seja desenhado perto dele
            renderable.sortY = context.playerPosition.y
            renderable.drawFunction = function()
                self:drawTexturedCone(capturedAnimation)
            end
            renderPipeline:add(renderable)
        end
    end
end

--- Desenha o contorno da área de efeito para debug/preview.
function ConeSlashController:drawConeOutlineOptimized()
    if not self.area.range or self.area.range <= 0 then return end

    love.graphics.setColor(self.visual.preview.color)
    local cx, cy = self.area.position.x, self.area.position.y
    local range = self.area.range
    local halfWidth = self.area.halfWidth
    local startAngle = self.area.angle - halfWidth
    local endAngle = self.area.angle + halfWidth
    local segments = 32
    local angleStep = (endAngle - startAngle) / segments

    local vertices = { cx, cy }
    for i = 0, segments do
        local angle = startAngle + angleStep * i
        table.insert(vertices, cx + range * math.cos(angle))
        table.insert(vertices, cy + range * math.sin(angle))
    end
    table.insert(vertices, cx)
    table.insert(vertices, cy)

    love.graphics.line(unpack(vertices))
    love.graphics.setColor(1, 1, 1, 1)
end

--- Desenha o cone de ataque com uma textura.
---@param animation AnimationInstance
function ConeSlashController:drawTexturedCone(animation)
    local areaData = animation.data.area
    if not areaData or areaData.range <= 0 then return end

    local progress = animation.progress
    local alpha = 1.0 - progress -- Efeito de fade-out
    if alpha <= 0 then return end

    local cx, cy = areaData.position.x, areaData.position.y
    local range = areaData.range
    local startAngle = areaData.angle - areaData.halfWidth
    local endAngle = areaData.angle + areaData.halfWidth
    local segments = 32

    local vertices = {}
    -- Ponto de origem do cone (mapeado para o centro inferior da textura)
    table.insert(vertices, { cx, cy, 0.5, 1 })

    -- Pontos do arco
    local angleStep = (endAngle - startAngle) / segments
    for i = 0, segments do
        local currentAngle = startAngle + angleStep * i
        local vertX = cx + range * math.cos(currentAngle)
        local vertY = cy + range * math.sin(currentAngle)
        local u = i / segments -- U vai de 0 a 1 ao longo do arco
        local v = 0            -- V é fixo no topo da textura
        table.insert(vertices, { vertX, vertY, u, v })
    end

    -- Cria e desenha a malha
    local mesh = love.graphics.newMesh(vertices, "fan")
    mesh:setTexture(self.attackTexture)

    local color = self.visual.attack.color
    love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * alpha)
    love.graphics.draw(mesh)
    love.graphics.setColor(1, 1, 1, 1)
end

function ConeSlashController:destroy()
    -- Limpa a tabela de animações para que o GC possa coletar as instâncias.
    self.activeAnimations = {}
end

return ConeSlashController
