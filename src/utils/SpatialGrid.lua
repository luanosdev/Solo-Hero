local SpatialGrid = {}
SpatialGrid.__index = SpatialGrid

function SpatialGrid:new(worldWidth, worldHeight, cellWidth, cellHeight)
    local instance = setmetatable({}, SpatialGrid)
    instance.worldWidth = worldWidth
    instance.worldHeight = worldHeight
    instance.cellWidth = cellWidth
    instance.cellHeight = cellHeight
    instance.numCols = math.ceil(worldWidth / cellWidth)
    instance.numRows = math.ceil(worldHeight / cellHeight)
    instance.grid = {} -- Tabela de tabelas para as células

    -- Inicializa o grid com células vazias (listas)
    for i = 1, instance.numCols do
        instance.grid[i] = {}
        for j = 1, instance.numRows do
            instance.grid[i][j] = {}
        end
    end
    print(string.format("SpatialGrid criado: %d x %d cells (%dx%d)", instance.numCols, instance.numRows, cellWidth, cellHeight))
    return instance
end

-- Converte coordenadas do mundo para coordenadas do grid (coluna, linha).
function SpatialGrid:getGridCoords(worldX, worldY)
    local col = math.floor(worldX / self.cellWidth) + 1
    local row = math.floor(worldY / self.cellHeight) + 1
    -- Garante que as coordenadas estão dentro dos limites do grid
    col = math.max(1, math.min(self.numCols, col))
    row = math.max(1, math.min(self.numRows, row))
    return col, row
end

-- Adiciona uma entidade a uma célula específica do grid.
-- Assume que a entidade tem um campo 'id' único.
function SpatialGrid:addEntityToCell(entity, col, row)
    if col >= 1 and col <= self.numCols and row >= 1 and row <= self.numRows then
        -- Adiciona apenas se não estiver já presente para evitar duplicatas na mesma célula por frame
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
    else
        -- print(string.format("AVISO [SpatialGrid]: Tentativa de adicionar entidade fora dos limites do grid (%d, %d)", col, row))
    end
end

-- Remove uma entidade de uma célula específica do grid.
function SpatialGrid:removeEntityFromCell(entity, col, row)
    if col >= 1 and col <= self.numCols and row >= 1 and row <= self.numRows then
        local cell = self.grid[col][row]
        for i = #cell, 1, -1 do
            if cell[i] == entity then
                table.remove(cell, i)
                -- Não precisa de break se a entidade pudesse (erroneamente) estar múltiplas vezes
                -- mas com a lógica de addEntityToCell, isso não deve acontecer.
            end
        end
    end
end

-- Atualiza a posição de uma entidade no grid.
-- A entidade deve ter position.x, position.y, id, e currentGridCells.
function SpatialGrid:updateEntityInGrid(entity)
    if not entity or not entity.position or not entity.id or not entity.currentGridCells then
        print("ERRO [SpatialGrid:updateEntityInGrid]: Entidade inválida ou sem position/id/currentGridCells.")
        return
    end

    local newEntityCells = {} -- Tabela para rastrear as novas células que a entidade ocupa
    local minCol, minRow = self:getGridCoords(entity.position.x - (entity.radius or 0), entity.position.y - (entity.radius or 0))
    local maxCol, maxRow = self:getGridCoords(entity.position.x + (entity.radius or 0), entity.position.y + (entity.radius or 0))

    -- Determina as novas células e adiciona a entidade a elas
    for r = minRow, maxRow do
        for c = minCol, maxCol do
            local cellKey = c .. ":" .. r
            newEntityCells[cellKey] = true -- Marca que a entidade está nesta nova célula
            if not entity.currentGridCells[cellKey] then
                -- Entidade entrou nesta célula
                self:addEntityToCell(entity, c, r)
            end
        end
    end

    -- Remove a entidade das células antigas das quais ela saiu
    for oldCellKey, _ in pairs(entity.currentGridCells) do
        if not newEntityCells[oldCellKey] then
            -- Entidade saiu desta célula antiga
            local parts = {}
            for part in string.gmatch(oldCellKey, "([^-:]+)") do -- Melhorado para pegar números com split
                table.insert(parts, tonumber(part))
            end
            if #parts == 2 then
                 self:removeEntityFromCell(entity, parts[1], parts[2])
            end
        end
    end

    -- Atualiza o registro de células da entidade
    entity.currentGridCells = newEntityCells
end

-- Remove completamente uma entidade do grid (quando ela morre ou é desativada).
function SpatialGrid:removeEntityFromGrid(entity)
    if not entity or not entity.currentGridCells then
        -- print("AVISO [SpatialGrid:removeEntityFromGrid]: Entidade inválida ou sem currentGridCells.")
        return
    end
    for cellKey, _ in pairs(entity.currentGridCells) do
        local parts = {}
        for part in string.gmatch(cellKey, "([^-:]+)") do
            table.insert(parts, tonumber(part))
        end
        if #parts == 2 then
            self:removeEntityFromCell(entity, parts[1], parts[2])
        end
    end
    entity.currentGridCells = {} -- Limpa o registro na entidade
end

-- Retorna uma lista de INSTÂNCIAS de entidades de células vizinhas e da própria célula.
-- A profundidade da vizinhança pode ser controlada (depth=0 para mesma célula, depth=1 para 3x3, etc.)
function SpatialGrid:getNearbyEntities(worldX, worldY, depth)
    depth = depth or 0 -- Profundidade padrão de 0 (apenas a célula atual)
    local centerCol, centerRow = self:getGridCoords(worldX, worldY)
    
    local nearbyEntities = {}
    local checkedEntities = {}

    for rOffset = -depth, depth do
        for cOffset = -depth, depth do
            local currentCol = centerCol + cOffset
            local currentRow = centerRow + rOffset

            if currentCol >= 1 and currentCol <= self.numCols and currentRow >= 1 and currentRow <= self.numRows then
                local cell = self.grid[currentCol][currentRow]
                for _, entityInstance in ipairs(cell) do
                    if not checkedEntities[entityInstance] then
                        table.insert(nearbyEntities, entityInstance)
                        checkedEntities[entityInstance] = true
                    end
                end
            end
        end
    end
    return nearbyEntities
end

return SpatialGrid 