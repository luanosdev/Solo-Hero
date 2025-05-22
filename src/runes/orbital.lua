--[[
    Orbital Rune
    Cria orbes que orbitam ao redor do jogador e causam dano aos inimigos próximos
]]

local RenderPipeline = require("src.render_pipeline")

local OrbitalRune = {}
OrbitalRune.__index = OrbitalRune -- Para permitir que instâncias herdem métodos

-- Propriedades padrão da classe
OrbitalRune.identifier = "rune_orbital"
OrbitalRune.defaultDepth = RenderPipeline.DEPTH_ENTITIES
OrbitalRune.defaultDamage = 100
OrbitalRune.defaultOrbitRadius = 90
OrbitalRune.defaultOrbCount = 3
OrbitalRune.defaultOrbRadius = 20
OrbitalRune.defaultRotationSpeed = 2       -- rad/s
OrbitalRune.defaultOrbDamageCooldown = 0.1 -- Cooldown GERAL do orbe após atingir QUALQUER inimigo
OrbitalRune.defaultEnemyCooldownPerOrb = 2 -- Cooldown para o MESMO ORBE atingir o MESMO inimigo

-- Configuração base da animação (compartilhada)
local baseAnimationConfig = {
    width = 67,
    height = 67,
    frameCount = 7,
    frameTime = 0.1,
    scale = 1, -- Será ajustado com base no orbRadius da instância
    frames = {},
    loaded = false
}

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Carrega os frames da animação globalmente (uma vez)
local function loadAnimationFrames()
    if not baseAnimationConfig.loaded then
        for i = 1, baseAnimationConfig.frameCount do
            local success, img = pcall(love.graphics.newImage, "assets/abilities/orbital/orbital_" .. i .. ".png")
            if success then
                baseAnimationConfig.frames[i] = img
            else
                print("ERRO ao carregar frame da animação orbital: assets/abilities/orbital/orbital_" .. i .. ".png")
            end
        end
        baseAnimationConfig.loaded = true
    end
end

--- Construtor para uma instância da habilidade Orbital.
--- @param playerManager PlayerManager Instância do gerenciador do jogador.
--- @param runeItemData table Dados da instância do item da runa.
--- @return table Instância da habilidade da runa.
function OrbitalRune:new(playerManager, runeItemData)
    loadAnimationFrames() -- Garante que as animações globais estão carregadas

    local instance = setmetatable({}, self)

    instance.playerManager = playerManager
    instance.runeItemData = runeItemData

    instance.name = runeItemData.name or "Orbes Orbitais (Instância)"
    instance.damage = runeItemData.damage or self.defaultDamage
    instance.orbitRadius = runeItemData.orbitRadius or self.defaultOrbitRadius
    instance.orbCount = runeItemData.orbCount or self.defaultOrbCount
    instance.orbRadius = runeItemData.orbRadius or self.defaultOrbRadius
    instance.rotationSpeed = runeItemData.rotationSpeed or self.defaultRotationSpeed
    instance.orbDamageCooldown = runeItemData.orb_damage_cooldown or self.defaultOrbDamageCooldown
    instance.enemyCooldownPerOrb = runeItemData.enemy_cooldown_per_orb or self.defaultEnemyCooldownPerOrb

    -- Configuração da animação para ESTA instância (copia a base, ajusta a escala)
    instance.animation = deepcopy(baseAnimationConfig)
    instance.animation.scale = instance.orbRadius / (baseAnimationConfig.width / 2) -- Ajusta escala ao raio do orbe
    instance.animation.currentFrame = 1
    instance.animation.timer = 0

    -- Estado dos orbes (específico da instância)
    instance.orbs = {}
    for i = 1, instance.orbCount do
        table.insert(instance.orbs, {
            angle = (i - 1) * (2 * math.pi / instance.orbCount),
            damagedEnemies = {},
            lastDamageTime = 0
        })
    end

    print(string.format("Instância de OrbitalRune criada: Dmg=%d, Count=%d, Radius=%.1f", instance.damage,
        instance.orbCount, instance.orbitRadius))
    return instance
end

function OrbitalRune:update(dt, enemies)
    self.animation.timer = self.animation.timer + dt
    if self.animation.timer >= self.animation.frameTime then
        self.animation.timer = self.animation.timer - self.animation.frameTime
        self.animation.currentFrame = self.animation.currentFrame + 1
        if self.animation.currentFrame > self.animation.frameCount then
            self.animation.currentFrame = 1
        end
    end

    for i, orb in ipairs(self.orbs) do
        orb.angle = orb.angle + self.rotationSpeed * dt
        orb.lastDamageTime = orb.lastDamageTime + dt

        local enemiesToRemoveFromOrbCD = {}
        for enemyId, time in pairs(orb.damagedEnemies) do
            orb.damagedEnemies[enemyId] = time - dt
            if orb.damagedEnemies[enemyId] <= 0 then
                table.insert(enemiesToRemoveFromOrbCD, enemyId)
            end
        end
        for _, enemyId in ipairs(enemiesToRemoveFromOrbCD) do
            orb.damagedEnemies[enemyId] = nil
        end

        self:applyOrbitalDamage(orb, i, dt, enemies)
    end
end

function OrbitalRune:draw()
    if not self.playerManager or not self.playerManager.player or not self.playerManager.player.position then return end

    local playerX = self.playerManager.player.position.x
    local playerY = self.playerManager.player.position.y + 25

    -- Usa os frames globais da baseAnimationConfig
    local frameToDraw = baseAnimationConfig.frames[self.animation.currentFrame]

    if not frameToDraw then return end -- Não desenha se o frame não estiver carregado

    for _, orb in ipairs(self.orbs) do
        local orbX = playerX + math.cos(orb.angle) * self.orbitRadius
        local orbY = playerY + math.sin(orb.angle) * self.orbitRadius

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            frameToDraw, -- Frame global
            orbX,
            orbY,
            0,
            self.animation.scale, -- Escala da instância
            self.animation.scale,
            frameToDraw:getWidth() / 2,
            frameToDraw:getHeight() / 2
        )
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Cast para runas orbitais geralmente não faz nada, elas são passivas.
function OrbitalRune:cast()
    return true
end

-- Função auxiliar para aplicar dano a um único alvo.
function OrbitalRune:applyDamageToTarget(target) -- Renomeado para clareza
    if not target then return false end

    if target.takeDamage then
        return target:takeDamage(self.damage)
    elseif target.receiveDamage then
        target:receiveDamage(self.damage, "orbital")
        return true
    else
        print("AVISO [OrbitalRune:applyDamageToTarget]: Alvo inválido ou sem método de dano.")
    end
    return false
end

function OrbitalRune:applyOrbitalDamage(orb, orbIndex, dt, enemies)
    if not enemies or not self.playerManager or not self.playerManager.player or not self.playerManager.player.position then return end

    if orb.lastDamageTime < self.orbDamageCooldown then return end

    local playerPos = self.playerManager.player.position
    local orbScreenX = playerPos.x + math.cos(orb.angle) * self.orbitRadius
    local orbScreenY = playerPos.y + 25 + math.sin(orb.angle) * self.orbitRadius -- Ajuste de Y para pés do player

    -- O raio de dano é o raio visual do orbe
    local damageRadius = self.orbRadius

    local anEnemyWasHitThisOrb = false

    for _, enemy in ipairs(enemies) do
        if enemy.isAlive and enemy.id and enemy.position then
            local enemyId = enemy.id

            local dx = enemy.position.x - orbScreenX
            local dy = (enemy:getCollisionPosition().position.y) - orbScreenY -- Compara com base do inimigo
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance <= (damageRadius + (enemy.radius or 10)) then -- Colisão círculo-círculo simples
                if not orb.damagedEnemies[enemyId] then
                    local died = self:applyDamageToTarget(enemy)
                    orb.damagedEnemies[enemyId] = self.enemyCooldownPerOrb
                    anEnemyWasHitThisOrb = true
                    -- Não precisa de `enemiesHitThisPass` se o cooldown geral do orbe for curto
                    -- e o cooldown por inimigo for mais longo.
                    -- Se um orbe atinge um inimigo, ele entra em cooldown para ESSE inimigo.
                    -- E o orbe em si entra em um cooldown geral muito curto para evitar hits múltiplos no mesmo frame.
                end
            end
        end
    end

    if anEnemyWasHitThisOrb then
        orb.lastDamageTime = 0 -- Reseta o cooldown geral DESTE orbe
    end
end

return OrbitalRune
