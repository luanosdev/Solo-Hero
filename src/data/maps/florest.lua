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

    -- Definições para as decorações do mapa
    decorations = {
        -- Lista de possíveis tiles de decoração
        tiles = {
            "assets/tilesets/forest/tiles/Flora A1_E.png",
            "assets/tilesets/forest/tiles/Flora A2_E.png",
        },
        -- Densidade: um valor entre 0 (nenhuma) e 1 (todas) que controla
        -- a chance de um tile ter uma decoração.
        density = 0.05, -- 5% de chance
    }

    -- Futuramente, poderemos adicionar mais camadas, como decorações, inimigos, etc.
    -- decorations = {
    --     ...
    -- },
    -- enemies = {
    --     ...
    -- }
}

return map_data
