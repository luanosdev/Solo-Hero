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

    rarity = {
        SS = { 1.0, 0.84, 0.0, 1.0 }, -- Dourado Brilhante (para SS)
        S = { 0.3, 0.6, 1.0, 1.0 },   -- Azul Solo Leveling
        A = { 0.8, 0.3, 0.3, 1.0 },   -- Vermelho escuro
        B = { 0.4, 0.4, 0.8, 1.0 },   -- Azul médio
        C = { 0.4, 0.6, 0.4, 1.0 },   -- Verde escuro
        D = { 0.5, 0.5, 0.5, 1.0 },   -- Cinza médio
        E = { 0.7, 0.7, 0.7, 1.0 },   -- Cinza claro
    },

    -- Mapeamento de Rank para Cor (pode referenciar 'rarity' ou ter cores próprias)
    rank = {
        SS = { 1.0, 0.84, 0.0, 1.0 }, -- Dourado Brilhante
        S  = { 0.3, 0.6, 1.0, 1.0 },  -- Azul Solo Leveling
        A  = { 0.8, 0.3, 0.3, 1.0 },  -- Vermelho escuro
        B  = { 0.4, 0.4, 0.8, 1.0 },  -- Azul médio
        C  = { 0.4, 0.6, 0.4, 1.0 },  -- Verde escuro
        D  = { 0.5, 0.5, 0.5, 1.0 },  -- Cinza médio
        E  = { 0.7, 0.7, 0.7, 1.0 }   -- Cinza claro
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
