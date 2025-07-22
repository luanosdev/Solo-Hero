--------------------------------------------------------------------------------
--- Tipos de Dados para o Sistema de Portais
--- @description Define a estrutura e os contratos de dados para
--- as configurações de portais e hordas.
--------------------------------------------------------------------------------

-- Define a estratégia de posicionamento para um padrão de spawn.
---@alias SpawnStrategy 'offscreen' | 'locator'

---@alias SpawnPatternType 'Wave' | 'Trickle' Tipo do padrão de spawn.

---@class SpawnEdge
---@field N boolean
---@field S boolean
---@field E boolean
---@field W boolean

---@class SpawnPatternData
---@field type SpawnPatternType Tipo do padrão de spawn.
---@field enemyClass table A classe do inimigo a ser spawnado.
---@field interval number Intervalo em segundos (entre ondas para 'Wave', por inimigo para 'Trickle').
---@field count number Quantidade de inimigos por evento (para 'Wave').
---@field maxConcurrent number Limite de inimigos deste tipo no mundo.
---@field maxSpawnsPerFrame number Limite de spawns por frame para diluir o custo.
---@field strategy SpawnStrategy A estratégia de posicionamento.
---@field spawnEdges SpawnEdge|nil Usado se a estratégia for 'offscreen'.
---@field locatorPoolName string|nil Usado se a estratégia for 'locator'.

---@class PhaseData
---@field duration number Duração da fase em segundos.
---@field spawnPatterns SpawnPatternData[] Uma lista de padrões de spawn ativos durante esta fase.

---@class BossEventData
---@field time number O segundo exato em que o boss deve aparecer.
---@field bossClass table A classe do boss a ser spawnado.
---@field rank Rank O rank do boss.

---@class HordeConfigData
---@field bossEvents BossEventData[]
---@field phases PhaseData[]

---@class PortalData
---@field id string ID único do portal (e.g., "rank_e_01_floresta_zumbi").
---@field name string Nome do portal para a UI.
---@field rank Rank Rank de dificuldade do portal.
---@field mapId string ID do mapa a ser carregado (e.g., "jungle").
---@field hordeConfig HordeConfigData A configuração da horda para este portal.
-- Outras propriedades como recompensas, eventos aleatórios, etc., podem ser adicionadas aqui.
