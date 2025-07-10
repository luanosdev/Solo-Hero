local NotificationDisplay = require("src.ui.components.notification_display")

--- Gerencia o sistema global de notificações com animações e pooling
--- @class NotificationManager
local NotificationManager = {}

--- @class NotificationData
--- @field id string Identificador único da notificação
--- @field type string Tipo da notificação (Constants.NOTIFICATION_TYPES)
--- @field title string Título da notificação
--- @field value string|number Valor ou quantidade
--- @field icon love.Image|nil Ícone da notificação
--- @field rarityColor table|nil Cor de fundo baseada na raridade
--- @field duration number Duração em segundos antes de desaparecer
--- @field createdAt number Timestamp de criação
--- @field animationPhase string Fase atual da animação ("sliding_in", "visible", "fading_out")
--- @field animationTime number Tempo decorrido na animação atual
--- @field targetY number Posição Y de destino
--- @field currentY number Posição Y atual
--- @field alpha number Transparência atual (0-1)
--- @field isUpdatingValue boolean Se o valor está animando
--- @field valueAnimationTime number Temporizador para a animação de valor

--- @type NotificationData[]
local activeNotifications = {}

--- @type NotificationData[]
local notificationPool = {}

--- @type NotificationShowData[]
local pendingNotifications = {}

local timeSinceLastSpawn = 0

local nextNotificationId = 1

function NotificationManager.init()
    Logger.info("notification_manager.init.started", "[NotificationManager:init] Inicializando sistema de notificações")

    -- Pré-criar notificações no pool para evitar garbage collection
    for i = 1, NotificationDisplay.NOTIFICATION_SYSTEM.POOL_SIZE do
        local notification = NotificationManager._createEmptyNotification()
        table.insert(notificationPool, notification)
    end

    Logger.info("notification_manager.init.completed",
        "[NotificationManager:init] Sistema de notificações inicializado com " ..
        NotificationDisplay.NOTIFICATION_SYSTEM.POOL_SIZE .. " notificações no pool")
end

--- Cria uma notificação vazia para o pool
--- @return NotificationData
function NotificationManager._createEmptyNotification()
    return {
        id = "",
        type = "",
        title = "",
        value = "",
        icon = nil,
        rarityColor = nil,
        duration = NotificationDisplay.NOTIFICATION_SYSTEM.DEFAULT_DURATION,
        createdAt = 0,
        animationPhase = "sliding_in",
        animationTime = 0,
        targetY = 0,
        currentY = 0,
        alpha = 1.0,
        isUpdatingValue = false,
        valueAnimationTime = 0
    }
end

--- Obtém uma notificação do pool ou cria uma nova
--- @return NotificationData
function NotificationManager._getNotificationFromPool()
    if #notificationPool > 0 then
        return table.remove(notificationPool)
    else
        Logger.debug("notification_manager.pool.creating_new",
            "[NotificationManager:_getNotificationFromPool] Pool vazio, criando nova notificação")
        return NotificationManager._createEmptyNotification()
    end
end

--- Retorna uma notificação para o pool
--- @param notification NotificationData
function NotificationManager._returnNotificationToPool(notification)
    -- Reset dos valores para reutilização
    notification.id = ""
    notification.type = ""
    notification.title = ""
    notification.value = ""
    notification.icon = nil
    notification.rarityColor = nil
    notification.duration = NotificationDisplay.NOTIFICATION_SYSTEM.DEFAULT_DURATION
    notification.createdAt = 0
    notification.animationPhase = "sliding_in"
    notification.animationTime = 0
    notification.targetY = 0
    notification.currentY = 0
    notification.alpha = 1.0
    notification.isUpdatingValue = false
    notification.valueAnimationTime = 0

    table.insert(notificationPool, notification)
end

---@class NotificationShowData
---@field type string
---@field title string
---@field value string
---@field icon? love.Image
---@field rarityColor table
---@field duration number

--- Exibe uma nova notificação
--- @param data NotificationShowData
function NotificationManager.show(data)
    if not data.type or not data.title then
        Logger.warn("notification_manager.show.invalid_data",
            "[NotificationManager:show] Dados insuficientes para criar notificação")
        return
    end

    -- Futuramente, aqui pode haver lógica para agrupar notificações pendentes.
    -- Por agora, apenas enfileira.
    table.insert(pendingNotifications, data)
end

--- Procura por uma notificação similar já ativa
--- @param type string
--- @param title string
--- @return number|nil Índice da notificação encontrada
function NotificationManager._findSimilarNotification(type, title)
    for i, notification in ipairs(activeNotifications) do
        if notification.type == type and notification.title == title then
            return i
        end
    end
    return nil
end

--- Atualiza as posições de destino de todas as notificações
function NotificationManager._updateNotificationPositions()
    for i, notification in ipairs(activeNotifications) do
        local targetY =
            NotificationDisplay.NOTIFICATION_SYSTEM.NOTIFICATION_START_Y +
            (i - 1) *
            (NotificationDisplay.NOTIFICATION_SYSTEM.NOTIFICATION_HEIGHT + NotificationDisplay.NOTIFICATION_SYSTEM.NOTIFICATION_SPACING)

        notification.targetY = targetY

        -- Se é uma nova notificação (sliding_in), começar fora da tela
        if notification.animationPhase == "sliding_in" and notification.animationTime == 0 then
            notification.currentY = targetY
        end
    end
end

--- Remove notificações excedentes quando há muitas na tela
function NotificationManager._removeExcessNotifications()
    while #activeNotifications > NotificationDisplay.NOTIFICATION_SYSTEM.MAX_VISIBLE_NOTIFICATIONS do
        local oldestNotification = table.remove(activeNotifications)
        NotificationManager._returnNotificationToPool(oldestNotification)
        Logger.debug("notification_manager.remove.excess",
            "[NotificationManager:_removeExcessNotifications] Removida notificação excedente")
    end
end

--- Atualiza todas as notificações ativas
--- @param dt number Delta time
function NotificationManager.update(dt)
    timeSinceLastSpawn = timeSinceLastSpawn + dt

    -- Processa a fila de notificações pendentes
    if timeSinceLastSpawn >= NotificationDisplay.NOTIFICATION_SYSTEM.DELAY_BETWEEN_NOTIFICATIONS and #pendingNotifications > 0 then
        if #activeNotifications < NotificationDisplay.NOTIFICATION_SYSTEM.MAX_VISIBLE_NOTIFICATIONS then
            timeSinceLastSpawn = 0
            ---@type NotificationShowData
            local data = table.remove(pendingNotifications, 1)

            -- Verifica se uma notificação similar já está ativa para "atualizá-la"
            local existingIndex = NotificationManager._findSimilarNotification(data.type, data.title)

            if existingIndex then
                -- Remove da posição atual e reinsere no topo
                local existing = table.remove(activeNotifications, existingIndex)

                -- Lógica de incremento para itens
                if existing.type == NotificationDisplay.NOTIFICATION_TYPES.ITEM_PICKUP then
                    -- Extrai o número do valor antigo e do novo (formato "x<num>")
                    local oldValue = tonumber(string.match(existing.value, "+ (%d+)")) or 0
                    local newValue = tonumber(string.match(data.value, "+ (%d+)")) or 0
                    local totalValue = oldValue + newValue
                    existing.value = "+ " .. tostring(totalValue)
                else
                    -- Para outros tipos, apenas substitui o valor
                    existing.value = data.value or ""
                end

                existing.createdAt = love.timer.getTime()
                existing.animationPhase = "sliding_in"
                existing.animationTime = 0
                existing.alpha = NotificationDisplay.NOTIFICATION_SYSTEM.INITIAL_ALPHA
                existing.isUpdatingValue = true
                existing.valueAnimationTime = 0
                table.insert(activeNotifications, 1, existing)
                Logger.debug("notification_manager.update.refreshed_existing",
                    "[NotificationManager:update] Notificação atualizada: " ..
                    existing.title .. " para " .. existing.value)
            else
                -- Cria uma nova notificação
                local notification = NotificationManager._getNotificationFromPool()

                notification.id = "notification_" .. nextNotificationId
                nextNotificationId = nextNotificationId + 1
                notification.type = data.type
                notification.title = data.title
                notification.value = data.value or ""
                notification.icon = data.icon
                notification.rarityColor = data.rarityColor
                notification.duration = data.duration or NotificationDisplay.NOTIFICATION_SYSTEM.DEFAULT_DURATION
                notification.createdAt = love.timer.getTime()
                notification.animationPhase = "sliding_in"
                notification.animationTime = 0
                notification.alpha = NotificationDisplay.NOTIFICATION_SYSTEM.INITIAL_ALPHA
                notification.isUpdatingValue = false
                notification.valueAnimationTime = 0

                table.insert(activeNotifications, 1, notification)
                Logger.debug("notification_manager.update.new_notification",
                    "[NotificationManager:update] Nova notificação da fila: " .. notification.title)
            end

            NotificationManager._updateNotificationPositions()
        end
    end

    local currentTime = love.timer.getTime()

    -- Iterar de trás para frente para permitir remoção segura
    for i = #activeNotifications, 1, -1 do
        local notification = activeNotifications[i]

        -- Lida com a animação de atualização do valor
        if notification.isUpdatingValue then
            notification.valueAnimationTime = notification.valueAnimationTime + dt
            if notification.valueAnimationTime >= NotificationDisplay.NOTIFICATION_SYSTEM.VALUE_UPDATE_ANIMATION_DURATION then
                notification.isUpdatingValue = false
                notification.valueAnimationTime = 0
            end
        end

        local elapsedTime = currentTime - notification.createdAt

        -- Verificar se deve começar a fade out
        if notification.animationPhase == "visible" and elapsedTime >= notification.duration then
            notification.animationPhase = "fading_out"
            notification.animationTime = 0
        end

        -- Atualizar animação
        NotificationManager._updateNotificationAnimation(notification, dt)

        -- Remover notificação se fade out completou
        if notification.animationPhase == "fading_out" and
            notification.animationTime >= NotificationDisplay.NOTIFICATION_SYSTEM.FADE_OUT_DURATION then
            table.remove(activeNotifications, i)
            NotificationManager._returnNotificationToPool(notification)

            -- Reposicionar notificações restantes
            NotificationManager._updateNotificationPositions()
        end
    end
end

--- Atualiza a animação de uma notificação específica
--- @param notification NotificationData
--- @param dt number
function NotificationManager._updateNotificationAnimation(notification, dt)
    notification.animationTime = notification.animationTime + dt

    if notification.animationPhase == "sliding_in" then
        local progress = math.min(
            notification.animationTime / NotificationDisplay.NOTIFICATION_SYSTEM.SLIDE_IN_DURATION,
            1.0
        )

        -- Interpolação suave para entrada (movimento vertical para posição final)
        local easeProgress = 1 - math.pow(1 - progress, 3)
        notification.currentY = notification.targetY

        if progress >= 1.0 then
            notification.animationPhase = "visible"
            notification.animationTime = 0
        end
    elseif notification.animationPhase == "visible" then
        -- Interpolação suave para a posição de destino
        local targetY = notification.targetY
        local currentY = notification.currentY
        local diff = targetY - currentY

        if math.abs(diff) > 1 then
            notification.currentY = currentY + diff * dt * 8 -- Velocidade de movimento vertical
        else
            notification.currentY = targetY
        end
    elseif notification.animationPhase == "fading_out" then
        local progress = math.min(
            notification.animationTime / NotificationDisplay.NOTIFICATION_SYSTEM.FADE_OUT_DURATION,
            1.0
        )
        notification.alpha = 1.0 - progress
    end
end

--- Retorna todas as notificações ativas para renderização
--- @return NotificationData[]
function NotificationManager.getActiveNotifications()
    return activeNotifications
end

--- Remove todas as notificações ativas
function NotificationManager.clear()
    for _, notification in ipairs(activeNotifications) do
        NotificationManager._returnNotificationToPool(notification)
    end
    activeNotifications = {}
    Logger.info("notification_manager.clear.completed",
        "[NotificationManager:clear] Todas as notificações foram removidas")
end

--- Obtém estatísticas do sistema de notificações
--- @return table
function NotificationManager.getStats()
    return {
        activeCount = #activeNotifications,
        poolCount = #notificationPool,
        pendingCount = #pendingNotifications,
        nextId = nextNotificationId
    }
end

return NotificationManager
