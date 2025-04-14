-- Módulo de gerenciamento do player
local SpritePlayer = require('src.animations.sprite_player')
local Warrior = require('src.classes.player.warrior')
local PlayerState = require("src.entities.player_state")
local EnemyManager = require("src.managers.enemy_manager")
local FloatingTextManager = require("src.managers.floating_text_manager")
local LevelUpModal = require("src.ui.level_up_modal")
local Camera = require("src.config.camera")
local InputManager = require("src.managers.input_manager")

local PlayerManager = {
    -- Referência ao player sprite
    player = nil,
    
    -- Classe atual do player
    class = nil,
    
    -- Estado do player
    state = nil,
    
    -- Level System
    level = 1,
    experience = 0,
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
    radius = 8,
    collectionRadius = 20, -- Raio base para coletar prismas
    
    -- Mouse tracking
    lastMouseX = 0,
    lastMouseY = 0,
    
    -- Mouse pressed tracking
    previousAutoAttack = false,
    previousAutoAim = false
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
    
    -- Desenha o sprite do player primeiro
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
    local baseWidth = 40
    local maxWidth = 60
    local healthBarHeight = 5
    local healthPercentage = PlayerManager.state:getHealthPercentage()
    
    -- Calculate dynamic width based on max health
    local healthBarWidth = baseWidth + (maxWidth - baseWidth) * (PlayerManager.state:getTotalHealth() / 200)
    
    -- Draw level circle
    local levelCircleRadius = 8
    local experiencePercentage = PlayerManager.experience / PlayerManager.experienceToNextLevel
    
    -- Posição do círculo de nível
    local levelCircleX = PlayerManager.player.x - healthBarWidth/2 - levelCircleRadius - 5
    local levelCircleY = PlayerManager.player.y - PlayerManager.radius - 10 + healthBarHeight/2
    
    -- Fundo do círculo de nível
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.circle("line", levelCircleX, levelCircleY, levelCircleRadius)
    
    -- Preenchimento do círculo de nível
    love.graphics.setColor(0.5, 0, 0.5)
    love.graphics.arc("fill", "open", levelCircleX, levelCircleY, levelCircleRadius, -math.pi/2, -math.pi/2 + (2 * math.pi * experiencePercentage))
    
    -- Número do nível
    love.graphics.setColor(1, 1, 1)
    local levelText = tostring(PlayerManager.level)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(levelText) * 0.8
    local textHeight = font:getHeight() * 0.8
    
    local textX = levelCircleX - textWidth/2
    local textY = levelCircleY - textHeight/2
    
    love.graphics.print(levelText, textX, textY, 0, 0.8)
    
    -- Health bar background
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 
        PlayerManager.player.x - healthBarWidth/2, 
        PlayerManager.player.y - PlayerManager.radius - 10,
        healthBarWidth, 
        healthBarHeight
    )
    
    -- Health bar fill
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle("fill", 
        PlayerManager.player.x - healthBarWidth/2, 
        PlayerManager.player.y - PlayerManager.radius - 10,
        healthBarWidth * healthPercentage, 
        healthBarHeight
    )
    
    -- Draw health bar segments
    love.graphics.setColor(0, 0, 0, 0.3)
    local segmentCount = 5
    local segmentWidth = healthBarWidth / segmentCount
    
    for i = 1, segmentCount - 1 do
        local x = PlayerManager.player.x - healthBarWidth/2 + segmentWidth * i
        love.graphics.line(
            x,
            PlayerManager.player.y - PlayerManager.radius - 10,
            x,
            PlayerManager.player.y - PlayerManager.radius - 5
        )
    end
    
    -- Draw health bar border
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("line", 
        PlayerManager.player.x - healthBarWidth/2, 
        PlayerManager.player.y - PlayerManager.radius - 10,
        healthBarWidth, 
        healthBarHeight
    )
    
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
    
    -- Draw class name
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(PlayerManager.class.name, 
        PlayerManager.player.x - 20, 
        PlayerManager.player.y - PlayerManager.radius - 25, 
        0, 0.8)
    
    Camera:detach()
    
    -- Debug info
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.print(string.format(
        -- Informações básicas
        "=== JOGADOR ===\n" ..
        "Posição: (%.1f, %.1f)\n" ..
        "Direção: %s\n" ..
        "Estado: %s\n" ..
        "Frame: %d\n" ..
        "Movimento: %s\n\n" ..
        
        -- Informações da classe
        "=== CLASSE ===\n" ..
        "Nome: %s\n" ..
        "Vida: %.1f/%.1f\n" ..
        "Dano: %.1f\n" ..
        "Velocidade: %.1f\n" ..
        "Defesa: %.1f\n" ..
        "Velocidade de Ataque: %.1f\n" ..
        "Chance de Crítico: %.1f%%\n" ..
        "Multiplicador de Crítico: %.1fx\n" ..
        "Regeneração de Vida: %.1f/s\n\n" ..
        
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
        "Dano: %.1f\n" ..
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
        "Quantidade de regeneração: %.1f",
        
        -- Valores básicos
        PlayerManager.player.x, PlayerManager.player.y,
        PlayerManager.player.animation.direction,
        PlayerManager.player.animation.state,
        PlayerManager.player.animation.currentFrame,
        PlayerManager.player.animation.isMovingBackward and "Backward" or "Forward",
        
        -- Valores da classe
        PlayerManager.class.name,
        PlayerManager.state.currentHealth,
        PlayerManager.state:getTotalHealth(),
        PlayerManager.state:getTotalDamage(),
        PlayerManager.state:getTotalSpeed(),
        PlayerManager.state:getTotalDefense(),
        PlayerManager.state:getTotalAttackSpeed(),
        PlayerManager.state:getTotalCriticalChance() * 100,
        PlayerManager.state:getTotalCriticalMultiplier(),
        PlayerManager.state:getTotalHealthRegen(),
        
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
        PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.damage or 0,
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
        PlayerManager.regenAmount
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
            print("Auto ataque: Target position:", targetX, targetY)
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

        if PlayerManager.equippedWeapon.attackInstance.damageType == "melee" then
            local enemies = EnemyManager:getEnemies()
            for _, enemy in ipairs(enemies) do
                if enemy.isAlive then
                    if PlayerManager.equippedWeapon.attackInstance:isPointInArea(enemy.positionX, enemy.positionY) then
                        if PlayerManager.equippedWeapon.attackInstance:applyDamage(enemy) then
                            PlayerManager.kills = PlayerManager.kills + 1
                            PlayerManager.addExperience(enemy.experienceValue)
                            PlayerManager.gold = PlayerManager.gold + math.random(1, 5)
                        else
                            error("[Erro] [PlayerManager.attack] Falha ao aplicar dano")
                        end
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
    print("\n=== DEBUG DO TARGET POSITION ===")
    print("Auto Aim:", PlayerManager.autoAim)
    print("Auto Aim Enabled:", PlayerManager.autoAimEnabled)
    print("Mouse Left Button:", InputManager.mouse.leftButton)
    
    -- Obtém a posição atual do mouse
    local mouseX, mouseY = InputManager.mouse.position()
    print("Mouse Position:", mouseX, mouseY)
    
    -- Se o botão do mouse estiver pressionado, usa a posição do mouse
    if InputManager.mouse.leftButton then
        print("Usando posição do mouse (botão pressionado)")
        return mouseX, mouseY
    end
    
    -- Se o auto aim estiver ativado, procura o inimigo mais próximo
    if PlayerManager.autoAim then
        print("Procurando inimigo mais próximo (auto aim ativado)")
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
            print("Inimigo encontrado:", closestEnemy.positionX, closestEnemy.positionY)
            local screenX, screenY = Camera:worldToScreen(closestEnemy.positionX, closestEnemy.positionY)
            print("Coordenadas convertidas:", screenX, screenY)
            return screenX, screenY
        else
            print("Nenhum inimigo encontrado, usando posição do mouse")
        end
    end
    
    -- Se não encontrou inimigo ou auto aim desativado, usa a posição do mouse
    print("Usando posição do mouse (padrão)")
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

return PlayerManager 