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
        -- Densidade global, pode ser usada como um fallback se uma decoração não tiver densidade própria.
        global_density = 0.05,

        -- Definição dos tipos de decorações
        types = {
            {
                id = "bush_type_1",
                affectedByWind = true, -- Esta decoração é afetada pelo vento.
                density = 0.03,        -- Chance de 3% de aparecer em um tile.
                variants = {
                    -- Lista de variações de imagem para esta decoração.
                    { name = "E", path = "assets/tilesets/forest/tiles/Flora A1_E.png" },
                    { name = "S", path = "assets/tilesets/forest/tiles/Flora A1_S.png" },
                    { name = "W", path = "assets/tilesets/forest/tiles/Flora A1_W.png" },
                    { name = "N", path = "assets/tilesets/forest/tiles/Flora A1_N.png" },
                    -- Adicionar outras direções (N, S, W) aqui se existirem
                }
            },
            {
                id = "bush_type_2",
                affectedByWind = true, -- Um arbusto baixo que não é afetado pelo vento.
                density = 0.02,        -- Chance de 2% de aparecer.
                variants = {
                    { name = "E", path = "assets/tilesets/forest/tiles/Flora A2_E.png" },
                    { name = "S", path = "assets/tilesets/forest/tiles/Flora A2_S.png" },
                    { name = "W", path = "assets/tilesets/forest/tiles/Flora A2_W.png" },
                    { name = "N", path = "assets/tilesets/forest/tiles/Flora A2_N.png" },
                }
            },
            {
                id = "bush_type_3",
                affectedByWind = false, -- Um arbusto baixo que não é afetado pelo vento.
                density = 0.01,         -- Chance de 1% de aparecer.
                variants = {
                    { name = "E", path = "assets/tilesets/forest/tiles/Flora A19_E.png" },
                    { name = "S", path = "assets/tilesets/forest/tiles/Flora A19_S.png" },
                    { name = "W", path = "assets/tilesets/forest/tiles/Flora A19_W.png" },
                    { name = "N", path = "assets/tilesets/forest/tiles/Flora A19_N.png" },
                }
            }
        }
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
