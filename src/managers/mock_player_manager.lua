-- src/managers/mock_player_manager.lua
-- Mock simples do PlayerManager para uso na LobbyScene

local MockPlayerManager = {}
MockPlayerManager.__index = MockPlayerManager

--- Cria uma nova instância do MockPlayerManager.
function MockPlayerManager:new()
    local instance = setmetatable({}, MockPlayerManager)

    -- Mock do PlayerState
    instance.state = {
        level = 15,
        experience = 12500,
        experienceToNextLevel = 20000,
        kills = 87,
        currentHealth = 180,

        -- Stats Base (Mock)
        baseHealth = 100,
        baseDefense = 20,
        baseSpeed = 5.0,
        baseCriticalChance = 0.10,    -- 10%
        baseCriticalMultiplier = 1.5, -- 1.5x
        baseHealthRegen = 1.0,        -- 1 HP/s
        baseMultiAttackChance = 0.0,  -- 0%
        baseDamage = 10,              -- Dano base da arma/classe (influencia o total)
        baseAttackSpeed = 1.0,        -- Tempo base entre ataques (segundos)
        baseRange = 100,              -- Alcance base da arma
        baseArea = math.pi / 4,       -- Ângulo base em radianos (45 graus)

        -- Bônus por Nível (Mock)
        levelBonus = {
            health = 50,             -- +50%
            defense = 25,            -- +25%
            speed = 10,              -- +10%
            criticalChance = 5,      -- +5% (percentual sobre o base? ou add flat? Varia, vamos mockar flat add)
            criticalMultiplier = 20, -- +20% (multiplicativo no bônus)
            healthRegen = 100,       -- +100%
            multiAttackChance = 0,   -- +0%
            damage = 30,             -- +30%
            attackSpeed = 15,        -- +15% (reduz cooldown)
            range = 10,              -- +10%
            area = 20                -- +20%
        },

        -- Bônus Fixos (Mock)
        fixedBonus = {
            health = 20,
            defense = 5,
            speed = 0.5,
            criticalChance = 0.02,    -- +2% flat
            criticalMultiplier = 0.1, -- +0.1x flat
            healthRegen = 0.5,        -- +0.5 HP/s flat
            multiAttackChance = 0.3,  -- +0%
            -- Não costuma ter bônus fixo para damage, attackSpeed, range, area
        },

        -- Funções getTotal (Mock) - Calculam o total baseado nos mocks acima
        getTotalHealth = function(self)
            local base = self.baseHealth or 0
            local percBonus = self.levelBonus.health or 0
            local fixed = self.fixedBonus.health or 0
            return math.floor(base * (1 + percBonus / 100) + fixed)
        end,
        getTotalDefense = function(self)
            local base = self.baseDefense or 0
            local percBonus = self.levelBonus.defense or 0
            local fixed = self.fixedBonus.defense or 0
            return math.floor(base * (1 + percBonus / 100) + fixed)
        end,
        getTotalSpeed = function(self)
            local base = self.baseSpeed or 0
            local percBonus = self.levelBonus.speed or 0
            local fixed = self.fixedBonus.speed or 0
            return base * (1 + percBonus / 100) + fixed
        end,
        getTotalCriticalChance = function(self)
            local base = self.baseCriticalChance or 0
            local percBonus = self.levelBonus.criticalChance or 0 -- Aqui é flat add no mock
            local fixed = self.fixedBonus.criticalChance or 0
            return base + (percBonus / 100) + fixed
        end,
        getTotalCriticalMultiplier = function(self)
            local base = self.baseCriticalMultiplier or 1
            local percBonus = self.levelBonus.criticalMultiplier or 0 -- % sobre o base
            local fixed = self.fixedBonus.criticalMultiplier or 0
            return base * (1 + percBonus / 100) + fixed
        end,
        getTotalHealthRegen = function(self)
            local base = self.baseHealthRegen or 0
            local percBonus = self.levelBonus.healthRegen or 0
            local fixed = self.fixedBonus.healthRegen or 0
            return base * (1 + percBonus / 100) + fixed
        end,
        getTotalMultiAttackChance = function(self)                   -- Simplesmente retorna o base + bônus
            local base = self.baseMultiAttackChance or 0
            local percBonus = self.levelBonus.multiAttackChance or 0 -- Flat add no mock
            local fixed = self.fixedBonus.multiAttackChance or 0
            return base + (percBonus / 100) + fixed
        end,
        -- Função específica para dano total, precisa da média do dano base da arma
        getTotalDamage = function(self, weaponBaseDamageAvg)
            local baseDmg = weaponBaseDamageAvg or self.baseDamage -- Usa a média da arma ou o base do state
            local percBonus = self.levelBonus.damage or 0
            -- Não tem fixed bonus para dano geralmente
            return math.floor(baseDmg * (1 + percBonus / 100))
        end,
        -- Cooldown efetivo (Attack Speed)
        getEffectiveCooldown = function(self, weaponBaseCooldown)
            local baseCd = weaponBaseCooldown or (1 / (self.baseAttackSpeed or 1))
            local percBonus = self.levelBonus.attackSpeed or 0
            return baseCd / (1 + percBonus / 100)
        end,
        -- Alcance Total
        getTotalRange = function(self, weaponBaseRange)
            local base = weaponBaseRange or self.baseRange or 0
            local percBonus = self.levelBonus.range or 0
            return base * (1 + percBonus / 100)
        end,
        -- Ângulo Total
        getTotalAngle = function(self, weaponBaseAngleRad)
            local base = weaponBaseAngleRad or self.baseArea or 0
            local percBonus = self.levelBonus.area or 0
            return base * (1 + percBonus / 100)
        end,

        -- Funções dummy para compatibilidade
        heal = function(self, amount) self.currentHealth = math.min(self:getTotalHealth(), self.currentHealth + amount) end,
        takeDamage = function(self, amount)
            local dmg = math.min(self.currentHealth, amount); self.currentHealth = self.currentHealth - dmg; return dmg
        end,
        addExperience = function(self, amount)
            self.experience = self.experience + amount; print("[Mock] XP adicionada:", amount); return false
        end, -- Mock não sobe de nível
        updateWeaponStats = function(self, weapon) print("[Mock] Stats da arma atualizados (não implementado)") end,
    }

    -- Mock da Arma Equipada
    instance.equippedWeapon = {
        name = "Espada Longa do Vácuo",
        rarity = 'S',        -- Ex: S, A, B, C, D, E
        damage = 30,         -- Era { min = 25, max = 35 }
        range = 120,
        angle = math.pi / 3, -- 60 graus
        description = "Uma lâmina que corta o próprio tecido da realidade.",
        -- Mock da AttackInstance associada
        attackInstance = {
            cooldown = 0.8, -- Cooldown base em segundos
            damageType = "Caos",
            -- Funções dummy se necessário
            update = function() end,
            draw = function() end,
            cast = function() end,
            getPreview = function() return false end,
        }
    }

    -- Mock das Runas Equipadas (Lista de ITENS)
    instance.equippedRuneItems = {
        {
            name = "Runa da Fúria Crescente",
            id = "rune_fury",
            rarity = 'A',
            level = 3,
            maxLevel = 5,
            description = "Aumenta o dano a cada golpe consecutivo."
            -- icon = "path/to/icon_fury.png" -- Opcional
        },
        {
            name = "Runa da Proteção Celestial",
            id = "rune_protection",
            rarity = 'B',
            level = 4,
            maxLevel = 4,
            description = "Concede um escudo temporário ao receber dano."
            -- icon = "path/to/icon_protection.png" -- Opcional
        },
        -- Pode adicionar mais runas mockadas aqui (até 4)
        {
            name = "Runa da Celeridade",
            id = "rune_haste",
            rarity = 'A',
            level = 1,
            maxLevel = 3,
            description = "Aumenta a velocidade de ataque temporariamente."
        }
    }

    -- Outras propriedades básicas que a UI possa acessar (inicialmente vazias ou mockadas)
    instance.player = { -- Mock básico do sprite/entidade player
        position = { x = 0, y = 0 }
        -- Outras propriedades do SpritePlayer se forem acessadas diretamente
    }
    instance.runes = {} -- Lista de instâncias ativas (pode deixar vazia no mock)
    instance.gameTime = 123.4
    instance.lastDamageTime = 100.0
    instance.damageCooldown = 5.0
    instance.accumulatedRegen = 0.2
    instance.regenInterval = 1.0

    return instance
end

return MockPlayerManager
