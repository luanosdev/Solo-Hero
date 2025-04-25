--- src/utils/formatters.lua
-- Módulo contendo funções utilitárias para formatação de dados.

local Formatters = {}

--- Formata o tempo em segundos para o formato MM:SS.
---@param seconds number Tempo total em segundos.
---@return string Tempo formatado como "MM:SS".
function Formatters.formatTime(seconds)
    seconds = math.max(0, math.floor(seconds or 0)) -- Garante que seja número >= 0
    local min = math.floor(seconds / 60)
    local sec = seconds % 60
    return string.format("%02d:%02d", min, sec)
end

-- Adicionar outras funções de formatação aqui no futuro, se necessário.

return Formatters
