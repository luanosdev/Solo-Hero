local enemies = {
    zombie_walker_male_1 = {
        unitType = "zombie_walker_male_1", -- Identificador único para este tipo de unidade
        name = "Zombie Walker",            -- ADICIONADO: Nome para exibição ou identificação
        assetPaths = {
            walk = "assets/enemies/zombie_male_1/walk.png",
            run = "assets/enemies/zombie_male_1/run.png",
            death_die1 = "assets/enemies/zombie_male_1/die.png",
            death_die2 = "assets/enemies/zombie_male_1/die2.png"
        },
        grids = {
            -- !! IMPORTANTE: Ajuste frameWidth, frameHeight e numAnimationFrames para CADA spritesheet !!
            -- Estes são valores de EXEMPLO. Você PRECISA verificá-los nos seus arquivos de imagem.
            walk = { frameWidth = 128, frameHeight = 128, numAnimationFrames = 15 },
            run = { frameWidth = 128, frameHeight = 128, numAnimationFrames = 15 },
            death_die1 = { frameWidth = 128, frameHeight = 128, numAnimationFrames = 15 },
            death_die2 = { frameWidth = 128, frameHeight = 128, numAnimationFrames = 15 }
        },
        -- Ordem das direções no spritesheet (de cima para baixo).
        -- Assumindo 8 direções, começando em 0 graus (Leste) e seguindo no sentido horário.
        angles = { 0, 45, 90, 135, 180, 225, 270, 315 },
        frameTimes = {
            walk = 0.08, -- Segundos por frame
            run = 0.10,  -- Segundos por frame
            death_die1 = 0.12,
            death_die2 = 0.12
        },

        defaultSpeed = 20,
        movementThreshold = 5,
        resetFrameOnStop = true,
        angleOffset = 0,

        instanceDefaults = {
            scale = 1,
            speed = 20,
            animation = {
                activeMovementType = 'walk' -- Começa andando
            }
        },

        -- Atributos de combate e IA
        health = 100,
        damage = 1,
        experienceValue = 20
    }
}

return enemies
