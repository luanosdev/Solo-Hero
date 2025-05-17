--[[
    Runa do Trovão
    Faz raios caírem em inimigos aleatórios periodicamente
]]

local ThunderRune = {}
ThunderRune.__index = ThunderRune -- Para permitir que instâncias herdem métodos

-- Propriedades que podem ser consideradas "default" ou "static" para a classe
ThunderRune.defaultDamage = 200
ThunderRune.defaultCooldown = 2.0
ThunderRune.defaultRangeMultiplier = 0.6 -- Multiplicador da dimensão da tela para o alcance

local baseAnimationConfig = {
    width = 128,
    height = 128,
    frameCount = 22,
    frameTime = 0.02,
    scale = 1,
    frames = {},   -- Cache global para frames da animação
    loaded = false -- Flag para carregar frames apenas uma vez
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
            local success, img = pcall(love.graphics.newImage, "assets/abilities/thunder/spell_bluetop_1_" .. i .. ".png")
            if success then
                baseAnimationConfig.frames[i] = img
            else
                print("ERRO ao carregar frame da animação do trovão: assets/abilities/thunder/spell_bluetop_1_" ..
                    i .. ".png")
            end
        end
        baseAnimationConfig.loaded = true
    end
end

--- Construtor para uma instância da habilidade da Runa do Trovão
--- @param playerManager PlayerManager Instância do gerenciador do jogador.
--- @param runeItemData table Dados da instância do item da runa.
--- @return table Instância da habilidade da runa.
function ThunderRune:new(playerManager, runeItemData)
    loadAnimationFrames()                   -- Garante que as animações estão carregadas

    local instance = setmetatable({}, self) -- Cria nova instância herdando de ThunderRune

    instance.playerManager = playerManager
    instance.runeItemData = runeItemData

    -- Usa dados do item da runa, com fallback para os defaults da classe
    instance.name = runeItemData.name or "Runa do Trovão (Instância)"
    instance.damage = runeItemData.damage or self.defaultDamage
    instance.cooldown = runeItemData.interval or self.defaultCooldown -- 'interval' em runes.lua
    instance.range = (runeItemData.radius or (math.max(love.graphics.getWidth(), love.graphics.getHeight()) * self.defaultRangeMultiplier))

    instance.currentCooldown = instance.cooldown -- Começa no cooldown para não disparar imediatamente

    -- Cada instância tem sua própria animação e raios ativos
    -- É importante copiar a tabela de animação para que cada instância tenha seu próprio timer e currentFrame
    instance.animation = deepcopy(baseAnimationConfig)
    -- Os frames em si (baseAnimationConfig.frames) são compartilhados (são userdata Image)
    instance.animation.currentFrame = 1 -- Reseta para a instância
    instance.animation.timer = 0        -- Reseta para a instância

    instance.activeBolts = {}

    print(string.format("Instância de ThunderRune criada: Dmg=%d, CD=%.2f, Range=%.1f", instance.damage,
        instance.cooldown, instance.range))
    return instance
end

function ThunderRune:update(dt, enemies)
    self.currentCooldown = self.currentCooldown - dt

    for i = #self.activeBolts, 1, -1 do
        local bolt = self.activeBolts[i]
        bolt.timer = bolt.timer + dt

        bolt.animation.timer = bolt.animation.timer + dt
        if bolt.animation.timer >= self.animation.frameTime then -- Usa self.animation para config base
            bolt.animation.timer = bolt.animation.timer - self.animation.frameTime
            bolt.animation.currentFrame = bolt.animation.currentFrame + 1
            if bolt.animation.currentFrame > self.animation.frameCount then
                -- Bolt animation finished, remove it or handle loop if desired
                table.remove(self.activeBolts, i)
                goto continue_bolt_loop -- Salta para o próximo bolt se este for removido
            end
        end

        if bolt.timer >= bolt.duration then
            table.remove(self.activeBolts, i)
        end
        ::continue_bolt_loop::
    end

    if self.currentCooldown <= 0 and enemies and #enemies > 0 then
        self:cast(enemies)
        self.currentCooldown = self.cooldown
    end
end

function ThunderRune:draw()
    for _, bolt in ipairs(self.activeBolts) do
        -- Usa os frames globais da baseAnimationConfig
        local frame = baseAnimationConfig.frames[bolt.animation.currentFrame]
        if frame then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(
                frame,
                bolt.x,
                bolt.y,
                0,
                self.animation.scale, -- Escala da instância
                self.animation.scale, -- Escala da instância
                frame:getWidth() / 2,
                frame:getHeight()
            )
        end
    end
end

function ThunderRune:cast(enemies)
    if not self.playerManager or not self.playerManager.player or not self.playerManager.player.position then
        print("AVISO [ThunderRune:cast]: playerManager ou player.position não disponível.")
        return
    end

    local validEnemies = {}
    local playerX = self.playerManager.player.position.x
    local playerY = self.playerManager.player.position.y

    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            local dx = enemy.position.x - playerX
            local dy = enemy.position.y - playerY
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance <= self.range then
                table.insert(validEnemies, enemy)
            end
        end
    end

    if #validEnemies > 0 then
        local target = validEnemies[math.random(1, #validEnemies)]

        self:applyDamage(target)

        local collisionPosition = target:getCollisionPosition()
        if not collisionPosition or not collisionPosition.position then
            print("AVISO [ThunderRune:cast]: target:getCollisionPosition() não retornou uma posição válida.")
            return
        end

        table.insert(self.activeBolts, {
            x = collisionPosition.position.x,
            y = collisionPosition.position.y + 20,
            timer = 0,
            duration = self.animation.frameCount * self.animation.frameTime, -- Duração baseada na animação completa
            animation = {                                                    -- Estado da animação para ESTE bolt
                currentFrame = 1,
                timer = 0
                -- frameTime e frameCount vêm de self.animation
            }
        })
    end
end

function ThunderRune:applyDamage(target)
    if not target or not target.receiveDamage then -- Alterado para receiveDamage
        print("AVISO [ThunderRune:applyDamage]: Alvo inválido ou sem método receiveDamage.")
        return false
    end
    -- Em vez de target:takeDamage, que pode ter lógica de redução específica do PlayerState,
    -- idealmente teríamos um target:receiveDamage(amount, type) mais genérico.
    -- Por ora, vamos manter target:takeDamage, mas isso pode precisar de refatoração.
    -- Se target for um inimigo, ele deve ter o método takeDamage que o PlayerManager usa.
    if target.takeDamage then
        return target:takeDamage(self.damage) -- Passa o dano da instância da runa
    elseif target.receiveDamage then          -- Fallback se existir um receiveDamage mais genérico
        target:receiveDamage(self.damage, "thunder")
        return true
    end
    return false
end

return ThunderRune
