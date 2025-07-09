---@class ArtefactDrop
---@field type string Tipo do drop (sempre "artefact")
---@field artefactId string ID do artefato
---@field chance number? Chance de drop (0-100)
---@field amount { min: number, max: number }? Quantidade mínima e máxima (padrão: 1)

---@class ArtefactDropTable
---@field normal table<string, ArtefactDrop[]> Drops normais (guaranteed e chance)
---@field mvp table<string, ArtefactDrop[]> Drops de MVP (guaranteed e chance)

-- Configurações de drops de artefatos para diferentes tipos de inimigos
---@type table<string, ArtefactDropTable>
local artefact_drops = {
    -- Zombies básicos (Walkers)
    zombie_walker = {
        normal = {
            guaranteed = {},
            chance = {
                {
                    type = "artefact",
                    artefactId = "empty_stone",
                    chance = 25,                  -- 25% de chance
                    amount = { min = 1, max = 2 } -- 1-2 pedras
                },
                {
                    type = "artefact",
                    artefactId = "crystal_fragment",
                    chance = 5 -- 15% de chance
                },
            }
        },
        mvp = {
            guaranteed = {
                {
                    type = "artefact",
                    artefactId = "unstable_core",
                    amount = { min = 1, max = 1 }
                }
            },
            chance = {
                {
                    type = "artefact",
                    artefactId = "putrefied_core",
                    chance = 20,
                    amount = { min = 1, max = 10 } -- 1-10 núcleos
                }
            }
        }
    },

    -- Zombies corredores (Runners) - mais rápidos, drops ligeiramente melhores
    zombie_runner = {
        normal = {
            guaranteed = {},
            chance = {
                {
                    type = "artefact",
                    artefactId = "crystal_fragment",
                    chance = 20,                  -- 20% de chance
                    amount = { min = 2, max = 5 } -- 1-3 fragmentos
                },
                {
                    type = "artefact",
                    artefactId = "putrefied_core",
                    chance = 10,                  -- 10% de chance de cristal
                    amount = { min = 1, max = 3 } -- 1-10 núcleos
                },
            }
        },
        mvp = {
            guaranteed = {
                {
                    type = "artefact",
                    artefactId = "unstable_core",
                    amount = { min = 1, max = 3 }
                }
            },
            chance = {
                {
                    type = "artefact",
                    artefactId = "putrefied_core",
                    chance = 20,                   -- 2% de chance de artefato S
                    amount = { min = 3, max = 15 } -- 1-10 núcleos
                }
            }
        }
    },
}

return artefact_drops
