-------------------------------------------------------------------------
-- Controlador para gerenciar textos flutuantes do jogador.
-- Responsável por criar, atualizar e desenhar textos flutuantes.
-------------------------------------------------------------------------

local FloatingText = require("src.entities.floating_text")
local Camera = require("src.config.camera")

---@class FloatingTextController
---@field playerManager PlayerManager Referência ao PlayerManager
---@field activeFloatingTexts FloatingText[] Lista de textos flutuantes ativos
local FloatingTextController = {}
FloatingTextController.__index = FloatingTextController

--- Cria uma nova instância do FloatingTextController.
---@param playerManager PlayerManager A instância do PlayerManager
---@return FloatingTextController
function FloatingTextController:new(playerManager)
    Logger.debug(
        "floating_text_controller.new",
        "[FloatingTextController:new] Inicializando controlador de textos flutuantes"
    )

    local instance = setmetatable({}, FloatingTextController)

    instance.playerManager = playerManager
    instance.activeFloatingTexts = {}

    return instance
end

--- Atualiza todos os textos flutuantes ativos
---@param dt number Delta time
function FloatingTextController:update(dt)
    if not self.activeFloatingTexts then return end

    -- Atualiza textos flutuantes de trás para frente para permitir remoção segura
    for i = #self.activeFloatingTexts, 1, -1 do
        local textInstance = self.activeFloatingTexts[i]
        if not textInstance:update(dt) then -- update retorna false se deve ser removido
            table.remove(self.activeFloatingTexts, i)
            Logger.debug(
                "floating_text_controller.remove",
                string.format("[FloatingTextController:update] Texto flutuante removido (índice %d)", i)
            )
        end
    end
end

--- Adiciona um novo texto flutuante ao jogador
---@param text string Texto a ser exibido
---@param props table Propriedades do texto flutuante
function FloatingTextController:addFloatingText(text, props)
    if not self.playerManager.player or not self.playerManager.player.position then
        Logger.warn(
            "floating_text_controller.add.no_player",
            "[FloatingTextController:addFloatingText] Tentativa de adicionar texto sem jogador válido"
        )
        return
    end

    -- Empilhamento básico (similar ao do inimigo)
    local stackOffsetY = #self.activeFloatingTexts * -15 -- Empilha para cima

    -- Converte posição do mundo para tela
    local screenX, screenY = Camera:worldToScreen(
        self.playerManager.player.position.x,
        self.playerManager.player.position.y
    )

    local textInstance = FloatingText:new(
        { x = screenX, y = screenY },
        text,
        props,
        0,           -- initialDelay
        stackOffsetY -- initialStackOffsetY
    )

    table.insert(self.activeFloatingTexts, textInstance)

    Logger.debug(
        "floating_text_controller.add",
        string.format("[FloatingTextController:addFloatingText] Texto '%s' adicionado (total: %d)",
            text, #self.activeFloatingTexts)
    )
end

--- Desenha todos os textos flutuantes ativos
function FloatingTextController:draw()
    if not self.activeFloatingTexts then return end

    for _, textInstance in ipairs(self.activeFloatingTexts) do
        textInstance:draw()
    end
end

--- Limpa todos os textos flutuantes ativos
function FloatingTextController:clear()
    Logger.debug(
        "floating_text_controller.clear",
        string.format("[FloatingTextController:clear] Limpando %d textos flutuantes", #self.activeFloatingTexts)
    )

    self.activeFloatingTexts = {}
end

--- Obtém o número de textos flutuantes ativos
---@return number
function FloatingTextController:getActiveCount()
    return #self.activeFloatingTexts
end

--- Verifica se há textos flutuantes ativos
---@return boolean
function FloatingTextController:hasActiveTexts()
    return #self.activeFloatingTexts > 0
end

--- Remove textos flutuantes por tipo específico (útil para limpeza seletiva)
---@param textType string|nil Tipo de texto a ser removido (se nil, remove todos)
function FloatingTextController:removeTextsByType(textType)
    if not textType then
        self:clear()
        return
    end

    local removedCount = 0
    for i = #self.activeFloatingTexts, 1, -1 do
        local textInstance = self.activeFloatingTexts[i]
        if textInstance.type == textType then
            table.remove(self.activeFloatingTexts, i)
            removedCount = removedCount + 1
        end
    end

    Logger.debug(
        "floating_text_controller.remove_by_type",
        string.format("[FloatingTextController:removeTextsByType] Removidos %d textos do tipo '%s'",
            removedCount, textType)
    )
end

--- Adiciona um texto de dano ao jogador
---@param damageAmount number Quantidade de dano
---@param isCritical boolean|nil Se o dano foi crítico
function FloatingTextController:addDamageText(damageAmount, isCritical)
    local Colors = require("src.ui.colors")
    local TablePool = require("src.utils.table_pool")

    local props = TablePool.get()
    props.textColor = Colors.damage_player
    props.scale = isCritical and 1.3 or 1.1
    props.velocityY = -45
    props.lifetime = 0.9
    props.isCritical = isCritical or false
    props.baseOffsetY = -40
    props.baseOffsetX = 0
    props.type = "damage"

    self:addFloatingText("-" .. tostring(damageAmount), props)
    TablePool.release(props)
end

--- Adiciona um texto de cura ao jogador
---@param healAmount number Quantidade de cura
---@param healType string|nil Tipo de cura ("regen", "potion", etc.)
function FloatingTextController:addHealText(healAmount, healType)
    local Colors = require("src.ui.colors")
    local TablePool = require("src.utils.table_pool")

    local props = TablePool.get()
    props.textColor = Colors.heal
    props.scale = 1.1
    props.velocityY = -30
    props.lifetime = 1.0
    props.baseOffsetY = -40
    props.baseOffsetX = 0
    props.type = "heal"

    local text = "+" .. tostring(healAmount) .. " HP"
    if healType then
        text = text .. " (" .. healType .. ")"
    end

    self:addFloatingText(text, props)
    TablePool.release(props)
end

--- Adiciona um texto de level up
function FloatingTextController:addLevelUpText()
    local TablePool = require("src.utils.table_pool")

    local props = TablePool.get()
    props.color = { 1, 1, 1 }
    props.scale = 1.5
    props.velocityY = -30
    props.lifetime = 1.0
    props.baseOffsetY = -40
    props.type = "levelup"

    self:addFloatingText("LEVEL UP!", props)
    TablePool.release(props)
end

--- Obtém informações de debug sobre os textos ativos
---@return table
function FloatingTextController:getDebugInfo()
    local typeCount = {}
    for _, textInstance in ipairs(self.activeFloatingTexts) do
        local textType = textInstance.type or "unknown"
        typeCount[textType] = (typeCount[textType] or 0) + 1
    end

    return {
        totalActive = #self.activeFloatingTexts,
        byType = typeCount
    }
end

return FloatingTextController
