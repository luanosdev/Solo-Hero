---@class ExperienceController
---@description Controlador para gerenciar experiência e level ups do jogador.
---@field eventService EventService Serviço de eventos
---@field bas
---@field pendingLevelUps number Contador para level ups pendentes
---@field currentExperience number Experiência atual do jogador
---@field experienceToNextLevel number Experiência necessária para o próximo level
---@field level number Level atual do jogador
local ExperienceController = {}
ExperienceController.__index = ExperienceController

ExperienceController.DEFAULT_BASE_GROWTH = {
    factor = 30,
    exponent = 1.5
}

--- Cria uma nova instância do ExperienceController.
---@param eventService EventService Serviço de eventos
function ExperienceController:new(eventService)
    local instance = setmetatable({}, ExperienceController)

    instance.eventService = eventService
    instance.pendingLevelUps = 0
    instance.currentExperience = 0
    instance.experienceToNextLevel = 0
    instance.level = 1

    return instance
end

---@class ExperienceBaseGrowth
---@field factor? number Fator de crescimento base
---@field exponent? number Expoente de crescimento base

--- Inicializa o ExperienceController.
---@param baseGrowth? ExperienceBaseGrowth Configuração de crescimento base
function ExperienceController:init(baseGrowth)
    Logger.debug(
        "experience_controller.init",
        "[ExperienceController:init] Inicializando controlador de experiência"
    )

    self.baseGrowth = self.DEFAULT_BASE_GROWTH

    if baseGrowth then
        self.baseGrowth.factor = baseGrowth.factor or self.baseGrowth.factor
        self.baseGrowth.exponent = baseGrowth.exponent or self.baseGrowth.exponent
    end
end

---@public Adiciona experiência ao jogador.
---@param amount number Quantidade de experiência a ser adicionada
---@param expBonusMultipler number Multiplicador de experiência
---@return number levelsGained Quantidade de levels ganhos
function ExperienceController:addExperience(amount, expBonusMultipler)
    local effectAmount = amount * expBonusMultipler

    self.currentExperience = self.currentExperience + effectAmount

    local levelsGained = 0

    while self.currentExperience >= self.experienceToNextLevel do
        self.level = self.level + 1
        self.currentExperience = self.currentExperience - self.experienceToNextLevel

        self.experienceToNextLevel = math.floor(self.baseGrowth.factor * self.level ^ self.baseGrowth.exponent)

        levelsGained = levelsGained + 1

    end

    self.eventService:emit(self.eventService.EVENTS.PLAYER_LEVELED_UP, levelsGained)

    return levelsGained
end

---@public Retorna o número de level ups pendentes.
---@return number
function ExperienceController:getPendingLevelUps()
    return self.pendingLevelUps
end

---@public Retorna a quantidade de experiência necessária para o próximo level.
---@return number
function ExperienceController:getExperienceToNextLevel()
    return self.experienceToNextLevel
end

---@public Retorna a quantidade de experiência atual do jogador.
---@return number
function ExperienceController:getCurrentExperience()
    return self.currentExperience
end

---@public Retorna o level atual do jogador.
---@return number
function ExperienceController:getLevel()
    return self.level
end

---@public Retorna a quantidade de experiência necessária para o próximo level.
---@param level number Level para o qual se deseja calcular a experiência
---@return number
function ExperienceController:getExperienceRequiredForLevel(level)
    return math.floor(self.baseGrowth.factor * level ^ self.baseGrowth.exponent)
end


return ExperienceController
