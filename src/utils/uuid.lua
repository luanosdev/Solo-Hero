--- Gera um UUID v4 aleatório (string)
--- @return string UUID v4
local function generate()
    local random = math.random
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    local uuid = string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)

    return uuid
end

local uuid = {
    generate = generate
}

return uuid
