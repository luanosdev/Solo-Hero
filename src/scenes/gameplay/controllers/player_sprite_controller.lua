local SpritePlayer = require('src.animations.sprite_player')
local Constants = require("src.config.constants")
local RenderPipeline = require("src.core.render_pipeline")
local TablePool = require("src.utils.table_pool")

---@class PlayerSpriteController
---@description Gerencia a criação, atualização e renderização do sprite do jogador.
--- Este controller é o "dono" da instância do `SpritePlayer` e o conecta
--- com o resto dos sistemas (movimento, stats, equipamento).
---@field playerSprite SpritePlayer|nil A instância do sprite do jogador.
---@field eventService EventService
---@field itemDataService ItemDataService
---@field eventListeners table
local PlayerSpriteController = {}
PlayerSpriteController.__index = PlayerSpriteController

---@param eventService EventService
---@param itemDataService ItemDataService
---@return PlayerSpriteController
function PlayerSpriteController:new(eventService, itemDataService)
    local instance = setmetatable({}, PlayerSpriteController)

    instance.playerSprite = nil
    instance.eventService = eventService
    instance.itemDataService = itemDataService
    instance.eventListeners = {}

    return instance
end

---@public Inicializa o controller.
---@param skinTone string
function PlayerSpriteController:init(skinTone)
    -- Inicializa o listener de eventos
    self:_listen(self.eventService.EVENTS.EQUIPMENT_CHANGED, self._onEquipmentChanged)

    self:_setupSprite(skinTone)

    -- Carrega os assets do sprite do jogador (operação idempotente)
    -- SpritePlayer.load() -- REMOVIDO
end

--- Atualiza a animação e o estado do sprite.
---@param dt number
---@param moveSpeedInPixels number
---@param moveVector Vector2D
---@param position Vector2D Posição do jogador em coordenadas de mundo.
---@param angle number Ângulo atual do jogador.
function PlayerSpriteController:update(dt, moveSpeedInPixels, moveVector, position, angle)
    if not self.playerSprite then return end
    -- TODO: Adicionar checagem de dash e UI lock

    self.playerSprite.velocity = moveVector
    self.playerSprite.position = position

    -- Atualiza o sprite com a posição de mundo. A câmera cuidará da centralização.
    SpritePlayer.update(self.playerSprite, dt, position, moveSpeedInPixels, angle)
end

---@public Adiciona o sprite do jogador ao pipeline de renderização.
--- Este método cria um item renderizável com uma função de desenho,
--- seguindo o padrão da arquitetura antiga para desacoplar o sprite do pipeline.
---@param renderPipeline RenderPipeline
---@param worldPosition Vector2D A posição atual do jogador no mundo para o cálculo do sortY.
function PlayerSpriteController:collectRenderables(renderPipeline, worldPosition)
    if not self.playerSprite then
        Logger.warn("player_sprite_controller.collect",
            "[PlayerSpriteController] Tentou coletar, mas self.playerSprite é nil.")
        return
    end

    -- Calcula o sortY para a profundidade 2.5D
    local playerBaseY = worldPosition.y + 25 -- Pés do sprite
    local worldX_eq = worldPosition.x / Constants.TILE_WIDTH
    local worldY_eq = playerBaseY / Constants.TILE_HEIGHT
    local isoY_ref_top = (worldX_eq + worldY_eq) * (Constants.TILE_HEIGHT / 2)
    local sortY = isoY_ref_top + Constants.TILE_HEIGHT

    -- Cria o item renderizável
    local renderableItem = TablePool.getGeneric()
    renderableItem.type = "player"
    renderableItem.sortY = sortY
    renderableItem.depth = RenderPipeline.DEPTH_ENTITIES
    renderableItem.x = worldPosition.x
    renderableItem.y = worldPosition.y
    renderableItem.drawFunction = function()
        -- Aplica a translação para a posição de mundo antes de desenhar
        love.graphics.push()
        love.graphics.translate(worldPosition.x, worldPosition.y)
        SpritePlayer.draw(self.playerSprite)
        love.graphics.pop()
    end

    renderPipeline:add(renderableItem)
end

---@public Atualiza a animação do sprite com base no comando de ataque.
---@param command AttackControllerCommand
function PlayerSpriteController:updateAttackAnimation(command)
    if not self.playerSprite then return end

    local isMoving = self.playerSprite.velocity.x ~= 0 or self.playerSprite.velocity.y ~= 0
    local animationType = command.animation

    SpritePlayer.startAttackAnimation(self.playerSprite, animationType, isMoving)
end

---@private Registra um listener de eventos.
---@param event string
---@param handler function
function PlayerSpriteController:_listen(event, handler)
    local listener = self.eventService:on(event, function(data) handler(self, data) end)
    table.insert(self.eventListeners, listener)
end

---@private Atualiza a aparência do sprite com base no equipamento.
function PlayerSpriteController:_onEquipmentChanged(event)
    assert(event, "PlayerSpriteController:onEquipmentChanged requer um evento")
    Logger.info("player_sprite_controller.onEquipmentChanged",
        "[PlayerSpriteController:onEquipmentChanged] Event received: ")

    -- DEBUG: Log detalhado do evento recebido
    Logger.info("player_sprite_controller.debug.event_details",
        string.format("[DEBUG] Event details - slotId: %s, hasNewItem: %s, hasAllEquipped: %s",
            tostring(event.slotId),
            tostring(event.newItem ~= nil),
            tostring(event.allEquipped ~= nil)
        ))

    if not event.slotId then
        assert(event.allEquipped, "PlayerSpriteController:onEquipmentChanged: precisa de um allEquipped")

        -- DEBUG: Log dos itens equipados
        Logger.info("player_sprite_controller.debug.all_equipped",
            string.format("[DEBUG] Processing all equipped items. Count: %d",
                event.allEquipped and #event.allEquipped or 0))

        -- Atualiza a aparência com base em todos os itens equipados
        local allEquipped = event.allEquipped
        -- Primeiro, a arma equipada
        local weapon = allEquipped[Constants.SLOT_IDS.WEAPON]
        if weapon then
            Logger.info("player_sprite_controller.debug.weapon_found",
                string.format("[DEBUG] Weapon found - itemBaseId: %s", tostring(weapon.itemBaseId)))

            local weaponBaseData = self.itemDataService:getBaseItemData(weapon.itemBaseId)
            if weaponBaseData then
                Logger.info("player_sprite_controller.debug.weapon_data",
                    string.format("[DEBUG] Weapon data - folderPath: %s, animationType: %s",
                        tostring(weaponBaseData.animationFolderPath),
                        tostring(weaponBaseData.animationType)))

                self.playerSprite.appearance.weapon = {
                    folderPath = weaponBaseData.animationFolderPath,
                    animationType = weaponBaseData.animationType
                }
            else
                Logger.warn("player_sprite_controller.debug.weapon_data_missing",
                    "[DEBUG] Weapon base data not found for: " .. tostring(weapon.itemBaseId))
            end

            -- Depois, os outros itens
            for slotId, item in pairs(allEquipped) do
                if item and item.itemBaseId ~= weapon.itemBaseId then
                    local itemBaseData = self.itemDataService:getBaseItemData(item.itemBaseId)
                    if itemBaseData then
                        self.playerSprite.appearance.equipment[slotId] = itemBaseData.animationFolderPath
                    end
                end
            end
        else
            Logger.warn("player_sprite_controller.debug.no_weapon",
                "[DEBUG] No weapon found in allEquipped")
        end
    else
        -- DEBUG: Log para mudanças específicas de slot
        Logger.info("player_sprite_controller.debug.slot_change",
            string.format("[DEBUG] Slot specific change - slotId: %s", tostring(event.slotId)))

        -- Verifico se o newItem é nulo, se for nulo, significa que o item foi desequipado
        local slotId = event.slotId
        if not event.newItem then
            Logger.info("player_sprite_controller.debug.unequip",
                string.format("[DEBUG] Unequipping item from slot: %s", tostring(slotId)))

            if slotId == Constants.SLOT_IDS.WEAPON then
                self.playerSprite.appearance.weapon = {
                    folderPath = nil,
                    animationType = nil
                }
            else
                self.playerSprite.appearance.equipment[slotId] = nil
            end
        else
            local newItem = event.newItem
            Logger.info("player_sprite_controller.debug.equip",
                string.format("[DEBUG] Equipping item - slotId: %s, itemBaseId: %s",
                    tostring(slotId), tostring(newItem.itemBaseId)))

            local itemBaseData = self.itemDataService:getBaseItemData(newItem.itemBaseId)
            if itemBaseData then
                Logger.info("player_sprite_controller.debug.item_data",
                    string.format("[DEBUG] Item data found - folderPath: %s, animationType: %s",
                        tostring(itemBaseData.animationFolderPath),
                        tostring(itemBaseData.animationType)))

                -- CORREÇÃO: Verificar slotId ao invés de itemBaseId
                if slotId == Constants.SLOT_IDS.WEAPON then
                    self.playerSprite.appearance.weapon = {
                        folderPath = itemBaseData.animationFolderPath,
                        animationType = itemBaseData.animationType
                    }
                else
                    self.playerSprite.appearance.equipment[slotId] = itemBaseData.animationFolderPath
                end
            else
                Logger.warn("player_sprite_controller.debug.item_data_missing",
                    "[DEBUG] Item base data not found for: " .. tostring(newItem.itemBaseId))
            end
        end
    end

    -- DEBUG: Log do estado final da aparência
    if self.playerSprite and self.playerSprite.appearance then
        Logger.info("player_sprite_controller.debug.final_appearance",
            string.format("[DEBUG] Final weapon appearance - folderPath: %s, animationType: %s",
                tostring(self.playerSprite.appearance.weapon.folderPath),
                tostring(self.playerSprite.appearance.weapon.animationType)))
    end
end

---@private Cria a instância do sprite do jogador com base na aparência fornecida.
--- Chamado pelo PlayerManager durante a inicialização.
---@param skinTone string
function PlayerSpriteController:_setupSprite(skinTone)
    assert(skinTone, "PlayerSpriteController:_setupSprite requer um skinTone")

    -- O sprite é criado na origem do mundo (0,0).
    -- A posição real será definida pelo MovementController.
    local spritePosition = {
        x = 0,
        y = 0
    }

    local appearance = {
        skinTone = skinTone,
        equipment = { bag = nil, belt = nil, chest = nil, head = nil, leg = nil, shoe = nil },
        weapon = { folderPath = nil, animationType = nil }
    }

    self.playerSprite = SpritePlayer.newConfig({
        position = spritePosition,
        scale = Constants.PLAYER_SCALE,
        appearance = appearance
    })

    self.playerSprite.velocity = { x = 0, y = 0 }

    Logger.info(
        "PlayerSpriteController:setupSprite",
        "Sprite do jogador criado com sucesso. Posição inicial: (" ..
        string.format("%.1f,%.1f", spritePosition.x, spritePosition.y) ..
        ") | Escala: " .. Constants.PLAYER_SCALE,
        true -- Mostra na tela
    )
end

---@public Destrói o sprite do jogador.
function PlayerSpriteController:destroy()
    Logger.info("player_sprite_controller.destroy", "[PlayerSpriteController:destroy] Destroying...")
    self.playerSprite = nil
    for _, listener in pairs(self.eventListeners) do
        self.eventService:off(listener.event, listener.id)
    end

    self.eventListeners = {}
end

return PlayerSpriteController
