module Arkham.Event.Cards.UnsolvedCase
  ( unsolvedCase
  , UnsolvedCase(..)
  ) where

import Arkham.Prelude

import Arkham.Ability
import Arkham.Card
import Arkham.Classes
import Arkham.Criteria
import Arkham.Deck
import Arkham.Effect.Window
import Arkham.EffectMetadata
import Arkham.Event.Cards qualified as Cards
import Arkham.Event.Runner
import Arkham.Helpers.Modifiers
import Arkham.Investigator.Deck
import Arkham.Investigator.Types ( Field (..) )
import Arkham.Matcher
import Arkham.Message hiding ( InvestigatorEliminated )
import Arkham.Placement
import Arkham.Projection
import Arkham.Target
import Arkham.Timing qualified as Timing

newtype UnsolvedCase = UnsolvedCase EventAttrs
  deriving anyclass (IsEvent, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

unsolvedCase :: EventCard UnsolvedCase
unsolvedCase = event UnsolvedCase Cards.unsolvedCase

instance HasAbilities UnsolvedCase where
  getAbilities (UnsolvedCase a) =
    [ restrictedAbility a 1 InYourHand $ ForcedAbility $ WouldBeShuffledIntoDeck
      (DeckIs (InvestigatorDeckByKey (eventOwner a) HunchDeck))
      (CardWithId $ toCardId a)
    , restrictedAbility a 2 (InThreatAreaOf You)
      $ ForcedAbility
      $ OrWindowMatcher
          [ GameEnds Timing.When
          , InvestigatorEliminated Timing.When (InvestigatorWithId $ eventOwner a)
          ]
    ]

instance RunMessage UnsolvedCase where
  runMessage msg e@(UnsolvedCase attrs) = case msg of
    InHand iid' (UseCardAbility iid (isSource attrs -> True) 1 _ _)
      | iid == iid' -> do
        popMessageMatching_ $ \case
          ShuffleCardsIntoDeck (InvestigatorDeckByKey _ HunchDeck) [card] ->
            card == toCard attrs
          _ -> False
        push $ CreateEventAt iid (toCard attrs) (InThreatArea iid)
        pure e
    InvestigatorPlayEvent iid eid _ _ _ | eid == toId attrs -> do
      hasClues <- fieldMap InvestigatorClues (> 0) iid
      highestShroud <- selectList $ HighestShroud Anywhere
      pushAll
        $ [ chooseOrRunOne
              iid
              [ targetLabel
                  location
                  [ RemoveClues (InvestigatorTarget iid) 1
                  , PlaceClues (LocationTarget location) 1
                  ]
              | location <- highestShroud
              ]
          | notNull highestShroud && hasClues
          ]
        <> [RemoveFromGame (toTarget attrs)]
      pure e
    UseCardAbility iid source 2 _ _ | isSource attrs source -> do
      push $ CreateWindowModifierEffect
        EffectGameWindow
        (EffectModifiers $ toModifiers attrs [XPModifier (-2)])
        source
        (InvestigatorTarget iid)
      pure e
    _ -> UnsolvedCase <$> runMessage msg attrs
