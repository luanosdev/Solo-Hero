---@class PlayerWrappedEventData
---@field player table O objeto do jogador que atravessou.
---@field newPosition Vector2D A nova posição do jogador.
---@field direction string A direção da travessia ('horizontal' ou 'vertical').

---@class PlayerLeveledUpEventData
---@field newLevel number O novo nível do jogador.
---@field levelsGained number Quantos níveis foram ganhos nesta atualização.
---@field currentExperience number A experiência atual do jogador após subir de nível.

---@class PlayerXPGainedEventData
---@field amount number A quantidade de experiência ganha.

---@class EquipmentChangedEventData
---@field slotId string O slot de equipamento que foi alterado.
---@field newItem table|nil A nova instância do item, ou nil se foi desequipado.
---@field oldItem table|nil A instância do item anterior, ou nil se o slot estava vazio.
---@field allEquipped table<string, table> Um snapshot de todos os itens equipados após a mudança.

---@class BonusesUpdatedEventData
---@field modifiers StatModifier[] Uma lista consolidada de todos os modificadores de stat daquela fonte.

---@class PlayerHealthUpdatedEventData
---@field current number A vida atual do jogador.
---@field max number A vida máxima do jogador.

---@class PlayerDiedEventData
---@description Evento emitido quando a vida do jogador chega a 0. Atualmente sem dados.

---@class PlayerStatUpdatedEventData
---@field stat StatKey O nome do stat que foi atualizado.
---@field newValue number O novo valor do stat.
---@field oldValue number O valor anterior do stat.

---@class PlayerStateInitializedEventData
---@description Evento emitido uma única vez quando o PlayerManager está totalmente inicializado.
---@field maxHealth number
---@field currentHealth number
---@field currentLevel number
---@field currentXP number
---@field flasks PotionFlask[]
---@field totalFlasks number
---@field hunterName string
---@field hunterRank string

---@class PlayerTookDamageEventData
---@field finalDamage number O dano final que o jogador sofreu.
---@field sourceEnemy BaseEnemy O inimigo que causou o dano.

---@class RequestLevelUpModalEventData
---@description Evento emitido para solicitar a abertura do modal de level up. Sem dados.

---@class LevelUpModalClosedEventData
---@description Evento emitido quando o modal de level up é fechado. Sem dados.

---@class RequestGamePauseEventData
---@description Evento emitido para solicitar a pausa do jogo. Sem dados.

---@class RequestGameUnpauseEventData
---@description Evento emitido para solicitar que o jogo seja despausado. Sem dados.

---@class PotionStateUpdatedEventData
---@description Evento emitido quando o estado dos frascos de poção muda.
---@field flasks PotionFlask[] O estado atual de todos os frascos.
---@field totalFlasks number Número total de frascos

---@class PotionUseRequestedEventData
---@description Evento emitido para solicitar o uso de uma poção. Sem dados.

---@class EnemyKilledEventData
---@description Evento emitido quando um inimigo é eliminado.
---@field enemy BaseEnemy O inimigo que foi eliminado.
