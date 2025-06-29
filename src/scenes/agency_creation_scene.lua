local SceneManager = require("src.core.scene_manager")
local ManagerRegistry = require("src.managers.manager_registry")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local UIElements = require("src.ui.ui_elements")
local InputField = require("src.ui.components.InputField")

local AgencyCreationScene = {}

-- Gerenciamento de estado da cena
local agencyNameField
local registerButton = {
    rect = {},
    text = "",
    isHovering = false,
    isDisabled = true -- Botão começa desabilitado
}

local function registerAgency()
    local agencyName = agencyNameField:getText()
    if string.gsub(agencyName, "%s+", "") ~= "" then
        local agencyManager = ManagerRegistry:get("agencyManager")
        agencyManager:createAgency(agencyName)
        SceneManager.switchScene("lobby_scene")
    else
        print("O nome da agência não pode ser vazio.")
    end
end

function AgencyCreationScene:load()
    local ww, wh = ResolutionUtils.getGameDimensions()

    -- Posição do InputField será calculada dinamicamente no draw,
    -- mas o objeto precisa ser criado aqui.
    agencyNameField = InputField:new({
        rect = { x = (ww - 400) / 2, y = 0, w = 400, h = 40 }, -- y será atualizado
        font = fonts.main_large,
        text = "",                                             -- Iniciar com texto vazio
        isActive = true,
        onEnter = registerAgency
    })

    -- Configuração do botão
    registerButton.text = "Registrar Agência"
    registerButton.isHovering = false
    registerButton.onClick = registerAgency
end

function AgencyCreationScene:update(dt)
    agencyNameField:update(dt)

    -- Habilita ou desabilita o botão com base no texto do input
    local agencyName = agencyNameField:getText()
    if string.gsub(agencyName, "%s+", "") == "" then
        registerButton.isDisabled = true
    else
        registerButton.isDisabled = false
    end
end

function AgencyCreationScene:draw()
    local ww, wh = ResolutionUtils.getGameDimensions()
    love.graphics.clear(colors.window_bg)

    -- Aumenta a altura do container para acomodar o texto
    local contractW, contractH = 800, 850
    local contractX, contractY = (ww - contractW) / 2, (wh - contractH) / 2

    UIElements.drawWindowFrame(contractX, contractY, contractW, contractH, nil)

    -- Layout dinâmico usando uma variável para a posição Y atual
    local currentY = contractY + 30

    love.graphics.setFont(fonts.title_large)
    love.graphics.setColor(colors.text_title)
    love.graphics.printf("Contrato de Fundação de Agência de Caçadores", contractX, currentY, contractW, "center")
    currentY = currentY + fonts.title_large:getHeight() + 25

    love.graphics.setFont(fonts.main)
    love.graphics.setColor(colors.text_muted)
    local contractText =
    [[Ao preencher este formulário gloriosamente burocrático, o(a) abaixo-assinado(a) declara, sem direito de reclamar depois, que:

- Está plenamente ciente de que gerir uma agência de caçadores envolve riscos letais, decisões duvidosas e uma quantidade questionável de papelada.

- Assume total responsabilidade por cada caçador que decidir colocar a vida em risco em nome da agência — inclusive aqueles que se jogarem no portal achando que é tobogã.

- Concorda que a reputação da agência será afetada por suas ações: se sair vitorioso, subirá de ranking e parecerá competente. Se perder caçadores, a reputação cairá mais rápido que o moral de um recruta cercado por demônios.

- Entende que todas as agências começam no Ranking E, ou seja: praticamente irrelevantes. Mas com esforço (e talvez um ou dois sacrifícios estratégicos), há esperança de alcançar o prestigiado Ranking S, onde as chances de morrer são... apenas um pouco menores.

- Autoriza este contrato a ser armazenado permanentemente nas profundezas do Arquivo Central das Burradas Registradas.]]

    -- Calcula a altura do texto com quebra de linha para posicionar o resto
    local textFont = fonts.main
    local _, wrappedLines = textFont:getWrap(contractText, contractW - 80)
    local textHeight = #wrappedLines * textFont:getHeight() * textFont:getLineHeight()

    love.graphics.printf(contractText, contractX + 40, currentY, contractW - 80, "left")
    currentY = currentY + textHeight + 60 -- Aumenta o espaço

    -- Atualiza a posição Y do input field e o desenha
    agencyNameField.rect.y = currentY
    agencyNameField:draw()
    currentY = currentY + agencyNameField.rect.h + 5 -- Avança o Y após desenhar o input

    -- Seção do Nome da Agência (agora abaixo do input como legenda)
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_muted)
    love.graphics.printf("Nome da Agência", contractX, currentY, contractW, "center")
    currentY = currentY + fonts.main:getHeight() + 30 -- Avança o Y para o próximo elemento

    -- Seção de assinatura
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_muted)
    local signatureText = "Assinatura do(a) Fundador(a): Eu"
    local dateText = "Data: " .. os.date("%d / %m / %Y")
    love.graphics.print(signatureText, contractX + 50, currentY)
    love.graphics.print(dateText, contractX + contractW - 50 - fonts.main:getWidth(dateText), currentY)
    currentY = currentY + fonts.main:getHeight() + 30

    -- Posiciona o botão e o texto de confirmação na parte inferior do painel
    local bottomAreaY = contractY + contractH
    local confirmationTextY = bottomAreaY - 140
    local buttonY = bottomAreaY - 80

    love.graphics.setFont(fonts.tooltip)
    love.graphics.setColor(colors.text_muted)
    local confirmationText =
    'Ao clicar em "Registrar Agência", você confirma que leu tudo isso (mesmo que não tenha lido) e aceita os termos acima (mesmo que esteja arrependido).'
    love.graphics.printf(confirmationText, contractX + 50, confirmationTextY, contractW - 100, "center")

    -- Atualiza a posição do botão e o desenha
    registerButton.rect = { x = (ww - 250) / 2, y = buttonY, w = 250, h = 50 }
    local btnColors = colors.button_primary
    UIElements.drawButton({
        rect = registerButton.rect,
        text = registerButton.text,
        isHovering = registerButton.isHovering,
        isDisabled = registerButton.isDisabled, -- Passa o estado para a função de desenho
        font = fonts.main_large,
        colors = btnColors,                     -- Passa a tabela de cores completa que inclui as cores de desabilitado
    })
end

function AgencyCreationScene:keypressed(key)
    agencyNameField:keypressed(key)
end

function AgencyCreationScene:textinput(t)
    agencyNameField:textinput(t)
end

function AgencyCreationScene:mousepressed(x, y, button)
    -- Lógica de clique para o botão (só funciona se não estiver desabilitado)
    if not registerButton.isDisabled and registerButton.isHovering and button == 1 and registerButton.onClick then
        registerButton.onClick()
        return -- Impede a execução de continuar após a troca de cena
    end
    -- Delega o clique para o campo de input
    agencyNameField:mousepressed(x, y, button)
end

function AgencyCreationScene:mousemoved(x, y)
    -- Lógica de hover (só se aplica se o botão não estiver desabilitado)
    local r = registerButton.rect
    if not registerButton.isDisabled and r and x > r.x and x < r.x + r.w and y > r.y and y < r.y + r.h then
        registerButton.isHovering = true
    else
        registerButton.isHovering = false
    end
end

function AgencyCreationScene:unload()
    agencyNameField = nil
    registerButton = {}
end

return AgencyCreationScene
