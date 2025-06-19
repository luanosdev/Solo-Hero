-- Módulo centralizado para carregar animações de inimigos e bosses
local SpritePlayer = require("src.animations.sprite_player")
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local EnemyData = require("src.data.enemies") -- Necessário para buscar as configs dos units
local BossData = require("src.data.bosses")   -- Necessário para buscar as configs dos bosses

local AnimationLoader = {}

--- Carrega animações que são sempre necessárias no início do jogo, como as do jogador.
function AnimationLoader.loadInitial()
    SpritePlayer.load() -- Assumindo que SpritePlayer.load() carrega as animações do jogador
    Logger.info("[AnimationLoader:loadInitial]", "Completado (ex: Player).")
end

--- Carrega animações para tipos de unidade específicos.
--- Utiliza AnimatedSpritesheet para unidades configuradas em src/data/enemies/*.lua
--- @param unitTypes table: Uma lista de strings, cada string sendo um unitType (ex: {"zombie_walker_male_1", "skeleton"}).
function AnimationLoader.loadUnits(unitTypes)
    if not unitTypes or #unitTypes == 0 then
        Logger.warn("[AnimationLoader:loadUnits]", "Nenhuma unitType fornecida para carregamento.")
        return
    end

    Logger.info(
        "[AnimationLoader:loadUnits]",
        string.format("Solicitado carregamento para: %s", table.concat(unitTypes, ", "))
    )

    for _, unitTypeString in ipairs(unitTypes) do
        local configForUnit = EnemyData[unitTypeString] or BossData[unitTypeString]

        if configForUnit then
            -- Verifica se a configuração parece ser para AnimatedSpritesheet (possui assetPaths)
            -- E se as animações para este unitType ainda não foram carregadas.
            if configForUnit.assetPaths and not AnimatedSpritesheet.assets[unitTypeString] then
                Logger.debug(
                    "[AnimationLoader:loadUnits]",
                    string.format("Carregando animações para unitType '%s' via AnimatedSpritesheet...", unitTypeString)
                )
                AnimatedSpritesheet.load(unitTypeString, configForUnit)
            elseif AnimatedSpritesheet.assets[unitTypeString] then
                Logger.debug(
                    "[AnimationLoader:loadUnits]",
                    string.format("Animações para unitType '%s' já carregadas.", unitTypeString)
                )
            elseif not configForUnit.assetPaths then
                Logger.warn(
                    "[AnimationLoader:loadUnits]",
                    string.format(
                        "Configuração para unitType '%s' existe em EnemyData, mas não parece ser para AnimatedSpritesheet (falta assetPaths).",
                        unitTypeString
                    )
                )
            end
        else
            Logger.warn(
                "[AnimationLoader:loadUnits]",
                string.format(
                    "Nenhuma configuração encontrada em EnemyData para unitType '%s'. Animações não carregadas.",
                    unitTypeString
                )
            )
        end
    end
    Logger.info("[AnimationLoader:loadUnits]", "Concluído.")
end

return AnimationLoader
