local ExtractionPortal = require("src.entities.extraction_portal")
local Culling = require("src.core.culling")
local Camera = require("src.config.camera")
local HUDGameplayManager = require("src.managers.hud_gameplay_manager")

---@class ExtractionPortalManager
---@field portals table<ExtractionPortal>
local ExtractionPortalManager = {}
ExtractionPortalManager.__index = ExtractionPortalManager

-- Cria uma nova instância do ExtractionPortalManager
function ExtractionPortalManager:new()
    local instance = setmetatable({}, ExtractionPortalManager)
    instance.portals = {}
    return instance
end

-- Inicializa o ExtractionPortalManager
---@param config { playerManager: PlayerManager } Tabela de configuração contendo o playerManager.
function ExtractionPortalManager:init(config)
    self.playerManager = config.playerManager
end

-- Spawna os portais
function ExtractionPortalManager:spawnPortals()
    local playerPos = self.playerManager.player.position
    local minPlayerDist = 1500 -- Minimum distance from player
    local maxPlayerDist = 3000 -- Maximum distance from player
    local minPortalDist = 1500 -- Minimum distance between portals
    local numPortals = 2
    local attempts = 50        -- Max attempts to find a valid position

    for i = 1, numPortals do
        local validPositionFound = false
        local x, y
        for _ = 1, attempts do
            local angle = math.random() * 2 * math.pi
            local distance = minPlayerDist + math.random() * (maxPlayerDist - minPlayerDist)
            x = playerPos.x + math.cos(angle) * distance
            y = playerPos.y + math.sin(angle) * distance

            -- Check distance from other portals
            local isPositionClear = true
            for _, otherPortal in ipairs(self.portals) do
                local distToPortal = math.sqrt((x - otherPortal.position.x) ^ 2 + (y - otherPortal.position.y) ^ 2)
                if distToPortal < minPortalDist then
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
    if not self.playerManager.player then return end
    local playerPos = self.playerManager.player.position
    local interactionRadius = 64 -- Same as portal radius, more or less
    local isPlayerOnAnyPortal = false

    for _, portal in ipairs(self.portals) do
        local distToPlayer = math.sqrt((portal.position.x - playerPos.x) ^ 2 + (portal.position.y - playerPos.y) ^ 2)

        if distToPlayer <= interactionRadius then
            isPlayerOnAnyPortal = true
            if portal.state == "idle" then
                portal:startActivation()
                HUDGameplayManager:startExtractionTimer(portal.activationDuration, "Extraindo...")
            end

            if portal.state == "activating" and HUDGameplayManager:isExtractionFinished() then
                portal.state = "activated"
                -- Trigger extraction
                Logger.info("ExtractionPortalManager", "EXTRACTION COMPLETE!")
                -- TODO: Implement scene change
                HUDGameplayManager:stopExtractionTimer()
            end
        else
            if portal.state == "activating" then
                portal:stopActivation()
                -- This will be handled by the general stop below
            end
        end
        portal:update(dt)
    end

    if not isPlayerOnAnyPortal then
        -- Stop the timer if the player moved away from ALL portals
        HUDGameplayManager:stopExtractionTimer()
        for _, portal in ipairs(self.portals) do
            portal:stopActivation()
        end
    end
end

-- Coleta os renderizáveis dos portais
---@param renderPipeline RenderPipeline
function ExtractionPortalManager:collectRenderables(renderPipeline)
    for _, portal in ipairs(self.portals) do
        if Culling.isInView(portal, Camera.x, Camera.y, Camera.screenWidth, Camera.screenHeight, 100) then
            portal:collectRenderables(renderPipeline)
        end
    end
end

return ExtractionPortalManager
