local TablePool = require("src.utils.table_pool")
local MathUtils = require("src.utils.math_utils") -- Adicionado

---@class SpatialGridIncremental
---@field gridWidth number Largura do grid em células (para wrapping).
---@field gridHeight number Altura do grid em células (para wrapping).
---@field cellWidth number Largura das células do grid.
---@field cellHeight number Altura das células do grid.
---@field numCols number Número de colunas do grid físico.
---@field numRows number Número de linhas do grid físico.
---@field isInfinite boolean True se o grid for infinito com wrapping.
---@field worldPixelWidth number Largura total do mundo em pixels (para cálculos toroidais).
---@field worldPixelHeight number Altura total do mundo em pixels (para cálculos toroidais).
local SpatialGridIncremental = {}
SpatialGridIncremental.__index = SpatialGridIncremental

--- Cria um novo grid espacial infinito.
---@param gridWidth number Largura do grid em células (para wrapping)
---@param gridHeight number Altura do grid em células (para wrapping)
---@param cellWidth number Largura de cada célula em pixels
---@param cellHeight number Altura de cada célula em pixels
---@param isInfinite boolean|nil Se true, usa wrapping infinito (padrão: true)
---@return SpatialGridIncremental
function SpatialGridIncremental:new(gridWidth, gridHeight, cellWidth, cellHeight, isInfinite)
    local instance = setmetatable({}, SpatialGridIncremental)
    instance.gridWidth = gridWidth
    instance.gridHeight = gridHeight
    instance.cellWidth = cellWidth
    instance.cellHeight = cellHeight
    instance.numCols = gridWidth
    instance.numRows = gridHeight
    instance.isInfinite = isInfinite ~= false -- Default true
    instance.grid = TablePool.getArray()

    -- Inicializa o grid físico
    for i = 1, instance.numCols do
        instance.grid[i] = TablePool.getArray()
        for j = 1, instance.numRows do
            instance.grid[i][j] = TablePool.getArray()
        end
    end

    -- Armazena as dimensões do mundo em pixels para cálculos de distância toroidal
    instance.worldPixelWidth = gridWidth * cellWidth
    instance.worldPixelHeight = gridHeight * cellHeight

    Logger.debug(
        "spatial_grid_incremental.new.created",
        string.format("SpatialGridIncremental criado: %d x %d cells (%dx%d) - Infinito: %s",
            instance.numCols, instance.numRows, cellWidth, cellHeight, tostring(instance.isInfinite))
    )
    return instance
end

--- Converte coordenadas de mundo para coordenadas de grid, aplicando wrapping se necessário.
---@param worldX number Coordenada X no mundo
---@param worldY number Coordenada Y no mundo
---@return number, number Coluna e linha do grid (1-indexed)
function SpatialGridIncremental:getGridCoords(worldX, worldY)
    local col = math.floor(worldX / self.cellWidth) + 1
    local row = math.floor(worldY / self.cellHeight) + 1

    if self.isInfinite then
        -- Aplica wrapping usando módulo para coordenadas infinitas
        col = ((col - 1) % self.numCols) + 1
        row = ((row - 1) % self.numRows) + 1

        -- Garante valores positivos para números negativos
        if col <= 0 then col = col + self.numCols end
        if row <= 0 then row = row + self.numRows end
    else
        -- Clamp para grid finito (compatibilidade)
        col = math.max(1, math.min(self.numCols, col))
        row = math.max(1, math.min(self.numRows, row))
    end

    return col, row
end

--- Adiciona a entidade a TODAS as células que seu raio toca.
--- Usado internamente por updateEntityInGrid.
---@param entity BaseEnemy A entidade a ser adicionada
function SpatialGridIncremental:_addEntityToOccupiedCells(entity)
    if not entity or not entity.position then return end
    entity.radius = entity.radius or 0

    local minCol, minRow = self:getGridCoords(entity.position.x - entity.radius, entity.position.y - entity.radius)
    local maxCol, maxRow = self:getGridCoords(entity.position.x + entity.radius, entity.position.y + entity.radius)

    -- Libera a tabela antiga se existir
    if entity.currentGridCells then
        TablePool.releaseGeneric(entity.currentGridCells)
    end
    entity.currentGridCells = TablePool.getGeneric()

    -- Para grid infinito, precisa calcular o range de células de forma diferente
    if self.isInfinite then
        -- Calcula quantas células o raio abrange
        local radiusInCells = math.ceil(entity.radius / math.min(self.cellWidth, self.cellHeight))
        local centerCol, centerRow = self:getGridCoords(entity.position.x, entity.position.y)

        -- Itera em um quadrado ao redor da célula central
        for dr = -radiusInCells, radiusInCells do
            for dc = -radiusInCells, radiusInCells do
                local targetCol = ((centerCol + dc - 1) % self.numCols) + 1
                local targetRow = ((centerRow + dr - 1) % self.numRows) + 1

                -- Garante valores positivos
                if targetCol <= 0 then targetCol = targetCol + self.numCols end
                if targetRow <= 0 then targetRow = targetRow + self.numRows end

                local cell = self.grid[targetCol][targetRow]
                local found = false
                for _, e in ipairs(cell) do
                    if e == entity then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(cell, entity)
                end
                entity.currentGridCells[targetCol .. ":" .. targetRow] = true
            end
        end
    else
        -- Grid finito - usa o comportamento original
        for r = minRow, maxRow do
            for c = minCol, maxCol do
                local cell = self.grid[c][r]
                local found = false
                for _, e in ipairs(cell) do
                    if e == entity then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(cell, entity)
                end
                entity.currentGridCells[c .. ":" .. r] = true
            end
        end
    end
end

--- Remove a entidade de TODAS as células que ela ocupava (baseado em entity.currentGridCells).
--- Usado internamente por updateEntityInGrid e para remoção completa.
---@param entity table A entidade a ser removida
function SpatialGridIncremental:_removeEntityFromOccupiedCells(entity)
    if not entity or not entity.currentGridCells then return end

    for cellKey, _ in pairs(entity.currentGridCells) do
        local parts = TablePool.getArray()
        for part in string.gmatch(cellKey, "([^-:]+)") do
            table.insert(parts, tonumber(part))
        end
        if #parts == 2 then
            local col, row = parts[1], parts[2]
            -- Para grid infinito, todas as coordenadas em currentGridCells são válidas
            local cell = self.grid[col][row]
            if cell then
                for i = #cell, 1, -1 do
                    if cell[i] == entity then
                        table.remove(cell, i)
                    end
                end
            end
        end
        TablePool.releaseArray(parts)
    end
    TablePool.releaseGeneric(entity.currentGridCells)
    entity.currentGridCells = nil
end

--- Atualiza a posição de uma entidade no grid.
--- A entidade só é removida/readicionada se sua CÉLULA PRINCIPAL mudar.
---@param entity BaseEnemy A entidade a ser atualizada
function SpatialGridIncremental:updateEntityInGrid(entity)
    if not entity or not entity.position or not entity.id then
        error("Entidade inválida ou sem posição/id")
    end
    entity.radius = entity.radius or 0

    -- Obtém a célula principal atual da entidade (baseada no seu centro)
    local newMainCol, newMainRow = self:getGridCoords(entity.position.x, entity.position.y)

    if newMainCol ~= entity.lastGridCol or newMainRow ~= entity.lastGridRow then
        -- Célula principal mudou! Precisa remover das células antigas e adicionar às novas.

        -- Remove a entidade de todas as células que ela ocupava anteriormente
        self:_removeEntityFromOccupiedCells(entity)

        -- Adiciona a entidade a todas as células que ela ocupa agora
        self:_addEntityToOccupiedCells(entity)

        -- Atualiza lastGridCol e lastGridRow da entidade
        entity.lastGridCol = newMainCol
        entity.lastGridRow = newMainRow
    else
        -- A célula principal não mudou, mas verificamos se o raio tocou outras células
        local previousCurrentCells = TablePool.getGeneric()
        if entity.currentGridCells then
            for k, v in pairs(entity.currentGridCells) do
                previousCurrentCells[k] = v
            end
        end

        if entity.currentGridCells then
            TablePool.releaseGeneric(entity.currentGridCells)
        end
        entity.currentGridCells = TablePool.getGeneric()

        if self.isInfinite then
            -- Para grid infinito, calcula células com wrapping
            local radiusInCells = math.ceil(entity.radius / math.min(self.cellWidth, self.cellHeight))
            local centerCol, centerRow = newMainCol, newMainRow

            for dr = -radiusInCells, radiusInCells do
                for dc = -radiusInCells, radiusInCells do
                    local targetCol = ((centerCol + dc - 1) % self.numCols) + 1
                    local targetRow = ((centerRow + dr - 1) % self.numRows) + 1

                    if targetCol <= 0 then targetCol = targetCol + self.numCols end
                    if targetRow <= 0 then targetRow = targetRow + self.numRows end

                    local cellKey = targetCol .. ":" .. targetRow
                    entity.currentGridCells[cellKey] = true
                    if not previousCurrentCells[cellKey] then
                        self:_addEntityToCell_Internal(entity, targetCol, targetRow)
                    end
                end
            end
        else
            -- Para grid finito, usa o método original
            local minCol, minRow = self:getGridCoords(
                entity.position.x - entity.radius,
                entity.position.y - entity.radius
            )
            local maxCol, maxRow = self:getGridCoords(
                entity.position.x + entity.radius,
                entity.position.y + entity.radius
            )

            for r = minRow, maxRow do
                for c = minCol, maxCol do
                    local cellKey = c .. ":" .. r
                    entity.currentGridCells[cellKey] = true
                    if not previousCurrentCells[cellKey] then
                        self:_addEntityToCell_Internal(entity, c, r)
                    end
                end
            end
        end

        -- Compara as células novas com as antigas para ver o que mudou
        for oldCellKey, _ in pairs(previousCurrentCells) do
            if not entity.currentGridCells[oldCellKey] then
                -- A entidade não está mais nesta célula, então a removemos
                self:_removeEntityFromCell_Internal(entity, oldCellKey)
            end
        end

        TablePool.releaseGeneric(previousCurrentCells)
    end
end

--- Função auxiliar apenas para adicionar à lista da célula, sem modificar entity.currentGridCells.
---@param entity table A entidade a ser adicionada
---@param col number Coluna da célula
---@param row number Linha da célula
function SpatialGridIncremental:_addEntityToCell_Internal(entity, col, row)
    if self.grid[col] and self.grid[col][row] then
        local cell = self.grid[col][row]
        local found = false
        for _, e in ipairs(cell) do
            if e == entity then
                found = true
                break
            end
        end
        if not found then
            table.insert(cell, entity)
        end
    end
end

--- Função auxiliar apenas para remover da lista da célula.
---@param entity table A entidade a ser removida
---@param col number Coluna da célula
---@param row number Linha da célula
function SpatialGridIncremental:_removeEntityFromCell_Internal(entity, col, row)
    local parts = TablePool.getArray()
    for part in string.gmatch(cellKey, "([^-:]+)") do
        table.insert(parts, tonumber(part))
    end

    if #parts == 2 then
        local col, row = parts[1], parts[2]
        if self.grid[col] and self.grid[col][row] then
            local cell = self.grid[col][row]
            for i = #cell, 1, -1 do
                if cell[i] == entity then
                    table.remove(cell, i)
                end
            end
        end
    end
    TablePool.releaseArray(parts)
end

--- Remove completamente uma entidade do grid (quando ela morre ou é desativada).
---@param entity table A entidade a ser removida completamente
function SpatialGridIncremental:removeEntityCompletely(entity)
    self:_removeEntityFromOccupiedCells(entity)
    entity.lastGridCol = nil
    entity.lastGridRow = nil
end

--- Obtém entidades próximas a uma posição, considerando wrapping infinito se aplicável.
--- ESTA É A FASE AMPLA: Retorna todos os candidatos em células próximas sem verificar a distância exata.
--- A verificação de distância exata (fase estreita) é responsabilidade do chamador.
--- Ao fim da função, a tabela 'nearbyEntities' deve ser liberada com TablePool.releaseArray.
---@param worldX number Coordenada X no mundo
---@param worldY number Coordenada Y no mundo
---@param searchRadius number Raio de busca
---@param requestingEntity table|nil Entidade que está fazendo a busca (será excluída dos resultados)
---@return table Tabela de entidades próximas (deve ser liberada com TablePool.release)
function SpatialGridIncremental:getNearbyEntities(worldX, worldY, searchRadius, requestingEntity)
    local nearbyEntities = TablePool.getArray()
    local checkedEntities = TablePool.getGeneric() -- Usar getGeneric para usar entidades como chaves

    if self.isInfinite then
        -- Para grid infinito, calcula o range de células de forma circular
        local radiusInCells = math.ceil(searchRadius / math.min(self.cellWidth, self.cellHeight))
        local centerCol, centerRow = self:getGridCoords(worldX, worldY)

        -- Itera em um quadrado ao redor da célula central com wrapping
        for dr = -radiusInCells, radiusInCells do
            for dc = -radiusInCells, radiusInCells do
                local targetCol = ((centerCol + dc - 1) % self.numCols) + 1
                local targetRow = ((centerRow + dr - 1) % self.numRows) + 1

                -- Garante valores positivos
                if targetCol <= 0 then targetCol = targetCol + self.numCols end
                if targetRow <= 0 then targetRow = targetRow + self.numRows end

                local cell = self.grid[targetCol][targetRow]
                if cell then
                    for _, entityInCell in ipairs(cell) do
                        -- Apenas adiciona à lista se não for a própria entidade e se ainda não foi adicionada.
                        if entityInCell ~= requestingEntity and not checkedEntities[entityInCell] then
                            table.insert(nearbyEntities, entityInCell)
                            checkedEntities[entityInCell] = true
                        end
                    end
                end
            end
        end
    else
        -- Para grid finito, usa o comportamento original
        local minSearchCol, minSearchRow = self:getGridCoords(worldX - searchRadius, worldY - searchRadius)
        local maxSearchCol, maxSearchRow = self:getGridCoords(worldX + searchRadius, worldY + searchRadius)

        for r = minSearchRow, maxSearchRow do
            for c = minSearchCol, maxSearchCol do
                local cell = self.grid[c][r]
                if cell then
                    for _, entityInCell in ipairs(cell) do
                        if entityInCell ~= requestingEntity and not checkedEntities[entityInCell] then
                            table.insert(nearbyEntities, entityInCell)
                            checkedEntities[entityInCell] = true
                        end
                    end
                end
            end
        end
    end

    TablePool.releaseGeneric(checkedEntities)
    -- IMPORTANTE: A tabela 'nearbyEntities' deve ser liberada pelo chamador
    return nearbyEntities
end

--- Destrói o grid e libera todas as tabelas do pool.
--- Deve ser chamada quando o grid não for mais necessário.
function SpatialGridIncremental:destroy()
    self:clear() -- Limpa todas as entidades primeiro
    -- Libera as tabelas das linhas e a tabela principal do grid
    for i = 1, #self.grid do
        if self.grid[i] then
            for j = 1, #self.grid[i] do
                if self.grid[i][j] then
                    TablePool.releaseArray(self.grid[i][j])
                end
            end
            TablePool.releaseArray(self.grid[i])
        end
    end
    TablePool.releaseArray(self.grid)
    Logger.info("spatial_grid.destroy.success", "Memória do SpatialGridIncremental liberada.")
end

--- Limpa completamente o grid, removendo todas as entidades.
function SpatialGridIncremental:clear()
    for i = 1, self.numCols do
        for j = 1, self.numRows do
            -- Apenas limpa a tabela da célula, não a substitui
            if self.grid[i] and self.grid[i][j] then
                local cell = self.grid[i][j]
                for k = #cell, 1, -1 do
                    table.remove(cell, k)
                end
            end
        end
    end
    Logger.info("spatial_grid.clear.success", "SpatialGridIncremental foi limpo.")
end

return SpatialGridIncremental
