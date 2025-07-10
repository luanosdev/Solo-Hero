--------------------------------------------------------------------------------
--- @author ReyalS
--- @release 1.0
--- @license MIT
--- @description
--- Funções auxiliares globais para localização.
--- Estas funções serão disponibilizadas globalmente para facilitar o uso
--- do sistema de localização em todo o projeto.

--------------------------------------------------------------------------------
--- TIPOS E VALIDAÇÃO LDOC
--------------------------------------------------------------------------------

---@alias LocalizationKey
---| "general.loading"          # Carregando...
---| "general.error"            # Erro
---| "general.warning"          # Aviso
---| "general.success"          # Sucesso
---| "general.cancel"           # Cancelar
---| "general.confirm"          # Confirmar
---| "general.yes"              # Sim
---| "general.no"               # Não
---| "general.ok"               # OK
---| "general.close"            # Fechar
---| "general.save"             # Salvar
---| "general.load"             # Carregar
---| "general.delete"           # Deletar
---| "general.edit"             # Editar
---| "general.new"              # Novo
---| "general.back"             # Voltar
---| "general.next"             # Próximo
---| "general.previous"         # Anterior
---| "general.continue"         # Continuar
---| "weapons.circular_smash_e_001.name"        # Nome da arma
---| "weapons.circular_smash_e_001.description" # Descrição da arma
---| "weapons.cone_slash_e_001.name"            # Nome da arma
---| "weapons.cone_slash_e_001.description"     # Descrição da arma
---| "archetypes.agile.name"                    # Nome do arquétipo
---| "archetypes.agile.description"             # Descrição do arquétipo
---| "ui.agency.patrimony"                      # Patrimônio
---| "ui.agency.no_active_hunter"               # Nenhum caçador ativo
---| "ui.agency.no_active_hunter_description"   # Recrute um caçador!
---| "ui.agency.no_active_hunter_error"         # Erro: Caçador não encontrado
---| "ui.agency.max_rank"                       # RANK MÁXIMO
---| "ui.agency.unknown"                        # Agência desconhecida
---| "ui.hunter.unknown"       # Caçador desconhecido
---| "ui.rank"                 # Rank
---| "ui.health"               # Vida
---| "ui.mana"                 # Mana
---| "ui.experience"           # Experiência
---| "ui.level"                # Nível
---| "ui.inventory"            # Inventário
---| "ui.equipment"            # Equipamento
---| "ui.skills"               # Habilidades
---| "ui.stats"                # Atributos
---| "ui.menu"                 # Menu
---| "ui.settings"             # Configurações
---| "ranks.E.name"            # Rank E
---| "ranks.D.name"            # Rank D
---| "ranks.C.name"            # Rank C
---| "ranks.B.name"            # Rank B
---| "ranks.A.name"            # Rank A
---| "ranks.S.name"            # Rank S
---| "system.loading_complete" # Carregamento concluído
---| "system.saving_game"      # Salvando jogo...
---| "system.game_saved"       # Jogo salvo com sucesso
---| "system.game_loaded"      # Jogo carregado com sucesso

---@alias WeaponLocalizationKey
---| "weapons.circular_smash_e_001.name"
---| "weapons.circular_smash_e_001.description"
---| "weapons.cone_slash_e_001.name"
---| "weapons.cone_slash_e_001.description"
---| "weapons.alternating_cone_strike_e_001.name"
---| "weapons.alternating_cone_strike_e_001.description"
---| "weapons.flame_stream_e_001.name"
---| "weapons.flame_stream_e_001.description"
---| "weapons.arrow_projectile_e_001.name"
---| "weapons.arrow_projectile_e_001.description"
---| "weapons.chain_lightning_e_001.name"
---| "weapons.chain_lightning_e_001.description"
---| "weapons.burst_projectile_e_001.name"
---| "weapons.burst_projectile_e_001.description"
---| "weapons.sequential_projectile_e_001.name"
---| "weapons.sequential_projectile_e_001.description"
---| "weapons.hammer.name"
---| "weapons.hammer.description"
---| "weapons.wooden_sword.name"
---| "weapons.wooden_sword.description"
---| "weapons.iron_sword.name"
---| "weapons.iron_sword.description"
---| "weapons.dual_daggers.name"
---| "weapons.dual_daggers.description"
---| "weapons.dual_noctilara_daggers.name"
---| "weapons.dual_noctilara_daggers.description"
---| "weapons.flamethrower.name"
---| "weapons.flamethrower.description"
---| "weapons.bow.name"
---| "weapons.bow.description"
---| "weapons.chain_laser.name"
---| "weapons.chain_laser.description"

---@alias ArchetypeLocalizationKey
---| "archetypes.agile.name"
---| "archetypes.agile.description"
---| "archetypes.alchemist_novice.name"
---| "archetypes.alchemist_novice.description"
---| "archetypes.vigorous.name"
---| "archetypes.vigorous.description"
---| "archetypes.aprendiz_rapido.name"
---| "archetypes.aprendiz_rapido.description"
---| "archetypes.sortudo_pequeno.name"
---| "archetypes.sortudo_pequeno.description"
---| "archetypes.bruto_pequeno.name"
---| "archetypes.bruto_pequeno.description"
---| "archetypes.poison_resistant.name"
---| "archetypes.poison_resistant.description"
---| "archetypes.hardy.name"
---| "archetypes.hardy.description"
---| "archetypes.collector.name"
---| "archetypes.collector.description"
---| "archetypes.vigilant.name"
---| "archetypes.vigilant.description"
---| "archetypes.frenetic.name"
---| "archetypes.frenetic.description"
---| "archetypes.field_medic.name"
---| "archetypes.field_medic.description"
---| "archetypes.cautious.name"
---| "archetypes.cautious.description"

local LocalizationManager = require("src.managers.localization_manager")

--- Módulo de funções auxiliares de localização
local LocalizationHelpers = {}

--- Obtém uma tradução usando uma chave de localização
--- @param key LocalizationKey A chave da tradução
--- @param params table|nil Parâmetros para interpolação na string (opcional)
--- @return string translation A tradução encontrada ou a chave se não encontrada
function LocalizationHelpers.getText(key, params)
    local manager = LocalizationManager:getInstance()
    return manager:getText(key, params)
end

--- Verifica se uma chave de tradução existe
--- @param key LocalizationKey A chave da tradução
--- @return boolean exists Se a chave existe
function LocalizationHelpers.keyExists(key)
    local manager = LocalizationManager:getInstance()
    return manager:keyExists(key)
end

--- Define o idioma ativo do sistema
--- @param languageId "pt_BR"|"en" ID do idioma para ativar
--- @return boolean success Se a mudança foi bem-sucedida
function LocalizationHelpers.setLanguage(languageId)
    local manager = LocalizationManager:getInstance()
    return manager:setLanguage(languageId)
end

--- Obtém o idioma atualmente ativo
--- @return "pt_BR"|"en" currentLanguage
function LocalizationHelpers.getCurrentLanguage()
    local manager = LocalizationManager:getInstance()
    return manager:getCurrentLanguage()
end

--- Obtém lista de idiomas disponíveis
--- @return table<string, LanguageInfo> availableLanguages
function LocalizationHelpers.getAvailableLanguages()
    local manager = LocalizationManager:getInstance()
    return manager:getAvailableLanguages()
end

--- Recarrega todas as traduções (útil para development)
function LocalizationHelpers.reload()
    local manager = LocalizationManager:getInstance()
    manager:reload()
end

--- Obtém estatísticas do sistema de localização
--- @return table stats Estatísticas de uso e cache
function LocalizationHelpers.getStats()
    local manager = LocalizationManager:getInstance()
    return manager:getStats()
end

--- Função auxiliar específica para obter nome e descrição de armas
--- @param weaponId string ID da arma (ex: "cone_slash_e_001")
--- @return string name, string description Nome e descrição da arma
function LocalizationHelpers.getWeaponInfo(weaponId)
    local nameKey = "weapons." .. weaponId .. ".name"
    local descKey = "weapons." .. weaponId .. ".description"

    local name = LocalizationHelpers.getText(nameKey)
    local description = LocalizationHelpers.getText(descKey)

    return name, description
end

--- Função auxiliar específica para obter nome e descrição de arquétipos
--- @param archetypeId string ID do arquétipo (ex: "agile")
--- @return string name, string description Nome e descrição do arquétipo
function LocalizationHelpers.getArchetypeInfo(archetypeId)
    local nameKey = "archetypes." .. archetypeId .. ".name"
    local descKey = "archetypes." .. archetypeId .. ".description"

    local name = LocalizationHelpers.getText(nameKey)
    local description = LocalizationHelpers.getText(descKey)

    return name, description
end

--- Função auxiliar específica para obter informações de rank
--- @param rankId "E"|"D"|"C"|"B"|"A"|"S" ID do rank
--- @return string name, string description Nome e descrição do rank
function LocalizationHelpers.getRankInfo(rankId)
    local nameKey = "ranks." .. rankId .. ".name"
    local descKey = "ranks." .. rankId .. ".description"

    local name = LocalizationHelpers.getText(nameKey)
    local description = LocalizationHelpers.getText(descKey)

    return name, description
end

return LocalizationHelpers
