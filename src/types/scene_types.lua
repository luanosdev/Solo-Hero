---@meta
-- Este arquivo define os tipos de dados para os argumentos
-- passados entre as cenas através do SceneManager.

---@class GameLoadingSceneArgs
---@field portalData PortalData Os dados completos do portal para o qual o jogador está entrando.
---@field hunterId string O ID do caçador selecionado para a missão.

---@class GameplaySceneArgs
---@field portalData PortalData Os dados completos do portal.
---@field hunterId string O ID do caçador selecionado.
---@field preloadedAssets table<string, MapAssets> Tabela contendo todos os ativos pré-carregados pela GameLoadingScene.

return {}
