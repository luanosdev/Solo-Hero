local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local StatsSection = require("src.ui.inventory.sections.stats_section")
local ArchetypeDetails = require("src.ui.components.ArchetypeDetails")

local HunterStatsColumn = {}

--- Desenha a coluna de Atributos e Arquétipos.
---@param x number Posição X da coluna.
---@param y number Posição Y inicial do conteúdo da coluna.
---@param w number Largura da coluna.
---@param h number Altura total disponível para o conteúdo da coluna.
---@param config table Tabela de configuração contendo os dados necessários:
---
---	  currentHp = number?,          -- Opcional: HP atual (Gameplay)
---	  level = number?,              -- Opcional: Nível atual (Gameplay)
---	  currentXp = number?,          -- Opcional: XP atual (Gameplay)
---	  xpToNextLevel = number?,      -- Opcional: XP para próx nível (Gameplay)
---	  finalStats = table,           -- Obrigatório: Tabela com status finais (lobby ou gameplay)
---	  archetypeIds = table,         -- Obrigatório: Lista de IDs/Info dos arquétipos
---	  archetypeManager = ArchetypeManager, -- Obrigatório: Instância do ArchetypeManager
---	  mouseX = number,              -- Obrigatório: Posição X do mouse
---	  mouseY = number               -- Obrigatório: Posição Y do mouse
---
---@return table|nil tooltipLines Retorna as linhas do tooltip de stats se houver hover, senão nil.
---@return number|nil tooltipX Retorna a posição X do tooltip de stats se houver hover, senão nil.
---@return number|nil tooltipY Retorna a posição Y do tooltip de stats se houver hover, senão nil.
function HunterStatsColumn.draw(x, y, w, h, config)
    -- Extrai dados da config para facilitar
    local currentHp = config.currentHp
    local level = config.level
    local currentXp = config.currentXp
    local xpToNextLevel = config.xpToNextLevel
    local finalStats = config.finalStats
    local archetypeIds = config.archetypeIds
    local archetypeManager = config.archetypeManager
    local mx = config.mouseX or 0
    local my = config.mouseY or 0

    -- DEBUG: Log da config recebida, focando em finalStats
    if config and config.finalStats then
        -- print("[HunterStatsColumn DEBUG] Config.finalStats recebido:") -- COMENTADO
        -- print("  > Tem _learnedLevelUpBonuses?", config.finalStats._learnedLevelUpBonuses ~= nil and not not next(config.finalStats._learnedLevelUpBonuses or {})) -- COMENTADO
        -- print("  > Tem _fixedBonus?", config.finalStats._fixedBonus ~= nil and not not next(config.finalStats._fixedBonus or {})) -- COMENTADO
        -- print("  > Tem archetypeIds na config?", config.archetypeIds ~= nil and #config.archetypeIds > 0) -- COMENTADO
    else
        print("[HunterStatsColumn DEBUG] Config OU config.finalStats é NULO.") -- MANTIDO COMO ALERTA
    end

    -- Validações básicas
    if not finalStats or not archetypeIds or not archetypeManager then
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: Dados essenciais ausentes na configuração de HunterStatsColumn!", x, y + h / 2, w,
            "center")
        love.graphics.setColor(colors.white)
        return
    end

    -- >>> SEÇÃO OPCIONAL: Status Gerais (HP, Nível, XP) <<<
    local generalSectionH = 0
    -- Só desenha se os dados de gameplay foram passados
    if currentHp ~= nil and level ~= nil and currentXp ~= nil and xpToNextLevel ~= nil then
        -- Tenta obter maxHp dos stats finais, senão usa um fallback (pode ser 0 se stats não tiver health)
        local maxHp = finalStats.health or 0

        local lineH = fonts.main:getHeight()
        local padding = 5
        generalSectionH = (lineH * 2) + (padding * 3) -- Altura para 2 linhas + paddings

        -- Linha 1: HP e Nível
        love.graphics.setFont(fonts.hud) -- Usa fonts.hud (existente e bold)
        love.graphics.setColor(colors.text_default)
        -- Arredonda HP para exibição
        local hpText = string.format("HP: %d / %d", math.floor(currentHp), math.floor(maxHp))
        local levelText = string.format("Nível: %d", level)
        love.graphics.print(hpText, x + padding, y + padding)
        love.graphics.printf(levelText, x + padding, y + padding, w - padding * 2, "right")

        -- Linha 2: XP
        love.graphics.setFont(fonts.main)
        -- Arredonda XP para exibição
        local xpText = string.format("XP: %d / %d", math.floor(currentXp), math.floor(xpToNextLevel))
        love.graphics.printf(xpText, x + padding, y + padding + lineH + padding, w - padding * 2, "left")

        -- Linha divisória (opcional)
        love.graphics.setColor(colors.window_border) -- Usa colors.window_border (existente)
        love.graphics.rectangle("fill", x, y + generalSectionH - 1, w, 1)
        love.graphics.setColor(colors.white)         -- Reset color
    else
        -- Se não passou dados de gameplay, a seção não ocupa espaço
        generalSectionH = 0
    end
    -- >>> FIM SEÇÃO OPCIONAL <<<

    -- Ajusta Y e H para as seções seguintes, considerando se a seção geral foi desenhada
    local remainingH = h - generalSectionH
    local statsY = y + generalSectionH
    local statsSectionH = math.floor(remainingH * 0.50) -- 50% do espaço *restante*
    local archetypesGapY = 5
    local archetypesTitleH = fonts.hud:getHeight() * 1.5
    local archetypesTitleY = statsY + statsSectionH + archetypesGapY
    local archetypesListStartY = archetypesTitleY + archetypesTitleH

    -- Ordena arquétipos (lógica movida para cá para garantir execução)
    local rankOrder = { S = 1, A = 2, B = 3, C = 4, D = 5, E = 6 }
    local sortedArchetypes = {}
    if archetypeIds then -- Garante que archetypeIds não seja nil
        for _, archIdInfo in ipairs(archetypeIds) do
            local finalArchId = type(archIdInfo) == 'table' and archIdInfo.id or archIdInfo
            if type(finalArchId) == 'string' then
                local data = archetypeManager:getArchetypeData(finalArchId)
                if data then
                    data.rank = (type(archIdInfo) == 'table' and archIdInfo.rank) or data.rank or 'E'
                    table.insert(sortedArchetypes, data)
                end
            end
        end
        table.sort(sortedArchetypes, function(a, b)
            local orderA = rankOrder[a.rank or 'E'] or 99
            local orderB = rankOrder[b.rank or 'E'] or 99
            if orderA == orderB then
                return (a.name or "") < (b.name or "")
            end
            return orderA < orderB
        end)
    end

    local statsTooltipLines, statsTooltipX, statsTooltipY = nil, nil,
        nil -- Inicializa variáveis para os dados do tooltip

    -- 1. Desenha Seção de Stats (usando finalStats da config)
    if finalStats and next(finalStats) then
        -- Passa sortedArchetypes e archetypeManager para StatsSection poder calcular tooltips
        -- print("[HunterStatsColumn DEBUG] Chamando StatsSection.drawBaseStats. finalStats tem _learnedLevelUpBonuses? ", finalStats._learnedLevelUpBonuses ~= nil and not not next(finalStats._learnedLevelUpBonuses or {})) -- COMENTADO
        statsTooltipLines, statsTooltipX, statsTooltipY = StatsSection.drawBaseStats(x, statsY, w, statsSectionH,
            finalStats, sortedArchetypes, archetypeManager, mx, my)
    else
        -- Mensagem de erro se faltar dados de stats
        love.graphics.setColor(colors.red)
        local errorMsg = "Dados insuficientes para Stats"
        love.graphics.printf(errorMsg, x, statsY + statsSectionH / 2, w, "center")
    end

    -- 2. Desenha Seção de Arquétipos ABAIXO dos Stats
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("ARQUÉTIPOS", x, archetypesTitleY, w, "left")
    local padding = 5

    if #sortedArchetypes > 0 then
        local itemsPerRow = 3                                                         -- <<< RESTAURADO PARA 3 COLUNAS
        local hGap = 5
        local vGap = 5                                                                -- Aumentado um pouco o vGap para melhor espaçamento
        local availableWidth = w - padding * 2
        local itemWidth = (availableWidth - (hGap * (itemsPerRow - 1))) / itemsPerRow -- <<< CALCULA LARGURA POR ITEM

        local currentX = x + padding
        local startListY = archetypesListStartY
        local currentY = startListY

        local archetypeDetailHeight = 0

        for i, archetypeData in ipairs(sortedArchetypes) do
            -- Cria uma instância de ArchetypeDetails SEM os modificadores
            -- Log removido para limpeza, já que a exibição básica está funcionando
            -- print(string.format("[HunterStatsColumn DEBUG] Preparando ArchetypeDetails para: ID=%s, Nome=%s, Rank=%s, ShowMod=%s",
            --     tostring(archetypeData.id), tostring(archetypeData.name), tostring(archetypeData.rank), "false")) -- Log antes de criar

            local archetypeComp = ArchetypeDetails:new({
                archetypeData = archetypeData,
                showModifiers = false,
                x = currentX,
                y = currentY,
                width = itemWidth,                                     -- <<< USA LARGURA CALCULADA
                padding = { left = 2, right = 2, top = 1, bottom = 1 } -- Padding interno menor para o componente
            })
            archetypeComp:_updateLayout()

            archetypeComp:draw()

            archetypeDetailHeight = archetypeComp.rect.h -- Atualiza a altura para o cheque de estouro

            -- Atualiza currentX e currentY para o próximo item
            if i % itemsPerRow == 0 then                           -- Se for o último item da linha
                currentX = x + padding                             -- Reseta X para o início da próxima linha
                currentY = currentY + archetypeDetailHeight + vGap -- Move Y para a próxima linha
            else
                currentX = currentX + itemWidth + hGap             -- Move X para a próxima coluna
            end

            if currentY + archetypeDetailHeight > y + h then -- Verifica se vai estourar a altura da coluna
                -- Adiciona um indicador de "mais arquétipos" se estourar
                love.graphics.setFont(fonts.main_small or fonts.main)
                love.graphics.setColor(colors.text_muted)
                love.graphics.printf("...", currentX, currentY, itemWidth, "center")
                love.graphics.setFont(fonts.main) -- Restaura fonte
                break
            end
        end
    else
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.text_muted)
        love.graphics.printf("Nenhum arquétipo.", x + padding, archetypesListStartY + 5, w - padding * 2, "left")
    end

    love.graphics.setColor(colors.white)                   -- Reset final

    return statsTooltipLines, statsTooltipX, statsTooltipY -- Retorna os dados do tooltip
end

return HunterStatsColumn
