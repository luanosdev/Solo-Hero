---@class PortalLoadoutSection
---@field isVisible boolean Se a seção está visível
---@field animationX number Posição X atual da animação
---@field targetX number Posição X alvo da animação
---@field animationSpeed number Velocidade da animação
---@field portalName string Nome do portal
---@field portalMap string Mapa do portal
---@field bosses table Lista de bosses do portal
---@field enemies table Lista de inimigos do portal
---@field sectionWidth number Largura da seção
---@field sectionHeight number Altura da seção
---@field padding number Espaçamento interno
local PortalLoadoutSection = {}
PortalLoadoutSection.__index = PortalLoadoutSection

local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")

---@class PortalLoadoutSectionConfig
---@field targetX? number Posição X alvo onde a seção deve aparecer
---@field animationSpeed number? Velocidade da animação (padrão: 10.0)
---@field sectionWidth number? Largura da seção (padrão: 400)
---@field sectionHeight number? Altura da seção (padrão: 600)
---@field padding number? Espaçamento interno (padrão: 20)

--- Cria uma nova instância da seção de loadout do portal
---@param config PortalLoadoutSectionConfig Configurações da seção
---@return PortalLoadoutSection
function PortalLoadoutSection.new(config)
    local instance = setmetatable({}, PortalLoadoutSection)

    instance.isVisible = false
    instance.sectionWidth = config.sectionWidth or 400
    instance.sectionHeight = config.sectionHeight or 600
    instance.padding = config.padding or 20

    -- Começa fora da tela à esquerda e vai para a esquerda (posição final)
    instance.animationX = -instance.sectionWidth
    instance.targetX = config.targetX or 50
    instance.animationSpeed = config.animationSpeed or 10.0

    -- Dados do portal
    instance.portalName = "Portal Desconhecido"
    instance.portalMap = "plains"
    instance.bosses = {}
    instance.enemies = {}

    Logger.info(
        "portal_loadout_section.new",
        "[PortalLoadoutSection] Criada nova seção de loadout"
    )

    return instance
end

--- Exibe a seção com animação
function PortalLoadoutSection:show()
    if self.isVisible then return end

    self.isVisible = true
    -- Reset para posição inicial (fora da tela à esquerda)
    self.animationX = -self.sectionWidth

    Logger.info(
        "portal_loadout_section.show",
        "[PortalLoadoutSection] Iniciando animação de entrada"
    )
end

--- Oculta a seção
function PortalLoadoutSection:hide()
    if not self.isVisible then return end

    self.isVisible = false
    self.animationX = -self.sectionWidth

    Logger.info(
        "portal_loadout_section.hide",
        "[PortalLoadoutSection] Seção ocultada"
    )
end

--- Atualiza as informações do portal baseadas nas definições
--- Utiliza os nomes das classes diretamente (class.name) quando disponível,
--- com fallback para conversão do unitType para compatibilidade
---@param portalDefinition table Definição do portal do portal_definitions.lua
function PortalLoadoutSection:updatePortalData(portalDefinition)
    if not portalDefinition then
        Logger.warn(
            "portal_loadout_section.updatePortalData",
            "[PortalLoadoutSection] Definição do portal não fornecida"
        )
        return
    end

    -- Atualizar dados básicos
    self.portalName = portalDefinition.name or "Portal Desconhecido"
    self.portalMap = portalDefinition.map or "plains"

    -- Processar bosses
    self.bosses = {}
    if portalDefinition.hordeConfig and portalDefinition.hordeConfig.bossConfig then
        for _, bossSpawn in ipairs(portalDefinition.hordeConfig.bossConfig.spawnTimes) do
            local bossName = "Boss Desconhecido"

            -- Tentar pegar nome da classe diretamente
            if bossSpawn.class and bossSpawn.class.name then
                bossName = bossSpawn.class.name
            else
                -- Fallback para o método antigo se não tiver classe
                bossName = self:_getBossDisplayName(bossSpawn.unitType)
            end

            table.insert(self.bosses, {
                name = bossName,
                rank = bossSpawn.rank,
                time = bossSpawn.time
            })
        end
    end

    -- Processar inimigos únicos de todos os ciclos
    self.enemies = {}
    local uniqueEnemies = {}
    if portalDefinition.hordeConfig and portalDefinition.hordeConfig.cycles then
        for _, cycle in ipairs(portalDefinition.hordeConfig.cycles) do
            if cycle.allowedEnemies then
                for _, enemy in ipairs(cycle.allowedEnemies) do
                    if not uniqueEnemies[enemy.unitType] then
                        uniqueEnemies[enemy.unitType] = true

                        local enemyName = "Inimigo Desconhecido"

                        -- Tentar pegar nome da classe diretamente
                        if enemy.class and enemy.class.name then
                            enemyName = enemy.class.name
                        else
                            -- Fallback para o método antigo se não tiver classe
                            enemyName = self:_getEnemyDisplayName(enemy.unitType)
                        end

                        table.insert(self.enemies, {
                            name = enemyName,
                            weight = enemy.weight
                        })
                    end
                end
            end
        end
    end

    Logger.info(
        "portal_loadout_section.updatePortalData",
        string.format(
            "[PortalLoadoutSection] Dados atualizados - Portal: %s, Mapa: %s, Bosses: %d, Inimigos: %d",
            self.portalName, self.portalMap, #self.bosses, #self.enemies
        )
    )
end

--- Converte o unitType do boss para nome legível
---@param unitType string Tipo da unidade
---@return string displayName Nome para exibição
function PortalLoadoutSection:_getBossDisplayName(unitType)
    local bossNames = {
        ["the_rotten_immortal"] = "O Imortal Apodrecido",
        ["spider"] = "Aranha Gigante",
        ["skeleton_king"] = "Rei Esqueleto",
        ["zombie_lord"] = "Lorde Zumbi"
    }

    return bossNames[unitType] or unitType:gsub("_", " "):gsub("(%l)(%w*)", function(a, b) return a:upper() .. b end)
end

--- Converte o unitType do inimigo para nome legível
---@param unitType string Tipo da unidade
---@return string displayName Nome para exibição
function PortalLoadoutSection:_getEnemyDisplayName(unitType)
    local enemyNames = {
        ["zombie_walker_male_1"] = "Zumbi Caminhante (M)",
        ["zombie_walker_female_1"] = "Zumbi Caminhante (F)",
        ["zombie_runner_male_1"] = "Zumbi Corredor (M)",
        ["zombie_runner_female_1"] = "Zumbi Corredor (F)",
        ["skeleton_warrior"] = "Guerreiro Esqueleto",
        ["skeleton_archer"] = "Arqueiro Esqueleto"
    }

    return enemyNames[unitType] or unitType:gsub("_", " "):gsub("(%l)(%w*)", function(a, b) return a:upper() .. b end)
end

--- Converte o nome do mapa para nome legível
---@param mapName string Nome do mapa
---@return string displayName Nome para exibição
function PortalLoadoutSection:_getMapDisplayName(mapName)
    local mapNames = {
        ["plains"] = "Planícies Sombrias",
        ["dungeon"] = "Masmorra Perdida",
        ["forest"] = "Floresta Assombrada",
        ["cemetery"] = "Cemitério Amaldiçoado"
    }

    return mapNames[mapName] or mapName:gsub("(%l)(%w*)", function(a, b) return a:upper() .. b end)
end

--- Atualiza a animação da seção
---@param dt number Delta time
function PortalLoadoutSection:update(dt)
    if not self.isVisible then return end

    -- Animação suave de X da esquerda para a direita
    if self.animationX < self.targetX then
        self.animationX = self.animationX + (self.targetX - self.animationX) * self.animationSpeed * dt

        -- Snap para posição final quando estiver muito próximo
        if math.abs(self.animationX - self.targetX) < 1 then
            self.animationX = self.targetX
        end
    end
end

--- Desenha a seção de loadout
---@param screenW number Largura da tela
---@param screenH number Altura da tela
function PortalLoadoutSection:draw(screenW, screenH)
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
    local labelFont = fonts.main_bold or fonts.main        -- Para labels (Portal:, Mapa:, etc)
    local textFont = fonts.main_small or fonts.main

    local currentY = sectionY + self.padding
    local lineHeight = textFont:getHeight() + 5
    local titleLineHeight = titleFont:getHeight() + 10

    -- Título da seção
    love.graphics.setFont(sectionTitleFont)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.print("INFORMAÇÕES DO PORTAL", sectionX + self.padding, currentY)
    currentY = currentY + titleLineHeight

    -- Separador
    love.graphics.setColor(colors.window_border)
    love.graphics.line(sectionX + self.padding, currentY, sectionX + self.sectionWidth - self.padding, currentY)
    currentY = currentY + 15

    -- Nome do Portal
    love.graphics.setFont(labelFont)
    love.graphics.setColor(colors.text_title)
    love.graphics.print("Portal:", sectionX + self.padding, currentY)
    currentY = currentY + lineHeight

    love.graphics.setFont(textFont)
    love.graphics.setColor(colors.text_main)
    love.graphics.printf(self.portalName, sectionX + self.padding + 20, currentY,
        self.sectionWidth - self.padding * 2 - 20, "left")
    currentY = currentY + lineHeight + 10

    -- Mapa
    love.graphics.setFont(labelFont)
    love.graphics.setColor(colors.text_title)
    love.graphics.print("Mapa:", sectionX + self.padding, currentY)
    currentY = currentY + lineHeight

    love.graphics.setFont(textFont)
    love.graphics.setColor(colors.text_main)
    love.graphics.print(self:_getMapDisplayName(self.portalMap), sectionX + self.padding + 20, currentY)
    currentY = currentY + lineHeight + 15

    -- Bosses
    love.graphics.setFont(labelFont)
    love.graphics.setColor(colors.text_title)
    love.graphics.print("Bosses:", sectionX + self.padding, currentY)
    currentY = currentY + lineHeight

    if #self.bosses > 0 then
        love.graphics.setFont(textFont)
        for i, boss in ipairs(self.bosses) do
            -- Cor baseada no rank do boss
            local rankColor = colors.rankDetails[boss.rank] and colors.rankDetails[boss.rank].text or colors.text_main
            love.graphics.setColor(rankColor)

            local bossText = string.format("• %s (Rank %s)", boss.name, boss.rank)
            if boss.time > 0 then
                bossText = bossText .. string.format(" - %d:%02d", math.floor(boss.time / 60), boss.time % 60)
            end

            love.graphics.print(bossText, sectionX + self.padding + 20, currentY)
            currentY = currentY + lineHeight
        end
    else
        love.graphics.setFont(textFont)
        love.graphics.setColor(colors.text_muted)
        love.graphics.print("• Nenhum boss encontrado", sectionX + self.padding + 20, currentY)
        currentY = currentY + lineHeight
    end

    currentY = currentY + 10

    -- Inimigos
    love.graphics.setFont(labelFont)
    love.graphics.setColor(colors.text_title)
    love.graphics.print("Inimigos:", sectionX + self.padding, currentY)
    currentY = currentY + lineHeight

    if #self.enemies > 0 then
        love.graphics.setFont(textFont)
        for i, enemy in ipairs(self.enemies) do
            love.graphics.setColor(colors.text_main)
            love.graphics.print("• " .. enemy.name, sectionX + self.padding + 20, currentY)
            currentY = currentY + lineHeight
        end
    else
        love.graphics.setFont(textFont)
        love.graphics.setColor(colors.text_muted)
        love.graphics.print("• Nenhum inimigo encontrado", sectionX + self.padding + 20, currentY)
        currentY = currentY + lineHeight
    end

    -- Resetar cor
    love.graphics.setColor(colors.white)
end

--- Verifica se a animação está completa
---@return boolean isComplete Se a animação está completa
function PortalLoadoutSection:isAnimationComplete()
    return self.isVisible and math.abs(self.animationX - self.targetX) < 1
end

return PortalLoadoutSection
