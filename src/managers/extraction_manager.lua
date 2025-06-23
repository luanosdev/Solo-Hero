local lume = require("src.libs.lume")
local TeleportEffect = require("src.effects.teleport_effect")
local SceneManager = require("src.core.scene_manager")
local HUDGameplayManager = require("src.managers.hud_gameplay_manager")
local ManagerRegistry = require("src.managers.manager_registry")

---@class ExtractionManager
local ExtractionManager = {}
ExtractionManager.__index = ExtractionManager

---@return ExtractionManager
function ExtractionManager:new()
    local instance = setmetatable({}, ExtractionManager)

    -- Generic State
    instance.isActive = false -- Is any extraction sequence or casting active?
    instance.timer = 0
    instance.config = {}

    -- Casting State
    instance.isCasting = false
    instance.onCastCompleteCallback = nil

    -- Sequence State
    instance.isSequencing = false
    instance.teleportEffect = nil
    instance.playerInitialPos = nil

    return instance
end

---@param config table { type: 'portal'|'item', source: any, duration: number, details?: any }
function ExtractionManager:startExtractionSequence(config)
    if self.isSequencing then return end
    print("[ExtractionManager] Starting extraction sequence of type: " .. config.type)

    local playerManager = ManagerRegistry:get("playerManager")
    self.isSequencing = true
    self.isActive = true -- A sequence is a form of activity
    self.config = config
    self.timer = 0

    -- Common logic: disable inputs and create teleport effect
    local inputManager = ManagerRegistry:get("inputManager")
    inputManager:setMovementEnabled(false)
    inputManager:setActionsEnabled(false)

    local effectPos
    if config.type == 'portal' then
        self.playerInitialPos = playerManager.player.position
        effectPos = config.source.position
        playerManager:setInvincible(true)
    elseif config.type == 'item' then
        effectPos = playerManager.player.position
    end
    self.teleportEffect = TeleportEffect:new(effectPos)
end

---@param dt number
function ExtractionManager:update(dt)
    if not self.isActive then return end

    if self.isCasting then
        self:_updateCasting(dt)
    end

    if self.isSequencing then
        self:_updateSequence(dt)
    end
end

---@param dt number
function ExtractionManager:_updateSequence(dt)
    local playerManager = ManagerRegistry:get("playerManager")
    self.timer = self.timer + dt

    if self.teleportEffect then
        if self.config.type == 'item' then
            local playerPos = playerManager.player.position
            self.teleportEffect.position.x = playerPos.x
            self.teleportEffect.position.y = playerPos.y
        end
        self.teleportEffect:update(dt)
    end

    if self.config.type == 'portal' then
        local moveDuration = 0.8
        if self.timer < moveDuration then
            local t = math.min(self.timer / moveDuration, 1.0)
            local newX = lume.lerp(self.playerInitialPos.x, self.config.source.position.x, t)
            local newY = lume.lerp(self.playerInitialPos.y, self.config.source.position.y, t)
            playerManager:setPosition({ x = newX, y = newY })
        end
    end

    if self.timer >= self.config.duration then
        local extractionType = self.config.details and self.config.details.extractionType or "all_items_instant"
        local summaryParams = self:_getExtractionSummaryArgs(extractionType)

        self:reset()
        SceneManager.switchScene("extraction_summary_scene", summaryParams)
    end
end

---@param renderPipeline RenderPipeline
function ExtractionManager:collectRenderables(renderPipeline)
    if not self.isSequencing or not self.teleportEffect then return end
    self.teleportEffect:collectRenderables(renderPipeline)
end

function ExtractionManager:getActive()
    return self.isActive
end

function ExtractionManager:reset()
    print("[ExtractionManager] Resetting state.")
    self.isActive = false
    self.isCasting = false
    self.isSequencing = false
    self.config = {}
    self.timer = 0
    self.teleportEffect = nil
    self.playerInitialPos = nil
    self.onCastCompleteCallback = nil

    HUDGameplayManager:stopExtraction()

    local inputManager = ManagerRegistry:get("inputManager")
    inputManager:setMovementEnabled(true)
    inputManager:setActionsEnabled(true)

    local playerManager = ManagerRegistry:get("playerManager")
    playerManager:setInvincible(false)
    playerManager:setAlpha(1)
end

--- Logic moved from GameplayScene
---@param extractionType string
---@return table params Parameters for the extraction summary scene
function ExtractionManager:_getExtractionSummaryArgs(extractionType)
    print(string.format("[ExtractionManager] Getting summary args for extraction type: %s", extractionType))
    local playerManager = ManagerRegistry:get("playerManager")
    local inventoryManager = ManagerRegistry:get("inventoryManager")
    local itemDataManager = ManagerRegistry:get("itemDataManager")
    local hunterManager = ManagerRegistry:get("hunterManager")
    local archetypeManager = ManagerRegistry:get("archetypeManager")
    local gameStatisticsManager = ManagerRegistry:get("gameStatisticsManager")
    local hunterId = playerManager:getCurrentHunterId()

    if not hunterId then
        error("No hunter ID found")
    end

    local finalStatsForSummary = playerManager:getCurrentFinalStats()
    local archetypeIdsForSummary = hunterManager:getArchetypeIds(hunterId)

    local backpackItemsToExtract = inventoryManager:getAllItemsGameplay() or {}
    local equipmentToExtract = playerManager:getCurrentEquipmentGameplay() or {}

    local params = {
        wasSuccess = true,
        hunterId = hunterId,
        hunterData = hunterManager:getHunterData(hunterId),
        portalData = self.config.source and self.config.source.portalData or { name = "Extração por Item", rank = "S" },
        extractedItems = backpackItemsToExtract,
        extractedEquipment = equipmentToExtract,
        finalStats = finalStatsForSummary,
        archetypeIds = archetypeIdsForSummary,
        archetypeManagerInstance = archetypeManager,
        gameplayStats = gameStatisticsManager:getRawStats()
    }

    return params
end

--- Casting logic moved from GameplayScene
---@param itemInstance table
function ExtractionManager:requestUseItem(itemInstance)
    if self.isCasting then return false end

    local itemDataManager = ManagerRegistry:get("itemDataManager")
    local baseData = itemDataManager:getBaseItemData(itemInstance.itemBaseId)
    if not baseData or not baseData.useDetails then return false end

    local useDetails = baseData.useDetails

    local inventoryManager = ManagerRegistry:get("inventoryManager")
    inventoryManager:removeItemInstance(itemInstance.instanceId, 1)

    self.isCasting = true
    self.isActive = true
    self.timer = 0
    self.config = {
        item = itemInstance,
        duration = useDetails.castTime or 0,
        details = useDetails,
        type = 'item'
    }

    local itemName = baseData.name or "Item Desconhecido"
    HUDGameplayManager:startItemCasting(self.config.duration, itemName)

    local playerManager = ManagerRegistry:get("playerManager")
    self.onCastCompleteCallback = function()
        self:startExtractionSequence({
            type = 'item',
            source = playerManager.player.position,
            duration = 3.0, -- Standard duration for item teleport effect
            details = useDetails
        })
    end

    if self.config.duration <= 0.01 then
        if self.onCastCompleteCallback then
            self.onCastCompleteCallback()
        end
        self:reset()
    end

    return true
end

---@param dt number
function ExtractionManager:_updateCasting(dt)
    if not self.isCasting then return end

    self.timer = self.timer + dt
    if self.timer >= self.config.duration then
        if self.onCastCompleteCallback then
            self.onCastCompleteCallback()
        end
        -- Don't reset here, the callback starts the sequence which will reset later
        self.isCasting = false
        self.timer = 0
    end
end

return ExtractionManager
