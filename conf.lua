function love.conf(t)
    t.window.title = "Solo Hero"
    t.window.width = 1920
    t.window.height = 1080
    t.window.fullscreen = true
    t.window.msaa = 16 -- Anti-aliasing
    t.modules.joystick = false
    t.modules.physics = false
    t.console = true -- Habilita console para debug (pressione `)
end
