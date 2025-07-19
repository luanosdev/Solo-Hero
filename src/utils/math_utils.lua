---@class MathUtils
local MathUtils = {}

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

    Logger.debug("math_utils.torus_check", string.format(
        "[TORUS_VECTOR_CHECK] From: (%.1f, %.1f) To: (%.1f, %.1f) World: (%d, %d) -> Result: (%.1f, %.1f)",
        fromX, fromY, toX, toY, worldWidth, worldHeight, dx_wrapped, dy_wrapped
    ))

    return dx_wrapped, dy_wrapped
end

return MathUtils
