---@class ArtefactDefinition
---@field id string ID único do artefato
---@field name string Nome do artefato
---@field description string Descrição do artefato
---@field icon string Caminho para o ícone
---@field rank "E"|"D"|"C"|"B"|"A"|"S" Raridade
---@field value number Valor de venda unitário

---@type table<string, ArtefactDefinition>
local artefacts = {
    empty_stone = {
        id = "empty_stone",
        name = "Pedra do Vazio",
        description =
        "Uma pedra que aparenta armazenar uma energia poderosa, porem quase vazia. Existem algumas tecnicas que fazem o pouco que resta dessa energia se tornarem fontes de energia poderosas.",
        icon = "assets/items/artefacts/empty_stone.png",
        rank = "E",
        value = 2,
    },

    crystal_fragment = {
        id = "crystal_fragment",
        name = "Fragmento de Cristal",
        description = "O modo que este artefato absorve a luz é único. Converte a luz em calor em questões de segundos.",
        icon = "assets/items/artefacts/crystal_fragment.png",
        rank = "E",
        value = 3,
    },

    putrefied_core = {
        id = "putrefied_core",
        name = "Núcleo Putrefato",
        description =
        "Um núcleo pulsante envolto em carne necrosada e cristalizações fúngicas. Emite um leve calor e um odor adocicado, que estranhamente atrai alguns comerciantes itinerantes. Dizem que pode ser usado como catalisador em rituais ou como reagente raro em alquimia negra.",
        icon = "assets/items/artefacts/putrefied_core.png",
        rank = "E",
        value = 5,
    },

    unstable_core = {
        id = "unstable_core",
        name = "Núcleo Instável",
        description =
        "Uma esfera pulsante extraída do coração de um monstro de elite. Seu interior fervilha com energia comprimida e instável, oscilando entre colapsar e explodir. Manipular esse artefato sem o devido preparo pode ser fatal.",
        icon = "assets/items/artefacts/unstable_core.png",
        rank = "D",
        value = 50,
    },

    --- The Rotten Immortal
    eternal_decay_relic = {
    id = "eternal_decay_relic",
        name = "Relíquia da Decadência Eterna",
        description =
        "Uma esfera de cristal negro que emite uma aura de decadência e morte. Seu interior pulsa com energia pútrida e eterna, como se a própria morte tivesse sido aprisionada dentro dele.",
        icon = "assets/items/artefacts/eternal_decay_relic.png",
        rank = "C",
        value = 500,
    },
}

return artefacts
