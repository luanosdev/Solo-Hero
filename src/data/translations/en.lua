--------------------------------------------------------------------------------
--- @author ReyalS
--- @release 1.0
--- @license MIT
--- @description
--- Translation file for English (en)
--- All Solo Hero game translations organized hierarchically

--------------------------------------------------------------------------------
--- TRANSLATION STRUCTURE
--------------------------------------------------------------------------------

local translations = {
    -- === GENERAL SYSTEM ===
    general = {
        loading = "Loading...",
        error = "Error",
        warning = "Warning",
        success = "Success",
        cancel = "Cancel",
        confirm = "Confirm",
        yes = "Yes",
        no = "No",
        ok = "OK",
        close = "Close",
        save = "Save",
        load = "Load",
        delete = "Delete",
        edit = "Edit",
        new = "New",
        back = "Back",
        next = "Next",
        previous = "Previous",
        continue = "Continue"
    },

    -- === AGENCY ===
    agency = {
        name = "Agency",
        patrimony = "Patrimony",
        no_active_hunter = "No Active Hunter",
        no_active_hunter_description = "Recruit a hunter!",
        no_active_hunter_error = "Error: Hunter not found",
        max_rank = "MAX RANK",
        unknown = "Unknown Agency"
    },

    -- === SHOP ===
    shop = {
        title = "Shop"
    },

    -- === STORAGE ===
    storage = {
        title = "Storage"
    },

    -- === LOADOUT ===
    loadout = {
        title = "Loadout"
    },

    -- === HUNTER ===
    hunter = {
        unknown = "Unknown Hunter"
    },

    -- === ITEM ===
    item = {
        type = {
            item = "Item",
            weapon = "Weapon",
            artefact = "Artefact",
            rune = "Rune"
        },
        unknown = "Unknown Item",
        attributes = {
            knockback_power = {
                none = "None",
                very_low = "Very Low",
                low = "Low",
                medium = "Medium",
                high = "High",
                very_high = "Very High"
            },
            range = "Range: {range}m",
            base_area_effect_radius = "Base Area Effect Radius: {baseAreaEffectRadius}m",
            angle = "Angle: {angle}°",
            knockback = "Knockback Power: {knockbackPower}",
            projectiles = "Projectiles: {projectiles}",
            chain_count = "Chain Count: {chainCount}"
        },
    },

    -- === ATTACK TYPES ===
    attack_types = {
        cone_slash = "Cone Slash",
        circular_smash = "Circular Smash",
        alternating_cone_strike = "Alternating Cone Strike",
        flame_stream = "Flame Stream",
        arrow_projectile = "Arrow Projectile",
        chain_lightning = "Chain Lightning",
        burst_projectile = "Burst Projectile",
        sequential_projectile = "Sequential Projectile"
    },

    -- === WEAPONS ===
    weapons = {
        -- Rank E
        circular_smash_e_001 = {
            name = "Great Forge Hammer",
            description = "A large forge hammer that deals area damage around the impact."
        },
        cone_slash_e_001 = {
            name = "Iron Sword",
            description = "An iron sword that deals area damage around the impact."
        },
        alternating_cone_strike_e_001 = {
            name = "Butcher Blades",
            description = "Butcher blades that deal alternating damage."
        },
        flame_stream_e_001 = {
            name = "Adapted Blowtorch",
            description = "An adapted blowtorch that fires flames dealing area damage."
        },
        arrow_projectile_e_001 = {
            name = "Hunting Bow",
            description = "A hunting bow used by long-distance hunters."
        },
        chain_lightning_e_001 = {
            name = "Improvised Coil",
            description = "An improvised coil that deals area damage around the impact."
        },
        burst_projectile_e_001 = {
            name = "Sawed-off Shotgun",
            description = "A loud shotgun that fires multiple projectiles at once."
        },
        sequential_projectile_e_001 = {
            name = "Scrap Machine Gun",
            description = "Fires a rapid sequence of projectiles. Aim can adjust during burst."
        },

        -- Rank D and above
        hammer = {
            name = "War Hammer",
            description = "A heavy hammer that deals area damage around the impact."
        },
        wooden_sword = {
            name = "Wooden Sword",
            description = "A simple sword made of wood"
        },
        iron_sword = {
            name = "Iron Sword",
            description = "A heavy and resistant iron sword."
        },
        dual_daggers = {
            name = "Twin Daggers",
            description = "Fast daggers that strike alternately in halves of a frontal cone."
        },
        dual_noctilara_daggers = {
            name = "Twin Noctilara Daggers",
            description = "Curved daggers that seem to absorb light, taken from the dreadful Noctilara."
        },
        flamethrower = {
            name = "Flamethrower",
            description = "Fires a continuous stream of slow fire particles."
        },
        bow = {
            name = "Short Bow",
            description = "A simple bow that fires three arrows."
        },
        chain_laser = {
            name = "Chain Laser",
            description = "Fires a beam that jumps between nearby enemies."
        }
    },

    -- === ARCHETYPES ===
    archetypes = {
        -- Rank E
        agile = {
            name = "Agile",
            description = "Faster than others, good for escaping from enemies."
        },
        alchemist_novice = {
            name = "Novice Alchemist",
            description = "Basic knowledge in potions, flasks fill a bit faster."
        },
        vigorous = {
            name = "Vigorous",
            description = "A bit more resistant than others, good for withstanding attacks."
        },
        aprendiz_rapido = {
            name = "Quick Learner",
            description = "Gains experience a bit faster."
        },
        sortudo_pequeno = {
            name = "A Bit Lucky",
            description = "A slight increase in general luck."
        },
        bruto_pequeno = {
            name = "Small Brute",
            description = "A slight increase in Strength."
        },
        poison_resistant = {
            name = "Poison Resistant",
            description = "Immune to toxins, but potions are less effective due to natural resistance."
        },
        hardy = {
            name = "Hardy",
            description = "Recovers health slightly faster after taking damage."
        },
        collector = {
            name = "Collector",
            description = "Slightly increases range for collecting items."
        },
        vigilant = {
            name = "Vigilant",
            description = "Detects items from farther away."
        },

        -- Rank D
        frenetic = {
            name = "Frenzied",
            description = "Attacks more frequently."
        },
        field_medic = {
            name = "Field Medic",
            description = "Specialist in first aid, potions heal more and fill faster."
        },
        cautious = {
            name = "Cautious",
            description = "Notices items from farther away."
        },
        barreira_magica = {
            name = "Magic Barrier",
            description = "Grants extra defense, but slightly reduces movement speed."
        },
        eco_temporal = {
            name = "Temporal Echo",
            description = "Abilities recharge a bit faster."
        },
        bottle_warrior = {
            name = "Bottle Warrior",
            description = "Carries more flasks than normal, but each heals less."
        },
        resilient = {
            name = "Resilient",
            description = "Improved constant health recovery."
        },
        focused = {
            name = "Focused",
            description = "Slightly reduces ability cooldown time."
        },
        shielded = {
            name = "Shielded",
            description = "Gains a small amount of additional defense."
        },

        -- Rank C
        determined = {
            name = "Determined",
            description = "Consistently higher attack speed."
        },
        alchemist_adept = {
            name = "Adept Alchemist",
            description = "Intermediate mastery in alchemy, gains an additional flask and improved healing."
        },
        predestined = {
            name = "Predestined",
            description = "Increases Luck."
        },
        guerreiro_nato = {
            name = "Born Warrior",
            description = "Increased Strength and Health."
        },
        blessed = {
            name = "Blessed",
            description = "Increases the number of Rune Slots."
        },
        precise = {
            name = "Precise",
            description = "Increases critical hit chance."
        },
        muralha = {
            name = "Wall",
            description = "Significantly increased health, but with movement speed penalty."
        },
        explorador_avancado = {
            name = "Advanced Explorer",
            description = "Increases item collection radius and experience gain."
        },
        evasivo = {
            name = "Evasive",
            description = "Recharges dash faster and moves with more agility."
        },
        fortified = {
            name = "Fortified",
            description = "Increases defense."
        },
        healer = {
            name = "Healer",
            description = "Increases amount of healing received."
        },
        swift = {
            name = "Swift",
            description = "Moves faster than normal."
        },
        tactical = {
            name = "Tactical",
            description = "Small cooldown reduction bonus."
        },

        -- Rank B
        executioner = {
            name = "Executioner",
            description = "Massive critical chance at the cost of defense."
        },
        combat_pharmacist = {
            name = "Combat Pharmacist",
            description = "Specialist in medical chemistry, flasks fill much faster and heal significantly more."
        },
        atirador_elite = {
            name = "Elite Marksman",
            description = "Considerably increases attack range, with a small reduction in attack speed."
        },
        vampiro_menor = {
            name = "Lesser Vampire",
            description = "Improves health regeneration per second, but decreases maximum health."
        },
        ariete = {
            name = "Battering Ram",
            description = "Advances much farther, but dash takes longer to recharge."
        },
        ranger = {
            name = "Ranger",
            description = "Increases attack range."
        },
        crusher = {
            name = "Crusher",
            description = "Expands attack area of abilities and weapons."
        },
        opportunist = {
            name = "Opportunist",
            description = "Small luck bonus for critical hits and items."
        },

        -- Rank A
        assassin = {
            name = "Assassin",
            description = "Enhanced critical damage and attack speed."
        },
        grand_alchemist = {
            name = "Grand Alchemist",
            description = "Supreme master of alchemy, gains extra flasks and superior quality potions."
        },
        mestre_das_runas = {
            name = "Rune Master",
            description = "Grants an additional rune slot and improves cooldown reduction."
        },
        colosso = {
            name = "Colossus",
            description = "Massively increased Strength and Defense, but with great attack speed penalty."
        },
        berserker = {
            name = "Berserker",
            description = "Increased attack speed and attack area, but less defense."
        },
        guardian = {
            name = "Guardian",
            description = "Massive defense, but with reduced speed."
        },
        avenger = {
            name = "Avenger",
            description = "Increases critical damage after taking damage."
        },

        -- Rank S
        immortal = {
            name = "Immortal",
            description = "Drastically increased health."
        },
        elixir_master = {
            name = "Elixir Master",
            description = "Transcended common alchemy, their flasks are legendary and regenerate almost instantly."
        },
        demon = {
            name = "Demon",
            description = "Increases critical hit chance."
        },
        insane = {
            name = "Insane",
            description = "Frequent multiple attacks, but very vulnerable."
        },
        reaper = {
            name = "Reaper",
            description = "Absurd chance of multi-attacks, but extremely fragile."
        },
        godspeed = {
            name = "Godspeed",
            description = "Extremely fast movement and attack."
        },
        phoenix = {
            name = "Phoenix",
            description = "Automatically revives once per match with half health."
        },
        overcharged = {
            name = "Overcharged",
            description = "Drastically reduces cooldown time, but increases damage taken."
        },
        arcanista_proibido = {
            name = "Forbidden Arcanist",
            description =
            "Immense Arcane Power: Critical damage, attack area and cooldown reduction significantly increased, but with great health sacrifice."
        }
    },

    -- === USER INTERFACE ===
    ui = {
        item_details_modal = {
            type_and_rank = "{type_t} Rank {rank}",
            damage = "Base Damage",
            attacks_per_second = "{attacksPerSecond} Attacks per Second",
            damage_per_second = "{damagePerSecond} Damage per Second",
            attack_type = "Attack Type: {attackType_t}",
            range = "Range: {range}",
            area = "Area: {area}",
            cooldown = "Cooldown: {cooldown}",
            knockback_power = "Knockback Power: {knockbackPower}",
            use_details = "Use Details",
            value = "Value: R$ {value}"
        },
        rank = "Rank",
        health = "Health",
        mana = "Mana",
        experience = "Experience",
        level = "Level",
        inventory = "Inventory",
        equipment = "Equipment",
        skills = "Skills",
        stats = "Stats",
        menu = "Menu",
        settings = "Settings",
        audio = "Audio",
        video = "Video",
        graphics = "Graphics",
        language = "Language",
        keybindings = "Keybindings",
        difficulty = "Difficulty",
        pause = "Pause",
        resume = "Resume",
        restart = "Restart",
        quit = "Quit"
    },

    -- === RANKS ===
    ranks = {
        E = {
            name = "Rank E",
            description = "Initial classification for new hunters"
        },
        D = {
            name = "Rank D",
            description = "Hunters with basic experience"
        },
        C = {
            name = "Rank C",
            description = "Competent and experienced hunters"
        },
        B = {
            name = "Rank B",
            description = "Veteran and specialized hunters"
        },
        A = {
            name = "Rank A",
            description = "Elite hunters, extremely skilled"
        },
        S = {
            name = "Rank S",
            description = "Legendary hunters, the most powerful"
        }
    },

    -- === SYSTEM MESSAGES ===
    system = {
        loading_complete = "Loading complete",
        saving_game = "Saving game...",
        game_saved = "Game saved successfully",
        game_loaded = "Game loaded successfully",
        error_saving = "Error saving game",
        error_loading = "Error loading game",
        invalid_key = "Invalid translation key: {key}",
        language_changed = "Language changed to: {language}",
        language_error = "Error changing language: {error}"
    }
}

return translations
