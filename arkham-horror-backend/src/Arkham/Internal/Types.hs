module Arkham.Internal.Types
  ( ArkhamChaosTokenInternal(..)
  , ArkhamInvestigatorInternal(..)
  , ArkhamScenarioInternal(..)
  , ArkhamChaosTokenResult(..)
  , ArkhamActionType(..)
  , ArkhamUpkeepPhaseInternal(..)
  , ArkhamEnemyPhaseInternal(..)
  , ArkhamMythosPhaseInternal(..)
  , ArkhamInvestigationPhaseInternal(..)
  , ArkhamCardTrait(..)
  )
where

import Arkham.Entity.ArkhamGame
import Arkham.Types.ChaosToken
import Arkham.Types.GameState
import Arkham.Types.Investigator
import Base.Lock
import ClassyPrelude
import Control.Monad.Random

data ArkhamCardTrait = Tome | Ghoul

data ArkhamActionType = AnyAction | TraitRestrictedAction ArkhamCardTrait

-- TODO: Should this be a reader with access to the investigator... probably
data ArkhamInvestigatorInternal = ArkhamInvestigatorInternal
  { investigatorElderSignToken :: ArkhamChaosTokenInternal
  , investigatorOnDefeatEnemy :: ArkhamGameState -> ArkhamGameState
  , investigatorAvailableActions :: [ArkhamActionType]
  }

data ArkhamChaosTokenResult = Modifier Int | Failure

data ArkhamChaosTokenInternal = ArkhamChaosTokenInternal
  { tokenToResult :: ArkhamGameState -> ArkhamInvestigator -> ArkhamChaosTokenResult
  , tokenOnFail :: ArkhamGameState -> ArkhamInvestigator -> ArkhamGameState
  , tokenOnSuccess :: ArkhamGameState -> ArkhamInvestigator -> ArkhamGameState
  , tokenOnReveal :: ArkhamGameState -> ArkhamInvestigator -> ArkhamGameState
  }

data ArkhamScenarioInternal = ArkhamScenarioInternal
  { scenarioName :: Text
  , scenarioSetup :: forall m. MonadRandom m => ArkhamGameState -> m ArkhamGameState
  , tokenMap :: HashMap ArkhamChaosToken ArkhamChaosTokenInternal
  , scenarioMythosPhase :: ArkhamMythosPhaseInternal
  , scenarioInvestigationPhase :: ArkhamInvestigationPhaseInternal
  , scenarioEnemyPhase :: ArkhamEnemyPhaseInternal
  , scenarioUpkeepPhase :: ArkhamUpkeepPhaseInternal
  , scenarioRun :: ArkhamGame -> IO ArkhamGame
  }

data ArkhamMythosPhaseInternal = ArkhamMythosPhaseInternal
  { mythosPhaseOnEnter :: PhaseStep
  , mythosPhaseAddDoom :: PhaseStep
  , mythosPhaseCheckAdvance :: PhaseStep
  , mythosPhaseDrawEncounter :: PhaseStep
  , mythosPhaseOnExit :: PhaseStep
  }

type PhaseStep
  = forall m . MonadIO m => Lockable ArkhamGame -> m (Lockable ArkhamGame)

data ArkhamInvestigationPhaseInternal = ArkhamInvestigationPhaseInternal
  { investigationPhaseOnEnter :: PhaseStep
  , investigationPhaseTakeActions :: PhaseStep
  , investigationPhaseOnExit :: PhaseStep
  }

data ArkhamEnemyPhaseInternal = ArkhamEnemyPhaseInternal
  { enemyPhaseOnEnter :: PhaseStep
  , enemyPhaseResolveHunters :: PhaseStep
  , enemyPhaseResolveEnemies :: PhaseStep
  , enemyPhaseOnExit :: PhaseStep
  }

data ArkhamUpkeepPhaseInternal = ArkhamUpkeepPhaseInternal
  { upkeepPhaseOnEnter :: PhaseStep
  , upkeepPhaseResetActions :: PhaseStep
  , upkeepPhaseReadyExhausted :: PhaseStep
  , upkeepPhaseDrawCardsAndGainResources :: PhaseStep
  , upkeepPhaseCheckHandSize :: PhaseStep
  , upkeepPhaseOnExit :: PhaseStep
  }
