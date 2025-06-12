--- Gerencia o estado e a lógica da tela de Game Over.

local gameOverMessagesData = require("src.data.game_over_messages_data")
local ArchetypesData = require("src.data.archetypes_data")
local fonts = require("src.ui.fonts") -- Assume que as fontes são carregadas globalmente

---@class GameOverManager
local GameOverManager = {}
GameOverManager.__index = GameOverManager

--- Cria uma nova instância do GameOverManager.
--- @return GameOverManager
function GameOverManager:new()
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

    instance.footerMessage = "Aperte qualquer tecla para continuar"
    instance.lossMessage = "Você perdeu seu caçador e todos os seus itens."

    instance.canExit = false
    instance.fadeAlpha = 0
    instance.messageAlpha = 0
    instance.footerAlpha = 0
    instance.footerBlinkTimer = 0

    instance.showLossMessage = false
    instance.lossMessageTimer = 0   -- Não usado diretamente, mas para consistência com GameplayScene
    instance.lossMessageDelay = 1.5 -- Tempo para a msg de perda aparecer após o início do game over

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
    self.canExit = false
    self.fadeAlpha = 0
    self.messageAlpha = 0
    self.footerAlpha = 0
    self.footerBlinkTimer = 0
    self.showLossMessage = false
    Logger.debug("GameOverManager", "Estado resetado.")
end

--- Seleciona uma mensagem de Game Over com base nos arquétipos do jogador.
--- @return string A mensagem selecionada.
function GameOverManager:_selectMessage()
    local playerManager = self.registry:get("playerManager")
    local hunterManager = self.registry:get("hunterManager")
    local hunterId = playerManager and playerManager:getCurrentHunterId()
    local archetypes = {}

    if hunterId and hunterManager and hunterManager.getArchetypeIds then -- getArchetypeIds pode não estar no mock
        archetypes = hunterManager:getArchetypeIds(hunterId) or {}
    end

    local possibleMessages = {}
    if gameOverMessagesData then
        for _, archetypeId in ipairs(archetypes) do
            local archetypeKey = string.lower(tostring(archetypeId)) -- Garante que é string
            if gameOverMessagesData[archetypeKey] then
                for _, msg in ipairs(gameOverMessagesData[archetypeKey]) do
                    table.insert(possibleMessages, msg)
                end
            end
        end
        if #possibleMessages == 0 or math.random() < 0.5 then
            if gameOverMessagesData.generic then
                for _, msg in ipairs(gameOverMessagesData.generic) do
                    table.insert(possibleMessages, msg)
                end
            end
        end
    end
    if #possibleMessages == 0 then return "Você morreu." end
    return possibleMessages[math.random(#possibleMessages)]
end

--- Ativa e configura a tela de Game Over.
--- @param portalData table Os dados do portal onde o jogador morreu.
function GameOverManager:start(portalData)
    if self.isGameOverActive then return end
    Logger.info("GameOverManager", "GAME OVER acionado!")
    self:reset()                       -- Garante um estado limpo antes de começar
    self.isGameOverActive = true
    self.portalData = portalData or {} -- Armazena os dados do portal

    self.message = self:_selectMessage()

    local playerManager = self.registry:get("playerManager") ---@type PlayerManager
    local hunterManager = self.registry:get("hunterManager") ---@type HunterManager
    local hunterId = playerManager and playerManager:getCurrentHunterId()

    if hunterId and hunterManager and hunterManager.getHunterData then
        local hunterData = hunterManager:getHunterData(hunterId)
        if hunterData then
            self.hunterName = hunterData.name or "Caçador Desconhecido"
            if hunterData.finalRankId and ArchetypesData and ArchetypesData.Ranks and ArchetypesData.Ranks[hunterData.finalRankId] then
                self.hunterRank = ArchetypesData.Ranks[hunterData.finalRankId].name or hunterData.finalRankId
            else
                self.hunterRank = hunterData.finalRankId or "Rank Desconhecido"
            end
        else
            self.hunterName = "Caçador Investigador"
            self.hunterRank = "Rank Secreto"
        end
    else
        self.hunterName = "Caçador Anônimo"
        self.hunterRank = "Rank Indefinido"
        Logger.warn("GameOverManager:start", "Não foi possível obter dados do HunterManager.")
    end

    self.timestamp = os.date("Hora da morte: %d/%m/%Y %H:%M:%S")
    -- TODO: Parar inputs de gameplay, fechar UIs da GameplayScene (a GameplayScene fará isso antes de chamar start)
    -- TODO: Adicionar som de "Game Over" ou música triste
end

--- Atualiza a lógica da tela de Game Over.
--- @param dt number Delta time.
function GameOverManager:update(dt)
    if not self.isGameOverActive then return end

    self.timer = self.timer + dt

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

    if not self.showLossMessage and self.timer > self.lossMessageDelay then
        self.showLossMessage = true
    end

    if not self.canExit and self.timer >= self.duration then
        self.canExit = true
        Logger.debug("GameOverManager", "Agora pode sair da tela de Game Over.")
    end

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

    local mainMessageFont = fonts.gameOver or fonts.main_large or fonts.main
    local detailFont = fonts.main_large
    local footerFont = fonts.main_large

    -- Estimar altura total para centralização
    local estimatedTotalHeight = 0
    if self.message ~= "" then
        local lineCount = 0
        for _ in self.message:gmatch("([^\r\n]+)") do lineCount = lineCount + 1 end -- Corrigido: \n para \\n
        estimatedTotalHeight = estimatedTotalHeight + mainMessageFont:getHeight() * math.max(1, lineCount)
    end
    estimatedTotalHeight = estimatedTotalHeight + detailFont:getHeight() * 2 + 25
    if self.showLossMessage then estimatedTotalHeight = estimatedTotalHeight + detailFont:getHeight() + 20 end

    currentY = (screenHeight / 2) - (estimatedTotalHeight / 2)

    if mainMessageFont and self.messageAlpha > 0 and self.message ~= "" then
        love.graphics.setFont(mainMessageFont)
        love.graphics.setColor(1, 0.1, 0.1, self.messageAlpha)
        local lines = {}
        for s in self.message:gmatch("([^\r\n]+)") do table.insert(lines, s) end -- Corrigido: \n para \\n
        for i, line in ipairs(lines) do
            local lineWidth = mainMessageFont:getWidth(line)
            love.graphics.printf(line, (screenWidth - lineWidth) / 2, currentY, screenWidth, "left")
            currentY = currentY + mainMessageFont:getHeight()
        end
    end

    currentY = currentY + 20

    if detailFont and self.messageAlpha > 0 then
        love.graphics.setFont(detailFont)
        love.graphics.setColor(0.8, 0.8, 0.8, self.messageAlpha)

        local hunterInfo = string.format("%s, %s", self.hunterName, self.hunterRank)
        local infoWidth = detailFont:getWidth(hunterInfo)
        love.graphics.printf(hunterInfo, (screenWidth - infoWidth) / 2, currentY, screenWidth, "left")
        currentY = currentY + detailFont:getHeight() + 5

        local timeWidth = detailFont:getWidth(self.timestamp)
        love.graphics.printf(self.timestamp, (screenWidth - timeWidth) / 2, currentY, screenWidth, "left")
        currentY = currentY + detailFont:getHeight() + 20
    end

    if detailFont and self.showLossMessage and self.messageAlpha > 0 then
        love.graphics.setFont(detailFont)
        love.graphics.setColor(0.9, 0.5, 0.5, self.messageAlpha)
        local lossMsgWidth = detailFont:getWidth(self.lossMessage)
        love.graphics.printf(self.lossMessage, (screenWidth - lossMsgWidth) / 2, currentY, screenWidth, "left")
    end

    if footerFont and self.canExit and self.footerAlpha > 0 then
        love.graphics.setFont(footerFont)
        love.graphics.setColor(1, 0.1, 0.1, self.footerAlpha)
        local footerMsgWidth = footerFont:getWidth(self.footerMessage)
        love.graphics.printf(self.footerMessage, (screenWidth - footerMsgWidth) / 2, screenHeight - 50, screenWidth,
            "left")
    end

    love.graphics.setFont(fonts.main or love.graphics.getFont()) -- Reseta a fonte principal
    love.graphics.setColor(1, 1, 1, 1)
end

--- Lida com a saída da tela de Game Over para a tela de Resumo.
function GameOverManager:handleExit()
    if not self.canExit then return end

    Logger.info("GameOverManager", "Saindo da tela de Game Over para a tela de Resumo.")

    local hunterManager = self.registry:get("hunterManager") ---@type HunterManager
    local playerManager = self.registry:get("playerManager") ---@type PlayerManager
    local hunterId = playerManager:getCurrentHunterId()
    if not hunterId then
        error("[GameOverManager:handleExit] Nenhum caçador selecionado.")
        return
    end
    local hunterData = hunterManager:getHunterData(hunterId)

    -- Deleta o caçador permanentemente
    hunterManager:deleteHunter(hunterId)
    Logger.info("GameOverManager",
        string.format("Caçador %s (ID: %s) foi permanentemente deletado.", hunterData.name, hunterId))


    local params = {
        extractionSuccessful = false,
        hunterId = hunterId,
        hunterData = hunterData,
        portalData = self.portalData,
        lootedItems = {},        -- Nenhum item é extraído na morte
        extractedItems = {},     -- Nenhum item vai para o loadout
        extractedEquipment = {}, -- Nenhum equipamento é salvo
        finalStats = nil,        -- Sem stats finais para mostrar
        archetypeIds = hunterData and hunterData.archetypeIds or {}
    }

    self.sceneManager.switchScene("extraction_summary_scene", params)
end

return GameOverManager
