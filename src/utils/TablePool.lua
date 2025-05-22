---@class TablePool
local TablePool = {}

--- O pool em si, armazenará listas de tabelas por "tipo" (embora aqui seja genérico)
--- No nosso caso, todas as tabelas serão "genéricas"
local pool = {} 
local pooledCount = 0
local maxPooledTables = 200 -- Limite para não consumir memória demais com tabelas não usadas

--- Estatísticas (opcional, para debug)
local stats = {
    getRequests = 0,
    newCreations = 0,
    releaseRequests = 0,
    poolHits = 0,
    poolMisses = 0
}

--- Retorna uma tabela do pool ou cria uma nova se o pool estiver vazio.
--- @return table Uma tabela limpa (vazia).
function TablePool.get()
    stats.getRequests = stats.getRequests + 1
    if pooledCount > 0 then
        local tbl = pool[pooledCount]
        pool[pooledCount] = nil -- Remove do pool efetivamente
        pooledCount = pooledCount - 1
        stats.poolHits = stats.poolHits + 1
        return tbl
    else
        stats.newCreations = stats.newCreations + 1
        stats.poolMisses = stats.poolMisses + 1
        return {}
    end
end

--- Retorna uma tabela ao pool para reutilização.
--- A tabela é limpa (todos os pares chave-valor são removidos).
--- @param tbl table A tabela a ser retornada ao pool.
function TablePool.release(tbl)
    if not tbl then return end
    stats.releaseRequests = stats.releaseRequests + 1

    -- Limpa a tabela (remove todas as chaves)
    for k, _ in pairs(tbl) do
        tbl[k] = nil
    end

    if pooledCount < maxPooledTables then
        pooledCount = pooledCount + 1
        pool[pooledCount] = tbl
    else
        -- Opcional: Logar que o pool está cheio, ou simplesmente descartar a tabela
        -- print("AVISO [TablePool]: Pool cheio, descartando tabela.")
    end
end

--- Retorna estatísticas de uso do pool (para debug).
--- @return table Tabela com estatísticas.
function TablePool.getStats()
    local currentStats = {
        getRequests = stats.getRequests,
        newCreations = stats.newCreations,
        releaseRequests = stats.releaseRequests,
        poolHits = stats.poolHits,
        poolMisses = stats.poolMisses,
        currentlyPooled = pooledCount,
        maxPoolSize = maxPooledTables
    }
    return currentStats
end

--- Reseta as estatísticas do pool.
function TablePool.resetStats()
    stats.getRequests = 0
    stats.newCreations = 0
    stats.releaseRequests = 0
    stats.poolHits = 0
    stats.poolMisses = 0
    -- Não reseta pooledCount nem o pool em si, apenas as métricas de requisição
end

return TablePool 