---@class AttackControllerCommand
---@field animation string|nil O tipo de animação a ser disparada (ex: 'melee', 'ranged').
---@field sound string|nil O som a ser tocado.
---@field vfx table|nil Efeitos visuais a serem criados.

---@class AttackControllerInterface
---@field weaponInstance BaseWeapon
---@field cooldownRemaining number
---@field currentCooldownDuration number Duração total do cooldown atual, considerando a velocidade de ataque.
---@field name string
---@field description string
---@field cachedBaseData BaseWeapon|CircularSmashWeapon|ConeSlashWeapon|FlameStreamWeapon|SpreadProjectileWeapon|SequentialProjectileWeapon|ChainLightningWeapon

---@class BaseAttackController : AttackControllerInterface
---@description Classe base para todos os controllers de habilidade de ataque.
---@description Centraliza a lógica de cooldown e define a interface que o orquestrador (PlayerManager)
---@description usará para solicitar descrições de ataque de qualquer habilidade.
local BaseAttackController = {}
BaseAttackController.__index = BaseAttackController

BaseAttackController.MIN_ATTACK_SPEED = 0.01

---@class AttackControllerConfig
---@field name string
---@field description string
---@field constants table|nil

--- Cria a base para um controller de ataque.
---@param weaponInstance BaseWeapon A instância da arma associada.
---@param config AttackControllerConfig A configuração específica da habilidade.
---@return BaseAttackController
function BaseAttackController:new(weaponInstance, config)
    local o = setmetatable({}, self)

    assert(weaponInstance, "BaseAttackController:new - weaponInstance é obrigatório.")
    assert(config, "BaseAttackController:new - config é obrigatório.")

    o.weaponInstance = weaponInstance
    o.cachedBaseData = weaponInstance:getBaseData()
    if not o.cachedBaseData then
        error("BaseAttackController:new - BaseData não encontrado na weaponInstance.")
    end
    Logger.debug("BaseAttackController:new", "cachedBaseData: " .. Logger.dumpTable(o.cachedBaseData, 2))

    o.cooldownRemaining = 0
    o.currentCooldownDuration = 0
    o.name = config.name
    o.description = config.description

    return o
end

---@public Atualiza o estado interno do controller, principalmente o cooldown.
--- Este método deve ser chamado a cada frame pelo PlayerManager.
---@param dt number
---@param context AttackContext Dados "puros" fornecidos pelo PlayerManager.
function BaseAttackController:update(dt, context)
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = math.max(0, self.cooldownRemaining - dt)
    end

    -- Hook para que as subclasses possam implementar sua própria lógica de update.
    self:updateSpecific(dt, context)
end

---@public Tenta gerar as descrições do ataque se o cooldown permitir.
---@param context AttackContext
---@return AttackDescriptor[]|nil descriptions Uma lista de descrições de ataque para o PlayerManager processar, ou nil se estiver em cooldown.
function BaseAttackController:tryAttack(context)
    if self.cooldownRemaining > 0 then
        return nil
    end

    self:applyCooldown(context)

    -- Chama a implementação específica da subclasse, que retornará as descrições do ataque.
    return self:castSpecific(context)
end

---@protected Aplica o cooldown baseado nos stats do contexto.
---@param context AttackContext
function BaseAttackController:applyCooldown(context)
    local baseCooldown = self.cachedBaseData.cooldown
    local attackSpeed = math.max(context.finalStats.attackSpeed, BaseAttackController.MIN_ATTACK_SPEED)
    self.currentCooldownDuration = baseCooldown / attackSpeed
    self.cooldownRemaining = self.currentCooldownDuration
end

---@protected Calcula o delay entre múltiplos ataques.
---@param totalAttacks number
---@param delayStep number
---@return number[] delays
function BaseAttackController:calculateAttackDelays(totalAttacks, delayStep)
    local delays = {}
    local currentDelay = 0

    for i = 1, totalAttacks do
        table.insert(delays, currentDelay)
        currentDelay = currentDelay + delayStep
    end
    return delays
end

---@public Retorna o progresso do cooldown atual (0 a 1).
---@return number progress (1 = pronto para atacar, 0 = acabou de atacar)
function BaseAttackController:getCooldownProgress()
    if self.cooldownRemaining <= 0 then
        return 1
    end
    if not self.currentCooldownDuration or self.currentCooldownDuration == 0 then
        return 0 -- Evita divisão por zero se o ataque ainda não ocorreu.
    end

    return 1 - (self.cooldownRemaining / self.currentCooldownDuration)
end

-- ===============================================================
-- HOOKS PARA SUBCLASSES (MÉTODOS ABSTRATOS)
-- Estes métodos DEVEM ser implementados pelas classes filhas.
-- ===============================================================

---@protected Hook para update específico da subclasse.
---@param dt number
---@param context AttackContext
function BaseAttackController:updateSpecific(dt, context)
    -- Implementado por subclasses
end

---@protected Hook para gerar as descrições de ataque.
---@description A subclasse deve implementar este método para descrever a(s) forma(s) geométrica(s) do ataque.
---@param context AttackContext
---@return AttackDescriptor[] descriptions Uma lista de descritores de ataque.
function BaseAttackController:castSpecific(context)
    -- Implementado por subclasses
    error(self.name .. " não implementou o método :castSpecific()")
    return {}
end

---@protected Hook para coletar renderizáveis (previsões de ataque, etc.).
---@param renderPipeline RenderPipeline
---@param context AttackContext
function BaseAttackController:collectRenderables(renderPipeline, context)
    -- Implementado por subclasses
end

---@protected Hook para liberar recursos, se necessário.
function BaseAttackController:destroy()
    -- Implementado por subclasses
end

return BaseAttackController
