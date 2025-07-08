---@class LevelUpImageManager
--- Gerencia o carregamento e cache de imagens para o sistema de level up
--- Segue o padrão do AssetManager para otimizar performance
local LevelUpImageManager = {}

-- Cache de imagens carregadas
LevelUpImageManager.imageCache = {}

-- Estado do carregamento
LevelUpImageManager.isLoaded = false
LevelUpImageManager.loadingInProgress = false

-- Estatísticas de carregamento
LevelUpImageManager.stats = {
    totalImages = 0,
    loadedImages = 0,
    failedImages = 0,
    cacheHits = 0
}

--- Pré-carrega todas as imagens das skills de level up
--- @return boolean success True se o carregamento foi bem-sucedido
function LevelUpImageManager:preloadAllImages()
    if self.isLoaded then
        Logger.debug("LevelUpImageManager", "Imagens já carregadas, pulando pré-carregamento")
        return true
    end

    if self.loadingInProgress then
        Logger.warn("LevelUpImageManager", "Carregamento já em progresso")
        return false
    end

    self.loadingInProgress = true
    Logger.info("LevelUpImageManager", "Iniciando pré-carregamento de imagens das skills...")

    local LevelUpBonusesData = require("src.data.level_up_bonuses_data")
    local loadedCount = 0
    local failedCount = 0
    local uniquePaths = {}

    -- Coleta todos os caminhos únicos de imagens
    for bonusId, bonusData in pairs(LevelUpBonusesData.Bonuses) do
        if bonusData.image_path and bonusData.image_path ~= "" then
            uniquePaths[bonusData.image_path] = true
        end
    end

    -- Conta total de imagens únicas
    local totalImages = 0
    for _ in pairs(uniquePaths) do
        totalImages = totalImages + 1
    end

    self.stats.totalImages = totalImages
    Logger.debug("LevelUpImageManager",
        string.format("Encontradas %d imagens únicas para carregar", totalImages))

    -- Carrega cada imagem única
    for imagePath in pairs(uniquePaths) do
        local success, imageOrError = pcall(love.graphics.newImage, imagePath)

        if success then
            self.imageCache[imagePath] = imageOrError
            loadedCount = loadedCount + 1
            Logger.debug("LevelUpImageManager.load_image",
                string.format("Carregada: %s", imagePath))
        else
            -- Armazena nil para não tentar carregar novamente
            self.imageCache[imagePath] = nil
            failedCount = failedCount + 1
            Logger.warn("LevelUpImageManager.load_failed",
                string.format("Falha ao carregar '%s': %s", imagePath, tostring(imageOrError)))
        end
    end

    -- Atualiza estatísticas
    self.stats.loadedImages = loadedCount
    self.stats.failedImages = failedCount
    self.isLoaded = true
    self.loadingInProgress = false

    Logger.info("LevelUpImageManager",
        string.format("Pré-carregamento concluído: %d/%d imagens carregadas com sucesso, %d falharam",
            loadedCount, totalImages, failedCount))

    return loadedCount > 0
end

--- Obtém uma imagem do cache
--- @param imagePath string Caminho da imagem
--- @return love.Image|nil Imagem carregada ou nil se não encontrada
function LevelUpImageManager:getImage(imagePath)
    if not imagePath or imagePath == "" then
        Logger.warn("LevelUpImageManager", "Caminho de imagem vazio fornecido")
        return nil
    end

    -- Se não foi pré-carregado, tenta carregar sob demanda
    if not self.isLoaded then
        Logger.warn("LevelUpImageManager",
            "Tentativa de obter imagem antes do pré-carregamento, carregando sob demanda: " .. imagePath)
        return self:_loadImageOnDemand(imagePath)
    end

    local image = self.imageCache[imagePath]

    if image then
        self.stats.cacheHits = self.stats.cacheHits + 1
        Logger.debug("LevelUpImageManager.cache_hit",
            string.format("Cache hit para: %s", imagePath))
        return image
    else
        Logger.warn("LevelUpImageManager.cache_miss",
            string.format("Imagem não encontrada no cache: %s", imagePath))
        return nil
    end
end

--- Carrega uma imagem sob demanda (fallback)
--- @param imagePath string Caminho da imagem
--- @return love.Image|nil Imagem carregada ou nil
function LevelUpImageManager:_loadImageOnDemand(imagePath)
    if self.imageCache[imagePath] ~= nil then
        return self.imageCache[imagePath]
    end

    Logger.debug("LevelUpImageManager.on_demand",
        string.format("Carregando sob demanda: %s", imagePath))

    local success, imageOrError = pcall(love.graphics.newImage, imagePath)

    if success then
        self.imageCache[imagePath] = imageOrError
        Logger.debug("LevelUpImageManager.on_demand_success",
            string.format("Carregamento sob demanda bem-sucedido: %s", imagePath))
        return imageOrError
    else
        self.imageCache[imagePath] = nil
        Logger.warn("LevelUpImageManager.on_demand_failed",
            string.format("Falha no carregamento sob demanda de '%s': %s", imagePath, tostring(imageOrError)))
        return nil
    end
end

--- Limpa o cache de imagens
function LevelUpImageManager:clearCache()
    Logger.info("LevelUpImageManager", "Limpando cache de imagens...")

    local clearedCount = 0
    for imagePath, image in pairs(self.imageCache) do
        if image then
            clearedCount = clearedCount + 1
        end
    end

    self.imageCache = {}
    self.isLoaded = false
    self.loadingInProgress = false

    -- Reset estatísticas
    self.stats = {
        totalImages = 0,
        loadedImages = 0,
        failedImages = 0,
        cacheHits = 0
    }

    Logger.info("LevelUpImageManager",
        string.format("Cache limpo: %d imagens removidas", clearedCount))
end

--- Força coleta de lixo no cache
function LevelUpImageManager:collectGarbage()
    Logger.debug("LevelUpImageManager", "Forçando coleta de lixo...")
    collectgarbage("collect")
end

--- Obtém estatísticas do manager
--- @return table Estatísticas de carregamento e uso
function LevelUpImageManager:getStats()
    return {
        isLoaded = self.isLoaded,
        loadingInProgress = self.loadingInProgress,
        totalImages = self.stats.totalImages,
        loadedImages = self.stats.loadedImages,
        failedImages = self.stats.failedImages,
        cacheHits = self.stats.cacheHits,
        cacheSize = self:_getCacheSize()
    }
end

--- Conta o número de imagens no cache
--- @return number Número de imagens carregadas no cache
function LevelUpImageManager:_getCacheSize()
    local count = 0
    for _, image in pairs(self.imageCache) do
        if image then
            count = count + 1
        end
    end
    return count
end

--- Verifica se uma imagem está disponível no cache
--- @param imagePath string Caminho da imagem
--- @return boolean True se a imagem está no cache
function LevelUpImageManager:hasImage(imagePath)
    return self.imageCache[imagePath] ~= nil
end

--- Obtém informações de debug sobre o cache
--- @return string Informações formatadas sobre o estado do cache
function LevelUpImageManager:getDebugInfo()
    local stats = self:getStats()
    return string.format(
        "LevelUpImageManager Status:\n" ..
        "  Loaded: %s\n" ..
        "  Loading: %s\n" ..
        "  Cache Size: %d/%d\n" ..
        "  Cache Hits: %d\n" ..
        "  Failed Loads: %d",
        tostring(stats.isLoaded),
        tostring(stats.loadingInProgress),
        stats.cacheSize,
        stats.totalImages,
        stats.cacheHits,
        stats.failedImages
    )
end

return LevelUpImageManager
