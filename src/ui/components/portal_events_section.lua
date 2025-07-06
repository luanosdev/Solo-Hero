local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local Logger = require("src.libs.logger")

--- Seção de eventos aleatórios do portal
---@class PortalEventsSection
---@field isVisible boolean Se a seção está visível
---@field animationX number Posição X atual da animação
---@field targetX number Posição X final da animação
---@field animationSpeed number Velocidade da animação
---@field sectionWidth number Largura da seção
---@field sectionHeight number Altura da seção
---@field padding number Espaçamento interno
---@field portalName string Nome do portal
---@field portalMap string Nome do mapa
---@field events EventData[] Lista de eventos aleatórios
local PortalEventsSection = {}
PortalEventsSection.__index = PortalEventsSection

--- Dados de um evento aleatório
---@class EventData
---@field name string Nome do evento
---@field description string Descrição do evento
---@field rank string Rank do evento (E, D, C, B, A, S)
---@field type string Tipo do evento


--- Eventos mock para demonstração
---@type table<string, EventData[]>
local MOCK_EVENTS = {
    ["plains"] = {
        { name = "Baú Perdido",          description = "Um baú trancado escondido nas planícies", rank = "C", type = "treasure" },
        { name = "Caçador Desaparecido", description = "Fantasma de um caçador perdido",          rank = "B", type = "boss" },
        { name = "Zona de Corrupção",    description = "Área corrompida com loot melhor",         rank = "A", type = "area" },
        { name = "Comerciante Perdido",  description = "Mercador com itens raros",                rank = "D", type = "npc" },
        { name = "Mineração",            description = "Pedras roxosas para minerar",             rank = "E", type = "resource" }
    },
    ["dungeon"] = {
        { name = "Ritual Sombrio",     description = "Círculo mágico com bônus temporários",   rank = "B", type = "ritual" },
        { name = "Tempestade de Mana", description = "Regeneração de mana aumentada",          rank = "A", type = "weather" },
        { name = "Ameaça Eminente",    description = "Bosses mais fortes nas redondezas",      rank = "S", type = "boss" },
        { name = "Altar Ancestral",    description = "Sacrifique itens por bônus permanentes", rank = "C", type = "altar" },
        { name = "Invasão",            description = "Ondas extras de inimigos",               rank = "B", type = "invasion" }
    },
    ["forest"] = {
        { name = "Neblina Venenosa",     description = "Visibilidade reduzida, inimigos mais fracos", rank = "D", type = "weather" },
        { name = "Vento Gelado",         description = "Velocidade reduzida, drop rate aumentado",    rank = "C", type = "weather" },
        { name = "Caçador Desaparecido", description = "Espírito vingativo na floresta",              rank = "A", type = "boss" },
        { name = "Baú Perdido",          description = "Tesouro escondido entre as árvores",          rank = "E", type = "treasure" },
        { name = "Zona de Corrupção",    description = "Área infectada com recompensas",              rank = "B", type = "area" }
    },
    ["cemetery"] = {
        { name = "Ameaça Eminente",    description = "Mortos-vivos mais poderosos",   rank = "S", type = "boss" },
        { name = "Ritual Sombrio",     description = "Círculos necromânticos ativos", rank = "A", type = "ritual" },
        { name = "Invasão",            description = "Horda de mortos-vivos",         rank = "B", type = "invasion" },
        { name = "Altar Ancestral",    description = "Altar profano dos antigos",     rank = "C", type = "altar" },
        { name = "Tempestade de Mana", description = "Energia sombria no ar",         rank = "D", type = "weather" }
    }
}

--- Cria uma nova instância da seção de eventos
---@param config table Configurações da seção
---@return PortalEventsSection instance Nova instância
function PortalEventsSection.new(config)
    config = config or {}

    local instance = setmetatable({}, PortalEventsSection)

    -- Configurações da seção
    instance.isVisible = false
    instance.sectionWidth = config.sectionWidth or 400
    instance.sectionHeight = config.sectionHeight or 600
    instance.padding = config.padding or 20

    -- Começa fora da tela à direita e vai para a direita (posição final)
    instance.animationX = 1920 + instance.sectionWidth
    instance.targetX = config.targetX or (1920 - instance.sectionWidth - 50)
    instance.animationSpeed = config.animationSpeed or 10.0

    -- Dados do portal
    instance.portalName = ""
    instance.portalMap = ""
    instance.events = {}

    Logger.info(
        "portal_events_section.new",
        "[PortalEventsSection] Seção de eventos criada"
    )

    return instance
end

--- Exibe a seção com animação
function PortalEventsSection:show()
    if self.isVisible then return end

    self.isVisible = true
    -- Reset para posição inicial (fora da tela à direita)
    self.animationX = 1920 + self.sectionWidth

    Logger.info(
        "portal_events_section.show",
        "[PortalEventsSection] Seção de eventos exibida"
    )
end

--- Oculta a seção
function PortalEventsSection:hide()
    if not self.isVisible then return end

    self.isVisible = false
    self.animationX = 1920 + self.sectionWidth

    Logger.info(
        "portal_events_section.hide",
        "[PortalEventsSection] Seção de eventos ocultada"
    )
end

--- Atualiza os dados do portal e gera eventos aleatórios
---@param portalName string Nome do portal
---@param portalMap string Nome do mapa
function PortalEventsSection:updatePortalData(portalName, portalMap)
    self.portalName = portalName or ""
    self.portalMap = portalMap or ""

    -- Gera eventos aleatórios baseados no mapa
    self:_generateRandomEvents()

    Logger.info(
        "portal_events_section.updatePortalData",
        string.format(
            "[PortalEventsSection] Dados atualizados - Portal: %s, Mapa: %s, Eventos: %d",
            self.portalName, self.portalMap, #self.events
        )
    )
end

--- Gera eventos aleatórios para o mapa atual
function PortalEventsSection:_generateRandomEvents()
    self.events = {}

    -- Pega os eventos disponíveis para o mapa
    local availableEvents = MOCK_EVENTS[self.portalMap] or MOCK_EVENTS["plains"]

    -- Seleciona 3-5 eventos aleatórios
    local numEvents = math.random(3, 5)
    local selectedEvents = {}

    -- Cria uma cópia dos eventos disponíveis
    local eventPool = {}
    for i, event in ipairs(availableEvents) do
        table.insert(eventPool, {
            name = event.name,
            description = event.description,
            rank = event.rank,
            type = event.type
        })
    end

    -- Seleciona eventos aleatórios sem repetir
    for i = 1, numEvents do
        if #eventPool == 0 then break end

        local randomIndex = math.random(1, #eventPool)
        local selectedEvent = eventPool[randomIndex]

        table.insert(self.events, selectedEvent)
        table.remove(eventPool, randomIndex)
    end
end

--- Converte o tipo do evento para nome legível
---@param eventType string Tipo do evento
---@return string displayName Nome para exibição
function PortalEventsSection:_getEventTypeDisplayName(eventType)
    local typeNames = {
        ["treasure"] = "Tesouro",
        ["boss"] = "Boss",
        ["area"] = "Área",
        ["npc"] = "NPC",
        ["resource"] = "Recurso",
        ["ritual"] = "Ritual",
        ["weather"] = "Clima",
        ["altar"] = "Altar",
        ["invasion"] = "Invasão"
    }

    return typeNames[eventType] or eventType:gsub("(%l)(%w*)", function(a, b) return a:upper() .. b end)
end

--- Atualiza a animação da seção
---@param dt number Delta time
function PortalEventsSection:update(dt)
    if not self.isVisible then return end

    -- Animação suave de X da direita para a esquerda
    if self.animationX > self.targetX then
        self.animationX = self.animationX - (self.animationX - self.targetX) * self.animationSpeed * dt

        -- Snap para posição final quando estiver muito próximo
        if math.abs(self.animationX - self.targetX) < 1 then
            self.animationX = self.targetX
        end
    end
end

--- Desenha a seção de eventos
---@param screenW number Largura da tela
---@param screenH number Altura da tela
function PortalEventsSection:draw(screenW, screenH)
    if not self.isVisible then return end

    -- Posição da seção
    local sectionX = self.animationX
    local sectionY = (screenH - self.sectionHeight) / 2

    -- Fundo da seção
    love.graphics.setColor(colors.window_bg)
    love.graphics.rectangle("fill", sectionX, sectionY, self.sectionWidth, self.sectionHeight)

    -- Borda da seção
    love.graphics.setColor(colors.window_border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", sectionX, sectionY, self.sectionWidth, self.sectionHeight)
    love.graphics.setLineWidth(1)

    -- Fonte para títulos e texto
    local titleFont = fonts.main_bold or fonts.main
    local sectionTitleFont = fonts.main_bold or fonts.main -- Para título principal da seção
    local labelFont = fonts.main_bold or fonts.main        -- Para labels dos eventos
    local textFont = fonts.main_small or fonts.main

    local currentY = sectionY + self.padding
    local lineHeight = textFont:getHeight() + 5
    local titleLineHeight = titleFont:getHeight() + 10

    -- Título da seção
    love.graphics.setFont(sectionTitleFont)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.print("EVENTOS ALEATÓRIOS", sectionX + self.padding, currentY)
    currentY = currentY + titleLineHeight

    -- Separador
    love.graphics.setColor(colors.window_border)
    love.graphics.line(sectionX + self.padding, currentY, sectionX + self.sectionWidth - self.padding, currentY)
    currentY = currentY + 15

    -- Descrição
    love.graphics.setFont(textFont)
    love.graphics.setColor(colors.text_muted)
    love.graphics.printf("Eventos especiais que podem ocorrer durante a exploração:",
        sectionX + self.padding, currentY, self.sectionWidth - self.padding * 2, "left")
    currentY = currentY + lineHeight * 2 + 10

    -- Lista de eventos
    if #self.events > 0 then
        for i, event in ipairs(self.events) do
            -- Nome do evento com cor baseada no rank
            local rankColor = colors.rankDetails[event.rank] and colors.rankDetails[event.rank].text or colors.text_main
            love.graphics.setFont(labelFont)
            love.graphics.setColor(rankColor)
            love.graphics.print("• " .. event.name, sectionX + self.padding, currentY)
            currentY = currentY + lineHeight + 2

            -- Tipo do evento
            love.graphics.setFont(textFont)
            love.graphics.setColor(colors.text_muted)
            love.graphics.print("  Tipo: " .. self:_getEventTypeDisplayName(event.type), sectionX + self.padding,
                currentY)
            currentY = currentY + lineHeight

            -- Descrição do evento
            love.graphics.setColor(colors.text_main)
            love.graphics.printf("  " .. event.description, sectionX + self.padding, currentY,
                self.sectionWidth - self.padding * 2, "left")
            currentY = currentY + lineHeight + 10
        end
    else
        love.graphics.setFont(textFont)
        love.graphics.setColor(colors.text_muted)
        love.graphics.print("• Nenhum evento especial encontrado", sectionX + self.padding, currentY)
        currentY = currentY + lineHeight
    end

    -- Resetar cor
    love.graphics.setColor(colors.white)
end

--- Verifica se a animação está completa
---@return boolean isComplete Se a animação está completa
function PortalEventsSection:isAnimationComplete()
    return self.isVisible and math.abs(self.animationX - self.targetX) < 1
end

return PortalEventsSection
