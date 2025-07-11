-------------------------------------------------
--- The Rotten Immortal Boss
-------------------------------------------------
local BaseBoss = require("src.enemies.boss.base_boss")
local BossesData = require("src.data.bosses")
local data = BossesData.the_rotten_immortal

---@class TheRottenImmortal : BaseBoss
local TheRottenImmortal = {}

-- Atribuindo dados do arquivo de configuração
TheRottenImmortal.className = data.className
TheRottenImmortal.name = data.name
TheRottenImmortal.maxHealth = data.maxHealth
TheRottenImmortal.damage = data.damage
TheRottenImmortal.experienceValue = data.experienceValue
TheRottenImmortal.speed = data.speed
TheRottenImmortal.size = data.size
TheRottenImmortal.knockbackResistance = data.knockbackResistance
TheRottenImmortal.abilityCooldown = data.abilityCooldown
TheRottenImmortal.abilities = data.abilities
TheRottenImmortal.unitType = data.unitType
TheRottenImmortal.spriteData = data.instanceDefaults
TheRottenImmortal.artefactDrops = data.artefactDrops

setmetatable(TheRottenImmortal, { __index = BaseBoss })

return TheRottenImmortal
