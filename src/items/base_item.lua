local BaseItem = {}
BaseItem.__index = BaseItem

--[[-
    Construtor da Classe Base de Itens.
    Aceita uma tabela 'config' com as propriedades iniciais do item.

    Propriedades Essenciais Esperadas (com padrões):
    - name (string): Nome do item. Padrão: "Unnamed Item"
    - type (string): Tipo do item (ex: "weapon", "jewel", "rune", "consumable"). Padrão: "item"
    - description (string): Descrição do item. Padrão: ""
    - icon (string/userdata): Identificador ou objeto para o ícone do item. Padrão: nil

    Outras propriedades comuns podem ser definidas aqui ou nas classes filhas.
]]
function BaseItem:new(config)
    -- Garante que config seja uma tabela
    config = type(config) == 'table' and config or {}

    local instance = {}

    -- Copia todas as chaves/valores de config para a nova instância
    for k, v in pairs(config) do
        instance[k] = v
    end

    -- Define valores padrão ESSENCIAIS se não foram fornecidos na config
    instance.name = instance.name or "Unnamed Item"
    instance.type = instance.type or "item"
    instance.description = instance.description or "" -- Padrão para descrição
    instance.icon = instance.icon or nil -- Padrão para ícone

    -- Guarda a config original, se necessário para referência futura
    -- instance.config = config

    -- Define o metatable para a própria classe BaseItem (ou classe filha que chamou)
    setmetatable(instance, self)
    return instance
end

-- Exemplo de métodos que podem ser chamados em qualquer item
function BaseItem:getName()
    return self.name
end

function BaseItem:getDescription()
    return self.description
end

function BaseItem:getType()
    return self.type
end

function BaseItem:getIcon()
    return self.icon
end

return BaseItem 