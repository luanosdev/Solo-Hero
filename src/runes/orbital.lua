--[[
    Orbital Rune
    Cria orbes que orbitam ao redor do jogador e causam dano aos inimigos próximos
]]

local BaseAbility = require("src.abilities.player._base_ability")
local OrbitalRune = setmetatable({}, { __index = BaseAbility })

OrbitalRune.name = "Orbes Orbitais"
OrbitalRune.description = "Cria orbes que orbitam ao redor do jogador e causam dano aos inimigos próximos"
OrbitalRune.damage = 15
OrbitalRune.damageType = "orbital"
OrbitalRune.color = {0, 0.8, 1, 0.3} -- Cor azul para os orbes

OrbitalRune.orbitRadius = 70 -- Raio da órbita
OrbitalRune.orbCount = 3 -- Número de orbes
OrbitalRune.orbRadius = 8 -- Tamanho de cada orbe
OrbitalRune.rotationSpeed = 2 -- Velocidade de rotação em radianos por segundo
OrbitalRune.shadowOffset = 3 -- Deslocamento da sombra
OrbitalRune.shadowAlpha = 0.2 -- Transparência da sombra

function OrbitalRune:init(playerManager)
    BaseAbility.init(self, playerManager)

    -- REMOVIDO: Cooldown compartilhado não é mais necessário para este objetivo
    -- self.sharedDamagedEnemies = {} 

    -- Estado dos orbes
    self.orbs = {}
    for i = 1, self.orbCount do
        table.insert(self.orbs, {
            angle = (i - 1) * (2 * math.pi / self.orbCount), -- Distribui os orbes igualmente
            damagedEnemies = {}, -- VOLTOU: Cooldown específico deste orbe para cada inimigo
            height = 0, 
            targetHeight = 0,
            pulseScale = 1,
            pulseSpeed = 2,
            lastDamageTime = 0, -- Tempo desde o último dano DESTE ORBE
            damageCooldown = 0.1, -- Cooldown GERAL do orbe após atingir QUALQUER inimigo (baixo)
            enemyCooldown = 0.5 -- Cooldown para ESTE ORBE atingir o MESMO inimigo novamente (curto)
        })
    end
end

function OrbitalRune:update(dt, enemies)
    BaseAbility.update(self, dt)

    -- REMOVIDO: Atualização do cooldown compartilhado
    
    -- Atualiza a posição dos orbes
    for i, orb in ipairs(self.orbs) do -- Usar i, orb pode ser útil para debug
        -- Atualiza o ângulo de rotação
        orb.angle = orb.angle + self.rotationSpeed * dt
        
        -- Atualiza a altura com suavização
        orb.height = orb.height + (orb.targetHeight - orb.height) * dt * 5
        
        -- Atualiza o pulso
        orb.pulseScale = 1 + math.sin(love.timer.getTime() * orb.pulseSpeed) * 0.1
        
        -- Atualiza o tempo desde o último dano GERAL deste orbe
        orb.lastDamageTime = orb.lastDamageTime + dt

        -- *** NOVO: Atualiza cooldowns específicos deste orbe para inimigos ***
        local enemiesToRemoveFromOrbCD = {}
        for enemyId, time in pairs(orb.damagedEnemies) do
            orb.damagedEnemies[enemyId] = time - dt
            if orb.damagedEnemies[enemyId] <= 0 then
                table.insert(enemiesToRemoveFromOrbCD, enemyId)
                -- print(string.format("Orb %d Cooldown expirado para inimigo ID: %d", i, enemyId)) -- Log Opcional
            end
        end
        for _, enemyId in ipairs(enemiesToRemoveFromOrbCD) do
            orb.damagedEnemies[enemyId] = nil
        end
        -- *** FIM NOVO ***
        
        -- Aplica dano
        self:applyOrbitalDamage(orb, i, dt, enemies) -- Passar 'i' para logs se necessário

        -- Atualiza o timer de reset da altura
        if orb.heightResetTimer and orb.heightResetTimer > 0 then
            orb.heightResetTimer = orb.heightResetTimer - dt
            if orb.heightResetTimer <= 0 then
                orb.targetHeight = 0
                orb.pulseScale = 1
                orb.heightResetTimer = nil
            end
        end
    end
end


function OrbitalRune:draw()
    -- Obtém a posição do jogador
    local playerX = self.playerManager.player.position.x
    local playerY = self.playerManager.player.position.y
    
    for _, orb in ipairs(self.orbs) do
        -- Calcula a posição do orbe em coordenadas do mundo
        local orbX = playerX + math.cos(orb.angle) * self.orbitRadius
        local orbY = playerY + math.sin(orb.angle) * self.orbitRadius
        
        -- Desenha a sombra
        love.graphics.setColor(0, 0, 0, self.shadowAlpha)
        love.graphics.circle("fill", 
            orbX + self.shadowOffset, 
            orbY + self.shadowOffset, 
            self.orbRadius * orb.pulseScale)
        
        -- Desenha o orbe base
        love.graphics.setColor(self.color)
        love.graphics.circle("fill", 
            orbX, 
            orbY - orb.height, 
            self.orbRadius * orb.pulseScale)
        
        -- Desenha o efeito de pulso
        local pulseRadius = self.orbRadius * 1.5 * orb.pulseScale
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.color[4] * 0.5)
        love.graphics.circle("line", 
            orbX, 
            orbY - orb.height, 
            pulseRadius)
        
        -- Desenha o efeito de brilho
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.circle("fill", 
            orbX, 
            orbY - orb.height, 
            self.orbRadius * 0.5 * orb.pulseScale)
    end
end

function OrbitalRune:applyOrbitalDamage(orb, orbIndex, dt, enemies) -- Adicionado orbIndex para debug
    if not enemies then return end
    
    -- 1. Verifica se ESTE ORBE pode causar dano (cooldown geral do orbe)
    if orb.lastDamageTime < orb.damageCooldown then return end
    
    -- Posições
    local playerX = self.playerManager.player.position.x
    local playerY = self.playerManager.player.position.y
    local orbX = playerX + math.cos(orb.angle) * self.orbitRadius
    local orbY = playerY + math.sin(orb.angle) * self.orbitRadius
    local damageRadius = self.orbRadius * 2

    -- *** CHAVE: Tabela temporária para inimigos atingidos NESTA PASSAGEM ESPECÍFICA ***
    local enemiesHitThisPass = {}
    local anEnemyWasHit = false -- Flag para resetar o cooldown geral do orbe UMA VEZ

    for _, enemy in ipairs(enemies) do
        if enemy.isAlive and enemy.id then
            local enemyId = enemy.id
            
            -- Distância
            local dx = enemy.position.x - orbX
            local dy = (enemy.position.y - orbY) * 0.5 -- Ajuste isométrico
            local distance = math.sqrt(dx * dx + dy * dy)
            
            -- Debug Log (opcional, mas recomendado para teste)
            print(string.format(
                "Orb %d (Angle %.2f) | Verificando Inimigo ID: %d em (%.1f, %.1f):\n" ..
                "Distância: %.1f\n" ..
                "Em cooldown (ESTE ORBE): %s (Restante: %.2f)\n" ..
                "Atingido (NESTA PASSAGEM): %s",
                orbIndex, orb.angle,
                enemyId,
                enemy.position.x, enemy.position.y,
                distance,
                orb.damagedEnemies[enemyId] and "Sim" or "Não",
                orb.damagedEnemies[enemyId] or 0,
                enemiesHitThisPass[enemyId] and "Sim" or "Não"
            ))
            
            -- Verifica colisão
            if distance <= damageRadius then
                -- *** VERIFICAÇÕES CRÍTICAS ***
                -- 1. O inimigo NÃO está no cooldown DESTE ORBE ESPECÍFICO?
                -- 2. O inimigo NÃO foi atingido NESTA PASSAGEM ESPECÍFICA por este orbe?
                if not orb.damagedEnemies[enemyId] and not enemiesHitThisPass[enemyId] then
                    
                    -- *** APLICA DANO E COOLDOWNS IMEDIATAMENTE ***
                    local died = self:applyDamage(enemy) -- Chama o dano, guarda se morreu

                    -- Marca como atingido NESTA PASSAGEM para evitar hits múltiplos instantâneos do *mesmo* orbe
                    enemiesHitThisPass[enemyId] = true 
                    
                    -- Marca o inimigo para o cooldown longo DESTE ORBE
                    orb.damagedEnemies[enemyId] = orb.enemyCooldown 

                    -- Marca que este orbe atingiu algo nesta verificação
                    anEnemyWasHit = true 

                    -- Efeitos visuais
                    orb.targetHeight = 5
                    orb.pulseScale = 1.2
                    orb.heightResetTimer = 0.2

                    -- Log Detalhado do Dano
                    print(string.format(
                        "DANO APLICADO! (por Orb %d)\n" ..
                        "Inimigo ID: %d (Vida restante após: %d)\n" .. -- Pega a vida atual
                        "Dano: %d\n" ..
                        "Novo cooldown (ESTE ORBE para ID %d): %.2f",
                        orbIndex, 
                        enemyId, enemy.currentHealth, -- Mostra a vida DEPOIS do hit
                        self.damage,
                        enemyId, orb.enemyCooldown
                    ))
                    
                    -- Opcional: Se um orbe só deve atingir UM único inimigo por passagem, descomente a linha abaixo.
                    -- Se ele pode atingir múltiplos inimigos DIFERENTES enquanto passa por um grupo, deixe comentado.
                    -- break 
                end
            end
        end
    end

    -- Se este orbe atingiu QUALQUER inimigo nesta passagem, reinicia seu cooldown geral.
    if anEnemyWasHit then
        orb.lastDamageTime = 0
        -- print(string.format("Orb %d reiniciou lastDamageTime.", orbIndex)) -- Log opcional
    end
end

return OrbitalRune 