-- Módulo genérico para salvar e carregar dados do jogo usando love.filesystem.

---@class PersistenceManager
local PersistenceManager = {}

--[[---------------------------------------------------------------------------
  Funções Auxiliares de Serialização/Deserialização Simples (Internas)
---------------------------------------------------------------------------]]

--- Converte um valor Lua simples para sua representação em string Lua.
-- Suporta nil, boolean, number, string e tabelas (recursivamente, sem ciclos).
-- @local
-- @param value any Valor a ser serializado.
-- @return string String representando o valor em código Lua.
local function serializeValue(value)
    local t = type(value)
    if t == "nil" then
        return "nil"
    elseif t == "boolean" then
        return tostring(value)
    elseif t == "number" then
        -- Garante que números especiais como inf/-inf não quebrem a serialização
        if value == math.huge then return "math.huge" end
        if value == -math.huge then return "-math.huge" end
        if value ~= value then return "0/0" end -- NaN
        return string.format("%.17g", value)    -- Preserva precisão
    elseif t == "string" then
        return string.format("%q", value)       -- Usa aspas e escapa caracteres
    elseif t == "table" then
        local parts = {}
        -- Verifica se é array ou tabela chave-valor (simplificado)
        local is_array = true
        local count = 0
        for k, _ in pairs(value) do
            count = count + 1
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                is_array = false
            end
        end
        if #value ~= count then is_array = false end

        if is_array then
            for i = 1, #value do
                table.insert(parts, serializeValue(value[i]))
            end
        else
            -- Ordena as chaves alfabeticamente para uma serialização mais consistente (opcional)
            local keys = {}
            for k in pairs(value) do table.insert(keys, k) end
            table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
            end)

            for _, k in ipairs(keys) do
                local v = value[k]
                local keyStr
                if type(k) == "string" and k:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
                    keyStr = k
                else
                    keyStr = "[" .. serializeValue(k) .. "]"
                end
                table.insert(parts, keyStr .. " = " .. serializeValue(v))
            end
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        error("Tipo não suportado para serialização: " .. t)
    end
end

--- Tenta deserializar uma string Lua em um valor Lua.
-- ATENÇÃO: Usa loadstring, que pode ser inseguro se a string vier de fontes não confiáveis.
-- @local
-- @param str string String Lua a ser deserializada (espera-se que retorne um valor).
-- @return any Valor deserializado ou nil em caso de erro.
local function deserializeString(str)
    if not str or str == "" then return nil end                         -- Evita erro com string vazia
    local func, err = load("return " .. str, nil, "t", { math = math }) -- Adiciona 'return', escopo seguro
    if not func then
        print("PersistenceManager: Erro ao compilar string para deserialização: ", err)
        return nil
    end
    -- Define um metatable para proteger contra acesso a globais indesejadas dentro do load
    -- setfenv(func, { math = math }) -- Deprecated em Lua 5.2+ / Luajit. 'load' acima já faz isso.

    local success, valueOrErr = pcall(func)
    if not success then
        print("PersistenceManager: Erro ao executar string para deserialização: ", valueOrErr)
        return nil
    end
    return valueOrErr
end

--[[---------------------------------------------------------------------------
  Funções Públicas de Persistência
---------------------------------------------------------------------------]]

--- Salva uma tabela Lua em um arquivo no diretório de save do jogo.
-- Os dados são serializados para uma string Lua.
---@param filename string Nome do arquivo (ex: "game_state.dat").
---@param data table Tabela Lua a ser salva.
---@return boolean `true` se o salvamento foi bem-sucedido, `false` caso contrário.
function PersistenceManager.saveData(filename, data)
    if not filename or filename == "" then
        print("PersistenceManager.saveData ERRO: Nome de arquivo inválido.")
        return false
    end
    if type(data) ~= "table" then
        print("PersistenceManager.saveData ERRO: Os dados a serem salvos devem ser uma tabela.")
        return false
    end

    print(string.format("PersistenceManager: Tentando serializar dados para '%s'...", filename))
    local serializeSuccess, resultOrError = pcall(serializeValue, data)

    if not serializeSuccess then
        print(string.format("PersistenceManager.saveData ERRO ao serializar dados para '%s': %s", filename,
            tostring(resultOrError)))
        return false
    end

    -- Se chegou aqui, serializeSuccess é true e resultOrError contém a string serializada
    local actualSerializedData = resultOrError
    print(string.format("PersistenceManager: Serialização para '%s' bem-sucedida (tamanho: %d bytes).", filename,
        #actualSerializedData))

    print(string.format("PersistenceManager: Tentando escrever arquivo '%s'...", filename))
    -- Usa pcall também para a escrita no arquivo
    local writeSuccess, w_err = pcall(love.filesystem.write, filename, actualSerializedData)

    if writeSuccess then
        print(string.format("PersistenceManager: Dados salvos com sucesso em '%s'.", filename))
        return true
    else
        print(string.format("PersistenceManager.saveData ERRO ao escrever arquivo '%s': %s", filename, tostring(w_err)))
        return false
    end
end

--- Carrega dados de um arquivo no diretório de save do jogo.
-- O conteúdo do arquivo é deserializado de uma string Lua para uma tabela.
---@param filename string Nome do arquivo a ser carregado (ex: "game_state.dat").
---@return table | nil A tabela Lua carregada, ou `nil` se o arquivo não existir, estiver vazio ou ocorrer erro.
function PersistenceManager.loadData(filename)
    if not filename or filename == "" then
        print("PersistenceManager.loadData ERRO: Nome de arquivo inválido.")
        return nil
    end

    local info = love.filesystem.getInfo(filename)
    if not info or info.type ~= 'file' or info.size == 0 then
        print(string.format("PersistenceManager: Arquivo de save '%s' não encontrado ou vazio.", filename))
        return nil
    end

    print(string.format("PersistenceManager: Tentando ler arquivo '%s'...", filename))
    local success, content_or_error = pcall(love.filesystem.read, filename)

    if not success then
        -- Ocorreu um erro DENTRO da função love.filesystem.read que fez o pcall falhar.
        print(string.format("PersistenceManager.loadData ERRO (pcall) ao ler arquivo '%s': %s", filename,
            tostring(content_or_error)))
        return nil
    end

    -- Se pcall teve sucesso, verificamos o que love.filesystem.read retornou (que está em content_or_error)
    -- love.filesystem.read retorna 'nil' em caso de falha (ex: permissão negada, mesmo que exista)
    if content_or_error == nil then
        print(string.format(
            "PersistenceManager.loadData ERRO: love.filesystem.read retornou nil para '%s' (após pcall sucesso).",
            filename))
        return nil
    end

    -- Se chegou aqui, success é true e content_or_error contém a string lida
    local fileContent = content_or_error
    print(string.format("PersistenceManager: Arquivo '%s' lido com sucesso (%d bytes). Tentando deserializar...",
        filename, #fileContent))

    local data = deserializeString(fileContent)
    if data == nil then
        print(string.format("PersistenceManager: Falha ao deserializar dados de '%s'. O arquivo pode estar corrompido.",
            filename))
        return nil -- deserializeString já logou o erro específico
    end

    if type(data) ~= "table" then
        print(string.format("PersistenceManager: Dados carregados de '%s' não são uma tabela. Tipo: %s", filename,
            type(data)))
        return nil
    end

    print(string.format("PersistenceManager: Dados carregados e deserializados com sucesso de '%s'.", filename))
    return data
end

return PersistenceManager
