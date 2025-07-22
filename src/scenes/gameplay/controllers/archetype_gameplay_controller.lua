local ServiceLocator = require("src.core.service_locator")

---@class ArchetypeGameplayController
---@description Gerencia os bônus de arquétipos de forma reativa, baseada em eventos.
--- Este controller ouve eventos do jogo (ex: level up) e emite um evento
--- consolidado com todas as "receitas" de bônus de arquétipo para o
--- PlayerStateController processar.
---@field eventService EventService
---@field hunterId string
---@field activeArchetypes ArchetypeData[]
---@field eventListeners table
local ArchetypeGameplayController = {}
ArchetypeGameplayController.__index = ArchetypeGameplayController

--- Cria uma nova instância do controller.
--- @param hunterId string O ID do caçador para carregar os arquétipos corretos.
function ArchetypeGameplayController:new(hunterId)
    local instance = setmetatable({}, ArchetypeGameplayController)
    instance.eventService = ServiceLocator.get("eventService")
    instance.hunterId = hunterId
    instance.activeArchetypes = {}
    instance.eventListeners = {}
    return instance
end

--- Inicializa o controller, carregando arquétipos e registrando ouvintes de eventos.
function ArchetypeGameplayController:init()
    -- TODO: Carregar arquétipos reais do ArchetypeManager usando self.hunterId
    self.activeArchetypes = self:_getMockArchetypes()

    self:_registerEventListeners()

    -- Dispara uma atualização inicial para garantir que os bônus sejam aplicados no início do jogo.
    self:_dispatchArchetypeBonuses()
end

--- Registra todos os ouvintes de eventos necessários.
function ArchetypeGameplayController:_registerEventListeners()
    local listener = self.eventService:on(
        self.eventService.EVENTS.PLAYER_LEVELED_UP,
        function() self:_onPlayerLeveledUp() end
    )
    table.insert(self.eventListeners, listener)
end

--- Callback para quando o jogador sobe de nível.
function ArchetypeGameplayController:_onPlayerLeveledUp()
    Logger.info(
        "archetype_gameplay_controller.level_up",
        "[ArchetypeGameplayController:onPlayerLeveledUp] Player leveled up, dispatching new bonuses."
    )
    -- Os bônus dependentes de nível serão recalculados, então reenviamos tudo.
    self:_dispatchArchetypeBonuses()
end

--- Coleta todas as "receitas" de bônus dos arquétipos ativos e dispara o evento.
function ArchetypeGameplayController:_dispatchArchetypeBonuses()
    ---@type StatModifier[]
    local statModifiers = {}

    for _, archetype in ipairs(self.activeArchetypes) do
        if archetype.bonuses then
            for _, bonus in ipairs(archetype.bonuses) do
                table.insert(statModifiers, bonus)
            end
        end
    end

    self.eventService:emit(
        self.eventService.EVENTS.ARCHETYPE_BONUSES_UPDATED,
        { modifiers = statModifiers }
    )
end

--- Retorna dados de arquétipos mockados para desenvolvimento.
--- @return ArchetypeData[]
function ArchetypeGameplayController:_getMockArchetypes()
    ---@type ArchetypeData[]
    local archetypes = {
        {
            id = "FAST_STRIKER",
            name = "Atacante Veloz",
            description = "+0.3 de velocidade de ataque base por nível (máx. 2).",
            bonuses = {
                {
                    stat = "attackSpeed",
                    type = "FLAT",
                    source = "ARCHETYPE_FAST_STRIKER",
                    ---@type BonusFunction
                    value = function(finalStats, context)
                        local ATTACK_SPEED_PER_LEVEL = 0.3
                        local MAX_ATTACK_SPEED = 2.0
                        return math.min((context.level - 1) * ATTACK_SPEED_PER_LEVEL, MAX_ATTACK_SPEED)
                    end
                }
            }
        },
        {
            id = "TANK",
            name = "Tanque",
            description = "+2 de Defesa para cada 50 de Vida Máxima.",
            bonuses = {
                {
                    stat = "defense",
                    type = "FLAT",
                    source = "ARCHETYPE_TANK",
                    ---@type BonusFunction
                    value = function(finalStats, context)
                        -- Esta receita cria uma dependência: defense -> health
                        local HEALTH_PER_DEFENSE = 50
                        local DEFENSE_PER_HEALTH = 2
                        local health = finalStats.health or 0
                        return math.floor(health / HEALTH_PER_DEFENSE) * DEFENSE_PER_HEALTH
                    end
                }
            }
        }
    }
    return archetypes
end

--- Limpa os ouvintes de eventos para evitar memory leaks.
function ArchetypeGameplayController:destroy()
    Logger.info(
        "archetype_gameplay_controller.destroy",
        "[ArchetypeGameplayController:destroy] Destroying and unsubscribing from events."
    )
    for _, listener in ipairs(self.eventListeners) do
        self.eventService:off(listener.event, listener.id)
    end
end

return ArchetypeGameplayController
