------------------------------------------------------------------------------------------------
--- Módulo para gerenciar efeitos de câmera como shake, pan e zoom.
------------------------------------------------------------------------------------------------

local Camera = require("src.config.camera")
local lume = require("src.libs.lume")

---@class CameraEffects
local CameraEffects = {}
CameraEffects.__index = CameraEffects

--- Cria uma nova instância do gerenciador de efeitos de câmera.
--- @return CameraEffects
function CameraEffects:new()
    ---@type CameraEffects
    local instance = setmetatable({}, CameraEffects)
    instance.effects = {}
    instance.isPanning = false
    instance.isZooming = false
    instance.isShaking = false
    instance.originalCameraTarget = nil
    instance.isManualControl = false
    return instance
end

--- Atualiza todos os efeitos de câmera ativos.
--- @param dt number Delta time.
function CameraEffects:update(dt)
    self.isManualControl = self:isActive()

    -- Update Shake
    local shakeEffect = self.effects.shake
    if shakeEffect then
        shakeEffect.elapsed = shakeEffect.elapsed + dt
        if shakeEffect.elapsed >= shakeEffect.duration then
            self.effects.shake = nil
            self.isShaking = false
            Camera.offsetX = 0
            Camera.offsetY = 0
        else
            local progress = shakeEffect.elapsed / shakeEffect.duration
            local currentMagnitude = shakeEffect.magnitude * (1 - progress) -- Diminish over time
            Camera.offsetX = (math.random() * 2 - 1) * currentMagnitude
            Camera.offsetY = (math.random() * 2 - 1) * currentMagnitude
        end
    end

    -- Update Pan
    local panEffect = self.effects.pan
    if panEffect then
        panEffect.elapsed = panEffect.elapsed + dt
        local progress = math.min(1, panEffect.elapsed / panEffect.duration)

        -- O alvo da câmera é o canto superior esquerdo da tela.
        -- Para centralizar um ponto (targetX, targetY), a câmera deve ir para:
        -- targetX - (largura_tela / escala / 2)
        local targetCamX = panEffect.targetX - (Camera.screenWidth / (2 * Camera.scale))
        local targetCamY = panEffect.targetY - (Camera.screenHeight / (2 * Camera.scale))

        Camera.x = lume.smooth(panEffect.startX, targetCamX, progress)
        Camera.y = lume.smooth(panEffect.startY, targetCamY, progress)

        if progress >= 1 then
            self.effects.pan = nil
            self.isPanning = false
        end
    end

    -- Update Zoom
    local zoomEffect = self.effects.zoom
    if zoomEffect then
        zoomEffect.elapsed = zoomEffect.elapsed + dt
        local progress = math.min(1, zoomEffect.elapsed / zoomEffect.duration)

        Camera.scale = lume.smooth(zoomEffect.startScale, zoomEffect.targetScale, progress)

        if progress >= 1 then
            self.effects.zoom = nil
            self.isZooming = false
        end
    end
end

--- Inicia um efeito de tremor na câmera.
--- @param duration number Duração do tremor em segundos.
--- @param magnitude number Força do tremor.
function CameraEffects:shake(duration, magnitude)
    self.isShaking = true
    self.effects.shake = {
        duration = duration,
        magnitude = magnitude,
        elapsed = 0
    }
end

--- Move a câmera suavemente para um ponto no mundo.
--- @param targetX number Coordenada X do alvo.
--- @param targetY number Coordenada Y do alvo.
--- @param duration number Duração da movimentação.
function CameraEffects:panTo(targetX, targetY, duration)
    self.isPanning = true
    self.effects.pan = {
        startX = Camera.x,
        startY = Camera.y,
        targetX = targetX, -- Coordenadas do mundo para focar
        targetY = targetY,
        duration = duration,
        elapsed = 0
    }
end

--- Altera o zoom da câmera suavemente.
--- @param targetScale number Nível de zoom alvo.
--- @param duration number Duração da transição de zoom.
function CameraEffects:zoomTo(targetScale, duration)
    self.isZooming = true
    self.effects.zoom = {
        startScale = Camera.scale,
        targetScale = targetScale,
        duration = duration,
        elapsed = 0
    }
end

--- Move e aplica zoom na câmera simultaneamente.
--- @param targetX number Coordenada X do alvo.
--- @param targetY number Coordenada Y do alvo.
--- @param targetScale number Nível de zoom alvo.
--- @param duration number Duração da transição.
function CameraEffects:panAndZoomTo(targetX, targetY, targetScale, duration)
    self:panTo(targetX, targetY, duration)
    self:zoomTo(targetScale, duration)
end

--- Restaura a câmera para o alvo original e zoom padrão.
--- @param duration number Duração da transição de retorno.
function CameraEffects:restore(duration)
    if self.originalCameraTarget and self.originalCameraTarget.position then
        self:panTo(self.originalCameraTarget.position.x, self.originalCameraTarget.position.y, duration)
    end
    self:zoomTo(Camera.defaultScale, duration) -- Retorna ao zoom normal
end

--- Verifica se algum efeito está ativo.
--- @return boolean
function CameraEffects:isActive()
    return self.isPanning or self.isZooming or self.isShaking
end

--- Para todos os efeitos e limpa o estado.
function CameraEffects:stop()
    self.effects = {}
    self.isPanning, self.isZooming, self.isShaking = false, false, false
    Camera.offsetX, Camera.offsetY = 0, 0
    self.isManualControl = false
end

return CameraEffects
