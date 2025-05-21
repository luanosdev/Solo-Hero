-- [[ Modo de Depuração Global ]] --
DEV = true             -- Define o modo de desenvolvimento para este arquivo de configuração
PROFILER = true       -- Define o modo de desenvolvimento para este arquivo de configuração
LOGGERS = true         -- Define o modo de desenvolvimento para este arquivo de configuração
LOGS_ON_CONSOLE = true -- Define se os logs serão impressos no console

function love.conf(t)
    t.window.title = "Solo Hero"
    t.window.width = 1920
    t.window.height = 1080
    t.window.fullscreen = true
    t.window.msaa = 16 -- Anti-aliasing

    -- Define o VSync. Se DEV for true, vsync é 0 (desligado).
    -- Se DEV for false ou nil, vsync é 1 (ligado, padrão).
    if DEV == true then
        t.window.vsync = 0 -- VSync desligado para DEV mode
    else
        t.window.vsync = 1 -- VSync ligado por padrão
    end

    t.modules.joystick = false
    t.modules.physics = false
    t.console = true -- Habilita console para debug (pressione `)
end
