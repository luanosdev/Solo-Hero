---@class Colors
local colors = {
    transparent = { 0, 0, 0, 0 },
    white = { 1, 1, 1, 1 }, -- #FFFFFF
    black = { 0, 0, 0, 1 }, -- #000000

    -- Cores base inspiradas em Solo Leveling
    window_bg = { 0.06, 0.07, 0.09, 0.95 },  -- Preto azulado escuro
    window_border = { 0.4, 0.45, 0.5, 0.8 }, -- Azul acinzentado
    window_title = { 0.7, 0.75, 0.8, 1.0 },  -- Branco azulado

    text_main = { 0.8, 0.85, 0.9, 1.0 },     -- Branco suave
    text_default = { 0.8, 0.85, 0.9, 1.0 },  -- Cor padrão (igual a text_main por enquanto)
    text_title = { 0.9, 0.92, 0.95, 1.0 },   -- Cor para títulos (ligeiramente mais claro)
    text_muted = { 0.5, 0.55, 0.6, 1.0 },    -- Cor para texto menos importante (cinza azulado)
    text_label = { 0.6, 0.65, 0.7, 1.0 },    -- Cinza claro
    text_highlight = { 0.3, 0.6, 1.0, 1.0 }, -- Azul brilhante
    text_value = { 0.85, 0.9, 0.95, 1 },     -- Branco azulado
    text_gold = { 0.9, 0.8, 0.3, 1.0 },      -- Dourado suave
    text_xp = { 0.4, 0.7, 1.0, 1.0 },        -- Azul claro

    bar_bg = { 0.08, 0.09, 0.11, 0.9 },      -- Preto azulado mais escuro
    bar_border = { 0.3, 0.35, 0.4, 0.8 },    -- Azul escuro
    hp_fill = { 0.7, 0.2, 0.2, 1.0 },        -- Vermelho escuro
    mp_fill = { 0.2, 0.4, 0.8, 1.0 },        -- Azul médio
    xp_fill = { 0.3, 0.6, 1.0, 1.0 },        -- Azul brilhante

    -- Cor para fundos de painéis/seções (como a lista/detalhes da guilda)
    panel_bg = { 0.08, 0.09, 0.12, 0.9 }, -- Azul/Preto levemente mais claro que window_bg

    slot_empty_bg = { 0.07, 0.08, 0.1, 0.8 },
    slot_empty_border = { 0.3, 0.35, 0.4, 0.6 },
    slot_hover_bg = { 0.1, 0.15, 0.2, 0.7 },
    slot_bg = { 0.1, 0.12, 0.15, 0.85 },             -- Cor de fundo para slots ocupados (pode ajustar)
    border_active = { 0.3, 0.7, 1.0, 1.0 },          -- Azul vibrante para borda do item/slot ativo
    -- <<< NOVAS CORES PARA SLOTS DE INVENTÁRIO/STORAGE >>>
    inventory_slot_bg = { 0.1, 0.12, 0.15, 0.9 },    -- Similar ao modal_bg, mas talvez um pouco mais opaco
    inventory_slot_border = { 0.4, 0.45, 0.5, 0.7 }, -- Similar ao window_border
    item_quantity_text = { 0.9, 0.9, 0.9, 1.0 },     -- Cor para texto de quantidade
    black_transparent_more = { 0, 0, 0, 0.7 },       -- Preto mais transparente para sombra de texto
    red = { 1, 0, 0, 1 },                            -- Cor vermelha básica para erros

    -- Cores de Raridade (mantidas como referência ou para itens)
    rarity = {
        SS = { 1.0, 0.84, 0.0, 1.0 }, -- Dourado Brilhante (para SS)
        S = { 0.3, 0.6, 1.0, 1.0 },   -- Azul Solo Leveling
        A = { 0.8, 0.3, 0.3, 1.0 },   -- Vermelho escuro
        B = { 0.4, 0.4, 0.8, 1.0 },   -- Azul médio
        C = { 0.4, 0.6, 0.4, 1.0 },   -- Verde escuro
        D = { 0.5, 0.5, 0.5, 1.0 },   -- Cinza médio
        E = { 0.7, 0.7, 0.7, 1.0 },   -- Cinza claro
    },

    -- Mapeamento de Rank para Cor (Cores Vibrantes Estilo Solo Leveling)
    --- @deprecated Usar colors.rankDetails para novas implementações.
    rank = {
        SS = { 1.0, 0.9, 0.2, 1.0 }, -- Dourado Vibrante
        S  = { 0.7, 0.2, 0.9, 1.0 }, -- Roxo Vibrante
        A  = { 1.0, 0.1, 0.1, 1.0 }, -- Vermelho Vivo
        B  = { 0.2, 0.5, 1.0, 1.0 }, -- Azul Brilhante
        C  = { 0.1, 0.8, 0.1, 1.0 }, -- Verde Brilhante
        D  = { 0.9, 0.5, 0.1, 1.0 }, -- Laranja
        E  = { 0.6, 0.6, 0.6, 1.0 }  -- Cinza
    },

    -- Novas definições de cores para Ranks com gradientes
    rankDetails = {
        -- Ranking E
        -- Gradiente: #2F2F2F → #4C4C4C
        -- Texto: #D6D6D6
        E = {
            text = { 0.839, 0.839, 0.839, 1.0 },          -- #D6D6D6
            gradientStart = { 0.184, 0.184, 0.184, 1.0 }, -- #2F2F2F
            gradientEnd = { 0.298, 0.298, 0.298, 1.0 }    -- #4C4C4C
        },
        -- Ranking D
        -- Gradiente: #2F8A78 → #58CBA8
        -- Texto: #8BFCD4
        D = {
            text = { 0.545, 0.988, 0.831, 1.0 },          -- #8BFCD4
            gradientStart = { 0.184, 0.541, 0.471, 1.0 }, -- #2F8A78
            gradientEnd = { 0.345, 0.796, 0.659, 1.0 }    -- #58CBA8
        },
        -- Ranking C
        -- Gradiente: #247BA0 → #5AC8E0
        -- Texto: #A4F4FF
        C = {
            text = { 0.643, 0.957, 1.0, 1.0 },            -- #A4F4FF
            gradientStart = { 0.141, 0.482, 0.627, 1.0 }, -- #247BA0
            gradientEnd = { 0.353, 0.784, 0.878, 1.0 }    -- #5AC8E0
        },
        -- Ranking B
        -- Gradiente: #692D84 → #A04DD1
        -- Texto: #F291FF
        B = {
            text = { 0.949, 0.569, 1.0, 1.0 },            -- #F291FF
            gradientStart = { 0.412, 0.176, 0.518, 1.0 }, -- #692D84
            gradientEnd = { 0.627, 0.302, 0.82, 1.0 }     -- #A04DD1
        },
        -- Ranking A
        -- Gradiente: #B3832C → #E5B84A
        -- Texto: #FFE28D
        A = {
            text = { 1.0, 0.886, 0.553, 1.0 },            -- #FFE28D
            gradientStart = { 0.702, 0.514, 0.173, 1.0 }, -- #B3832C
            gradientEnd = { 0.898, 0.722, 0.29, 1.0 }     -- #E5B84A
        },
        -- Ranking S
        -- Gradiente: #061821 → #00F0FF
        -- Texto: #00F0FF
        S = {
            text = { 0.0, 0.941, 1.0, 1.0 },              -- #00F0FF
            gradientStart = { 0.024, 0.094, 0.129, 1.0 }, -- #061821
            gradientEnd = { 0.0, 0.1175, 0.147, 1.0 }     -- #001E25 (Azul extremamente escuro)
        },
        -- Ranking SS
        -- Gradiente: #8B1A1A → #FF4A4A
        -- Texto: #FFD6D6
        SS = {
            text = { 1.0, 0.839, 0.839, 1.0 },            -- #FFD6D6
            gradientStart = { 0.545, 0.102, 0.102, 1.0 }, -- #8B1A1A
            gradientEnd = { 1.0, 0.29, 0.29, 1.0 }        -- #FF4A4A
        }
    },

    -- Cores para feedback de drag-and-drop
    placement_valid = { 0.2, 0.8, 0.2, 1.0 },   -- Verde para indicar local válido
    placement_invalid = { 0.8, 0.2, 0.2, 1.0 }, -- Vermelho para indicar local inválido

    alert_bg = { 0.08, 0.09, 0.11, 0.95 },
    alert_border = { 0.3, 0.6, 1.0, 1.0 },
    alert_text = { 0.8, 0.85, 0.9, 1.0 },
    alert_icon = { 0.3, 0.6, 1.0, 1.0 },
    damage_player = { 0.8, 0.3, 0.3, 1.0 },
    damage_enemy = { 0.85, 0.9, 0.95, 1.0 },
    damage_crit = { 0.3, 0.6, 1.0, 1.0 },
    heal = { 0.4, 0.8, 0.4, 1.0 },

    -- <<< CORES NEUTRAS PARA MODIFICADORES >>>
    positive = { 0.4, 0.7, 0.7, 0.9 }, -- Azul-esverdeado claro/Teal
    negative = { 0.8, 0.5, 0.3, 0.9 }, -- Laranja/Marrom suave

    -- Cores dos Tabs do Lobby
    lobby_background = { 0.15, 0.15, 0.2, 1 },    -- Fundo da cena do Lobby
    tab_bg = { 0.2, 0.2, 0.25, 1 },               -- Fundo normal do tab
    tab_hover = { 0.3, 0.3, 0.35, 1 },            -- Fundo do tab com hover
    tab_highlighted_bg = { 0.1, 0.4, 0.6, 1 },    -- Fundo do tab destacado
    tab_highlighted_hover = { 0.2, 0.5, 0.7, 1 }, -- Fundo do tab destacado com hover
    tab_text = { 0.9, 0.9, 0.9, 1 },              -- Cor do texto do tab
    tab_border = { 0.4, 0.4, 0.45, 1 },           -- Cor da borda do tab

    -- Cor do Modal de Detalhes do Portal
    modal_bg = { 0.1, 0.12, 0.15, 0.9 }, -- Fundo do modal (escuro, semitransparente)
    modal_border = { 0.3, 0.5, 0.7, 1 }, -- Borda do modal (azul acinzentado)

    -- Cores dos Botões do Modal
    button_primary_bg = { 0.2, 0.5, 0.8, 1 }, -- Azul para botão principal (Entrar)
    button_primary_hover = { 0.3, 0.6, 0.9, 1 },
    button_primary_text = { 1, 1, 1, 1 },
    button_secondary_bg = { 0.4, 0.4, 0.45, 1 }, -- Cinza para botão secundário (Cancelar)
    button_secondary_hover = { 0.5, 0.5, 0.55, 1 },
    button_secondary_text = { 1, 1, 1, 1 },
    button_border = { 0.6, 0.6, 0.65, 1 }, -- Borda comum para botões

    -- Cor do Mapa do Lobby
    map_tint = { 0.3, 0.4, 0.6, 1.0 }, -- <<< NOVA COR

    enemyPowerColors = {
        [1] = { 0.7, 0.75, 0.8, 1.0 }, -- Branco azulado
        [2] = { 0.3, 0.6, 1.0, 1.0 },  -- Azul Solo Leveling
        [3] = { 0.8, 0.3, 0.3, 1.0 },  -- Vermelho escuro
        [4] = { 0.4, 0.0, 0.8, 1.0 },  -- Roxo escuro
        [5] = { 0.1, 0.2, 0.3, 1.0 },  -- Azul muito escuro
    },

    tooltip_bg = { 0.1, 0.1, 0.15, 0.95 },
    tooltip_border = { 0.4, 0.45, 0.5, 0.8 },

    -- Cores do Sistema de Poções (Temática Solo Leveling)
    potion = {
        -- Contorno do frasco
        flask_border_empty = { 0.4, 0.4, 0.45, 1.0 },      -- Cinza quando vazio
        flask_border_filling = { 0.5, 0.5, 0.55, 1.0 },    -- Cinza claro quando enchendo
        flask_border_ready = { 0.2, 0.8, 0.3, 1.0 },       -- Verde Solo Leveling quando pronto
        flask_border_ready_flash = { 0.4, 1.0, 0.5, 1.0 }, -- Verde brilhante para flash

        -- Líquido da poção
        liquid_healing = { 0.8, 0.2, 0.25, 0.7 },        -- Vermelho escuro para poção de cura
        liquid_healing_bright = { 1.0, 0.3, 0.35, 0.8 }, -- Vermelho mais claro conforme enche
        liquid_ready = { 0.15, 0.7, 0.25, 0.8 },         -- Verde escuro quando pronta
        liquid_ready_glow = { 0.3, 0.9, 0.4, 0.4 },      -- Brilho verde sutil no topo
        liquid_ready_flash = { 0.4, 1.0, 0.5, 0.6 },     -- Verde brilhante para flash

        -- Texto
        counter_text = { 0.8, 0.85, 0.9, 1.0 },   -- Texto do contador (branco azulado)
        percentage_text = { 0.9, 0.9, 0.9, 1.0 }, -- Texto de porcentagem
        ready_icon = { 0.95, 0.95, 0.95, 1.0 },   -- Ícone de pronto (checkmark)
    },
}

-- Cores para Botões (NOVO SISTEMA DE VARIANTES)

-- Cores base para facilitar a definição
local btn_text_light = { 1, 1, 1, 1 }
local btn_text_dark = { 0.1, 0.1, 0.1, 1 }
local btn_border_default = { 0.4, 0.45, 0.5, 1 }
local btn_bg_default = { 0.25, 0.28, 0.32, 1 }
local btn_hover_default = { 0.35, 0.38, 0.42, 1 }
local btn_pressed_default = { 0.2, 0.23, 0.27, 1 }
local btn_disabled_bg = { 0.2, 0.2, 0.2, 0.7 }
local btn_disabled_text = { 0.5, 0.5, 0.5, 0.8 }
local btn_disabled_border = { 0.3, 0.3, 0.3, 0.7 }

-- Variante Padrão (Default)
colors.button_default = {
    bgColor = btn_bg_default,
    hoverColor = btn_hover_default,
    pressedColor = btn_pressed_default,
    textColor = btn_text_light,
    borderColor = btn_border_default,
    disabledBgColor = btn_disabled_bg,
    disabledTextColor = btn_disabled_text,
    disabledBorderColor = btn_disabled_border,
}

-- Variante Primária (ex: Ações principais, confirmação)
colors.button_primary = {
    bgColor = { 0.2, 0.5, 0.8, 1 }, -- Azul
    hoverColor = { 0.3, 0.6, 0.9, 1 },
    pressedColor = { 0.15, 0.4, 0.7, 1 },
    textColor = btn_text_light,
    borderColor = { 0.4, 0.7, 1.0, 1 }, -- Borda azul mais clara
    disabledBgColor = btn_disabled_bg,
    disabledTextColor = btn_disabled_text,
    disabledBorderColor = btn_disabled_border,
}

-- Variante Secundária (ex: Ações alternativas, cancelar)
colors.button_secondary = {
    bgColor = { 0.6, 0.6, 0.6, 1 }, -- Cinza
    hoverColor = { 0.7, 0.7, 0.7, 1 },
    pressedColor = { 0.5, 0.5, 0.5, 1 },
    textColor = btn_text_dark,
    borderColor = { 0.8, 0.8, 0.8, 1 }, -- Borda cinza mais clara
    disabledBgColor = btn_disabled_bg,
    disabledTextColor = btn_disabled_text,
    disabledBorderColor = btn_disabled_border,
}

-- Variante de Perigo (ex: Excluir, ações destrutivas)
colors.button_danger = {
    bgColor = { 0.8, 0.2, 0.2, 1 }, -- Vermelho
    hoverColor = { 0.9, 0.3, 0.3, 1 },
    pressedColor = { 0.7, 0.15, 0.15, 1 },
    textColor = btn_text_light,
    borderColor = { 1.0, 0.4, 0.4, 1 }, -- Borda vermelha mais clara
    disabledBgColor = btn_disabled_bg,
    disabledTextColor = btn_disabled_text,
    disabledBorderColor = btn_disabled_border,
}

return colors
