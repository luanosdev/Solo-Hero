-- Configuração para o mapa da floresta.
-- Este arquivo define os elementos que compõem o mapa da floresta,
-- como os tiles do chão, decorações, e outras propriedades.

local map_data = {
    name = "Floresta",

    -- Definições para a camada do chão (ground)
    ground = {
        -- Por enquanto, estamos usando um único tile para todo o chão.
        -- O caractere '@' pode ser um identificador que será resolvido pelo sistema de mapas.
        tile = "assets/tilesets/forest/tiles/Ground G1_E.png",
    },

    -- Futuramente, poderemos adicionar mais camadas, como decorações, inimigos, etc.
    -- decorations = {
    --     ...
    -- },
    -- enemies = {
    --     ...
    -- }
}

return map_data
