--[[
    Runa do Trovão
    Faz raios caírem em inimigos aleatórios periodicamente
]]

local RenderPipeline = require("src.core.render_pipeline")
local TablePool = require("src.utils.table_pool")

local ThunderRune = {}
ThunderRune.__index = ThunderRune -- Para permitir que instâncias herdem métodos

-- Propriedades que podem ser consideradas "default" ou "static" para a classe
ThunderRune.identifier = "rune_thunder"
ThunderRune.defaultDepth = RenderPipeline.DEPTH_EFFECTS_WORLD_UI
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

--- Atualiza a habilidade do Trovão.
--- @param dt number Tempo de atualização.
--- @param enemies BaseEnemy[] Lista de inimigos.
--- @param finalStats table Estatísticas finais do jogador.
function ThunderRune:update(dt, enemies, finalStats)
    self.currentCooldown = self.currentCooldown - dt

    for i = #self.activeBolts, 1, -1 do
        local bolt = self.activeBolts[i]
        bolt.timer = bolt.timer + dt

        bolt.animation.timer = bolt.animation.timer + dt
        if bolt.animation.timer >= self.animation.frameTime then -- Usa self.animation para config base
            bolt.animation.timer = bolt.animation.timer - self.animation.frameTime
            bolt.animation.currentFrame = bolt.animation.currentFrame + 1
            if bolt.animation.currentFrame > self.animation.frameCount then
                -- Bolt animation finished, release it
                TablePool.release(bolt.animation)
                TablePool.release(bolt)
                table.remove(self.activeBolts, i)
                goto continue_bolt_loop -- Salta para o próximo bolt se este for removido
            end
        end

        if bolt.timer >= bolt.duration then
            TablePool.release(bolt.animation)
            TablePool.release(bolt)
            table.remove(self.activeBolts, i)
        end
        ::continue_bolt_loop::
    end

    if self.currentCooldown <= 0 and enemies and #enemies > 0 then
        self:cast(enemies)
        local cooldownReduction = finalStats.cooldownReduction
        if cooldownReduction <= 0 then cooldownReduction = 0.01 end
        local finalCooldown = self.cooldown / cooldownReduction
        self.currentCooldown = finalCooldown
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

    local validEnemies = TablePool.get()
    local playerX = self.playerManager.player.position.x
    local playerY = self.playerManager.player.position.y

    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            local dx = enemy.position.x - playerX
            local dy = enemy.position.y - playerY
            local distSq = dx * dx + dy * dy        -- Calcula o quadrado da distância
            local rangeSq = self.range * self.range -- Calcula o quadrado do alcance

            if distSq <= rangeSq then               -- Compara os quadrados
                table.insert(validEnemies, enemy)
            end
        end
    end

    if #validEnemies > 0 then
        local target = validEnemies[math.random(1, #validEnemies)]

        self:applyDamage(target)

        if not target or not target.position then
            print("AVISO [ThunderRune:cast]: Alvo ou posição do alvo inválidos para o raio.")
            TablePool.release(validEnemies) -- Libera a tabela antes de sair
            return
        end
        local targetPosX = target.position.x
        local targetPosY = target.position.y + 10 -- Ajuste isométrico similar ao getCollisionPosition de BaseEnemy

        -- Pega tabelas do pool para o novo raio e seu estado de animação
        local newBolt = TablePool.get()
        newBolt.x = targetPosX
        newBolt.y = targetPosY +
            20                                                                  -- Mantém o ajuste adicional de +20 específico do raio
        newBolt.timer = 0
        newBolt.duration = self.animation.frameCount * self.animation.frameTime -- Duração baseada na animação completa

        local animState = TablePool.get()
        animState.currentFrame = 1
        animState.timer = 0
        newBolt.animation = animState

        table.insert(self.activeBolts, newBolt)
    end

    TablePool.release(validEnemies) -- Libera a tabela de inimigos válidos
end

function ThunderRune:applyDamage(target)
    if not target then return false end

    local damageAmount = self.damage
    local died = false

    if target.takeDamage then
        died = target:takeDamage(damageAmount)
        if self.playerManager and self.playerManager.registerDamageDealt then
            self.playerManager:registerDamageDealt(damageAmount, false, { abilityId = self.identifier })
        end
        return died
    elseif target.receiveDamage then
        target:receiveDamage(damageAmount, "thunder")
        if self.playerManager and self.playerManager.registerDamageDealt then
            self.playerManager:registerDamageDealt(damageAmount, false, { abilityId = self.identifier })
        end
        return true
    end
    return false
end

return ThunderRune
