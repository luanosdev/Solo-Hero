-------------------------------------------------------
-- Experience Orb Manager
-- Gerencia os orbes de experiência que podem ser coletados pelo jogador

local ExperienceOrb = require("src.entities.experience_orb")
local ManagerRegistry = require("src.managers.manager_registry")
local Constants = require("src.config.constants")
local TablePool = require("src.utils.table_pool")
local Culling = require("src.core.culling")
local Camera = require("src.config.camera")

---@class ExperienceOrbManager
---@field orbs table Lista de orbes de experiência ativos
local ExperienceOrbManager = {
    orbs = {} -- Lista de orbes de experiência ativos
}

function ExperienceOrbManager:init()
    self.orbs = {}
end

function ExperienceOrbManager:update(dt)
    local playerManager = ManagerRegistry:get("playerManager")

    local camX, camY, camWidth, camHeight = Camera:getViewPort() -- Obtém a visão da câmera

    -- Atualiza e remove orbes coletados
    for i = #self.orbs, 1, -1 do
        local orb = self.orbs[i]

        -- Fututamente temos que mudar a logica pois podemos fazer um sistema de coletar orbes que estão fora da tela
        local inViewForUpdate = Culling.isInView(orb, camX, camY, camWidth, camHeight, 0)

        if inViewForUpdate then
            if orb:update(dt) then
                -- Adiciona a experiência ao jogador através do PlayerManager
                playerManager:addExperience(orb.experience)
            end
        end
    end
end

function ExperienceOrbManager:addOrb(x, y, experience)
    local orb = ExperienceOrb:new(x, y, experience)
    table.insert(self.orbs, orb)
end

--- Coleta os orbes de experiência renderizáveis para a lista de renderização da cena.
---@param renderPipeline RenderPipeline RenderPipeline para adicionar os dados de renderização do orbe.
function ExperienceOrbManager:collectRenderables(renderPipeline)
    if not self.orbs or #self.orbs == 0 then
        return
    end

    local camX, camY, camWidth, camHeight = Camera:getViewPort() -- Obtém a visão da câmera

    for _, orb in ipairs(self.orbs) do
        if not orb.collected then
            -- A posição do orbe já inclui a levitação para fins de cálculo de sortY
            -- Para converter a posição do orbe (que é cartesian no centro) para o sistema isométrico de tiles:
            local orbWorldX = orb.position.x
            local orbWorldY = orb.position.y -- Isso inclui a levitação na lógica do orbe, o que é bom.

            -- Verifica se o orbe está na tela para renderização
            if Culling.isInView(orb, camX, camY, camWidth, camHeight, 0) then
                -- Precisamos converter a posição do orbe para uma "base" isométrica para ordenação.
                -- A função de desenho do orbe já lida com sua posição correta na tela.
                -- A sortY deve representar a "base" do orbe no mundo isométrico.
                -- Como o orbe flutua, sua "base" percebida para ordenação pode ser simplesmente seu y isométrico.
                local isoY = (orbWorldX + orbWorldY) * (Constants.TILE_HEIGHT / 2)

                -- Adiciona uma pequena elevação na sortY para garantir que orbes "mais altos" (levitando)
                -- sejam desenhados corretamente sobre entidades que estão "no chão" na mesma coordenada isométrica.
                -- A levitação já está em orb.position.y pela lógica de ExperienceOrb:draw (levitationOffset)
                -- A sortY pode ser o isoY + uma parte da "altura visual" do orbe, similar aos tiles.
                -- Para simplificar, vamos usar o isoY diretamente, e o depth controlará a sobreposição principal.
                -- A profundidade 1 é a mesma de jogadores e inimigos.
                local sortYValue = isoY + (orb.radius or 5) -- Ordena pela base do orbe + seu raio

                local renderableItem = TablePool.get()
                renderableItem.type = "experience_orb"
                renderableItem.sortY = sortYValue
                renderableItem.depth = 1 -- Mesma camada de jogadores/inimigos, mas orbes podem flutuar visualmente acima.
                renderableItem.drawFunction = function()
                    -- Verifica se o orbe ainda existe e não foi coletado antes de tentar desenhar
                    -- Isso é uma salvaguarda, pois o estado pode mudar entre collectRenderables e o momento do desenho.
                    if orb and not orb.collected then
                        orb:draw()
                    end
                end
                renderPipeline:add(renderableItem)
            end
        end
    end
end

return ExperienceOrbManager
