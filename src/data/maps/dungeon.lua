-- Configuração para o mapa da floresta.
-- Este arquivo define os elementos que compõem o mapa da floresta,
-- como os tiles do chão, decorações, e outras propriedades.

local map_data = {
    name = "Dungeon",

    -- Definições para a camada do chão (ground)
    ground = {
        -- Por enquanto, estamos usando um único tile para todo o chão.
        -- O caractere '@' pode ser um identificador que será resolvido pelo sistema de mapas.
        tile = "assets/tilesets/dungeon/tiles/Ground A1_E.png",
    },

    -- Definições para as decorações do mapa, agora usando um sistema de layers.
    -- As layers são renderizadas na ordem em que aparecem na lista.
    decorations = {
        layers = {
            --- Grama por cima do chão
            {
                id = "bush_cluster_layer",
                placement = "clustered",
                cluster_scale = 25,
                cluster_density = 0.7,
                cluster_threshold = 0.6,
                types = {
                    {
                        id = "bush_type_1",
                        affectedByWind = false,
                        variants = {
                            { path = "assets/tilesets/dungeon/tiles/Flora B8_E.png" },
                            { path = "assets/tilesets/dungeon/tiles/Flora B8_S.png" },
                            { path = "assets/tilesets/dungeon/tiles/Flora B8_W.png" },
                            { path = "assets/tilesets/dungeon/tiles/Flora B8_N.png" },
                            { path = "assets/tilesets/dungeon/tiles/Flora B9_E.png" },
                            { path = "assets/tilesets/dungeon/tiles/Flora B9_S.png" },
                            { path = "assets/tilesets/dungeon/tiles/Flora B9_W.png" },
                            { path = "assets/tilesets/dungeon/tiles/Flora B9_N.png" },
                            { path = "assets/tilesets/dungeon/tiles/Flora B10_E.png" },
                            { path = "assets/tilesets/dungeon/tiles/Flora B10_S.png" },
                            { path = "assets/tilesets/dungeon/tiles/Flora B10_W.png" },
                            { path = "assets/tilesets/dungeon/tiles/Flora B10_N.png" },
                            { path = "assets/tilesets/dungeon/tiles/Flora B11_E.png" },
                            { path = "assets/tilesets/dungeon/tiles/Flora B11_S.png" },
                            { path = "assets/tilesets/dungeon/tiles/Flora B11_W.png" },
                            { path = "assets/tilesets/dungeon/tiles/Flora B11_N.png" },
                        }
                    }
                }
            },
            -- Arbustos por cima da grama
            {
                id = "ground_cover_layer",
                placement = "clustered",
                cluster_scale = 1,
                cluster_density = 0.02,
                cluster_threshold = 0.05,
                types = {

                    {
                        id = "bush_type_4",
                        affectedByWind = false,
                        variants = {
                            { name = "E", path = "assets/tilesets/dungeon/tiles/Pillar A6_E.png" },
                            { name = "S", path = "assets/tilesets/dungeon/tiles/Pillar A6_S.png" },
                            { name = "W", path = "assets/tilesets/dungeon/tiles/Pillar A6_W.png" },
                            { name = "N", path = "assets/tilesets/dungeon/tiles/Pillar A6_N.png" },
                        }
                    }
                }
            },
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
