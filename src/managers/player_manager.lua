-- Módulo de gerenciamento do player
local SpritePlayer = require('src.animations.sprite_player')
local Warrior = require('src.classes.player.warrior')
local PlayerState = require("src.entities.player_state")
local EnemyManager = require("src.managers.enemy_manager")
local FloatingTextManager = require("src.managers.floating_text_manager")
local LevelUpModal = require("src.ui.level_up_modal")
local Camera = require("src.config.camera")
local InputManager = require("src.managers.input_manager")
local IronSword = require("src.items.weapons.iron_sword")
local GoldSword = require("src.items.weapons.gold_sword")
local SteelSword = require("src.items.weapons.steel_sword")
local BronzeSword = require("src.items.weapons.bronze_sword")
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")

local PlayerManager = {
    -- Referência ao player sprite
    player = nil,
    
    -- Classe atual do player
    class = nil,
    
    -- Estado do player
    state = nil,
    
    -- Level System
    level = 1,
    experience = 40,
    experienceToNextLevel = 50,
    experienceMultiplier = 1.10, -- Multiplicador de experiência para o próximo nível
    
    -- Game Stats
    gameTime = 0,
    kills = 0,
    gold = 0,
    
    -- Abilities
    runes = {}, -- Lista de habilidades de runas
    
    -- Auto Attack
    autoAttack = false,
    autoAttackEnabled = false,
    autoAim = false,
    autoAimEnabled = false,
    
    -- Damage cooldown
    lastDamageTime = 0,
    damageCooldown = 5.0, -- Tempo de espera após receber dano para começar a regenerar
    
    -- Health regeneration
    lastRegenTime = 0,
    regenInterval = 1.0, -- Intervalo de regeneração em segundos
    regenAmount = 1, -- Quantidade fixa de HP recuperado
    accumulatedRegen = 0, -- HP acumulado para regeneração
    
    -- Collection
    radius = 25,
    collectionRadius = 100, -- Raio base para coletar prismas
    
    -- Mouse tracking
    lastMouseX = 0,
    lastMouseY = 0,
    
    -- Mouse pressed tracking
    previousAutoAttack = false,
    previousAutoAim = false,
    
    -- Weapons
    equippedWeapon = nil,
    availableWeapons = {
        [1] = IronSword,
        [2] = GoldSword,
        [3] = SteelSword,
        [4] = BronzeSword,
    }
}

-- Inicializa o player manager
function PlayerManager.init()
    -- Inicializa a classe do player (Warrior como padrão inicial)
    PlayerManager.initializeClass(Warrior)
    
    -- Carrega recursos do player sprite
    SpritePlayer.load()
    
    -- Cria configuração do player sprite
    PlayerManager.player = SpritePlayer.newConfig({
        x = love.graphics.getWidth() / 2,
        y = love.graphics.getHeight() / 2,
        scale = 1,
        speed = PlayerManager.state:getTotalSpeed()
    })
    
    -- Inicializa a câmera
    Camera:init()

    -- Equipa a arma inicial
    local startingWeapon = PlayerManager.class.startingWeapon
    if startingWeapon then
        print("Equipando arma inicial:", startingWeapon.name)
        PlayerManager.equippedWeapon = setmetatable({}, { __index = startingWeapon })
        PlayerManager.equippedWeapon:equip(PlayerManager)
    else
        print("AVISO: Nenhuma arma inicial definida para a classe", PlayerManager.class.name)
    end
    
    -- Inicializa o InputManager
    InputManager.init(PlayerManager)
    
    -- Inicializa o LevelUpModal
    LevelUpModal:init(PlayerManager)
end

-- Atualiza o estado do player e da câmera
function PlayerManager.update(dt)
    if not PlayerManager.state.isAlive then return end
    
    -- Atualiza o input manager
    InputManager.update(dt)
    
    -- Atualiza o tempo de jogo
    PlayerManager.gameTime = PlayerManager.gameTime + dt
    
    -- Atualiza o tempo desde o último dano
    PlayerManager.lastDamageTime = PlayerManager.lastDamageTime + dt
    
    -- Atualiza o ataque da arma
    if PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.attackInstance then
        PlayerManager.equippedWeapon.attackInstance:update(dt)
    end
    
    -- Update health recovery
    PlayerManager.updateHealthRecovery(dt)
    
    -- Update all rune abilities
    for _, rune in ipairs(PlayerManager.runes) do
        rune:update(dt)
        
        -- Executa a runa automaticamente se o cooldown zerar
        if rune.cooldownRemaining <= 0 then
            rune:cast(PlayerManager.player.x, PlayerManager.player.y)
        end
    end

    -- Atualiza o auto attack
    PlayerManager.updateAutoAttack()

    -- Atualiza o sprite do player
    SpritePlayer.update(PlayerManager.player, dt, Camera)
    
    -- Atualiza a câmera
    Camera:follow(PlayerManager.player, dt)
end

-- Desenha o player e elementos relacionados
function PlayerManager.draw()
    -- Aplica transformação da câmera
    Camera:attach()
    
    -- Desenha o círculo de colisão primeiro (embaixo de tudo)
    local circleY = PlayerManager.player.y + 25 -- Ajusta para ficar nos pés do sprite
    
    -- Salva o estado atual de transformação
    love.graphics.push()
    
    -- Aplica transformação isométrica no círculo
    love.graphics.translate(PlayerManager.player.x, circleY)
    love.graphics.scale(1, 0.5) -- Achata o círculo verticalmente para efeito isométrico
    
    -- Desenha o círculo com efeito isométrico
    love.graphics.setColor(0, 0.5, 1, 0.3) -- Azul semi-transparente
    love.graphics.circle("fill", 0, 0, PlayerManager.radius)
    love.graphics.setColor(0, 0.7, 1, 0.5) -- Azul mais escuro para a borda
    love.graphics.circle("line", 0, 0, PlayerManager.radius)
    
    -- Restaura o estado de transformação
    love.graphics.pop()
    
    -- Desenha o sprite do player
    love.graphics.setColor(1, 1, 1, 1)
    SpritePlayer.draw(PlayerManager.player)
    
    -- Desenha a arma equipada e seu ataque
    if PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.attackInstance then
        PlayerManager.equippedWeapon.attackInstance:draw()
    end
    
    -- Desenha todas as runas
    for _, rune in ipairs(PlayerManager.runes) do
        rune:draw()
    end
    
    -- Draw health bar
    local healthBarWidth = 60
    local healthBarHeight = 8
    local healthBarX = PlayerManager.player.x - healthBarWidth/2
    local healthBarY = PlayerManager.player.y - PlayerManager.radius - 10

    elements.drawResourceBar({
        x = healthBarX,
        y = healthBarY,
        height = healthBarHeight,
        current = PlayerManager.state.currentHealth,
        max = PlayerManager.state:getTotalHealth(),
        color = colors.hp_fill,
        bgColor = colors.bar_bg,
        borderColor = colors.bar_border,
        showShadow = true,
        segmentInterval = 20, -- Segmentos a cada 20 pontos de vida
        glow = true,
        -- Configurações opcionais de largura dinâmica
        dynamicWidth = true,
        baseWidth = 60,
        maxWidth = 120,
        scaleFactor = 0.5,
        minValue = 100,
        maxValue = 2000
    })
    
    -- Draw cooldown bar
    if PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.attackInstance then
        local cooldown = PlayerManager.equippedWeapon.attackInstance:getCooldownRemaining()
        if cooldown > 0 then
            local cooldownPercentage = cooldown / PlayerManager.equippedWeapon.attackInstance.cooldown
            
            -- Cooldown bar background
            love.graphics.setColor(0.2, 0, 0, 0.3)
            love.graphics.rectangle("fill", 
                PlayerManager.player.x - healthBarWidth/2, 
                PlayerManager.player.y - PlayerManager.radius - 5,
                healthBarWidth, 
                2
            )
            
            -- Cooldown bar fill
            love.graphics.setColor(1, 0, 0, 0.8)
            love.graphics.rectangle("fill", 
                PlayerManager.player.x - healthBarWidth/2, 
                PlayerManager.player.y - PlayerManager.radius - 5,
                healthBarWidth * cooldownPercentage, 
                2
            )
        end
    end
    
    Camera:detach()
    
    -- Debug info
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.format(
        -- Informações básicas
        "=== JOGADOR ===\n" ..
        "Posição: (%.1f, %.1f)\n" ..
        "Direção: %s\n" ..
        "Estado: %s\n" ..
        "Frame: %d\n" ..
        "Movimento: %s\n\n" ..
        
        -- Sistema de level
        "=== LEVEL ===\n" ..
        "Nível: %d\n" ..
        "Experiência: %d/%d\n" ..
        "Kills: %d\n" ..
        "Gold: %d\n" ..
        "Tempo de Jogo: %.1fs\n\n" ..
        
        -- Sistema de habilidades
        "=== HABILIDADES ===\n" ..
        "Arma Equipada: %s\n" ..
        "Descrição: %s\n" ..
        "Dano: %.1f (x%.1f%%) (+%.1f -%.1f%% de %.1f) = %.1f\n" ..
        "Velocidade de Ataque: %.1f\n" ..
        "Alcance: %.1f\n" ..
        "Tipo de Dano: %s\n" ..
        "Cooldown: %.1f/%.1f\n" ..
        "Auto Attack: %s\n" ..
        "Auto Aim: %s\n" ..
        "Preview: %s\n" ..
        "Runas Ativas: %d\n\n" ..
        
        -- Sistema de regeneração
        "=== REGENERAÇÃO ===\n" ..
        "Tempo desde último dano: %.1fs\n" ..
        "Cooldown de dano: %.1fs\n" ..
        "HP acumulado: %.1f\n" ..
        "Intervalo de regeneração: %.1fs\n" ..
        "Quantidade de regeneração: %.1f\n\n" ..
        
        -- Bônus por Level
        "=== BÔNUS POR LEVEL ===\n" ..
        "Vida: %.1f (x%.1f%%) (+%.1f -%.1f%% de %.1f) = %.1f\n" ..
        "Dano: %.1f (x%.1f%%) (+%.1f -%.1f%% de %.1f) = %.1f\n" ..
        "Defesa: %.1f (x%.1f%%) (+%.1f -%.1f%% de %.1f) = %.1f\n" ..
        "Velocidade: %.1f (x%.1f%%) (+%.1f -%.1f%% de %.1f) = %.1f m/s\n" ..
        "Velocidade de Ataque: %.1f (x%.1f%%) (+%.1f -%.1f%% de %.1f) = %.1f (%.1f ataques/s)\n" ..
        "Chance de Crítico: %.1f%% (x%.1f%%) (+%.1f%% -%.1f%% de %.1f%%) = %.1f%%\n" ..
        "Multiplicador de Crítico: %.1fx (x%.1f%%) (+%.1fx -%.1f%% de %.1fx) = %.1fx\n" ..
        "Regeneração de Vida: %.1f/s (x%.1f%%) (+%.1f/s -%.1f%% de %.1f/s) = %.1f/s\n" ..
        "Chance de Ataque Múltiplo: %.1f%% (x%.1f%%) (+%.1f%% -%.1f%% de %.1f%%) = %.1f%%",
        
        -- Valores básicos
        PlayerManager.player.x, PlayerManager.player.y,
        PlayerManager.player.animation.direction,
        PlayerManager.player.animation.state,
        PlayerManager.player.animation.currentFrame,
        PlayerManager.player.animation.isMovingBackward and "Backward" or "Forward",
        
        -- Valores de level
        PlayerManager.level,
        PlayerManager.experience,
        PlayerManager.experienceToNextLevel,
        PlayerManager.kills,
        PlayerManager.gold,
        PlayerManager.gameTime,
        
        -- Valores de habilidades
        PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.name or "Nenhuma",
        PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.description or "Nenhuma",
        PlayerManager.state.baseDamage,
        PlayerManager.state.levelBonus.damage,
        PlayerManager.state.baseDamage * (PlayerManager.state.levelBonus.damage / 100),
        PlayerManager.state.levelBonus.damage,
        PlayerManager.state.baseDamage,
        PlayerManager.state:getTotalDamage(PlayerManager.state.baseDamage),
        PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.attackSpeed or 0,
        PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.range or 0,
        PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.attackInstance and PlayerManager.equippedWeapon.attackInstance.damageType or "Nenhum",
        PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.attackInstance and PlayerManager.equippedWeapon.attackInstance.cooldownRemaining or 0,
        PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.attackInstance and PlayerManager.equippedWeapon.attackInstance.cooldown or 0,
        PlayerManager.autoAttackEnabled and "Ativado" or "Desativado",
        PlayerManager.autoAimEnabled and "Ativado" or "Desativado",
        PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.attackInstance and PlayerManager.equippedWeapon.attackInstance:getPreview() and "Ativado" or "Desativado",
        #PlayerManager.runes,
        
        -- Valores de regeneração
        PlayerManager.lastDamageTime,
        PlayerManager.damageCooldown,
        PlayerManager.accumulatedRegen,
        PlayerManager.regenInterval,
        PlayerManager.regenAmount,
        
        -- Valores de bônus por level
        PlayerManager.state.baseHealth,
        PlayerManager.state.levelBonus.health,
        PlayerManager.state.baseHealth * (PlayerManager.state.levelBonus.health / 100),
        PlayerManager.state.levelBonus.health,
        PlayerManager.state.baseHealth,
        PlayerManager.state:getTotalHealth(),
        
        PlayerManager.state.baseDamage,
        PlayerManager.state.levelBonus.damage,
        PlayerManager.state.baseDamage * (PlayerManager.state.levelBonus.damage / 100),
        PlayerManager.state.levelBonus.damage,
        PlayerManager.state.baseDamage,
        PlayerManager.state:getTotalDamage(PlayerManager.state.baseDamage),
        
        PlayerManager.state.baseDefense,
        PlayerManager.state.levelBonus.defense,
        PlayerManager.state.baseDefense * (PlayerManager.state.levelBonus.defense / 100),
        PlayerManager.state.levelBonus.defense,
        PlayerManager.state.baseDefense,
        PlayerManager.state:getTotalDefense(),
        
        PlayerManager.state.baseSpeed,
        PlayerManager.state.levelBonus.speed,
        PlayerManager.state.baseSpeed * (PlayerManager.state.levelBonus.speed / 100),
        PlayerManager.state.levelBonus.speed,
        PlayerManager.state.baseSpeed,
        PlayerManager.state:getTotalSpeed(),
        
        PlayerManager.state.baseAttackSpeed,
        PlayerManager.state.levelBonus.attackSpeed,
        PlayerManager.state.baseAttackSpeed * (PlayerManager.state.levelBonus.attackSpeed / 100),
        PlayerManager.state.levelBonus.attackSpeed,
        PlayerManager.state.baseAttackSpeed,
        PlayerManager.state:getTotalAttackSpeed(),
        1 / PlayerManager.state:getTotalAttackSpeed(), -- Ataques por segundo
        
        PlayerManager.state.baseCriticalChance,
        PlayerManager.state.levelBonus.criticalChance,
        PlayerManager.state.baseCriticalChance * (PlayerManager.state.levelBonus.criticalChance / 100),
        PlayerManager.state.levelBonus.criticalChance,
        PlayerManager.state.baseCriticalChance,
        PlayerManager.state:getTotalCriticalChance(),
        
        PlayerManager.state.baseCriticalMultiplier,
        PlayerManager.state.levelBonus.criticalMultiplier,
        PlayerManager.state.baseCriticalMultiplier * (PlayerManager.state.levelBonus.criticalMultiplier / 100),
        PlayerManager.state.levelBonus.criticalMultiplier,
        PlayerManager.state.baseCriticalMultiplier,
        PlayerManager.state:getTotalCriticalMultiplier(),
        
        PlayerManager.state.baseHealthRegen,
        PlayerManager.state.levelBonus.healthRegen,
        PlayerManager.state.baseHealthRegen * (PlayerManager.state.levelBonus.healthRegen / 100),
        PlayerManager.state.levelBonus.healthRegen,
        PlayerManager.state.baseHealthRegen,
        PlayerManager.state:getTotalHealthRegen(),
        
        PlayerManager.state.baseMultiAttackChance,
        PlayerManager.state.levelBonus.multiAttackChance,
        PlayerManager.state.baseMultiAttackChance * (PlayerManager.state.levelBonus.multiAttackChance / 100),
        PlayerManager.state.levelBonus.multiAttackChance,
        PlayerManager.state.baseMultiAttackChance,
        PlayerManager.state:getTotalMultiAttackChance()
    ), 10, 10)
end

function PlayerManager.updateHealthRecovery(dt)
    -- Atualiza regeneração de vida
    if PlayerManager.state.currentHealth < PlayerManager.state:getTotalHealth() and PlayerManager.lastDamageTime >= PlayerManager.damageCooldown then
        local hpPerSecond = PlayerManager.state:getTotalHealthRegen()
        PlayerManager.accumulatedRegen = PlayerManager.accumulatedRegen + (hpPerSecond * dt)
        
        -- Se acumulou pelo menos 1 HP, recupera
        if PlayerManager.accumulatedRegen >= 1 then
            FloatingTextManager:addText(
                PlayerManager.player.x,
                PlayerManager.player.y - PlayerManager.radius - 40,
                "+1",
                false,
                PlayerManager,
                {0, 1, 0}
            )
            PlayerManager.heal(1)
            PlayerManager.accumulatedRegen = PlayerManager.accumulatedRegen - 1
        end
    else
        PlayerManager.accumulatedRegen = 0
    end
end

function PlayerManager.updateAutoAttack()
    if PlayerManager.autoAttack or InputManager.mouse.leftButton then
        local cooldown = PlayerManager.equippedWeapon.attackInstance:getCooldownRemaining()
        if cooldown <= 0 then
            local targetX, targetY = PlayerManager.getTargetPosition()
            if targetX and targetY then
                -- Converte as coordenadas da tela para coordenadas do mundo
                local worldX, worldY = Camera:screenToWorld(targetX, targetY)
                PlayerManager.attack(worldX, worldY)
            end
        end
    end
end

-- Inicializa uma nova classe para o player
function PlayerManager.initializeClass(classDefinition)
    PlayerManager.class = classDefinition
    
    -- Inicializa estado com stats base
    PlayerManager.state = PlayerState
    PlayerManager.state:init(classDefinition:getBaseStats())
end

-- Funções de gerenciamento de vida
function PlayerManager.isAlive()
    return PlayerManager.state.isAlive
end

function PlayerManager.takeDamage(amount)
    PlayerManager.lastDamageTime = 0
    return PlayerManager.state:takeDamage(amount)
end

function PlayerManager.heal(amount)
    PlayerManager.state:heal(amount)
end

-- Funções de habilidades
function PlayerManager.addRune(rune)
    if not rune then return end
    table.insert(PlayerManager.runes, rune)
    if rune.init then
        rune:init(PlayerManager)
    end
end

-- Função para atacar com a arma equipada
function PlayerManager.attack(x, y)
    if not PlayerManager.equippedWeapon or not PlayerManager.equippedWeapon.attackInstance then
        error("[Erro] [PlayerManager.attack] Nenhuma arma ou instância de ataque encontrada")
        return false
    end

    local success = PlayerManager.equippedWeapon.attackInstance:cast(x, y)

    if success then
        -- Inicia a animação de ataque do sprite
        SpritePlayer.startAttackAnimation(PlayerManager.player)

        -- Verifica colisão com inimigos
        local enemies = EnemyManager:getEnemies()
        local enemiesHit = 0
        local totalEnemies = 0
        
        for _, enemy in ipairs(enemies) do
            if enemy.isAlive then
                totalEnemies = totalEnemies + 1
                -- Verifica se o inimigo está dentro da área de ataque usando isPointInArea
                local isInArea = PlayerManager.equippedWeapon.attackInstance:isPointInArea(enemy.positionX, enemy.positionY)
                
                if isInArea then
                    enemiesHit = enemiesHit + 1
                    -- Aplica o dano e verifica se o inimigo morreu
                    if PlayerManager.equippedWeapon.attackInstance:applyDamage(enemy) then
                        -- Se o inimigo morreu, atualiza as estatísticas do jogador
                        PlayerManager.kills = PlayerManager.kills + 1
                    end
                end
            end
        end

    end

    return success
end

-- Funções de experiência e level
function PlayerManager.addExperience(amount)
    PlayerManager.experience = PlayerManager.experience + amount
    
    if PlayerManager.experience >= PlayerManager.experienceToNextLevel then
        PlayerManager.levelUp()
    end
end

function PlayerManager.levelUp()
    PlayerManager.level = PlayerManager.level + 1
    local previousRequired = PlayerManager.experienceToNextLevel
    PlayerManager.experienceToNextLevel = previousRequired + math.floor(previousRequired * PlayerManager.experienceMultiplier)
    
    FloatingTextManager:addText(
        PlayerManager.player.x,
        PlayerManager.player.y - PlayerManager.radius - 30,
        "LEVEL UP!",
        true,
        PlayerManager,
        {1, 1, 0}
    )
    
    LevelUpModal:show()
end

-- Funções de controle
function PlayerManager.toggleAbilityAutoCast()
    PlayerManager.autoAttackEnabled = not PlayerManager.autoAttackEnabled
    PlayerManager.autoAttack = PlayerManager.autoAttackEnabled
end

function PlayerManager.toggleAbilityVisual()
    if PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.attackInstance then
        PlayerManager.equippedWeapon.attackInstance:togglePreview()
    end
end

function PlayerManager.toggleAutoAim()
    PlayerManager.autoAimEnabled = not PlayerManager.autoAimEnabled
    PlayerManager.autoAim = PlayerManager.autoAimEnabled
end

function PlayerManager.getTargetPosition()
    -- Obtém a posição atual do mouse
    local mouseX, mouseY = InputManager.mouse.position()
    
    -- Se o botão do mouse estiver pressionado, usa a posição do mouse
    if InputManager.mouse.leftButton then
        return mouseX, mouseY
    end
    
    -- Se o auto aim estiver ativado, procura o inimigo mais próximo
    if PlayerManager.autoAim then
        local enemies = EnemyManager:getEnemies()
        local closestEnemy = nil
        local closestDistance = math.huge
        
        for _, enemy in ipairs(enemies) do
            if enemy.isAlive then
                local dx = enemy.positionX - PlayerManager.player.x
                local dy = enemy.positionY - PlayerManager.player.y
                local distance = math.sqrt(dx * dx + dy * dy)
                
                if distance < closestDistance then
                    closestDistance = distance
                    closestEnemy = enemy
                end
            end
        end
        
        if closestEnemy then
            local screenX, screenY = Camera:worldToScreen(closestEnemy.positionX, closestEnemy.positionY)
            return screenX, screenY
        end
    end
    
    -- Se não encontrou inimigo ou auto aim desativado, usa a posição do mouse
    return mouseX, mouseY
end

function PlayerManager.leftMouseClicked(x, y)
    if not PlayerManager.autoAttackEnabled then
        -- Converte as coordenadas da tela para coordenadas do mundo
        local worldX, worldY = Camera:screenToWorld(x, y)
        PlayerManager.attack(worldX, worldY)
    end
end

function PlayerManager.leftMouseReleased(x, y)
    -- Nada a fazer aqui por enquanto
end

-- Retorna a posição de colisão do player (nos pés do sprite)
function PlayerManager.getCollisionPosition()
    return {
        x = PlayerManager.player.x,
        y = PlayerManager.player.y + 25,
        radius = PlayerManager.radius
    }
end

-- Função para equipar uma nova arma
function PlayerManager.equipWeapon(weaponClass)
    if PlayerManager.equippedWeapon then
        -- Reseta a instância atual
        PlayerManager.equippedWeapon.attackInstance = nil
    end
    
    -- Cria uma nova instância da arma
    PlayerManager.equippedWeapon = setmetatable({}, { __index = weaponClass })
    PlayerManager.equippedWeapon:equip(PlayerManager)
    
    -- Atualiza os atributos do player com os da nova arma
    PlayerManager.state:updateWeaponStats(PlayerManager.equippedWeapon)
    
    -- Exibe mensagem informativa
    print(string.format("Arma trocada para: %s", PlayerManager.equippedWeapon.name))
end

-- Função para trocar arma por índice
function PlayerManager.switchWeapon(index)
    local weapon = PlayerManager.availableWeapons[index]
    if weapon then
        PlayerManager.equipWeapon(weapon)
    end
end

-- Adiciona ao final da função love.keypressed
function PlayerManager.keypressed(key)
    -- Teclas numéricas para trocar armas
    if key >= "1" and key <= "9" then
        local index = tonumber(key)
        PlayerManager.switchWeapon(index)
    end
    
    -- Tecla de teste para subir de nível (F1)
    if key == "f1" then
        print("[DEBUG] Subindo de nível manualmente...")
        PlayerManager.levelUp()
    end
end

return PlayerManager 