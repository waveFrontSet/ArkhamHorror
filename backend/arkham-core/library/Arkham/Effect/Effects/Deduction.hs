module Arkham.Effect.Effects.Deduction
  ( deduction
  , Deduction(..)
  ) where

import Arkham.Prelude

import Arkham.Action qualified as Action
import Arkham.Classes
import Arkham.Effect.Runner
import Arkham.EffectMetadata
import Arkham.Message
import Arkham.Target

newtype Deduction = Deduction EffectAttrs
  deriving anyclass (HasAbilities, IsEffect, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

deduction :: EffectArgs -> Deduction
deduction = Deduction . uncurry4 (baseAttrs "01039")

instance RunMessage Deduction where
  runMessage msg e@(Deduction attrs@EffectAttrs {..}) = case msg of
    Successful (Action.Investigate, _) iid _ (LocationTarget lid) _ ->
      case effectMetadata of
        Just (EffectMetaTarget (LocationTarget lid')) | lid == lid' ->
          e <$ push
            (InvestigatorDiscoverClues iid lid 1 (Just Action.Investigate))
        _ -> pure e
    SkillTestEnds _ -> e <$ push (DisableEffect effectId)
    _ -> Deduction <$> runMessage msg attrs
