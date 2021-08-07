module Arkham.Types.Asset.Cards.Scrapper3
  ( scrapper3
  , Scrapper3(..)
  ) where

import Arkham.Prelude

import qualified Arkham.Asset.Cards as Cards
import Arkham.Types.Ability
import Arkham.Types.Asset.Attrs
import Arkham.Types.Asset.Helpers
import Arkham.Types.Asset.Runner
import Arkham.Types.Classes
import Arkham.Types.Cost
import Arkham.Types.Effect.Window
import Arkham.Types.EffectMetadata
import Arkham.Types.Message
import Arkham.Types.Modifier
import Arkham.Types.SkillType
import Arkham.Types.Target
import Arkham.Types.Window

newtype Scrapper3 = Scrapper3 AssetAttrs
  deriving anyclass IsAsset
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

scrapper3 :: AssetCard Scrapper3
scrapper3 = asset Scrapper3 Cards.scrapper3

instance HasActions env Scrapper3 where
  getActions iid (WhenSkillTest _) (Scrapper3 a) | ownedBy a iid = do
    pure [ mkAbility a idx $ FastAbility $ ResourceCost 1 | idx <- [1 .. 2] ]
  getActions _ _ _ = pure []

instance HasModifiersFor env Scrapper3

instance AssetRunner env => RunMessage env Scrapper3 where
  runMessage msg a@(Scrapper3 attrs) = case msg of
    UseCardAbility iid source _ 1 _ | isSource attrs source -> a <$ push
      (CreateWindowModifierEffect
        EffectPhaseWindow
        (EffectModifiers $ toModifiers attrs [SkillModifier SkillCombat 1])
        source
        (InvestigatorTarget iid)
      )
    UseCardAbility iid source _ 2 _ | isSource attrs source -> a <$ push
      (CreateWindowModifierEffect
        EffectPhaseWindow
        (EffectModifiers $ toModifiers attrs [SkillModifier SkillAgility 1])
        source
        (InvestigatorTarget iid)
      )
    _ -> Scrapper3 <$> runMessage msg attrs
