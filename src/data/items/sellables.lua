local sellables = {
    rotting_flesh = {
        id = "rotting_flesh",
        name = "Carne Apodrecida",
        type = "sellable",
        rarity = "E",
        description = "Uma carne podre vinda de um cadáver reanimado. Util para criar poções básicas.",
        icon = "assets/items/sellables/rotting_flesh.png",
        gridWidth = 1,
        gridHeight = 1,
        stackable = true,
        maxStack = 99,
        value = 1
    },
    torn_fabric = {
        id = "torn_fabric",
        name = "Tecido Rasgado",
        type = "sellable",
        rarity = "E",
        description = "O que sobrou da vestimenta de um zumbi. A origem desconhecida desperta o interesse de artesões.",
        icon = "assets/items/sellables/torn_fabric.png",
        gridWidth = 1,
        gridHeight = 1,
        stackable = true,
        maxStack = 99,
        value = 1
    },

    -- MVP
    intact_brain = {
        id = "intact_brain",
        name = "Cérebro Intacto",
        type = "sellable",
        rarity = "E",
        description = "Cérebro de um morto vivo que aparentemente possui alguma consciência. Usado em estudos médicos.",
        icon = "assets/items/sellables/intact_brain.png",
        gridWidth = 2,
        gridHeight = 2,
        stackable = false,
        maxStack = 1,
        value = 50
    },

    unstable_muscle = {
        id = "unstable_muscle",
        name = "Músculo Instável",
        type = "sellable",
        rarity = "E",
        description =
        "Músculo mutado de um zumbi, fazem com que o zumbi cosiga correr mais rápido. Usado em estudos médicos.",
        icon = "assets/items/sellables/unstable_muscle.png",
        gridWidth = 1,
        gridHeight = 1,
        stackable = true,
        maxStack = 99,
        value = 2
    },
    ruined_heart = {
        id = "ruined_heart",
        name = "Coração Rasgado",
        type = "sellable",
        rarity = "E",
        description =
        "Coração de um dos zumbis corredores, os musculos estao atrofiados e aparentemente estao se desintegrando.",
        icon = "assets/items/sellables/ruined_heart.png",
        gridWidth = 1,
        gridHeight = 1,
        stackable = true,
        maxStack = 99,
        value = 2
    },

    -- MVP
    strange_medallion = {
        id = "strange_medallion",
        name = "Medalhão Misterioso",
        type = "sellable",
        rarity = "E",
        description =
        "Um medalhão misterioso que um morto vivo carregegava, parece ter um numero ordenal incravado nele. Seria algum tipo de reconhecimento?",
        icon = "assets/items/sellables/strange_medallion.png",
        gridWidth = 1,
        gridHeight = 2,
        stackable = false,
        maxStack = 1,
        value = 100
    }

}

return sellables
