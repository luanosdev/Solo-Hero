-- [[ Modo de Depuração Global ]] --
DEV = true                                   -- Define o modo de desenvolvimento para este arquivo de configuração
PROFILER = false                             -- Define o modo de desenvolvimento para este arquivo de configuração
LOGGERS = true                               -- Define o modo de desenvolvimento para este arquivo de configuração
LOGS_ON_CONSOLE = true                       -- Define se os logs serão impressos no console
DEBUG_SHOW_PARTICLE_COLLISION_RADIUS = false -- Define se o raio de colisão das partículas deve ser exibido
function love.conf(t)
    t.window.title = "Solo Hero"
    t.window.width = 1920
    t.window.height = 1080
    t.window.fullscreen = true
    t.window.msaa = 4 -- Anti-aliasing

    -- Define o VSync. Se DEV for true, vsync é 0 (desligado).
    -- Se DEV for false ou nil, vsync é 1 (ligado, padrão).
    t.window.vsync = 0 -- VSync desligado para DEV mode

    t.modules.joystick = false
    t.modules.physics = false
    t.console = true -- Habilita console para debug (pressione `)
end
