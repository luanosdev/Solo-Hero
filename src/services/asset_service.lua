---@class AssetService
---@description Serviço global para carregar e gerenciar assets (imagens, sons, etc.).
---@field images table<string, love.Image> Cache para imagens.
---@field sounds table<string, love.Source> Cache para sons.
---@field fonts table<string, love.Font> Cache para fontes.
---@field failedAssets table<string, boolean> Rastreia assets que falharam ao carregar para evitar tentativas repetidas.
local AssetService = {}
AssetService.__index = AssetService

--- Cria uma nova instância do AssetService.
---@return AssetService
function AssetService:new()
    local instance = setmetatable({}, AssetService)
    instance.images = {}
    instance.sounds = {}
    instance.fonts = {}
    instance.failedAssets = {}
    Logger.info("AssetService:new", "Instância do AssetService criada.")
    return instance
end

--- Carrega uma imagem e a armazena em cache.
--- Se a imagem já estiver carregada, retorna a versão em cache.
--- Se o carregamento falhou anteriormente, não tenta novamente.
---@param path string Caminho para o arquivo de imagem.
---@return love.Image|nil Imagem carregada ou nil se houver erro ou falha anterior.
function AssetService:getImage(path)
    if not path then
        Logger.warn("AssetService:getImage", "Caminho nil fornecido.")
        return nil
    end

    -- Retorna do cache se já existir
    if self.images[path] then
        return self.images[path]
    end

    -- Se já falhou antes, não tenta de novo para evitar spam de erros.
    if self.failedAssets[path] then
        return nil
    end

    -- Tenta carregar a imagem
    local success, img_or_err = pcall(love.graphics.newImage, path)
    if success then
        self.images[path] = img_or_err
        -- Logger.debug("AssetService:getImage", "Imagem carregada: " .. path) -- Opcional, muito verboso
        return img_or_err
    else
        Logger.error("AssetService:getImage",
            string.format("Erro ao carregar imagem '%s': %s", path, tostring(img_or_err)))
        -- Marca como falha para não tentar novamente
        self.failedAssets[path] = true
        self.images[path] = nil -- Garante que o cache não contenha um valor inválido
        return nil
    end
end

--- Limpa todos os caches (imagens, sons, fontes) e o registro de falhas.
--- Útil ao recarregar o jogo ou trocar de contextos de assets de forma massiva.
function AssetService:clearAllCaches()
    self.images = {}
    self.sounds = {}
    self.fonts = {}
    self.failedAssets = {} -- Limpa tudo, para uma nova tentativa geral
    Logger.info("AssetService:clearAllCaches", "Todos os caches do AssetService foram limpos.")
end

return AssetService
