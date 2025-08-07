---@class Colors
local colors = {
    -- ========== CORES BÁSICAS (SEMPRE MANTER) ==========
    transparent = { 0, 0, 0, 0 },
}

-- ========== FUNÇÕES DE CONVERSÃO HEX ==========

--- Converte cor HEX para formato LÖVE (0-1)
---@param hex string Cor em formato HEX (#FFFFFF, #FFF, FFFFFF, FFF)
---@param alpha? number Alpha opcional (0-1), padrão 1.0
---@return table color Cor no formato {r, g, b, a} para LÖVE
function colors.hex(hex, alpha)
    alpha = alpha or 1.0

    -- Remove # se presente
    hex = hex:gsub("#", "")

    -- Expande formato curto (#FFF -> #FFFFFF)
    if #hex == 3 then
        hex = hex:gsub("(.)", "%1%1")
    end

    -- Valida formato
    if #hex ~= 6 then
        if Logger then
            Logger.error("colors.hex.invalid_format",
                string.format("[Colors.hex] Formato HEX inválido: %s", hex))
        end
        return { 1, 1, 1, alpha } -- Retorna branco como fallback
    end

    -- Converte cada componente
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255

    return { r, g, b, alpha }
end

--- Converte cor LÖVE (0-1) para formato HEX
---@param color table Cor no formato {r, g, b, a?} do LÖVE
---@return string hex Cor em formato HEX (#FFFFFF)
function colors.toHex(color)
    local r = math.floor(color[1] * 255 + 0.5)
    local g = math.floor(color[2] * 255 + 0.5)
    local b = math.floor(color[3] * 255 + 0.5)

    return string.format("#%02X%02X%02X", r, g, b)
end

--- Cria uma paleta de cores a partir de uma lista de HEX
---@param hexList table Lista de cores HEX {name = "#FFFFFF", ...}
---@param alpha? number Alpha global opcional
---@return table palette Paleta convertida para LÖVE
function colors.palette(hexList, alpha)
    local result = {}
    for name, hexColor in pairs(hexList) do
        result[name] = colors.hex(hexColor, alpha)
    end
    return result
end

--- Cria variações de uma cor base (mais claro/escuro)
---@param baseHex string Cor base em HEX
---@param steps? number Número de variações (padrão 5)
---@return table variations Variações {lighter1, lighter2, base, darker1, darker2}
function colors.variations(baseHex, steps)
    steps = steps or 5
    local base = colors.hex(baseHex)
    local result = {}

    local halfSteps = math.floor(steps / 2)

    for i = -halfSteps, halfSteps do
        local factor = 1 + (i * 0.2)              -- 20% de variação por step
        factor = math.max(0, math.min(2, factor)) -- Limita entre 0 e 2

        local name = i == 0 and "base" or
            (i > 0 and "lighter" .. i or "darker" .. math.abs(i))

        result[name] = {
            math.min(1, base[1] * factor),
            math.min(1, base[2] * factor),
            math.min(1, base[3] * factor),
            base[4]
        }
    end

    return result
end

-- ========== CORES PRINCIPAIS DO JOGO ==========

-- Cores básicas
colors.white = colors.hex("#FFFFFF")
colors.black = colors.hex("#000000")
colors.gray = colors.hex("#808080")
colors.red = colors.hex("#FF0000")

-- Interface base (Solo Leveling theme)
colors.window_bg = colors.hex("#0F1218", 0.95)    -- Fundo de janelas escuro
colors.window_border = colors.hex("#67738C", 0.8) -- Borda azul acinzentada
colors.window_title = colors.hex("#B3BFC6")       -- Título branco azulado
colors.panel_bg = colors.hex("#141A1F", 0.9)      -- Fundo de painéis
colors.modal_bg = colors.hex("#1D1F26", 0.9)      -- Fundo de modais
colors.modal_border = colors.hex("#4D7AB3")       -- Borda de modais

-- Cores de texto
colors.text_main = colors.hex("#CCD9E6")      -- Texto principal
colors.text_default = colors.hex("#CCD9E6")   -- Texto padrão
colors.text_title = colors.hex("#E6EBF2")     -- Títulos
colors.text_muted = colors.hex("#8C9199")     -- Texto secundário
colors.text_label = colors.hex("#999AA3")     -- Labels
colors.text_highlight = colors.hex("#4D99FF") -- Destaques azuis
colors.text_value = colors.hex("#D9E6F2")     -- Valores
colors.text_gold = colors.hex("#E6CC4D")      -- Texto dourado
colors.text_xp = colors.hex("#66B3FF")        -- Texto de XP
colors.text_success = colors.hex("#33CC52")   -- Verde sucesso
colors.text_danger = colors.hex("#CC3333")    -- Vermelho perigo

-- Barras de status
colors.bar_bg = colors.hex("#14161C", 0.9)     -- Fundo de barras
colors.bar_border = colors.hex("#4D5966", 0.8) -- Borda de barras
colors.hp_fill = colors.hex("#B33333")         -- Preenchimento de vida
colors.mp_fill = colors.hex("#3366CC")         -- Preenchimento de mana
colors.xp_fill = colors.hex("#4D99FF")         -- Preenchimento de XP

-- Inventário e slots
colors.slot_empty_bg = colors.hex("#121417", 0.8)         -- Slot vazio
colors.slot_empty_border = colors.hex("#4D5966", 0.3)     -- Borda slot vazio
colors.slot_hover_bg = colors.hex("#1A2633", 0.7)         -- Slot com hover
colors.slot_bg = colors.hex("#1D1F26", 0.85)              -- Slot ocupado
colors.border_active = colors.hex("#4D99FF")              -- Borda ativa
colors.inventory_slot_bg = colors.hex("#1D1F26", 0.9)     -- Slot do inventário
colors.inventory_slot_border = colors.hex("#67738C", 0.3) -- Borda slot inventário
colors.item_quantity_text = colors.hex("#E6E6E6")         -- Texto de quantidade

-- Botões
colors.button_primary_bg = colors.hex("#3380CC")      -- Botão principal
colors.button_primary_hover = colors.hex("#4D99E6")   -- Hover botão principal
colors.button_primary_text = colors.hex("#FFFFFF")    -- Texto botão principal
colors.button_secondary_bg = colors.hex("#666873")    -- Botão secundário
colors.button_secondary_hover = colors.hex("#8C8C8C") -- Hover botão secundário
colors.button_secondary_text = colors.hex("#FFFFFF")  -- Texto botão secundário
colors.button_border = colors.hex("#9999A6")          -- Borda de botões

-- Alertas e notificações
colors.alert_bg = colors.hex("#14161C", 0.95) -- Fundo de alerta
colors.alert_border = colors.hex("#4D99FF")   -- Borda de alerta
colors.alert_text = colors.hex("#CCD9E6")     -- Texto de alerta
colors.alert_icon = colors.hex("#4D99FF")     -- Ícone de alerta

-- Dano e cura
colors.damage_player = colors.hex("#CC4D4D") -- Dano do jogador
colors.damage_enemy = colors.hex("#D9E6F2")  -- Dano do inimigo
colors.damage_crit = colors.hex("#4D99FF")   -- Dano crítico
colors.heal = colors.hex("#66CC66")          -- Cura

-- Feedback visual
colors.positive = colors.hex("#66B3B3", 0.9)     -- Positivo (azul-verde)
colors.negative = colors.hex("#CC8052", 0.9)     -- Negativo (laranja)
colors.placement_valid = colors.hex("#33CC33")   -- Drop válido
colors.placement_invalid = colors.hex("#CC3333") -- Drop inválido

-- Lobby e navegação
colors.lobby_background = colors.hex("#262633") -- Fundo do lobby
colors.navbar_money = colors.hex("#F2D633")     -- Dourado do dinheiro
colors.navbar_tickets = colors.hex("#33B3FF")   -- Azul dos tickets

-- Tabs
colors.tab_bg = colors.hex("#333340")                -- Fundo normal de tab
colors.tab_hover = colors.hex("#4D4D59")             -- Tab com hover
colors.tab_highlighted_bg = colors.hex("#1A6699")    -- Tab destacado
colors.tab_highlighted_hover = colors.hex("#3380B3") -- Tab destacado hover
colors.tab_text = colors.hex("#E6E6E6")              -- Texto de tab
colors.tab_border = colors.hex("#666673")            -- Borda de tab

-- Tooltip
colors.tooltip_bg = colors.hex("#1A1A26", 0.95)    -- Fundo de tooltip
colors.tooltip_border = colors.hex("#67738C", 0.8) -- Borda de tooltip

-- Mapa
colors.map_tint = colors.hex("#4D6699") -- Tom do mapa

-- Utilidades
colors.black_transparent_more = colors.hex("#000000", 0.7) -- Sombra de texto

--- Cores das barras
--- Vida
local hpBarBaseColor = colors.hex("#CC4D4D", 0.95)
colors.hpBarBase = hpBarBaseColor
colors.hpBarFill = hpBarBaseColor
colors.hpBarTrail = colors.hex("#CC4D4D", 0.5)

--- Experiência
local xpBarBaseColor = colors.hex("#8A2BE2", 0.95)
colors.xplevelNumber = xpBarBaseColor
colors.xpText = colors.white
colors.xpGainText = xpBarBaseColor
colors.xpBarBase = xpBarBaseColor
colors.xpBarFill = xpBarBaseColor
colors.xpBarTrail = colors.hex("#8A2BE2", 0.5)

-- ========== SISTEMA DE RARIDADE ==========

colors.rarity = colors.palette({
    SS = "#FFD700", -- Dourado brilhante
    S = "#4D99FF",  -- Azul Solo Leveling
    A = "#CC4D4D",  -- Vermelho escuro
    B = "#6666CC",  -- Azul médio
    C = "#669966",  -- Verde escuro
    D = "#808080",  -- Cinza médio
    E = "#B3B3B3",  -- Cinza claro
})

-- Raridade com detalhes de gradiente (convertida para HEX)
colors.rankDetails = {
    E = {
        text = colors.hex("#D6D6D6"),
        gradientStart = colors.hex("#2F2F2F"),
        gradientEnd = colors.hex("#4C4C4C")
    },
    D = {
        text = colors.hex("#8BFCD4"),
        gradientStart = colors.hex("#2F8A78"),
        gradientEnd = colors.hex("#58CBA8")
    },
    C = {
        text = colors.hex("#A4F4FF"),
        gradientStart = colors.hex("#247BA0"),
        gradientEnd = colors.hex("#5AC8E0")
    },
    B = {
        text = colors.hex("#F291FF"),
        gradientStart = colors.hex("#692D84"),
        gradientEnd = colors.hex("#A04DD1")
    },
    A = {
        text = colors.hex("#FFE28D"),
        gradientStart = colors.hex("#B3832C"),
        gradientEnd = colors.hex("#E5B84A")
    },
    S = {
        text = colors.hex("#00F0FF"),
        gradientStart = colors.hex("#1A0B2E"),
        gradientEnd = colors.variations("#1A0B2E", 10)[1]
    },
    SS = {
        text = colors.hex("#FFD6D6"),
        gradientStart = colors.hex("#8B1A1A"),
        gradientEnd = colors.hex("#FF4A4A")
    },
    TEST = {
        text = colors.hex("#FFFFFF"),
        gradientStart = colors.hex("#FF00FF"),
        gradientEnd = colors.hex("#FFAAFF")
    }
}

-- ========== SISTEMA DE POÇÕES ==========

colors.potion = colors.palette({
    flask_border_empty = "#666673",
    flask_border_filling = "#80808C",
    flask_border_ready = "#33CC4D",
    flask_border_ready_flash = "#66FF80",
    liquid_healing = "#CC3340",
    liquid_healing_bright = "#FF4D59",
    liquid_ready = "#26B340",
    liquid_ready_glow = "#4DE666",
    liquid_ready_flash = "#66FF80",
    counter_text = "#CCD9E6",
    percentage_text = "#E6E6E6",
    ready_icon = "#F2F2F2",
}, 0.8) -- Alpha global de 0.8 para líquidos

-- ========== CORES DE ATRIBUTOS ==========

colors.attribute_colors = colors.palette({
    -- Ofensivo - Tons de Vermelho/Laranja
    damage = "#FF4136",            -- Vermelho Fogo
    attack_speed = "#FF851B",      -- Laranja
    criticalChance = "#FFC43D",    -- Amarelo Dourado
    criticalDamage = "#FFD700",    -- Dourado Brilhante
    multiAttackChance = "#FFAA00", -- Laranja Âmbar

    -- Defensivo - Tons de Azul/Ciano
    maxHealth = "#0074D9",   -- Azul Intenso
    defense = "#7FDBFF",     -- Azul Céu
    healthRegen = "#39CCCC", -- Ciano

    -- Mobilidade - Tons de Verde/Lima
    moveSpeed = "#2ECC40",    -- Verde
    dashCharges = "#A1E533",  -- Verde Lima
    dashCooldown = "#01FF70", -- Verde Elétrico
    dashDistance = "#BEEF9E", -- Verde Claro
    dashDuration = "#89AC76", -- Verde Musgo

    -- Utilitário e Suporte - Tons de Roxo/Magenta
    pickupRadius = "#B10DC9",      -- Roxo
    luck = "#F012BE",              -- Magenta
    expBonus = "#E374FF",          -- Lilás
    cooldownReduction = "#D462FF", -- Violeta

    -- Poções - Tons de Marrom/Cobre
    potionFlasks = "#D2691E",     -- Chocolate
    potionHealAmount = "#B87333", -- Cobre
    potionFillRate = "#8B4513",   -- Marrom Sela

    -- Especial - Tons Cinza/Branco
    range = "#DDDDDD",     -- Cinza Claro
    area = "#F5F5F5",      -- Branco Neve
    strength = "#FFFFFF",  -- Branco Puro
    runeSlots = "#92E594", -- Verde Cura
})

-- ========== CORES DE INIMIGOS ==========

colors.enemyPowerColors = colors.palette({
    level_1 = "#B3BFC6", -- Branco azulado
    level_2 = "#4D99FF", -- Azul Solo Leveling
    level_3 = "#CC4D4D", -- Vermelho escuro
    level_4 = "#6600CC", -- Roxo escuro
    level_5 = "#1A334D", -- Azul muito escuro
})

-- ========== TONS DE PELE ==========

colors.skinTones = colors.palette({
    pale = "#FAEADE",         -- Pálido rosado
    light = "#F7DCC4",        -- Claro dourado
    medium_light = "#E0BD9E", -- Médio claro
    medium = "#D4AB82",       -- Médio bronzeado
    medium_dark = "#A87D5C",  -- Médio escuro
    dark = "#7D5940",         -- Escuro
    very_dark = "#52381A",    -- Muito escuro
    olive = "#CCB58F",        -- Oliva
    warm = "#E3BA92",         -- Quente
    cool = "#F5D9CC",         -- Frio
})

-- ========== SISTEMA DE BOTÕES VARIANTES ==========

-- Cores base para botões
local btn_colors = colors.palette({
    text_light = "#FFFFFF",
    text_dark = "#1A1A1A",
    border_default = "#6673804D",
    bg_default = "#404752",
    hover_default = "#59616B",
    pressed_default = "#343A45",
    disabled_bg = "#333333",
    disabled_text = "#808080",
    disabled_border = "#4D4D4D",
}, 0.8) -- Alpha para botões

-- Variante padrão
colors.button_default = {
    bgColor = btn_colors.bg_default,
    hoverColor = btn_colors.hover_default,
    pressedColor = btn_colors.pressed_default,
    textColor = btn_colors.text_light,
    borderColor = btn_colors.border_default,
    disabledBgColor = btn_colors.disabled_bg,
    disabledTextColor = btn_colors.disabled_text,
    disabledBorderColor = btn_colors.disabled_border,
}

-- Variante primária
colors.button_primary = {
    bgColor = colors.hex("#3380CC"),
    hoverColor = colors.hex("#4D99E6"),
    pressedColor = colors.hex("#2666B3"),
    textColor = btn_colors.text_light,
    borderColor = colors.hex("#66B3FF"),
    disabledBgColor = btn_colors.disabled_bg,
    disabledTextColor = btn_colors.disabled_text,
    disabledBorderColor = btn_colors.disabled_border,
}

-- Variante secundária
colors.button_secondary = {
    bgColor = colors.hex("#999999"),
    hoverColor = colors.hex("#B3B3B3"),
    pressedColor = colors.hex("#808080"),
    textColor = btn_colors.text_dark,
    borderColor = colors.hex("#CCCCCC"),
    disabledBgColor = btn_colors.disabled_bg,
    disabledTextColor = btn_colors.disabled_text,
    disabledBorderColor = btn_colors.disabled_border,
}

-- Variante de perigo
colors.button_danger = {
    bgColor = colors.hex("#CC3333"),
    hoverColor = colors.hex("#E64D4D"),
    pressedColor = colors.hex("#B32626"),
    textColor = btn_colors.text_light,
    borderColor = colors.hex("#FF6666"),
    disabledBgColor = btn_colors.disabled_bg,
    disabledTextColor = btn_colors.disabled_text,
    disabledBorderColor = btn_colors.disabled_border,
}

-- ========== NÚMEROS DE DANO ==========

colors.damage_number = colors.palette({
    normal = "#FFFFFF",         -- Branco
    critical = "#FFC700",       -- Dourado
    super_critical = "#FF3399", -- Rosa/Magenta
})

-- ========== TRANSIÇÕES DE EXTRAÇÃO ==========

colors.extraction_transition = {
    success = colors.palette({
        background = "#051408",
        accent_primary = "#1A9933",
        accent_secondary = "#26CC4D",
        text_primary = "#B3F2CC",
        text_secondary = "#80CC99",
        progress_fill = "#33E666",
        progress_bg = "#0D401A",
        glow_effect = "#4DFF80",
    }),
    death = colors.palette({
        background = "#140505",
        accent_primary = "#991A1A",
        accent_secondary = "#CC2626",
        text_primary = "#F2B3B3",
        text_secondary = "#CC8080",
        progress_fill = "#E63333",
        progress_bg = "#400D0D",
        glow_effect = "#FF4D4D",
    })
}

-- ========== PALETAS TEMÁTICAS ==========

-- Paleta Solo Leveling
colors.solo_leveling = colors.palette({
    shadow_monarch = "#1A0B2E", -- Roxo escuro do Monarca das Sombras
    ice_blue = "#00D4FF",       -- Azul gelo dos ataques mágicos
    hunter_gold = "#FFD700",    -- Dourado dos hunters rank S
    system_green = "#00FF88",   -- Verde dos sistemas/upgrades
    boss_red = "#FF0040",       -- Vermelho intenso dos bosses
    portal_purple = "#8A2BE2",  -- Roxo místico dos portais
    dark_dungeon = "#0D1117",   -- Preto azulado das dungeons
    mana_crystal = "#4FC3F7",   -- Azul cristalino do mana
})

-- Paleta de feedback
colors.feedback = colors.palette({
    success = "#4CAF50", -- Verde de sucesso
    warning = "#FF9800", -- Laranja de aviso
    error = "#F44336",   -- Vermelho de erro
    info = "#2196F3",    -- Azul de informação
    loading = "#9C27B0", -- Roxo de carregamento
})

return colors
