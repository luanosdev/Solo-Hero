--[[
    Módulo de gerenciamento do player
]]

local SpritePlayer = require('src.animations.sprite_player')
local Warrior = require('src.classes.player.warrior')
local PlayerState = require("src.entities.player_state")
local LevelUpModal = require("src.ui.level_up_modal")
local Camera = require("src.config.camera")
local WoodenSword = require("src.items.weapons.wooden_sword")
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local LevelUpAnimation = require("src.animations.level_up_animation")
local ManagerRegistry = require("src.managers.manager_registry")

local PlayerManager = {
    -- Referência ao player sprite
    player = nil,
    
    -- Classe atual do player
    class = nil,
    
    -- Estado do player
    state = nil,
    
    -- Game Stats
    gameTime = 0,
    
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
    originalAutoAttackState = false, -- Guarda o estado original do auto-ataque
    originalAutoAimState = false, -- Guarda o estado original do auto-aim
    previousLeftButtonState = false, -- Estado do botão esquerdo no frame anterior
    
    -- Weapons
    equippedWeapon = nil,
    availableWeapons = {
        [1] = WoodenSword,
    },

    -- Level Up Animation
    isLevelingUp = false,
    levelUpAnimation = nil
}

-- Inicializa o player manager
function PlayerManager:init()
    self.inputManager = ManagerRegistry:get("inputManager")
    self.enemyManager = ManagerRegistry:get("enemyManager")
    self.floatingTextManager = ManagerRegistry:get("floatingTextManager")

    -- Inicializa a classe do player (Warrior como padrão inicial)
    self:initializeClass(Warrior)
    
    -- Carrega recursos do player sprite
    SpritePlayer.load()
    
    -- Cria configuração do player sprite
    self.player = SpritePlayer.newConfig({
        position = {
            x = love.graphics.getWidth() / 2,
            y = love.graphics.getHeight() / 2,
        },
        scale = 0.8,
        speed = self.state:getTotalSpeed()
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
    
    -- Inicializa os modais
    LevelUpModal:init(self, self.inputManager)
    
    -- Inicializa a animação de level up
    self.levelUpAnimation = LevelUpAnimation:new()
end

-- Atualiza o estado do player e da câmera
function PlayerManager:update(dt)
    if not self.state.isAlive then return end
    
    -- Gerenciamento do estado do botão esquerdo do mouse
    local currentLeftButtonState = self.inputManager.mouse.isLeftButtonDown

    -- Botão foi pressionado neste frame?
    if currentLeftButtonState and not self.previousLeftButtonState then
        -- Salva o estado atual das opções de toggle
        self.originalAutoAttackState = self.autoAttackEnabled
        self.originalAutoAimState = self.autoAimEnabled
    end

    -- Botão está sendo segurado?
    if currentLeftButtonState then
        -- Força ataque contínuo e mira no mouse
        self.autoAttack = true
        self.autoAim = false
    else
        -- Botão não está pressionado, usa as configurações de toggle
        self.autoAttack = self.autoAttackEnabled
        self.autoAim = self.autoAimEnabled

        -- Botão foi solto neste frame?
        if not currentLeftButtonState and self.previousLeftButtonState then
            -- A restauração já ocorreu no bloco 'else' acima
            -- Poderíamos garantir que os 'Enabled' reflitam o estado restaurado, mas
            -- como o clique não deve alterar os toggles, não mexemos neles aqui.
            -- self.autoAttackEnabled = self.originalAutoAttackState -- Opcional
            -- self.autoAimEnabled = self.originalAutoAimState     -- Opcional
        end
    end

    -- Atualiza o estado anterior do botão para o próximo frame
    self.previousLeftButtonState = currentLeftButtonState

    -- Atualiza o input manager
    self.inputManager:update(dt)
    
    -- Atualiza o tempo de jogo
    self.gameTime = self.gameTime + dt
    
    -- Atualiza a animação de level up se estiver ativa
    if self.isLevelingUp then
        self.levelUpAnimation:update(dt, self.player.position.x, self.player.position.y)
        if self.levelUpAnimation.isComplete then
            self.isLevelingUp = false
            LevelUpModal:show()
        end
    end
    
    -- Define a posição do alvo (para mira e animação)
    local targetPosition = self:getTargetPosition()

    -- Atualiza o ataque da arma
    if self.equippedWeapon and self.equippedWeapon.attackInstance then
        -- Atualiza o ângulo da habilidade com base no alvo ANTES de atualizar a instância
        local dx = targetPosition.x - self.player.position.x
        local dy = targetPosition.y - self.player.position.y
        local angle = math.atan2(dy, dx)

        self.equippedWeapon.attackInstance:update(dt, angle)
    end
    
    -- Update health recovery
    self:updateHealthRecovery(dt)
    
    -- Update all rune abilities
    for _, rune in ipairs(self.runes) do
        rune:update(dt, self.enemyManager.enemies)
        
        -- Executa a runa automaticamente se o cooldown zerar
        if rune.cooldownRemaining and rune.cooldownRemaining <= 0 then
            rune:cast(self.player.x, self.player.y)
        end
    end

    -- Atualiza o auto attack
    self:updateAutoAttack()

    -- Atualiza o sprite do player passando a posição do alvo
    SpritePlayer.update(self.player, dt, targetPosition)
    
    -- Atualiza a câmera
    Camera:follow(self.player.position, dt)
end

-- Desenha o player e elementos relacionados
function PlayerManager:draw()
    -- Aplica transformação da câmera
    Camera:attach()
    
    -- Desenha o círculo de colisão primeiro (embaixo de tudo)
    local circleY = self.player.position.y + 25 -- Ajusta para ficar nos pés do sprite
    
    -- Salva o estado atual de transformação
    love.graphics.push()
    
    -- Aplica transformação isométrica no círculo
    love.graphics.translate(self.player.position.x, circleY)
    love.graphics.scale(1, 0.5) -- Achata o círculo verticalmente para efeito isométrico
    
    -- Desenha o círculo com efeito isométrico
    love.graphics.setColor(0, 0.5, 1, 0.3) -- Azul semi-transparente
    love.graphics.circle("fill", 0, 0, self.radius)
    love.graphics.setColor(0, 0.7, 1, 0.5) -- Azul mais escuro para a borda
    love.graphics.circle("line", 0, 0, self.radius)
    
    -- Restaura o estado de transformação
    love.graphics.pop()
    
    -- Desenha a animação de level up se estiver ativa
    if self.isLevelingUp then
        self.levelUpAnimation:draw(self.player.position.x, self.player.position.y)
    end
    
    -- Desenha todas as runas (aura, orbital, etc) ATRÁS do jogador
    for _, rune in ipairs(self.runes) do
        rune:draw()
    end
    
    -- Desenha o sprite do player
    love.graphics.setColor(1, 1, 1, 1)
    SpritePlayer.draw(self.player)
    
    -- Desenha a arma equipada e seu ataque
    if self.equippedWeapon and self.equippedWeapon.attackInstance then
        self.equippedWeapon.attackInstance:draw()
    end
    
    -- Draw health bar
    local healthBarWidth = 60
    local healthBarHeight = 8
    local healthBarX = PlayerManager.player.position.x - healthBarWidth/2
    local healthBarY = PlayerManager.player.position.y - PlayerManager.radius - 10

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
                PlayerManager.player.position.x - healthBarWidth/2, 
                PlayerManager.player.position.y - PlayerManager.radius - 5,
                healthBarWidth, 
                2
            )
            
            -- Cooldown bar fill
            love.graphics.setColor(1, 0, 0, 0.8)
            love.graphics.rectangle("fill", 
                PlayerManager.player.position.x - healthBarWidth/2, 
                PlayerManager.player.position.y - PlayerManager.radius - 5,
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
        PlayerManager.player.position.x, PlayerManager.player.position.y,
        PlayerManager.player.animation.direction,
        PlayerManager.player.animation.state,
        PlayerManager.player.animation.currentFrame,
        PlayerManager.player.animation.isMovingBackward and "Backward" or "Forward",
        
        -- Valores de level (agora em PlayerState)
        PlayerManager.state.level,
        PlayerManager.state.experience,
        PlayerManager.state.experienceToNextLevel,
        PlayerManager.state.kills,
        PlayerManager.state.gold,
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

function PlayerManager:updateHealthRecovery(dt)    
    -- Atualiza o tempo desde o último dano
    self.lastDamageTime = self.lastDamageTime + dt

    -- Atualiza regeneração de vida
    if self.state.currentHealth < self.state:getTotalHealth() and self.lastDamageTime >= self.damageCooldown then
        local hpPerSecond = self.state:getTotalHealthRegen()
        self.accumulatedRegen = self.accumulatedRegen + (hpPerSecond * dt)
        
        -- Se acumulou pelo menos 1 HP, recupera
        if self.accumulatedRegen >= 1 then
            self.floatingTextManager:addText(
                self.player.position.x,
                self.player.position.y - self.radius - 60,
                "+1",
                false,
                self.player.position,
                {0, 1, 0}
            )
            self.state:heal(1)
            self.accumulatedRegen = self.accumulatedRegen - 1
        end
    else
        self.accumulatedRegen = 0
    end
end

function PlayerManager:updateAutoAttack()
    if self.autoAttack or self.inputManager.mouse.leftButton then
        local cooldown = self.equippedWeapon.attackInstance:getCooldownRemaining()
        if cooldown <= 0 then
            -- Apenas ataca, a mira já foi definida em PlayerManager:update
            self:attack()
        end
    end
end

-- Inicializa uma nova classe para o player
function PlayerManager:initializeClass(classDefinition)
    self.class = classDefinition
    
    -- Inicializa estado com stats base
    self.state = PlayerState
    self.state:init(classDefinition:getBaseStats())
end

-- Funções de gerenciamento de vida
function PlayerManager:isAlive()
    return self.state.isAlive
end

function PlayerManager:takeDamage(amount)
    self.lastDamageTime = 0
    return self.state:takeDamage(amount)
end


-- Funções de habilidades
function PlayerManager:addRune(rune)
    if not rune then return end
    table.insert(self.runes, rune)
    if rune.init then
        rune:init(self)
    end
end

-- Função para atacar com a arma equipada
function PlayerManager:attack()
    if not self.equippedWeapon or not self.equippedWeapon.attackInstance then
        error("[Erro] [PlayerManager.attack] Nenhuma arma ou instância de ataque encontrada")
        return false
    end
    
    -- A direção do ataque já foi definida em PlayerManager:update com base no targetPosition
    local success = self.equippedWeapon.attackInstance:cast() -- Não precisa mais passar inimigos aqui

    if success then
        -- Inicia a animação de ataque do sprite
        SpritePlayer.startAttackAnimation(self.player)
    end

    return success
end

-- Funções de experiência e level
function PlayerManager:addExperience(amount)
    local leveledUp = self.state:addExperience(amount)
    if leveledUp then
        self:onLevelUp()
    end
end

--[[ Função chamada quando o PlayerState indica um level up ]]
function PlayerManager:onLevelUp()
    -- Efeitos visuais e sonoros de level up
    self.floatingTextManager:addText(
        self.player.position.x,
        self.player.position.y - self.radius - 30,
        "LEVEL UP!",
        true,
        self.player.position,
        {1, 1, 0}
    )

    -- Inicia a animação de level up (que então mostrará o modal)
    self.isLevelingUp = true
    self.levelUpAnimation:start(self.player.position)

    -- Log para debug
    print(string.format("[PlayerManager] Level up para %d! Próximo nível em %d XP.", self.state.level, self.state.experienceToNextLevel))
end

-- Funções de controle
function PlayerManager:toggleAbilityAutoCast()
    self.autoAttackEnabled = not self.autoAttackEnabled
    self.autoAttack = self.autoAttackEnabled
end

function PlayerManager:toggleAbilityVisual()
    if self.equippedWeapon and self.equippedWeapon.attackInstance then
        self.equippedWeapon.attackInstance:togglePreview()
    end
end

function PlayerManager:toggleAutoAim()
    self.autoAimEnabled = not self.autoAimEnabled
    self.autoAim = self.autoAimEnabled
end

--[[
    Função para obter a posição do alvo
    Se o auto aim estiver ativado, procura o inimigo mais próximo
    Se não estiver ativado, usa a posição do mouse
]]
function PlayerManager:getTargetPosition()
    -- Obtém a posição atual do mouse em coordenadas do mundo
    local mouseScreenX, mouseScreenY = self.inputManager:getMousePosition()
    local mouseWorldX, mouseWorldY = Camera:screenToWorld(mouseScreenX, mouseScreenY)

    -- Se o auto aim estiver ativado, procura o inimigo mais próximo
    if self.autoAim then
        local enemies = self.enemyManager:getEnemies()
        local closestEnemy = nil
        local closestDistanceSq = math.huge -- Usar distância quadrada para eficiência
        
        for _, enemy in ipairs(enemies) do
            if enemy.isAlive then
                local dx = enemy.position.x - self.player.position.x
                local dy = enemy.position.y - self.player.position.y
                local distanceSq = dx * dx + dy * dy -- Comparar quadrado da distância
                
                if distanceSq < closestDistanceSq then
                    closestDistanceSq = distanceSq
                    closestEnemy = enemy
                end
            end
        end
        
        -- Se encontrou um inimigo, retorna a posição dele (mundo)
        if closestEnemy then
            return { x = closestEnemy.position.x, y = closestEnemy.position.y }
        end
    end
    
    -- Se não encontrou inimigo ou auto aim desativado, usa a posição do mouse (mundo)
    return { x = mouseWorldX, y = mouseWorldY }
end

function PlayerManager:leftMouseClicked(x, y)
    -- Nada a fazer aqui por enquanto, a lógica foi movida para update
end

function PlayerManager:leftMouseReleased(x, y)
    -- Nada a fazer aqui por enquanto, a lógica foi movida para update
end

-- Retorna a posição de colisão do player (nos pés do sprite)
function PlayerManager:getCollisionPosition()
    return {
        position = {
            x = self.player.position.x,
            y = self.player.position.y + 25,
        },
        radius = self.radius
    }
end

-- Função para equipar uma nova arma
function PlayerManager:equipWeapon(weaponClass)
    if self.equippedWeapon then
        -- Reseta a instância atual
        self.equippedWeapon.attackInstance = nil
    end
    
    -- Cria uma nova instância da arma
    self.equippedWeapon = setmetatable({}, { __index = weaponClass })
    self.equippedWeapon:equip(self)
    
    -- Atualiza os atributos do player com os da nova arma
    self.state:updateWeaponStats(self.equippedWeapon)
    
    -- Exibe mensagem informativa
    print(string.format("Arma trocada para: %s", self.equippedWeapon.name))
end

-- Função para trocar arma por índice
function PlayerManager:switchWeapon(index)
    local weapon = self.availableWeapons[index]
    if weapon then
        self:equipWeapon(weapon)
    end
end

-- Adiciona ao final da função love.keypressed
function PlayerManager:keypressed(key)
    -- Teclas numéricas para trocar armas
    if key >= "1" and key <= "9" then
        local index = tonumber(key)
        self:switchWeapon(index)
    end
    
    -- Tecla de teste para subir de nível (F1)
    if key == "f1" then
        print("[DEBUG] Adicionando XP para forçar level up...")
        -- Adiciona a quantidade de XP necessária para o próximo nível + 1
        local xpNeeded = self.state.experienceToNextLevel - self.state.experience
        self:addExperience(math.max(1, xpNeeded))
    end
end

return PlayerManager