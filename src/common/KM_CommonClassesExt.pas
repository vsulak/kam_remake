unit KM_CommonClassesExt;
{$I KaM_Remake.inc}
interface
uses
  SysUtils, TypInfo, Classes,
  Generics.Collections,
  KM_CommonClasses, KM_CommonTypes;

type
  ERuntimeTypeError = class(Exception);

  {$IFDEF WDC}
  TSet<T> = class
  const
    BIT_MASKS: array [0..7] of Byte = (1, 2, 4, 8, 16, 32, 64, 128);
  strict private
    class function TypeInfo: PTypeInfo; inline; static;
    class function GetCardinality(const PSet: PByteArray; const SizeOfSet(*in bytes*): Integer): Integer; inline; static;
    class function GetSetToString(const PSet: PByteArray; const SizeOfSet(*in bytes*): Integer): String; static;
  public
    class function IsSet: Boolean; static;
    class function Cardinality(const Value: T): Integer; static;
    class function SetToString(const Value: T): String; static;
  end;
  {$ENDIF}

  // List with unique elements
  TKMListUnique<T> = class(TList<T>)
  public
    function Add(const Value: T): Integer; reintroduce;
  end;

  TKMWeightedList<T> = class(TList<T>)
    fWeight: array of Single;
  public
    procedure Add(const aValue: T; aWeight: Single); reintroduce;
    function GetWeightedRandom(out aValue: T): Boolean;
  end;

  TKMLimitedList<T> = class(TList<T>)
  private
    fMaxLength: Integer;
  public
    constructor Create(aMaxLength: Integer);
    function Add(const Value: T): Integer; reintroduce;
  end;

  TKMLimitedUniqueList<T> = class(TKMLimitedList<T>)
  public
    function Add(const Value: T): Integer; reintroduce;
  end;

  {$IFDEF WDC}
  TKMEnumUtils = class
    class function TryGetAs<T>(aEnumStr: String; out aEnumValue: T): Boolean;
  end;
  {$ENDIF}

  TKMVarValue = class
  private
  type
    TKMVarValueType = (rcNone, rcAnsiString, rcUnicodeString, rcInteger, rcExtended, rcBoolean);
  var
    fType: TKMVarValueType;
    fStrA: AnsiString;
    fStrW: UnicodeString;
    fInt: Int64;
    fExtn: Extended;
    fBool: Boolean;
  public
    constructor Create(aVarRec: TVarRec); overload;

    procedure SetByVarRec(aValue: TVarRec);
    function ToVarRec: TVarRec;

    procedure Save(aStream: TKMemoryStream);
    procedure Load(aStream: TKMemoryStream);
  end;

  TKMVarValueList = class(TObjectList<TKMVarValue>)
  public
    function ToVarRecArray: TKMVarRecArray;
    procedure AddVarRecs(aParams: array of const);

    procedure Save(aSaveStream: TKMemoryStream);
    procedure Load(aLoadStream: TKMemoryStream);
  end;

{$IFDEF FPC}
// Simple helpers to replace TSet<T> generics that crash FPC 3.2.2
function KMSetCardinality(const aSet; aSizeBytes: Integer): Integer;
function KMSetToString(const aSet; aSizeBytes: Integer; aTypeInfo: PTypeInfo): String;
{$ENDIF}


implementation
uses
  KM_CommonUtils;


{ TKMListUnique<T> }
function TKMListUnique<T>.Add(const Value: T): Integer;
begin
  if Contains(Value) then Exit(0);

  Result := inherited Add(Value);
end;


{ TKMWeightedList }
procedure TKMWeightedList<T>.Add(const aValue: T; aWeight: Single);
begin
  inherited Add(aValue);

  if Count >= Length(fWeight) then
    SetLength(fWeight, Count + 32);

  fWeight[Count - 1] := aWeight;
end;


function TKMWeightedList<T>.GetWeightedRandom(out aValue: T): Boolean;
var
  I: Integer;
  WeightsSum, Rnd: Extended;
begin
  Result := False;

  if Count = 0 then
    Exit;

  WeightsSum := 0;
  for I := 0 to Count - 1 do
    WeightsSum := WeightsSum + fWeight[I];

  Rnd := KaMRandomS1(WeightsSum{$IFDEF DBG_RNG_SPY}, 'TKMWeightedList.GetWeightedRandom'{$ENDIF});

  for I := 0 to Count - 1 do
  begin
    if Rnd < fWeight[I] then
    begin
      aValue := Items[I];
      Exit(True);
    end;
    Rnd := Rnd - fWeight[I];
  end;
  Assert(False, 'Error getting weighted random');
end;


{ TKMLimitedList<T> }
constructor TKMLimitedList<T>.Create(aMaxLength: Integer);
begin
  inherited Create;

  fMaxLength := aMaxLength;
end;


function TKMLimitedList<T>.Add(const Value: T): Integer;
begin
  Result := inherited Add(Value);

  if Count > fMaxLength then
    Delete(0); // Delete the oldest item
end;


{ TKMLimitedUniqueList }
function TKMLimitedUniqueList<T>.Add(const Value: T): Integer;
begin
  if Contains(Value) then Exit(0);

  Result := inherited Add(Value);
end;


{$IFDEF WDC}
{ TSet<T>

  Usage: Writeln(TSet<SomeSet>.Cardinality(Value));

  taken from:
  https://stackoverflow.com/questions/34442102/how-can-i-get-the-number-of-elements-of-any-variable-of-type-set }
class function TSet<T>.TypeInfo: PTypeInfo;
begin
  Result := System.TypeInfo(T);
end;


class function TSet<T>.IsSet: Boolean;
begin
  Result := TypeInfo.Kind = tkSet;
end;


class function TSet<T>.GetCardinality(const PSet: PByteArray; const SizeOfSet(*in bytes*): Integer): Integer;
var
  I, J: Integer;
begin
  Result := 0;
  for I := 0 to SizeOfSet - 1 do
    for J := 0 to 7 do
      if (PSet^[I] and BIT_MASKS[J]) > 0 then
        Inc(Result);
end;


class function TSet<T>.GetSetToString(const PSet: PByteArray; const SizeOfSet(*in bytes*): Integer): String;
var
  I, J: Integer;
  BaseType: PTypeInfo;
begin
  Result := '';

  BaseType := GetTypeData(TypeInfo).CompType{$IFDEF WDC}^{$ENDIF}; //FPC has PTypeInfo here, while WDC has PPTypeInfo

  for I := 0 to SizeOfSet - 1 do
    for J := 0 to 7 do
      if (PSet^[I] and BIT_MASKS[J]) > 0 then
      begin
        if Result <> '' then
          Result := Result + ', ';
        {$IFDEF WDC}
        Result := Result + GetEnumName(BaseType, J + I*8);
        {$ENDIF}
        {$IFDEF FPC}
        if BaseType^.Kind = tkInteger then //For some reason FPC can't return EnumName, at least for tkInteger values
          Result := Result + IntToStr(J + I*8)
        else
          Result := Result + GetEnumName(BaseType, J + I*8);
        {$ENDIF}
      end;
  Result := '[' + Result + ']';
end;


class function TSet<T>.Cardinality(const Value: T): Integer;
begin
  if not IsSet then
    raise ERuntimeTypeError.Create('Invalid type in TSet<T>, T must be a set');
  Result := GetCardinality(PByteArray(@Value), SizeOf(Value));
end;


class function TSet<T>.SetToString(const Value: T): String;
begin
  if not IsSet then
    raise ERuntimeTypeError.Create('Invalid type in TSet<T>, T must be a set');

  Result := GetSetToString(PByteArray(@Value), SizeOf(Value));
end;


{ TKMEnumUtils }
// example from https://stackoverflow.com/questions/2472487/converting-an-string-to-a-enum-type-using-tvalue
// Get enum value from enum string
class function TKMEnumUtils.TryGetAs<T>(aEnumStr: String; out aEnumValue: T): Boolean;
var
  tipInfo: PTypeInfo;
  enumIntVal: Integer;
  PEnumVal: Pointer;
begin
   tipInfo := TypeInfo(T);
   enumIntVal := GetEnumValue(tipInfo, aEnumStr);

   if enumIntVal = -1 then
     Exit(False);

   PEnumVal := @enumIntVal;
   aEnumValue := T(PEnumVal^);
   Result := True;
end;
{$ENDIF}


{ TKMVarValueList }
function TKMVarValueList.ToVarRecArray: TKMVarRecArray;
var
  I: Integer;
begin
  SetLength(Result, Count);
  for I := 0 to Count - 1 do
    Result[I] := Items[I].ToVarRec;
end;


procedure TKMVarValueList.AddVarRecs(aParams: array of const);
var
  I: Integer;
begin
  for I := Low(aParams) to High(aParams) do
    Add(TKMVarValue.Create(aParams[I]));
end;


procedure TKMVarValueList.Load(aLoadStream: TKMemoryStream);
var
  I, cnt: Integer;
  varValue: TKMVarValue;
begin
  aLoadStream.CheckMarker('VarValueList');
  aLoadStream.Read(cnt);
  for I := 0 to cnt - 1 do
  begin
    varValue := TKMVarValue.Create;
    varValue.Load(aLoadStream);
    Add(varValue);
  end;
end;


procedure TKMVarValueList.Save(aSaveStream: TKMemoryStream);
var
  I: Integer;
begin
  aSaveStream.PlaceMarker('VarValueList');
  aSaveStream.Write(Count);
  for I := 0 to Count - 1 do
    Items[I].Save(aSaveStream);
end;


function KMSetCardinality(const aSet; aSizeBytes: Integer): Integer;
var
  I, J: Integer;
  P: PByte;
begin
  Result := 0;
  P := @aSet;
  for I := 0 to aSizeBytes - 1 do
    for J := 0 to 7 do
      if ((P + I)^ and (1 shl J)) > 0 then
        Inc(Result);
end;


function KMSetToString(const aSet; aSizeBytes: Integer; aTypeInfo: PTypeInfo): String;
var
  I, J: Integer;
  P: PByte;
  BaseType: PTypeInfo;
begin
  Result := '';
  P := @aSet;
  BaseType := GetTypeData(aTypeInfo)^.CompType;

  for I := 0 to aSizeBytes - 1 do
    for J := 0 to 7 do
      if ((P + I)^ and (1 shl J)) > 0 then
      begin
        if Result <> '' then
          Result := Result + ', ';
        if BaseType^.Kind = tkInteger then
          Result := Result + IntToStr(J + I * 8)
        else
          Result := Result + GetEnumName(BaseType, J + I * 8);
      end;
  Result := '[' + Result + ']';
end;


{ TKMVarValue }
constructor TKMVarValue.Create(aVarRec: TVarRec);
begin
  inherited Create;

  SetByVarRec(aVarRec);
end;


procedure TKMVarValue.SetByVarRec(aValue: TVarRec);
begin
  case aValue.VType of
    vtAnsiString:     begin
                        fType := rcAnsiString;
                        fStrA := AnsiString(aValue.VAnsiString);
                      end;
    {$IFDEF WDC}
    vtUnicodeString:  begin
                        fType := rcUnicodeString;
                        fStrW := UnicodeString(aValue.VUnicodeString);
                      end;
    {$ENDIF}
    vtWideString:     begin
                        fType := rcUnicodeString;
                        fStrW := UnicodeString(aValue.VWideString);
                      end;
    vtString:         begin
                        fType := rcAnsiString;
                        fStrA := aValue.VString^;
                      end;
    vtInteger:        begin
                        fType := rcInteger;
                        fInt := aValue.VInteger;
                      end;
    vtInt64:          begin
                        fType := rcInteger;
                        fInt := aValue.VInt64^;
                      end;
    vtExtended:       begin
                        fType := rcExtended;
                        fExtn := aValue.VExtended^;
                      end;
    vtBoolean:        begin
                        fType := rcBoolean;
                        fBool := aValue.VBoolean;
                      end;
  end;
end;


function TKMVarValue.ToVarRec: TVarRec;
begin
  case fType of
    rcAnsiString:     begin
                        Result.VType := vtAnsiString;
                        Result.VAnsiString := Pointer(fStrA);
                      end;
    rcUnicodeString:  begin
                        {$IFDEF WDC}
                        Result.VType := vtUnicodeString;
                        Result.VUnicodeString := Pointer(fStrW);
                        {$ENDIF}
                        {$IFDEF FPC}
                        Result.VType := vtWideString;
                        Result.VWideString := Pointer(fStrW);
                        {$ENDIF}
                      end;
    rcInteger:        begin
                        Result.VType := vtInteger;
                        Result.VInteger := fInt;
                      end;
    rcExtended:       begin
                        Result.VType := vtExtended;
                        Result.VExtended := @fExtn;
                      end;
    rcBoolean:        begin
                        Result.VType := vtBoolean;
                        Result.VBoolean := fBool;
                      end;
  end;
end;


procedure TKMVarValue.Save(aStream: TKMemoryStream);
begin
  aStream.Write(fType, SizeOf(fType));
  case fType of
    rcAnsiString:     aStream.WriteA(fStrA);
    rcUnicodeString:  aStream.WriteW(fStrW);
    rcInteger:        aStream.Write(fInt);
    rcExtended:       aStream.Write(fExtn);
    rcBoolean:        aStream.Write(fBool);
  end;
end;


procedure TKMVarValue.Load(aStream: TKMemoryStream);
begin
  aStream.Read(fType, SizeOf(fType));
  case fType of
    rcAnsiString:     aStream.ReadA(fStrA);
    rcUnicodeString:  aStream.ReadW(fStrW);
    rcInteger:        aStream.Read(fInt);
    rcExtended:       aStream.Read(fExtn);
    rcBoolean:        aStream.Read(fBool);
  end;
end;


end.
