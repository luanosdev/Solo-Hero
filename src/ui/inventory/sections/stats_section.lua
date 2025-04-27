-- src/ui/inventory/sections/stats_section.lua
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")    -- Para formatNumber
local Constants = require("src.config.constants") -- <<< IMPORTANTE: Precisamos dos stats base

-- Helper para formatar Chance de Ataque Múltiplo (Movido de inventory_screen)
local function formatMultiAttack(value)
    value = value or 0
    local guaranteedExtra = math.floor(value)
    local chanceForNext = math.floor((value - guaranteedExtra) * 100 + 0.5) -- Arredonda para % inteira

    if guaranteedExtra > 0 and chanceForNext > 0 then
        return string.format("%d + %d%%", guaranteedExtra, chanceForNext)
    elseif guaranteedExtra > 0 then
        return tostring(guaranteedExtra)
    elseif chanceForNext > 0 then
        return string.format("%d%%", chanceForNext)
    else
        return "0%" -- Ou "0" se preferir
    end
end

-- Helper para formatar os modificadores de um arquétipo para exibição
local function formatArchetypeModifier(key, value)
    local statName, modifierType = key:match("^(.+)_([^_]+)$")
    if not statName then return key .. " = " .. tostring(value) end -- Fallback

    local label = "?"
    local formattedValue = "?"

    -- Mapeia a chave do modificador para um nome de stat legível
    local labelMap = {
        health = "Vida",
        defense = "Defesa",
        moveSpeed = "Velocidade",
        critChance = "Chance Crítico",
        critDamage = "Dano Crítico",
        healthPerTick = "Regen. Vida/s",
        healthRegenDelay = "Delay Regen.",
        multiAttackChance = "Atq. Múltiplo",
        attackSpeed = "Vel. Ataque",
        expBonus = "Bônus Exp",
        cooldownReduction = "Red. Recarga",
        range = "Alcance",
        attackArea = "Área Ataque",
        pickupRadius = "Raio Coleta",
        healingBonus = "Bônus Cura",
        runeSlots = "Slots Runa"
        -- Adicionar outros stats se necessário
    }
    label = labelMap[statName] or statName -- Usa o nome mapeado ou a chave crua

    -- Formata o valor baseado no tipo de modificador
    if modifierType == "add" then
        -- Adiciona sinal e formata número, remove .0 se inteiro
        formattedValue = string.format("%+.1f", value):gsub("%.0$", "")
        -- Adiciona % para chances
        if string.find(statName, "Chance") then formattedValue = formattedValue .. "%" end
    elseif modifierType == "mult" then
        -- Converte multiplicador para percentual (ex: 1.1 -> +10%, 0.9 -> -10%)
        local percentage = (value - 1) * 100
        formattedValue = string.format("%+.0f%%", percentage)
    else
        formattedValue = tostring(value) -- Fallback
    end

    return label .. ": " .. formattedValue
end

local StatsSection = {}

-- Desenha a seção de estatísticas (esquerda) (Movido de inventory_screen)
-- Recebe playerManager como argumento
function StatsSection.draw(x, y, w, h, playerManager)
    -- <<< VERIFICAÇÃO ADICIONADA PARA playerManager NULO (MOCK) >>>
    if not playerManager then
        -- Desenha um placeholder ou mensagem se o playerManager for nulo
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.text_label)
        love.graphics.printf("Dados do Herói (Indisponível)", x, y + h / 2, w, "center")
        return -- Sai da função se não há dados para mostrar
    end
    -- <<< FIM VERIFICAÇÃO >>>

    local state = playerManager.state -- Acessa o estado do jogador

    -- Definições de espaçamento padrão (reduzido)
    local lineHeight = fonts.main:getHeight() * 1.1            -- Reduzido para ser mais compacto
    local sectionTitleLineHeight = fonts.hud:getHeight() * 1.5 -- Espaço após títulos de seção
    local sectionSpacing = lineHeight *
        1.5                                                    -- Espaço entre seções principais (baseado no novo lineHeight)

    -- <<< REMOÇÃO DO TÍTULO INTERNO >>>
    -- Título da Seção (Maior) (REMOVIDO)
    -- love.graphics.setFont(fonts.title) -- Fonte Maior para o título principal
    -- love.graphics.setColor(colors.text_highlight)
    -- love.graphics.printf("HERÓI", x, y, w, "center")
    -- local titleH = fonts.title:getHeight() * 1.2 -- Espaçamento após título principal
    -- local currentY = y + titleH
    -- <<< FIM REMOÇÃO >>>

    -- <<< AJUSTE: currentY começa diretamente em 'y' (a posição inicial passada) >>>
    local currentY = y

    -- Subtítulo: DADOS EM JOGO
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("DADOS EM JOGO", x, currentY, w, "left")
    currentY = currentY + sectionTitleLineHeight -- Espaçamento padrão após título de seção

    -- Mini-seção: Dados principais
    love.graphics.setFont(fonts.main)
    -- Vida
    love.graphics.setColor(colors.text_label)
    love.graphics.print("Vida", x, currentY)
    love.graphics.setColor(colors.hp_fill)
    -- USA HELPER MOVIDO para elements
    local hpText = elements.formatNumber(state.currentHealth) .. "/" .. elements.formatNumber(state:getTotalHealth())
    love.graphics.printf(hpText, x, currentY, w, "right")
    currentY = currentY + lineHeight -- Usar lineHeight reduzido

    -- Nível (ADICIONADO)
    love.graphics.setColor(colors.text_label)
    love.graphics.print("Nível", x, currentY)
    love.graphics.setColor(colors.text_value) -- Ou outra cor se preferir
    love.graphics.printf(tostring(state.level), x, currentY, w, "right")
    currentY = currentY + lineHeight          -- Avança Y para a próxima linha

    -- Experiência
    love.graphics.setColor(colors.text_label)
    love.graphics.print("Experiência", x, currentY)
    love.graphics.setColor(colors.xp_fill)
    local xpNeeded = math.max(0, state.experienceToNextLevel - state.experience)
    -- USA HELPER MOVIDO para elements
    local xpText = elements.formatNumber(state.experience) .. "/" .. elements.formatNumber(state.experienceToNextLevel)
    love.graphics.printf(xpText, x, currentY, w, "right")
    currentY = currentY + lineHeight -- Usar lineHeight reduzido
    -- XP para próximo nível
    love.graphics.setFont(fonts.main_small)
    love.graphics.setColor(colors.text_label)
    -- USA HELPER MOVIDO para elements
    love.graphics.printf("(" .. elements.formatNumber(xpNeeded) .. " para próximo nivel)", x,
        currentY - fonts.main:getHeight() * 0.1, w, "right")
    love.graphics.setFont(fonts.main)
    currentY = currentY + lineHeight * 0.8 -- Espaço menor ainda OK

    -- Abates
    love.graphics.setColor(colors.text_label)
    love.graphics.print("Abates (Chefes/MVP/Inimigos)", x, currentY)
    love.graphics.setColor(colors.text_value)
    -- USA HELPER MOVIDO para elements
    local killsText = "0/0/" .. elements.formatNumber(state.kills)
    love.graphics.printf(killsText, x, currentY, w, "right")
    currentY = currentY + sectionSpacing -- Espaço entre seções principais

    -- Seção: Memória (Placeholder)
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.print("MEMÓRIA", x, currentY)
    currentY = currentY + sectionTitleLineHeight -- Espaçamento padrão após título de seção

    local memoryStats = {
        { label = "Força",        value = 15 },
        { label = "Destreza",     value = 12 },
        { label = "Inteligência", value = 18 },
        { label = "Vitalidade",   value = 14 }
    }

    love.graphics.setFont(fonts.main)
    for _, stat in ipairs(memoryStats) do
        love.graphics.setColor(colors.text_label)
        love.graphics.print(stat.label, x, currentY)
        love.graphics.setColor(colors.text_value)
        local valueStr = tostring(stat.value)
        love.graphics.printf(valueStr, x, currentY, w, "right")
        currentY = currentY + lineHeight                -- Usar lineHeight reduzido
        if currentY > y + h - lineHeight then break end -- Segurança
    end
    currentY = currentY + sectionSpacing                -- Espaço entre seções principais

    -- Seção de Atributos (baseados no state)
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.print("ATRIBUTOS", x, currentY)
    currentY = currentY + sectionTitleLineHeight -- Espaçamento padrão após título de seção

    -- Estrutura para buscar e exibir atributos
    local attributesToShow = {
        { label = "Vida Máxima",       baseKey = "baseHealth",             percKey = "health",             fixedKey = "health",             totalFunc = state.getTotalHealth,             format = "%d" },
        { label = "Defesa",            baseKey = "baseDefense",            percKey = "defense",            fixedKey = "defense",            totalFunc = state.getTotalDefense,            format = "%d" },
        { label = "Velocidade Mov.",   baseKey = "baseSpeed",              percKey = "speed",              fixedKey = "speed",              totalFunc = state.getTotalSpeed,              format = "%.1f" },
        { label = "Chance Crítico",    baseKey = "baseCriticalChance",     percKey = "criticalChance",     fixedKey = "criticalChance",     totalFunc = state.getTotalCriticalChance,     format = "%.1f%%" },
        { label = "Mult. Crítico",     baseKey = "baseCriticalMultiplier", percKey = "criticalMultiplier", fixedKey = "criticalMultiplier", totalFunc = state.getTotalCriticalMultiplier, format = "%.1fx" },
        { label = "Regen. Vida",       baseKey = "baseHealthRegen",        percKey = "healthRegen",        fixedKey = "healthRegen",        totalFunc = state.getTotalHealthRegen,        format = "%.1f/Vida p/s" },      -- Formato original, será ajustado no display
        { label = "Chance Atq. Múlt.", baseKey = "baseMultiAttackChance",  percKey = "multiAttackChance",  fixedKey = "multiAttackChance",  totalFunc = state.getTotalMultiAttackChance,  formatter = formatMultiAttack }, -- Usa formatter especial
    }
    local baseColor = colors.text_value
    local percBonusColor = colors.text_gold
    local fixedBonusColor = colors.heal
    local totalColor = colors.text_highlight
    local operatorColor = colors.text_label

    love.graphics.setFont(fonts.main)

    -- Loop para desenhar ATRIBUTOS com detalhamento
    for _, attr in ipairs(attributesToShow) do
        local baseValue = state[attr.baseKey] or 0
        local percValue = state.levelBonus[attr.percKey] or 0
        local fixedValue = attr.fixedKey and state.fixedBonus[attr.fixedKey] or 0
        local totalValue = attr.totalFunc(state)

        -- FORMATACAO CONDICIONAL
        local totalStr = "?"
        local showDetails = true -- Default to showing details

        if attr.label == "Chance Crítico" then
            local displayValue = totalValue * 100
            totalStr = string.format(attr.format, displayValue)
        elseif attr.label == "Regen. Vida" then
            if totalValue > 0.001 then -- Check for non-zero regen
                local timePerHP = 1 / totalValue
                totalStr = string.format("%.1fs / HP", timePerHP)
            else
                totalStr = "N/A s / HP"
            end
            showDetails = false -- Don't show details for Regen Vida in s/HP format
        else
            -- Default formatting for other attributes
            totalStr = attr.formatter and attr.formatter(totalValue) or string.format(attr.format, totalValue)
            if attr.label == "Velocidade Mov." then totalStr = totalStr .. " m/s" end
        end

        -- Print Label
        love.graphics.setColor(colors.text_label)
        love.graphics.print(attr.label, x, currentY)

        if showDetails then
            -- Formata as strings das partes para DETALHES
            local baseStr = string.format("%.1f", baseValue):gsub("%.0$", "")
            if attr.label == "Chance Crítico" then
                baseStr = string.format("%.1f", baseValue * 100):gsub("%.0$", "")
            end
            local percStr = string.format("+%.0f%%", percValue)
            local fixedStr = attr.fixedKey and fixedValue ~= 0 and string.format("%+.1f", fixedValue):gsub("%.0$", "") or
                nil
            if attr.label == "Chance Crítico" and fixedStr then
                fixedStr = string.format("%+.1f%%", fixedValue * 100):gsub("%.0%%", "%%")
            end

            -- Calcula larguras para alinhamento à direita (DOS DETALHES)
            local totalWidth = fonts.main:getWidth(totalStr)
            local baseWidth = fonts.main:getWidth(baseStr)
            local percWidth = fonts.main:getWidth(percStr)
            local fixedWidth = fixedStr and fonts.main:getWidth(fixedStr) or 0
            local bracketWidth = fonts.main:getWidth(" () ")
            local plusWidth = fonts.main:getWidth(" + ")
            local currentDrawX = x + w

            -- Desenha Total (à direita)
            currentDrawX = currentDrawX - totalWidth
            love.graphics.setColor(totalColor)
            love.graphics.print(totalStr, currentDrawX, currentY)

            -- Desenha Detalhes (entre parênteses, à esquerda do total)
            currentDrawX = currentDrawX - fonts.main:getWidth(" )")
            love.graphics.setColor(operatorColor)
            love.graphics.print(")", currentDrawX, currentY)

            -- Desenha Fixo (se existir)
            if fixedStr then
                currentDrawX = currentDrawX - fixedWidth
                love.graphics.setColor(fixedBonusColor)
                love.graphics.print(fixedStr, currentDrawX, currentY)

                currentDrawX = currentDrawX - plusWidth
                love.graphics.setColor(operatorColor)
                love.graphics.print(" + ", currentDrawX, currentY)
            end

            -- Desenha Percentual (se existir)
            if percValue ~= 0 then
                currentDrawX = currentDrawX - percWidth
                love.graphics.setColor(percBonusColor)
                love.graphics.print(percStr, currentDrawX, currentY)

                if fixedStr then
                    currentDrawX = currentDrawX - plusWidth
                    love.graphics.setColor(operatorColor)
                    love.graphics.print(" + ", currentDrawX, currentY)
                end
            end

            -- Desenha Base
            currentDrawX = currentDrawX - baseWidth
            love.graphics.setColor(baseColor)
            love.graphics.print(baseStr, currentDrawX, currentY)

            -- Desenha Parêntese de Abertura
            currentDrawX = currentDrawX - fonts.main:getWidth(" (")
            love.graphics.setColor(operatorColor)
            love.graphics.print(" (", currentDrawX, currentY)
        else
            -- Se não mostra detalhes, apenas desenha o valor total alinhado à direita
            local totalWidth = fonts.main:getWidth(totalStr)
            local currentDrawX = x + w - totalWidth
            love.graphics.setColor(totalColor)
            love.graphics.print(totalStr, currentDrawX, currentY)
        end

        currentY = currentY + lineHeight
        if currentY > y + h - lineHeight then break end
    end
    currentY = currentY + sectionSpacing -- Espaço entre seções principais

    -- Seção da Arma Equipada
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.print("ARMA EQUIPADA", x, currentY)
    currentY = currentY + sectionTitleLineHeight -- Espaçamento padrão após título de seção

    local equippedWeapon = playerManager.equippedWeapon
    love.graphics.setFont(fonts.main)

    if equippedWeapon then
        local baseColor = colors.text_value
        local percBonusColor = colors.text_gold
        local totalColor = colors.text_highlight
        local operatorColor = colors.text_label

        local weaponStatsToDraw = {}
        table.insert(weaponStatsToDraw, { label = "Nome", value = equippedWeapon.name or "Desconhecido", simple = true })
        local baseDamageValue = equippedWeapon.damage or 0
        local baseDamageStrToDisplay = "?"
        local avgBaseDamageForTotalCalc = 0
        if type(baseDamageValue) == "table" and baseDamageValue.min and baseDamageValue.max then
            baseDamageStrToDisplay = string.format("%d-%d", baseDamageValue.min, baseDamageValue.max)
            avgBaseDamageForTotalCalc = (baseDamageValue.min + baseDamageValue.max) / 2
        elseif type(baseDamageValue) == "number" then
            baseDamageStrToDisplay = string.format("%d", baseDamageValue)
            avgBaseDamageForTotalCalc = baseDamageValue
        end
        table.insert(weaponStatsToDraw,
            {
                label = "Dano Total",
                baseValueStr = baseDamageStrToDisplay,
                percBonus = state.levelBonus.damage or 0,
                totalValue =
                    state:getTotalDamage(avgBaseDamageForTotalCalc),
                format = "%d",
                detail = true
            })

        if equippedWeapon.attackInstance and equippedWeapon.attackInstance.cooldown and equippedWeapon.attackInstance.cooldown > 0 then
            local weaponCooldown = equippedWeapon.attackInstance.cooldown
            local percBonus = state.levelBonus.attackSpeed or 0
            local effectiveCooldown = weaponCooldown / (1 + percBonus / 100)
            local attacksPerSecond = (effectiveCooldown > 0) and (1 / effectiveCooldown) or 0
            table.insert(weaponStatsToDraw,
                { label = "Atq./Seg", value = attacksPerSecond, format = "%.2f", simple = true })
        end
        if equippedWeapon.range then
            local baseRange = equippedWeapon.range
            local percBonusRange = state.levelBonus.range or 0
            local totalRange = baseRange * (1 + percBonusRange / 100)
            table.insert(weaponStatsToDraw,
                {
                    label = "Alcance",
                    baseValue = baseRange,
                    percBonus = percBonusRange,
                    totalValue = totalRange,
                    format =
                    "%.1f",
                    detail = true
                })
        end
        if equippedWeapon.attackInstance and equippedWeapon.attackInstance.damageType then
            table.insert(
                weaponStatsToDraw,
                { label = "Tipo Dano", value = equippedWeapon.attackInstance.damageType, simple = true })
        end
        if equippedWeapon.attackInstance and equippedWeapon.attackInstance.cooldown then
            table.insert(weaponStatsToDraw,
                { label = "Cooldown Base", value = equippedWeapon.attackInstance.cooldown, format = "%.2fs", simple = true })
        end
        if equippedWeapon.angle then
            local baseAngleRad = equippedWeapon.angle
            local areaBonusPerc = state.levelBonus.area or 0
            local effectiveAngleRad = baseAngleRad * (1 + areaBonusPerc / 100)
            local baseAngleDeg = math.deg(baseAngleRad)
            local effectiveAngleDeg = math.deg(effectiveAngleRad)
            table.insert(weaponStatsToDraw, {
                label = "Ângulo Efetivo",
                baseValue = baseAngleDeg,
                percBonus = areaBonusPerc,
                totalValue = effectiveAngleDeg,
                format = "%.0f°",
                detail = true
            })
        end

        for _, stat in ipairs(weaponStatsToDraw) do
            love.graphics.setColor(colors.text_label)
            love.graphics.print(stat.label, x, currentY)

            if stat.simple then
                love.graphics.setColor(colors.text_value)
                local valueStr = "?"
                xpcall(
                    function() valueStr = stat.format and string.format(stat.format, stat.value) or tostring(stat.value) end,
                    function(err) print("[Error][StatsSection] " .. err) end)
                love.graphics.printf(valueStr, x, currentY, w, "right")
            elseif stat.detail then
                local totalStr, baseStr, percStr = "?", "?", "?"

                -- Format Total
                xpcall(function() totalStr = string.format(stat.format, stat.totalValue) end,
                    function(err) print("[Error][StatsSection] " .. err) end)

                -- Format Base
                xpcall(function()
                    if stat.baseValueStr then
                        baseStr = stat.baseValueStr
                    elseif type(stat.baseValue) == "number" then
                        baseStr = string.format("%.1f", stat.baseValue):gsub("%.0$", "")
                    end
                end, function(err) print("[Error][StatsSection] " .. err) end)

                -- Format Percentage
                xpcall(function()
                    if type(stat.percBonus) == "number" then
                        percStr = string.format("+%.0f%%", stat.percBonus)
                    end
                end, function(err) print("[Error][StatsSection] " .. err) end)

                -- Calcula larguras
                local totalWidth = fonts.main:getWidth(totalStr)
                local baseWidth = fonts.main:getWidth(baseStr)
                local percWidth = fonts.main:getWidth(percStr)
                local bracketWidth = fonts.main:getWidth(" () ")
                local plusWidth = fonts.main:getWidth(" + ")
                local currentDrawX = x + w

                -- Desenha Total
                currentDrawX = currentDrawX - totalWidth
                love.graphics.setColor(totalColor)
                love.graphics.print(totalStr, currentDrawX, currentY)
                currentDrawX = currentDrawX - fonts.main:getWidth(" )")
                love.graphics.setColor(operatorColor)
                love.graphics.print(")", currentDrawX, currentY)
                if stat.percBonus ~= 0 then
                    currentDrawX = currentDrawX - percWidth
                    love.graphics.setColor(percBonusColor)
                    love.graphics.print(percStr, currentDrawX, currentY)
                    currentDrawX = currentDrawX - plusWidth
                    love.graphics.setColor(operatorColor)
                    love.graphics.print(" + ", currentDrawX, currentY)
                end
                currentDrawX = currentDrawX - baseWidth
                love.graphics.setColor(baseColor)
                love.graphics.print(baseStr, currentDrawX, currentY)
                currentDrawX = currentDrawX - fonts.main:getWidth(" (")
                love.graphics.setColor(operatorColor)
                love.graphics.print(" (", currentDrawX, currentY)
            end
            currentY = currentY + lineHeight
            if currentY > y + h - lineHeight then break end
        end
    else
        love.graphics.setColor(colors.text_label)
        love.graphics.printf("Nenhuma arma equipada", x, currentY, w, "left")
        currentY = currentY + lineHeight
    end

    love.graphics.setFont(fonts.main)
end

--- NOVA FUNÇÃO: Desenha apenas os atributos base para o Lobby.
---@param x number Posição X da área.
---@param y number Posição Y da área.
---@param w number Largura da área.
---@param h number Altura da área.
---@param finalStats table Tabela contendo os atributos FINAIS calculados.
---@param archetypeIds table Lista de IDs dos arquétipos do caçador.
---@param archetypeManager ArchetypeManager Instância do ArchetypeManager.
function StatsSection.drawBaseStats(x, y, w, h, finalStats, archetypeIds, archetypeManager) -- <<< NOVOS PARÂMETROS
    if not finalStats or not next(finalStats) then
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.text_label)
        love.graphics.printf("Herói sem stats calculados?", x, y + h / 2, w, "center")
        return
    end
    -- <<< REMOVIDA VERIFICAÇÃO DE archetypeIds/archetypeManager aqui, feita na chamada >>>

    local baseStats = Constants.HUNTER_DEFAULT_STATS
    if not baseStats then
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.red)
        love.graphics.printf("ERRO: HUNTER_DEFAULT_STATS não encontrado!", x, y + h / 2, w, "center")
        return
    end

    local lineHeight = fonts.main:getHeight() * 1.2
    local smallLineHeight = fonts.main_small:getHeight() * 1.1
    local hudLineHeight = fonts.hud:getHeight() * 1.5
    local currentY = y
    local sectionStartY = y   -- Guarda o Y inicial da seção para checagem de altura
    local availableHeight = h -- Altura total disponível para a seção

    -- Título da Seção de Atributos
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("ATRIBUTOS DO CAÇADOR", x, currentY, w, "left")
    currentY = currentY + hudLineHeight

    -- Lista de atributos para exibir
    local attributesToShow = {
        { label = "Vida",            key = "health",            format = "%d" },
        { label = "Defesa",          key = "defense",           format = "%d" },
        { label = "Velocidade",      key = "moveSpeed",         format = "%.1f",   suffix = " m/s" },
        { label = "Chance Crítico",  key = "critChance",        format = "%.1f%%", multiplier = 100 },
        { label = "Dano Crítico",    key = "critDamage",        format = "%.1fx",  multiplier = 100,   baseMultiplier = 100 },
        { label = "Regen. Vida/s",   key = "healthPerTick",     format = "%.1f/s" },
        { label = "Delay Regen.",    key = "healthRegenDelay",  format = "%.1fs" },
        { label = "Atq. Múltiplo",   key = "multiAttackChance", format = "%.1f%%", multiplier = 100 },
        { label = "Vel. Ataque",     key = "attackSpeed",       format = "%.2f/s" },
        { label = "Bônus Exp",       key = "expBonus",          format = "%.0f%%", multiplier = 100,   baseMultiplier = 100 },
        { label = "Redução Recarga", key = "cooldownReduction", format = "%.0f%%", multiplier = -100,  baseValue = 1,        displayMultiplier = 100 },
        { label = "Alcance",         key = "range",             format = "x%.1f",  baseMultiplier = 1, displayMultiplier = 1 },
        { label = "Área Ataque",     key = "attackArea",        format = "x%.1f",  baseMultiplier = 1, displayMultiplier = 1 },
        { label = "Raio Coleta",     key = "pickupRadius",      format = "%d" },
        { label = "Bônus Cura",      key = "healingBonus",      format = "%.0f%%", multiplier = 100,   baseMultiplier = 100 },
        { label = "Slots Runa",      key = "runeSlots",         format = "%d" },
    }

    love.graphics.setFont(fonts.main)
    local baseColor = colors.text_value
    local bonusColor = colors.text_gold
    local totalColor = colors.text_highlight
    local operatorColor = colors.text_label

    -- Loop para desenhar Atributos
    for _, attr in ipairs(attributesToShow) do
        local finalValue = finalStats[attr.key]
        local defaultValue = baseStats[attr.key]

        if finalValue ~= nil and defaultValue ~= nil then
            love.graphics.setColor(colors.text_label)
            love.graphics.print(attr.label, x, currentY)

            local displayMultiplier = attr.multiplier or 1
            local baseDisplayMultiplier = attr.baseMultiplier or displayMultiplier
            local displaySuffix = attr.suffix or ""
            local finalDisplayValue = finalValue * displayMultiplier
            local defaultDisplayValue = defaultValue * baseDisplayMultiplier

            if attr.key == "cooldownReduction" then
                finalDisplayValue = (1 - finalValue) * (attr.displayMultiplier or 100)
                defaultDisplayValue = (1 - (attr.baseValue or defaultValue)) * (attr.displayMultiplier or 100)
                attr.format = "%.0f%%"
            elseif attr.key == "critDamage" then
                finalDisplayValue = finalValue * 100
                defaultDisplayValue = defaultValue * 100
                attr.format = "%.0fx"
            elseif attr.key == "range" or attr.key == "attackArea" then
                finalDisplayValue = finalValue
                defaultDisplayValue = defaultValue
                attr.format = "x%.1f"
            end

            local bonusDisplayValue = finalDisplayValue - defaultDisplayValue
            local finalStr = string.format(attr.format, finalDisplayValue) .. displaySuffix
            local defaultStr = string.format(attr.format, defaultDisplayValue)
            local bonusStr = ""
            if math.abs(bonusDisplayValue) > 0.01 then
                bonusStr = string.format("%+.1f", bonusDisplayValue):gsub("%.0$", "")
                if string.find(attr.format, "%%") then bonusStr = bonusStr .. "%" end
                bonusStr = bonusStr:gsub("%%+%%", "%%")
                if attr.key == "critDamage" then
                    bonusStr = string.format("%+.0f", bonusDisplayValue) .. "x"
                elseif attr.key == "range" or attr.key == "attackArea" then
                    bonusStr = string.format("%+.1f", bonusDisplayValue)
                end
            end

            local totalWidth = fonts.main:getWidth(finalStr)
            local defaultWidth = fonts.main:getWidth(defaultStr)
            local bonusWidth = fonts.main:getWidth(bonusStr)
            local currentDrawX = x + w

            currentDrawX = currentDrawX - totalWidth
            love.graphics.setColor(totalColor)
            love.graphics.print(finalStr, currentDrawX, currentY)

            if bonusStr ~= "" then
                currentDrawX = currentDrawX - fonts.main:getWidth(" = ")
                love.graphics.setColor(operatorColor)
                love.graphics.print(" = ", currentDrawX, currentY)
                currentDrawX = currentDrawX - fonts.main:getWidth(" )")
                love.graphics.setColor(operatorColor)
                love.graphics.print(")", currentDrawX, currentY)
                currentDrawX = currentDrawX - bonusWidth
                love.graphics.setColor(bonusColor)
                love.graphics.print(bonusStr, currentDrawX, currentY)
                currentDrawX = currentDrawX - fonts.main:getWidth(" (")
                love.graphics.setColor(operatorColor)
                love.graphics.print(" (", currentDrawX, currentY)
                currentDrawX = currentDrawX - defaultWidth
                love.graphics.setColor(baseColor)
                love.graphics.print(defaultStr, currentDrawX, currentY)
            else
                currentDrawX = currentDrawX - fonts.main:getWidth(" = ")
                love.graphics.setColor(operatorColor)
                love.graphics.print(" = ", currentDrawX, currentY)
                currentDrawX = currentDrawX - defaultWidth
                love.graphics.setColor(baseColor)
                love.graphics.print(defaultStr, currentDrawX, currentY)
            end
            currentY = currentY + lineHeight
        end
        if currentY > sectionStartY + availableHeight - lineHeight then break end
    end

    -- <<< INÍCIO: NOVA SUBSEÇÃO DE ARQUÉTIPOS >>>
    currentY = currentY + lineHeight * 0.5 -- Pequeno espaço antes da nova seção

    -- Verifica se ainda há espaço vertical suficiente
    if currentY < sectionStartY + availableHeight - hudLineHeight then
        love.graphics.setFont(fonts.hud)
        love.graphics.setColor(colors.text_highlight)
        love.graphics.printf("ARQUÉTIPOS", x, currentY, w, "left")
        currentY = currentY + hudLineHeight

        if archetypeIds and #archetypeIds > 0 and archetypeManager then
            for _, archetypeId in ipairs(archetypeIds) do
                -- Verifica espaço antes de desenhar o arquétipo
                if currentY > sectionStartY + availableHeight - lineHeight then break end

                local archetypeData = archetypeManager:getArchetypeData(archetypeId)
                if archetypeData then
                    local rankColor = colors.rank[archetypeData.rank or 'E'] or colors.white
                    local rankText = string.format(" [%s]", archetypeData.rank or '?')
                    local nameText = archetypeData.name or "Desconhecido"
                    local nameWidth = fonts.main:getWidth(nameText)
                    local rankWidth = fonts.main_small:getWidth(rankText)

                    -- Desenha Nome
                    love.graphics.setFont(fonts.main)
                    love.graphics.setColor(colors.text_value)
                    love.graphics.print(nameText, x, currentY)

                    -- Desenha Rank (ao lado do nome, com cor)
                    love.graphics.setFont(fonts.main_small)
                    love.graphics.setColor(rankColor)
                    love.graphics.print(rankText, x + nameWidth + 2, currentY + 1) -- Pequeno offset

                    currentY = currentY + lineHeight * 0.8                         -- Espaço menor após nome+rank

                    -- Desenha Modificadores
                    if archetypeData.modifiers then
                        love.graphics.setFont(fonts.main_small)
                        love.graphics.setColor(colors.text_label) -- Cor mais suave para modificadores
                        local modifierIndent = x + 10             -- Indenta os modificadores
                        for modKey, modValue in pairs(archetypeData.modifiers) do
                            -- Verifica espaço antes de desenhar modificador
                            if currentY > sectionStartY + availableHeight - smallLineHeight then break end

                            local modifierStr = formatArchetypeModifier(modKey, modValue)
                            love.graphics.print(modifierStr, modifierIndent, currentY)
                            currentY = currentY + smallLineHeight
                        end
                        currentY = currentY + smallLineHeight * 0.3 -- Pequeno espaço extra após modificadores
                    else
                        currentY = currentY + smallLineHeight * 0.5 -- Espaço mesmo se não houver mods
                    end
                else
                    -- Desenha placeholder se archetypeData não for encontrado
                    love.graphics.setFont(fonts.main_small)
                    love.graphics.setColor(colors.red)
                    love.graphics.print(" - Arquetipo ID: " .. archetypeId .. " (Não encontrado)", x + 5, currentY)
                    currentY = currentY + smallLineHeight
                end
            end
        else
            love.graphics.setFont(fonts.main_small)
            love.graphics.setColor(colors.text_label)
            love.graphics.printf("Nenhum arquétipo atribuído.", x, currentY, w, "left")
            currentY = currentY + smallLineHeight
        end
    end
    -- <<< FIM: NOVA SUBSEÇÃO DE ARQUÉTIPOS >>>

    love.graphics.setFont(fonts.main) -- Reset final
    love.graphics.setColor(colors.white)
end

return StatsSection
