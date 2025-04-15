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
    radius = 25,
    collectionRadius = 120, -- Raio base para coletar prismas
    
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
        PlayerManager.state:getTotalDamage(0),
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

        -- Verifica colisão com inimigos
        local enemies = EnemyManager:getEnemies()
        local enemiesHit = 0
        local totalEnemies = 0
        
        print("\n=== DEBUG POSIÇÕES ===")
        print("Posição do jogador:", PlayerManager.player.x, PlayerManager.player.y)
        print("Posição do cone:", PlayerManager.equippedWeapon.attackInstance.area.x, PlayerManager.equippedWeapon.attackInstance.area.y)
        print("Ângulo do cone:", math.deg(PlayerManager.equippedWeapon.attackInstance.area.angle))
        print("Alcance do cone:", PlayerManager.equippedWeapon.attackInstance.area.range)
        
        for _, enemy in ipairs(enemies) do
            if enemy.isAlive then
                totalEnemies = totalEnemies + 1
                -- Verifica se o inimigo está dentro da área de ataque usando isPointInArea
                local isInArea = PlayerManager.equippedWeapon.attackInstance:isPointInArea(enemy.positionX, enemy.positionY)
                
                print(string.format(
                    "Inimigo %d: (%.1f, %.1f) - %s",
                    totalEnemies,
                    enemy.positionX,
                    enemy.positionY,
                    isInArea and "DENTRO" or "FORA"
                ))
                
                if isInArea then
                    enemiesHit = enemiesHit + 1
                    -- Aplica o dano e verifica se o inimigo morreu
                    if PlayerManager.equippedWeapon.attackInstance:applyDamage(enemy) then
                        -- Se o inimigo morreu, atualiza as estatísticas do jogador
                        PlayerManager.kills = PlayerManager.kills + 1
                        PlayerManager.addExperience(enemy.experienceValue)
                        PlayerManager.gold = PlayerManager.gold + math.random(1, 5)
                    end
                end
            end
        end
        
        -- Debug: Mostra informações sobre os inimigos atingidos
        print(string.format(
            "\n=== DEBUG ATAQUE ===\n" ..
            "Total de inimigos: %d\n" ..
            "Inimigos atingidos: %d\n" ..
            "Porcentagem: %.1f%%",
            totalEnemies,
            enemiesHit,
            totalEnemies > 0 and (enemiesHit / totalEnemies) * 100 or 0
        ))
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
end

return PlayerManager 