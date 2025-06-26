local BaseProjectile = require("src.entities.projectiles.base_projectile")
local TablePool = require("src.utils.table_pool")
local CombatHelpers = require("src.utils.combat_helpers")

-- Carrega a imagem da flecha uma vez
local arrowImage = love.graphics.newImage("assets/attacks/arrow/arrow.png")
-- Pega as dimensões da imagem para usar como origem (centro)
local imgWidth = arrowImage:getWidth()   -- Espessura da imagem original
local imgHeight = arrowImage:getHeight() -- Comprimento da imagem original
local originX = imgWidth / 2
local originY = imgHeight / 2

-- Calcula a escala base para que a altura (comprimento da flecha) seja ~60 pixels
local baseDesiredLength = 30
local baseScale = baseDesiredLength / imgHeight

-- Define um raio de colisão base para a ponta da flecha.
-- Este valor será escalado pelo areaScale.
-- Por exemplo, pode ser metade da espessura base da flecha ou um valor ajustado para gameplay.
local baseCollisionRadiusAtTip = (imgWidth * baseScale) / 2 -- Metade da espessura visual base

---@class Arrow : BaseProjectile
---@field maxRange number Alcance máximo da flecha.
---@field distanceTraveled number Distância percorrida pela flecha.
---@field currentPiercing number Quantidade de inimigos que a flecha ainda pode perfurar.
---@field visualScale number Escala visual final da flecha, afetada pela área.
---@field collisionRadiusAtTip number Raio de colisão final na ponta da flecha.
---@field tipOffsetFromCenter number Distância do centro da imagem da flecha até sua ponta.
---@field playerManager PlayerManager
---@field weaponInstance BaseWeapon
local Arrow = setmetatable({}, { __index = BaseProjectile })
Arrow.__index = Arrow

--- Cria uma nova instância de Flecha.
---@param params table Tabela de parâmetros.
function Arrow:new(params)
    -- Define o custo de durabilidade por acerto para esta classe.
    -- Custo alto: 0.51 permite 2 acertos (1 / 0.51 ≈ 1.96).
    params.hitCost = params.hitCost or 0.51

    local instance = setmetatable({}, Arrow)
    instance:reset(params)
    return instance
end

--- Reseta uma instância de Flecha existente para reutilização (pooling).
---@param params table Tabela de parâmetros.
function Arrow:reset(params)
    -- Chama o reset da classe base
    BaseProjectile.reset(self, params)

    -- Propriedades específicas da Flecha
    self.maxRange = params.range or 100
    self.currentPiercing = params.piercing or 1
    local currentAreaScale = params.areaScale or 1

    self.distanceTraveled = 0

    self.visualScale = baseScale * currentAreaScale
    -- O raio de colisão na ponta é o raio base escalado pela areaScale
    self.collisionRadiusAtTip = baseCollisionRadiusAtTip * currentAreaScale

    -- A distância do centro da imagem da flecha até sua ponta.
    self.tipOffsetFromCenter = (imgHeight / 2) * self.visualScale
end

--- Lida com o tempo de vida do projétil, consumindo durabilidade com base na distância.
function Arrow:_updateLifetime(dt, moveX, moveY)
    if self.maxRange <= 0 then return end

    local distanceTraveledInFrame = math.sqrt(moveX ^ 2 + moveY ^ 2)
    local durabilityCost = distanceTraveledInFrame / self.maxRange

    self.durability = self.durability - durabilityCost
    if self.durability <= 0 then
        self.isActive = false
    end
end

--- Retorna a área de busca para a consulta no grid espacial.
function Arrow:_getSearchBounds()
    -- O searchRadius para o spatialGrid ainda pode ser baseado no tamanho geral da flecha
    -- para encontrar candidatos. O comprimento visual da flecha é imgHeight * self.visualScale.
    local visualLength = imgHeight * self.visualScale
    local visualWidth = imgWidth * self.visualScale
    local searchRadius = math.max(visualLength, visualWidth) * 0.75 -- Um pouco mais que a metade da maior dimensão

    -- A busca é centrada na posição do projétil, não na ponta, para abranger todo o corpo
    return { x = self.position.x, y = self.position.y, radius = searchRadius }
end

--- Retorna a geometria de colisão deste projétil (a ponta da flecha).
function Arrow:_getCollisionCircle()
    local tipX = self.position.x + math.cos(self.angle) * self.tipOffsetFromCenter
    local tipY = self.position.y + math.sin(self.angle) * self.tipOffsetFromCenter
    return { x = tipX, y = tipY, radius = self.collisionRadiusAtTip }
end

--- Sobrescreve a direção do knockback para se originar da ponta da flecha se ela estiver parada.
function Arrow:_getKnockbackDirection(enemy)
    if self.speed > 0 then
        -- Se estiver em movimento, usa a direção da velocidade (comportamento padrão)
        return BaseProjectile._getKnockbackDirection(self, enemy)
    end

    -- Se a flecha está parada, calcula direção da ponta para o inimigo
    local tipX = self.position.x + math.cos(self.angle) * self.tipOffsetFromCenter
    local tipY = self.position.y + math.sin(self.angle) * self.tipOffsetFromCenter
    local dx = enemy.position.x - tipX
    local dy = enemy.position.y - tipY
    local distSq = dx * dx + dy * dy
    if distSq > 0 then
        local dist = math.sqrt(distSq)
        return { x = dx / dist, y = dy / dist }
    end

    -- Fallback para o comportamento base se estiverem sobrepostos
    return BaseProjectile._getKnockbackDirection(self, enemy)
end

--- Lida com a lógica pós-acerto (perfuração).
function Arrow:_onHit(enemy)
    self.currentPiercing = self.currentPiercing - 1
    if self.currentPiercing < 0 then
        self.isActive = false
    end
end

function Arrow:draw()
    if not self.isActive then return end

    -- Desenha a durabilidade restante como um contorno que diminui
    local outlineAlpha = self.durability
    local outlineColor = { self.color[1], self.color[2], self.color[3], outlineAlpha }
    local outlineThickness = 1
    local mainColor = { 1, 1, 1, 1 }

    love.graphics.push()
    love.graphics.translate(self.position.x, self.position.y)
    love.graphics.rotate(self.angle + math.pi / 2) -- Imagem da flecha aponta para cima, +pi/2 para alinhar com ângulo 0 = direita

    -- Desenha a borda com base na durabilidade
    if outlineAlpha > 0 then
        love.graphics.setColor(outlineColor)
        local offsets = {
            { outlineThickness, 0 }, { -outlineThickness, 0 },
            { 0,                outlineThickness }, { 0, -outlineThickness }
        }
        for _, offset in ipairs(offsets) do
            love.graphics.draw(arrowImage, offset[1] / self.visualScale, offset[2] / self.visualScale, 0,
                self.visualScale,
                self.visualScale, originX, originY)
        end
    end

    -- Desenha a imagem principal
    love.graphics.setColor(mainColor)
    love.graphics.draw(arrowImage, 0, 0, 0, self.visualScale, self.visualScale, originX, originY)

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)

    -- DEBUG: Desenha o círculo de colisão da ponta
    if self.isActive and DEBUG_SHOW_PARTICLE_COLLISION_RADIUS then
        local tipX_debug = self.position.x + math.cos(self.angle) * self.tipOffsetFromCenter
        local tipY_debug = self.position.y + math.sin(self.angle) * self.tipOffsetFromCenter
        love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.circle("fill", tipX_debug, tipY_debug, self.collisionRadiusAtTip)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return Arrow
