------------------------------------------------
-- ActiveSkillsDisplay
-- Componente de UI para exibir a arma e as runas equipadas, junto com seus cooldowns.
------------------------------------------------

local Logger = require("src.libs.logger")
local Colors = require("src.ui.colors")

---@class ActiveSkillsDisplay
---@field playerManager PlayerManager
---@field itemDataManager ItemDataManager
---@field skills table
---@field silhouetteShader love.Shader
local ActiveSkillsDisplay = {}
ActiveSkillsDisplay.__index = ActiveSkillsDisplay

-- Configurações visuais
local CONFIG = {
    y_position = love.graphics.getHeight() - 70,
    icon_size = 58,
    spacing = 72,
    background_color_alpha = 0.5, -- Opacidade do fundo quando o cooldown está cheio
    border_width = 1.5,
    shockwave_duration = 0.2,
    shockwave_max_radius_mult = 1.6,
    -- Efeito de expansão no shockwave
    shockwave_expand_mult = 0.2, -- Aumenta 20%
}

-- Mapeamento de cores por raridade de arma
local RARITY_COLORS = {
    E = { 150 / 255, 150 / 255, 150 / 255, 1 }, -- Cinza
    D = { 100 / 255, 200 / 255, 100 / 255, 1 }, -- Verde
    C = { 100 / 255, 150 / 255, 255 / 255, 1 }, -- Azul
    B = { 200 / 255, 100 / 255, 255 / 255, 1 }, -- Roxo
    A = { 255 / 255, 200 / 255, 80 / 255, 1 },  -- Laranja
    S = { 255 / 255, 100 / 255, 100 / 255, 1 }, -- Vermelho
}

-- Cores específicas para cada runa
local RUNE_COLORS = {
    rune_orbital_e = { 0 / 255, 200 / 255, 255 / 255, 1 }, -- Ciano
    rune_thunder_e = { 255 / 255, 255 / 255, 0 / 255, 1 }, -- Amarelo
    rune_aura_e = { 220 / 255, 50 / 255, 220 / 255, 1 },   -- Magenta
    -- Adicione outras runas aqui
}

--- Cria uma nova instância do ActiveSkillsDisplay.
--- @param playerManager PlayerManager A instância do gerenciador do jogador.
--- @param itemDataManager ItemDataManager A instância do gerenciador de dados de itens.
--- @return ActiveSkillsDisplay
function ActiveSkillsDisplay:new(playerManager, itemDataManager)
    local instance = setmetatable({}, ActiveSkillsDisplay)
    instance.playerManager = playerManager
    instance.itemDataManager = itemDataManager
    instance.skills = {} -- Tabela para armazenar o estado de cada slot de habilidade
    instance.silhouetteShader = love.graphics.newShader("src/ui/shaders/silhouette.fs")
    instance.debugged = false

    return instance
end

--- Atualiza o estado dos ícones de habilidade.
--- @param dt number Delta time.
function ActiveSkillsDisplay:update(dt)
    if not self.playerManager or not self.playerManager.player or not self.playerManager.state then
        self:_updateSkillList({}, dt) -- Limpa a lista se o jogador não for válido
        return
    end

    local currentSkills = {}

    local finalStats = self.playerManager:getCurrentFinalStats()

    -- 1. Arma
    local weapon = self.playerManager.equippedWeapon
    if weapon and weapon.itemInstance and weapon.attackInstance then
        local baseData = weapon:getBaseData()
        local cooldownTotal = baseData.cooldown / finalStats.attackSpeed
        local cooldownRemaining = weapon.attackInstance.cooldownRemaining
        local progress = 1 -- Começa como pronto
        if cooldownTotal and cooldownTotal > 0 and cooldownRemaining then
            progress = 1 - (cooldownRemaining / cooldownTotal)
        end

        Logger.debug("ActiveSkillsDisplay", "weapon: " .. weapon.itemInstance.itemBaseId)
        Logger.debug("ActiveSkillsDisplay", "progress: " .. progress)
        table.insert(currentSkills, {
            id = weapon.itemInstance.itemBaseId,
            type = "weapon",
            progress = progress,
        })

        Logger.debug("ActiveSkillsDisplay", "currentSkills: " .. #currentSkills)
    else
        Logger.debug("ActiveSkillsDisplay", "weapon: nil")
    end

    -- 2. Runas
    for _, ability in pairs(self.playerManager.activeRuneAbilities or {}) do
        if ability and ability.runeItemData then
            local runeItem = ability.runeItemData
            local id = runeItem.itemBaseId or runeItem.id
            local progress

            if ability.effect == "orbital" then
                -- A runa orbital não tem um cooldown tradicional, então baseamos no tempo de rotação.
                -- Isso é uma aproximação visual, podemos ajustar se necessário.
                local rotationTime = (2 * math.pi) / (ability.rotationSpeed or 2)
                progress = (love.timer.getTime() % rotationTime) / rotationTime
            else
                -- Para outras runas, usamos a lógica de cooldown padrão.
                local cooldownTotal = ability.cooldown
                local cooldownRemaining = ability.currentCooldown

                if cooldownTotal and cooldownRemaining and cooldownTotal > 0 then
                    progress = 1 - (cooldownRemaining / cooldownTotal)
                else
                    progress = 1 -- Se não houver cooldown, considera-se sempre pronta.
                end
            end

            table.insert(currentSkills, {
                id = id,
                type = "rune",
                progress = progress,
            })
        end
    end

    self:_updateSkillList(currentSkills, dt)
end

--- Lógica interna para atualizar a lista de skills, carregar imagens e gerenciar efeitos.
function ActiveSkillsDisplay:_updateSkillList(currentSkills, dt)
    -- Marca todas as skills existentes para verificação
    for _, skill in ipairs(self.skills) do
        skill.isActive = false
    end

    -- Itera sobre as skills atuais que devem ser exibidas
    for _, currentSkillData in ipairs(currentSkills) do
        local existingSkill = self:_findSkillById(currentSkillData.id)

        if existingSkill then
            -- Skill já existe, apenas atualiza
            local previous_progress = existingSkill.progress
            local wasReady = existingSkill.cooldown_ready

            existingSkill.progress = currentSkillData.progress
            existingSkill.cooldown_ready = currentSkillData.progress >= 1
            existingSkill.isActive = true

            -- O pulso deve acontecer quando a skill FICA pronta.
            -- Condição 1: Não estava pronta e agora está (progress >= 1).
            local justBecameReady = not wasReady and existingSkill.cooldown_ready
            -- Condição 2: Não estava pronta, e o progresso regrediu.
            -- Isso significa que ela ficou pronta e foi usada antes da UI atualizar.
            local wasUsedWithoutBeingReady = not wasReady and existingSkill.progress < previous_progress

            if justBecameReady or wasUsedWithoutBeingReady then
                existingSkill.shockwaveTimer = 0 -- Acabou de ficar pronta ou foi usada
            end
        else
            -- Nova skill, precisa ser criada
            local imagePath = nil
            local baseItemData = self.itemDataManager:getBaseItemData(currentSkillData.id)

            if baseItemData then
                imagePath = baseItemData.iconPath -- Usa o novo campo com o caminho original
            end

            if imagePath then
                local success, img = pcall(love.graphics.newImage, imagePath)
                if success then
                    local isReady = currentSkillData.progress >= 1

                    -- Define a cor baseada no tipo e ID/Raridade
                    local color = { 1, 1, 1, 1 } -- Cor padrão (branco)
                    if currentSkillData.type == "weapon" and baseItemData and baseItemData.rarity then
                        -- Usa a cor de texto do rank definida em colors.lua
                        color = Colors.rankDetails[baseItemData.rarity].text or color
                    elseif currentSkillData.type == "rune" and baseItemData then
                        -- Usa a cor definida diretamente nos dados da runa
                        color = baseItemData.color or color
                    end

                    table.insert(self.skills, {
                        id = currentSkillData.id,
                        type = currentSkillData.type,
                        image = img,
                        progress = currentSkillData.progress,
                        cooldown_ready = isReady,
                        shockwaveTimer = isReady and 0 or -1,
                        color = color,
                        isActive = true,
                    })
                else
                    Logger.warn("[ActiveSkillsDisplay]",
                        string.format(" Falha ao carregar imagem para a skill '%s' em '%s'",
                            currentSkillData.id, imagePath))
                end
            end
        end
    end

    -- Remove as skills que não estão mais ativas
    for i = #self.skills, 1, -1 do
        local skill = self.skills[i]
        if not skill.isActive then
            table.remove(self.skills, i)
        end
    end

    -- Atualiza o efeito de shockwave
    for _, skill in ipairs(self.skills) do
        if skill.shockwaveTimer >= 0 then
            skill.shockwaveTimer = skill.shockwaveTimer + dt
            if skill.shockwaveTimer > CONFIG.shockwave_duration then
                skill.shockwaveTimer = -1
            end
        end
    end
end

--- Encontra uma skill na lista interna pelo seu ID de item base.
function ActiveSkillsDisplay:_findSkillById(id)
    for _, skill in ipairs(self.skills) do
        if skill.id == id then
            return skill
        end
    end
    return nil
end

--- Desenha os ícones de habilidade.
function ActiveSkillsDisplay:draw()
    if #self.skills == 0 then return end

    local base_size = CONFIG.icon_size
    local weapon_size = base_size * 1.2
    local rune_size = base_size

    -- Calcula a largura total do grupo de ícones para centralização
    local total_width
    if #self.skills > 1 then
        local first_skill_radius = ((self.skills[1].type == "weapon") and weapon_size or rune_size) / 2
        local last_skill_radius = ((self.skills[#self.skills].type == "weapon") and weapon_size or rune_size) / 2
        local centers_distance = (#self.skills - 1) * CONFIG.spacing
        total_width = centers_distance + first_skill_radius + last_skill_radius
    elseif #self.skills == 1 then
        total_width = (self.skills[1].type == "weapon") and weapon_size or rune_size
    else
        total_width = 0
    end

    -- Calcula a posição inicial para o centro do primeiro ícone
    local first_skill_radius = #self.skills > 0 and ((self.skills[1].type == "weapon") and weapon_size or rune_size) / 2 or
        0
    local start_x = (love.graphics.getWidth() - total_width) / 2 + first_skill_radius

    for i, skill in ipairs(self.skills) do
        local current_size = (skill.type == "weapon") and weapon_size or rune_size
        local x = start_x + (i - 1) * CONFIG.spacing
        local y = CONFIG.y_position
        local radius = current_size / 2
        local skill_color = skill.color or { 1, 1, 1, 1 }

        -- Animação de expansão horizontal no shockwave
        local expand_scale = 1
        if skill.shockwaveTimer >= 0 then
            local shock_progress = skill.shockwaveTimer / CONFIG.shockwave_duration
            -- math.sin(x * pi) cria uma curva suave de 0 a 1 e de volta a 0
            expand_scale = 1 + CONFIG.shockwave_expand_mult * math.sin(shock_progress * math.pi)
        end

        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.scale(expand_scale, expand_scale) -- Aplica a expansão em ambos os eixos

        -- Desenha o fundo com cor baseada no progresso do cooldown
        local r, g, b = skill_color[1], skill_color[2], skill_color[3]
        -- Interpola a opacidade do fundo de 0 até a opacidade final
        local backgroundAlpha = skill.progress * CONFIG.background_color_alpha
        love.graphics.setColor(r, g, b, backgroundAlpha)
        love.graphics.circle("fill", 0, 0, radius)

        -- Desenha a borda
        love.graphics.setLineWidth(CONFIG.border_width)
        love.graphics.setColor(skill_color)
        love.graphics.circle("line", 0, 0, radius)

        -- Desenha o ícone
        if skill.image then
            local prevShader = love.graphics.getShader()
            love.graphics.setShader() -- Remove o shader de silhueta

            local imgW, imgH = skill.image:getDimensions()
            local scale = current_size * 0.7 / math.max(imgW, imgH) -- Usa o tamanho atual
            love.graphics.setColor(1, 1, 1, 1)                      -- Garante que a imagem seja desenhada com sua cor original
            love.graphics.draw(skill.image, 0, 0, 0, scale, scale, imgW / 2, imgH / 2)

            love.graphics.setShader(prevShader)
        end

        love.graphics.pop()

        -- Desenha o efeito de shockwave (fora do push/pop para não ser escalado)
        if skill.shockwaveTimer >= 0 then
            local shockProgress = skill.shockwaveTimer / CONFIG.shockwave_duration
            local currentRadius = radius * (1 + (shockProgress * (CONFIG.shockwave_max_radius_mult - 1)))
            local alpha = (1 - shockProgress) * skill_color[4]

            love.graphics.setLineWidth(CONFIG.border_width * (2.5 - shockProgress * 1.5))
            love.graphics.setColor(skill_color[1], skill_color[2], skill_color[3], alpha)
            love.graphics.circle("line", x, y, currentRadius)
        end
    end

    -- Reseta a cor e a largura da linha
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

return ActiveSkillsDisplay
