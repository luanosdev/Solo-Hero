------------------------------------------------------------------------------------------------
-- Gerencia a cena de apresentação de um boss.
------------------------------------------------------------------------------------------------

local CameraEffects = require("src.utils.camera_effects")
local BossHealthBar = require("src.ui.boss_health_bar")
local Colors = require("src.ui.colors")

---@class BossPresentationManager
local BossPresentationManager = {}
BossPresentationManager.__index = BossPresentationManager

-- Estados da apresentação
local PRESENTATION_STATE = {
    INACTIVE = "inactive",
    PAN_TO_BOSS = "pan_to_boss",
    SHOWCASE = "showcase",
    PAN_TO_PLAYER = "pan_to_player"
}

--- Cria uma nova instância do gerenciador.
--- @return BossPresentationManager
function BossPresentationManager:new()
    ---@type BossPresentationManager
    local instance = setmetatable({}, BossPresentationManager)
    instance.cameraEffects = CameraEffects:new()
    instance.state = PRESENTATION_STATE.INACTIVE
    instance.boss = nil
    instance.playerManager = nil
    instance.timer = 0
    instance.showcaseDuration = 3 -- Duração da cena de showcase (em segundos)
    return instance
end

--- Inicia a apresentação de um boss.
--- @param boss BaseBoss O boss a ser apresentado.
--- @param playerManager PlayerManager A instância do player manager.
function BossPresentationManager:start(boss, playerManager)
    if self:isActive() then return end

    Logger.info("[BossPresentationManager]", " Iniciando apresentação para: " .. (boss.name or "Boss"))
    self.boss = boss
    self.playerManager = playerManager
    self.state = PRESENTATION_STATE.PAN_TO_BOSS
    self.timer = 0
    self.boss.isPresented = true -- Marca como apresentado para não triggar de novo

    -- Salva o alvo original da câmera (o jogador) e inicia o pan/zoom
    self.cameraEffects.originalCameraTarget = self.playerManager.player
    self.cameraEffects:panAndZoomTo(self.boss.position.x, self.boss.position.y, 1.2, 1.5)
end

--- Atualiza a lógica da apresentação.
--- @param dt number Delta time.
function BossPresentationManager:update(dt)
    if not self:isActive() then return end

    self.timer = self.timer + dt
    self.cameraEffects:update(dt)

    if self.state == PRESENTATION_STATE.PAN_TO_BOSS then
        if not self.cameraEffects:isActive() then
            self.state = PRESENTATION_STATE.SHOWCASE
            self.timer = 0
            -- Boss executa a animação de "taunt"
            if self.boss.taunt then self.boss:taunt() end
            -- Inicia o tremor da câmera
            self.cameraEffects:shake(1, 4)
            -- Mostra a barra de vida
            BossHealthBar:show(self.boss)
        end
    elseif self.state == PRESENTATION_STATE.SHOWCASE then
        if self.timer >= self.showcaseDuration then
            self.state = PRESENTATION_STATE.PAN_TO_PLAYER
            self.timer = 0
            -- Inicia o retorno da câmera para o jogador
            self.cameraEffects:restore(1.0)
            BossHealthBar:hide() -- Esconde a barra temporariamente até o boss se tornar ativo
        end
    elseif self.state == PRESENTATION_STATE.PAN_TO_PLAYER then
        if not self.cameraEffects:isActive() then
            -- Apresentação concluída
            self:finish()
        end
    end
end

--- Desenha elementos da apresentação (como a tarja preta).
function BossPresentationManager:draw()
    if not self:isActive() then return end

    -- Desenha um overlay escuro
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1, 1)

    -- Mostra a barra de vida do boss durante a apresentação
    if self.state == PRESENTATION_STATE.SHOWCASE or self.state == PRESENTATION_STATE.PAN_TO_BOSS then
        BossHealthBar:show(self.boss)
    end
end

--- Finaliza a apresentação e restaura o estado do jogo.
function BossPresentationManager:finish()
    Logger.info("[BossPresentationManager]", "Apresentação finalizada.")
    if self.boss then
        self.boss.isPresentationFinished = true -- Libera o boss para atacar
        self.boss.isImmobile = false            -- Garante que o boss possa se mover novamente
    end

    self.state = PRESENTATION_STATE.INACTIVE
    self.boss = nil
    self.playerManager = nil
    self.cameraEffects:stop()
    BossHealthBar:hide()
end

--- Verifica se a apresentação está ativa.
--- @return boolean
function BossPresentationManager:isActive()
    return self.state ~= PRESENTATION_STATE.INACTIVE
end

return BossPresentationManager
