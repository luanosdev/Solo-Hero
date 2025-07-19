--------------------------------------------------------------------------------
--- Extraction Portal Manager
--- Gerencia a criação e atualização dos portais de extração
--------------------------------------------------------------------------------

local ExtractionPortal = require("src.entities.extraction_portal")
local ManagerRegistry = require("src.managers.manager_registry")
local HUDGameplayManager = require("src.managers.hud_gameplay_manager")

---@class ExtractionPortalManager
---@field portals table<ExtractionPortal>
local ExtractionPortalManager = {}
ExtractionPortalManager.__index = ExtractionPortalManager

ExtractionPortalManager.CULL_MARGIN_DRAW = 50
ExtractionPortalManager.CULL_MARGIN_UPDATE = 200
ExtractionPortalManager.MIN_PORTAL_DIST = 10000
ExtractionPortalManager.MAX_PORTAL_DIST = 15000
--- TODO: ExtractionPortalManager.NUM_PORTALS - Essa propriedade deve vir do mapa
ExtractionPortalManager.NUM_PORTALS = 2
ExtractionPortalManager.ATTEMPTS = 50
ExtractionPortalManager.PORTAL_INTERACTION_RADIUS = 64
ExtractionPortalManager.PORTAL_SEQUENCE_DURATION = 2.5

-- Cria uma nova instância do ExtractionPortalManager
function ExtractionPortalManager:new()
    local instance = setmetatable({}, ExtractionPortalManager)
    instance.portals = {}
    instance.wasPlayerOnPortalLastFrame = false
    return instance
end

-- Spawna os portais
function ExtractionPortalManager:spawnPortals()
    ---@type PlayerManager
    local playerManager = ManagerRegistry:get("playerManager")

    local playerPos = playerManager:getPlayerPosition()

    for i = 1, self.NUM_PORTALS do
        local validPositionFound = false
        local x, y
        for _ = 1, self.ATTEMPTS do
            local angle = math.random() * 2 * math.pi
            local distance = self.MIN_PORTAL_DIST + math.random() * (self.MAX_PORTAL_DIST - self.MIN_PORTAL_DIST)
            x = playerPos.x + math.cos(angle) * distance
            y = playerPos.y + math.sin(angle) * distance

            -- Check distance from other portals
            local isPositionClear = true
            for _, otherPortal in ipairs(self.portals) do
                local distToPortal = math.sqrt((x - otherPortal.position.x) ^ 2 + (y - otherPortal.position.y) ^ 2)
                if distToPortal < self.MIN_PORTAL_DIST then
                    isPositionClear = false
                    break
                end
            end

            if isPositionClear then
                validPositionFound = true
                break
            end
        end

        if validPositionFound then
            local portal = ExtractionPortal:new(x, y)
            table.insert(self.portals, portal)
            Logger.info("ExtractionPortalManager", string.format("Portal %d spawned at %.2f, %.2f", i, x, y))
        else
            Logger.warn("ExtractionPortalManager", string.format("Failed to find a valid position for portal %d", i))
        end
    end
end

-- Atualiza os portais
---@param dt number Delta time.
function ExtractionPortalManager:update(dt)
    ---@type PlayerManager
    local playerManager = ManagerRegistry:get("playerManager")
    ---@type ExtractionManager
    local extractionManager = ManagerRegistry:get("extractionManager")
    ---@type CullingManager
    local cullingManager = ManagerRegistry:get("cullingManager")

    local playerPos = playerManager:getPlayerPosition()
    local interactionRadius = self.PORTAL_INTERACTION_RADIUS
    local isPlayerOnAnyPortalThisFrame = false

    for _, portal in ipairs(self.portals) do
        if cullingManager:isInView(portal, self.CULL_MARGIN_UPDATE) then
            local distToPlayer = math.sqrt((portal.position.x - playerPos.x) ^ 2 + (portal.position.y - playerPos.y) ^ 2)

            if distToPlayer <= interactionRadius then
                isPlayerOnAnyPortalThisFrame = true
                if portal.state == "idle" then
                    portal:startActivation()
                    extractionManager:showExtractionTimerProgress(portal.activationDuration, "Extraindo...")
                end

                if portal.state == "activating" and HUDGameplayManager:isExtractionFinished() then
                    portal.state = "activated"
                    extractionManager:stopExtractionTimer()

                    -- Inicia a nova sequência de extração através do manager unificado
                    extractionManager:startExtractionSequence({
                        type = 'portal',
                        source = portal,
                        duration = self.PORTAL_SEQUENCE_DURATION,
                        details = { portalData = portal.portalData }
                    })
                end
            end
            portal:update(dt)
        end
    end

    -- Esta condição agora verifica corretamente se o jogador ACABOU de sair da área do portal.
    if self.wasPlayerOnPortalLastFrame and not isPlayerOnAnyPortalThisFrame then
        HUDGameplayManager:stopExtractionTimer()
        for _, portal in ipairs(self.portals) do
            -- Garante que todos os portais sejam resetados se o jogador sair da área.
            portal:stopActivation()
        end
    end

    -- Atualiza o estado para o próximo frame.
    self.wasPlayerOnPortalLastFrame = isPlayerOnAnyPortalThisFrame
end

-- Coleta os renderizáveis dos portais
---@param renderPipeline RenderPipeline
function ExtractionPortalManager:collectRenderables(renderPipeline)
    ---@type CullingManager
    local cullingManager = ManagerRegistry:get("cullingManager")

    for _, portal in ipairs(self.portals) do
        if cullingManager:isInView(portal, self.CULL_MARGIN_DRAW) then
            portal:collectRenderables(renderPipeline)
        end
    end
end

-- Spawna um portal no local de morte do ultimo boss
-- TODO: ExtractionPortalManager:spawnPortalOnDeath - Essa função deve ser chamada quando o ultimo boss morrer, talvez com uma animação de morte
---@param x number
---@param y number
function ExtractionPortalManager:spawnPortalOnDeath(x, y)
    local portal = ExtractionPortal:new(x, y)
    table.insert(self.portals, portal)
end

return ExtractionPortalManager
