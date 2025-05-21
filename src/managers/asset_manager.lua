-- Gerenciador simples para carregar e cachear assets, começando com imagens.
---@class AssetManager
local AssetManager = {}
AssetManager.images = {} -- Cache para imagens
AssetManager.fonts = {}  -- Cache para fontes (exemplo, pode adicionar depois)
AssetManager.sounds = {} -- Cache para sons (exemplo, pode adicionar depois)

--- Carrega uma imagem e a armazena em cache.
--- Se a imagem já estiver carregada, retorna a versão em cache.
---@param path string Caminho para o arquivo de imagem.
---@return love.Image|nil Imagem carregada ou nil se houver erro.
function AssetManager:getImage(path)
    if not path then
        print("AssetManager:getImage - Caminho nil fornecido.")
        return nil
    end
    if not self.images[path] then
        -- Tenta carregar a imagem
        local success, img_or_err = pcall(love.graphics.newImage, path)
        if success then
            self.images[path] = img_or_err
            -- print("AssetManager: Imagem carregada: " .. path)
        else
            print(string.format("AssetManager: Erro ao carregar imagem '%s': %s", path, tostring(img_or_err)))
            -- Armazena nil para não tentar carregar repetidamente uma imagem que falhou
            self.images[path] = nil
        end
    end
    return self.images[path]
end

--- Limpa o cache de imagens (ou todos os caches).
--- Útil ao trocar de cenas ou temas que usam assets diferentes.
function AssetManager:clearImageCache()
    self.images = {}
    print("AssetManager: Cache de imagens limpo.")
end

function AssetManager:clearAllCaches()
    self.images = {}
    self.fonts = {}
    self.sounds = {}
    print("AssetManager: Todos os caches foram limpos.")
end

-- Retorna a tabela do AssetManager para que possa ser usada como um módulo global.
return AssetManager
