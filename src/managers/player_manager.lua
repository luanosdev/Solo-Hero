--[[
    Módulo de gerenciamento do player
]]

local SpritePlayer = require('src.animations.sprite_player')
local Warrior = require('src.classes.player.warrior')
local PlayerState = require("src.entities.player_state")
local LevelUpModal = require("src.ui.level_up_modal")
local Camera = require("src.config.camera")
local WoodenSword = require("src.items.weapons.wooden_sword")
local Bow = require("src.items.weapons.bow")
local DualDaggers = require("src.items.weapons.dual_daggers")
local Hammer = require("src.items.weapons.hammer")
local Flamethrower = require("src.items.weapons.flamethrower")
local ChainLaser = require("src.items.weapons.chain_laser")
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
        [2] = Bow,
        [3] = DualDaggers,
        [4] = Hammer,
        [5] = Flamethrower,
        [6] = ChainLaser
    },

    -- Level Up Animation
    isLevelingUp = false,
    levelUpAnimation = nil
}

-- Inicializa o player manager
function PlayerManager:init(config)
    config = config or {}
    -- Obtém managers necessários da config
    self.inputManager = config.inputManager 
    self.enemyManager = config.enemyManager 
    self.floatingTextManager = config.floatingTextManager 
    self.inventoryManager = config.inventoryManager

    -- Validação das dependências
    if not self.inputManager or not self.enemyManager or not self.floatingTextManager or not self.inventoryManager then
        error("ERRO CRÍTICO [PlayerManager]: Uma ou mais dependências não foram injetadas!")
    end

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
    local startingWeapon = self.class.startingWeapon
    if startingWeapon then
        print("Equipando arma inicial:", startingWeapon.name)
        self.equippedWeapon = setmetatable({}, { __index = startingWeapon })
        self.equippedWeapon:equip(self)
    else
        print("AVISO: Nenhuma arma inicial definida para a classe", self.class.name)
    end
    
    -- Inicializa os modais
    LevelUpModal:init(self, self.inputManager)
    
    -- Inicializa a animação de level up
    self.levelUpAnimation = LevelUpAnimation:new()
    print("PlayerManager inicializado.") -- Mensagem final de inicialização
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
    
    -- Define a posição do alvo e calcula o ângulo UMA VEZ
    local targetPosition = self:getTargetPosition()
    local currentAngle = 0
    if self.player and self.player.position then -- Garante que player existe
        local dx = targetPosition.x - self.player.position.x
        local dy = targetPosition.y - self.player.position.y
        currentAngle = math.atan2(dy, dx)
    end

    -- Atualiza o ataque da arma, passando o ângulo calculado
    if self.equippedWeapon and self.equippedWeapon.attackInstance then
        self.equippedWeapon.attackInstance:update(dt, currentAngle)
    end
    
    -- Update health recovery
    self:updateHealthRecovery(dt)
    
    -- Update all rune abilities
    for _, rune in ipairs(self.runes) do
        rune:update(dt, self.enemyManager.enemies)
        
        -- Executa a runa automaticamente se o cooldown zerar
        if rune.cooldownRemaining and rune.cooldownRemaining <= 0 then
            -- A runa precisa da posição do player, não do ângulo de mira
            rune:cast(self.player.position.x, self.player.position.y)
        end
    end

    -- Atualiza o auto attack, passando o ângulo calculado
    self:updateAutoAttack(currentAngle)

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

--[[-
    Atualiza a lógica de recuperação de vida do jogador

    @param dt (number): Delta time
]]
function PlayerManager:updateHealthRecovery(dt)
    -- Verifica se já passou o cooldown após o último dano
    if self.gameTime >= self.lastDamageTime + self.damageCooldown then
        self.lastRegenTime = self.lastRegenTime + dt

        -- Se passou o intervalo de regeneração
        if self.lastRegenTime >= self.regenInterval then
            self.lastRegenTime = self.lastRegenTime - self.regenInterval -- Subtrai o intervalo, mantendo o resto

            -- Calcula a regeneração baseada nos stats usando o método correto
            local effectiveRegen = self.state:getTotalHealthRegen() -- CORRIGIDO: Usar getTotalHealthRegen()
            self.accumulatedRegen = self.accumulatedRegen + effectiveRegen

            -- Se a regeneração acumulada for >= 1, cura o jogador
            local healAmount = math.floor(self.accumulatedRegen)
            if healAmount >= 1 then
                self.state:heal(healAmount)
                self.accumulatedRegen = self.accumulatedRegen - healAmount
                -- Mostra texto flutuante de cura (opcional)
                -- self.floatingTextManager:addText(self.player.position.x, self.player.position.y - 50, "+" .. healAmount .. " HP", false, nil, {0, 1, 0})
            end
        end
    else
        -- Se estiver em cooldown de dano, reseta o timer de regeneração
        self.lastRegenTime = 0
        self.accumulatedRegen = 0
    end
end

-- Modificado para aceitar o ângulo como argumento
function PlayerManager:updateAutoAttack(currentAngle)
    if self.autoAttack and self.equippedWeapon and self.equippedWeapon.attackInstance then
        -- Monta a tabela de argumentos para cast usando o ângulo recebido
        local args = {
            angle = currentAngle
        }

        -- Chama cast com a tabela de argumentos
        self.equippedWeapon.attackInstance:cast(args)
    end
end

-- Inicializa uma nova classe para o player
function PlayerManager:initializeClass(classDefinition)
    self.class = classDefinition

    -- Inicializa estado com stats base
    print(string.format("[PlayerManager] Tentando inicializar PlayerState para classe: %s...", classDefinition.name or "Desconhecida"))
    self.state = PlayerState:new(classDefinition:getBaseStats())
    -- Verifica se self.state foi criado com sucesso
    if self.state then
        print(string.format("[PlayerManager] PlayerState inicializado com sucesso. HP: %d/%d", self.state.currentHealth, self.state:getTotalHealth()))
    else
        print("ERRO CRÍTICO [PlayerManager]: Falha ao inicializar PlayerState! self.state é nil.")
        error("Falha ao inicializar PlayerState") -- Lança um erro real para parar a execução
    end
end

-- Funções de gerenciamento de vida
function PlayerManager:isAlive()
    return self.state.isAlive
end

function PlayerManager:takeDamage(amount, source)
    local damageTaken = self.state:takeDamage(amount)
    if damageTaken > 0 then
        self.lastDamageTime = self.gameTime -- Atualiza o tempo do último dano
        self.lastRegenTime = 0 -- Reseta o timer de regeneração
        self.accumulatedRegen = 0
        
        -- Mostra texto flutuante de dano
        self.floatingTextManager:addText(
            self.player.position.x,
            self.player.position.y - 40, -- Posição do texto de dano
            "-" .. damageTaken,
            false,
            nil,
            {1, 0, 0} -- Cor vermelha para dano
        )
        print(string.format("Player levou %d de dano de %s. HP restante: %d/%d", damageTaken, source or "Desconhecido", self.state.currentHealth, self.state:getTotalHealth()))
    end
    
    if not self.state.isAlive then
        print("Player Morreu!")
        -- TODO: Implementar lógica de morte (ex: tela de game over)
    end
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
    if self.autoAim and self.enemyManager then
        local closestEnemy = self:findClosestEnemy(self.player.position, self.enemyManager.enemies)
        if closestEnemy then
            return closestEnemy.position
        end
    end
    -- Se autoAim desativado, mira não encontrada, ou enemyManager não disponível, usa o mouse
    return self.inputManager:getMouseWorldPosition()
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

-- Adiciona um item ao inventário do jogador.
-- Delega a lógica para o InventoryManager.
-- @param itemBaseId (string): O ID base do item a ser adicionado.
-- @param quantity (number): A quantidade a ser adicionada.
function PlayerManager:addInventoryItem(itemBaseId, quantity)
    if not self.inventoryManager then
        print("ERRO: InventoryManager não inicializado!")
        return 0 -- Retorna 0 adicionado em caso de erro
    end

    -- Obtém nome ANTES de adicionar, caso precise para logs/mensagens
    local baseData = nil
    local itemName = itemBaseId -- Fallback para o ID se não conseguir dados base
    local itemDataMgr = ManagerRegistry:get("itemDataManager") -- Pega o data manager
    if itemDataMgr then
        baseData = itemDataMgr:getBaseItemData(itemBaseId)
        if baseData and baseData.name then
            itemName = baseData.name
        end
    end

    local addedQuantity = self.inventoryManager:addItem(itemBaseId, quantity)

    if addedQuantity < quantity then
        local leftover = quantity - addedQuantity
        print(string.format("Inventário cheio para %s. %d não foram adicionados.", itemName, leftover))
        -- TODO: Lidar com itens que não couberam (ex: dropar no chão?)
        -- Poderia retornar a quantidade que sobrou: return leftover
    else
        print(string.format("Adicionado %d %s ao inventário.", addedQuantity, itemName))
    end

    -- Exibe o estado atual do inventário (para debug)
    self.inventoryManager:printInventory()

    -- Retorna a quantidade que foi realmente adicionada
    return addedQuantity
end

-- Encontra o inimigo mais próximo da posição dada
-- @param position (table): Posição de referência {x, y}
-- @param enemies (table): Lista de inimigos a verificar
-- @return table: O inimigo mais próximo, ou nil se a lista estiver vazia
function PlayerManager:findClosestEnemy(position, enemies)
    local closestEnemy = nil
    local minDistanceSq = math.huge

    if not enemies or #enemies == 0 then
        return nil
    end

    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            local dx = enemy.position.x - position.x
            local dy = enemy.position.y - position.y
            local distanceSq = dx * dx + dy * dy
            if distanceSq < minDistanceSq then
                minDistanceSq = distanceSq
                closestEnemy = enemy
            end
        end
    end
    return closestEnemy
end

--[[ -
    Adiciona uma nova habilidade (runa) à lista de habilidades ativas do jogador.
    @param abilityInstance (table): A instância da habilidade a ser adicionada.
]]
function PlayerManager:addAbility(abilityInstance)
    if not abilityInstance then
        print("AVISO [PlayerManager]: Tentativa de adicionar habilidade nula.")
        return
    end
    table.insert(self.runes, abilityInstance)
    print(string.format("[PlayerManager] Habilidade '%s' adicionada. Total de runas: %d", abilityInstance.name or "Desconhecida", #self.runes))
end

return PlayerManager