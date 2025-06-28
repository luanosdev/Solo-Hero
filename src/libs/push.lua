---@class Push
---@field defaults table
---@field STENCIL_VALUE number
---@field canvas table
---@field borderColor table
---@field canvases table
---@field canvasShaders table
---@field activeShader table
local push = {}

-- Configurações padrão
push.defaults = {
    gameWidth = 1920,
    gameHeight = 1080,
    windowWidth = 1920,
    windowHeight = 1080,
    fullscreen = false,
    resizable = true,
    canvas = true,
    pixelperfect = false,
    highdpi = false,
    stretched = false
}

-- Variáveis internas
local STENCIL_VALUE = 1
local canvas, borderColor = nil, { 0, 0, 0 }
local canvases = {}
local canvasShaders = {}
local activeShader = nil
local ww, wh, gw, gh = 0, 0, 0, 0
local _sx, _sy, _dx, _dy = 0, 0, 0, 0

---@param gameWidth number
---@param gameHeight number
---@param windowWidth number
---@param windowHeight number
---@param options table
function push:setupScreen(gameWidth, gameHeight, windowWidth, windowHeight, options)
    options = options or {}

    gw, gh = gameWidth, gameHeight
    ww, wh = windowWidth, windowHeight

    love.window.setMode(windowWidth, windowHeight, {
        fullscreen = options.fullscreen or push.defaults.fullscreen,
        resizable = options.resizable or push.defaults.resizable,
        vsync = options.vsync or false,
        msaa = options.msaa or 0,
        highdpi = options.highdpi or push.defaults.highdpi
    })

    self:initValues()

    if options.canvas or push.defaults.canvas then
        self:setupCanvas()
    end
end

---@param canvases_table? table
function push:setupCanvas(canvases_table)
    -- Tentar criar canvas com stencil, fallback para canvas padrão se falhar
    local canvas, hasStencil = self:_createCanvasWithStencil(gw, gh)

    table.insert(canvases, {
        name = "_default",
        canvas = canvas,
        hasStencil = hasStencil
    })

    if canvases_table then
        for i = 1, #canvases_table do
            local _table = canvases_table[i]
            local canvas, hasStencil = self:_createCanvasWithStencil(gw, gh)

            table.insert(canvases, {
                name = _table.name,
                canvas = canvas,
                hasStencil = hasStencil,
                shader = _table.shader
            })
        end
    end
end

-- Função auxiliar para criar canvas com stencil, com fallback
function push:_createCanvasWithStencil(width, height)
    -- Tentar diferentes abordagens para criar canvas com stencil
    local canvas, hasStencil = nil, false

    -- Tentativa 1: Canvas com stencil integrado (LÖVE 12+)
    pcall(function()
        canvas = love.graphics.newCanvas(width, height, { stencil = true })
        hasStencil = true
    end)

    -- Tentativa 2: Canvas com formato de tabela (LÖVE 11.x)
    if not canvas then
        pcall(function()
            canvas = love.graphics.newCanvas(width, height, { format = "rgba8", stencil = true })
            hasStencil = true
        end)
    end

    -- Fallback: Canvas padrão sem stencil
    if not canvas then
        canvas = love.graphics.newCanvas(width, height)
        hasStencil = false
        Logger.warn("push.canvas_creation", "[push:_createCanvasWithStencil] Usando canvas sem stencil (fallback)")
    else
        Logger.info("push.canvas_creation", "[push:_createCanvasWithStencil] Canvas com stencil criado com sucesso")
    end

    return canvas, hasStencil
end

---@param name string
function push:setCanvas(name)
    if not name or name == "_default" then
        return love.graphics.setCanvas(self:getCanvas("_default").canvas)
    end
    local _canvas = self:getCanvas(name)
    return love.graphics.setCanvas(_canvas.canvas)
end

---@param name string
function push:getCanvas(name)
    name = name or "_default"
    for i = 1, #canvases do
        if canvases[i].name == name then
            return canvases[i]
        end
    end
end

---@param name string
---@param shader table
function push:setShader(name, shader)
    if not name then
        activeShader = shader
        return activeShader
    end

    local _canvas = self:getCanvas(name)
    if _canvas then
        canvasShaders[name] = shader
    end
end

function push:initValues()
    _sx = ww / gw
    _sy = wh / gh

    if not push.defaults.stretched then
        _sx = math.min(_sx, _sy)
        _sy = _sx
    end

    _dx = (ww - (gw * _sx)) * 0.5
    _dy = (wh - (gh * _sy)) * 0.5
end

---@param operation string
function push:apply(operation)
    if operation == "start" then
        self:start()
    elseif operation == "finish" or operation == "end" then
        self:finish()
    end
end

function push:start()
    if #canvases > 0 then
        love.graphics.setCanvas(self:getCanvas("_default").canvas)
        love.graphics.clear()
    else
        love.graphics.push()
        love.graphics.translate(_dx, _dy)
        love.graphics.scale(_sx, _sy)
    end
end

function push:finish()
    if #canvases > 0 then
        love.graphics.setCanvas()

        for i = 1, #canvases do
            local _table = canvases[i]
            love.graphics.setColor(1, 1, 1, 1)

            -- Aplicar shader se existir
            local shader = _table.shader or canvasShaders[_table.name] or activeShader
            if type(shader) == "table" then
                for j = 1, #shader do
                    love.graphics.setShader(shader[j])
                end
            elseif shader then
                love.graphics.setShader(shader)
            end

            love.graphics.draw(_table.canvas, _dx, _dy, 0, _sx, _sy)
            love.graphics.setShader()
        end

        -- Desenhar bordas se não for stretched
        if not push.defaults.stretched then
            self:drawBorders()
        end
    else
        love.graphics.pop()
    end
end

function push:drawBorders()
    love.graphics.setColor(borderColor)

    -- Bordas superiores e inferiores
    if _dy > 0 then
        love.graphics.rectangle("fill", 0, 0, ww, _dy)
        love.graphics.rectangle("fill", 0, wh - _dy, ww, _dy)
    end

    -- Bordas laterais
    if _dx > 0 then
        love.graphics.rectangle("fill", 0, 0, _dx, wh)
        love.graphics.rectangle("fill", ww - _dx, 0, _dx, wh)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

---@param r number
---@param g number
---@param b number
---@param a number
function push:setBorderColor(r, g, b, a)
    if type(r) == "table" then
        borderColor = r
        for i = 1, 4 do borderColor[i] = borderColor[i] or 0 end
    else
        borderColor = { r or 0, g or 0, b or 0, a or 1 }
    end
end

---@param x number
---@param y number
function push:toGame(x, y)
    if x < _dx or x > ww - _dx or y < _dy or y > wh - _dy then
        return nil, nil
    end
    return (x - _dx) / _sx, (y - _dy) / _sy
end

---@param x number
---@param y number
function push:toReal(x, y)
    return x * _sx + _dx, y * _sy + _dy
end

---@param winw? number
---@param winh? number
function push:switchFullscreen(winw, winh)
    local fullscreen, fstype = love.window.getFullscreen()
    if not fullscreen then
        ww, wh = love.window.getDesktopDimensions()
        love.window.setFullscreen(true, "desktop")
    else
        ww, wh = winw or push.defaults.windowWidth, winh or push.defaults.windowHeight
        love.window.setMode(ww, wh)
    end
    self:initValues()
end

---@param w number
---@param h number
function push:resize(w, h)
    ww, wh = w, h
    self:initValues()
end

function push:getWidth()
    return gw
end

function push:getHeight()
    return gh
end

---@return number, number
function push:getDimensions()
    return gw, gh
end

--- Verifica se o canvas padrão tem suporte a stencil
---@return boolean hasStencil Se o canvas tem suporte a stencil
function push:hasStencilSupport()
    local defaultCanvas = self:getCanvas("_default")
    return defaultCanvas and defaultCanvas.hasStencil or false
end

--- Retorna informações sobre os canvas disponíveis
---@return table canvasInfo Informações sobre canvas e stencil
function push:getCanvasInfo()
    local info = {
        totalCanvases = #canvases,
        hasStencil = self:hasStencilSupport(),
        canvases = {}
    }

    for i = 1, #canvases do
        table.insert(info.canvases, {
            name = canvases[i].name,
            hasStencil = canvases[i].hasStencil or false
        })
    end

    return info
end

return push
