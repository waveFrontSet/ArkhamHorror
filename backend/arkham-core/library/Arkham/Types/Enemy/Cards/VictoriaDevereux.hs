{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.Enemy.Cards.VictoriaDevereux where

import Arkham.Import

import Arkham.Types.Action hiding (Ability)
import Arkham.Types.Enemy.Attrs
import Arkham.Types.Enemy.Helpers
import Arkham.Types.Enemy.Runner

newtype VictoriaDevereux = VictoriaDevereux Attrs
  deriving newtype (Show, ToJSON, FromJSON)

victoriaDevereux :: EnemyId -> VictoriaDevereux
victoriaDevereux uuid =
  VictoriaDevereux
    $ baseAttrs uuid "01140"
    $ (healthDamageL .~ 1)
    . (fightL .~ 3)
    . (healthL .~ Static 3)
    . (evadeL .~ 2)
    . (uniqueL .~ True)

instance HasModifiersFor env VictoriaDevereux where
  getModifiersFor = noModifiersFor

instance ActionRunner env => HasActions env VictoriaDevereux where
  getActions iid NonFast (VictoriaDevereux attrs@Attrs {..}) = do
    baseActions <- getActions iid NonFast attrs
    resourceCount <- getResourceCount iid
    locationId <- getId @LocationId iid
    canAffordActions <- getCanAffordCost
      iid
      (toSource attrs)
      (ActionCost 1 (Just Parley) enemyTraits)
    pure
      $ baseActions
      <> [ ActivateCardAbilityAction
             iid
             (mkAbility (EnemySource enemyId) 1 (ActionAbility 1 (Just Parley)))
         | canAffordActions && resourceCount >= 5 && locationId == enemyLocation
         ]
  getActions _ _ _ = pure []

instance (EnemyRunner env) => RunMessage env VictoriaDevereux where
  runMessage msg e@(VictoriaDevereux attrs@Attrs {..}) = case msg of
    InvestigatorDrawEnemy iid _ eid | eid == enemyId ->
      e <$ spawnAt (Just iid) eid "Northside"
    UseCardAbility iid (EnemySource eid) _ 1 | eid == enemyId ->
      e <$ unshiftMessages
        [SpendResources iid 5, AddToVictory (EnemyTarget enemyId)]
    _ -> VictoriaDevereux <$> runMessage msg attrs
