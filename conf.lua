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
    -- Configurações otimizadas para forçar dimensões corretas
    t.window.width = 1280       -- Janela padrão para desenvolvimento
    t.window.height = 720
    t.window.fullscreen = false -- O push gerencia fullscreen
    t.window.resizable = false  -- FORÇAR dimensões fixas para evitar redimensionamento
    t.window.msaa = 0           -- Desabilitado para melhor performance
    t.window.highdpi = true     -- Suporte para telas de alta DPI
    t.window.minwidth = 1280    -- Força dimensões mínimas iguais às desejadas
    t.window.minheight = 720    -- Força dimensões mínimas iguais às desejadas
    t.window.centered = true    -- Centraliza a janela

    -- VSync ligado para estabilidade visual
    t.window.vsync = 1

    t.modules.joystick = true
    t.console = DEV
end
