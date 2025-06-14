--- @class ItemGridLogic
local ItemGridLogic = {}

--- Verifica se uma área retangular está completamente livre em uma grade.
---@param grid table A grade 2D onde verificar (grid[row][col] contém instanceId ou nil).
---@param rows number Número total de linhas da grade.
---@param cols number Número total de colunas da grade.
---@param startRow number Linha inicial da área (1-indexed).
---@param startCol number Coluna inicial da área (1-indexed).
---@param width number Largura da área (em slots).
---@param height number Altura da área (em slots).
---@return boolean True se a área estiver completamente livre e dentro dos limites.
function ItemGridLogic.isAreaFree(grid, rows, cols, startRow, startCol, width, height)
    -- Verifica limites básicos
    if startRow < 1 or startCol < 1 or startRow + height - 1 > rows or startCol + width - 1 > cols then
        return false
    end
    -- Verifica cada célula na área
    for r = startRow, startRow + height - 1 do
        -- Garante que a linha exista na grade antes de acessar colunas
        if not grid[r] then
            -- Se a linha nem existe, a área não pode estar ocupada nela (consideramos livre)
            -- No entanto, se a verificação de limites acima passou, isso indica uma grade 'esparsa'.
            -- Para simplificar, vamos assumir que se a linha não existe, está livre.
        else
            for c = startCol, startCol + width - 1 do
                -- Se a célula na linha existe e não é nil, está ocupada
                if grid[r][c] ~= nil then
                    return false
                end
            end
        end
    end
    return true -- Nenhuma célula ocupada encontrada
end

--- Encontra o primeiro espaço livre retangular em uma grade que comporte as dimensões dadas.
---@param grid table A grade 2D.
---@param rows number Número total de linhas da grade.
---@param cols number Número total de colunas da grade.
---@param width number Largura do espaço necessário.
---@param height number Altura do espaço necessário.
---@return table|nil Posição {row, col} do canto superior esquerdo do espaço livre, ou nil se não encontrar.
function ItemGridLogic.findFreeSpace(grid, rows, cols, width, height)
    -- Itera pelas possíveis posições de início (r, c)
    for r = 1, rows - height + 1 do
        for c = 1, cols - width + 1 do
            -- Usa isAreaFree para verificar se o espaço a partir daqui está livre
            if ItemGridLogic.isAreaFree(grid, rows, cols, r, c, width, height) then
                return { row = r, col = c } -- Encontrou espaço, retorna coordenadas
            end
        end
    end
    return nil -- Nenhum espaço livre encontrado
end

--- Verifica se um item PODE ser colocado em uma posição alvo, considerando colisões.
--- Esta função é usada ANTES de mover/adicionar, tipicamente durante o drag para validação.
---@param grid table A grade 2D onde verificar.
---@param rows number Número total de linhas da grade.
---@param cols number Número total de colunas da grade.
---@param itemInstanceId number|nil O ID da instância do item sendo verificado (se aplicável, para evitar colisões consigo mesmo em cenários de swap futuros, embora não usado na lógica atual).
---@param targetRow integer Linha alvo (1-indexed).
---@param targetCol integer Coluna alvo (1-indexed).
---@param checkWidth integer Largura a ser usada para a checagem.
---@param checkHeight integer Altura a ser usada para a checagem.
---@return boolean True se o item pode ser colocado, false caso contrário.
function ItemGridLogic.canPlaceItemAt(grid, rows, cols, itemInstanceId, targetRow, targetCol, checkWidth, checkHeight)
    -- 1. Verifica limites da grade para a área de checagem
    if targetRow < 1 or targetCol < 1 or targetRow + checkHeight - 1 > rows or targetCol + checkWidth - 1 > cols then
        return false -- Fora dos limites da grade
    end

    -- 2. Verifica colisão com outros itens na grade
    for r = targetRow, targetRow + checkHeight - 1 do
        for c = targetCol, targetCol + checkWidth - 1 do
            -- Se a célula existe e não é nil, está ocupada.
            -- A lógica atual simplificada não precisa verificar itemInstanceId.
            if grid[r] and grid[r][c] ~= nil then
                return false -- Já ocupado
            end
        end
    end

    return true -- Espaço livre e dentro dos limites
end

--- Marca as células da grade como ocupadas por uma instância de item.
---@param grid table A grade 2D a ser modificada.
---@param rows number Número total de linhas da grade (para verificação de limites).
---@param cols number Número total de colunas da grade (para verificação de limites).
---@param instanceId number O ID da instância que está ocupando as células.
---@param startRow integer Linha inicial da área (1-indexed).
---@param startCol integer Coluna inicial da área (1-indexed).
---@param width integer Largura da área a marcar.
---@param height integer Altura da área a marcar.
function ItemGridLogic.markGridOccupied(grid, rows, cols, instanceId, startRow, startCol, width, height)
    for r = startRow, startRow + height - 1 do
        for c = startCol, startCol + width - 1 do
            -- Garante que a linha exista
            if grid[r] == nil then grid[r] = {} end
            -- Verifica limites antes de marcar
            if r >= 1 and r <= rows and c >= 1 and c <= cols then
                if grid[r][c] ~= nil and grid[r][c] ~= instanceId then
                    -- Isso não deveria acontecer se canPlaceItemAt foi chamado antes,
                    -- mas é um log de segurança.
                    print(string.format(
                        "AVISO (markGridOccupied): Célula [%d,%d] já estava ocupada por ID %s ao tentar marcar para ID %s!",
                        r, c, tostring(grid[r][c]), tostring(instanceId)))
                end
                grid[r][c] = instanceId
            else
                print(string.format(
                    "AVISO (markGridOccupied): Tentativa de marcar célula fora dos limites [%d,%d] para item %s", r, c,
                    tostring(instanceId)))
            end
        end
    end
end

--- Limpa (define como nil) as células da grade ocupadas por uma instância de item.
---@param grid table A grade 2D a ser modificada.
---@param rows number Número total de linhas da grade (para verificação de limites).
---@param cols number Número total de colunas da grade (para verificação de limites).
---@param instanceId number O ID da instância cujas células devem ser limpas.
---@param startRow integer Linha inicial da área (1-indexed).
---@param startCol integer Coluna inicial da área (1-indexed).
---@param width integer Largura da área a limpar.
---@param height integer Altura da área a limpar.
function ItemGridLogic.clearGridArea(grid, rows, cols, instanceId, startRow, startCol, width, height)
    for r = startRow, startRow + height - 1 do
        for c = startCol, startCol + width - 1 do
            -- Verifica limites e se a linha existe
            if r >= 1 and r <= rows and c >= 1 and c <= cols and grid[r] then
                -- Limpa apenas se a célula pertence à instância correta
                if grid[r][c] == instanceId then
                    grid[r][c] = nil
                elseif grid[r][c] ~= nil then
                    -- Log se tentou limpar célula ocupada por outro item (inesperado)
                    print(string.format(
                        "AVISO (clearGridArea): Tentativa de limpar célula [%d,%d] que não pertencia ao item %s (pertencia a %s?)",
                        r, c, tostring(instanceId), tostring(grid[r][c])))
                end
                -- else
                -- Não precisa logar se a célula está fora dos limites ou a linha não existe, apenas ignora.
            end
        end
    end
end

return ItemGridLogic
