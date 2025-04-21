-- src/ui/inventory_screen.lua
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local glowShader = nil -- Variável para armazenar o shader, se carregado
local ManagerRegistry = require("src.managers.manager_registry") -- Adicionado
-- local player = require("src.entities.player") -- Assumindo que os dados do jogador virão daqui

-- Helper para formatar números
local function formatNumber(num)
    num = math.floor(num or 0) -- Garante que seja um número inteiro
    if num < 1000 then
        return tostring(num)
    elseif num < 1000000 then
        return string.format("%.1fK", num / 1000):gsub("%.0K", "K")
    elseif num < 1000000000 then
        return string.format("%.1fM", num / 1000000):gsub("%.0M", "M")
    else
        return string.format("%.1fB", num / 1000000000):gsub("%.0B", "B")
    end
end

-- Helper para formatar Chance de Ataque Múltiplo
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

local InventoryScreen = {}
InventoryScreen.isVisible = false
InventoryScreen.slotsPerRow = 8 -- Aumentado de 6 para 8
InventoryScreen.slotSize = 48 -- Tamanho base para inventário
InventoryScreen.slotSpacing = 5
InventoryScreen.equipmentSlotSize = 64 -- Tamanho maior para slots de equipamento
InventoryScreen.runeSlotSize = 32 -- Tamanho menor para runas

-- Função para obter o shader (será chamado pelo main.lua)
function InventoryScreen.setGlowShader(shader)
    glowShader = shader
end

-- Função para alternar a visibilidade e pausar/retomar o jogo
function InventoryScreen.toggle()
    -- print("  [InventoryScreen] toggle START. Current isVisible:", InventoryScreen.isVisible) -- DEBUG Removido
    InventoryScreen.isVisible = not InventoryScreen.isVisible
    -- print("  [InventoryScreen] toggle END. New isVisible:", InventoryScreen.isVisible) -- DEBUG Removido
    -- A lógica real de pausa/retomada será gerenciada no main.lua
    if InventoryScreen.isVisible then
        -- print("Inventário aberto.") -- DEBUG Removido
        -- TODO: Potencialmente buscar dados frescos do jogador aqui, se necessário
    else
        -- print("Inventário fechado.") -- DEBUG Removido
    end
    return InventoryScreen.isVisible -- Retorna o novo estado
end

function InventoryScreen.update(dt)
    if not InventoryScreen.isVisible then return end
    -- Lógica de atualização da UI, se houver (ex: efeitos de hover, animações)
end

-- Função principal de desenho da tela
function InventoryScreen.draw() -- Removido playerManager como argumento
    if not InventoryScreen.isVisible then return end

    -- Obtém PlayerManager do registro
    local playerManager = ManagerRegistry:get("playerManager")

    local screenW, screenH = love.graphics.getDimensions()
    -- Dimensões e posição do painel principal (Aumentado)
    local panelW = math.min(screenW * 0.95, 1400)
    local panelH = math.min(screenH * 0.85, 800)
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2
    -- print("  [InventoryScreen.draw] Calculou Painel e Seções") -- DEBUG Removido

    -- print("  [InventoryScreen.draw] Chamando drawWindowFrame...") -- DEBUG Removido
    elements.drawWindowFrame(panelX, panelY, panelW, panelH, "CHEERFUL JACK")
    -- print("  [InventoryScreen.draw] Retornou de drawWindowFrame") -- DEBUG Removido

    -- Calcula dimensões e posições das seções
    local padding = 20
    local titleHeight = fonts.title:getHeight()
    -- Ajusta Y inicial das seções para caber títulos internos
    local sectionTopY = panelY + titleHeight * 1.5 + padding
    local sectionContentH = panelH - (sectionTopY - panelY) - padding

    -- Larguras das seções (Ajustando para talvez dar mais espaço ao equipamento?)
    local statsW = panelW * 0.25
    local equipmentW = panelW * 0.30 -- Aumentado
    local inventoryW = panelW - statsW - equipmentW - padding * 4 -- O restante

    local statsX = panelX + padding
    local equipmentX = statsX + statsW + padding
    local inventoryX = equipmentX + equipmentW + padding

    InventoryScreen.drawStats(statsX, sectionTopY, statsW, sectionContentH, playerManager) -- Passa o playerManager obtido
    InventoryScreen.drawEquipment(equipmentX, sectionTopY, equipmentW, sectionContentH) -- TODO: Passar playerManager se necessário
    InventoryScreen.drawInventory(inventoryX, sectionTopY, inventoryW, sectionContentH) -- TODO: Passar playerManager se necessário
end

-- Desenha a seção de estatísticas (esquerda)
function InventoryScreen.drawStats(x, y, w, h, playerManager) -- Argumento playerManager permanece, pois é passado de draw()
    local state = playerManager.state -- Acessa o estado do jogador

    -- Definições de espaçamento padrão (reduzido)
    local lineHeight = fonts.main:getHeight() * 1.1 -- Reduzido para ser mais compacto
    -- local detailLineHeight = fonts.main:getHeight() * 1.1 -- Removido, usar lineHeight
    local sectionTitleLineHeight = fonts.hud:getHeight() * 1.5 -- Espaço após títulos de seção
    local sectionSpacing = lineHeight * 1.5 -- Espaço entre seções principais (baseado no novo lineHeight)

    -- Título da Seção (Maior)
    love.graphics.setFont(fonts.title) -- Fonte Maior para o título principal
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("HERÓI", x, y, w, "center")
    local titleH = fonts.title:getHeight() * 1.2 -- Espaçamento após título principal
    local currentY = y + titleH

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
    local hpText = formatNumber(state.currentHealth) .. "/" .. formatNumber(state:getTotalHealth())
    love.graphics.printf(hpText, x, currentY, w, "right")
    currentY = currentY + lineHeight -- Usar lineHeight reduzido

    -- Nível (ADICIONADO)
    love.graphics.setColor(colors.text_label)
    love.graphics.print("Nível", x, currentY)
    love.graphics.setColor(colors.text_value) -- Ou outra cor se preferir
    love.graphics.printf(tostring(state.level), x, currentY, w, "right")
    currentY = currentY + lineHeight -- Avança Y para a próxima linha

    -- Experiência
    love.graphics.setColor(colors.text_label)
    love.graphics.print("Experiência", x, currentY)
    love.graphics.setColor(colors.xp_fill)
    local xpNeeded = math.max(0, state.experienceToNextLevel - state.experience)
    local xpText = formatNumber(state.experience) .. "/" .. formatNumber(state.experienceToNextLevel)
    love.graphics.printf(xpText, x, currentY, w, "right")
    currentY = currentY + lineHeight -- Usar lineHeight reduzido
    -- XP para próximo nível
    love.graphics.setFont(fonts.main_small)
    love.graphics.setColor(colors.text_label)
    love.graphics.printf("(" .. formatNumber(xpNeeded) .. " para próximo nivel)", x, currentY - fonts.main:getHeight()*0.1, w, "right")
    love.graphics.setFont(fonts.main)
    currentY = currentY + lineHeight * 0.8 -- Espaço menor ainda OK

    -- Abates
    love.graphics.setColor(colors.text_label)
    love.graphics.print("Abates (Chefes/MVP/Inimigos)", x, currentY)
    love.graphics.setColor(colors.text_value)
    local killsText = "0/0/" .. formatNumber(state.kills)
    love.graphics.printf(killsText, x, currentY, w, "right")
    currentY = currentY + sectionSpacing -- Espaço entre seções principais

    -- Seção: Memória
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.print("MEMÓRIA", x, currentY)
    currentY = currentY + sectionTitleLineHeight -- Espaçamento padrão após título de seção

    local memoryStats = {
        {label = "Força", value = 15},
        {label = "Destreza", value = 12},
        {label = "Inteligência", value = 18},
        {label = "Vitalidade", value = 14}
    }

    love.graphics.setFont(fonts.main)
    for _, stat in ipairs(memoryStats) do
        love.graphics.setColor(colors.text_label)
        love.graphics.print(stat.label, x, currentY)
        love.graphics.setColor(colors.text_value)
        local valueStr = tostring(stat.value)
        love.graphics.printf(valueStr, x, currentY, w, "right")
        currentY = currentY + lineHeight -- Usar lineHeight reduzido
        if currentY > y + h - lineHeight then break end -- Segurança
    end
    currentY = currentY + sectionSpacing -- Espaço entre seções principais

    -- Seção de Atributos (baseados no state)
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.print("ATRIBUTOS", x, currentY)
    currentY = currentY + sectionTitleLineHeight -- Espaçamento padrão após título de seção

    -- Estrutura para buscar e exibir atributos
    local attributesToShow = {
        {label = "Vida Máxima",      baseKey="baseHealth", percKey="health", fixedKey="health", totalFunc=state.getTotalHealth, format = "%d"},
        {label = "Defesa",           baseKey="baseDefense", percKey="defense", fixedKey="defense", totalFunc=state.getTotalDefense, format = "%d"},
        {label = "Velocidade Mov.",  baseKey="baseSpeed", percKey="speed", fixedKey="speed", totalFunc=state.getTotalSpeed, format = "%.1f"}, -- Unidade m/s será adicionada manualmente
        {label = "Chance Crítico",   baseKey="baseCriticalChance", percKey="criticalChance", fixedKey="criticalChance", totalFunc=state.getTotalCriticalChance, format = "%.1f%%"},
        {label = "Mult. Crítico",    baseKey="baseCriticalMultiplier", percKey="criticalMultiplier", fixedKey="criticalMultiplier", totalFunc=state.getTotalCriticalMultiplier, format = "%.1fx"},
        {label = "Regen. Vida",      baseKey="baseHealthRegen", percKey="healthRegen", fixedKey="healthRegen", totalFunc=state.getTotalHealthRegen, format = "%.1f/Vida p/s"},
        {label = "Chance Atq. Múlt.", baseKey="baseMultiAttackChance", percKey="multiAttackChance", fixedKey=nil, totalFunc=state.getTotalMultiAttackChance, formatter = formatMultiAttack}, -- Usa formatter especial
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
                totalStr = "N/A s / HP" -- Or perhaps "---" ?
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
            local fixedStr = attr.fixedKey and fixedValue ~= 0 and string.format("%+.1f", fixedValue):gsub("%.0$", "") or nil
            if attr.label == "Chance Crítico" and fixedStr then
                 fixedStr = string.format("%+.1f%%", fixedValue * 100):gsub("%.0%%", "%%")
            end

            -- Calcula larguras para alinhamento à direita (DOS DETALHES)
            local totalWidth = fonts.main:getWidth(totalStr) -- Largura do valor total (já formatado)
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

                -- Só adiciona o "+" se não for o único bônus (base sempre existe)
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

        currentY = currentY + lineHeight -- Usar lineHeight reduzido
        if currentY > y + h - lineHeight then break end -- Segurança (usar lineHeight)
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
        -- Cores para detalhes
        local baseColor = colors.text_value
        local percBonusColor = colors.text_gold
        local totalColor = colors.text_highlight
        local operatorColor = colors.text_label

        -- Stats da arma para desenhar
        local weaponStatsToDraw = {}
        table.insert(weaponStatsToDraw, {label = "Nome", value = equippedWeapon.name or "Desconhecido", simple = true})
        -- Ajuste para Dano Total
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
        table.insert(weaponStatsToDraw, {label = "Dano Total", baseValueStr = baseDamageStrToDisplay, percBonus = state.levelBonus.damage or 0, totalValue = state:getTotalDamage(avgBaseDamageForTotalCalc), format = "%d", detail = true})
        
        -- RE-ADICIONANDO Atq./Seg com cálculo correto
        if equippedWeapon.attackInstance and equippedWeapon.attackInstance.cooldown and equippedWeapon.attackInstance.cooldown > 0 then
            local weaponCooldown = equippedWeapon.attackInstance.cooldown
            local percBonus = state.levelBonus.attackSpeed or 0
            -- Calcula cooldown efetivo: Base / (1 + Bonus%)
            local effectiveCooldown = weaponCooldown / (1 + percBonus / 100)
            local attacksPerSecond = (effectiveCooldown > 0) and (1 / effectiveCooldown) or 0
            table.insert(weaponStatsToDraw, {label = "Atq./Seg", value = attacksPerSecond, format = "%.2f", simple = true})
        end
        if equippedWeapon.range then 
            local baseRange = equippedWeapon.range
            local percBonusRange = state.levelBonus.range or 0
            local totalRange = baseRange * (1 + percBonusRange / 100) 
            table.insert(weaponStatsToDraw, {label = "Alcance", baseValue = baseRange, percBonus = percBonusRange, totalValue = totalRange, format = "%.1f", detail = true})
        end
        if equippedWeapon.attackInstance and equippedWeapon.attackInstance.damageType then table.insert(weaponStatsToDraw, {label = "Tipo Dano", value = equippedWeapon.attackInstance.damageType, simple = true}) end
        if equippedWeapon.attackInstance and equippedWeapon.attackInstance.cooldown then
            table.insert(weaponStatsToDraw, {label = "Cooldown Base", value = equippedWeapon.attackInstance.cooldown, format = "%.2fs", simple = true})
        end
        -- Área (Exibe a base da arma) -- REMOVIDO
        -- Adicionar Ângulo Efetivo (Detalhado)
        if equippedWeapon.angle then -- Check base angle in weapon definition
            local baseAngleRad = equippedWeapon.angle
            local areaBonusPerc = state.levelBonus.area or 0
            -- Calcula ângulo efetivo (Suposição: Bônus de área aumenta o ângulo proporcionalmente)
            local effectiveAngleRad = baseAngleRad * (1 + areaBonusPerc / 100)
            -- Converte para graus para exibição
            local baseAngleDeg = math.deg(baseAngleRad)
            local effectiveAngleDeg = math.deg(effectiveAngleRad)
            table.insert(weaponStatsToDraw, {
                label = "Ângulo Efetivo", 
                baseValue = baseAngleDeg, 
                percBonus = areaBonusPerc, 
                totalValue = effectiveAngleDeg, 
                format = "%.0f°", -- Formato em graus
                detail = true
            })
        end
        
        -- Loop para desenhar stats da arma
        for _, stat in ipairs(weaponStatsToDraw) do
            love.graphics.setColor(colors.text_label)
            love.graphics.print(stat.label, x, currentY)
            
            if stat.simple then 
                love.graphics.setColor(colors.text_value)
                local valueStr = "?"
                xpcall(function() valueStr = stat.format and string.format(stat.format, stat.value) or tostring(stat.value) end, 
                    function(err) -- print(string.format("ERRO formatando stat SIMPLES '%s': %s", stat.label, err)) -- DEBUG Comentado
                        end)
                love.graphics.printf(valueStr, x, currentY, w, "right")
            elseif stat.detail then 
                local totalStr, baseStr, percStr = "?", "?", "?" -- Default values

                -- Format Total
                xpcall(function()
                    totalStr = string.format(stat.format, stat.totalValue) 
                end, function(err) -- print(string.format("  [DEBUG] ERROR formatting totalStr for %s: %s", stat.label, err)) -- DEBUG Comentado
                    end)

                -- Format Base
                xpcall(function()
                    if stat.baseValueStr then
                        baseStr = stat.baseValueStr
                    elseif type(stat.baseValue) == "number" then
                        baseStr = string.format("%.1f", stat.baseValue):gsub("%.0$", "") 
                    end
                end, function(err) -- print(string.format("  [DEBUG] ERROR formatting baseStr for %s: %s", stat.label, err)) -- DEBUG Comentado
                    end)

                -- Format Percentage
                -- print(string.format("  [DEBUG] Formatting percBonus: %s (Type: %s) for %s", tostring(stat.percBonus), type(stat.percBonus), stat.label)) -- DEBUG Comentado
                xpcall(function()
                    if type(stat.percBonus) == "number" then
                        percStr = string.format("+%.0f%%", stat.percBonus)
                    end
                end, function(err) -- print(string.format("  [DEBUG] ERROR formatting percStr for %s: %s", stat.label, err)) -- DEBUG Comentado
                    end)

                -- Calcula larguras (usando as strings formatadas)
                local totalWidth = fonts.main:getWidth(totalStr)
                local baseWidth = fonts.main:getWidth(baseStr)
                local percWidth = fonts.main:getWidth(percStr)
                local bracketWidth = fonts.main:getWidth(" () ")
                local plusWidth = fonts.main:getWidth(" + ")
                local currentDrawX = x + w

                -- ... (Lógica de desenho usando totalStr, baseStr, percStr permanece a mesma) ...
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
        currentY = currentY + lineHeight -- Usar lineHeight reduzido
    end

    love.graphics.setFont(fonts.main)
end

-- Desenha a seção de equipamento (centro)
function InventoryScreen.drawEquipment(x, y, w, h)
    -- print("    [InventoryScreen.drawEquipment] START") -- DEBUG Removido
    -- Adiciona Título da Seção
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("EQUIPAMENTO", x, y, w, "center")
    local titleH = fonts.hud:getHeight() * 1.5
    local contentStartY = y + titleH -- Y onde o conteúdo começa
    local contentH = h - titleH -- Altura disponível

    -- Área de pré-visualização do personagem (placeholder) - Mantendo por enquanto
    local previewH = contentH * 0.5 -- Reduzido para dar espaço aos slots
    local previewW = previewH * 0.6
    local previewX = x + (w - previewW) / 2
    local previewY = contentStartY + contentH * 0.05 -- Um pouco abaixo do título
    love.graphics.setColor(colors.slot_empty_border)
    love.graphics.rectangle("line", previewX, previewY, previewW, previewH)
    love.graphics.setColor(colors.text_label)
    love.graphics.printf("Visual", previewX, previewY + previewH/2 - fonts.main:getHeight()/2, previewW, "center")

    -- Slots de equipamento principais
    local eqSlotSize = InventoryScreen.equipmentSlotSize
    local eqSpacing = InventoryScreen.slotSpacing * 2 -- Espaçamento entre slots de equipamento

    -- Posições relativas ao centro da seção ou à preview? Vamos tentar relativo ao centro da seção.
    local centerX = x + w / 2
    local startEqY = previewY + previewH + eqSpacing * 2 -- Começa abaixo da preview

    local equipmentSlots = {
        {id = "weapon",   label="Arma",     relX = -1, relY = 0},
        {id = "armor",    label="Armadura", relX = 1,  relY = 0},
        {id = "amulet",   label="Amuleto",  relX = -1, relY = 1},
        {id = "backpack", label="Mochila",  relX = 1,  relY = 1},
    }

    love.graphics.setLineWidth(1)
    for _, slot in ipairs(equipmentSlots) do
        -- Calcula X baseado no centro, relX (-1 ou 1), tamanho e espaçamento
        local slotX = centerX + slot.relX * (eqSlotSize / 2 + eqSpacing / 2) - eqSlotSize / 2
        -- Calcula Y baseado na posição inicial e relY
        local slotY = startEqY + slot.relY * (eqSlotSize + eqSpacing)

        -- TODO: Obter o item equipado para este slot
        local equippedItem = nil -- Exemplo: PlayerManager.player.equipment[slot.id]

        InventoryScreen.drawSingleSlot(slotX, slotY, eqSlotSize, eqSlotSize, equippedItem, slot.label)
    end

    -- Slots de Runas
    local runeSlotSize = InventoryScreen.runeSlotSize
    local runeSpacing = InventoryScreen.slotSpacing
    local numRunes = 4 -- Quantidade de runas
    local totalRunesWidth = numRunes * runeSlotSize + (numRunes - 1) * runeSpacing
    local runesStartX = centerX - totalRunesWidth / 2
    local runesY = startEqY + 2 * (eqSlotSize + eqSpacing) -- Abaixo dos slots principais

    love.graphics.setFont(fonts.main)
    love.graphics.setColor(colors.text_label)
    love.graphics.printf("Runas", x, runesY - fonts.main:getHeight() * 1.5, w, "center") -- Título para runas

    for i = 1, numRunes do
        local slotX = runesStartX + (i-1) * (runeSlotSize + runeSpacing)
        -- TODO: Obter a runa equipada para este slot
        local equippedRune = nil -- Exemplo: PlayerManager.player.runes[i]

        InventoryScreen.drawSingleSlot(slotX, runesY, runeSlotSize, runeSlotSize, equippedRune)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setFont(fonts.main) -- Garante fonte padrão
    -- print("    [InventoryScreen.drawEquipment] END") -- DEBUG Removido
end

-- Desenha a seção do inventário (direita)
function InventoryScreen.drawInventory(x, y, w, h)
    -- print("    [InventoryScreen.drawInventory] START") -- DEBUG Removido
    -- Adiciona Título da Seção
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)

    local titleH = fonts.hud:getHeight() * 1.5
    local contentStartY = y + titleH -- Y onde o conteúdo começa
    local contentH = h - titleH -- Altura disponível

    local slotSize = InventoryScreen.slotSize
    local spacing = InventoryScreen.slotSpacing
    local cols = InventoryScreen.slotsPerRow -- Agora 8
    local rows = 6 -- Fixo em 6 linhas por enquanto

    -- Calcula a largura real da grade para centralizar título e itens
    local gridWidth = cols * slotSize + math.max(0, cols - 1) * spacing
    local gridStartX = x + (w - gridWidth) / 2 -- X onde a grade começa

    -- Conta itens atuais e calcula total de slots
    local currentItemCount = 0
    -- TODO: Obter inventário real do PlayerManager ou similar
    local inventoryItems = { -- Usando placeholder por enquanto
        { id = "potion_heal", quantity = 6, rarity = "C" }, { id = "scrap", quantity = 19, rarity = "E" }, nil, nil, nil, nil, nil, nil, -- Linha 1 (8 cols)
        { id = "molotov", quantity = 3, rarity = "B" }, { id = "notes", quantity = 2, rarity = "E" }, { id = "ammo_pistol", quantity = 7, rarity = "E" }, { id = "suit", rarity = "A" }, { id = "energy_cell", quantity = 2, rarity = "B" }, nil, nil, nil, -- Linha 2
        { id = "portal_device", rarity = "S" }, { id = "comic1", rarity = "D" }, { id = "duct_tape", quantity = 35, rarity = "E" }, { id = "crystal_shard", quantity = 6, rarity = "A" }, nil, nil, nil, nil, -- Linha 3
        { id = "energy_drink", quantity = 20, rarity = "E" }, { id = "component", quantity = 80, rarity = "E" }, { id = "food_can", quantity = 7, rarity = "E" }, { id = "comic2", rarity = "D" }, { id = "medkit", quantity = 1, rarity = "B"}, nil, nil, nil, -- Linha 4
        { id = "key", quantity = 4, rarity = "E" }, { id = "scissors", quantity = 4, rarity = "E" }, { id = "lighter", quantity = 2, rarity = "E" }, { id = "toolbox", rarity = "B" }, { id = "stimpack", quantity = 4, rarity = "C"}, nil, nil, nil, -- Linha 5
        nil, nil, nil, nil, nil, nil, nil, nil, -- Linha 6
    }
    -- Contagem real dos itens no placeholder
    for _, item in ipairs(inventoryItems) do
        if item then currentItemCount = currentItemCount + 1 end
    end
    local totalSlots = rows * cols -- 6 * 8 = 48
    local countText = string.format(" (%d/%d)", currentItemCount, totalSlots) -- TODO: O total deveria vir da mochila?

    -- Desenha Título Centralizado com Contagem
    local titleText = "INVENTÁRIO" .. countText
    love.graphics.printf(titleText, x, y, w, "center") -- Desenha o título

    -- Ajusta Y inicial da grade de slots para ficar abaixo do título
    local startY = contentStartY
    -- Ajusta X inicial da grade para centralizar
    local startX = gridStartX

    -- Preenche a tabela inventoryItems se necessário (usando o placeholder)
    local currentSize = #inventoryItems
    if currentSize < totalSlots then
        for i = currentSize + 1, totalSlots do
            inventoryItems[i] = nil -- Atribuição direta
        end
    elseif currentSize > totalSlots then -- Trunca se placeholder for maior
        for i = currentSize, totalSlots + 1, -1 do
            inventoryItems[i] = nil
        end
    end

    -- Reativando slotIndex e setLineWidth
    local slotIndex = 1
    love.graphics.setLineWidth(1)

    -- Loop principal para desenhar os slots
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            local slotX = startX + c * (slotSize + spacing)
            local slotY = startY + r * (slotSize + spacing)
            local item = inventoryItems[slotIndex]

            -- Usa a função helper para desenhar o slot
            InventoryScreen.drawSingleSlot(slotX, slotY, slotSize, slotSize, item)

            slotIndex = slotIndex + 1
            -- Não precisamos mais do break interno aqui se a tabela já tem o tamanho certo
            -- if slotIndex > totalSlots then break end
        end
        -- Nem do break externo
        -- if slotIndex > totalSlots then break end
    end

    love.graphics.setLineWidth(1)
    love.graphics.setFont(fonts.main) -- Garante que a fonte padrão seja restaurada
    -- print("    [InventoryScreen.drawInventory] END (Código completo reativado)") -- DEBUG Removido
end


-- Função HELPER para desenhar um único slot (equipamento ou inventário)
function InventoryScreen.drawSingleSlot(slotX, slotY, slotW, slotH, item, label)
    if item then
         -- TODO: Desenhar ícone real do item baseado em item.id
         -- Placeholder: Desenha a primeira letra do ID
         love.graphics.setColor(colors.white)
         love.graphics.setFont(fonts.title) -- Usando uma fonte maior para placeholder
         love.graphics.printf(string.sub(item.id, 1, 1), slotX, slotY + slotH * 0.1, slotW, "center")
         love.graphics.setFont(fonts.main) -- Restaura fonte

         -- Desenha borda e brilho da raridade
         if elements and elements.drawRarityBorderAndGlow then
             elements.drawRarityBorderAndGlow(item.rarity or 'E', slotX, slotY, slotW, slotH)
         else -- Fallback
             local rarityColor = colors.rarity[item.rarity or 'E'] or colors.rarity['E']
             love.graphics.setLineWidth(2)
             love.graphics.setColor(rarityColor)
             love.graphics.rectangle("line", slotX, slotY, slotW, slotH, 3, 3)
             love.graphics.setLineWidth(1)
         end

         -- Desenha contagem de itens (se aplicável e > 1)
         if item.quantity and item.quantity > 1 then
             love.graphics.setFont(fonts.stack_count)
             local countStr = tostring(item.quantity)
             local textW = fonts.stack_count:getWidth(countStr)
             local textH = fonts.stack_count:getHeight()
             -- Posiciona no canto inferior direito
             local textX = slotX + slotW - textW - 3
             local textY = slotY + slotH - textH - 1

             love.graphics.setColor(0, 0, 0, 0.6) -- Fundo semi-transparente
             love.graphics.rectangle("fill", textX - 1, textY - 1, textW + 2, textH + 1, 2, 2)
             love.graphics.setColor(colors.white)
             love.graphics.print(countStr, textX, textY)
             love.graphics.setFont(fonts.main) -- Restaura fonte
         end
    else
        -- Desenha slot vazio
        love.graphics.setColor(colors.slot_empty_bg)
        love.graphics.rectangle("fill", slotX, slotY, slotW, slotH, 3, 3)
        love.graphics.setColor(colors.slot_empty_border)
        love.graphics.rectangle("line", slotX, slotY, slotW, slotH, 3, 3)

        -- Desenha label do slot se fornecido (para equipamento)
        if label then
            love.graphics.setFont(fonts.main_small)
            love.graphics.setColor(colors.text_label)
            love.graphics.printf(label, slotX, slotY + slotH/2 - fonts.main_small:getHeight()/2, slotW, "center")
            love.graphics.setFont(fonts.main)
        end
    end
end


-- Função para processar input quando o inventário está visível
function InventoryScreen.keypressed(key)
    if not InventoryScreen.isVisible then return false end

    -- TODO: Adicionar lógica de navegação/interação dentro do inventário
    if key == "escape" or key == "tab" then -- 'tab' também fecha (a pausa é tratada em main.lua)
        InventoryScreen.toggle()
        return true
    end

    -- print("Inventory handled key:", key) -- DEBUG Removido
    return true -- Consome outras teclas por enquanto
end

-- Função para tratar cliques do mouse quando o inventário está visível
function InventoryScreen.mousepressed(x, y, button)
    if not InventoryScreen.isVisible then return false end

    -- TODO: Lógica de clique nos slots
    -- print("Inventory click detection placeholder @", x, y, button) -- DEBUG Removido

    -- Consome o clique por enquanto para evitar interação com o jogo
    return true
end

return InventoryScreen 