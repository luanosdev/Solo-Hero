local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local Logger = require("src.libs.logger")

--- Seção de ação do portal (botão de iniciar missão)
---@class PortalActionSection
---@field isVisible boolean Se a seção está visível
---@field animationY number Posição Y atual da animação
---@field targetY number Posição Y final da animação
---@field animationSpeed number Velocidade da animação
---@field sectionWidth number Largura da seção
---@field sectionHeight number Altura da seção
---@field padding number Espaçamento interno
---@field buttonWidth number Largura do botão
---@field buttonHeight number Altura do botão
---@field portalName string Nome do portal
---@field portalRank string Rank do portal
---@field isButtonHovered boolean Se o botão está sendo hover
---@field buttonRect table Retângulo do botão para detecção de clique
local PortalActionSection = {}
PortalActionSection.__index = PortalActionSection

--- Configurações da seção de ação
---@class PortalActionSectionConfig
---@field targetY? number Posição Y alvo onde a seção deve aparecer
---@field animationSpeed? number Velocidade da animação (padrão: 10.0)
---@field sectionWidth? number Largura da seção (padrão: 500)
---@field sectionHeight? number Altura da seção (padrão: 120)
---@field padding? number Espaçamento interno (padrão: 20)
---@field buttonWidth? number Largura do botão (padrão: 300)
---@field buttonHeight? number Altura do botão (padrão: 60)


--- Cria uma nova instância da seção de ação
---@param config PortalActionSectionConfig? Configurações da seção
---@return PortalActionSection instance Nova instância
function PortalActionSection.new(config)
    config = config or {}

    local instance = setmetatable({}, PortalActionSection)

    -- Configurações da seção
    instance.isVisible = false
    instance.sectionWidth = config.sectionWidth or 500
    instance.sectionHeight = config.sectionHeight or 120
    instance.padding = config.padding or 20
    instance.buttonWidth = config.buttonWidth or 300
    instance.buttonHeight = config.buttonHeight or 60

    -- Começa fora da tela embaixo e vai para cima
    instance.animationY = 1080 + instance.buttonHeight
    instance.targetY = config.targetY or (1080 - instance.buttonHeight - 100)
    instance.animationSpeed = config.animationSpeed or 10.0

    -- Dados do portal
    instance.portalName = "Portal Desconhecido"
    instance.portalRank = "E"

    -- Estado do botão
    instance.isButtonHovered = false
    instance.buttonRect = { x = 0, y = 0, width = instance.buttonWidth, height = instance.buttonHeight }

    Logger.info(
        "portal_action_section.new",
        "[PortalActionSection] Seção de ação criada"
    )

    return instance
end

--- Exibe a seção com animação
function PortalActionSection:show()
    if self.isVisible then return end

    self.isVisible = true
    -- Reset para posição inicial (fora da tela embaixo)
    self.animationY = 1080 + self.buttonHeight

    Logger.info(
        "portal_action_section.show",
        "[PortalActionSection] Seção de ação exibida"
    )
end

--- Oculta a seção
function PortalActionSection:hide()
    if not self.isVisible then return end

    self.isVisible = false
    self.animationY = 1080 + self.buttonHeight

    Logger.info(
        "portal_action_section.hide",
        "[PortalActionSection] Seção de ação ocultada"
    )
end

--- Atualiza os dados do portal
---@param portalName string Nome do portal
---@param portalRank string Rank do portal
function PortalActionSection:updatePortalData(portalName, portalRank)
    self.portalName = portalName or "Portal Desconhecido"
    self.portalRank = portalRank or "E"

    Logger.info(
        "portal_action_section.updatePortalData",
        string.format(
            "[PortalActionSection] Dados atualizados - Portal: %s, Rank: %s",
            self.portalName, self.portalRank
        )
    )
end

--- Atualiza a animação e estado do botão
---@param dt number Delta time
---@param mx number Posição X do mouse
---@param my number Posição Y do mouse
function PortalActionSection:update(dt, mx, my)
    if not self.isVisible then return end

    -- Animação suave de Y de baixo para cima
    if self.animationY > self.targetY then
        self.animationY = self.animationY - (self.animationY - self.targetY) * self.animationSpeed * dt

        -- Snap para posição final quando estiver muito próximo
        if math.abs(self.animationY - self.targetY) < 1 then
            self.animationY = self.targetY
        end
    end

    -- Atualizar posição do botão para detecção de hover
    local buttonX = (1920 - self.buttonWidth) / 2
    local buttonY = self.animationY

    self.buttonRect.x = buttonX
    self.buttonRect.y = buttonY

    -- Verificar hover do botão
    self.isButtonHovered = mx >= buttonX and mx <= buttonX + self.buttonWidth and
        my >= buttonY and my <= buttonY + self.buttonHeight
end

--- Desenha a seção de ação
---@param screenW number Largura da tela
---@param screenH number Altura da tela
function PortalActionSection:draw(screenW, screenH)
    if not self.isVisible then return end

    -- Fonte para texto
    local titleFont = fonts.main_bold or fonts.main

    -- Botão centralizado na tela
    local buttonX = (screenW - self.buttonWidth) / 2
    local buttonY = self.animationY

    -- Cor do botão baseada no rank e hover
    local rankColor = colors.rankDetails[self.portalRank] and colors.rankDetails[self.portalRank].gradientStart or
        colors.button_primary
    local buttonColor = rankColor

    -- Efeito de hover
    if self.isButtonHovered then
        -- Aumentar intensidade da cor no hover
        buttonColor = {
            math.min(1.0, rankColor[1] + 0.1),
            math.min(1.0, rankColor[2] + 0.1),
            math.min(1.0, rankColor[3] + 0.1),
            rankColor[4] or 1.0
        }
    end

    -- Fundo do botão
    love.graphics.setColor(buttonColor)
    love.graphics.rectangle("fill", buttonX, buttonY, self.buttonWidth, self.buttonHeight)

    -- Borda do botão
    love.graphics.setColor(colors.white)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", buttonX, buttonY, self.buttonWidth, self.buttonHeight)
    love.graphics.setLineWidth(1)

    -- Texto do botão
    love.graphics.setFont(titleFont)
    love.graphics.setColor(colors.white)
    local buttonText = "ENTRAR NO PORTAL"
    love.graphics.printf(buttonText, buttonX, buttonY + (self.buttonHeight - titleFont:getHeight()) / 2, self
        .buttonWidth, "center")

    -- Resetar cor
    love.graphics.setColor(colors.white)
end

--- Verifica se a animação está completa
---@return boolean isComplete Se a animação está completa
function PortalActionSection:isAnimationComplete()
    return self.isVisible and math.abs(self.animationY - self.targetY) < 1
end

--- Verifica se o botão foi clicado
---@param mx number Posição X do mouse
---@param my number Posição Y do mouse
---@return boolean wasClicked Se o botão foi clicado
function PortalActionSection:isButtonClicked(mx, my)
    if not self.isVisible then return false end

    return mx >= self.buttonRect.x and mx <= self.buttonRect.x + self.buttonWidth and
        my >= self.buttonRect.y and my <= self.buttonRect.y + self.buttonHeight
end

--- Obtém os dados do portal para iniciar a missão
---@return table portalData Dados do portal
function PortalActionSection:getPortalData()
    return {
        name = self.portalName,
        rank = self.portalRank
    }
end

return PortalActionSection
