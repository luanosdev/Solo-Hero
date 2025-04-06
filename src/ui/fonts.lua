local fonts = {}
local font_path = "assets/fonts/"

function fonts.load()
    local main_font_file = font_path .. "Rajdhani-Medium.ttf"
    local bold_font_file = font_path .. "Rajdhani-Bold.ttf"
    local fallback_font = "verdana"

    if not love.filesystem.getInfo(main_font_file) then main_font_file = fallback_font end
    if not love.filesystem.getInfo(bold_font_file) then bold_font_file = fallback_font end

    fonts.main_small = love.graphics.newFont(main_font_file, 14)
    fonts.main = love.graphics.newFont(main_font_file, 16)
    fonts.main_large = love.graphics.newFont(main_font_file, 18)
    fonts.title = love.graphics.newFont(bold_font_file, 24)
    fonts.hud = love.graphics.newFont(bold_font_file, 15)
    fonts.details_title = love.graphics.newFont(bold_font_file, 20)
    fonts.tooltip = love.graphics.newFont(main_font_file, 13)
    fonts.stack_count = love.graphics.newFont(font_path.."Roboto-Bold.ttf" or fallback_font, 11)

    love.graphics.setFont(fonts.main)
end

return fonts 