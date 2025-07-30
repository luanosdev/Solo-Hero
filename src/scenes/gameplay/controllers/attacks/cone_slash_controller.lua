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
        halfWidth = 0,
        baseWidth = 0 -- Adicionado para a base do trapézio
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
        self.area.baseWidth = newRange / 6
    end
end

--- Calcula os vértices de um trapézio de ataque.
---@param area table A área de ataque com posição, ângulo, alcance, etc.
---@return Vector2D[] Uma lista de vértices para o trapézio.
function ConeSlashController:calculateTrapezoidVertices(area)
    local origin = area.position
    local angle = area.angle
    local range = area.range
    local halfAngleWidth = area.halfWidth
    local baseWidth = area.baseWidth

    local halfBaseWidth = baseWidth * 0.5
    local perpAngle = angle + (math.pi / 2)

    -- Vetor perpendicular à direção do ataque
    local perpVecX = math.cos(perpAngle)
    local perpVecY = math.sin(perpAngle)

    -- Vértices da base (perto do jogador)
    local p1 = { x = origin.x + perpVecX * halfBaseWidth, y = origin.y + perpVecY * halfBaseWidth }
    local p2 = { x = origin.x - perpVecX * halfBaseWidth, y = origin.y - perpVecY * halfBaseWidth }

    -- Para o lado distante, usamos o ângulo de abertura para calcular a largura
    -- A largura do arco a uma distância `range` é `2 * range * sin(halfAngleWidth)`
    local halfFarWidth = range * math.sin(halfAngleWidth)

    -- Centro do lado distante
    local farCenterX = origin.x + range * math.cos(angle)
    local farCenterY = origin.y + range * math.sin(angle)

    -- Vértices do lado distante
    local p3 = { x = farCenterX + perpVecX * halfFarWidth, y = farCenterY + perpVecY * halfFarWidth }
    local p4 = { x = farCenterX - perpVecX * halfFarWidth, y = farCenterY - perpVecY * halfFarWidth }

    -- Retorna os vértices em ordem para desenhar o polígono (ex: anti-horário)
    return { p2, p1, p3, p4 }
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
        local vertices = self:calculateTrapezoidVertices(self.area)

        ---@type PolygonAttackDescriptor
        local polygonDescriptor = {
            shape = "polygon",
            vertices = vertices,
            origin = self.area.position,
            range = self.area.range
        }
        table.insert(descriptors, polygonDescriptor)

        -- A lógica de animação visual é apenas para controlar o tempo de vida do efeito.
        -- Passamos os vértices para a animação para que o desenho seja consistente.
        local animationData = { area = self.area, vertices = vertices }
        local animation = AttackAnimationSystem.createInstance(
            "cone_slash_trapezoid",
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
    local vertices = self:calculateTrapezoidVertices(self.area)

    -- Desempacota os vértices para o formato que love.graphics.polygon espera
    local points = {}
    for _, v in ipairs(vertices) do
        table.insert(points, v.x)
        table.insert(points, v.y)
    end

    love.graphics.polygon("line", points)
    love.graphics.setColor(1, 1, 1, 1)
end

--- Desenha o cone de ataque com uma textura.
---@param animation AnimationInstance
function ConeSlashController:drawTexturedCone(animation)
    local vertices = animation.data.vertices
    if not vertices then return end

    local progress = animation.progress
    local alpha = 1.0 - progress -- Efeito de fade-out
    if alpha <= 0 then return end

    -- Mapeamento de UV para a textura
    -- p2 (base-esquerda) -> (0, 1)
    -- p1 (base-direita) -> (1, 1)
    -- p3 (longe-direita) -> (1, 0)
    -- p4 (longe-esquerda) -> (0, 0)
    local meshVertices = {
        { vertices[1].x, vertices[1].y, 0, 1 }, -- p2
        { vertices[2].x, vertices[2].y, 1, 1 }, -- p1
        { vertices[3].x, vertices[3].y, 1, 0 }, -- p3
        { vertices[4].x, vertices[4].y, 0, 0 }, -- p4
    }

    -- Cria e desenha a malha
    local mesh = love.graphics.newMesh(meshVertices, "fan")
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
