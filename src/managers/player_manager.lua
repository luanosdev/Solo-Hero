--[[
    Módulo de gerenciamento do player
]]

local SpritePlayer = require('src.animations.sprite_player')
local PlayerState = require("src.entities.player_state")
local LevelUpModal = require("src.ui.level_up_modal")
local elements = require("src.ui.ui_elements")
local Camera = require("src.config.camera")
local LevelUpAnimation = require("src.animations.level_up_animation")
local Constants = require("src.config.constants")

---@class FinalStats
---@field health number Vida máxima final.
---@field attackSpeed number Velocidade de ataque final (ataques por segundo).
---@field moveSpeed number Velocidade de movimento final.
---@field critChance number Chance de crítico final (fração, ex: 0.10 para 10%).
---@field critDamage number Dano crítico final (multiplicador, ex: 1.5 para 150%).
---@field multiAttackChance number Chance de ataque múltiplo final (fração).
---@field expBonus number Bônus de experiência final (multiplicador, ex: 1.0 para 100%).
---@field defense number Defesa final.
---@field healthRegenCooldown number Cooldown de regeneração de vida (segundos).
---@field healthPerTick number Regeneração de vida por tick/segundo final.
---@field healthRegenDelay number Atraso para iniciar a regeneração de vida após dano (segundos).
---@field cooldownReduction number Redução de cooldown final (multiplicador, ex: 1.0 para nenhuma redução).
---@field range number Alcance final (multiplicador).
---@field attackArea number Área de ataque final (multiplicador).
---@field pickupRadius number Raio de coleta final.
---@field healingBonus number Bônus de cura recebida final (multiplicador).
---@field runeSlots number Quantidade final de slots de runa.
---@field luck number Sorte final (multiplicador).
---@field weaponDamage number Dano final da arma (calculado).
---@field _baseWeaponDamage number Dano base da arma (antes de multiplicadores).
---@field _playerDamageMultiplier number Multiplicador de dano total do jogador.
---@field _levelBonus table<string, number>|nil Bônus de atributos ganhos por level up (formato: {statKey = value}).
---@field _fixedBonus table<string, number>|nil Bônus fixos de atributos de outras fontes (formato: {statKey = value}).
---@field _learnedLevelUpBonuses table<string, any>|nil Detalhes dos bônus de level up aprendidos.
---@field equippedItems table<string, any>|nil Itens equipados (formato: {slotId = itemInstance}).
---@field archetypeIds table[]|nil IDs dos arquétipos ativos.

-- Função auxiliar para contar elementos em qualquer tabela (inclusive dicionários)
local function getTableSize(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

---@class PlayerManager
local PlayerManager = {
    -- Referência ao player sprite
    player = nil, ---@type table
    -- Estado do player (será criado em setupGameplay)
    state = nil, ---@class PlayerState
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
    -- Health regeneration
    lastRegenTime = 0,
    regenInterval = 1.0,  -- Intervalo de regeneração em segundos
    accumulatedRegen = 0, -- HP acumulado para regeneração
    -- Tamanho do círculo de colisão
    radius = 25,
    -- Mouse tracking
    lastMouseX = 0,
    lastMouseY = 0,

    -- Mouse pressed tracking
    originalAutoAttackState = false, -- Guarda o estado original do auto-ataque
    originalAutoAimState = false,    -- Guarda o estado original do auto-aim
    previousLeftButtonState = false, -- Estado do botão esquerdo no frame anterior

    -- Weapons (equippedWeapon será definido em setupGameplay)
    equippedWeapon = nil, ---@class BaseWeapon
    -- Level Up Animation
    isLevelingUp = false,
    levelUpAnimation = nil,

    -- Level Up Modal Management
    pendingLevelUps = 0, -- << NOVO: Contador para level ups pendentes

    inputManager = nil, ---@class InputManager
    enemyManager = nil, ---@class EnemyManager
    floatingTextManager = nil, ---@class FloatingTextManager
    inventoryManager = nil, ---@class InventoryManager
    hunterManager = nil, ---@class HunterManager
    itemDataManager = nil, ---@class ItemDataManager
    archetypeManager = nil, ---@class ArchetypeManager

    currentHunterId = nil,            -- <<< ADICIONADO: Para armazenar o ID do caçador ativo

    finalStatsCache = nil,            -- Guarda a última tabela de stats calculada
    statsNeedRecalculation = true,    -- Flag para indicar se o cache precisa ser atualizado
}
PlayerManager.__index = PlayerManager -- <<< ADICIONADO __index >>>

--- Cria uma nova instância BÁSICA do PlayerManager.
--- A configuração real do jogador acontece em setupGameplay.
--- @return PlayerManager
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
    instance.lastRegenTime = 0
    instance.regenInterval = 1.0
    instance.accumulatedRegen = 0
    instance.radius = 25
    instance.lastMouseX = 0
    instance.lastMouseY = 0
    instance.originalAutoAttackState = false
    instance.originalAutoAimState = false
    instance.previousLeftButtonState = false
    instance.equippedWeapon = nil ---@class BaseWeapon
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
    instance.archetypeManager = nil

    instance.finalStatsCache = nil
    instance.statsNeedRecalculation = true
    instance.pendingLevelUps = 0 -- Inicializa contador

    print("[PlayerManager] Instance created (awaiting setupGameplay).")
    return instance
end

--- Configura o jogador para o gameplay com base nos dados de um caçador específico.
--- Chamado pela GameplayScene após a inicialização dos managers.
--- @param registry ManagerRegistry Instância do registro de managers.
--- @param hunterId string ID do caçador a ser configurado.
function PlayerManager:setupGameplay(registry, hunterId)
    print(string.format("[PlayerManager] Setting up gameplay for hunter ID: %s", hunterId))

    -- Armazena o ID do caçador atual
    self.currentHunterId = hunterId

    -- 1. Obtém os managers necessários do Registry
    self.inputManager = registry:get("inputManager") ---@class InputManager
    self.enemyManager = registry:get("enemyManager") ---@class EnemyManager
    self.floatingTextManager = registry:get("floatingTextManager") ---@class FloatingTextManager
    self.inventoryManager = registry:get("inventoryManager") ---@class InventoryManager
    self.hunterManager = registry:get("hunterManager") ---@class HunterManager
    self.itemDataManager = registry:get("itemDataManager") ---@class ItemDataManager
    self.archetypeManager = registry:get("archetypeManager") ---@class ArchetypeManager

    -- Validação crucial das dependências
    if not self.inputManager or not self.enemyManager or not self.floatingTextManager or
        not self.hunterManager or not self.itemDataManager then
        error("ERRO CRÍTICO [PlayerManager:setupGameplay]: Falha ao obter um ou mais managers do Registry!")
    end

    -- 2. Obtém dados do Caçador
    local hunterData = self.hunterManager.hunters and self.hunterManager.hunters[hunterId]
    local equippedItems = self.hunterManager:getEquippedItems(hunterId)
    local finalStats = self.hunterManager:getHunterFinalStats(hunterId)

    if not hunterData or not equippedItems or not finalStats or not next(finalStats) then
        error(string.format(
            "ERRO CRÍTICO [PlayerManager:setupGameplay]: Falha ao obter dados completos para hunter ID: %s", hunterId))
    end

    -- 3. Inicializa PlayerState com os stats finais
    self.state = PlayerState:new(finalStats) ---@class PlayerState
    if not self.state then
        error(string.format("ERRO CRÍTICO [PlayerManager:setupGameplay]: Falha ao criar PlayerState para hunter ID: %s",
            hunterId))
    end

    -- 4. Cria a instância do Sprite do Jogador
    local finalSpeed = finalStats.moveSpeed
    print(string.format("  - Player final speed for sprite: %.2f", finalSpeed))
    self.player = SpritePlayer.newConfig({
        position = { x = love.graphics.getWidth() / 2, y = love.graphics.getHeight() / 2 },
        scale = 0.8,
        speed = finalSpeed -- Usa a velocidade calculada
    })
    print(string.format("  - Player Sprite instance created. Type of self.player: %s", type(self.player)))

    -- 5. Equipa a Arma
    local weaponItem = equippedItems[Constants.SLOT_IDS.WEAPON]

    if weaponItem then
        -- Constrói o caminho para a CLASSE da arma (ex: src.items.weapons.dual_daggers)
        local weaponClassPath = string.format("src.items.weapons.%s", weaponItem.itemBaseId)

        -- Tenta carregar a classe da arma
        local success, WeaponClass = pcall(require, weaponClassPath)

        if success and WeaponClass then
            -- OBS: Assumindo que a classe da arma tem um método :new(config) que aceita itemBaseId
            local weaponInstance = WeaponClass:new({ itemBaseId = weaponItem.itemBaseId })

            if weaponInstance then
                print(string.format("    - Weapon instance created for '%s'.", weaponItem.itemBaseId))
                -- Armazena a instância da arma
                self.equippedWeapon = weaponInstance

                if self.equippedWeapon.equip then -- Verifica se o método existe
                    self.equippedWeapon:equip(self, weaponItem)
                else
                    error(string.format("ERRO CRÍTICO: O método :equip não foi encontrado na classe da arma '%s'!",
                        weaponClassPath))
                end
            else
                error(string.format("ERRO: Falha ao criar a instância da arma '%s' usando :new().", weaponClassPath))
            end
        else
            error(string.format("ERRO CRÍTICO: Não foi possível carregar a classe da arma: %s. Detalhe: %s",
                weaponClassPath, tostring(WeaponClass))) -- WeaponClass aqui conterá a mensagem de erro do pcall
            self.equippedWeapon = nil
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
                    error(string.format("ERRO: Não foi possível carregar a classe da habilidade: %s",
                        runeBaseData.abilityClass))
                end
            else
                -- Avisa se falta abilityClass, mas o item está equipado
                error(string.format("AVISO: Runa '%s' no slot %d não possui 'abilityClass' ou dados base.",
                    runeItem.itemBaseId or 'ID Desconhecido', i))
            end
        end
    end
    print(string.format("  - Rune activation complete. %d active rune abilities.", getTableSize(self.activeRuneAbilities)))

    -- 7. Inicializa outros componentes que dependem do PlayerManager
    LevelUpModal:init(self, self.inputManager)

    print(string.format("[PlayerManager] Gameplay setup for hunter '%s' complete.", hunterData.name))

    -- Preeche a vida do player com o valor final de health
    local currentFinalStats = self:getCurrentFinalStats()
    self.state.currentHealth = currentFinalStats.health

    -- Invalida o cache de stats
    self:invalidateStatsCache()
end

-- Atualiza o estado do player e da câmera
function PlayerManager:update(dt)
    if not self.state or not self.state.isAlive then
        return
    end
    self.gameTime = self.gameTime + dt

    -- Tenta mostrar o modal de level up se houver pendências e o modal não estiver visível
    self:tryShowLevelUpModal() -- << NOVO: Chamada para gerenciar a fila de modais

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
    if self.player and self.player.position then
        Camera:follow(self.player.position, dt)
    end
end

-- Desenha o player e elementos relacionados
function PlayerManager:draw()
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

    -- Desenha a barra de vida em cima do player caso a vida nao esteja cheia
    local finalStats = self:getCurrentFinalStats()
    if self.state and self.state.currentHealth < finalStats.health then
        elements.drawResourceBar({
            x = self.player.position.x - 25,
            y = self.player.position.y - 40,
            width = 50,
            height = 3,
            current = self.state.currentHealth,
            maxValue = finalStats.health,
            showText = false,
            cacheEnabled = true,
            entityId = "player"
        })
    end

    -- Desenha a animação de level up se estiver ativa
    if self.isLevelingUp then
        self.levelUpAnimation:draw(self.player.position.x, self.player.position.y)
    end

    -- Desenha as HABILIDADES ATIVAS das runas equipadas
    for slotId, abilityInstance in pairs(self.activeRuneAbilities) do
        abilityInstance:draw()
    end

    -- Desenha o sprite do player
    if self.player then
        -- Correção: Chama a função draw do MÓDULO SpritePlayer, passando a instância self.player
        -- REMOVIDOS: Logs antes de desenhar o sprite
        SpritePlayer.draw(self.player)
    else
        print("PlayerManager:draw - self.player is nil, cannot draw.")
    end

    -- Desenha a arma equipada e seu ataque
    if self.equippedWeapon and self.equippedWeapon.attackInstance then
        self.equippedWeapon.attackInstance:draw()
    end
end

--[[-
    Atualiza a lógica de recuperação de vida do jogador

    @param dt (number): Delta time
]]
function PlayerManager:updateHealthRecovery(dt)
    if not self.state then return end

    -- Obtém os stats finais UMA VEZ para usar nos cálculos de recuperação
    local finalStats = self:getCurrentFinalStats()
    local finalMaxHealth = finalStats.health
    local finalHealthRegenPerSecond = finalStats.healthPerTick -- Assumindo que healthPerTick é o regen/s final
    local finalHealingBonusMultiplier = finalStats
        .healingBonus                                          -- Assumindo que healingBonus é o multiplicador final (já calculado em getCurrentFinalStats)
    -- A lógica de delay já está sendo tratada pelo gameTime vs lastDamageTime

    if self.gameTime >= self.lastDamageTime + finalStats.healthRegenDelay then -- Usa delay dos stats
        self.lastRegenTime = self.lastRegenTime + dt
        if self.lastRegenTime >= self.regenInterval then
            self.lastRegenTime = self.lastRegenTime - self.regenInterval

            -- A regeneração agora usa o valor final calculado
            self.accumulatedRegen = self.accumulatedRegen + finalHealthRegenPerSecond
            local healAmount = math.floor(self.accumulatedRegen)

            -- Verifica se precisa curar (usa finalMaxHealth)
            if healAmount >= 1 and self.state.currentHealth < finalMaxHealth then
                -- Chama heal passando os valores finais necessários
                local healedAmount = self.state:heal(healAmount, finalMaxHealth, finalHealingBonusMultiplier)
                self.accumulatedRegen = self.accumulatedRegen - healedAmount -- Reduz apenas o que foi curado

                if healedAmount > 0 and self.floatingTextManager then
                    self.floatingTextManager:addText(self.player.position.x, self.player.position.y - 50,
                        "+" .. healedAmount .. " HP", false, nil, { 0, 1, 0 })
                end
            end
        end
    else
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
    elseif self.autoAttack then
        if (self.equippedWeapon and not self.equippedWeapon.attackInstance) then
            error(string.format(
                "  [DEBUG PM:updateAutoAttack] AutoAttack ON but weapon/instance missing. Weapon: %s, Instance: %s",
                tostring(self.equippedWeapon), tostring(self.equippedWeapon and self.equippedWeapon.attackInstance))) -- DEBUG (Temporarily Disabled)
        end
    end
end

-- Funções de gerenciamento de vida
function PlayerManager:isAlive()
    return self.state and self.state.isAlive -- <<< ADICIONADO: Verifica se state existe
end

function PlayerManager:takeDamage(amount, source)
    if not self.state or not self.state.isAlive then return end

    -- 1. Calcula os stats finais para obter a defesa e calcular a redução
    local finalStats = self:getCurrentFinalStats()
    local finalDefense = finalStats.defense

    -- 2. Calcula a redução de dano usando a defesa final
    local K = Constants and Constants.DEFENSE_DAMAGE_REDUCTION_K
    local finalDamageReduction = finalDefense / (finalDefense + K)
    finalDamageReduction = math.min(Constants and Constants.MAX_DAMAGE_REDUCTION, finalDamageReduction)

    -- 3. Chama PlayerState:takeDamage passando a redução calculada
    local damageTaken = self.state:takeDamage(amount, finalDamageReduction)

    if damageTaken > 0 then
        self.lastDamageTime = self.gameTime
        self.lastRegenTime = 0
        self.accumulatedRegen = 0

        if self.floatingTextManager then
            self.floatingTextManager:addPlayerDamageText(self.player.position, "-" .. damageTaken, self.player)
        end
    end

    if not self.state.isAlive then
        print("Player Morreu!")
        -- TODO: Lógica de morte
    end
end

---Funções de experiência e level
function PlayerManager:addExperience(amount)
    if not self.state then return end

    -- Calcula o ganho de EXP efetivo
    local totalStats = self:getCurrentFinalStats()
    local levelsGained = self.state:addExperience(amount, totalStats.expBonus) -- << MODIFICADO: Captura levelsGained

    if levelsGained > 0 then                                                   -- << MODIFICADO: Verifica se levelsGained > 0
        print(string.format("[PlayerManager] Gained %d level(s)! Now level %d. Next level at %d XP.",
            levelsGained, self.state.level, self.state.experienceToNextLevel))

        self.pendingLevelUps = self.pendingLevelUps + levelsGained -- << NOVO: Adiciona à fila
        self:invalidateStatsCache()                                -- Invalida o cache pois o nível mudou (e bônus podem ter mudado)

        for i = 1, levelsGained do
            if self.floatingTextManager and self.player then
                self.floatingTextManager:addCustomText(self.player.position, "LEVEL UP!", self.player,
                    { color = { 1, 1, 1 } })
            end
        end

        self:tryShowLevelUpModal() -- Tenta abrir o modal imediatamente
    end
end

--- Tenta mostrar o modal de level up se houver níveis pendentes e o modal não estiver visível.
function PlayerManager:tryShowLevelUpModal()
    if self.pendingLevelUps > 0 and LevelUpModal and not LevelUpModal.visible then
        self.pendingLevelUps = self.pendingLevelUps - 1
        LevelUpModal:show()
        print(string.format("[PlayerManager] Showing Level Up Modal. Pending levels: %d", self.pendingLevelUps))
        -- Pausa o jogo ou reduz a velocidade enquanto o modal está aberto
        -- Exemplo: self.uiManager:setGamePaused(true, "level_up")
        -- OU Gameloop.timeScale = 0.1
    end
end

--- Função para ativar/desativar o auto attack
function PlayerManager:toggleAbilityAutoAttack()
    self.autoAttackEnabled = not self.autoAttackEnabled
    self.autoAttack = self.autoAttackEnabled
end

--- Função para ativar/desativar o visual do auto attack
function PlayerManager:toggleAttackPreview()
    if self.equippedWeapon and self.equippedWeapon.attackInstance then
        self.equippedWeapon.attackInstance:togglePreview()
    end
end

function PlayerManager:toggleAutoAim()
    self.autoAimEnabled = not self.autoAimEnabled
    self.autoAim = self.autoAimEnabled
end

--- Função para obter a posição do alvo
--- Se o auto aim estiver ativado, procura o inimigo mais próximo
--- Se não estiver ativado, usa a posição do mouse
function PlayerManager:getTargetPosition()
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
        error("Error [getTargetPosition]: InputManager não disponível, usando posição padrão (0,0).")
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

--- Retorna uma tabela contendo os valores finais dos atributos do jogador,
--- incluindo bônus de nível e fixos calculados pelo PlayerState.
--- Utiliza um cache para evitar recálculos desnecessários.
---@return FinalStats
function PlayerManager:getCurrentFinalStats()
    -- Retorna o cache se ele for válido
    if not self.statsNeedRecalculation and self.finalStatsCache then
        return self.finalStatsCache
    end

    print("[PlayerManager] Recalculating final stats...") -- Log para saber quando o cálculo real ocorre

    if not self.state then
        error("Error [PlayerManager:getCurrentFinalStats]: PlayerState não inicializado.")
    end
    if not self.hunterManager then
        error("Error [PlayerManager:getCurrentFinalStats]: HunterManager não inicializado.")
    end
    if not self.archetypeManager then
        error("Error [PlayerManager:getCurrentFinalStats]: ArchetypeManager não inicializado.")
    end

    -- 1. Pega os stats BASE do PlayerState (que vieram dos defaults + arquétipos INICIAIS)
    local baseStats = {}
    local defaultStats = Constants.HUNTER_DEFAULT_STATS
    for key, _ in pairs(defaultStats) do
        baseStats[key] = self.state[key] or defaultStats[key]
    end

    -- 2. Agrega BÔNUS (Level Up + Arquétipos)
    local totalFixedBonuses = {}
    local totalFixedFractionBonuses = {}
    local totalPercentageBonuses = {}

    -- 2a. Bônus de Level Up (já agregados no PlayerState)
    for statKey, value in pairs(self.state.fixedBonus or {}) do
        -- Precisa determinar se o valor em fixedBonus é Fixo ou Fração Fixa
        -- Vamos assumir uma convenção ou verificar o tipo do stat base?
        -- Por simplicidade, vamos assumir que fixedBonus para stats que usam fração (critChance, critDamage) já armazena a fração,
        -- e para os outros, armazena o valor fixo. Precisamos separar.
        if statKey == "critChance" or statKey == "critDamage" or statKey == "attackSpeed" or statKey == "multiAttackChance" or statKey == "range" or statKey == "attackArea" or statKey == "luck" or statKey == "expBonus" or statKey == "healingBonus" or statKey == "cooldownReduction" then
            totalFixedFractionBonuses[statKey] = (totalFixedFractionBonuses[statKey] or 0) + value
        else -- health, defense, moveSpeed, healthRegen, pickupRadius, healthRegenDelay, healthPerTick, runeSlots
            totalFixedBonuses[statKey] = (totalFixedBonuses[statKey] or 0) + value
        end
    end
    for statKey, value in pairs(self.state.levelBonus or {}) do
        totalPercentageBonuses[statKey] = (totalPercentageBonuses[statKey] or 0) + value
    end
    -- 2b. Bônus de Arquétipos
    local hunterArchetypeIds = self.state.archetypeIds or {}
    if self.hunterManager and self.hunterManager.archetypeManager then
        for _, archIdInfo in ipairs(hunterArchetypeIds) do
            local finalArchId = type(archIdInfo) == 'table' and archIdInfo.id or archIdInfo
            local archetypeData = self.hunterManager.archetypeManager:getArchetypeData(finalArchId)
            if archetypeData and archetypeData.modifiers then
                for _, mod in ipairs(archetypeData.modifiers) do
                    local statName = mod.stat
                    local modValue = mod.value or 0
                    if mod.type == "fixed" then
                        totalFixedBonuses[statName] = (totalFixedBonuses[statName] or 0) + modValue
                    elseif mod.type == "fixed_percentage_as_fraction" then
                        totalFixedFractionBonuses[statName] = (totalFixedFractionBonuses[statName] or 0) + modValue
                    elseif mod.type == "percentage" then
                        totalPercentageBonuses[statName] = (totalPercentageBonuses[statName] or 0) + modValue
                    end
                end
            end
        end
    end

    -- 3. Calcula os Stats FINAIS aplicando bônus na NOVA ORDEM
    local calculatedStats = {} -- Usar tabela temporária para o cálculo
    for statKey, baseValue in pairs(baseStats) do
        if statKey ~= "weaponDamage" then
            local currentValue = baseValue

            -- Aplica Fixed
            currentValue = currentValue + (totalFixedBonuses[statKey] or 0)

            -- Aplica Fixed Fraction (Aditivo)
            currentValue = currentValue + (totalFixedFractionBonuses[statKey] or 0)

            -- Aplica Percentage
            currentValue = currentValue * (1 + (totalPercentageBonuses[statKey] or 0) / 100)
            calculatedStats[statKey] = currentValue
        end
    end

    -- 4. Calcula weaponDamage separadamente
    local baseWeaponDamage = 0
    local weaponBaseId = nil
    if self.currentHunterId and self.hunterManager and self.state and self.state.equippedItems then
        local equippedHunterItems = self.hunterManager:getEquippedItems(self.currentHunterId)
        if equippedHunterItems then
            local weaponInstance = equippedHunterItems[Constants.SLOT_IDS.WEAPON]
            if weaponInstance and weaponInstance.itemBaseId then weaponBaseId = weaponInstance.itemBaseId end
        end
    end
    if weaponBaseId and self.itemDataManager then
        local weaponData = self.itemDataManager:getBaseItemData(weaponBaseId)
        if weaponData then
            baseWeaponDamage = weaponData.damage
        end
    end
    calculatedStats._baseWeaponDamage = baseWeaponDamage -- Salva para tooltip

    -- Calcula o multiplicador de dano final (usando os bônus agregados)
    local damageMultiplierBase = 1.0
    local damageMultiplierFixed = totalFixedBonuses["damageMultiplier"] or 0
    local damageMultiplierFixedFraction = totalFixedFractionBonuses["damageMultiplier"] or 0
    local damageMultiplierPercentage = totalPercentageBonuses["damageMultiplier"] or 0
    local finalDamageMultiplier = (damageMultiplierBase + damageMultiplierFixed + damageMultiplierFixedFraction) *
        (1 + damageMultiplierPercentage / 100)
    calculatedStats._playerDamageMultiplier = finalDamageMultiplier
    calculatedStats.weaponDamage = math.floor(baseWeaponDamage * finalDamageMultiplier)

    -- 5. Adiciona informações restantes para a UI / Tooltips
    calculatedStats._levelBonus = self.state.levelBonus
    calculatedStats._fixedBonus = self.state.fixedBonus
    calculatedStats._learnedLevelUpBonuses = self.state.learnedLevelUpBonuses or {}
    calculatedStats.equippedItems = self.state.equippedItems or {}
    calculatedStats.archetypeIds = self.state.archetypeIds or {}

    -- 6. Aplica clamps finais
    calculatedStats.runeSlots = math.max(0, math.floor(calculatedStats.runeSlots or 0))
    calculatedStats.luck = math.max(0, calculatedStats.luck or 0)
    -- <<< FIM: Lógica de cálculo >>>

    -- Armazena no cache e marca como atualizado
    self.finalStatsCache = calculatedStats
    self.statsNeedRecalculation = false

    return self.finalStatsCache
end

--- ADICIONADO: Invalida o cache de stats, forçando recálculo na próxima chamada de getCurrentFinalStats.
function PlayerManager:invalidateStatsCache()
    print("[PlayerManager] Invalidating stats cache.")
    self.statsNeedRecalculation = true
end

--- Retorna o ID do caçador atualmente configurado para o gameplay.
--- @return string|nil O ID do caçador ou nil se não estiver configurado.
function PlayerManager:getCurrentHunterId()
    return self.currentHunterId
end

--- ADICIONADO: Define/Limpa a arma ativa e inicializa seu estado
--- Define a arma ativa no PlayerManager e chama seu método :equip.
--- Passar nil para limpar a arma ativa.
--- @param weaponInstance table|nil A instância completa do item da arma (dados), ou nil.
function PlayerManager:setActiveWeapon(weaponInstance)
    -- Limpa a arma anterior (se houver)
    self.equippedWeapon = nil

    -- Se estamos equipando uma nova arma (não nil)
    if weaponInstance and weaponInstance.itemBaseId then
        local itemBaseId = weaponInstance.itemBaseId
        local weaponClassPath = string.format("src.items.weapons.%s", itemBaseId)

        -- Tenta carregar a classe da arma
        local success, WeaponClass = pcall(require, weaponClassPath)

        if success and WeaponClass then
            -- Cria uma nova instância da CLASSE da arma
            local classInstance = WeaponClass:new({ itemBaseId = itemBaseId })

            if classInstance then
                -- Armazena a INSTÂNCIA DA CLASSE
                self.equippedWeapon = classInstance

                -- Chama o método :equip da INSTÂNCIA DA CLASSE, passando os DADOS do item
                if self.equippedWeapon.equip then
                    print(string.format(
                        "    -> Calling :equip on weapon CLASS instance (AttackInstance Type BEFORE: %s)",
                        type(self.equippedWeapon.attackInstance)))
                    self.equippedWeapon:equip(self, weaponInstance)
                else
                    error(string.format("    - ERRO CRÍTICO: O método :equip não foi encontrado na classe da arma '%s'!",
                        weaponClassPath))
                end
            else
                error(string.format("    - ERRO: Falha ao criar a instância da CLASSE da arma '%s' usando :new().",
                    weaponClassPath))
            end
        else
            error(string.format("    - ERRO CRÍTICO: Não foi possível carregar a classe da arma: %s. Detalhe: %s",
                weaponClassPath, tostring(WeaponClass)))
        end
    end
    self:invalidateStatsCache()
end

return PlayerManager
