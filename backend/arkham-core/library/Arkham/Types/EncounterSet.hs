module Arkham.Types.EncounterSet where

import Arkham.Prelude

data EncounterSet
  = TheGathering
  | TheMidnightMasks
  | TheDevourerBelow
  | CultOfUmordhoth
  | Rats
  | Ghouls
  | StrikingFear
  | AncientEvils
  | ChillingCold
  | Nightgaunts
  | DarkCult
  | LockedDoors
  | AgentsOfHastur
  | AgentsOfYogSothoth
  | AgentsOfShubNiggurath
  | AgentsOfCthulhu
  | ExtracurricularActivity
  | TheHouseAlwaysWins
  | ArmitagesFate
  | TheMiskatonicMuseum
  | TheEssexCountyExpress
  | BloodOnTheAltar
  | UndimensionedAndUnseen
  | WhereDoomAwaits
  | LostInTimeAndSpace
  | Sorcery
  | BishopsThralls
  | Dunwich
  | Whippoorwills
  | BadLuck
  | BeastThralls
  | NaomisCrew
  | TheBeyond
  | HideousAbominations
  | CurtainCall
  | ReturnToTheGathering
  | ReturnToTheMidnightMasks
  | ReturnToTheDevourerBelow
  | GhoulsOfUmordhoth
  | TheDevourersCult
  | ReturnCultOfUmordhoth
  | TheBayou
  | CurseOfTheRougarou
  | CarnevaleOfHorrors
  | Test
  deriving stock (Show, Eq, Generic, Bounded, Enum)
  deriving anyclass (ToJSON, FromJSON, Hashable)
