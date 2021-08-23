module Arkham.Types.Location.Cards.AdministrationOffice_130
  ( administrationOffice_130
  , AdministrationOffice_130(..)
  ) where

import Arkham.Prelude

import qualified Arkham.Location.Cards as Cards (administrationOffice_130)
import Arkham.Types.Classes
import Arkham.Types.GameValue
import Arkham.Types.InvestigatorId
import Arkham.Types.Location.Attrs
import Arkham.Types.Location.Helpers
import Arkham.Types.Modifier
import Arkham.Types.Query
import Arkham.Types.Source

newtype AdministrationOffice_130 = AdministrationOffice_130 LocationAttrs
  deriving anyclass IsLocation
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

administrationOffice_130 :: LocationCard AdministrationOffice_130
administrationOffice_130 = location
  AdministrationOffice_130
  Cards.administrationOffice_130
  1
  (PerPlayer 1)
  Triangle
  [Square]

instance HasCount ResourceCount env InvestigatorId => HasModifiersFor env AdministrationOffice_130 where
  getModifiersFor (InvestigatorSource iid) target (AdministrationOffice_130 attrs)
    | isTarget attrs target
    = do
      resources <- unResourceCount <$> getCount iid
      pure $ toModifiers attrs [ CannotInvestigate | resources <= 4 ]
  getModifiersFor _ _ _ = pure []

instance HasAbilities env AdministrationOffice_130 where
  getAbilities iid window (AdministrationOffice_130 attrs) =
    getAbilities iid window attrs

instance LocationRunner env => RunMessage env AdministrationOffice_130 where
  runMessage msg (AdministrationOffice_130 attrs) =
    AdministrationOffice_130 <$> runMessage msg attrs
