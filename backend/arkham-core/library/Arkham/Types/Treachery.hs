{-# LANGUAGE UndecidableInstances #-}
module Arkham.Types.Treachery
  ( lookupTreachery
  , Treachery(..)
  , isWeakness
  , treacheryLocation
  )
where

import Arkham.Json
import Arkham.Types.Card
import Arkham.Types.Classes
import Arkham.Types.InvestigatorId
import Arkham.Types.LocationId
import Arkham.Types.Query
import Arkham.Types.Treachery.Attrs
import Arkham.Types.Treachery.Cards
import Arkham.Types.Treachery.Runner
import Arkham.Types.TreacheryId
import ClassyPrelude
import Data.Coerce
import Generics.SOP hiding (Generic)
import qualified Generics.SOP as SOP
import Safe (fromJustNote)

data Treachery
  = CoverUp' CoverUp
  | HospitalDebts' HospitalDebts
  | AbandonedAndAlone' AbandonedAndAlone
  | Amnesia' Amnesia
  | Paranoia' Paranoia
  | Haunted' Haunted
  | Psychosis' Psychosis
  | Hypochondria' Hypochondria
  | HuntingShadow' HuntingShadow
  | FalseLead' FalseLead
  | UmordhothsWrath' UmordhothsWrath
  | GraspingHands' GraspingHands
  | AncientEvils' AncientEvils
  | RottingRemains' RottingRemains
  | FrozenInFear' FrozenInFear
  | DissonantVoices' DissonantVoices
  | CryptChill' CryptChill
  | ObscuringFog' ObscuringFog
  | MysteriousChanting' MysteriousChanting
  | OnWingsOfDarkness' OnWingsOfDarkness
  | LockedDoor' LockedDoor
  | TheYellowSign' TheYellowSign
  | OfferOfPower' OfferOfPower
  | DreamsOfRlyeh' DreamsOfRlyeh
  deriving stock (Show, Generic)
  deriving anyclass (ToJSON, FromJSON, SOP.Generic)

deriving anyclass instance (ActionRunner env investigator) => HasActions env investigator Treachery
deriving anyclass instance (TreacheryRunner env) => RunMessage env Treachery

instance HasCardCode Treachery where
  getCardCode = treacheryCardCode . treacheryAttrs

instance HasTraits Treachery where
  getTraits = treacheryTraits . treacheryAttrs

instance HasCount DoomCount () Treachery where
  getCount _ = DoomCount . treacheryDoom . treacheryAttrs

instance HasId (Maybe OwnerId) () Treachery where
  getId _ = (OwnerId <$>) . treacheryOwner . treacheryAttrs

lookupTreachery
  :: CardCode -> (TreacheryId -> Maybe InvestigatorId -> Treachery)
lookupTreachery = fromJustNote "Unkown treachery" . flip lookup allTreacheries

allTreacheries
  :: HashMap CardCode (TreacheryId -> Maybe InvestigatorId -> Treachery)
allTreacheries = mapFromList
  [ ("01007", (CoverUp' .) . coverUp)
  , ("01011", (HospitalDebts' .) . hospitalDebts)
  , ("01015", (AbandonedAndAlone' .) . abandonedAndAlone)
  , ("01096", (Amnesia' .) . amnesia)
  , ("01097", (Paranoia' .) . paranoia)
  , ("01098", (Haunted' .) . haunted)
  , ("01099", (Psychosis' .) . psychosis)
  , ("01100", (Hypochondria' .) . hypochondria)
  , ("01135", (HuntingShadow' .) . huntingShadow)
  , ("01136", (FalseLead' .) . falseLead)
  , ("01158", (UmordhothsWrath' .) . umordhothsWrath)
  , ("01162", (GraspingHands' .) . graspingHands)
  , ("01166", (AncientEvils' .) . ancientEvils)
  , ("01163", (RottingRemains' .) . rottingRemains)
  , ("01164", (FrozenInFear' .) . frozenInFear)
  , ("01165", (DissonantVoices' .) . dissonantVoices)
  , ("01167", (CryptChill' .) . cryptChill)
  , ("01168", (ObscuringFog' .) . obscuringFog)
  , ("01171", (MysteriousChanting' .) . mysteriousChanting)
  , ("01173", (OnWingsOfDarkness' .) . onWingsOfDarkness)
  , ("01174", (LockedDoor' .) . lockedDoor)
  , ("01176", (TheYellowSign' .) . theYellowSign)
  , ("01178", (OfferOfPower' .) . offerOfPower)
  , ("01182", (DreamsOfRlyeh' .) . dreamsOfRlyeh)
  ]

isWeakness :: Treachery -> Bool
isWeakness = treacheryWeakness . treacheryAttrs

treacheryLocation :: Treachery -> Maybe LocationId
treacheryLocation = treacheryAttachedLocation . treacheryAttrs

treacheryAttrs :: Treachery -> Attrs
treacheryAttrs = getAttrs

getAttrs :: (All2 IsAttrs (Code a), SOP.Generic a) => a -> Attrs
getAttrs a = go (unSOP $ from a)
 where
  go :: (All2 IsAttrs xs) => NS (NP I) xs -> Attrs
  go (S next) = go next
  go (Z (I x :* _)) = coerce x
  go (Z Nil) = error "should not happen"

class (Coercible a Attrs) => IsAttrs a
instance (Coercible a Attrs) => IsAttrs a
