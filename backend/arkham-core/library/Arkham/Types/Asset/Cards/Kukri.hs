{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.Asset.Cards.Kukri
  ( kukri
  , Kukri(..)
  )
where

import Arkham.Import

import qualified Arkham.Types.Action as Action
import Arkham.Types.Asset.Attrs
import Arkham.Types.Asset.Helpers

newtype Kukri = Kukri Attrs
  deriving newtype (Show, ToJSON, FromJSON)

kukri :: AssetId -> Kukri
kukri uuid = Kukri $ (baseAttrs uuid "02036") { assetSlots = [HandSlot] }

instance ActionRunner env => HasActions env Kukri where
  getActions iid NonFast (Kukri a) | ownedBy a iid = do
    fightAvailable <- hasFightActions iid NonFast
    pure
      [ ActivateCardAbilityAction
          iid
          (mkAbility (toSource a) 1 (ActionAbility 1 (Just Action.Fight)))
      | fightAvailable
      ]
  getActions _ _ _ = pure []

instance HasModifiersFor env Kukri where
  getModifiersFor = noModifiersFor

instance
  ( HasQueue env
  , HasModifiersFor env ()
  , HasCount ActionRemainingCount env InvestigatorId
  )
  => RunMessage env Kukri where
  runMessage msg a@(Kukri attrs) = case msg of
    UseCardAbility iid source _ 1 | isSource attrs source ->
      a <$ unshiftMessages
        [ CreateSkillTestEffect
          (EffectModifiers $ toModifiers attrs [SkillModifier SkillCombat 1])
          source
          (InvestigatorTarget iid)
        , ChooseFightEnemy iid source SkillCombat False
        ]
    PassedSkillTest iid _ source _ _ | isSource attrs source -> do
      actionRemainingCount <- unActionRemainingCount <$> getCount iid
      if actionRemainingCount > 0
        then a <$ unshiftMessage
          (chooseOne
            iid
            [ Label
              "Spend 1 action to deal +1 damage"
              [ LoseActions iid source 1
              , CreateSkillTestEffect
                (EffectModifiers $ toModifiers attrs [DamageDealt 1])
                source
                (InvestigatorTarget iid)
              ]
            , Label "Skip additional Kukri damage" []
            ]
          )
        else pure a
    _ -> Kukri <$> runMessage msg attrs
