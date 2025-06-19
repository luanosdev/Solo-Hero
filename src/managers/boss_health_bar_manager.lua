local BossHPBar = require("src.ui.components.BossHPBar")

---@class BossHealthBarManager
---@field activeBars table<number, BossHPBar> Mapa de barras ativas, usando o ID do boss como chave.
---@field barOrder table<number> Lista de IDs de bosses na ordem em que devem ser desenhados.
local BossHealthBarManager = {
    activeBars = {},
    barOrder = {},
}

function BossHealthBarManager:init()
    self:destroy()
    print("BossHealthBarManager inicializado.")
end

--- Adiciona uma barra de vida para um novo chefe.
---@param boss BaseBoss O chefe que acabou de ser spawnado.
function BossHealthBarManager:addBoss(boss)
    if not boss or not boss.id then
        Logger.warn("[BossHealthBarManager]", "Tentativa de adicionar boss inválido ou sem ID.")
        return
    end
    if self.activeBars[boss.id] then
        Logger.warn("[BossHealthBarManager]", "Tentativa de adicionar boss que já possui uma barra de vida ativa.")
        return
    end

    local initialY = 20 -- Posição Y inicial para a primeira barra
    local newBar = BossHPBar:new(boss, initialY)

    self.activeBars[boss.id] = newBar
    table.insert(self.barOrder, boss.id)
    self:repositionBars()

    Logger.info("[BossHealthBarManager]", "Barra de vida adicionada para o boss: " .. boss.name)
end

--- Inicia a animação de apresentação da barra de vida de um chefe.
---@param boss BaseBoss O chefe cuja apresentação está começando.
function BossHealthBarManager:startPresentation(boss)
    if boss and self.activeBars[boss.id] then
        self.activeBars[boss.id]:show()
    end
end

function BossHealthBarManager:update(dt)
    -- Itera de trás para frente para permitir remoção segura
    for i = #self.barOrder, 1, -1 do
        local bossId = self.barOrder[i]
        local bar = self.activeBars[bossId]

        if bar then
            bar:update(dt)
            if bar:isFinished() then
                self.activeBars[bossId] = nil
                table.remove(self.barOrder, i)
                self:repositionBars()
            end
        else
            -- Limpeza caso o ID exista em barOrder mas não em activeBars
            table.remove(self.barOrder, i)
            self:repositionBars()
        end
    end
end

function BossHealthBarManager:draw()
    for _, bossId in ipairs(self.barOrder) do
        local bar = self.activeBars[bossId]
        if bar then
            bar:draw()
        end
    end
end

--- Reposiciona as barras na tela, empilhando-as.
function BossHealthBarManager:repositionBars()
    local currentY = 20
    local spacing = 15

    for _, bossId in ipairs(self.barOrder) do
        local bar = self.activeBars[bossId]
        if bar then
            bar:setY(currentY)
            currentY = currentY + bar:getHeight() + spacing
        end
    end
end

function BossHealthBarManager:destroy()
    self.activeBars = {}
    self.barOrder = {}
    print("BossHealthBarManager destruído.")
end

return BossHealthBarManager
