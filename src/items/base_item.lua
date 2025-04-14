local BaseItem = {
    name = "Item Base",
    description = "Descrição do item",
    type = "item",
    icon = nil,
    stackable = false,
    maxStack = 1,
    quantity = 1
}

function BaseItem:new(overrides)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    
    -- Aplica overrides se existirem
    if overrides then
        for k, v in pairs(overrides) do
            o[k] = v
        end
    end
    
    return o
end

return BaseItem 