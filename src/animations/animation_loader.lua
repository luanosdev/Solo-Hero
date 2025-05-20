-- Módulo centralizado para carregar animações de inimigos e bosses
local SpritePlayer = require("src.animations.sprite_player")
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local EnemyData = require("src.data.enemies") -- Necessário para buscar as configs dos units

local AnimationLoader = {}

--- Carrega animações que são sempre necessárias no início do jogo, como as do jogador.
function AnimationLoader.loadInitial()
    SpritePlayer.load() -- Assumindo que SpritePlayer.load() carrega as animações do jogador
    print("AnimationLoader: loadInitial completado (ex: Player).")
end

--- Carrega animações para tipos de unidade específicos.
--- Utiliza AnimatedSpritesheet para unidades configuradas em src/data/enemies/*.lua
--- @param unitTypes table: Uma lista de strings, cada string sendo um unitType (ex: {"zombie_walker_male_1", "skeleton"}).
function AnimationLoader.loadUnits(unitTypes)
    if not unitTypes or #unitTypes == 0 then
        print("AnimationLoader:loadUnits - Nenhuma unitType fornecida para carregamento.")
        return
    end

    print(string.format("AnimationLoader:loadUnits - Solicitado carregamento para: %s", table.concat(unitTypes, ", ")))

    for _, unitTypeString in ipairs(unitTypes) do
        local configForUnit = EnemyData[unitTypeString]

        if configForUnit then
            -- Verifica se a configuração parece ser para AnimatedSpritesheet (possui assetPaths)
            -- E se as animações para este unitType ainda não foram carregadas.
            if configForUnit.assetPaths and not AnimatedSpritesheet.assets[unitTypeString] then
                print(string.format("  Carregando animações para unitType '%s' via AnimatedSpritesheet...",
                    unitTypeString))
                AnimatedSpritesheet.load(unitTypeString, configForUnit)
            elseif AnimatedSpritesheet.assets[unitTypeString] then
                print(string.format("  Animações para unitType '%s' já carregadas.", unitTypeString))
            elseif not configForUnit.assetPaths then
                print(string.format(
                    "  AVISO [AnimationLoader]: Configuração para unitType '%s' existe em EnemyData, mas não parece ser para AnimatedSpritesheet (falta assetPaths).",
                    unitTypeString))
            end
        else
            print(string.format(
                "  AVISO [AnimationLoader]: Nenhuma configuração encontrada em EnemyData para unitType '%s'. Animações não carregadas.",
                unitTypeString))
        end
    end
    print("AnimationLoader:loadUnits concluído.")
end

return AnimationLoader
