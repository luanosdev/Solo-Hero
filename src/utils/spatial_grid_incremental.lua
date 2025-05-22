local SpatialGridIncremental = {}
SpatialGridIncremental.__index = SpatialGridIncremental

local TablePool = require("src.utils.table_pool")

function SpatialGridIncremental:new(worldWidth, worldHeight, cellWidth, cellHeight)
    local instance = setmetatable({}, SpatialGridIncremental)
    instance.worldWidth = worldWidth
    instance.worldHeight = worldHeight
    instance.cellWidth = cellWidth
    instance.cellHeight = cellHeight
    instance.numCols = math.ceil(worldWidth / cellWidth)
    instance.numRows = math.ceil(worldHeight / cellHeight)
    instance.grid = TablePool.get()

    for i = 1, instance.numCols do
        instance.grid[i] = TablePool.get()
        for j = 1, instance.numRows do
            instance.grid[i][j] = TablePool.get()
        end
    end
    -- print(string.format("SpatialGridIncremental criado: %d x %d cells (%dx%d)", instance.numCols, instance.numRows, cellWidth, cellHeight))
    return instance
end

function SpatialGridIncremental:getGridCoords(worldX, worldY)
    local col = math.floor(worldX / self.cellWidth) + 1
    local row = math.floor(worldY / self.cellHeight) + 1
    col = math.max(1, math.min(self.numCols, col))
    row = math.max(1, math.min(self.numRows, row))
    return col, row
end

-- Adiciona a entidade a TODAS as células que seu raio toca.
-- Usado internamente por updateEntityInGrid.
function SpatialGridIncremental:_addEntityToOccupiedCells(entity)
    if not entity or not entity.position then return end

    local minCol, minRow = self:getGridCoords(entity.position.x - entity.radius, entity.position.y - entity.radius)
    local maxCol, maxRow = self:getGridCoords(entity.position.x + entity.radius, entity.position.y + entity.radius)
    
    -- Se entity.currentGridCells já existe e é uma tabela do pool, precisa ser liberada antes de pegar uma nova.
    -- No entanto, a lógica de updateEntityInGrid já chama _removeEntityFromOccupiedCells que a limpa e poderia liberá-la lá.
    -- Por simplicidade aqui, assumimos que quem chama _addEntityToOccupiedCells garante que entity.currentGridCells está pronto para ser preenchido.
    -- Se entity.currentGridCells fosse ser substituído, faríamos TablePool.release(entity.currentGridCells) ANTES de TablePool.get()
    if entity.currentGridCells then TablePool.release(entity.currentGridCells) end -- Libera a antiga se existir
    entity.currentGridCells = TablePool.get() -- Pega uma nova tabela para as células ocupadas

    for r = minRow, maxRow do
        for c = minCol, maxCol do
            if c >= 1 and c <= self.numCols and r >= 1 and r <= self.numRows then
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

-- Remove a entidade de TODAS as células que ela ocupava (baseado em entity.currentGridCells).
-- Usado internamente por updateEntityInGrid e para remoção completa.
function SpatialGridIncremental:_removeEntityFromOccupiedCells(entity)
    if not entity or not entity.currentGridCells then return end

    for cellKey, _ in pairs(entity.currentGridCells) do
        local parts = TablePool.get() -- Usa TablePool para 'parts'
        for part in string.gmatch(cellKey, "([^-:]+)") do
            table.insert(parts, tonumber(part))
        end
        if #parts == 2 then
            local col, row = parts[1], parts[2]
            if col >= 1 and col <= self.numCols and row >= 1 and row <= self.numRows then
                local cell = self.grid[col][row]
                if cell then -- Adiciona verificação se a célula existe
                    for i = #cell, 1, -1 do
                        if cell[i] == entity then
                            table.remove(cell, i)
                        end
                    end
                end
            end
        end
        TablePool.release(parts) -- Libera 'parts'
    end
    TablePool.release(entity.currentGridCells) -- Libera a tabela currentGridCells da entidade
    entity.currentGridCells = nil -- Define como nil para que seja obtida uma nova na próxima adição
end

-- Atualiza a posição de uma entidade no grid.
-- A entidade só é removida/readicionada se sua CÉLULA PRINCIPAL mudar.
function SpatialGridIncremental:updateEntityInGrid(entity)
    if not entity or not entity.position or not entity.id then -- entity.radius é opcional, default 0
        print("ERRO [SpatialGridIncremental:updateEntityInGrid]: Entidade inválida ou sem posição/id.")
        return
    end
    entity.radius = entity.radius or 0 -- Garante que o raio existe

    -- Obtém a célula principal atual da entidade (baseada no seu centro)
    local newMainCol, newMainRow = self:getGridCoords(entity.position.x, entity.position.y)

    if newMainCol ~= entity.lastGridCol or newMainRow ~= entity.lastGridRow then
        -- Célula principal mudou! Precisa remover das células antigas e adicionar às novas.
        
        -- 1. Remove a entidade de todas as células que ela ocupava anteriormente
        --    (baseado em seu raio na posição anterior, que estava em entity.currentGridCells)
        self:_removeEntityFromOccupiedCells(entity) 
        
        -- 2. Adiciona a entidade a todas as células que ela ocupa AGORA com base em sua nova posição e raio.
        self:_addEntityToOccupiedCells(entity)

        -- 3. Atualiza lastGridCol e lastGridRow da entidade
        entity.lastGridCol = newMainCol
        entity.lastGridRow = newMainRow
    else
        -- A célula principal não mudou. 
        -- No entanto, se o raio da entidade for significativo, ela ainda pode ter entrado/saído
        -- de células periféricas mesmo sem mudar a célula principal. 
        -- Para uma otimização mais completa (e complexa), precisaríamos recalcular 
        -- as currentGridCells e compará-las com as anteriores. 
        -- Mas para a solicitação atual (só atualizar se CÉLULA PRINCIPAL mudou), esta otimização para aqui.
        -- Se você quiser a checagem completa de todas as células do raio, podemos ajustar.
        
        -- Para garantir que `currentGridCells` está correto mesmo que a entidade não tenha mudado de célula principal
        -- mas possa ter se movido DENTRO da célula e seu raio agora toque outras células vizinhas,
        -- precisamos re-popular currentGridCells e potencialmente adicionar/remover de células periféricas.
        -- Esta parte torna a lógica mais próxima da versão anterior do SpatialGrid incremental.
        -- Se a intenção é *apenas* mover se a *célula principal* muda, o bloco abaixo é desnecessário.
        -- Vou mantê-lo para robustez, pois uma entidade pode se mover dentro de uma célula grande
        -- e seu raio começar a tocar novas células vizinhas ou deixar de tocar outras.

        local previousCurrentCells = TablePool.get()
        for k,v in pairs(entity.currentGridCells or {}) do previousCurrentCells[k] = v end
        
        -- Libera a antiga entity.currentGridCells ANTES de obter uma nova
        if entity.currentGridCells then TablePool.release(entity.currentGridCells) end
        entity.currentGridCells = TablePool.get() 
        
        local minCol, minRow = self:getGridCoords(entity.position.x - entity.radius, entity.position.y - entity.radius)
        local maxCol, maxRow = self:getGridCoords(entity.position.x + entity.radius, entity.position.y + entity.radius)

        local newCurrentCells = entity.currentGridCells -- Reutiliza a tabela já obtida
        for r = minRow, maxRow do
            for c = minCol, maxCol do
                local cellKey = c .. ":" .. r
                newCurrentCells[cellKey] = true
                if not previousCurrentCells[cellKey] then
                    self:_addEntityToCell_Internal(entity,c,r)
                end
            end
        end
        for oldCellKey, _ in pairs(previousCurrentCells) do
            if not newCurrentCells[oldCellKey] then
                 local parts = TablePool.get() -- Usa TablePool
                 for part in string.gmatch(oldCellKey, "([^-:]+)") do table.insert(parts, tonumber(part)) end
                 if #parts == 2 then self:_removeEntityFromCell_Internal(entity, parts[1], parts[2]) end
                 TablePool.release(parts) -- Libera
            end
        end
        -- entity.currentGridCells já é newCurrentCells
        TablePool.release(previousCurrentCells)
    end
end

-- Função auxiliar apenas para adicionar à lista da célula, sem modificar entity.currentGridCells
function SpatialGridIncremental:_addEntityToCell_Internal(entity, col, row)
    if col >= 1 and col <= self.numCols and row >= 1 and row <= self.numRows then
        local cell = self.grid[col][row]
        if not cell then -- Célula pode não existir se o grid foi limpo de forma agressiva
            self.grid[col][row] = TablePool.get()
            cell = self.grid[col][row]
        end
        local found = false
        for _, e in ipairs(cell) do
            if e == entity then found = true; break; end
        end
        if not found then table.insert(cell, entity); end
    end
end

-- Função auxiliar apenas para remover da lista da célula
function SpatialGridIncremental:_removeEntityFromCell_Internal(entity, col, row)
    if col >= 1 and col <= self.numCols and row >= 1 and row <= self.numRows then
        local cell = self.grid[col][row]
        if cell then -- Verifica se a célula (lista) existe
            for i = #cell, 1, -1 do
                if cell[i] == entity then table.remove(cell, i); end
            end
        end
    end
end

-- Remove completamente uma entidade do grid (quando ela morre ou é desativada).
function SpatialGridIncremental:removeEntityCompletely(entity)
    self:_removeEntityFromOccupiedCells(entity)
    entity.lastGridCol = nil -- Reseta para que seja totalmente readicionada se reutilizada
    entity.lastGridRow = nil
end

function SpatialGridIncremental:getNearbyEntities(worldX, worldY, searchRadius, requestingEntity)
    local nearbyEntities = TablePool.get() -- Pega do pool
    local checkedEntities = TablePool.get() -- Pega do pool

    -- Determina as células que a área de busca (ponto + searchRadius) toca
    local minSearchCol, minSearchRow = self:getGridCoords(worldX - searchRadius, worldY - searchRadius)
    local maxSearchCol, maxSearchRow = self:getGridCoords(worldX + searchRadius, worldY + searchRadius)

    for r = minSearchRow, maxSearchRow do
        for c = minSearchCol, maxSearchCol do
            if c >= 1 and c <= self.numCols and r >= 1 and r <= self.numRows then
                local cell = self.grid[c][r]
                if cell then -- Verifica se a célula existe
                    for _, entityInCell in ipairs(cell) do
                        if entityInCell ~= requestingEntity and not checkedEntities[entityInCell] then
                            -- Opcional: checagem de distância real se searchRadius for preciso
                            local dx = entityInCell.position.x - worldX
                            local dy = entityInCell.position.y - worldY
                            local distSq = dx*dx + dy*dy
                            if distSq <= (searchRadius + (entityInCell.radius or 0))^2 then
                                table.insert(nearbyEntities, entityInCell)
                                checkedEntities[entityInCell] = true
                            end
                        end
                    end
                end
            end
        end
    end
    TablePool.release(checkedEntities) -- Libera checkedEntities
    -- IMPORTANTE: A tabela 'nearbyEntities' é RETORNADA. Quem chama esta função
    -- é responsável por chamar TablePool.release(nearbyEntities) quando não precisar mais dela.
    return nearbyEntities
end

-- Adicionar uma função para limpar/liberar todas as tabelas do grid quando o grid não for mais necessário
function SpatialGridIncremental:destroy()
    if self.grid then
        for i = 1, self.numCols do
            if self.grid[i] then
                for j = 1, self.numRows do
                    if self.grid[i][j] then
                        TablePool.release(self.grid[i][j])
                        self.grid[i][j] = nil
                    end
                end
                TablePool.release(self.grid[i])
                self.grid[i] = nil
            end
        end
        TablePool.release(self.grid)
        self.grid = nil
    end
    -- print("SpatialGridIncremental destruído e tabelas liberadas.")
end

return SpatialGridIncremental 