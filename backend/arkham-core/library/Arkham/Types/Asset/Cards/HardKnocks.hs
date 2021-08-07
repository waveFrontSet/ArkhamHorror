module Arkham.Types.Asset.Cards.HardKnocks
  ( HardKnocks(..)
  , hardKnocks
  ) where

import Arkham.Prelude

import qualified Arkham.Asset.Cards as Cards
import Arkham.Types.Ability
import Arkham.Types.Asset.Attrs
import Arkham.Types.Asset.Helpers
import Arkham.Types.Asset.Runner
import Arkham.Types.Classes
import Arkham.Types.Cost
import Arkham.Types.Message
import Arkham.Types.Modifier
import Arkham.Types.SkillType
import Arkham.Types.Target
import Arkham.Types.Window

newtype HardKnocks = HardKnocks AssetAttrs
  deriving anyclass IsAsset
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

hardKnocks :: AssetCard HardKnocks
hardKnocks = asset HardKnocks Cards.hardKnocks

instance HasModifiersFor env HardKnocks

ability :: Int -> AssetAttrs -> Ability
ability idx a = mkAbility (toSource a) idx (FastAbility $ ResourceCost 1)

instance HasActions env HardKnocks where
  getActions iid (WhenSkillTest SkillCombat) (HardKnocks a) =
    pure [ ability 1 a | ownedBy a iid ]
  getActions iid (WhenSkillTest SkillAgility) (HardKnocks a) =
    pure [ ability 2 a | ownedBy a iid ]
  getActions _ _ _ = pure []

instance (AssetRunner env) => RunMessage env HardKnocks where
  runMessage msg a@(HardKnocks attrs) = case msg of
    UseCardAbility iid source _ 1 _ | isSource attrs source -> a <$ push
      (skillTestModifier
        attrs
        (InvestigatorTarget iid)
        (SkillModifier SkillCombat 1)
      )
    UseCardAbility iid source _ 2 _ | isSource attrs source -> a <$ push
      (skillTestModifier
        attrs
        (InvestigatorTarget iid)
        (SkillModifier SkillAgility 1)
      )
    _ -> HardKnocks <$> runMessage msg attrs
