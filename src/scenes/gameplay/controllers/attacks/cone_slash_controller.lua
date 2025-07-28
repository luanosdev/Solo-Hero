local BaseAttackController = require("src.scenes.gameplay.controllers.attacks.base_attack_controller")
local AttackAnimationSystem = require("src.utils.attack_animation_system")
local CombatGeometry = require("src.utils.combat_geometry")
local Constants = require("src.config.constants")
local TablePool = require("src.utils.table_pool")

---@class ConeSlashController : BaseAttackController
---@description Controller para a habilidade de ataque Cone Slash.
---@description Herda de BaseAttackController e implementa a lógica específica
---@description de ataque em cone, retornando comandos para o PlayerManager.
---@field activeAnimations AnimationInstance[] Animações de ataque ativas.
---@field area table Área de efeito calculada e reutilizada.
---@field visual table Configurações visuais específicas do ataque.
local ConeSlashController = setmetatable({}, { __index = BaseAttackController })
ConeSlashController.__index = ConeSlashController

ConeSlashController.OFFSET_FOR_SPAWN = 10

-- Configurações da habilidade
ConeSlashController.CONFIG = {
    name = _T("attack_types.cone_slash.name"),
    description = _T("attack_types.cone_slash.description"),
    constants = {
        DELAY_STEP = 0.1,
        SHELL_WIDTH_RATIO = 0.18,
        MIN_SHELL_WIDTH = 24
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
        animationDuration = 0.1,
        segments = 20,
        color = { 1, 1, 1, 0.8 }
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

    Logger.debug("ConeSlashController:recalculateArea", "stats: " .. Logger.dumpTable(stats, 2))

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

        -- A lógica de animação visual continua sendo responsabilidade do controller.
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
            self:drawConeFillOptimized(animation, context)
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

--- Desenha o preenchimento da animação de ataque.
---@param animation AnimationInstance
---@param context AttackContext
function ConeSlashController:drawConeFillOptimized(animation, context)
    local areaData = animation.data.area
    local progress = animation.progress
    if not areaData or progress < 0.01 then return end

    local fullRange = areaData.range
    local shellWidth = math.max(
        ConeSlashController.CONFIG.constants.MIN_SHELL_WIDTH,
        fullRange * ConeSlashController.CONFIG.constants.SHELL_WIDTH_RATIO
    )
    local shellInner, shellOuter, isValid = AttackAnimationSystem.calculateShellProgress(
        progress, context.playerRadius, fullRange, shellWidth
    )

    if not isValid then return end

    local cx, cy = areaData.position.x, areaData.position.y
    local startAngle = areaData.angle - areaData.halfWidth
    local endAngle = areaData.angle + areaData.halfWidth
    local segments = self.visual.attack.segments
    local angleStep = (endAngle - startAngle) / segments

    local vertices = TablePool.getArray()

    for i = 0, segments do
        local angle = startAngle + angleStep * i
        table.insert(vertices, cx + shellOuter * math.cos(angle))
        table.insert(vertices, cy + shellOuter * math.sin(angle))
    end

    for i = segments, 0, -1 do
        local angle = startAngle + angleStep * i
        table.insert(vertices, cx + shellInner * math.cos(angle))
        table.insert(vertices, cy + shellInner * math.sin(angle))
    end

    if #vertices >= 6 then
        local color = self.visual.attack.color
        love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1.0) * 0.6)
        love.graphics.polygon("fill", unpack(vertices))

        local baseFadeWidth = shellWidth * 0.35
        local fadeInner = shellInner
        local fadeOuter = math.min(shellOuter, shellInner + baseFadeWidth)

        if fadeOuter > fadeInner then
            local fadeVertices = TablePool.getArray()
            for i = 0, segments do
                local angle = startAngle + angleStep * i
                table.insert(fadeVertices, cx + fadeOuter * math.cos(angle))
                table.insert(fadeVertices, cy + fadeOuter * math.sin(angle))
            end
            for i = segments, 0, -1 do
                local angle = startAngle + angleStep * i
                table.insert(fadeVertices, cx + fadeInner * math.cos(angle))
                table.insert(fadeVertices, cy + fadeInner * math.sin(angle))
            end

            if #fadeVertices >= 6 then
                love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1.0) * 0.3)
                love.graphics.polygon("fill", unpack(fadeVertices))
            end
            TablePool.releaseArray(fadeVertices)
        end

        love.graphics.setColor(1, 1, 1, 0.7 * (1 - progress))
        love.graphics.setLineWidth(2)
        local borderVertices = TablePool.getArray()
        for i = 0, segments do
            local angle = startAngle + angleStep * i
            table.insert(borderVertices, cx + shellOuter * math.cos(angle))
            table.insert(borderVertices, cy + shellOuter * math.sin(angle))
        end
        love.graphics.line(unpack(borderVertices))
        love.graphics.setLineWidth(1)
        TablePool.releaseArray(borderVertices)

        love.graphics.setColor(1, 1, 1, 1)
    end
    TablePool.releaseArray(vertices)
end

function ConeSlashController:destroy()
    -- Limpa a tabela de animações para que o GC possa coletar as instâncias.
    self.activeAnimations = {}
end

return ConeSlashController
