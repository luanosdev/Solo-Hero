-- ========================================
-- EXEMPLO PRÁTICO: Como usar cores HEX
-- ========================================

local colors = require("src.ui.colors")

-- ========== 1. USO BÁSICO ==========

-- ANTES (formato LÖVE manual - difícil de visualizar)
local old_way = {
    background = { 0.06, 0.07, 0.09, 0.95 }, -- Que cor é essa? 🤔
    button = { 0.2, 0.5, 0.8, 1.0 },         -- E essa? 🤔
    text = { 0.8, 0.85, 0.9, 1.0 },          -- Difícil saber...
}

-- DEPOIS (formato HEX - você VÊ a cor na IDE!)
local new_way = {
    background = colors.hex("#0F1218", 0.95), -- Azul escuro! 👀
    button = colors.hex("#3380CC"),           -- Azul bonito! 👀
    text = colors.hex("#D9DDE6"),             -- Branco azulado! 👀
}

-- ========== 2. PALETAS TEMÁTICAS ==========

-- Crie uma paleta Solo Leveling completa
local solo_leveling_theme = colors.palette({
    -- Personagens principais
    sung_jinwoo = "#1A0B2E", -- Roxo escuro do protagonista
    shadow_army = "#000000", -- Preto das sombras

    -- Sistema
    system_blue = "#00D4FF",  -- Azul do sistema
    level_up = "#00FF88",     -- Verde dos level ups
    notification = "#FFD700", -- Dourado das notificações

    -- Inimigos e perigos
    boss_aura = "#FF0040",      -- Vermelho dos bosses
    dungeon_portal = "#8A2BE2", -- Roxo dos portais

    -- UI
    dark_bg = "#0D1117",  -- Fundo escuro
    panel_bg = "#161B22", -- Painéis
    border = "#30363D",   -- Bordas
})

-- Use: solo_leveling_theme.sung_jinwoo, solo_leveling_theme.system_blue, etc.

-- ========== 3. VARIAÇÕES AUTOMÁTICAS ==========

-- Crie 5 tons de azul automaticamente
local blue_theme = colors.variations("#2196F3")

-- Agora você tem:
-- blue_theme.lighter2  -- Azul bem claro
-- blue_theme.lighter1  -- Azul claro
-- blue_theme.base      -- Azul original (#2196F3)
-- blue_theme.darker1   -- Azul escuro
-- blue_theme.darker2   -- Azul bem escuro

-- Perfect para botões:
function MyButton:draw()
    local button_color
    if self.pressed then
        button_color = blue_theme.darker2
    elseif self.hovered then
        button_color = blue_theme.lighter1
    else
        button_color = blue_theme.base
    end

    love.graphics.setColor(unpack(button_color))
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
end

-- ========== 4. CORES DE RARIDADE ==========

-- Sistema de raridade colorido e fácil de ver
local rarity_colors = colors.palette({
    common = "#9E9E9E",    -- Cinza
    uncommon = "#4CAF50",  -- Verde
    rare = "#2196F3",      -- Azul
    epic = "#9C27B0",      -- Roxo
    legendary = "#FF9800", -- Laranja
    mythic = "#F44336",    -- Vermelho
    divine = "#FFD700",    -- Dourado
})

function Item:getRarityColor()
    return rarity_colors[self.rarity] or rarity_colors.common
end

-- ========== 5. FEEDBACK VISUAL ==========

local feedback_colors = colors.palette({
    success = "#4CAF50", -- Verde ✅
    warning = "#FF9800", -- Laranja ⚠️
    error = "#F44336",   -- Vermelho ❌
    info = "#2196F3",    -- Azul ℹ️
    loading = "#9C27B0", -- Roxo ⏳
})

function NotificationSystem:show(message, type)
    local bg_color = feedback_colors[type] or feedback_colors.info

    -- Desenha notificação com cor apropriada
    love.graphics.setColor(unpack(bg_color))
    love.graphics.rectangle("fill", x, y, width, height)

    -- Texto sempre legível (branco)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(message, x + 10, y + 10)
end

-- ========== 6. CONVERSÃO REVERSA ==========

-- Se você tem cores em formato LÖVE e quer o HEX
local existing_color = { 0.8, 0.2, 0.2, 1.0 }
local hex_version = colors.toHex(existing_color) -- "#CC3333"

print("A cor vermelha é: " .. hex_version)       -- Para documentação

-- ========== 7. MIGRANDO CORES EXISTENTES ==========

-- Identifique cores no seu código atual e converta:

-- ANTES
local old_colors = {
    hp_bar = { 0.7, 0.2, 0.2, 1.0 }, -- ❌ Difícil de ajustar
    mp_bar = { 0.2, 0.4, 0.8, 1.0 }, -- ❌ Que azul é esse?
    xp_bar = { 0.3, 0.6, 1.0, 1.0 }, -- ❌ Muito claro? Muito escuro?
}

-- DEPOIS (converta usando uma ferramenta online ou calculando)
local new_colors = {
    hp_bar = colors.hex("#B33333"), -- ✅ Vermelho escuro - vejo na IDE!
    mp_bar = colors.hex("#3366CC"), -- ✅ Azul médio - perfeito!
    xp_bar = colors.hex("#4D99FF"), -- ✅ Azul claro - exactly!
}

-- ========== 8. EXEMPLO REAL: PAINEL DE INVENTÁRIO ==========

function InventoryPanel:draw()
    -- Cores definidas com HEX - fáceis de ajustar e visualizar
    local panel_bg = colors.hex("#1E1E1E", 0.9)   -- Cinza escuro
    local slot_empty = colors.hex("#2D2D30", 0.8) -- Cinza médio
    local slot_hover = colors.hex("#3E3E42", 0.9) -- Cinza claro
    local border_color = colors.hex("#404040")    -- Cinza da borda
    local text_color = colors.hex("#FFFFFF")      -- Branco puro

    -- Desenha fundo do painel
    love.graphics.setColor(unpack(panel_bg))
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

    -- Desenha slots
    for i, slot in ipairs(self.slots) do
        local slot_color = slot.hovered and slot_hover or slot_empty
        love.graphics.setColor(unpack(slot_color))
        love.graphics.rectangle("fill", slot.x, slot.y, slot.size, slot.size)

        -- Borda
        love.graphics.setColor(unpack(border_color))
        love.graphics.rectangle("line", slot.x, slot.y, slot.size, slot.size)

        -- Item (se houver)
        if slot.item then
            -- Cor baseada na raridade
            local item_color = rarity_colors[slot.item.rarity]
            love.graphics.setColor(unpack(item_color))
            love.graphics.rectangle("fill", slot.x + 2, slot.y + 2, slot.size - 4, slot.size - 4)
        end
    end
end

-- ========== VANTAGENS DEMONSTRADAS ==========

--[[
✅ ANTES: { 0.2, 0.5, 0.8, 1.0 }
   - Que cor é essa? Preciso rodar o jogo para ver
   - Difícil de ajustar
   - Sem contexto visual

✅ DEPOIS: colors.hex("#3380CC")
   - Vejo a cor azul diretamente na IDE!
   - Copio direto do Photoshop/Figma
   - Fácil de documentar e ajustar

✅ PALETAS:
   - Cores organizadas por tema
   - Fácil manutenção
   - Consistência visual

✅ VARIAÇÕES:
   - Estados de hover/pressed automáticos
   - Gradientes harmoniosos
   - Menos código manual
--]]

return {
    solo_leveling_theme = solo_leveling_theme,
    blue_theme = blue_theme,
    rarity_colors = rarity_colors,
    feedback_colors = feedback_colors,
}
