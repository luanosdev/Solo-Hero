---@class MathUtils
local MathUtils = {}

--- Retorna o comprimento de um vetor 2D (hipotenusa).
---@param x number Componente x do vetor.
---@param y number Componente y do vetor.
---@return number O comprimento do vetor.
function MathUtils.vectorLength(x, y)
    return math.sqrt(x * x + y * y)
end

--- Normaliza um vetor 2D para ter comprimento 1, mantendo sua direção.
--- Retorna (0, 0) se o vetor original tiver comprimento zero para evitar divisão por zero.
---@param x number Componente x do vetor.
---@param y number Componente y do vetor.
---@return number nx, number ny - Os componentes x e y do vetor normalizado.
function MathUtils.normalize(x, y)
    local lenSq = x * x + y * y
    if lenSq > 0 then
        local invLen = 1 / math.sqrt(lenSq)
        return x * invLen, y * invLen
    end
    return 0, 0
end

--- Calcula o vetor de deslocamento mais curto entre dois pontos em um espaço toroidal (que se repete).
--- Essencial para a IA de inimigos em mapas infinitos, garantindo que eles tomem o caminho mais curto
--- para o jogador, mesmo que isso signifique atravessar a "borda" do mapa.
---@param fromX number Posição X de origem.
---@param fromY number Posição Y de origem.
---@param toX number Posição X do alvo.
---@param toY number Posição Y do alvo.
---@param worldWidth number A largura total do mundo (em qualquer unidade, desde que consistente).
---@param worldHeight number A altura total do mundo (em qualquer unidade, desde que consistente).
---@return number dx_wrapped, number dy_wrapped - O vetor de deslocamento mais curto.
function MathUtils.calculateShortestTorusVector(fromX, fromY, toX, toY, worldWidth, worldHeight)
    -- Calcula o delta X
    local dx = toX - fromX
    local dx_wrapped = dx
    if math.abs(dx) > worldWidth / 2 then
        if dx > 0 then
            dx_wrapped = dx - worldWidth
        else
            dx_wrapped = dx + worldWidth
        end
    end

    -- Calcula o delta Y
    local dy = toY - fromY
    local dy_wrapped = dy
    if math.abs(dy) > worldHeight / 2 then
        if dy > 0 then
            dy_wrapped = dy - worldHeight
        else
            dy_wrapped = dy + worldHeight
        end
    end

    return dx_wrapped, dy_wrapped
end

--- Verifica se dois retângulos (AABB - Axis-Aligned Bounding Box) se intersectam.
--- Essa função é mais precisa que o culling por raio para objetos retangulares.
---@param rect1 {x: number, y: number, w: number, h: number} Primeiro retângulo (posição do centro + dimensões).
---@param rect2 {x: number, y: number, w: number, h: number} Segundo retângulo (posição do centro + dimensões).
---@return boolean true se os retângulos se intersectam, false caso contrário.
function MathUtils.rectangleIntersection(rect1, rect2)
    -- Converte posições do centro para cantos superiores esquerdos
    local r1x1 = rect1.x - rect1.w / 2
    local r1y1 = rect1.y - rect1.h / 2
    local r1x2 = rect1.x + rect1.w / 2
    local r1y2 = rect1.y + rect1.h / 2

    local r2x1 = rect2.x - rect2.w / 2
    local r2y1 = rect2.y - rect2.h / 2
    local r2x2 = rect2.x + rect2.w / 2
    local r2y2 = rect2.y + rect2.h / 2

    -- Verifica se há interseção
    return not (r1x2 < r2x1 or r2x2 < r1x1 or r1y2 < r2y1 or r2y2 < r1y1)
end

--- Verifica se dois retângulos (AABB) se intersectam em um mundo toroidal (infinito).
--- Esta versão é altamente otimizada: ela normaliza a posição do primeiro retângulo
--- para o "clone" mais próximo do segundo retângulo e então realiza um único teste de interseção.
---@param rect1 {x: number, y: number, w: number, h: number} O primeiro retângulo (entidade).
---@param rect2 {x: number, y: number, w: number, h: number} O segundo retângulo (câmera).
---@param worldW number A largura do mundo para o wrap-around.
---@param worldH number A altura do mundo para o wrap-around.
---@return boolean true se os retângulos se intersectam, false caso contrário.
function MathUtils.rectangleIntersectionToroidal(rect1, rect2, worldW, worldH)
    -- Calcula os limites da câmera (rect2) uma única vez
    local camLeft = rect2.x - rect2.w / 2
    local camRight = rect2.x + rect2.w / 2
    local camTop = rect2.y - rect2.h / 2
    local camBottom = rect2.y + rect2.h / 2

    -- Normaliza a posição central da entidade (rect1) para o clone mais próximo da câmera
    local entX = rect1.x
    while entX < camLeft - worldW / 2 do entX = entX + worldW end
    while entX > camRight + worldW / 2 do entX = entX - worldW end

    local entY = rect1.y
    while entY < camTop - worldH / 2 do entY = entY + worldH end
    while entY > camBottom + worldH / 2 do entY = entY - worldH end

    -- Calcula os limites da entidade com a posição normalizada
    local entLeft = entX - rect1.w / 2
    local entRight = entX + rect1.w / 2
    local entTop = entY - rect1.h / 2
    local entBottom = entY + rect1.h / 2

    -- Realiza um único teste AABB com as coordenadas normalizadas
    -- Retorna true se houver interseção, e false caso contrário.
    return not (entRight < camLeft or entLeft > camRight or entBottom < camTop or entTop > camBottom)
end

return MathUtils
