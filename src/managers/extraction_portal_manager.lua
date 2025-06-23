local ExtractionPortal = require("src.entities.extraction_portal")

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

    for _, portal in ipairs(self.portals) do
        local distToPlayer = math.sqrt((portal.position.x - playerPos.x) ^ 2 + (portal.position.y - playerPos.y) ^ 2)

        if distToPlayer <= interactionRadius then
            portal:startActivation()
            portal.activationTimer = portal.activationTimer + dt
            if portal.activationTimer >= portal.activationDuration then
                portal.state = "activated"
                -- Trigger extraction
                print("EXTRACTION COMPLETE!")
                -- TODO: Implement scene change
            end
        else
            portal:stopActivation()
        end

        portal:update(dt)
    end
end

-- Coleta os renderizáveis dos portais
---@param renderPipeline RenderPipeline
function ExtractionPortalManager:collectRenderables(renderPipeline)
    for _, portal in ipairs(self.portals) do
        portal:collectRenderables(renderPipeline)
    end
end

return ExtractionPortalManager
