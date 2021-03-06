unit WiRL.Persistence.DynamicTypes;

interface

uses
  System.Classes, System.SysUtils, Data.DB, System.Rtti, System.TypInfo,
  System.Generics.Collections;

type
  IDynamicType = interface
  ['{DD163E75-134C-4035-809C-D9E1EEEC4225}']
  end;

  IDynamicStream = interface(IDynamicType)
  ['{968D03E7-273F-4E94-A3EA-ECB7A73F0715}']
    procedure LoadFromStream(AStream: TStream);
    procedure SaveToStream(AStream: TStream);
  end;

  IDynamicList = interface(IDynamicType)
  ['{9F4A2D72-078B-4EA2-B86E-068206AD0F16}']
    function NewItem: TValue;
    function GetItemType: TRttiType;
    procedure Add(AItem: TValue);
    procedure Clear;
    function Count: Integer;
    // Enumerator functions
    function Current: TValue;
    function MoveNext: Boolean;
  end;

  IDynamicMap = interface(IDynamicType)
  ['{89E60A06-C1A9-4D70-83B8-85D9B29510DB}']
    function NewKey: TValue;
    function NewValue: TValue;
    function GetKeyType: TRttiType;
    function GetValueType: TRttiType;
    procedure Add(const AKey, AValue: TValue);
    procedure Clear;
    function Count: Integer;
    // Enumerator functions
    function CurrentKey: TValue;
    function CurrentValue: TValue;
    function MoveNext: Boolean;
  end;

  TDynamicStream = class(TInterfacedObject, IDynamicStream)
  private
    FInstance: TObject;
    FLoadMethod: TRttiMethod;
    FSaveMethod: TRttiMethod;
    constructor Create(AInstance: TObject; ALoadMethod, ASaveMethod: TRttiMethod);
  public
    class function GuessType(AInstance: TObject): IDynamicStream;
  public
    procedure LoadFromStream(AStream: TStream);
    procedure SaveToStream(AStream: TStream);
  end;

  TDynamicList = class(TInterfacedObject, IDynamicList)
  private
    FInstance: TObject;
    FItemType: TRttiType;
    FAddMethod: TRttiMethod;
    FClearMethod: TRttiMethod;
    FMoveNextMethod: TRttiMethod;
    FCurrentProperty: TRttiProperty;
    FCountProperty: TRttiProperty;
    constructor Create(AInstance: TObject; AItemType: TRttiType;
      AAddMethod, AClearMethod, AMoveNextMethod: TRttiMethod;
      ACurrentProperty, ACountProperty: TRttiProperty);
  public
    class function GuessType(AInstance: TObject): IDynamicList;
  public
    function NewItem: TValue;
    function GetItemType: TRttiType;
    procedure Add(AItem: TValue);
    procedure Clear;
    function Count: Integer;
    // Enumerator functions
    function Current: TValue;
    function MoveNext: Boolean;
  end;

  TDynamicMap = class(TInterfacedObject, IDynamicMap)
  public type
    TEnumerator = class
    private
      const CURRENT_PROP = 'Current';
      const MOVENEXT_METH = 'MoveNext';
    private
      FInstance: TObject;
      FMoveNextMethod: TRttiMethod;
      FCurrentProperty: TRttiProperty;
    public
      constructor Create(AMethod: TRttiMethod; AInstance: TObject);
      destructor Destroy; override;
    public
      function Current: TValue;
      function MoveNext: Boolean;
    end;
  private
    FInstance: TObject;
    FKeyType: TRttiType;
    FValueType: TRttiType;
    FAddMethod: TRttiMethod;
    FClearMethod: TRttiMethod;
    FKeyEnum: TDynamicMap.TEnumerator;
    FValueEnum: TDynamicMap.TEnumerator;
    FCountProp: TRttiProperty;

    constructor Create(AInstance: TObject; AKeyType, AValueType: TRttiType;
      AAddMethod, AClearMethod: TRttiMethod; ACountProp: TRttiProperty;
      AKeyEnum, AValueEnum: TDynamicMap.TEnumerator);
  public
    class function GuessType(AInstance: TObject): IDynamicMap;
    destructor Destroy; override;
  public
    function NewKey: TValue;
    function NewValue: TValue;
    function GetKeyType: TRttiType;
    function GetValueType: TRttiType;
    procedure Add(const AKey, AValue: TValue);
    procedure Clear;
    function Count: Integer;
    // Enumerator functions
    function CurrentKey: TValue;
    function CurrentValue: TValue;
    function MoveNext: Boolean;
  end;

implementation

uses
  WiRL.Persistence.Types,
  WiRL.Rtti.Utils;

{ TDynamicStream }

constructor TDynamicStream.Create(AInstance: TObject; ALoadMethod, ASaveMethod: TRttiMethod);
begin
  FInstance := AInstance;
  FLoadMethod := ALoadMethod;
  FSaveMethod := ASaveMethod;
end;

class function TDynamicStream.GuessType(AInstance: TObject): IDynamicStream;
var
  LType: TRttiType;
  LLoadMethod, LSaveMethod: TRttiMethod;
begin
  if not Assigned(AInstance) then
    Exit(nil);

  LType := TRttiHelper.Context.GetType(AInstance.ClassType);

  if not Assigned(LType) then
    Exit(nil);

  LLoadMethod := LType.GetMethod('LoadFromStream');
  if not Assigned(LLoadMethod) then
    Exit(nil);

  LSaveMethod := LType.GetMethod('SaveToStream');
  if not Assigned(LSaveMethod) then
    Exit(nil);

  Result := Self.Create(AInstance, LLoadMethod, LSaveMethod);
end;

procedure TDynamicStream.LoadFromStream(AStream: TStream);
begin
  FLoadMethod.Invoke(FInstance, [AStream]);
end;

procedure TDynamicStream.SaveToStream(AStream: TStream);
begin
  FSaveMethod.Invoke(FInstance, [AStream]);
end;

{ TDynamicList }

procedure TDynamicList.Add(AItem: TValue);
begin
  FAddMethod.Invoke(FInstance, [AItem]);
end;

procedure TDynamicList.Clear;
begin
  FClearMethod.Invoke(FInstance, []);
end;

function TDynamicList.Count: Integer;
begin
  Result := FCountProperty.GetValue(FInstance).AsInteger;
end;

constructor TDynamicList.Create(AInstance: TObject; AItemType: TRttiType;
  AAddMethod, AClearMethod, AMoveNextMethod: TRttiMethod;
  ACurrentProperty, ACountProperty: TRttiProperty);
begin
  FInstance := AInstance;
  FItemType := AItemType;
  FAddMethod := AAddMethod;
  FClearMethod := AClearMethod;
  FMoveNextMethod := AMoveNextMethod;
  FCurrentProperty := ACurrentProperty;
  FCountProperty := ACountProperty;
end;

function TDynamicList.Current: TValue;
begin
  Result := FCurrentProperty.GetValue(FInstance);
end;

function TDynamicList.GetItemType: TRttiType;
begin
  Result := FItemType;
end;

class function TDynamicList.GuessType(AInstance: TObject): IDynamicList;
var
  LMethodGetEnumerator, LMethodAdd: TRttiMethod;
  LMethodClear, LMethodMoveNext: TRttiMethod;
  LEnumObject: TObject;
  LListType, LItemType, LEnumType: TRttiType;
  LCountProp, LCurrentProp: TRttiProperty;
begin
  Result := nil;
  LListType := TRttiHelper.Context.GetType(AInstance.ClassType);

  LMethodGetEnumerator := LListType.GetMethod('GetEnumerator');
  if not Assigned(LMethodGetEnumerator) or
     (LMethodGetEnumerator.MethodKind <> mkFunction) or
     (LMethodGetEnumerator.ReturnType.Handle.Kind <> tkClass)
  then
    Exit;

  LMethodClear := LListType.GetMethod('Clear');
  if not Assigned(LMethodClear) then
    Exit;

  LMethodAdd := LListType.GetMethod('Add');
  if not Assigned(LMethodAdd) or (Length(LMethodAdd.GetParameters) <> 1) then
    Exit;

  LItemType := LMethodAdd.GetParameters[0].ParamType;

  LCountProp := LListType.GetProperty('Count');
  if not Assigned(LCountProp) then
    Exit;

  LEnumObject := LMethodGetEnumerator.Invoke(AInstance, []).AsObject;
  if not Assigned(LEnumObject) then
    Exit;

  try
    LEnumType := TRttiHelper.Context.GetType(LEnumObject.ClassType);

    LCurrentProp := LEnumType.GetProperty('Current');
    if not Assigned(LCurrentProp) then
      Exit;

    LMethodMoveNext := LEnumType.GetMethod('MoveNext');
    if not Assigned(LMethodMoveNext) or
       (Length(LMethodMoveNext.GetParameters) <> 0) or
       (LMethodMoveNext.MethodKind <> mkFunction) or
       (LMethodMoveNext.ReturnType.Handle <> TypeInfo(Boolean))
    then
      Exit;

    Result := TDynamicList.Create(
      AInstance,
      LItemType,
      LMethodAdd,
      LMethodClear,
      LMethodMoveNext,
      LCurrentProp,
      LCountProp
    );

  finally
    LEnumObject.Free;
  end;
end;

function TDynamicList.MoveNext: Boolean;
begin
  Result := FMoveNextMethod.Invoke(FInstance, []).AsBoolean;
end;

function TDynamicList.NewItem: TValue;
begin
  Result := TRttiHelper.CreateNewValue(FItemType);
end;

{ TDynamicMap }

procedure TDynamicMap.Add(const AKey, AValue: TValue);
begin
  FAddMethod.Invoke(FInstance, [AKey, AValue]);
end;

procedure TDynamicMap.Clear;
begin
  FClearMethod.Invoke(FInstance, []);
end;

function TDynamicMap.Count: Integer;
begin
  Result := FCountProp.GetValue(FInstance).AsInteger;
end;

constructor TDynamicMap.Create(AInstance: TObject; AKeyType, AValueType: TRttiType;
  AAddMethod, AClearMethod: TRttiMethod; ACountProp: TRttiProperty;
  AKeyEnum, AValueEnum: TDynamicMap.TEnumerator);
begin
  FInstance := AInstance;
  FKeyType := AKeyType;
  FValueType := AValueType;
  FAddMethod := AAddMethod;
  FClearMethod := AClearMethod;
  FKeyEnum := AKeyEnum;
  FValueEnum := AValueEnum;
  FCountProp := ACountProp;
end;

function TDynamicMap.CurrentKey: TValue;
begin
  Result := FKeyEnum.Current;
end;

function TDynamicMap.CurrentValue: TValue;
begin
  Result := FValueEnum.Current;
end;

destructor TDynamicMap.Destroy;
begin
  FKeyEnum.Free;
  FValueEnum.Free;
  inherited;
end;

function TDynamicMap.GetKeyType: TRttiType;
begin
  Result := FKeyType;
end;

function TDynamicMap.GetValueType: TRttiType;
begin
  Result := FValueType;
end;

class function TDynamicMap.GuessType(AInstance: TObject): IDynamicMap;
var
  LMapType: TRttiType;
  LKeyType, LValType: TRttiType;
  LKeyProp, LValProp: TRttiProperty;
  LCountProp: TRttiProperty;
  LAddMethod, LClearMethod: TRttiMethod;

  LKeyEnumMethod, LValEnumMethod: TRttiMethod;
  LKeyEnumObject, LValEnumObject: TObject;
  LKeyEnum, LValEnum: TDynamicMap.TEnumerator;
begin
  Result := nil;

  LMapType := TRttiHelper.Context.GetType(AInstance.ClassType);

  // Keys & Values Enumerator
  LKeyProp := LMapType.GetProperty('Keys');
  if not Assigned(LKeyProp) then
    Exit;

  LValProp := LMapType.GetProperty('Values');
  if not Assigned(LValProp) then
    Exit;

  LKeyEnumObject := LKeyProp.GetValue(AInstance).AsObject;
  LValEnumObject := LValProp.GetValue(AInstance).AsObject;

  LKeyEnumMethod := TRttiHelper.Context.GetType(LKeyEnumObject.ClassInfo).GetMethod('GetEnumerator');
  LValEnumMethod := TRttiHelper.Context.GetType(LValEnumObject.ClassInfo).GetMethod('GetEnumerator');

  LKeyEnum := TDynamicMap.TEnumerator.Create(LKeyEnumMethod, LKeyEnumObject);
  LValEnum := TDynamicMap.TEnumerator.Create(LValEnumMethod, LValEnumObject);
  // End Keys & Values Enumerator

  LClearMethod := LMapType.GetMethod('Clear');
  if not Assigned(LClearMethod) then
    Exit;

  LAddMethod := LMapType.GetMethod('Add');
  if not Assigned(LAddMethod) or (Length(LAddMethod.GetParameters) <> 2) then
    Exit;

  LKeyType := LAddMethod.GetParameters[0].ParamType;
  LValType := LAddMethod.GetParameters[1].ParamType;

  LCountProp := LMapType.GetProperty('Count');
  if not Assigned(LCountProp) then
    Exit;

  Result := TDynamicMap.Create(
    AInstance,
    LKeyType,
    LValType,
    LAddMethod,
    LClearMethod,
    LCountProp,
    LKeyEnum,
    LValEnum
  );
end;

function TDynamicMap.MoveNext: Boolean;
begin
  Result := (FKeyEnum.MoveNext and FValueEnum.MoveNext);
end;

function TDynamicMap.NewKey: TValue;
begin
  Result := TRttiHelper.CreateNewValue(FKeyType);
end;

function TDynamicMap.NewValue: TValue;
begin
  Result := TRttiHelper.CreateNewValue(FValueType);
end;

{ TDynamicMap.TEnumerator }

constructor TDynamicMap.TEnumerator.Create(AMethod: TRttiMethod; AInstance: TObject);
begin
  // Memory creation, must destroy the object
  FInstance := AMethod.Invoke(AInstance, []).AsObject;

  FCurrentProperty := TRttiHelper.Context.GetType(FInstance.ClassInfo).GetProperty(CURRENT_PROP);
  if not Assigned(FCurrentProperty) then
    raise ENeonException.CreateFmt('Property [%s] not found', [CURRENT_PROP]);

  FMoveNextMethod := TRttiHelper.Context.GetType(FInstance.ClassInfo).GetMethod(MOVENEXT_METH);
  if not Assigned(FMoveNextMethod) then
    raise ENeonException.CreateFmt('Method [%s] not found', [MOVENEXT_METH]);
end;

function TDynamicMap.TEnumerator.Current: TValue;
begin
  Result := FCurrentProperty.GetValue(FInstance);
end;

destructor TDynamicMap.TEnumerator.Destroy;
begin
  FInstance.Free;
  inherited;
end;

function TDynamicMap.TEnumerator.MoveNext: Boolean;
begin
  Result := FMoveNextMethod.Invoke(FInstance, []).AsBoolean;
end;

end.
