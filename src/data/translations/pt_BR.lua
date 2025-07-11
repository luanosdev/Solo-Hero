--------------------------------------------------------------------------------
--- @author ReyalS
--- @release 1.0
--- @license MIT
--- @description
--- Arquivo de tradução para Português Brasileiro (pt_BR)
--- Todas as traduções do jogo Solo Hero organizadas hierarquicamente

--------------------------------------------------------------------------------
--- ESTRUTURA DE TRADUÇÕES
--------------------------------------------------------------------------------

---@type TranslationData
local translations = {
    -- === SISTEMA GERAL ===
    general = {
        loading = "Carregando...",
        error = "Erro",
        warning = "Aviso",
        success = "Sucesso",
        cancel = "Cancelar",
        confirm = "Confirmar",
        yes = "Sim",
        no = "Não",
        ok = "OK",
        close = "Fechar",
        save = "Salvar",
        load = "Carregar",
        delete = "Deletar",
        edit = "Editar",
        new = "Novo",
        back = "Voltar",
        next = "Próximo",
        previous = "Anterior",
        continue = "Continuar"
    },

    -- === AGÊNCIA ===
    agency = {
        name = "Agência",
        patrimony = "Patrimônio",
        no_active_hunter = "Nenhum Caçador Ativo",
        no_active_hunter_description = "Recrute um caçador!",
        no_active_hunter_error = "Erro: Caçador não encontrado",
        max_rank = "RANK MÁXIMO",
        unknown = "Agência Desconhecida"
    },

    -- === SHOP ===
    shop = {
        title = "Mercado"
    },

    -- === STORAGE ===
    storage = {
        title = "Armazenamento"
    },

    -- === LOADOUT ===
    loadout = {
        title = "Mochila"
    },

    -- === CAÇADOR ===
    hunter = {
        unknown = "Caçador Desconhecido"
    },

    -- === ITEM ===
    item = {
        type = {
            item = "Item",
            weapon = "Arma",
            artefact = "Artefato",
            rune = "Runa",
        },
        unknown = "Item Desconhecido",
        attributes = {
            knockback_power = {
                none = "Nenhum",
                very_low = "Muito Baixo",
                low = "Baixo",
                medium = "Médio",
                high = "Alto",
                very_high = "Muito Alto",
            },
            range = "Alcance do ataque: {range}m",
            base_area_effect_radius = "Raio de Efeito Base: {baseAreaEffectRadius}m",
            angle = "Ângulo de Ataque: {angle}°",
            knockback = "Poder de Empurrão: {knockbackPower}",
            projectiles = "Projéteis: {projectiles}",
            chain_count = "Contagem de Encadeamento: {chainCount}",
        },
    },

    -- === Tipos de Ataque ===
    attack_types = {
        cone_slash = "Cone de Corte",
        circular_smash = "Circular de Esmagamento",
        alternating_cone_strike = "Alternado de Cone de Corte",
        flame_stream = "Fluxo de Chamas",
        arrow_projectile = "Projétil de Flecha",
        chain_lightning = "Raio Encadeado",
        burst_projectile = "Disparo de Múltiplos Projéteis",
        sequential_projectile = "Disparo de Rajada de Projéteis",
    },

    -- === ARMAS ===
    weapons = {
        -- Rank E
        circular_smash_e_001 = {
            name = "Marreta Grande de Forja",
            description = "Uma marreta grande de forja que causa dano em área ao redor do impacto."
        },
        cone_slash_e_001 = {
            name = "Espada de Ferro",
            description = "Uma espada de ferro que causa dano em área ao redor do impacto."
        },
        alternating_cone_strike_e_001 = {
            name = "Lâminas de Açougue",
            description = "Lâminas de açougue que causam dano alternado."
        },
        flame_stream_e_001 = {
            name = "Maçarico Adaptado",
            description = "Um maçarico adaptado que atira chamas que causam dano em área."
        },
        arrow_projectile_e_001 = {
            name = "Arco de Caça",
            description = "Um arco de caça usado por caçadores de longa distância."
        },
        chain_lightning_e_001 = {
            name = "Bobina Improvisada",
            description = "Uma bobina improvisada que causa dano em área ao redor do impacto."
        },
        burst_projectile_e_001 = {
            name = "Escopeta de Cano Serrado",
            description = "Uma escopeta barulhenta que dispara múltiplos projéteis de uma vez."
        },
        sequential_projectile_e_001 = {
            name = "Metralhadora de Sucata",
            description = "Dispara uma rápida sequência de projéteis. A mira pode ajustar durante a rajada."
        },

        -- Rank D e acima
        hammer = {
            name = "Martelo de Guerra",
            description = "Um martelo pesado que causa dano em área ao redor do impacto."
        },
        wooden_sword = {
            name = "Espada de Madeira",
            description = "Uma espada simples feita de madeira"
        },
        iron_sword = {
            name = "Espada de Ferro",
            description = "Uma espada de ferro pesada e resistente."
        },
        dual_daggers = {
            name = "Adagas Gêmeas",
            description = "Adagas rápidas que golpeiam alternadamente em metades de um cone frontal."
        },
        dual_noctilara_daggers = {
            name = "Adagas Noctilara Gêmeas",
            description = "Adagas curvas que parecem absorver a luz, tiradas da temível Noctilara."
        },
        flamethrower = {
            name = "Lança-Chamas",
            description = "Dispara um fluxo contínuo de partículas de fogo lentas."
        },
        bow = {
            name = "Arco Curto",
            description = "Um arco simples que dispara três flechas."
        },
        chain_laser = {
            name = "Laser Encadeado",
            description = "Dispara um raio que salta entre inimigos próximos."
        }
    },

    -- === ARTEFATOS ===
    artefacts = {
        -- Rank E
        empty_stone = {
            name = "Pedra do Vazio",
            description =
            "Uma pedra que aparenta armazenar uma energia poderosa, porem quase vazia. Existem algumas tecnicas que fazem o pouco que resta dessa energia se tornarem fontes de energia poderosas.",
        },
        crystal_fragment = {
            name = "Fragmento de Cristal",
            description =
            "O modo que este artefato absorve a luz é único. Converte a luz em calor em questões de segundos.",
        },
        putrefied_core = {
            name = "Núcleo Putrefato",
            description =
            "Um núcleo pulsante envolto em carne necrosada e cristalizações fúngicas. Emite um leve calor e um odor adocicado, que estranhamente atrai alguns comerciantes itinerantes. Dizem que pode ser usado como catalisador em rituais ou como reagente raro em alquimia negra.",
        },
        unstable_core = {
            name = "Núcleo Instável",
            description =
            "Uma esfera pulsante extraída do coração de um monstro de elite. Seu interior fervilha com energia comprimida e instável, oscilando entre colapsar e explodir. Manipular esse artefato sem o devido preparo pode ser fatal.",
        },
        eternal_decay_relic = {
            name = "Relíquia da Decadência Eterna",
            description =
            "Uma esfera de cristal negro, trincada, pulsando com uma aura mórbida de decadência e morte, um olho de um caçador que ja foi uma lenda quando os primeiros portais apareceram - que agora, não passa de uma pilha de carne que parece ter sofrido serios ferimetos de uma batalha anterior previa a sua morte. Agora ele vaga dentre os portais, sempre aparecendo misteriosamente atacando quaisquer caçador que aparece a sua frente. Colecionadores pagam caro do fragmento para estudar o que pode acontecido no dia de ruptura",
        },
    },

    -- === RUNAS ===
    runes = {
        -- Rank E
        rune_orbital_e = {
            name = "Runa Orbital",
            description = "Invoca esferas de energia que orbitam o caçador.",
        },
        rune_thunder_e = {
            name = "Runa do Trovão",
            description = "Invoca raios periodicamente em inimigos próximos.",
        },
        rune_aura_e = {
            name = "Runa de Aura",
            description = "Cria uma aura que causa dano contínuo a inimigos dentro dela.",
        },
    },

    -- === TELEPORT STONES ===
    teleport_stones = {
        teleport_stone_d = {
            name = "Pedra de Teleporte (D)",
            description =
            "Te teleporta em menos de 1 segundo. Apenas equipamentos são levados, util para saidas de emergência.",
        },
        teleport_stone_b = {
            name = "Pedra de Teleporte (B)",
            description = "Te teleporta em menos de 4 segundos. Uma seleção aleatória de seus items coletados é perdida.",
        },
        teleport_stone_a = {
            name = "Pedra de Teleporte (A)",
            description = "Te teleporta em menos de 7 segundos. Leva todos os equipamentos e itens da mochila.",
        },
        teleport_stone_s = {
            name = "Pedra de Teleporte (S)",
            description = "Te teleporta instantaneamente. Leva todos os equipamentos e itens da mochila.",
        },
    },

    -- === ARQUÉTIPOS ===
    archetypes = {
        -- Rank E
        agile = {
            name = "Ágil",
            description = "É mais rapido que outros, bom para fugir de inimigos."
        },
        alchemist_novice = {
            name = "Alquimista Novato",
            description = "Conhecimento básico em poções, frascos enchem um pouco mais rápido."
        },
        vigorous = {
            name = "Vigoroso",
            description = "Um pouco mais resistente que outros, bom para resistir aos ataques."
        },
        aprendiz_rapido = {
            name = "Aprendiz Rápido",
            description = "Ganha experiência um pouco mais rápido."
        },
        sortudo_pequeno = {
            name = "Um pouco Sortudo",
            description = "Um leve aumento na sorte geral."
        },
        bruto_pequeno = {
            name = "Pequeno Bruto",
            description = "Um leve aumento na Força."
        },
        poison_resistant = {
            name = "Resistente a Venenos",
            description = "Imune a toxinas, mas poções são menos eficazes devido à resistência natural."
        },
        hardy = {
            name = "Resistente",
            description = "Recupera vida ligeiramente mais rápido após sofrer dano."
        },
        collector = {
            name = "Coletor",
            description = "Aumenta levemente o alcance para coletar itens."
        },
        vigilant = {
            name = "Vigilante",
            description = "Detecta itens de mais longe."
        },

        -- Rank D
        frenetic = {
            name = "Frenético",
            description = "Ataca com mais frequência."
        },
        field_medic = {
            name = "Médico de Campo",
            description = "Especialista em primeiros socorros, poções curam mais e enchem mais rápido."
        },
        cautious = {
            name = "Cauteloso",
            description = "Percebe itens de mais longe."
        },
        barreira_magica = {
            name = "Barreira Mágica",
            description = "Concede defesa extra, mas reduz levemente a velocidade de movimento."
        },
        eco_temporal = {
            name = "Eco Temporal",
            description = "As habilidades recarregam um pouco mais rápido."
        },
        bottle_warrior = {
            name = "Guerreiro das Garrafas",
            description = "Carrega mais frascos que o normal, mas cada um cura menos."
        },
        resilient = {
            name = "Resiliente",
            description = "Recuperação de vida constante melhorada."
        },
        focused = {
            name = "Focado",
            description = "Reduz um pouco o tempo de recarga de habilidades."
        },
        shielded = {
            name = "Blindado",
            description = "Ganha uma pequena quantidade de defesa adicional."
        },

        -- Rank C
        determined = {
            name = "Determinado",
            description = "Velocidade de ataque consistentemente maior."
        },
        alchemist_adept = {
            name = "Alquimista Adepto",
            description = "Domínio intermediário em alquimia, ganha um frasco adicional e cura aprimorada."
        },
        predestined = {
            name = "Predestinado",
            description = "Aumenta a Sorte."
        },
        guerreiro_nato = {
            name = "Guerreiro Nato",
            description = "Força e Vida aumentadas."
        },
        blessed = {
            name = "Bem-Aventurado",
            description = "Aumenta a Quantidade de Slots Runa."
        },
        precise = {
            name = "Preciso",
            description = "Aumenta a chance de acertos críticos."
        },
        muralha = {
            name = "Muralha",
            description = "Vida significativamente aumentada, mas com penalidade na velocidade de movimento."
        },
        explorador_avancado = {
            name = "Explorador Avançado",
            description = "Aumenta o raio de coleta de itens e o ganho de experiência."
        },
        evasivo = {
            name = "Evasivo",
            description = "Recarrega o dash mais rápido e se move com mais agilidade."
        },
        fortified = {
            name = "Fortificado",
            description = "Aumenta a defesa."
        },
        healer = {
            name = "Curandeiro",
            description = "Aumenta a quantidade de cura recebida."
        },
        swift = {
            name = "Veloz",
            description = "Movimenta-se mais rapidamente que o normal."
        },
        tactical = {
            name = "Tático",
            description = "Pequeno bônus de redução de recarga."
        },

        -- Rank B
        executioner = {
            name = "Executor",
            description = "Chance crítica massiva ao custo de defesa."
        },
        combat_pharmacist = {
            name = "Farmacêutico de Combate",
            description =
            "Especialista em química médica, frascos enchem muito mais rápido e curam significativamente mais."
        },
        atirador_elite = {
            name = "Atirador de Elite",
            description =
            "Aumenta consideravelmente o alcance dos ataques, com uma pequena redução na velocidade de ataque."
        },
        vampiro_menor = {
            name = "Vampiro Menor",
            description = "Melhora a regeneração de vida por segundo, mas diminui a vida máxima."
        },
        ariete = {
            name = "Aríete",
            description = "Avança uma distância muito maior, mas o dash demora mais para recarregar."
        },
        ranger = {
            name = "Atirador",
            description = "Aumenta o alcance dos ataques."
        },
        crusher = {
            name = "Esmagador",
            description = "Amplia a área de ataque das habilidades e armas."
        },
        opportunist = {
            name = "Oportunista",
            description = "Pequeno bônus de sorte para acertos críticos e itens."
        },

        -- Rank A
        assassin = {
            name = "Assassino",
            description = "Dano crítico e velocidade de ataque aprimorados."
        },
        grand_alchemist = {
            name = "Grande Alquimista",
            description = "Mestre supremo da alquimia, ganha frascos extras e poções de qualidade superior."
        },
        mestre_das_runas = {
            name = "Mestre das Runas",
            description = "Concede um slot de runa adicional e melhora a redução de recarga."
        },
        colosso = {
            name = "Colosso",
            description = "Força e Defesa massivamente aumentadas, mas com grande penalidade na velocidade de ataque."
        },
        berserker = {
            name = "Berserker",
            description = "Velocidade de ataque e área de ataque aumentadas, mas menos defesa."
        },
        guardian = {
            name = "Guardião",
            description = "Defesa maciça, mas com velocidade reduzida."
        },
        avenger = {
            name = "Vingador",
            description = "Aumenta o dano crítico após sofrer dano."
        },

        -- Rank S
        immortal = {
            name = "Imortal",
            description = "Vida drasticamente aumentada."
        },
        elixir_master = {
            name = "Mestre dos Elixires",
            description =
            "Transcendeu a alquimia comum, seus frascos são lendários e se regeneram quase instantaneamente."
        },
        demon = {
            name = "Demônio",
            description = "Aumenta a chance de acertos críticos."
        },
        insane = {
            name = "Insano",
            description = "Ataques múltiplos frequentes, mas muito vulnerável."
        },
        reaper = {
            name = "Ceifador",
            description = "Chance absurda de multi-ataques, mas extremamente frágil."
        },
        godspeed = {
            name = "Velocidade Divina",
            description = "Movimentação e ataque extremamente rápidos."
        },
        phoenix = {
            name = "Fênix",
            description = "Renasce automaticamente uma vez por partida com metade da vida."
        },
        overcharged = {
            name = "Sobrecarregado",
            description = "Reduz drasticamente o tempo de recarga, mas aumenta o dano recebido."
        },
        arcanista_proibido = {
            name = "Arcanista Proibido",
            description =
            "Poder Arcano Imenso: Dano crítico, área de ataque e redução de recarga significativamente aumentados, mas com grande sacrifício de vida."
        }
    },

    -- === INTERFACE DO USUÁRIO ===
    ui = {
        item_details_modal = {
            type_and_rank = "{type_t} Ranking {rank}",
            damage = "Dano base",
            attacks_per_second = "{attacksPerSecond} Ataques por Segundo",
            damage_per_second = "{damagePerSecond} Dano por Segundo",
            attack_type = "Tipo de ataque: {attackType_t}",
            range = "Alcance: {range}",
            area = "Área: {area}",
            cooldown = "Recarga: {cooldown}",
            knockback_power = "Poder de Empurrão: {knockbackPower}",
            use_details = "Detalhes de uso",
            value = "Valor: R$ {value}"
        },

        rank = "Ranking",
        health = "Vida",
        mana = "Mana",
        experience = "Experiência",
        level = "Nível",
        inventory = "Inventário",
        equipment = "Equipamento",
        skills = "Habilidades",
        stats = "Atributos",
        menu = "Menu",
        settings = "Configurações",
        audio = "Áudio",
        video = "Vídeo",
        graphics = "Gráficos",
        language = "Idioma",
        keybindings = "Controles",
        difficulty = "Dificuldade",
        pause = "Pausar",
        resume = "Retomar",
        restart = "Reiniciar",
        quit = "Sair"
    },

    -- === RANKS ===
    ranks = {
        E = {
            name = "Rank E",
            description = "Classificação inicial para novos caçadores"
        },
        D = {
            name = "Rank D",
            description = "Caçadores com experiência básica"
        },
        C = {
            name = "Rank C",
            description = "Caçadores competentes e experientes"
        },
        B = {
            name = "Rank B",
            description = "Caçadores veteranos e especializados"
        },
        A = {
            name = "Rank A",
            description = "Caçadores de elite, extremamente habilidosos"
        },
        S = {
            name = "Rank S",
            description = "Caçadores lendários, os mais poderosos"
        }
    },

    -- === MENSAGENS DO SISTEMA ===
    system = {
        loading_complete = "Carregamento concluído",
        saving_game = "Salvando jogo...",
        game_saved = "Jogo salvo com sucesso",
        game_loaded = "Jogo carregado com sucesso",
        error_saving = "Erro ao salvar o jogo",
        error_loading = "Erro ao carregar o jogo",
        invalid_key = "Chave de tradução inválida: {key}",
        language_changed = "Idioma alterado para: {language}",
        language_error = "Erro ao alterar idioma: {error}"
    }
}

return translations
