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

    -- Definições para as decorações do mapa, agora usando um sistema de layers.
    -- As layers são renderizadas na ordem em que aparecem na lista.
    decorations = {
        layers = {
            --- Grama por cima do chão
            {
                id = "bush_cluster_layer",
                placement = "clustered",
                cluster_scale = 20,
                cluster_density = 0.7,
                cluster_threshold = 0.6,
                types = {
                    {
                        id = "bush_type_1",
                        affectedByWind = false,
                        variants = {
                            { path = "assets/tilesets/forest/tiles/Flora B1_E.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B1_S.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B1_W.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B1_N.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B2_E.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B2_S.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B2_W.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B2_N.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B3_E.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B3_S.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B3_W.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B3_N.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B4_E.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B4_S.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B4_W.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B4_N.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B5_E.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B5_S.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B5_W.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B5_N.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B6_E.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B6_S.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B6_W.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B6_N.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B7_E.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B7_S.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B7_W.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B7_N.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B8_E.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B8_S.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B8_W.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B8_N.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B9_E.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B9_S.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B9_W.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B9_N.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B10_E.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B10_S.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B10_W.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B10_N.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B11_E.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B11_S.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B11_W.png" },
                            { path = "assets/tilesets/forest/tiles/Flora B11_N.png" },
                        }
                    }
                }
            },
            -- Arbustos por cima da grama
            {
                id = "ground_cover_layer",
                placement = "clustered",
                cluster_scale = 10,
                cluster_density = 0.2,
                cluster_threshold = 0.2,
                types = {
                    {
                        id = "bush_type_2",
                        affectedByWind = true,
                        variants = {
                            { name = "E", path = "assets/tilesets/forest/tiles/Flora A3_E.png" },
                            { name = "S", path = "assets/tilesets/forest/tiles/Flora A3_S.png" },
                            { name = "W", path = "assets/tilesets/forest/tiles/Flora A3_W.png" },
                            { name = "N", path = "assets/tilesets/forest/tiles/Flora A3_N.png" },
                        }
                    },
                    {
                        id = "bush_type_3",
                        affectedByWind = true,
                        variants = {
                            { name = "E", path = "assets/tilesets/forest/tiles/Flora A7_E.png" },
                            { name = "S", path = "assets/tilesets/forest/tiles/Flora A7_S.png" },
                            { name = "W", path = "assets/tilesets/forest/tiles/Flora A7_W.png" },
                            { name = "N", path = "assets/tilesets/forest/tiles/Flora A7_N.png" },
                        }
                    }
                }
            },
            -- Layer 3: Árvores aleatórias.
            {
                id = "tree_layer",
                placement = "random",
                density = 0.01, -- Chance de 5% de uma árvore aparecer em qualquer tile.
                types = {
                    {
                        id = "tree_type_1",
                        affectedByWind = true, -- As copas podem balançar
                        variants = {
                            { name = "E", path = "assets/tilesets/forest/tiles/Tree A9_E.png" },
                            { name = "N", path = "assets/tilesets/forest/tiles/Tree A9_N.png" },
                            { name = "S", path = "assets/tilesets/forest/tiles/Tree A9_S.png" },
                            { name = "W", path = "assets/tilesets/forest/tiles/Tree A9_W.png" },
                        }
                    }
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
