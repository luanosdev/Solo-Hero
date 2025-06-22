-- json.lua (version 0.9.1)
--
-- Copyright (c) 2012-2014, rxi
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See https://github.com/rxi/json.lua for details.
--

local json = { _version = "0.9.1" }

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
    ["\\"] = "\\",
    ["\""] = "\"",
    ["\b"] = "b",
    ["\f"] = "f",
    ["\n"] = "n",
    ["\r"] = "r",
    ["\t"] = "t",
}

local escape_char_map_inv = { ["/"] = "/" }
for k, v in pairs(escape_char_map) do
    escape_char_map_inv[v] = k
end


local function escape_char(c)
    return "\\" .. (escape_char_map[c] or string.format("u%04x", string.byte(c)))
end


local function encode_nil(val)
    return "null"
end


local function encode_table(val, stack)
    local res = {}
    stack = stack or {}

    -- Circular reference check
    if stack[val] then error("circular reference") end
    stack[val] = true

    if rawget(val, 1) then -- Treat as array
        for i = 1, #val do
            table.insert(res, encode(val[i], stack))
        end
        stack[val] = nil
        return "[" .. table.concat(res, ",") .. "]"
    else -- Treat as object
        for k, v in pairs(val) do
            if type(k) ~= "string" then
                error("invalid table key: " .. tostring(k))
            end
            table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
        end
        stack[val] = nil
        return "{" .. table.concat(res, ",") .. "}"
    end
end


local function encode_string(val)
    return '"' .. string.gsub(val, "[%c\"\\]", escape_char) .. '"'
end


local function encode_number(val)
    -- Check for infinity and NaN
    if val ~= val or val == 1 / 0 or val == -1 / 0 then
        error("unexpected number value '" .. tostring(val) .. "'")
    end
    return string.format("%.14g", val)
end


local type_func_map = {
    ["nil"] = encode_nil,
    ["table"] = encode_table,
    ["string"] = encode_string,
    ["number"] = encode_number,
    ["boolean"] = tostring,
}


encode = function(val, stack)
    local t = type(val)
    local f = type_func_map[t]
    if f then
        return f(val, stack)
    end
    error("unexpected type '" .. t .. "'")
end


function json.encode(val)
    return encode(val)
end

-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local decode

local function next_char(str, idx, set, invalid_set)
    local chr = string.sub(str, idx, idx)
    if not set or string.find(set, chr, 1, true) then
        return chr, idx + 1
    end
    if invalid_set and string.find(invalid_set, chr, 1, true) then
        error("invalid character '" .. chr .. "' at " .. idx)
    end
    error("expected " .. set .. " at " .. idx .. " but got '" .. chr .. "'")
end


local function next_chars(str, idx, n)
    local res = string.sub(str, idx, idx + n - 1)
    return res, idx + n
end


local function decode_error(str, idx, msg)
    local line_count = 1
    local col_count = 1
    for i = 1, idx - 1 do
        col_count = col_count + 1
        if string.sub(str, i, i) == "\n" then
            line_count = line_count + 1
            col_count = 1
        end
    end
    error(string.format("%s at line %d col %d", msg, line_count, col_count))
end


local function codepoint_to_utf8(n)
    -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
    local f = math.floor
    if n <= 0x7f then
        return string.char(n)
    elseif n <= 0x7ff then
        return string.char(f(n / 64) + 192, n % 64 + 128)
    elseif n <= 0xffff then
        return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
    elseif n <= 0x10ffff then
        return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 224,
            f(n % 4096 / 64) + 128, n % 64 + 128)
    end
    error(string.format("invalid codepoint '%x'", n))
end


local function parse_unicode_escape(s)
    local n1 = tonumber(s:sub(1, 4), 16)
    if s:sub(5, 6) == "\\u" then
        local n2 = tonumber(s:sub(7, 10), 16)
        -- Surrogate pair
        if n1 >= 0xD800 and n1 <= 0xDBFF and n2 >= 0xDC00 and n2 <= 0xDFFF then
            local n = 0x10000 + (n1 - 0xD800) * 0x400 + (n2 - 0xDC00)
            return codepoint_to_utf8(n), 10
        end
    end
    return codepoint_to_utf8(n1), 4
end


local function parse_string(str, i)
    local res = ""
    local j = i
    local c = string.sub(str, j, j)
    if c ~= '"' then error() end
    j = j + 1
    while true do
        c = string.sub(str, j, j)
        if c == '"' then break end
        if c == "\\" then
            j = j + 1
            c = string.sub(str, j, j)
            if c == "u" then
                local hex = str:sub(j + 1, j + 10)
                local utf8_char, n = parse_unicode_escape(hex)
                res = res .. utf8_char
                j = j + n
            else
                res = res .. escape_char_map_inv[c]
            end
        else
            res = res .. c
        end
        j = j + 1
    end
    return res, j + 1
end


local function parse_number(str, i)
    local x, y = string.find(str, "[-.0-9eE+]+", i)
    if not x then return nil end
    return tonumber(str:sub(x, y)), y + 1
end


local function skip_whitespace(str, i)
    local x, y = string.find(str, "^%s*", i)
    return y + 1
end


local function parse_table(str, i)
    local res = {}
    local j = i
    local c = string.sub(str, j, j)
    local arr = (c == "[")
    if c ~= "{" and c ~= "[" then error() end

    j = skip_whitespace(str, j + 1)
    c = string.sub(str, j, j)
    if c == (arr and "]" or "}") then
        return res, j + 1
    end

    while true do
        -- Key
        if not arr then
            local key
            key, j = decode(str, j)
            if type(key) ~= "string" then
                decode_error(str, j, "object key expected")
            end
            j = skip_whitespace(str, j)
            if string.sub(str, j, j) ~= ":" then
                decode_error(str, j, "':' expected")
            end
            j = skip_whitespace(str, j + 1)
            res[key] = decode(str, j)
        else
            res[#res + 1] = decode(str, j)
        end
        j = res[#res] and select(2, decode(str, j)) or select(2, decode(str, j))
        j = skip_whitespace(str, j)
        c = string.sub(str, j, j)
        if c == (arr and "]" or "}") then
            break
        end
        if c ~= "," then
            decode_error(str, j, "',' expected")
        end
        j = skip_whitespace(str, j + 1)
    end
    return res, j + 1
end


decode = function(str, idx)
    idx = idx or 1
    idx = skip_whitespace(str, idx)
    local chr = string.sub(str, idx, idx)
    if not chr or chr == "" then
        return nil, idx
    end

    -- null
    if chr == "n" then
        local s, e = next_chars(str, idx, 4)
        if s == "null" then
            return nil, e
        end
    end

    -- boolean
    if chr == "t" then
        local s, e = next_chars(str, idx, 4)
        if s == "true" then
            return true, e
        end
    end
    if chr == "f" then
        local s, e = next_chars(str, idx, 5)
        if s == "false" then
            return false, e
        end
    end

    -- string
    if chr == '"' then
        return parse_string(str, idx)
    end

    -- table
    if chr == "{" or chr == "[" then
        return parse_table(str, idx)
    end

    -- number
    local num, e = parse_number(str, idx)
    if num then
        return num, e
    end

    -- Error
    decode_error(str, idx, "value expected")
end


function json.decode(str)
    return decode(str)
end

return json
