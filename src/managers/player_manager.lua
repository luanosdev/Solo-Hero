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
    itemDataManager = nil,
    currentHunterId = nil             -- <<< ADICIONADO: Para armazenar o ID do caçador ativo
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

    -- Armazena o ID do caçador atual
    self.currentHunterId = hunterId -- <<<< ADICIONADO

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

    -- DEBUG: Log finalStats ANTES de passar para PlayerState:new
    if finalStats and next(finalStats) then
        -- print("[PlayerManager:setupGameplay DEBUG] finalStats ANTES de PlayerState:new:") -- COMENTADO
        -- print("  > Tem equippedItems?", finalStats.equippedItems ~= nil and not not next(finalStats.equippedItems or {})) -- COMENTADO
        if finalStats.equippedItems and finalStats.equippedItems.weapon then
            print("    [PlayerManager:setupGameplay] Weapon ID em finalStats para PlayerState:new:",
                finalStats.equippedItems.weapon)                                                           -- MANTIDO
        else
            print("    [PlayerManager:setupGameplay] Weapon ID em finalStats é nil para PlayerState:new.") -- MANTIDO
        end
        -- print("  > Tem archetypeIds?", finalStats.archetypeIds ~= nil and #finalStats.archetypeIds > 0) -- COMENTADO
    else
        print("[PlayerManager:setupGameplay DEBUG] finalStats é NULO ou VAZIO ANTES de PlayerState:new.")
    end

    -- 3. Inicializa PlayerState com os stats finais
    self.state = PlayerState:new(finalStats)
    if not self.state then
        error(string.format("ERRO CRÍTICO [PlayerManager:setupGameplay]: Falha ao criar PlayerState para hunter ID: %s",
            hunterId))
    end
    print(string.format("  - PlayerState initialized. HP: %d/%d, Speed: %.2f",
        self.state.currentHealth, self.state:getTotalHealth(), self.state:getTotalMoveSpeed()))

    -- 4. Cria a instância do Sprite do Jogador
    local finalSpeed = self.state:getTotalMoveSpeed()                                       -- ATUALIZADO para getTotalMoveSpeed
    print(string.format("  - Player final speed for sprite: %.2f", finalSpeed))             -- DEBUG
    self.player = SpritePlayer.newConfig({
        position = { x = love.graphics.getWidth() / 2, y = love.graphics.getHeight() / 2 }, -- Posição inicial padrão
        scale = 0.8,
        speed =
            finalSpeed                                                                                     -- Usa a velocidade calculada pelo PlayerState
    })
    print(string.format("  - Player Sprite instance created. Type of self.player: %s", type(self.player))) -- DEBUG
    print("  - Player Sprite instance created.")

    -- 5. Equipa a Arma
    local weaponItem = equippedItems[Constants.SLOT_IDS.WEAPON]

    if weaponItem then
        -- Constrói o caminho para a CLASSE da arma (ex: src.items.weapons.dual_daggers)
        local weaponClassPath = string.format("src.items.weapons.%s", weaponItem.itemBaseId)
        print(string.format("  - Attempting to load weapon class: %s", weaponClassPath))

        -- Tenta carregar a classe da arma
        local success, WeaponClass = pcall(require, weaponClassPath)

        if success and WeaponClass then
            print(string.format("  - Weapon class '%s' loaded successfully.", weaponClassPath))
            -- Cria uma instância da classe da arma, passando o itemBaseId
            -- OBS: Assumindo que a classe da arma tem um método :new(config) que aceita itemBaseId
            local weaponInstance = WeaponClass:new({ itemBaseId = weaponItem.itemBaseId })

            if weaponInstance then
                print(string.format("    - Weapon instance created for '%s'.", weaponItem.itemBaseId))
                -- Armazena a instância da arma
                self.equippedWeapon = weaponInstance

                -- Chama o método :equip DA INSTÂNCIA da arma
                -- Passa o PlayerManager (self) e os dados do item específico (weaponItem)
                print(string.format("    -> Calling :equip on weapon instance (Type: %s)",
                    type(self.equippedWeapon.attackInstance)))
                if self.equippedWeapon.equip then -- Verifica se o método existe
                    self.equippedWeapon:equip(self, weaponItem)
                    print(string.format("    -> :equip called. Type of attackInstance inside weapon: %s",
                        type(self.equippedWeapon.attackInstance))) -- Verifica se attackInstance foi criado
                    print(string.format("    - Weapon '%s' equipped and configured via its class.", weaponItem
                        .itemBaseId))

                    -- REMOVIDO: A atualização dos stats agora é responsabilidade do método :equip da arma.
                    -- self.state:updateWeaponStats(self.equippedWeapon)
                else
                    print(string.format("    - ERRO CRÍTICO: O método :equip não foi encontrado na classe da arma '%s'!",
                        weaponClassPath))
                    self.equippedWeapon = nil -- Desequipa se :equip falhar ou não existir
                end
            else
                print(string.format("    - ERRO: Falha ao criar a instância da arma '%s' usando :new().", weaponClassPath))
                self.equippedWeapon = nil
            end
        else
            print(string.format("    - ERRO CRÍTICO: Não foi possível carregar a classe da arma: %s. Detalhe: %s",
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
    if self.player and self.player.position then
        Camera:follow(self.player.position, dt)
    else
        -- print("PlayerManager Update: SKIPPING Camera:follow (Player or position is nil)") -- DEBUG (Mantido por segurança)
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

    -- REMOVIDO: Libera a transformação da câmera (já feita pela GameplayScene)
    -- Camera:detach()
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
            if healAmount >= 1 and self.state.currentHealth < self.state:getTotalHealth() then
                self.state:heal(healAmount)
                self.accumulatedRegen = self.accumulatedRegen - healAmount
                -- Mostra texto flutuante de cura (opcional)
                self.floatingTextManager:addText(self.player.position.x, self.player.position.y - 50,
                    "+" .. healAmount .. " HP", false, nil, { 0, 1, 0 })
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
    elseif self.autoAttack then
        print(string.format(
            "  [DEBUG PM:updateAutoAttack] AutoAttack ON but weapon/instance missing. Weapon: %s, Instance: %s",
            tostring(self.equippedWeapon), tostring(self.equippedWeapon and self.equippedWeapon.attackInstance))) -- DEBUG (Temporarily Disabled)
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
        error("AVISO [getTargetPosition]: InputManager não disponível, usando posição padrão (0,0).")
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
function PlayerManager:getCurrentFinalStats()
    if not self.state then
        print("AVISO [PlayerManager:getCurrentFinalStats]: PlayerState não inicializado. Retornando tabela vazia.")
        return {}
    end

    local finalStats = {
        health = self.state:getTotalHealth(),
        defense = self.state:getTotalDefense(),
        moveSpeed = self.state:getTotalMoveSpeed(),
        critChance = self.state:getTotalCritChance(),
        critDamage = self.state:getTotalCritDamage(),
        healthPerTick = self.state:getTotalHealthPerTick(),
        healthRegenDelay = self.state:getTotalHealthRegenDelay(),
        multiAttackChance = self.state:getTotalMultiAttackChance(),
        attackSpeed = self.state:getTotalAttackSpeed(),
        expBonus = self.state:getTotalExpBonus(),
        cooldownReduction = self.state:getTotalCooldownReduction(),
        range = self.state:getTotalRange(),
        attackArea = self.state:getTotalArea(),
        healingBonus = self.state:getTotalHealingBonus(),
        luck = self.state:getTotalLuck() or 0,
        runeSlots = self.state:getTotalRuneSlots(),
        _levelBonus = self.state._levelBonus,
        _fixedBonus = self.state._fixedBonus,
        _archetypeBonus = self.state._archetypeBonus, -- Presumindo que _archetypeBonus é o campo correto em PlayerState para os bônus de arquétipo consolidados
        _baseWeaponDamage = 0,
        _playerDamageMultiplier = 1.0,
        _learnedLevelUpBonuses = self.state.learnedLevelUpBonuses or {},
        -- <<< ADICIONANDO OS CAMPOS QUE FALTAVAM >>>
        equippedItems = self.state.equippedItems or {},
        archetypeIds = self.state.archetypeIds or {} -- Assumindo que PlayerState tem um campo archetypeIds
    }

    -- Adiciona informações da arma equipada, se houver
    -- print("[PlayerManager:getCurrentFinalStats DEBUG] self.state.equippedItems ANTES de pegar weaponId. Existe?", self.state and self.state.equippedItems ~= nil) -- COMENTADO
    local equippedWeaponId = self.state.equippedItems and self.state.equippedItems.weapon
    if equippedWeaponId and self.itemDataManager then
        local weaponData = self.itemDataManager:getItemData(equippedWeaponId)
        if weaponData and weaponData.stats then
            local baseDmg = weaponData.stats.damage or 0
            local minDmg = weaponData.stats.min_damage
            local maxDmg = weaponData.stats.max_damage

            if minDmg and maxDmg then
                baseDmg = (minDmg + maxDmg) / 2
            end
            finalStats._baseWeaponDamage = baseDmg
        end
    end

    -- Calcula o multiplicador de dano do jogador
    -- (1 + (total de bônus percentuais de dano / 100))
    -- Assumindo que _levelBonus.damage é o principal bônus percentual (ex: 10 para 10%)
    local totalPercentageDamageBonus = (self.state._levelBonus and self.state._levelBonus.damage or 0) +
        (self.state._fixedBonus and self.state._fixedBonus.damage_percent or 0) -- Se houver um bônus fixo percentual

    finalStats._playerDamageMultiplier = 1 + (totalPercentageDamageBonus / 100)

    -- Calcula o dano final da arma com base nos componentes
    -- Se _baseWeaponDamage for 0 (sem arma ou arma com 0 de dano), weaponDamage será 0.
    finalStats.weaponDamage = (finalStats._baseWeaponDamage or 0) * (finalStats._playerDamageMultiplier or 1)

    -- print(string.format("[PlayerManager DEBUG Dano] BaseDmg: %s, Multiplier: %s (TotalPercBonus: %s), FinalDmg: %s, WeaponID: %s", -- COMENTADO
    --     tostring(finalStats._baseWeaponDamage), tostring(finalStats._playerDamageMultiplier),
    --     tostring(totalPercentageDamageBonus), tostring(finalStats.weaponDamage),
    --     tostring(equippedWeaponId))) -- Log para o cálculo de dano

    return finalStats
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
                    self.equippedWeapon:equip(self, weaponInstance) -- Passa os DADOS (weaponInstance)
                    print(string.format("    -> :equip called. Attack instance type AFTER: %s",
                        type(self.equippedWeapon.attackInstance)))
                else
                    error(string.format("    - ERRO CRÍTICO: O método :equip não foi encontrado na classe da arma '%s'!",
                        weaponClassPath))
                    self.equippedWeapon = nil -- Desequipa se :equip falhar
                end
            else
                error(string.format("    - ERRO: Falha ao criar a instância da CLASSE da arma '%s' usando :new().",
                    weaponClassPath))
                self.equippedWeapon = nil
            end
        else
            error(string.format("    - ERRO CRÍTICO: Não foi possível carregar a classe da arma: %s. Detalhe: %s",
                weaponClassPath, tostring(WeaponClass)))
            self.equippedWeapon = nil
        end
    end
end

return PlayerManager
