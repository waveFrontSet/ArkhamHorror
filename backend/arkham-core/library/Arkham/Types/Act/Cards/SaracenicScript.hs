module Arkham.Types.Act.Cards.SaracenicScript
  ( SaracenicScript(..)
  , saracenicScript
  ) where

import Arkham.Prelude

import Arkham.Act.Cards qualified as Cards
import Arkham.Asset.Cards qualified as Assets
import Arkham.Types.Act.Attrs
import Arkham.Types.Act.Runner
import Arkham.Types.CampaignLogKey
import Arkham.Types.Card
import Arkham.Types.Card.PlayerCard
import Arkham.Types.Classes
import Arkham.Types.Game.Helpers
import Arkham.Types.GameValue
import Arkham.Types.InvestigatorId
import Arkham.Types.Matcher
import Arkham.Types.Message

newtype SaracenicScript = SaracenicScript ActAttrs
  deriving anyclass (IsAct, HasAbilities, HasModifiersFor env)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

saracenicScript :: ActCard SaracenicScript
saracenicScript = act
  (1, A)
  SaracenicScript
  Cards.saracenicScript
  (Just $ GroupClueCost (PerPlayer 2) (LocationWithTitle "Whateley Ruins"))

instance ActRunner env => RunMessage env SaracenicScript where
  runMessage msg a@(SaracenicScript attrs@ActAttrs {..}) = case msg of
    AdvanceAct aid _ | aid == actId && onSide B attrs -> do
      survived <- getHasRecord DrHenryArmitageSurvivedTheDunwichLegacy
      investigatorIds <- map unInScenarioInvestigatorId
        <$> getSetList @InScenarioInvestigatorId ()
      investigatorEsotericFormulaPairs <- for investigatorIds $ \iid ->
        (iid, ) <$> (PlayerCard <$> genPlayerCard Assets.esotericFormula)
      a <$ pushAll
        ([ TakeControlOfSetAsideAsset iid esotericFormula
         | (iid, esotericFormula) <- investigatorEsotericFormulaPairs
         ]
        <> [ PlaceDoomOnAgenda | not survived ]
        <> [AdvanceActDeck actDeckId (toSource attrs)]
        )
    _ -> SaracenicScript <$> runMessage msg attrs
