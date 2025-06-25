---------------------------------------------------
--- GameOverManager
--- Gerencia o estado e a lógica da tela de Game Over.
---------------------------------------------------

local gameOverMessagesData = require("src.data.game_over_messages_data")
local ArchetypesData = require("src.data.archetypes_data")
local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local helpers = require("src.utils.helpers")

---@class GameOverManager
local GameOverManager = {}
GameOverManager.__index = GameOverManager

--- Cria uma nova instância do GameOverManager.
--- @return GameOverManager
function GameOverManager.new()
    ---@class GameOverManager
    local instance = setmetatable({}, GameOverManager)
    instance.registry = nil ---@type ManagerRegistry
    instance.sceneManager = nil -- Será injetado via init

    instance.isGameOverActive = false
    instance.timer = 0
    instance.duration = 5 -- Duração do escurecimento + tempo de mensagem antes de poder sair

    instance.message = ""
    instance.hunterName = ""
    instance.hunterRank = ""
    instance.timestamp = ""
    instance.portalData = nil -- Armazena os dados do portal para o cálculo de reputação
    instance.deathCause = nil -- Causa da morte

    -- Dados para a cena de resumo
    instance.finalStats = nil
    instance.gameplayStats = nil
    instance.archetypeIds = nil
    instance.archetypeManagerInstance = nil
    instance.extractedEquipment = nil
    instance.hunterId = nil

    instance.footerMessage = "Aperte qualquer tecla para continuar"
    instance.lossMessage = "Você perdeu seu caçador e todos os seus itens."

    instance.canExit = false
    instance.fadeAlpha = 0
    instance.messageAlpha = 0
    instance.footerAlpha = 0
    instance.footerBlinkTimer = 0

    instance.showLossMessage = false
    instance.lossMessageTimer = 0
    instance.lossMessageDelay = 1.5 -- Tempo para a msg de perda aparecer após o início do game over

    -- Efeitos Visuais
    instance.mainMessageColor = { r = 1, g = 1, b = 1 }
    instance.colorAnimDuration = 3.0 -- Duração da animação de cor

    -- Histórico de mortes
    instance.deathHistory = {}

    Logger.debug("GameOverManager", "Instância criada.")
    return instance
end

--- Inicializa o manager com dependências necessárias.
--- @param registry ManagerRegistry A instância do registro de managers.
--- @param sceneMgr SceneManager A instância do gerenciador de cenas.
function GameOverManager:init(registry, sceneMgr)
    self.registry = registry
    self.sceneManager = sceneMgr
    Logger.debug("GameOverManager", "Inicializado com Registry e SceneManager.")
end

--- Reseta o estado de Game Over.
function GameOverManager:reset()
    self.isGameOverActive = false
    self.timer = 0
    self.message = ""
    self.hunterName = ""
    self.hunterRank = ""
    self.timestamp = ""
    self.portalData = nil
    self.deathCause = nil
    self.canExit = false
    self.fadeAlpha = 0
    self.messageAlpha = 0
    self.footerAlpha = 0
    self.footerBlinkTimer = 0
    self.showLossMessage = false
    self.mainMessageColor = { r = 1, g = 1, b = 1 } -- Reseta a cor
    -- Não reseta o histórico de mortes aqui, deve ser feito explicitamente
    Logger.debug("GameOverManager", "Estado resetado.")
end

--- Seleciona uma mensagem de Game Over com base nos arquétipos do jogador.
--- @return string A mensagem selecionada.
function GameOverManager:_selectMessage()
    local playerManager = self.registry:get("playerManager")
    local hunterManager = self.registry:get("hunterManager")
    local hunterId = playerManager and playerManager:getCurrentHunterId()
    local archetypes = {}

    if hunterId and hunterManager and hunterManager.getArchetypeIds then
        archetypes = hunterManager:getArchetypeIds(hunterId) or {}
    end

    local possibleMessages = {}
    if gameOverMessagesData then
        -- Tenta usar mensagens de arquétipo primeiro
        for _, archetypeId in ipairs(archetypes) do
            local archetypeKey = string.lower(tostring(archetypeId))
            if gameOverMessagesData[archetypeKey] then
                for _, msg in ipairs(gameOverMessagesData[archetypeKey]) do table.insert(possibleMessages, msg) end
            end
        end
        -- Se não houver mensagens de arquétipo ou aleatoriamente, usa as genéricas
        if #possibleMessages == 0 or math.random() < 0.5 then
            if gameOverMessagesData.generic then
                for _, msg in ipairs(gameOverMessagesData.generic) do table.insert(possibleMessages, msg) end
            end
        end
    end
    if #possibleMessages == 0 then
        Logger.warn("GameOverManager", "Nenhuma mensagem de morte encontrada, usando fallback.")
        return "Você morreu."
    end
    return possibleMessages[math.random(#possibleMessages)]
end

--- Ativa e configura a tela de Game Over.
--- @param portalData table Os dados do portal onde o jogador morreu.
--- @param deathCause string A causa da morte.
function GameOverManager:start(portalData, deathCause)
    if self.isGameOverActive then return end
    Logger.info("GameOverManager", "GAME OVER acionado!")
    self:reset()                       -- Garante um estado limpo antes de começar
    self.isGameOverActive = true
    self.portalData = portalData or {} -- Armazena os dados do portal
    self.deathCause = deathCause or "Causa Desconhecida"

    local playerManager = self.registry:get("playerManager") ---@type PlayerManager
    local hunterManager = self.registry:get("hunterManager") ---@type HunterManager
    local gameStatisticsManager = self.registry:get("gameStatisticsManager") ---@type GameStatisticsManager
    local archetypeManager = self.registry:get("archetypeManager") ---@type ArchetypeManager

    self.hunterId = playerManager:getCurrentHunterId()
    self.finalStats = playerManager:getCurrentFinalStats()
    self.archetypeIds = playerManager.stateController.archetypeIds
    self.gameplayStats = gameStatisticsManager:getRawStats()
    self.archetypeManagerInstance = archetypeManager
    self.extractedEquipment = playerManager:getCurrentEquipmentGameplay()

    self.message = self:_selectMessage()

    local hunterData = hunterManager:getHunterData(self.hunterId)
    if hunterData then
        self.hunterName = hunterData.name or "Caçador Desconhecido"
        if hunterData.finalRankId and ArchetypesData and ArchetypesData.Ranks and ArchetypesData.Ranks[hunterData.finalRankId] then
            self.hunterRank = ArchetypesData.Ranks[hunterData.finalRankId].name or hunterData.finalRankId
        else
            self.hunterRank = hunterData.finalRankId or "Rank Desconhecido"
        end
    else
        self.hunterName = "Caçador Anônimo"
        self.hunterRank = "Rank Indefinido"
        Logger.warn("GameOverManager:start", "Não foi possível obter dados do HunterManager.")
    end

    self.timestamp = os.date("Hora da morte: %d/%m/%Y %H:%M:%S")

    -- Adiciona ao histórico de mortes
    if hunterData then
        local deathRecord = {
            hunterData = hunterData,
            portalData = self.portalData,
            deathTime = love.timer.getTime(),
            deathReason = self.message, -- Usa a mensagem aleatória
            deathCause = self.deathCause,
            level = playerManager.stateController:getCurrentLevel(),
            finalStats = self.finalStats,
            gameplayStats = self.gameplayStats
        }
        table.insert(self.deathHistory, deathRecord)
        Logger.debug("GameOverManager", "Registro de morte adicionado ao histórico.")
    end
end

--- Atualiza a lógica da tela de Game Over.
--- @param dt number Delta time.
function GameOverManager:update(dt)
    if not self.isGameOverActive then return end

    self.timer = self.timer + dt

    -- Lógica de fade-in para o fundo e a mensagem
    local fadeEffectDuration = self.duration * 0.6
    if self.timer < fadeEffectDuration then
        self.fadeAlpha = math.min(1, self.timer / fadeEffectDuration)
    else
        self.fadeAlpha = 1
    end

    local messageAppearanceDelay = fadeEffectDuration * 0.3
    local messageFadeInTime = fadeEffectDuration * 0.5
    if self.timer > messageAppearanceDelay then
        self.messageAlpha = math.min(1, (self.timer - messageAppearanceDelay) / messageFadeInTime)
    else
        self.messageAlpha = 0
    end

    -- Lógica para mostrar mensagem de perda
    if not self.showLossMessage and self.timer > self.lossMessageDelay then
        self.showLossMessage = true
    end

    -- Lógica para habilitar a saída
    if not self.canExit and self.timer >= self.duration then
        self.canExit = true
        Logger.debug("GameOverManager", "Agora pode sair da tela de Game Over.")
    end

    -- Animação de cor da mensagem principal
    if self.timer > messageAppearanceDelay then
        local startColor = colors.text_title or { 1, 1, 1 }
        local endColor = { 1, 0.1, 0.1 } -- Vermelho Sangue
        local animProgress = math.min(1, (self.timer - messageAppearanceDelay) / self.colorAnimDuration)

        self.mainMessageColor.r = helpers.lerp(startColor[1], endColor[1], animProgress)
        self.mainMessageColor.g = helpers.lerp(startColor[2], endColor[2], animProgress)
        self.mainMessageColor.b = helpers.lerp(startColor[3], endColor[3], animProgress)
    end

    -- Lógica para piscar o texto do rodapé
    if self.canExit then
        self.footerBlinkTimer = self.footerBlinkTimer + dt
        local blinkRate = math.pi * 2
        self.footerAlpha = (math.sin(self.footerBlinkTimer * blinkRate) + 1) / 2
    else
        self.footerAlpha = 0
    end
end

--- Desenha a tela de Game Over.
function GameOverManager:draw()
    if not self.isGameOverActive then return end

    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local currentY = 0

    love.graphics.setColor(0, 0, 0, self.fadeAlpha * 0.85)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

    local mainMessageFont = fonts.game_over or fonts.title_large or fonts.title
    local detailFont = fonts.main_large or fonts.main
    local footerFont = fonts.main_large or fonts.main

    -- Estimar altura total para centralização
    local estimatedTotalHeight = 0
    local wrappedLines = {}
    if self.message ~= "" then
        _, wrappedLines = mainMessageFont:getWrap(self.message, screenWidth * 0.8)
        estimatedTotalHeight = estimatedTotalHeight + mainMessageFont:getHeight() * #wrappedLines
    end
    estimatedTotalHeight = estimatedTotalHeight + detailFont:getHeight() * 2 + 25
    if self.deathCause and self.deathCause ~= "" and self.deathCause ~= "Causa Desconhecida" then
        estimatedTotalHeight = estimatedTotalHeight + detailFont:getHeight() + 5
    end
    if self.showLossMessage then estimatedTotalHeight = estimatedTotalHeight + detailFont:getHeight() + 20 end

    currentY = (screenHeight / 2) - (estimatedTotalHeight / 2)

    -- Desenha a mensagem principal com contorno e cor animada
    if mainMessageFont and self.messageAlpha > 0 and self.message ~= "" then
        love.graphics.setFont(mainMessageFont)
        local outlineOffset = 2
        local outlineAlpha = self.messageAlpha * 0.7

        local lineY = currentY
        for _, line in ipairs(wrappedLines) do
            local lineWidth = mainMessageFont:getWidth(line)
            local lineX = (screenWidth - lineWidth) / 2

            -- Desenha o contorno
            love.graphics.setColor(0, 0, 0, outlineAlpha)
            love.graphics.print(line, lineX - outlineOffset, lineY)
            love.graphics.print(line, lineX + outlineOffset, lineY)
            love.graphics.print(line, lineX, lineY - outlineOffset)
            love.graphics.print(line, lineX, lineY + outlineOffset)

            -- Desenha o texto principal com cor animada
            love.graphics.setColor(self.mainMessageColor.r, self.mainMessageColor.g, self.mainMessageColor.b,
                self.messageAlpha)
            love.graphics.print(line, lineX, lineY)

            lineY = lineY + mainMessageFont:getHeight()
        end
        currentY = lineY
    end

    currentY = currentY + 20

    -- Desenha os detalhes
    if detailFont and self.messageAlpha > 0 then
        love.graphics.setFont(detailFont)
        love.graphics.setColor(colors.text_main[1] or 0.8, colors.text_main[2] or 0.8, colors.text_main[3] or 0.8,
            self.messageAlpha)

        local hunterInfo = string.format("%s, %s", self.hunterName, self.hunterRank)
        love.graphics.printf(hunterInfo, 0, currentY, screenWidth, "center")
        currentY = currentY + detailFont:getHeight() + 5

        love.graphics.printf(self.timestamp, 0, currentY, screenWidth, "center")
        currentY = currentY + detailFont:getHeight() + 5

        -- Desenha a causa da morte
        if self.deathCause and self.deathCause ~= "" and self.deathCause ~= "Causa Desconhecida" then
            love.graphics.setColor(colors.text_highlight[1] or 1, colors.text_highlight[2] or 0.1,
                colors.text_highlight[3] or 0.1, self.messageAlpha)
            love.graphics.printf("Causa: " .. self.deathCause, 0, currentY, screenWidth, "center")
            currentY = currentY + detailFont:getHeight()
        end

        currentY = currentY + 20
    end

    -- Desenha a mensagem de perda
    if detailFont and self.showLossMessage and self.messageAlpha > 0 then
        love.graphics.setFont(detailFont)
        love.graphics.setColor(colors.red[1] or 0.9, colors.red[2] or 0.5, colors.red[3] or 0.5, self.messageAlpha)
        love.graphics.printf(self.lossMessage, 0, currentY, screenWidth, "center")
    end

    -- Desenha o rodapé
    if footerFont and self.canExit and self.footerAlpha > 0 then
        love.graphics.setFont(footerFont)
        love.graphics.setColor(colors.text_highlight[1] or 1, colors.text_highlight[2] or 0.1,
            colors.text_highlight[3] or 0.1, self.footerAlpha)
        love.graphics.printf(self.footerMessage, 0, screenHeight - 80, screenWidth, "center")
    end

    love.graphics.setFont(fonts.main or love.graphics.getFont()) -- Reseta a fonte principal
    love.graphics.setColor(1, 1, 1, 1)
end

--- Lida com o input do teclado.
function GameOverManager:keypressed(key, scancode, isrepeat)
    if self.isGameOverActive and self.canExit and not isrepeat then
        self:handleExit()
    end
end

--- Lida com a saída da tela de Game Over para a tela de Resumo.
function GameOverManager:handleExit()
    if not self.canExit then return end

    Logger.info("GameOverManager", "Saindo da tela de Game Over para a tela de Resumo.")

    local hunterManager = self.registry:get("hunterManager") ---@type HunterManager
    local hunterData = hunterManager:getHunterData(self.hunterId)

    -- Deleta o caçador permanentemente
    if hunterManager.deleteHunter then
        hunterManager:deleteHunter(self.hunterId)
        Logger.info("GameOverManager",
            string.format("Caçador %s (ID: %s) foi permanentemente deletado.", self.hunterName, self.hunterId))
    end

    local params = {
        wasSuccess = false,
        hunterData = hunterData,
        portalData = self.portalData,
        extractedItems = {},     -- Nenhum item vai para o loadout
        extractedEquipment = {}, -- Nenhum equipamento é salvo
        finalStats = self.finalStats,
        gameplayStats = self.gameplayStats,
        archetypeIds = self.archetypeIds,
        archetypeManagerInstance = self.archetypeManagerInstance,
        lootedItems = {} -- Nenhum item é extraído na morte
    }

    self.sceneManager.switchScene("extraction_summary_scene", params)
    self:reset()
end

--- Retorna o histórico de mortes.
---@return table[] Lista de registros de morte.
function GameOverManager:getDeathHistory()
    return self.deathHistory
end

--- Limpa o histórico de mortes.
function GameOverManager:clearDeathHistory()
    self.deathHistory = {}
    Logger.debug("GameOverManager", "Histórico de mortes limpo.")
end

return GameOverManager
