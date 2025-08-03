--------------------------------------------------------------------------------
-- Contém os dados de configuração para o efeito visual de level up.
--------------------------------------------------------------------------------

local Colors = require("src.ui.colors")

---@class LevelUpEffectData
local LevelUpData = {
    -- Caminhos para os assets visuais do efeito.
    baseImagePath = "assets/effects/teleporter-effect-var-5.png",
    overlayImagePath = "assets/effects/teleporter-effect-var-5-overlay.png",

    -- Configuração da spritesheet de animação.
    grid = {
        columns = 10,
        rows = 10,
    },

    -- Controle de tempo da animação.
    frameDuration = 0.01, -- Duração de cada frame em segundos.

    -- Propriedades visuais do efeito.
    tint = Colors.solo_leveling.portal_purple,

    -- Propriedades visuais do overlay (camada adicional).
    overlayTint = Colors.solo_leveling.portal_purple,
}

return LevelUpData
