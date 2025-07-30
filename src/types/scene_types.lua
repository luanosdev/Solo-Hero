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
---@field renderPipeline RenderPipeline

---@class GameplaySceneContext
---@field registry SceneManagerRegistry
---@field renderPipeline RenderPipeline
---@field serviceLocator ServiceLocator
---@field args GameplaySceneArgs

---@class AttackContext
---@description Contém todos os dados puros necessários para um controller de ataque tomar decisões.
---@field playerPosition Vector2D Posição atual do jogador.
---@field targetPosition Vector2D Posição do alvo (mouse ou inimigo).
---@field playerAngle number Ângulo atual do jogador.
---@field isMoving boolean Se o jogador está se movendo.
---@field playerRadius number Raio do jogador.
---@field finalStats table<StatKey, number> Tabela com os stats finais do jogador.

---@class AttackHitResult
---@field entitiesHit BaseEnemy[] A lista de inimigos atingidos.
---@field damageDealt number O dano total causado neste hit.
---@field isCritical boolean Se o golpe foi crítico.
---@field isSuperCritical boolean Se o golpe foi super crítico.

-- ===================================================================
-- Tipos de Descritores de Ataque (NOVO)
-- ===================================================================

---@class CircleAttackDescriptor
---@field shape "circle" O tipo de forma do ataque.
---@field origin Vector2D O centro do círculo.
---@field radius number O raio do círculo.

---@class PolygonAttackDescriptor
---@field shape "polygon" O tipo de forma do ataque.
---@field vertices Vector2D[] Os vértices do polígono.
---@field origin Vector2D A origem do polígono.
---@field range number O alcance (comprimento) do polígono.

---@class ConeAttackDescriptor
---@field shape "cone" O tipo de forma do ataque.
---@field origin Vector2D A origem do cone.
---@field angle number O ângulo central do cone em radianos.
---@field range number O alcance (comprimento) do cone.
---@field halfWidth number Metade da largura angular do cone em radianos.

---@class LineAttackDescriptor
---@field shape "line" O tipo de forma do ataque.
---@field startPos Vector2D A posição inicial da linha.
---@field endPos Vector2D A posição final da linha.
---@field width number A largura da linha.

---@alias AttackDescriptor CircleAttackDescriptor | ConeAttackDescriptor | LineAttackDescriptor | PolygonAttackDescriptor

return {}
