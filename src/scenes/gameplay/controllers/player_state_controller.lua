local ServiceLocator = require("src.core.service_locator")
local HunterBaseStats = require("src.data.hunter_base_stats")
local ALL_STATS = require("src.data.stats_list")

---@class StatSources
---@field base table Stats base do caçador.
---@field equipment StatModifier[] Bônus de todos os equipamentos.
---@field levelUp StatModifier[] Bônus de todos os level ups.
---@field archetypes StatModifier[] Bônus de todos os arquétipos.

---@class PlayerStateControllerV2
---@description Gerencia o estado e os atributos do jogador usando um grafo de dependências.
---@field finalStats table<StatKey, number> Os stats finais calculados.
---@field sources StatSources As fontes de todos os modificadores de stats.
---@field eventService EventService
---@field eventListeners table
local PlayerStateController = {}
PlayerStateController.__index = PlayerStateController

function PlayerStateController:new()
    local instance = setmetatable({}, PlayerStateController)

    -- Stats Finais (a fonte da verdade para o resto do jogo)
    instance.finalStats = {}
    instance.sources = {
        base = HunterBaseStats,
        equipment = {},
        levelUp = {},
        archetypes = {}
    }

    instance.eventService = ServiceLocator.get("eventService")
    instance.eventListeners = {}

    return instance
end

--- Inicializa o controlador, configurando o estado inicial e registrando ouvintes de eventos.
function PlayerStateController:init()
    Logger.info("player_state_controller.init", "[PlayerStateController:init] Initializing...")
    self:_registerEventListeners()
    self:_triggerRecalculation()
end

--- Obtém o valor final de um stat específico.
---@param statName StatKey
---@return number
function PlayerStateController:getFinalStat(statName)
    return self.finalStats[statName] or 0
end

--- Registra ouvintes de eventos para atualizações de bônus de arquétipo.
function PlayerStateController:_registerEventListeners()
    local events = self.eventService.EVENTS
    self:_listen(events.ARCHETYPE_BONUSES_UPDATED, self._onArchetypeBonusesUpdated)
    self:_listen(events.EQUIPMENT_BONUSES_UPDATED, self._onEquipmentBonusesUpdated)
    -- TODO: Adicionar ouvintes para LevelUp
end

--- @param event string
--- @param handler function
function PlayerStateController:_listen(event, handler)
    local listener = self.eventService:on(event, function(data) handler(self, data) end)
    table.insert(self.eventListeners, listener)
end

--- Handler para o evento de atualização de bônus de arquétipo.
---@param data {modifiers: StatModifier[]}
function PlayerStateController:_onArchetypeBonusesUpdated(data)
    Logger.info(
        "player_state_controller.archetypes_updated",
        "[PlayerStateController:_onArchetypeBonusesUpdated] Archetype bonuses updated."
    )
    self.sources.archetypes = data.modifiers or {}
    self:_triggerRecalculation()
end

--- Handler para o evento de atualização de bônus de equipamento.
---@param data {modifiers: StatModifier[]}
function PlayerStateController:_onEquipmentBonusesUpdated(data)
    Logger.info(
        "player_state_controller.equipment_updated",
        "[PlayerStateController:_onEquipmentBonusesUpdated] Equipment bonuses updated."
    )
    self.sources.equipment = data.modifiers or {}
    self:_triggerRecalculation()
end

--- Coleta o contexto de jogo atual e dispara o recálculo de todos os stats.
function PlayerStateController:_triggerRecalculation()
    -- TODO: Obter dados de outros managers (Experience, KillCounter, etc.)
    ---@type GameplayContext
    local context = {
        level = 1, -- Mocked
        kills = 0, -- Mocked
        time = 0   -- Mocked
    }
    self:_recalculateAllStats(context)
end

--- Orquestra o recálculo de todos os stats usando um grafo de dependências.
---@param context GameplayContext
function PlayerStateController:_recalculateAllStats(context)
    local allModifiers = self:_getAllModifiers()
    local dependencyGraph = self:_buildDependencyGraph(allModifiers)
    local sortedStats, err = self:_topologicalSort(dependencyGraph)

    if not sortedStats then
        error("[PlayerStateController] Circular dependency detected in stats: " .. err)
    end

    local newFinalStats = {}
    for _, statName in ipairs(sortedStats) do
        local baseValue = self.sources.base[statName] or 0
        local flatBonus = 0
        local percentBonus = 0

        for _, modifier in ipairs(allModifiers) do
            if modifier.stat == statName then
                local value = modifier.value
                if type(value) == "function" then
                    value = value(newFinalStats, context)
                end

                if modifier.type == "FLAT" then
                    flatBonus = flatBonus + value
                elseif modifier.type == "PERCENTAGE" then
                    percentBonus = percentBonus + value
                end
            end
        end

        newFinalStats[statName] = (baseValue + flatBonus) * (1 + percentBonus / 100)
    end

    -- Atualiza os stats finais e emite eventos apenas para os que mudaram.
    for statName, newValue in pairs(newFinalStats) do
        self:_updateFinalStat(statName, newValue)
    end
end

--- Constrói um grafo de dependências a partir de uma lista de modificadores.
---@param modifiers StatModifier[]
---@return table<StatKey, StatKey[]> O grafo de adjacências.
function PlayerStateController:_buildDependencyGraph(modifiers)
    ---@type table<StatKey, StatKey[]>
    local graph = {}
    for _, stat in ipairs(ALL_STATS) do
        graph[stat] = {}
    end

    Logger.info("build_dependency_graph.start", "--- Building Dependency Graph ---")
    for _, modifier in ipairs(modifiers) do
        if type(modifier.value) == "function" then
            Logger.debug("build_dependency_graph.modifier",
                string.format("Processing modifier for '%s' from source '%s'", modifier.stat, modifier.source)
            )
            local funcStr = string.dump(modifier.value)
            for _, dependencyStat in ipairs(ALL_STATS) do
                -- Verifica se a função depende de 'dependencyStat' E
                -- se 'dependencyStat' não é o mesmo stat que a função está calculando.
                if dependencyStat ~= modifier.stat and funcStr:match("finalStats%." .. dependencyStat) then
                    Logger.debug("build_dependency_graph.edge_added",
                        string.format("  -> Detected dependency: '%s' depends on '%s'. Adding edge.", modifier.stat,
                            dependencyStat)
                    )
                    -- A stat do modifier ('modifier.stat') depende de 'dependencyStat'.
                    -- Adiciona uma aresta: dependencyStat -> modifier.stat
                    table.insert(graph[dependencyStat], modifier.stat)
                end
            end
        end
    end

    local graphStr = "Final Graph: {\n"
    for stat, dependencies in pairs(graph) do
        if #dependencies > 0 then
            graphStr = graphStr .. string.format("  %s -> {%s}\n", stat, table.concat(dependencies, ", "))
        end
    end
    graphStr = graphStr .. "}"
    Logger.info("build_dependency_graph.result", graphStr)
    Logger.info("build_dependency_graph.end", "--- Dependency Graph Built ---")

    return graph
end

--- Ordena os stats usando o algoritmo de Kahn (Ordenação Topológica).
---@param graph table<StatKey, StatKey[]>
---@return StatKey[]|nil statsOrdenedList, string|nil errorMsg lista ordenada ou nil e uma msg de erro em caso de ciclo.
function PlayerStateController:_topologicalSort(graph)
    local inDegree = {}
    local queue = {}
    local result = {}

    for stat, _ in pairs(graph) do
        inDegree[stat] = 0
    end

    for u, neighbors in pairs(graph) do
        for _, v in ipairs(neighbors) do
            inDegree[v] = (inDegree[v] or 0) + 1
        end
    end

    for stat, degree in pairs(inDegree) do
        if degree == 0 then
            table.insert(queue, stat)
        end
    end

    while #queue > 0 do
        local u = table.remove(queue, 1)
        table.insert(result, u)

        for _, v in ipairs(graph[u]) do
            inDegree[v] = inDegree[v] - 1
            if inDegree[v] == 0 then
                table.insert(queue, v)
            end
        end
    end

    if #result ~= #ALL_STATS then
        return nil, "Cycle detected"
    end

    return result
end

--- Atualiza o valor de um stat final e emite um evento se ele mudou.
---@param statName StatKey
---@param newValue number
function PlayerStateController:_updateFinalStat(statName, newValue)
    local oldValue = self.finalStats[statName]
    if oldValue ~= newValue then
        self.finalStats[statName] = newValue
        self.eventService:emit(self.eventService.EVENTS.PLAYER_STAT_UPDATED, {
            stat = statName,
            newValue = newValue,
            oldValue = oldValue or 0
        })
    end
end

--- Agrega modificadores de todas as fontes.
---@return StatModifier[]
function PlayerStateController:_getAllModifiers()
    local all = {}
    for _, mod in ipairs(self.sources.archetypes) do table.insert(all, mod) end
    for _, mod in ipairs(self.sources.equipment) do table.insert(all, mod) end
    for _, mod in ipairs(self.sources.levelUp) do table.insert(all, mod) end
    return all
end

--- Desregistra todos os ouvintes de eventos para evitar memory leaks.
function PlayerStateController:destroy()
    Logger.info("player_state_controller.destroy", "[PlayerStateController:destroy] Destroying...")
    for _, listener in ipairs(self.eventListeners) do
        self.eventService:off(listener.event, listener.id)
    end
end

return PlayerStateController
