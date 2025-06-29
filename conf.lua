-- [[ Modo de Depuração Global ]] --

-- Define se o modo de desenvolvimento está ativo
DEV = true
-- Define se o profiler está ativo
PROFILER = DEV and false
-- Define se os loggers estão ativos
LOGGERS = DEV and true
-- Define se os logs serão impressos no console
LOGS_ON_CONSOLE = DEV and true
-- Define se o raio de colisão das partículas deve ser exibido
DEBUG_SHOW_PARTICLE_COLLISION_RADIUS = DEV and false
-- Define se o hot reload deve ser ativado
HOT_RELOAD = DEV and false
-- Define se as bordas e coordenadas dos chunks devem ser exibidas
DEBUG_SHOW_CHUNK_BOUNDS = DEV and false

function love.conf(t)
    t.window.title = "Solo Hero"
    -- Configurações de janela básicas - o sistema push vai gerenciar resolução e fullscreen
    t.window.width = 1280       -- Janela menor por padrão para desenvolvimento
    t.window.height = 720
    t.window.fullscreen = false -- Deixa o push gerenciar fullscreen
    t.window.resizable = true   -- Permite redimensionamento
    t.window.msaa = 4           -- Anti-aliasing

    -- Define o VSync. Se DEV for true, vsync é 0 (desligado).
    -- Se DEV for false ou nil, vsync é 1 (ligado, padrão).
    t.window.vsync = 0 -- VSync desligado para DEV mode

    t.modules.joystick = true
    t.console = DEV
end
