local HunterBaseStats = require("src.data.hunter_base_stats")
local ALL_STATS = require("src.data.stats_list")

--- Configurações do sistema
---@type table
local CONFIG = {
    DEBOUNCE_TIME = 0.016,            -- ~1 frame at 60fps
    MAX_CALCULATION_ITERATIONS = 100, -- Proteção contra loops infinitos
    ENABLE_CACHING = true,            -- Habilita cache de dependency graph
    LOG_LEVEL = "INFO"                -- Nível de log
}

--- Fontes de modificadores de stats
---@class StatSources
---@field base table Stats base do caçador
---@field equipment StatModifier[] Bônus de todos os equipamentos
---@field levelUp StatModifier[] Bônus de todos os level ups
---@field archetypes StatModifier[] Bônus de todos os arquétipos

--- Informações de debug de dependências
---@class DependencyDebugInfo
---@field dependencies string[] Stats dos quais o stat especificado depende
---@field dependents string[] Stats que dependem do stat especificado

--- Snapshot do estado atual
---@class StateSnapshot
---@field finalStats table<string, number> Stats finais no momento do snapshot
---@field timestamp number Timestamp Unix do snapshot
---@field sources StatSources Informações sobre as fontes de modificadores

--- PlayerStateController - Gerencia stats do jogador com otimizações de performance
---@class PlayerStateController
local PlayerStateController = {}
PlayerStateController.__index = PlayerStateController

--- Cria uma nova instância do controlador de estado
---@param eventService EventService Serviço de eventos
---@return PlayerStateController instance Nova instância
function PlayerStateController:new(eventService)
    ---@class PlayerStateController
    local instance = setmetatable({}, PlayerStateController)

    instance.finalStats = {}
    instance.sources = {
        base = HunterBaseStats,
        equipment = {},
        levelUp = {},
        archetypes = {}
    }

    instance.eventService = eventService
    instance.eventListeners = {}

    -- Cache e otimizações
    instance.dependencyGraphCache = nil
    instance.modifiersCache = nil
    instance.lastModifiersHash = nil

    -- Debouncing
    instance.recalculationPending = false
    instance.recalculationTimer = nil

    return instance
end

--- Inicializa o controlador, configurando estado inicial e registrando listeners
function PlayerStateController:init()
    Logger.info("player_state_controller.init", "[PlayerStateController:init] Initializing...")
    self:_registerEventListeners()
    self:_triggerRecalculation()
end

---@public Obtem um unico stat
---@param statName StatKey Nome do stat
---@return number Valor do stat
function PlayerStateController:getStat(statName)
    return self.finalStats[statName]
end

---@public Obtem uma tabela com os valores dos stats solicitados
---@param statNames StatKey[] Nome do stat, lista de nomes, ou nil para todos
---@return number|table<StatKey, number> Valor do stat ou tabela com valores
---@usage
---local hp = controller:getStats("hp")
---local combat = controller:getStats({"attack", "defense"})
---local all = controller:getStats()
function PlayerStateController:getStats(statNames)
    local result = {}
    for _, statName in ipairs(statNames) do
        result[statName] = self.finalStats[statName] or 0
    end
    return result
end

---@public Obtém o valor final de um ou múltiplos stats
---@return table<StatKey, number> Tabela com todos os stats
function PlayerStateController:getAllStats()
    return self.finalStats
end

---@private Registra listeners de eventos para atualizações
function PlayerStateController:_registerEventListeners()
    local events = self.eventService.EVENTS
    self:_listen(events.ARCHETYPE_BONUSES_UPDATED, self._onArchetypeBonusesUpdated)
    self:_listen(events.EQUIPMENT_BONUSES_UPDATED, self._onEquipmentBonusesUpdated)
    -- TODO: Adicionar listeners para LevelUp
end

---@private Registra um listener de evento
---@param event string Nome do evento
---@param handler function Handler para o evento
function PlayerStateController:_listen(event, handler)
    local listener = self.eventService:on(event, function(data) handler(self, data) end)
    table.insert(self.eventListeners, listener)
end

---@private Handler para atualização de bônus de arquétipo
---@param data table Dados do evento com modificadores
function PlayerStateController:_onArchetypeBonusesUpdated(data)
    if not self:_validateEventData(data, "archetypes") then
        return
    end

    Logger.info("player_state_controller.archetypes_updated",
        "[PlayerStateController] Archetype bonuses updated.")

    self.sources.archetypes = data.modifiers
    self:_triggerRecalculation()
end

---@private Handler para atualização de bônus de equipamento
---@param data table Dados do evento com modificadores
function PlayerStateController:_onEquipmentBonusesUpdated(data)
    if not self:_validateEventData(data, "equipment") then
        return
    end

    Logger.info("player_state_controller.equipment_updated",
        "[PlayerStateController] Equipment bonuses updated.")

    self.sources.equipment = data.modifiers
    self:_triggerRecalculation()
end

---@private Valida dados de evento recebidos
---@param data table Dados para validar
---@param source string Fonte dos dados
---@return boolean True se válido
function PlayerStateController:_validateEventData(data, source)
    if not data or not data.modifiers then
        Logger.warn("player_state_controller",
            string.format("Received invalid %s bonuses data", source))
        return false
    end

    -- Valida cada modificador
    for i, modifier in ipairs(data.modifiers) do
        if not self:_validateModifier(modifier) then
            Logger.error("player_state_controller",
                string.format("Invalid modifier at index %d in %s bonuses", i, source))
            return false
        end
    end

    return true
end

---@private Valida um modificador individual
---@param modifier StatModifier Modificador para validar
---@return boolean True se válido
function PlayerStateController:_validateModifier(modifier)
    -- Cria lookup table para stats se não existir
    if not self._statsLookup then
        self._statsLookup = {}
        for _, stat in ipairs(ALL_STATS) do
            self._statsLookup[stat] = true
        end
    end

    if not modifier.stat or not self._statsLookup[modifier.stat] then
        Logger.error("player_state_controller",
            string.format("Invalid stat '%s' in modifier", tostring(modifier.stat)))
        return false
    end

    if not modifier.type or (modifier.type ~= "FLAT" and modifier.type ~= "PERCENTAGE") then
        Logger.error("player_state_controller",
            string.format("Invalid modifier type '%s'", tostring(modifier.type)))
        return false
    end

    if modifier.value == nil then
        Logger.error("player_state_controller", "Modifier value cannot be nil")
        return false
    end

    return true
end

---@private Gera hash dos modificadores atuais para cache
---@return string Hash representando estado atual dos modificadores
function PlayerStateController:_getModifiersHash()
    local hashParts = {}
    for source, modifiers in pairs(self.sources) do
        if source ~= "base" then
            table.insert(hashParts, source .. ":" .. #modifiers)
        end
    end
    return table.concat(hashParts, "|")
end

---@private Dispara recálculo com debounce para evitar recálculos excessivos
function PlayerStateController:_triggerRecalculation()
    if self.recalculationPending then
        return -- Já tem um recálculo pendente
    end

    self.recalculationPending = true

    -- Cancela timer anterior se existir
    if self.recalculationTimer then
        self.recalculationTimer:cancel()
    end

    -- Simula timer com coroutine (adapte para seu sistema)
    self.recalculationTimer = {
        cancel = function() end -- Placeholder
    }

    -- Em um sistema real, use seu timer aqui
    -- Timer.after(CONFIG.DEBOUN-CE_TIME, function()
    --    self:_performRecalculation()
    --    self.recalculationPending = false
    -- end)

    -- Por enquanto, executa imediatamente
    self:_performRecalculation()
    self.recalculationPending = false
end

---@private Executa o recálculo efetivo
function PlayerStateController:_performRecalculation()
    -- TODO: Obter dados reais de outros managers
    local context = {
        level = 1, -- Mocked
        kills = 0, -- Mocked
        time = 0   -- Mocked
    }
    self:_recalculateAllStats(context)
end

---@private Orquestra o recálculo completo de todos os stats
---@param context GameplayContext Contexto atual do jogo
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
        newFinalStats[statName] = self:_calculateStat(statName, baseValue, allModifiers, newFinalStats, context)
    end

    -- Atualiza stats finais e emite eventos apenas para os que mudaram
    for statName, newValue in pairs(newFinalStats) do
        self:_updateFinalStat(statName, newValue)
    end
end

---@private Calcula o valor final de um stat específico
---@param statName string Nome do stat
---@param baseValue number Valor base do stat
---@param modifiers StatModifier[] Lista de modificadores
---@param finalStats table Stats já calculados (para dependências)
---@param context GameplayContext Contexto do jogo
---@return number Valor final calculado
function PlayerStateController:_calculateStat(statName, baseValue, modifiers, finalStats, context)
    local flatBonus = 0
    local percentBonus = 0

    for _, modifier in ipairs(modifiers) do
        if modifier.stat == statName then
            local value = modifier.value
            if type(value) == "function" then
                value = value(finalStats, context)
            end

            if modifier.type == "FLAT" then
                flatBonus = flatBonus + value
            elseif modifier.type == "PERCENTAGE" then
                percentBonus = percentBonus + value
            end
        end
    end

    return (baseValue + flatBonus) * (1 + percentBonus / 100)
end

---@private Constrói grafo de dependências com cache
---@param modifiers StatModifier[] Lista de modificadores
---@return table<string, string[]> Grafo de adjacências
function PlayerStateController:_buildDependencyGraph(modifiers)
    if not CONFIG.ENABLE_CACHING then
        return self:_buildDependencyGraphUncached(modifiers)
    end

    local currentHash = self:_getModifiersHash()

    -- Usa cache se os modificadores não mudaram
    if self.dependencyGraphCache and self.lastModifiersHash == currentHash then
        Logger.debug("player_state_controller.cache", "Using cached dependency graph")
        return self.dependencyGraphCache
    end

    local graph = self:_buildDependencyGraphUncached(modifiers)

    -- Atualiza cache
    self.dependencyGraphCache = graph
    self.lastModifiersHash = currentHash

    return graph
end

---@private Constrói grafo de dependências sem cache
---@param modifiers StatModifier[] Lista de modificadores
---@return table<string, string[]> Grafo de adjacências
function PlayerStateController:_buildDependencyGraphUncached(modifiers)
    local graph = {}
    for _, stat in ipairs(ALL_STATS) do
        graph[stat] = {}
    end

    -- Cria lookup table para stats
    local statsLookup = {}
    for _, stat in ipairs(ALL_STATS) do
        statsLookup[stat] = true
    end

    Logger.info("build_dependency_graph.start", "--- Building Dependency Graph ---")

    for _, modifier in ipairs(modifiers) do
        if type(modifier.value) == "function" then
            Logger.debug("build_dependency_graph.modifier",
                string.format("Processing modifier for '%s' from source '%s'",
                    modifier.stat, modifier.source or "unknown"))

            -- Prioriza dependencies explícitas se disponíveis
            if modifier.dependencies then
                for _, dep in ipairs(modifier.dependencies) do
                    if statsLookup[dep] and dep ~= modifier.stat then
                        Logger.debug("build_dependency_graph.edge_added",
                            string.format("  -> Explicit dependency: '%s' depends on '%s'",
                                modifier.stat, dep))
                        table.insert(graph[dep], modifier.stat)
                    end
                end
            else
                -- Fallback para detecção por string (menos eficiente)
                local funcStr = string.dump(modifier.value)
                for _, dependencyStat in ipairs(ALL_STATS) do
                    if dependencyStat ~= modifier.stat and
                        funcStr:match("finalStats%." .. dependencyStat) then
                        Logger.debug("build_dependency_graph.edge_added",
                            string.format("  -> Detected dependency: '%s' depends on '%s'",
                                modifier.stat, dependencyStat))
                        table.insert(graph[dependencyStat], modifier.stat)
                    end
                end
            end
        end
    end

    -- Log do grafo final
    local graphStr = "Final Graph: {\n"
    for stat, dependencies in pairs(graph) do
        if #dependencies > 0 then
            graphStr = graphStr .. string.format("  %s -> {%s}\n",
                stat, table.concat(dependencies, ", "))
        end
    end
    graphStr = graphStr .. "}"
    Logger.info("build_dependency_graph.result", graphStr)
    Logger.info("build_dependency_graph.end", "--- Dependency Graph Built ---")

    return graph
end

--- Ordena stats usando algoritmo de Kahn (Ordenação Topológica)
---@param graph table<string, string[]> Grafo de dependências
---@return string[]|nil, string|nil Lista ordenada ou nil + erro em caso de ciclo
function PlayerStateController:_topologicalSort(graph)
    local inDegree = {}
    local queue = {}
    local result = {}

    -- Inicializa grau de entrada
    for stat, _ in pairs(graph) do
        inDegree[stat] = 0
    end

    -- Calcula grau de entrada
    for u, neighbors in pairs(graph) do
        for _, v in ipairs(neighbors) do
            inDegree[v] = (inDegree[v] or 0) + 1
        end
    end

    -- Adiciona nós sem dependências à fila
    for stat, degree in pairs(inDegree) do
        if degree == 0 then
            table.insert(queue, stat)
        end
    end

    -- Processa ordenação topológica
    local iterations = 0
    while #queue > 0 do
        iterations = iterations + 1
        if iterations > CONFIG.MAX_CALCULATION_ITERATIONS then
            return nil, "Maximum iterations exceeded"
        end

        local u = table.remove(queue, 1)
        table.insert(result, u)

        for _, v in ipairs(graph[u]) do
            inDegree[v] = inDegree[v] - 1
            if inDegree[v] == 0 then
                table.insert(queue, v)
            end
        end
    end

    -- Verifica se todos os stats foram processados
    if #result ~= #ALL_STATS then
        return nil, "Cycle detected"
    end

    return result
end

---@private Atualiza valor final de um stat e emite evento se mudou
---@param statName string Nome do stat
---@param newValue number Novo valor
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

---@private Agrega modificadores de todas as fontes
---@return StatModifier[] Lista consolidada de modificadores
function PlayerStateController:_getAllModifiers()
    -- Usa cache se disponível
    local currentHash = self:_getModifiersHash()
    if self.modifiersCache and self.lastModifiersHash == currentHash then
        return self.modifiersCache
    end

    local all = {}
    for _, mod in ipairs(self.sources.archetypes) do table.insert(all, mod) end
    for _, mod in ipairs(self.sources.equipment) do table.insert(all, mod) end
    for _, mod in ipairs(self.sources.levelUp) do table.insert(all, mod) end

    -- Atualiza cache
    self.modifiersCache = all

    return all
end

---@public Limpa recursos e desregistra listeners para evitar memory leaks
function PlayerStateController:destroy()
    Logger.info("player_state_controller.destroy", "[PlayerStateController:destroy] Destroying V2...")

    -- Cancela timer pendente
    if self.recalculationTimer then
        self.recalculationTimer:cancel()
    end

    -- Remove listeners
    for _, listener in ipairs(self.eventListeners) do
        self.eventService:off(listener.event, listener.id)
    end

    -- Limpa caches
    self.dependencyGraphCache = nil
    self.modifiersCache = nil

    -- Limpa referencias
    self.eventListeners = {}
    self.finalStats = {}
end

return PlayerStateController
