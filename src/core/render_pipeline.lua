---@class RenderPipeline
---@field buckets table<number, table<RenderableItem>> Tabela de buckets de renderização, chaveada por profundidade.
---@field spriteBatchReferences table<love.Texture, love.SpriteBatch> Referências a SpriteBatches gerenciados externamente.
---@field spriteBatchDrawData table<love.Texture, table<SpriteBatchDrawArgs>> Dados para desenhar nos SpriteBatches.
---@field sortableBuckets table<number, boolean> Configuração de quais buckets devem ser ordenados por sortY.
local RenderPipeline = {}
RenderPipeline.__index = RenderPipeline

-- Constantes de Profundidade para clareza e consistência
RenderPipeline.DEPTH_GROUND = 0           -- Geralmente tratado pelo MapManager
RenderPipeline.DEPTH_DROPS = 1
RenderPipeline.DEPTH_ENTITIES = 2         -- Jogador, Inimigos
RenderPipeline.DEPTH_EFFECTS_WORLD_UI = 3 -- Efeitos como projéteis, UI no mundo

local TablePool = require("src.utils.table_pool")

--- Cria uma nova instância do RenderPipeline.
---@return RenderPipeline
function RenderPipeline:new()
    local instance = setmetatable({}, RenderPipeline)
    instance.buckets = {
        [RenderPipeline.DEPTH_DROPS] = {},
        [RenderPipeline.DEPTH_ENTITIES] = {},
        [RenderPipeline.DEPTH_EFFECTS_WORLD_UI] = {},
    }
    -- Armazena referências aos SpriteBatches que são criados e gerenciados externamente (ex: em GameplayScene ou Managers)
    -- A chave é a textura do SpriteBatch.
    instance.spriteBatchReferences = {}

    -- Armazena os dados de desenho para cada SpriteBatch. Estes dados são coletados dos itens
    -- (ex: enemy_sprite) e depois usados para popular o SpriteBatch correspondente antes de desenhá-lo.
    -- A chave é a textura do SpriteBatch.
    instance.spriteBatchDrawData = {}

    -- Nova referência para o gerenciador de mapa.
    instance.mapManager = nil

    -- Configura quais buckets devem ser ordenados por 'sortY' para simular profundidade 2.5D.
    instance.sortableBuckets = {
        [RenderPipeline.DEPTH_ENTITIES] = true,
        -- Adicione outras profundidades se necessário
    }
    return instance
end

--- Limpa todos os buckets e dados de SpriteBatch para o próximo frame.
-- Os SpriteBatches em si (love.graphics.SpriteBatch) não são destruídos aqui, apenas seus dados de desenho.
-- As referências aos SpriteBatches são mantidas.
function RenderPipeline:reset()
    for depth, bucket in pairs(self.buckets) do
        -- Reutiliza a tabela do bucket, limpando seu conteúdo.
        -- Isso evita a recriação de tabelas a cada frame.
        for i = #bucket, 1, -1 do
            TablePool.release(bucket[i])
            table.remove(bucket, i)
        end
    end

    for texture, dataList in pairs(self.spriteBatchDrawData) do
        -- Reutiliza a tabela de dados de desenho, limpando seu conteúdo.
        for i = #dataList, 1, -1 do
            TablePool.release(dataList[i])
            table.remove(dataList, i)
        end
        -- Importante: O SpriteBatch referenciado (self.spriteBatchReferences[texture])
        -- deve ser limpo externamente (usando batch:clear()) antes de adicionar novos sprites,
        -- o que faremos na função draw() deste pipeline.
    end
end

--- Registra um SpriteBatch existente para ser usado pelo pipeline.
--- O pipeline adicionará sprites a este batch e o desenhará.
---@param texture Texture A textura associada ao SpriteBatch (usada como chave).
---@param batch love.SpriteBatch A instância do SpriteBatch.
function RenderPipeline:registerSpriteBatch(texture, batch)
    if not texture or not batch then
        -- Logger não está disponível aqui, então usamos print para erros críticos de setup.
        print("RenderPipeline ERRO: Tentativa de registrar SpriteBatch com textura ou batch nulo.")
        return
    end
    self.spriteBatchReferences[texture] = batch
    -- Garante que haja uma lista para armazenar dados de desenho para esta textura.
    if not self.spriteBatchDrawData[texture] then
        self.spriteBatchDrawData[texture] = {}
    end
end

--- Define o gerenciador de mapa a ser usado pelo pipeline.
--- @param mapManager (table) A instância do gerenciador de mapa (ex: ProceduralMapManager).
function RenderPipeline:setMapManager(mapManager)
    self.mapManager = mapManager
end

--- Adiciona um item renderizável a um bucket de renderização apropriado baseado em sua profundidade.
---@param item RenderableItem O item a ser adicionado. Deve ter 'depth', 'type', e dados de renderização.
-- Exemplo de item para SpriteBatch: { depth=2, type="enemy_sprite", texture=tex, quad=q, x=1, y=1, sortY=1, scale=1, ox=0, oy=0 }
-- Exemplo de item para drawFunction: { depth=2, type="player", drawFunction=fn, sortY=1 }
function RenderPipeline:add(item)
    if not item or not item.depth then
        print(string.format("RenderPipeline AVISO: Item inválido ou sem 'depth' fornecido: %s", tostring(item)))
        return
    end

    local bucket = self.buckets[item.depth]
    if bucket then
        table.insert(bucket, item)
    else
        print(string.format("RenderPipeline AVISO: Tentativa de adicionar item a bucket de profundidade inválida: %d",
            item.depth))
    end
end

--- Desenha todos os elementos gerenciados pelo pipeline.
--- Isso inclui o mapa, itens nos buckets (ordenados conforme necessário) e SpriteBatches.
--- O Camera:attach() e Camera:detach() devem ser chamados externamente, antes e depois desta função.
---@param cameraX number Posição X da câmera (usada para parallax ou culling se o mapManager precisar).
---@param cameraY number Posição Y da câmera.
function RenderPipeline:draw(cameraX, cameraY)
    -- 1. Desenha o Mapa (usando a referência interna)
    if self.mapManager and self.mapManager.draw then
        self.mapManager:draw(cameraX, cameraY)
    end

    -- 2. Processa e desenha itens dos buckets
    -- Ordem explícita para garantir a sequência correta de profundidade.
    local depthDrawOrder = {
        RenderPipeline.DEPTH_DROPS,
        RenderPipeline.DEPTH_ENTITIES,
        RenderPipeline.DEPTH_EFFECTS_WORLD_UI
    }

    for _, depthValue in ipairs(depthDrawOrder) do
        local bucket = self.buckets[depthValue]
        if bucket and #bucket > 0 then
            -- A ordenação manual de 'bucket' foi removida.
            -- A profundidade agora é gerenciada pelo SpriteBatch usando o parâmetro 'depth',
            -- o que resolve o problema de ordenação entre diferentes texturas (batches).

            -- Desenha/Processa os itens do bucket
            for _, item in ipairs(bucket) do
                if item.type == "enemy_sprite" or item.type == "batched_animation" then -- Generalizar para qualquer sprite batched
                    local batchDataList = self.spriteBatchDrawData[item.texture]
                    if batchDataList then
                        -- Coleta os dados para adicionar ao SpriteBatch. O desenho real do batch ocorre depois.
                        table.insert(batchDataList, {
                            quad = item.quad,
                            x = item.x,
                            y = item.y,
                            r = item.rotation or 0,
                            sx = item.scale or 1,
                            sy = item.scale or 1,
                            ox = item.ox or 0,
                            oy = item.oy or 0,
                            depth_in_batch = item.sortY,
                        })
                    else
                        print(string.format(
                            "RenderPipeline AVISO: Lista de dados de SpriteBatch não encontrada para textura: %s",
                            tostring(item.texture)))
                    end
                elseif item.drawFunction then
                    -- Para itens que fornecem sua própria função de desenho (jogador, orbs, drops, etc.)
                    item.drawFunction()
                elseif item.image and item.drawX and item.drawY then -- Desenho básico de imagem
                    love.graphics.draw(item.image, item.drawX, item.drawY, item.rotation_rad or 0, item.scaleX or 1,
                        item.scaleY or 1, item.ox or 0, item.oy or 0)
                else
                    -- print(string.format("RenderPipeline AVISO: Item no bucket sem método de desenho claro: type=%s", item.type))
                end
            end
        end
    end

    -- 3. Desenha os SpriteBatches
    -- love.graphics.setColor(1,1,1,1) -- Garante cor branca antes de desenhar batches, se necessário
    for texture, dataList in pairs(self.spriteBatchDrawData) do
        local batch = self.spriteBatchReferences[texture]
        if batch and #dataList > 0 then
            batch:clear() -- Limpa o batch antes de adicionar os sprites do frame atual
            for _, drawArgs in ipairs(dataList) do
                -- Usa a variante de :add() com o parâmetro de profundidade.
                -- A profundidade é baseada no sortY (posição Y), garantindo que
                -- entidades mais "ao sul" na tela sejam desenhadas por cima.
                -- math.floor é usado pois 'depth' precisa ser um número inteiro.
                batch:add(drawArgs.quad, drawArgs.x, drawArgs.y, drawArgs.r, drawArgs.sx, drawArgs.sy, drawArgs.ox,
                    drawArgs.oy, 0, 0, math.floor(drawArgs.depth_in_batch or 0))
            end
            if batch:getCount() > 0 then -- Verifica se há algo para desenhar
                -- print(string.format("RenderPipeline: Desenhando batch para textura %s com %d sprites", tostring(texture), batch:getCount()))
                love.graphics.draw(batch)
            end
        end
    end
end

--- Destroi o pipeline e limpa todos os recursos
function RenderPipeline:destroy()
    -- Limpa todos os buckets e dados de SpriteBatch
    self:reset()

    -- Limpa referências dos SpriteBatches (sem destruir os batches, pois são gerenciados externamente)
    self.spriteBatchReferences = {}
    self.spriteBatchDrawData = {}

    -- Remove referência do map manager
    self.mapManager = nil

    -- Limpa buckets
    self.buckets = {}
    self.sortableBuckets = {}

    print("RenderPipeline destruído.")
end

return RenderPipeline
