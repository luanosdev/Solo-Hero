local colors = {
    transparent = { 0, 0, 0, 0 },
    white = { 1, 1, 1, 1 }, -- #FFFFFF
    black = { 0, 0, 0, 1 }, -- #000000

    -- Cores base inspiradas em Solo Leveling
    window_bg = { 0.06, 0.07, 0.09, 0.95 },  -- Preto azulado escuro
    window_border = { 0.4, 0.45, 0.5, 0.8 }, -- Azul acinzentado
    window_title = { 0.7, 0.75, 0.8, 1.0 },  -- Branco azulado

    text_main = { 0.8, 0.85, 0.9, 1.0 },     -- Branco suave
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

    slot_empty_bg = { 0.07, 0.08, 0.1, 0.8 },
    slot_empty_border = { 0.3, 0.35, 0.4, 0.6 },
    slot_hover_bg = { 0.1, 0.15, 0.2, 0.7 },

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

    enemyPowerColors = {
        [1] = { 0.7, 0.75, 0.8, 1.0 }, -- Branco azulado
        [2] = { 0.3, 0.6, 1.0, 1.0 },  -- Azul Solo Leveling
        [3] = { 0.8, 0.3, 0.3, 1.0 },  -- Vermelho escuro
        [4] = { 0.4, 0.0, 0.8, 1.0 },  -- Roxo escuro
        [5] = { 0.1, 0.2, 0.3, 1.0 },  -- Azul muito escuro
    }
}

return colors
