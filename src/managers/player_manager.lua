--[[
    Módulo de gerenciamento do player
]]

local SpritePlayer = require('src.animations.sprite_player')
local PlayerState = require("src.entities.player_state")
local LevelUpModal = require("src.ui.level_up_modal")
local Camera = require("src.config.camera")
local LevelUpAnimation = require("src.animations.level_up_animation")
local Constants = require("src.config.constants") -- <<< ADICIONADO para SLOT_IDS

-- Função auxiliar para contar elementos em qualquer tabela (inclusive dicionários)
local function getTableSize(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

local PlayerManager = {
    -- Referência ao player sprite
    player = nil,

    -- REMOVIDO: class não é mais armazenado aqui
    -- class = nil,

    -- Estado do player (será criado em setupGameplay)
    state = nil,

    -- Game Stats
    gameTime = 0,

    -- Tabela para guardar instâncias de habilidades de runas EQUIPADAS
    activeRuneAbilities = {},

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
    regenInterval = 1.0,  -- Intervalo de regeneração em segundos
    regenAmount = 1,      -- Quantidade fixa de HP recuperado
    accumulatedRegen = 0, -- HP acumulado para regeneração

    -- Collection
    radius = 25,
    collectionRadius = 100, -- Raio base para coletar prismas

    -- Mouse tracking
    lastMouseX = 0,
    lastMouseY = 0,

    -- Mouse pressed tracking
    originalAutoAttackState = false, -- Guarda o estado original do auto-ataque
    originalAutoAimState = false,    -- Guarda o estado original do auto-aim
    previousLeftButtonState = false, -- Estado do botão esquerdo no frame anterior

    -- Weapons (equippedWeapon será definido em setupGameplay)
    equippedWeapon = nil,
    -- REMOVIDO: availableWeapons não é mais usado aqui
    -- availableWeapons = { ... },

    -- Level Up Animation
    isLevelingUp = false,
    levelUpAnimation = nil,

    -- <<< ADICIONADO: Managers injetados >>>
    inputManager = nil,
    enemyManager = nil,
    floatingTextManager = nil,
    inventoryManager = nil,
    hunterManager = nil,
    itemDataManager = nil
}
PlayerManager.__index = PlayerManager -- <<< ADICIONADO __index >>>

--- Cria uma nova instância BÁSICA do PlayerManager.
--- A configuração real do jogador acontece em setupGameplay.
function PlayerManager:new()
    print("[PlayerManager] Creating new instance...")
    local instance = setmetatable({}, PlayerManager) -- <<< USAR PlayerManager aqui >>>

    -- Inicializa propriedades básicas com valores padrão/vazios
    instance.player = nil
    instance.state = nil
    instance.gameTime = 0
    instance.activeRuneAbilities = {}
    instance.autoAttack = false
    instance.autoAttackEnabled = false
    instance.autoAim = false
    instance.autoAimEnabled = false
    instance.lastDamageTime = 0
    instance.damageCooldown = 5.0 -- <<< DEFINIR VALOR PADRÃO damageCooldown >>>
    instance.lastRegenTime = 0
    instance.regenInterval = 1.0  -- <<< DEFINIR VALOR PADRÃO regenInterval >>>
    instance.regenAmount = 1      -- <<< DEFINIR VALOR PADRÃO regenAmount >>>
    instance.accumulatedRegen = 0
    instance.radius = 25
    instance.collectionRadius = 100 -- <<< DEFINIR VALOR PADRÃO collectionRadius >>>
    instance.lastMouseX = 0
    instance.lastMouseY = 0
    instance.originalAutoAttackState = false
    instance.originalAutoAimState = false
    instance.previousLeftButtonState = false
    instance.equippedWeapon = nil
    instance.isLevelingUp = false
    instance.levelUpAnimation = LevelUpAnimation:new() -- Cria a instância da animação aqui

    -- Carrega recursos do player sprite (pode ser feito uma vez globalmente também)
    SpritePlayer.load()

    -- Injeta managers vazios inicialmente (serão preenchidos pelo Bootstrap/Registry)
    instance.inputManager = nil
    instance.enemyManager = nil
    instance.floatingTextManager = nil
    instance.inventoryManager = nil
    instance.hunterManager = nil
    instance.itemDataManager = nil

    print("[PlayerManager] Instance created (awaiting setupGameplay).")
    return instance
end

--- Configura o jogador para o gameplay com base nos dados de um caçador específico.
--- Chamado pela GameplayScene após a inicialização dos managers.
--- @param registry ManagerRegistry Instância do registro de managers.
--- @param hunterId string ID do caçador a ser configurado.
function PlayerManager:setupGameplay(registry, hunterId)
    print(string.format("[PlayerManager] Setting up gameplay for hunter ID: %s", hunterId))

    -- 1. Obtém os managers necessários do Registry
    self.inputManager = registry:get("inputManager")
    self.enemyManager = registry:get("enemyManager")
    self.floatingTextManager = registry:get("floatingTextManager")
    self.inventoryManager = registry:get("inventoryManager") -- Mantém se necessário para outras funções
    self.hunterManager = registry:get("hunterManager")
    self.itemDataManager = registry:get("itemDataManager")

    -- Validação crucial das dependências
    if not self.inputManager or not self.enemyManager or not self.floatingTextManager or
        not self.hunterManager or not self.itemDataManager then
        error("ERRO CRÍTICO [PlayerManager:setupGameplay]: Falha ao obter um ou mais managers do Registry!")
    end
    print("  - Managers obtained from Registry.")

    -- 2. Obtém dados do Caçador
    local hunterData = self.hunterManager.hunters and self.hunterManager.hunters[hunterId]
    local equippedItems = self.hunterManager:getEquippedItems(hunterId)
    local finalStats = self.hunterManager:getHunterFinalStats(hunterId)

    if not hunterData or not equippedItems or not finalStats or not next(finalStats) then
        error(string.format(
            "ERRO CRÍTICO [PlayerManager:setupGameplay]: Falha ao obter dados completos para hunter ID: %s", hunterId))
    end
    print(string.format("  - Hunter data loaded. Name: %s, Rank: %s", hunterData.name, hunterData.finalRankId))

    -- 3. Inicializa PlayerState com os stats finais
    self.state = PlayerState:new(finalStats)
    if not self.state then
        error(string.format("ERRO CRÍTICO [PlayerManager:setupGameplay]: Falha ao criar PlayerState para hunter ID: %s",
            hunterId))
    end
    print(string.format("  - PlayerState initialized. HP: %d/%d, Speed: %.2f",
        self.state.currentHealth, self.state:getTotalHealth(), self.state:getTotalSpeed()))

    -- 4. Cria a instância do Sprite do Jogador
    self.player = SpritePlayer.newConfig({
        position = { x = love.graphics.getWidth() / 2, y = love.graphics.getHeight() / 2 }, -- Posição inicial padrão
        scale = 0.8,
        speed = self.state:getTotalSpeed()                                                  -- Usa a velocidade calculada pelo PlayerState
    })
    print("  - Player Sprite instance created.")

    -- 5. Equipa a Arma
    local weaponItem = equippedItems[Constants.SLOT_IDS.WEAPON]
    if weaponItem then
        local weaponBaseData = self.itemDataManager:getBaseItemData(weaponItem.itemBaseId)
        if weaponBaseData and weaponBaseData.attackClass then
            print(string.format("  - Equipping weapon: %s (Class: %s)", weaponItem.itemBaseId, weaponBaseData
                .attackClass))
            -- Assume que attackClass é o caminho para o require da CLASSE da ARMA (ex: "src.items.weapons.bow")
            local WeaponClass = require(weaponBaseData.attackClass)
            if WeaponClass then
                -- Cria uma instância da classe da arma
                self.equippedWeapon = setmetatable({}, { __index = WeaponClass })
                -- Chama o método :equip DA INSTÂNCIA da arma, passando o PlayerManager
                self.equippedWeapon:equip(self, weaponItem)       -- Passa a instância do item equipado
                self.state:updateWeaponStats(self.equippedWeapon) -- Atualiza stats baseados na arma equipada
                print(string.format("    - Weapon '%s' equipped successfully.", self.equippedWeapon.name))
            else
                print(string.format("    - ERRO: Não foi possível carregar a classe da arma: %s",
                    weaponBaseData.attackClass))
            end
        else
            print(string.format("    - AVISO: Dados base ou 'attackClass' não encontrados para a arma equipada: %s",
                weaponItem.itemBaseId))
        end
    else
        print("  - AVISO: Nenhuma arma equipada encontrada para o caçador.")
        self.equippedWeapon = nil
    end

    -- 6. Inicializa Runas EQUIPADAS (CRIA INSTÂNCIAS DE HABILIDADES)
    self.activeRuneAbilities = {}                                       -- Limpa habilidades anteriores
    print("  - Initializing EQUIPPED rune abilities...")
    local equippedItems = self.hunterManager:getEquippedItems(hunterId) -- Pega itens equipados
    local maxRuneSlots = self.state.runeSlots or 0

    for i = 1, maxRuneSlots do
        local slotId = Constants.SLOT_IDS.RUNE .. i -- Ex: "rune_1"
        local runeItem = equippedItems[slotId]
        if runeItem then
            local runeBaseData = self.itemDataManager:getBaseItemData(runeItem.itemBaseId)
            if runeBaseData and runeBaseData.abilityClass then
                print(string.format("    - Activating rune '%s' in slot %d. Ability class: %s", runeItem.itemBaseId, i,
                    runeBaseData.abilityClass))
                local AbilityClass = require(runeBaseData.abilityClass)
                if AbilityClass then
                    -- Cria a instância da habilidade e armazena por slotId
                    self.activeRuneAbilities[slotId] = AbilityClass:new(self, runeItem)
                else
                    print(string.format("      - ERRO: Não foi possível carregar a classe da habilidade: %s",
                        runeBaseData.abilityClass))
                end
            else
                -- Avisa se falta abilityClass, mas o item está equipado
                print(string.format("    - AVISO: Runa '%s' no slot %d não possui 'abilityClass' ou dados base.",
                    runeItem.itemBaseId or 'ID Desconhecido', i))
            end
        end
    end
    print(string.format("  - Rune activation complete. %d active rune abilities.", getTableSize(self.activeRuneAbilities)))

    -- 7. Inicializa outros componentes que dependem do PlayerManager
    -- Camera:init() -- Câmera é inicializada pela GameplayScene agora
    LevelUpModal:init(self, self.inputManager)
    print("  - LevelUpModal initialized.")

    print(string.format("[PlayerManager] Gameplay setup for hunter '%s' complete.", hunterData.name))
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

    -- Update ATIVAS rune abilities (baseado nos slots equipados)
    -- Itera sobre as habilidades ativas que foram criadas em setupGameplay (ou quando equipadas)
    for slotId, abilityInstance in pairs(self.activeRuneAbilities) do
        abilityInstance:update(dt, self.enemyManager.enemies)
        -- Executa a runa automaticamente se o cooldown zerar
        if abilityInstance.cooldownRemaining and abilityInstance.cooldownRemaining <= 0 then
            abilityInstance:cast(self.player.position.x, self.player.position.y)
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

    -- Desenha as HABILIDADES ATIVAS das runas equipadas
    for slotId, abilityInstance in pairs(self.activeRuneAbilities) do
        abilityInstance:draw()
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
        "Runas Ativas (Equipadas): %d\n\n" ..

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
        PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.attackInstance and
        PlayerManager.equippedWeapon.attackInstance.damageType or "Nenhum",
        PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.attackInstance and
        PlayerManager.equippedWeapon.attackInstance.cooldownRemaining or 0,
        PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.attackInstance and
        PlayerManager.equippedWeapon.attackInstance.cooldown or 0,
        PlayerManager.autoAttackEnabled and "Ativado" or "Desativado",
        PlayerManager.autoAimEnabled and "Ativado" or "Desativado",
        PlayerManager.equippedWeapon and PlayerManager.equippedWeapon.attackInstance and
        PlayerManager.equippedWeapon.attackInstance:getPreview() and "Ativado" or "Desativado",
        getTableSize(self.activeRuneAbilities),

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
    if not self.state then return end -- <<< ADICIONADO: Verifica se state existe
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
    if not self.state then return end -- <<< ADICIONADO: Verifica se state existe
    if self.autoAttack and self.equippedWeapon and self.equippedWeapon.attackInstance then
        -- Monta a tabela de argumentos para cast usando o ângulo recebido
        local args = {
            angle = currentAngle
        }

        -- Chama cast com a tabela de argumentos
        self.equippedWeapon.attackInstance:cast(args)
    end
end

-- Funções de gerenciamento de vida
function PlayerManager:isAlive()
    return self.state and self.state.isAlive -- <<< ADICIONADO: Verifica se state existe
end

function PlayerManager:takeDamage(amount, source)
    if not self.state then return end -- <<< ADICIONADO: Verifica se state existe
    local damageTaken = self.state:takeDamage(amount)
    if damageTaken > 0 then
        self.lastDamageTime = self.gameTime -- Atualiza o tempo do último dano
        self.lastRegenTime = 0              -- Reseta o timer de regeneração
        self.accumulatedRegen = 0

        -- Mostra texto flutuante de dano
        if self.floatingTextManager then -- <<< ADICIONADO: Verifica se floatingTextManager existe
            self.floatingTextManager:addText(
                self.player.position.x,
                self.player.position.y - 40, -- Posição do texto de dano
                "-" .. damageTaken,
                false,
                nil,
                { 1, 0, 0 } -- Cor vermelha para dano
            )
        end
        print(string.format("Player levou %d de dano de %s. HP restante: %d/%d", damageTaken, source or "Desconhecido",
            self.state.currentHealth, self.state:getTotalHealth()))
    end

    if not self.state.isAlive then
        print("Player Morreu!")
        -- TODO: Implementar lógica de morte (ex: tela de game over)
    end
end

-- Funções de experiência e level
function PlayerManager:addExperience(amount)
    if not self.state then return end -- <<< ADICIONADO: Verifica se state existe
    local leveledUp = self.state:addExperience(amount)
    if leveledUp then
        self:onLevelUp()
    end
end

--[[ Função chamada quando o PlayerState indica um level up ]]
function PlayerManager:onLevelUp()
    if not self.state then return end -- <<< ADICIONADO: Verifica se state existe
    -- Efeitos visuais e sonoros de level up
    if self.floatingTextManager then  -- <<< ADICIONADO: Verifica se floatingTextManager existe
        self.floatingTextManager:addText(
            self.player.position.x,
            self.player.position.y - self.radius - 30,
            "LEVEL UP!",
            true,
            self.player.position,
            { 1, 1, 0 }
        )
    end

    -- Inicia a animação de level up (que então mostrará o modal)
    self.isLevelingUp = true
    if self.levelUpAnimation then -- <<< ADICIONADO: Verifica se levelUpAnimation existe
        self.levelUpAnimation:start(self.player.position)
    end

    -- Log para debug
    print(string.format("[PlayerManager] Level up para %d! Próximo nível em %d XP.", self.state.level,
        self.state.experienceToNextLevel))
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
    -- <<< ADICIONADO: Verificações de existência para managers >>>
    if self.autoAim and self.enemyManager and self.player and self.player.position then
        local closestEnemy = self:findClosestEnemy(self.player.position, self.enemyManager.enemies)
        if closestEnemy then
            return closestEnemy.position
        end
    end
    -- Se autoAim desativado, mira não encontrada, ou managers/player não disponíveis, usa o mouse
    if self.inputManager then
        return self.inputManager:getMouseWorldPosition()
    else
        -- Fallback muito básico se InputManager não estiver pronto
        print("AVISO [getTargetPosition]: InputManager não disponível, usando posição padrão (0,0).")
        return { x = 0, y = 0 }
    end
end

function PlayerManager:leftMouseClicked(x, y)
    -- Nada a fazer aqui por enquanto, a lógica foi movida para update
end

function PlayerManager:leftMouseReleased(x, y)
    -- Nada a fazer aqui por enquanto, a lógica foi movida para update
end

-- Retorna a posição de colisão do player (nos pés do sprite)
function PlayerManager:getCollisionPosition()
    if not self.player or not self.player.position then -- <<< ADICIONADO: Verifica se player existe
        print("AVISO [getCollisionPosition]: Player não inicializado, retornando posição padrão.")
        return { position = { x = 0, y = 0 }, radius = self.radius }
    end
    return {
        position = {
            x = self.player.position.x,
            y = self.player.position.y + 25,
        },
        radius = self.radius
    }
end

-- NOTE: Funções equipWeapon e switchWeapon mantidas mas podem precisar de revisão/remoção

-- Adiciona ao final da função love.keypressed (MANTER por enquanto, mas switchWeapon pode não funcionar)
function PlayerManager:keypressed(key)
    -- Teclas numéricas para trocar armas (PODE NÃO FUNCIONAR MAIS)
    if key >= "1" and key <= "9" then
        -- local index = tonumber(key)
        -- self:switchWeapon(index) -- Chamada removida/comentada pois depende de availableWeapons
        print("AVISO: Troca de arma via teclas numéricas desabilitada temporariamente.")
    end

    -- Tecla de teste para subir de nível (F1)
    if key == "f1" then
        if self.state then -- Garante que o estado existe
            print("[DEBUG] Adicionando XP para forçar level up...")
            local xpNeeded = self.state.experienceToNextLevel - self.state.experience
            self:addExperience(math.max(1, xpNeeded))
        else
            print("[DEBUG] ERRO: Não é possível adicionar XP, PlayerState não inicializado.")
        end
    end
end

-- Adiciona um item ao inventário do jogador.
-- Delega a lógica para o InventoryManager.
-- @param itemBaseId (string): O ID base do item a ser adicionado.
-- @param quantity (number): A quantidade a ser adicionada.
function PlayerManager:addInventoryItem(itemBaseId, quantity)
    -- <<< REMOVIDO: inventoryManager agora é propriedade de self >>>
    -- if not self.inventoryManager then
    --     print("ERRO: InventoryManager não inicializado!")
    --     return 0 -- Retorna 0 adicionado em caso de erro
    -- end

    -- <<< ADICIONADO: Usa self.inventoryManager e self.itemDataManager >>>
    if not self.inventoryManager or not self.itemDataManager then
        print("ERRO [addInventoryItem]: InventoryManager ou ItemDataManager não inicializado!")
        return 0
    end

    -- Obtém nome ANTES de adicionar, caso precise para logs/mensagens
    local baseData = self.itemDataManager:getBaseItemData(itemBaseId)
    local itemName = (baseData and baseData.name) or itemBaseId -- Fallback para o ID

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
    -- self.inventoryManager:printInventory() -- REMOVIDO: printInventory não existe mais

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

-- Função auxiliar para contar elementos em uma tabela (necessária para pairs)
local function table_size(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

return PlayerManager
