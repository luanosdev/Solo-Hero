---@class PortalTitleSection
---@field isVisible boolean Se a seção está visível
---@field animationY number Posição Y atual da animação
---@field targetY number Posição Y alvo da animação
---@field animationSpeed number Velocidade da animação
---@field portalName string Nome do portal
---@field portalRank string Rank do portal
---@field shadowOffset number Offset da sombra do texto
local PortalTitleSection = {}
PortalTitleSection.__index = PortalTitleSection

local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")

---@class PortalTitleSectionConfig
---@field portalName string Nome do portal
---@field portalRank string Rank do portal
---@field targetY number Posição Y alvo onde a seção deve aparecer
---@field animationSpeed number? Velocidade da animação (padrão: 8.0)
---@field shadowOffset number? Offset da sombra do texto (padrão: 3)

--- Cria uma nova instância da seção do título do portal
---@param config PortalTitleSectionConfig Configurações da seção
---@return PortalTitleSection
function PortalTitleSection.new(config)
    local instance = setmetatable({}, PortalTitleSection)

    instance.isVisible = false
    instance.animationY = -200 -- Começa acima da tela
    instance.targetY = config.targetY or 120
    instance.animationSpeed = config.animationSpeed or 8.0
    instance.portalName = config.portalName or "Portal Desconhecido"
    instance.portalRank = config.portalRank or "E"
    instance.shadowOffset = config.shadowOffset or 3

    Logger.info(
        "portal_title_section.new",
        "[PortalTitleSection] Criada nova seção do título para portal: " .. instance.portalName
    )

    return instance
end

--- Exibe a seção com animação
function PortalTitleSection:show()
    if self.isVisible then return end

    self.isVisible = true
    self.animationY = -200 -- Reset para posição inicial

    Logger.info(
        "portal_title_section.show",
        "[PortalTitleSection] Iniciando animação de entrada"
    )
end

--- Oculta a seção
function PortalTitleSection:hide()
    if not self.isVisible then return end

    self.isVisible = false
    self.animationY = -200

    Logger.info(
        "portal_title_section.hide",
        "[PortalTitleSection] Seção ocultada"
    )
end

--- Atualiza a seção do título
---@param portalName string Nome do portal
---@param portalRank string Rank do portal
function PortalTitleSection:updatePortalInfo(portalName, portalRank)
    self.portalName = portalName
    self.portalRank = portalRank

    Logger.info(
        "portal_title_section.updatePortalInfo",
        "[PortalTitleSection] Informações atualizadas: " .. portalName .. " (Rank " .. portalRank .. ")"
    )
end

--- Atualiza a animação da seção
---@param dt number Delta time
function PortalTitleSection:update(dt)
    if not self.isVisible then return end

    -- Animação suave de Y de cima para baixo
    if self.animationY < self.targetY then
        self.animationY = self.animationY + (self.targetY - self.animationY) * self.animationSpeed * dt

        -- Snap para posição final quando estiver muito próximo
        if math.abs(self.animationY - self.targetY) < 1 then
            self.animationY = self.targetY
        end
    end
end

--- Desenha a seção do título
---@param screenW number Largura da tela
---@param screenH number Altura da tela
function PortalTitleSection:draw(screenW, screenH)
    if not self.isVisible then return end

    -- Usar fonte grande para o título
    local titleFont = fonts.game_over or fonts.main_bold or fonts.main
    love.graphics.setFont(titleFont)

    -- Obter cores do rank do portal
    local rankColors = colors.rankDetails[self.portalRank]
    if not rankColors then
        -- Fallback para rank E se não encontrar o rank
        rankColors = colors.rankDetails.E
        Logger.warn(
            "portal_title_section.draw",
            string.format("[PortalTitleSection] Rank '%s' não encontrado, usando fallback", self.portalRank)
        )
    end

    -- Calcular posição centralizada na tela
    local textWidth = titleFont:getWidth(self.portalName)
    local textX = (screenW - textWidth) / 2
    local textY = self.animationY

    -- Desenhar sombra do texto usando gradientStart (mais escuro)
    love.graphics.setColor(
        rankColors.gradientStart[1],
        rankColors.gradientStart[2],
        rankColors.gradientStart[3],
        0.8
    )
    love.graphics.print(self.portalName, textX + self.shadowOffset, textY + self.shadowOffset)

    -- Desenhar texto principal usando a cor do texto do rank
    love.graphics.setColor(rankColors.text)
    love.graphics.print(self.portalName, textX, textY)

    -- Resetar cor
    love.graphics.setColor(colors.white)
end

--- Verifica se a animação está completa
---@return boolean isComplete Se a animação está completa
function PortalTitleSection:isAnimationComplete()
    return self.isVisible and math.abs(self.animationY - self.targetY) < 1
end

return PortalTitleSection
