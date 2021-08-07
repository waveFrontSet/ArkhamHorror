module Arkham.Types.Enemy.Cards.HermanCollins
  ( HermanCollins(..)
  , hermanCollins
  ) where

import Arkham.Prelude

import qualified Arkham.Enemy.Cards as Cards
import Arkham.Types.Ability
import Arkham.Types.Action hiding (Ability)
import Arkham.Types.Classes
import Arkham.Types.Cost
import Arkham.Types.Enemy.Attrs
import Arkham.Types.Enemy.Helpers
import Arkham.Types.Enemy.Runner
import Arkham.Types.Id
import Arkham.Types.Matcher
import Arkham.Types.Message
import Arkham.Types.Window

newtype HermanCollins = HermanCollins EnemyAttrs
  deriving anyclass IsEnemy
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

hermanCollins :: EnemyCard HermanCollins
hermanCollins = enemyWith
  HermanCollins
  Cards.hermanCollins
  (3, Static 4, 4)
  (1, 1)
  (spawnAtL ?~ LocationWithTitle "Graveyard")

instance HasModifiersFor env HermanCollins

instance ActionRunner env => HasActions env HermanCollins where
  getActions iid NonFast (HermanCollins attrs@EnemyAttrs {..}) =
    withBaseActions iid NonFast attrs $ do
      locationId <- getId @LocationId iid
      pure
        [ mkAbility attrs 1 $ ActionAbility
            (Just Parley)
            (Costs [ActionCost 1, HandDiscardCost 4 Nothing mempty mempty])
        | locationId == enemyLocation
        ]
  getActions _ _ _ = pure []

instance EnemyRunner env => RunMessage env HermanCollins where
  runMessage msg e@(HermanCollins attrs) = case msg of
    UseCardAbility _ source _ 1 _ | isSource attrs source ->
      e <$ push (AddToVictory $ toTarget attrs)
    _ -> HermanCollins <$> runMessage msg attrs
