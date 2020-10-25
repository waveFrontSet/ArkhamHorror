{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.Investigator.Cards.JennyBarnes where

import Arkham.Import

import Arkham.Types.Investigator.Attrs
import Arkham.Types.Investigator.Runner
import Arkham.Types.Stats
import Arkham.Types.Trait

newtype JennyBarnes = JennyBarnes Attrs
  deriving newtype (Show, ToJSON, FromJSON)

instance HasModifiersFor env JennyBarnes where
  getModifiersFor source target (JennyBarnes attrs) =
    getModifiersFor source target attrs

jennyBarnes :: JennyBarnes
jennyBarnes = JennyBarnes $ baseAttrs
  "02003"
  "Jenny Barnes"
  Rogue
  Stats
    { health = 8
    , sanity = 7
    , willpower = 3
    , intellect = 3
    , combat = 3
    , agility = 3
    }
  [Drifter]

instance ActionRunner env => HasActions env JennyBarnes where
  getActions i window (JennyBarnes attrs) = getActions i window attrs

instance InvestigatorRunner env => HasTokenValue env JennyBarnes where
  getTokenValue (JennyBarnes attrs) iid token | iid == investigatorId attrs =
    case drawnTokenFace token of
      ElderSign ->
        pure $ TokenValue token (PositiveModifier $ investigatorResources attrs)
      _other -> getTokenValue attrs iid token
  getTokenValue (JennyBarnes attrs) iid token = getTokenValue attrs iid token

instance (InvestigatorRunner env) => RunMessage env JennyBarnes where
  runMessage msg (JennyBarnes attrs) = case msg of
    AllDrawCardAndResource | not (attrs ^. defeated || attrs ^. resigned) ->
      JennyBarnes <$> runMessage msg (attrs & resources +~ 1)
    _ -> JennyBarnes <$> runMessage msg attrs
