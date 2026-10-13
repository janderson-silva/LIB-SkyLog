unit SkyLog;

interface

{$IF CompilerVersion < 33.0}
  {$MESSAGE FATAL 'Esta versao do SkyLog requer Delphi 10.3 Rio ou superior.'}
{$IFEND}

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  System.Rtti, System.TypInfo, System.Generics.Collections,
  Vcl.Forms, Vcl.Controls, Vcl.ExtCtrls;

type
  TSkyLog = class;
  TSkyLogWriteErrorEvent = procedure(Sender: TObject; const FileName,
    ErrorMessage: string) of object;

  TSkyLog = class(TComponent)
  private
    FEnabled: Boolean;
    FLogDirectory: string;
    FHooks: TList<TComponent>;
    FDiagnostics: TStringList;
    FLastWriteError: string;
    FOnWriteError: TSkyLogWriteErrorEvent;
    FWriting: Boolean;
    FLogAbort: Boolean;
    function GetForm: TCustomForm;
    procedure SetEnabled(const Value: Boolean);
    procedure AttachTree(Component: TComponent);
    procedure Detach;
    procedure WriteException(E: Exception; Component: TComponent;
      const EventName, HandlerName, Phase: string; Address: Pointer);
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Refresh;
    function OwnsComponent(Component: TComponent): Boolean;
    procedure LogException(E: Exception; Component: TComponent = nil;
      const EventName: string = ''; const HandlerName: string = '');
    procedure Execute(Component: TComponent; const EventName: string;
      const Action: TProc);
    property MonitoredForm: TCustomForm read GetForm;
    property Diagnostics: TStringList read FDiagnostics;
    property LastWriteError: string read FLastWriteError;
  published
    property Enabled: Boolean read FEnabled write SetEnabled default True;
    property LogDirectory: string read FLogDirectory write FLogDirectory;
    property LogAbort: Boolean read FLogAbort write FLogAbort default False;
    property OnWriteError: TSkyLogWriteErrorEvent read FOnWriteError write FOnWriteError;
  end;

implementation

uses
  System.IOUtils, FireDAC.Stan.Error, FireDAC.Comp.Client;

type
  PLogFrame = ^TLogFrame;
  TLogFrame = record
    Parent: PLogFrame;
    Correlation: string;
    Origin: string;
    EventName: string;
    HandlerName: string;
    Failure: Exception;
  end;

  TSkyHook = class(TComponent)
  protected
    Logger: TSkyLog;
    Target: TComponent;
    Depth: Integer;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor CreateHook(ALogger: TSkyLog; ATarget: TComponent);
    procedure Unhook; virtual;
  end;

  TSkyEventHook = class(TSkyHook)
  private
    Prop: PPropInfo;
    MethodType: TRttiMethodType;
    Impl: TMethodImplementation;
    Original: TMethod;
    Replacement: TMethod;
    HandlerName: string;
    IsFireDAC: Boolean;
    procedure Invoke(UserData: Pointer; const Args: TArray<TValue>;
      out Result: TValue);
{$IF CompilerVersion < 37.0}
    function LegacyEventMethod: TRttiMethod;
  published
    procedure LegacyFireDACError(ASender, AInitiator: TObject; var E: Exception);
{$IFEND}
  public
    constructor CreateEvent(ALogger: TSkyLog; ATarget: TComponent;
      AProp: PPropInfo; AType: TRttiMethodType);
    destructor Destroy; override;
    procedure Unhook; override;
  end;

  TSkyWindowHook = class(TSkyHook)
  private
    Original: TWndMethod;
    procedure WindowProc(var Message: TMessage);
  public
    constructor CreateWindow(ALogger: TSkyLog; ATarget: TControl);
    procedure Unhook; override;
  end;

  TSkyRetirement = class
  private
    Items: TObjectList<TSkyHook>;
    Timer: TTimer;
    procedure Collect(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Retire(Hook: TSkyHook);
  end;

var
  RttiContext: TRttiContext;
  Retirement: TSkyRetirement;
  FileLock: TObject;

threadvar
  CurrentFrame: PLogFrame;

function ComponentPath(Component: TComponent): string;
var
  Part: string;
begin
  Result := '';
  while (Component <> nil) and (Component <> Application) do
  begin
    Part := Component.Name;
    if Part = '' then
      Part := Component.ClassName;
    if Result = '' then
      Result := Part
    else
      Result := Part + '.' + Result;
    Component := Component.Owner;
  end;
end;

function SameMethod(const A, B: TMethod): Boolean;
begin
  Result := (A.Code = B.Code) and (A.Data = B.Data);
end;

function SingleLine(const S: string): string;
begin
  Result := S.Replace('\', '\\').Replace(#13, '\r').Replace(#10, '\n')
    .Replace('|', '\|');
end;

procedure EnterFrame(var Frame: TLogFrame; Component: TComponent;
  const EventName, HandlerName: string);
var
  ID: TGUID;
begin
  Frame.Parent := CurrentFrame;
  Frame.Failure := nil;
  Frame.Origin := ComponentPath(Component);
  Frame.EventName := EventName;
  Frame.HandlerName := HandlerName;
  if Frame.Parent <> nil then
    Frame.Correlation := Frame.Parent.Correlation
  else
  begin
    CreateGUID(ID);
    Frame.Correlation := GUIDToString(ID);
  end;
  CurrentFrame := @Frame;
end;

procedure LeaveFrame(var Frame: TLogFrame);
begin
  CurrentFrame := Frame.Parent;
  // Only propagate a failure while it is actually unwinding. Successful calls
  // never leave stale exception pointers in the parent frame.
  if (Frame.Parent <> nil) and (Frame.Failure <> nil) then
    Frame.Parent.Failure := Frame.Failure;
end;

{ Active trampolines must survive a form/logger freed inside its own event. }
constructor TSkyRetirement.Create;
begin
  inherited;
  Items := TObjectList<TSkyHook>.Create(True);
  Timer := TTimer.Create(nil);
  Timer.Enabled := False;
  Timer.Interval := 100;
  Timer.OnTimer := Collect;
end;

destructor TSkyRetirement.Destroy;
begin
  Timer.Free;
  Items.Free;
  inherited;
end;

procedure TSkyRetirement.Collect(Sender: TObject);
var
  I: Integer;
begin
  for I := Items.Count - 1 downto 0 do
    if Items[I].Depth = 0 then
      Items.Delete(I);
  Timer.Enabled := Items.Count > 0;
end;

procedure TSkyRetirement.Retire(Hook: TSkyHook);
begin
  Hook.Unhook;
  if Hook.Depth = 0 then
    Hook.Free
  else
  begin
    Items.Add(Hook);
    Timer.Enabled := True;
  end;
end;

constructor TSkyHook.CreateHook(ALogger: TSkyLog; ATarget: TComponent);
begin
  inherited Create(nil);
  Logger := ALogger;
  Target := ATarget;
  Target.FreeNotification(Self);
  Logger.FreeNotification(Self);
end;

procedure TSkyHook.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = Target) then
    Target := nil;
  if (Operation = opRemove) and (AComponent = Logger) then
    Logger := nil;
end;

procedure TSkyHook.Unhook;
begin
  // An in-flight event remains observable across Refresh. FreeNotification
  // clears Logger if it is destroyed before this callback returns.
end;

{$IF CompilerVersion < 37.0}
procedure TSkyEventHook.LegacyFireDACError(ASender, AInitiator: TObject;
  var E: Exception);
begin
  // Signature source for a FireDAC event that has no original handler.
  // Only its RTTI is used; this method is never called.
end;

function TSkyEventHook.LegacyEventMethod: TRttiMethod;
var
  Candidate: TRttiMethod;
  Parameters, Expected: TArray<TRttiParameter>;
  I: Integer;
  Matches: Boolean;
begin
  // Rio exposes CreateImplementation on TRttiMethod, not TRttiMethodType.
  // Use the handler's published/extended RTTI and let the RTL marshal the
  // platform ABI. The RTTI context owns the signature and invocation metadata.
  if IsFireDAC then
    Exit(RttiContext.GetType(TSkyEventHook).GetMethod('LegacyFireDACError'));

  if (Original.Code <> nil) and (Original.Data <> nil) then
  begin
    Expected := MethodType.GetParameters;
    for Candidate in RttiContext.GetType(TObject(Original.Data).ClassType).GetMethods do
      if (Candidate.CodeAddress = Original.Code) and Candidate.HasExtendedInfo and
        not Candidate.IsStatic and not Candidate.IsClassMethod and
        (Candidate.CallingConvention = MethodType.CallingConvention) and
        (Candidate.ReturnType = MethodType.ReturnType) then
      begin
        Parameters := Candidate.GetParameters;
        Matches := Length(Parameters) = Length(Expected);
        if Matches then
          for I := 0 to High(Parameters) do
            if (Parameters[I].ParamType <> Expected[I].ParamType) or
              (Parameters[I].Flags <> Expected[I].Flags) then
            begin
              Matches := False;
              Break;
            end;
        if Matches then
          Exit(Candidate);
      end;
  end;
  raise ENotSupportedException.Create(
    'Esta versao do Delphi requer RTTI estendida no metodo do evento. ' +
    'Publique o handler ou habilite RTTI para a visibilidade do metodo.');
end;
{$IFEND}

constructor TSkyEventHook.CreateEvent(ALogger: TSkyLog;
  ATarget: TComponent; AProp: PPropInfo; AType: TRttiMethodType);
var
  Name: string;
  Parameter: TRttiParameter;
begin
  inherited CreateHook(ALogger, ATarget);
  Prop := AProp;
  MethodType := AType;
  if (MethodType.CallingConvention <> ccReg) or
    (Length(MethodType.GetParameters) <> GetTypeData(MethodType.Handle).ParamCount) then
    raise ENotSupportedException.Create('Assinatura sem RTTI completa ou convencao diferente de register.');
  for Parameter in MethodType.GetParameters do
    if (Parameter.ParamType = nil) or (pfArray in Parameter.Flags) then
      raise ENotSupportedException.Create('Parametro sem tipo ou open array nao suportado.');
  Original := GetMethodProp(Target, Prop);
  IsFireDAC := AType.Handle = TypeInfo(TFDErrorEvent);
  if (Original.Code <> nil) and (Original.Data <> nil) then
  begin
    Name := TObject(Original.Data).MethodName(Original.Code);
    HandlerName := string(Name);
    if HandlerName = '' then
      HandlerName := '0x' + IntToHex(NativeUInt(Original.Code), SizeOf(Pointer) * 2);
    HandlerName := TObject(Original.Data).ClassName + '.' + HandlerName;
  end;
{$IF CompilerVersion >= 37.0}
  Impl := MethodType.CreateImplementation(nil,
{$ELSE}
  Impl := LegacyEventMethod.CreateImplementation(nil,
{$IFEND}
    procedure(UserData: Pointer; const Args: TArray<TValue>; out Result: TValue)
    begin
      Invoke(UserData, Args, Result);
    end);
  Replacement.Code := Impl.CodeAddress;
  Replacement.Data := Self;
  SetMethodProp(Target, Prop, Replacement);
end;

destructor TSkyEventHook.Destroy;
begin
  Unhook;
  Impl.Free;
  inherited;
end;

procedure TSkyEventHook.Unhook;
begin
  if (Target <> nil) and (Replacement.Code <> nil) and
    SameMethod(GetMethodProp(Target, Prop), Replacement) then
    SetMethodProp(Target, Prop, Original);
  inherited;
end;

procedure TSkyEventHook.Invoke(UserData: Pointer; const Args: TArray<TValue>;
  out Result: TValue);
var
  Frame: TLogFrame;
  Values: TArray<TValue>;
  Callable: TValue;
  E: Exception;
  Parameters: TArray<TRttiParameter>;
  I: Integer;
  ErrorSource: TComponent;
begin
  Inc(Depth);
  EnterFrame(Frame, Target, string(Prop.Name), HandlerName);
  try
    // CreateImplementation includes the hidden Self parameter at index zero.
    // Scalar TValue values are copied; copy var/out values back before the
    // trampoline writes its argument array back to the original caller.
    Values := Copy(Args, 1, Length(Args) - 1);
    Parameters := MethodType.GetParameters;
    for I := 0 to High(Values) do
      if Parameters[I].ParamType <> nil then
        Values[I] := Values[I].Cast(Parameters[I].ParamType.Handle);
    if IsFireDAC and (Length(Values) = 3) and (Logger <> nil) then
    begin
      E := Exception(Values[2].AsObject);
      ErrorSource := Target;
      if Values[1].AsObject is TComponent then
        ErrorSource := TComponent(Values[1].AsObject)
      else if Target is TFDCustomConnection then
        // A shared connection may report an internal command from any form.
        // Without a component initiator, only its query's OnError is scoped.
        ErrorSource := nil;
      if (E <> nil) and Logger.OwnsComponent(ErrorSource) then
        Logger.WriteException(E, ErrorSource, string(Prop.Name), HandlerName,
          'FireDAC', nil);
    end;
    try
      Result := TValue.Empty;
      if MethodType.ReturnType <> nil then
        TValue.Make(nil, MethodType.ReturnType.Handle, Result);
      if Original.Code <> nil then
      begin
        TValue.Make(@Original, MethodType.Handle, Callable);
        try
          Result := MethodType.Invoke(Callable, Values);
        finally
          for I := 0 to High(Values) do
            if Parameters[I].Flags * [pfVar, pfOut] <> [] then
              Args[I + 1] := Values[I];
        end;
      end;
      Frame.Failure := nil;
    except
      on E: Exception do
      begin
        if (Logger <> nil) and (Target <> nil) and (Frame.Failure <> E) then
          Logger.WriteException(E, Target, string(Prop.Name), HandlerName,
            'Evento', ExceptAddr);
        Frame.Failure := E;
        raise;
      end;
    end;
  finally
    LeaveFrame(Frame);
    Dec(Depth);
  end;
end;

constructor TSkyWindowHook.CreateWindow(ALogger: TSkyLog; ATarget: TControl);
begin
  inherited CreateHook(ALogger, ATarget);
  Original := ATarget.WindowProc;
  ATarget.WindowProc := WindowProc;
end;

procedure TSkyWindowHook.Unhook;
var
  Current, Replacement: TWndMethod;
begin
  if Target <> nil then
  begin
    Current := TControl(Target).WindowProc;
    Replacement := WindowProc;
    if SameMethod(TMethod(Current), TMethod(Replacement)) then
      TControl(Target).WindowProc := Original;
  end;
  inherited;
end;

procedure TSkyWindowHook.WindowProc(var Message: TMessage);
var
  Frame: TLogFrame;
begin
  Inc(Depth);
  EnterFrame(Frame, Target, 'WindowProc(0x' + IntToHex(Message.Msg, 4) + ')', '');
  try
    try
      Original(Message);
      Frame.Failure := nil;
    except
      on E: Exception do
      begin
        if (Logger <> nil) and (Target <> nil) and (Frame.Failure <> E) then
          Logger.WriteException(E, Target, Frame.EventName, '', 'Mensagem', ExceptAddr);
        Frame.Failure := E;
        raise;
      end;
    end;
  finally
    LeaveFrame(Frame);
    Dec(Depth);
  end;
end;

constructor TSkyLog.Create(AOwner: TComponent);
begin
  inherited;
  FEnabled := True;
  FHooks := TList<TComponent>.Create;
  FDiagnostics := TStringList.Create;
  // Runtime construction needs an explicit Refresh after configuring events.
  // DFM instances are activated by Loaded, before the normal OnCreate call.
end;

destructor TSkyLog.Destroy;
begin
  FEnabled := False;
  Detach;
  FHooks.Free;
  FDiagnostics.Free;
  inherited;
end;

function TSkyLog.GetForm: TCustomForm;
begin
  if Owner is TCustomForm then
    Result := TCustomForm(Owner)
  else
    Result := nil;
end;

function TSkyLog.OwnsComponent(Component: TComponent): Boolean;
begin
  Result := False;
  if MonitoredForm = nil then
    Exit;
  while Component <> nil do
  begin
    if Component = MonitoredForm then
      Exit(True);
    // A child form is a separate scope even when its Owner is this form.
    if Component is TCustomForm then
      Exit(False);
    Component := Component.Owner;
  end;
end;

procedure TSkyLog.Loaded;
begin
  inherited;
  Refresh;
end;

procedure TSkyLog.SetEnabled(const Value: Boolean);
begin
  if FEnabled = Value then
    Exit;
  FEnabled := Value;
  if Value then
    Refresh
  else
    Detach;
end;

procedure TSkyLog.Detach;
var
  I: Integer;
begin
  if FHooks = nil then
    Exit;
  for I := FHooks.Count - 1 downto 0 do
    Retirement.Retire(TSkyHook(FHooks[I]));
  FHooks.Clear;
end;

procedure TSkyLog.Refresh;
var
  I: Integer;
begin
  if csDesigning in ComponentState then
    Exit;
  if GetCurrentThreadId <> MainThreadID then
    raise EInvalidOperation.Create('SkyLog.Refresh deve executar na thread principal.');
  Detach;
  FDiagnostics.Clear;
  if not FEnabled then
    Exit;
  if MonitoredForm = nil then
    raise EInvalidOperation.Create('O Owner do SkyLog deve ser o formulario monitorado.');
  for I := 0 to Owner.ComponentCount - 1 do
    if (Owner.Components[I] is TSkyLog) and (Owner.Components[I] <> Self) and
      TSkyLog(Owner.Components[I]).Enabled then
      raise EInvalidOperation.Create('Use apenas um SkyLog ativo por formulario.');
{$IF CompilerVersion < 37.0}
  // Loading the package in the Rio IDE must not create a timer/window.
  // Start retirement only when a form is actually monitored at runtime.
  if Retirement = nil then
    Retirement := TSkyRetirement.Create;
{$IFEND}
  AttachTree(MonitoredForm);
end;

procedure TSkyLog.AttachTree(Component: TComponent);
var
  Props: PPropList;
  Count, I: Integer;
  Prop: PPropInfo;
  M: TMethod;
  RType: TRttiType;
begin
  if not OwnsComponent(Component) or (Component is TSkyLog) then
    Exit;
  if Component is TControl then
    FHooks.Add(TSkyWindowHook.CreateWindow(Self, TControl(Component)));
  Count := GetPropList(Component.ClassInfo, [tkMethod], nil);
  GetMem(Props, Count * SizeOf(Pointer));
  try
    GetPropList(Component.ClassInfo, [tkMethod], Props);
    for I := 0 to Count - 1 do
    begin
      Prop := Props[I];
      if (Prop.GetProc = nil) or (Prop.SetProc = nil) then
        Continue;
      M := GetMethodProp(Component, Prop);
      if (M.Code = nil) and (Prop.PropType^ <> TypeInfo(TFDErrorEvent)) then
        Continue;
      try
        RType := RttiContext.GetType(Prop.PropType^);
        if not (RType is TRttiMethodType) then
          Continue;
        FHooks.Add(TSkyEventHook.CreateEvent(Self, Component, Prop,
          TRttiMethodType(RType)));
      except
        on E: Exception do
          FDiagnostics.Add(ComponentPath(Component) + '.' + string(Prop.Name) +
            ': ' + E.ClassName + ': ' + E.Message);
      end;
    end;
  finally
    FreeMem(Props);
  end;
  for I := 0 to Component.ComponentCount - 1 do
    AttachTree(Component.Components[I]);
end;

procedure TSkyLog.WriteException(E: Exception; Component: TComponent;
  const EventName, HandlerName, Phase: string; Address: Pointer);
var
  Stamp: TDateTime;
  Directory, FileName, Entry, Code, Chain: string;
  Frame: PLogFrame;
  DB: EFDDBEngineException;
  I: Integer;
  Bytes: TBytes;
  Stream: TFileStream;
begin
  if (E = nil) or not FEnabled or FWriting or
    ((E is EAbort) and not FLogAbort) or not OwnsComponent(Component) then
    Exit;
  FWriting := True;
  FileName := '';
  try
    try
      Stamp := Now;
      Directory := FLogDirectory;
      if Directory = '' then
        Directory := TPath.Combine(ExtractFilePath(ParamStr(0)), 'logs')
      else if not TPath.IsPathRooted(Directory) then
        Directory := TPath.Combine(ExtractFilePath(ParamStr(0)), Directory);
      FileName := TPath.Combine(Directory, FormatDateTime('yyyy-mm-dd', Stamp) + '.log');
      Code := 'n/a';
      DB := nil;
      if E is EFDDBEngineException then
        DB := EFDDBEngineException(E)
      else if E is EFDDBArrayExecuteError then
        DB := EFDDBArrayExecuteError(E).Exception;
      if DB <> nil then
        Code := IntToStr(DB.ErrorCode)
      else if E is EOSError then
        Code := IntToStr(EOSError(E).ErrorCode);
      Entry := '[' + FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Stamp) +
        '] Origem: ' + SingleLine(ComponentPath(Component)) +
        ' | Formulario: ' + SingleLine(MonitoredForm.Name) +
        ' | Componente: ' + SingleLine(Component.Name) + ' (' + Component.ClassName + ')' +
        ' | Evento: ' + SingleLine(EventName) + ' | Metodo: ' + SingleLine(HandlerName) +
        ' | ' + E.ClassName + ' | Codigo: ' + Code + ' | Fase: ' + Phase +
        ' | PID: ' + UIntToStr(GetCurrentProcessId) +
        ' | Thread: ' + UIntToStr(GetCurrentThreadId);
      if CurrentFrame <> nil then
        Entry := Entry + ' | Ocorrencia: ' + CurrentFrame.Correlation;
      if Address <> nil then
        Entry := Entry + ' | Endereco: 0x' + IntToHex(NativeUInt(Address), SizeOf(Pointer) * 2);
      Entry := Entry + ' | Erro: ' + SingleLine(E.Message) + sLineBreak;
      Chain := '';
      Frame := CurrentFrame;
      while Frame <> nil do
      begin
        if Chain <> '' then
          Chain := ' -> ' + Chain;
        Chain := SingleLine(Frame.Origin + '.' + Frame.EventName +
          ' [' + Frame.HandlerName + ']') + Chain;
        Frame := Frame.Parent;
      end;
      if Chain <> '' then
        Entry := Entry + '  Contexto: ' + Chain + sLineBreak;
      if DB <> nil then
      begin
        for I := 0 to DB.ErrorCount - 1 do
          Entry := Entry + Format('  Banco[%d]: Codigo=%d | Objeto=%s | Erro=%s',
            [I, DB.Errors[I].ErrorCode, SingleLine(DB.Errors[I].ObjName),
             SingleLine(DB.Errors[I].Message)]) + sLineBreak;
      end;
      if E.StackTrace <> '' then
        Entry := Entry + '  StackTrace: ' + SingleLine(E.StackTrace) + sLineBreak;
      Bytes := TEncoding.UTF8.GetBytes(Entry);
      System.TMonitor.Enter(FileLock);
      try
        if not ForceDirectories(Directory) then
          raise EInOutError.Create('Nao foi possivel criar a pasta de logs: ' + Directory);
        if FileExists(FileName) then
          Stream := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyWrite)
        else
          Stream := TFileStream.Create(FileName, fmCreate or fmShareDenyWrite);
        try
          Stream.Seek(0, soEnd);
          if Length(Bytes) > 0 then
            Stream.WriteBuffer(Bytes[0], Length(Bytes));
        finally
          Stream.Free;
        end;
      finally
        System.TMonitor.Exit(FileLock);
      end;
      FLastWriteError := '';
    except
      on LogError: Exception do
      begin
        FLastWriteError := LogError.ClassName + ': ' + LogError.Message;
        OutputDebugString(PChar('SkyLog: ' + FLastWriteError));
        if Assigned(FOnWriteError) then
          try
            FOnWriteError(Self, FileName, FLastWriteError);
          except
            // A logging failure must never replace the application's exception.
          end;
      end;
    end;
  finally
    FWriting := False;
  end;
end;

procedure TSkyLog.LogException(E: Exception; Component: TComponent;
  const EventName, HandlerName: string);
begin
  if Component = nil then
    Component := MonitoredForm;
  WriteException(E, Component, EventName, HandlerName, 'Manual', ExceptAddr);
end;

procedure TSkyLog.Execute(Component: TComponent; const EventName: string;
  const Action: TProc);
var
  Frame: TLogFrame;
begin
  if not Assigned(Action) then
    raise EArgumentNilException.Create('Action');
  if Component = nil then
    Component := MonitoredForm;
  if not OwnsComponent(Component) then
    raise EArgumentException.Create('O componente informado nao pertence a este formulario.');
  EnterFrame(Frame, Component, EventName, '');
  try
    try
      Action();
      Frame.Failure := nil;
    except
      on E: Exception do
      begin
        if Frame.Failure <> E then
          WriteException(E, Component, EventName, '', 'Operacao', ExceptAddr);
        Frame.Failure := E;
        raise;
      end;
    end;
  finally
    LeaveFrame(Frame);
  end;
end;

initialization
  RttiContext := TRttiContext.Create;
  FileLock := TObject.Create;
{$IF CompilerVersion >= 37.0}
  Retirement := TSkyRetirement.Create;
{$IFEND}

finalization
  Retirement.Free;
  FileLock.Free;
  RttiContext.Free;

end.
