unit KM_HandEntityHelper;
{$I KaM_Remake.inc}
interface
uses
  KM_HandEntity, KM_Units, KM_UnitWarrior, KM_UnitGroup, KM_Houses;

type
  TKMHandEntityHelper = class helper for TKMHandEntity
    function AsUnit: TKMUnit;
    function AsUnitWarrior: TKMUnitWarrior;
    function AsGroup: TKMUnitGroup;
    function AsHouse: TKMHouse;
  end;


implementation


{ TKMHandEntityHelper }
function TKMHandEntityHelper.AsGroup: TKMUnitGroup;
begin
  if Self is TKMUnitGroup then
    Result := TKMUnitGroup(Self)
  else
    Result := nil;
end;


function TKMHandEntityHelper.AsHouse: TKMHouse;
begin
  if Self is TKMHouse then
    Result := TKMHouse(Self)
  else
    Result := nil;
end;


function TKMHandEntityHelper.AsUnit: TKMUnit;
begin
  if Self is TKMUnit then
    Result := TKMUnit(Self)
  else
    Result := nil;
end;


function TKMHandEntityHelper.AsUnitWarrior: TKMUnitWarrior;
begin
  if Self is TKMUnitWarrior then
    Result := TKMUnitWarrior(Self)
  else
    Result := nil;
end;


end.
