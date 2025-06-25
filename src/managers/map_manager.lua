-- Gerencia o carregamento e o acesso aos dados de configuração dos mapas.

---@class MapManager
---@field maps table<string, table> Cache para os dados dos mapas carregados
local MapManager = {}
MapManager.maps = {} -- Cache para os dados dos mapas carregados

--- Carrega os dados de configuração de um mapa.
-- @param mapName (string) O nome do arquivo do mapa a ser carregado (ex: "florest").
-- @return (table|nil) A tabela com os dados do mapa se for bem-sucedido, ou nil se falhar.
function MapManager:loadMap(mapName)
    if not mapName then
        error("MapManager:loadMap - mapName não pode ser nulo.")
    end

    -- Se o mapa já estiver carregado, retorna a partir do cache.
    if self.maps[mapName] then
        return self.maps[mapName]
    end

    local path = "src.data.maps." .. mapName
    local ok, mapData = pcall(require, path)

    if ok then
        Logger:info("Mapa '" .. mapName .. "' carregado com sucesso.")
        self.maps[mapName] = mapData
        return mapData
    else
        error("Falha ao carregar o mapa: " .. path)
        return nil
    end
end

--- Retorna os dados de configuração de um mapa já carregado.
--- @param mapName (string) O nome do mapa.
--- @return table mapData Os dados do mapa se estiver carregado
function MapManager:getMapData(mapName)
    if not self.maps[mapName] then
        error("Tentativa de acessar dados do mapa '" .. mapName .. "' que não foi carregado.")
    end
    return self.maps[mapName]
end

return MapManager
