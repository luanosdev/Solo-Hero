--------------------------------------------------------------------------------
-- Bullet Projectile
-- Um projétil simples, circular, usado por armas como escopetas.
--------------------------------------------------------------------------------

local BaseProjectile = require("src.entities.projectiles.base_projectile")

local bulletImage = love.graphics.newImage("assets/attacks/bullet/bullet.png")
local imageWidth = bulletImage:getWidth()
local imageHeight = bulletImage:getHeight()

-- Raio base do projétil antes de qualquer escala de área.
local BASE_RADIUS = 6

---@class Bullet : BaseProjectile
---@field radius number Raio visual e de colisão do projétil.
---@field maxRange number O alcance máximo que o projétil pode viajar.
local Bullet = setmetatable({}, { __index = BaseProjectile })
Bullet.__index = Bullet

--- Cria uma nova instância de Bullet.
---@param params table Tabela de parâmetros, veja BaseProjectile:new e as propriedades de Bullet.
---@return Bullet
function Bullet:new(params)
    -- Define o custo de durabilidade por acerto para esta classe.
    -- Custo médio: 0.34 permite 3 acertos (1 / 0.34 ≈ 2.94).
    params.hitCost = params.hitCost or 0.34

    local instance = setmetatable({}, Bullet)
    instance:reset(params)
    return instance
end

--- Reseta um Bullet para reutilização (pooling).
---@param params table Tabela de parâmetros.
function Bullet:reset(params)
    -- Chama o reset da classe base
    BaseProjectile.reset(self, params)

    -- Propriedades específicas do Bullet
    self.maxRange = params.range or 100
    self.radius = BASE_RADIUS * (params.areaScale or 1)
end

--- Lida com o tempo de vida do projétil, consumindo durabilidade com base na distância.
function Bullet:_updateLifetime(dt, moveX, moveY)
    if self.maxRange <= 0 then return end -- Evita divisão por zero se o alcance for 0

    local distanceTraveledInFrame = math.sqrt(moveX ^ 2 + moveY ^ 2)
    local durabilityCost = distanceTraveledInFrame / self.maxRange

    self.durability = self.durability - durabilityCost
    if self.durability <= 0 then
        self.isActive = false
    end
end

--- Retorna a área de busca para a consulta no grid espacial.
function Bullet:_getSearchBounds()
    return { x = self.position.x, y = self.position.y, radius = self.radius }
end

--- Retorna a geometria de colisão deste projétil.
function Bullet:_getCollisionCircle()
    return { x = self.position.x, y = self.position.y, radius = self.radius }
end

--- Desenha o projétil na tela.
function Bullet:draw()
    if not self.isActive then return end
    love.graphics.setColor(self.color)
    local scale = (self.radius * 2) / imageWidth
    love.graphics.draw(
        bulletImage,
        self.position.x,
        self.position.y,
        self.angle,
        scale,
        scale,
        imageWidth / 2,
        imageHeight / 2
    )
end

return Bullet
