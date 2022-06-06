module Arkham.Location.Cards.Courtyard
  ( courtyard
  , Courtyard(..)
  ) where

import Arkham.Prelude

import Arkham.Ability
import Arkham.Location.Cards qualified as Cards
import Arkham.Card.CardType
import Arkham.Classes
import Arkham.Criteria
import Arkham.GameValue
import Arkham.Location.Runner
import Arkham.Location.Helpers
import Arkham.Matcher
import Arkham.Message
import Arkham.Timing qualified as Timing

newtype Courtyard = Courtyard LocationAttrs
  deriving anyclass (IsLocation, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

courtyard :: LocationCard Courtyard
courtyard = location
  Courtyard
  Cards.courtyard
  5
  (Static 0)
  Circle
  [Squiggle, Square, T, Equals, Plus]

instance HasAbilities Courtyard where
  getAbilities (Courtyard attrs) = withBaseAbilities
    attrs
    [ restrictedAbility attrs 1 Here $ ForcedAbility $ Enters
        Timing.After
        You
        ThisLocation
    | locationRevealed attrs
    ]

instance RunMessage Courtyard where
  runMessage msg l@(Courtyard attrs) = case msg of
    UseCardAbility iid source _ 1 _ | isSource attrs source ->
      l <$ push (DiscardTopOfEncounterDeck iid 1 (Just $ toTarget attrs))
    DiscardedTopOfEncounterDeck iid [card] target | isTarget attrs target -> do
      l <$ when
        (toCardType card == EnemyType)
        (pushAll
          [ RemoveFromEncounterDiscard card
          , InvestigatorDrewEncounterCard iid card
          ]
        )
    _ -> Courtyard <$> runMessage msg attrs
