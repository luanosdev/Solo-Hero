--[[
    Drop Manager
    Gerencia os drops de bosses e outros inimigos
]]

local ManagerRegistry = require("src.managers.manager_registry")
local DropEntity = require("src.entities.drop_entity")

local DropManager = {
    activeDrops = {}, -- Lista de drops ativos no mundo
}

--[[
    Inicializa o gerenciador de drops
]]
function DropManager:init()
    self.activeDrops = {}
    self.playerManager = ManagerRegistry:get("playerManager")
    self.enemyManager = ManagerRegistry:get("enemyManager")
    self.runeManager = ManagerRegistry:get("runeManager")
    self.floatingTextManager = ManagerRegistry:get("floatingTextManager")
end

--[[
    Processa os drops de um boss derrotado
    @param boss O boss que foi derrotado
]]
function DropManager:processBossDrops(boss)
    -- Obtém a configuração de drops do mundo atual
    local worldConfig = self.enemyManager.worldConfig
    if not worldConfig or not worldConfig.bossConfig or not worldConfig.bossConfig.drops then 
        print("Aviso: Configuração de drops não encontrada para o mundo atual")
        return 
    end
    
    local bossConfig = worldConfig.bossConfig.drops[boss.class]
    if not bossConfig then 
        print("Aviso: Configuração de drops não encontrada para o boss:", boss.class.name)
        return 
    end
    
    print("Processando drops do boss:", boss.class.name)
    
    -- Lista para armazenar todos os drops que serão criados
    local dropsToCreate = {}
    
    -- Primeiro processa os drops garantidos
    for _, drop in ipairs(bossConfig.drops) do
        if drop.guaranteed then
            print("Criando drop garantido:", drop.type)
            table.insert(dropsToCreate, drop)
        end
    end
    
    -- Depois processa os drops com chance
    for _, drop in ipairs(bossConfig.drops) do
        if not drop.guaranteed and math.random() <= (drop.weight / 100) then
            print("Criando drop com chance:", drop.type)
            table.insert(dropsToCreate, drop)
        end
    end
    
    -- Espalha os drops em um círculo ao redor do boss
    local dropCount = #dropsToCreate
    local spreadRadius = 30 -- Raio do círculo onde os drops serão espalhados
    local angleStep = (2 * math.pi) / dropCount -- Ângulo entre cada drop
    
    for i, drop in ipairs(dropsToCreate) do
        -- Calcula o ângulo para este drop
        local angle = angleStep * (i - 1) + (math.random() * 0.2 - 0.1) -- Adiciona um pouco de aleatoriedade
        
        -- Calcula a posição do drop no círculo
        local dropX = boss.positionX + math.cos(angle) * spreadRadius
        local dropY = boss.positionY + math.sin(angle) * spreadRadius
        
        self:createDrop(drop, dropX, dropY)
    end
end

--[[
    Cria uma entidade de drop no mundo
    @param drop Configuração do drop
    @param x Posição X do drop
    @param y Posição Y do drop
]]
function DropManager:createDrop(drop, x, y)
    local dropEntity = DropEntity:new(x, y, drop)
    table.insert(self.activeDrops, dropEntity)
end

--[[
    Atualiza os drops ativos
    @param dt Delta time
]]
function DropManager:update(dt)
    for i = #self.activeDrops, 1, -1 do
        local drop = self.activeDrops[i]
        if drop:update(dt, PlayerManager) then
            -- Se o drop foi coletado, aplica seus efeitos
            self:applyDrop(drop.config)
            table.remove(self.activeDrops, i)
        end
    end
end

--[[
    Aplica um drop ao jogador
    @param drop O drop a ser aplicado
]]
function DropManager:applyDrop(drop)
    if drop.type == "rune" then
        print("Gerando runa de raridade:", drop.rarity)
        local rune = self.runeManager:generateRune(drop.rarity)
        self.playerManager.addRune(rune)
        
    elseif drop.type == "gold" then
        local amount = math.random(drop.amount.min, drop.amount.max)
        self.playerManager.gold = self.playerManager.gold + amount
        
        -- Mostra texto flutuante do ouro obtido
        self.floatingTextManager:addText(
            self.playerManager.player.position.x,
            self.playerManager.player.position.y - self.playerManager.player.radius - 30,
            "+" .. amount .. " Ouro",
            true,
            self.playerManager.player.position,
            {1, 0.84, 0} -- Cor dourada
        )
    end
end

--[[
    Desenha os drops ativos
]]
function DropManager:draw()
    for _, drop in ipairs(self.activeDrops) do
        drop:draw()
    end
end

return DropManager 