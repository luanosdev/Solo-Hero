local Constants = require("src.config.constants")

---@class CombatHelpers
local CombatHelpers = {}

--- Aplica knockback a um inimigo alvo.
--- @param targetEnemy BaseEnemy O inimigo que sofrerá o knockback.
--- @param attackerPosition table Posição {x, y} da origem do ataque (jogador, centro do AoE).
--- @param attackKnockbackPower number O poder de knockback do ataque.
--- @param attackKnockbackForce number A força base de knockback do ataque.
--- @param playerStrength number A força atual do jogador.
--- @param knockbackDirectionOverride? {x: number, y: number} Vetor de direção normalizado opcional para o knockback (usado por projéteis).
--- @return boolean True se o knockback foi aplicado, false caso contrário.
function CombatHelpers.applyKnockback(
    targetEnemy,
    attackerPosition,
    attackKnockbackPower,
    attackKnockbackForce,
    playerStrength,
    knockbackDirectionOverride
)
    if not targetEnemy or not targetEnemy.isAlive or targetEnemy.isDying or not targetEnemy.knockbackResistance then
        return false
    end

    if not attackKnockbackPower or attackKnockbackPower <= 0 or targetEnemy.knockbackResistance <= 0 then
        return false
    end

    if attackKnockbackPower >= targetEnemy.knockbackResistance then
        local dirX, dirY = 0, 0

        if knockbackDirectionOverride and (knockbackDirectionOverride.x ~= 0 or knockbackDirectionOverride.y ~= 0) then
            -- Usa a direção fornecida (já deve estar normalizada)
            dirX = knockbackDirectionOverride.x
            dirY = knockbackDirectionOverride.y
        elseif attackerPosition then
            -- Calcula a direção do atacante para o alvo
            local dx = targetEnemy.position.x - attackerPosition.x
            local dy = targetEnemy.position.y - attackerPosition.y
            local distSq = dx * dx + dy * dy

            if distSq > 0 then
                local dist = math.sqrt(distSq)
                dirX = dx / dist
                dirY = dy / dist
            else
                -- Alvo e atacante na mesma posição, empurra em direção aleatória
                local randomAngle = math.random() * 2 * math.pi
                dirX = math.cos(randomAngle)
                dirY = math.sin(randomAngle)
            end
        else
            -- Não há direção de override nem posição do atacante, não pode aplicar knockback
            return false
        end

        -- Garante que playerStrength é um número
        local strength = playerStrength or 0
        local knockbackVelocityValue = (strength + attackKnockbackForce) / 1 -- Conforme a fórmula

        if knockbackVelocityValue > 0 then
            targetEnemy:applyKnockback(dirX, dirY, knockbackVelocityValue)
            return true
        end
    end

    return false
end

return CombatHelpers
