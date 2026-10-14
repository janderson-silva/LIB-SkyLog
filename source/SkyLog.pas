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
  TSkyLogFormat = (slfJSON, slfText);
  TSkyLogLevel = (sllDebug, sllInfo, sllWarning, sllError, sllFatal);
  TSkyLog = class;
  TSkyLogWriteErrorEvent = procedure(Sender: TObject; const FileName,
    ErrorMessage: string) of object;
  TSkyLogStackTraceEvent = procedure(Sender: TObject; E: Exception;
    Address: Pointer; var StackTrace: string) of object;

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
    FApplicationName: string;
    FApplicationVersion: string;
    FApplicationBuild: string;
    FMaxFileSizeMB: Integer;
    FRetentionDays: Integer;
    FLastCleanupError: string;
    FOnCleanupError: TSkyLogWriteErrorEvent;
    FOnGetStackTrace: TSkyLogStackTraceEvent;
    FOnDiagnostics: TNotifyEvent;
    FNotifyingDiagnostics: Boolean;
    FLogFormat: TSkyLogFormat;
    FMinimumLevel: TSkyLogLevel;
    FMaskSensitiveData: Boolean;
    FSensitiveFields: TStrings;
    FSensitiveValues: TStrings;
    function GetRoot: TComponent;
    function GetForm: TCustomForm;
    procedure SetSensitiveFields(const Value: TStrings);
    procedure SetSensitiveValues(const Value: TStrings);
    function MaskText(const Value: string): string;
    procedure SetEnabled(const Value: Boolean);
    procedure SetMaxFileSizeMB(const Value: Integer);
    procedure SetRetentionDays(const Value: Integer);
    procedure NotifyDiagnostics;
    procedure AttachTree(Component: TComponent);
    procedure Detach;
    procedure WriteException(E: Exception; Component: TComponent;
      const EventName, HandlerName, Phase: string; Address: Pointer);
    procedure WriteRecord(Level: TSkyLogLevel; const MessageText: string;
      E: Exception; Component: TComponent;
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
    procedure Log(Level: TSkyLogLevel; const MessageText: string;
      Component: TComponent = nil; const EventName: string = '');
    procedure Debug(const MessageText: string; Component: TComponent = nil);
    procedure Info(const MessageText: string; Component: TComponent = nil);
    procedure Warning(const MessageText: string; Component: TComponent = nil);
    procedure Error(const MessageText: string; Component: TComponent = nil);
    procedure Fatal(const MessageText: string; Component: TComponent = nil);
    property MonitoredRoot: TComponent read GetRoot;
    property MonitoredForm: TCustomForm read GetForm;
    property Diagnostics: TStringList read FDiagnostics;
    property LastWriteError: string read FLastWriteError;
    property LastCleanupError: string read FLastCleanupError;
  published
    property LogFormat: TSkyLogFormat read FLogFormat write FLogFormat default slfJSON;
    property MinimumLevel: TSkyLogLevel read FMinimumLevel write FMinimumLevel default sllDebug;
    property MaskSensitiveData: Boolean read FMaskSensitiveData write FMaskSensitiveData default True;
    property SensitiveFields: TStrings read FSensitiveFields write SetSensitiveFields;
    property SensitiveValues: TStrings read FSensitiveValues write SetSensitiveValues;
    property Enabled: Boolean read FEnabled write SetEnabled default True;
    property LogDirectory: string read FLogDirectory write FLogDirectory;
    property LogAbort: Boolean read FLogAbort write FLogAbort default False;
    property ApplicationName: string read FApplicationName write FApplicationName;
    property ApplicationVersion: string read FApplicationVersion write FApplicationVersion;
    property ApplicationBuild: string read FApplicationBuild write FApplicationBuild;
    property MaxFileSizeMB: Integer read FMaxFileSizeMB write SetMaxFileSizeMB default 10;
    property RetentionDays: Integer read FRetentionDays write SetRetentionDays default 30;
    property OnWriteError: TSkyLogWriteErrorEvent read FOnWriteError write FOnWriteError;
    property OnCleanupError: TSkyLogWriteErrorEvent read FOnCleanupError write FOnCleanupError;
    property OnGetStackTrace: TSkyLogStackTraceEvent read FOnGetStackTrace write FOnGetStackTrace;
    property OnDiagnostics: TNotifyEvent read FOnDiagnostics write FOnDiagnostics;
  end;

implementation

uses
  System.IOUtils, System.DateUtils, System.Hash, System.JSON, System.RegularExpressions,
  System.StrUtils,
  FireDAC.Stan.Error, FireDAC.Comp.Client;

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
  FileParts: TDictionary<string, Integer>;
  CleanupDates: TDictionary<string, TDateTime>;
  ProcessSession: string;
  ExecutableName: string;
  ExecutableVersion: string;
  ExecutableBuild: string;
  StorageName: string;

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

function LogValue(const S: string): string;
begin
  if S = '' then
    Result := 'n/a'
  else
    Result := SingleLine(S);
end;

function NewIdentifier: string;
var
  ID: TGUID;
begin
  if CreateGUID(ID) <> 0 then
    raise EInvalidOperation.Create('Nao foi possivel gerar um identificador de log.');
  Result := GUIDToString(ID);
end;

procedure EnsureProcessInfo;
var
  FileName: string;
  Size, Handle: DWORD;
  InfoSize: UINT;
  Buffer: TBytes;
  Info: PVSFixedFileInfo;
  InfoPointer: Pointer;
begin
  // Called under FileLock, lazily: loading the package in the IDE needs no I/O.
  if ProcessSession <> '' then
    Exit;
  FileName := ExpandFileName(ParamStr(0));
  ExecutableName := ExtractFileName(FileName);
  ExecutableVersion := '';
  ExecutableBuild := '';
  StorageName := 'skylog-v2-' + THashSHA2.GetHashString(LowerCase(FileName));
  Handle := 0;
  Size := GetFileVersionInfoSize(PChar(FileName), Handle);
  if Size > 0 then
  begin
    SetLength(Buffer, Size);
    if GetFileVersionInfo(PChar(FileName), 0, Size, @Buffer[0]) and
      VerQueryValue(@Buffer[0], '\', InfoPointer, InfoSize) then
    begin
      Info := PVSFixedFileInfo(InfoPointer);
      if (Info <> nil) and (InfoSize >= SizeOf(TVSFixedFileInfo)) and
        (Info.dwSignature = $FEEF04BD) then
      begin
        ExecutableVersion := Format('%d.%d.%d.%d',
          [HiWord(Info.dwFileVersionMS), LoWord(Info.dwFileVersionMS),
           HiWord(Info.dwFileVersionLS), LoWord(Info.dwFileVersionLS)]);
        ExecutableBuild := IntToStr(LoWord(Info.dwFileVersionLS));
      end;
    end;
  end;
  ProcessSession := NewIdentifier.Replace('{', '').Replace('}', '').Replace('-', '');
end;

function LogTimestamp(out LocalStamp: TDateTime): string;
var
  UTC: TSystemTime;
  UTCStamp: TDateTime;
  OffsetMinutes: Integer;
  Sign: string;
begin
  GetSystemTime(UTC);
  UTCStamp := SystemTimeToDateTime(UTC);
  LocalStamp := TTimeZone.Local.ToLocalTime(UTCStamp);
  // Derive both the wall time and its offset from the same UTC instant,
  // including the repeated hour at the end of daylight saving time.
  OffsetMinutes := Round((LocalStamp - UTCStamp) * MinsPerDay);
  if OffsetMinutes < 0 then
    Sign := '-'
  else
    Sign := '+';
  OffsetMinutes := Abs(OffsetMinutes);
  Result := FormatDateTime('yyyy-mm-dd"T"hh":"nn":"ss"."zzz', LocalStamp) +
    Sign + Format('%.2d:%.2d', [OffsetMinutes div 60, OffsetMinutes mod 60]);
end;

function IsManagedLog(const Name: string; out LogDate: TDateTime): Boolean;
var
  Parts: TArray<string>;
  I, Y, M, D, Part: Integer;
begin
  Result := False;
  if (ExtractFileExt(Name) <> '.log') and (ExtractFileExt(Name) <> '.jsonl') then
    Exit;
  Parts := ChangeFileExt(Name, '').Split(['_']);
  if Length(Parts) <> 3 then
    Exit;
  if (Length(Parts[0]) <> 17) or (Copy(Parts[0], 1, 7) <> 'skylog-') or
    (Length(Parts[1]) <> 32) or (Length(Parts[2]) <> 6) then
    Exit;
  for I := 1 to Length(Parts[1]) do
    if not CharInSet(Parts[1][I], ['0'..'9', 'A'..'F']) then
      Exit;
  for I := 1 to Length(Parts[2]) do
    if not CharInSet(Parts[2][I], ['0'..'9']) then
      Exit;
  if not TryStrToInt(Parts[2], Part) or (Part < 1) then
    Exit;
  if (Parts[0][12] <> '-') or (Parts[0][15] <> '-') then
    Exit;
  if not TryStrToInt(Copy(Parts[0], 8, 4), Y) or
    not TryStrToInt(Copy(Parts[0], 13, 2), M) or
    not TryStrToInt(Copy(Parts[0], 16, 2), D) then
    Exit;
  if (Y < 1) or (Y > 9999) or (M < 1) or (M > 12) or (D < 1) or (D > 31) then
    Exit;
  Result := TryEncodeDate(Y, M, D, LogDate);
  if Result then
    Result := Parts[0] = 'skylog-' + FormatDateTime('yyyy-mm-dd', LogDate);
end;

function CleanupLogs(const Directory: string; const Stamp: TDateTime;
  RetentionDays: Integer; out ErrorFile, ErrorMessage: string): Boolean;
var
  Search: TSearchRec;
  Key, Candidate: string;
  Previous, LogDate, Cutoff: TDateTime;
  Status: Integer;
  DeleteError: DWORD;
begin
  Result := False;
  ErrorFile := '';
  ErrorMessage := '';
  if RetentionDays = 0 then
    Exit;
  ErrorFile := Directory;
  try
    Key := Directory + '|' + IntToStr(RetentionDays);
    if CleanupDates.TryGetValue(Key, Previous) and (Trunc(Stamp) = Previous) then
      Exit;
    // At most one sweep per day and policy, even after an I/O error. It is
    // independent of appending the current record.
    Result := True;
    CleanupDates.AddOrSetValue(Key, Trunc(Stamp));
    Cutoff := Trunc(Stamp) - RetentionDays + 1;
    Status := FindFirst(TPath.Combine(Directory, 'skylog-*'), faAnyFile, Search);
    if Status = ERROR_FILE_NOT_FOUND then
      Exit;
    if Status <> 0 then
      RaiseLastOSError(Status);
    try
      repeat
        if (Search.Attr and faDirectory = 0) and
          (Search.FindData.dwFileAttributes and FILE_ATTRIBUTE_REPARSE_POINT = 0) and
          IsManagedLog(Search.Name, LogDate) and (LogDate < Cutoff) then
        begin
          Candidate := TPath.Combine(Directory, Search.Name);
          try
            // A recently modified old file may still be used by another process.
            if TFile.GetLastWriteTime(Candidate) < Cutoff then
              if not Winapi.Windows.DeleteFile(PChar(Candidate)) then
              begin
                DeleteError := GetLastError;
                // Another instance may have already removed this expired file.
                if DeleteError <> ERROR_FILE_NOT_FOUND then
                  RaiseLastOSError(DeleteError);
              end;
          except
            on E: Exception do
              if ErrorMessage = '' then
              begin
                ErrorFile := Candidate;
                ErrorMessage := E.ClassName + ': ' + E.Message;
              end;
          end;
        end;
        Status := FindNext(Search);
      until Status <> 0;
      if Status <> ERROR_NO_MORE_FILES then
        RaiseLastOSError(Status);
    finally
      FindClose(Search);
    end;
  except
    on E: Exception do
    begin
      Result := True;
      if ErrorMessage = '' then
        ErrorMessage := E.ClassName + ': ' + E.Message;
    end;
  end;
end;

procedure AppendLog(const Directory, BaseName, Extension: string; const Bytes: TBytes;
  MaxFileSizeMB: Integer; out FileName: string);
var
  Base: string;
  Part: Integer;
  Limit, OriginalSize: Int64;
  Stream: TFileStream;
begin
  Base := TPath.Combine(Directory, BaseName);
  // Each format maintains its own segment counter.
  if not FileParts.TryGetValue(Base + Extension, Part) then
    Part := 1;
  Limit := Int64(MaxFileSizeMB) * 1024 * 1024;
  while True do
  begin
    if Part > 999999 then
      raise EInOutError.Create('Limite de segmentos diarios do log atingido.');
    FileName := Base + '_' + Format('%.6d', [Part]) + Extension;
    if FileExists(FileName) then
      Stream := TFileStream.Create(FileName, fmOpenReadWrite or fmShareDenyWrite)
    else
      Stream := TFileStream.Create(FileName, fmCreate or fmShareDenyWrite);
    try
      // Preserve a complete record, even when that record alone exceeds Limit.
      if (Limit = 0) or (Stream.Size = 0) or
        (Stream.Size + Length(Bytes) <= Limit) then
      begin
        OriginalSize := Stream.Size;
        Stream.Seek(0, soEnd);
        try
          if Length(Bytes) > 0 then
            Stream.WriteBuffer(Bytes[0], Length(Bytes));
        except
          // A short/failed write must not leave half a JSON record before
          // the next append. Preserve the original I/O error if rollback fails.
          try
            Stream.Size := OriginalSize;
          except
          end;
          raise;
        end;
        FileParts.AddOrSetValue(Base + Extension, Part);
        Exit;
      end;
    finally
      Stream.Free;
    end;
    Inc(Part);
  end;
end;

procedure EnterFrame(var Frame: TLogFrame; Component: TComponent;
  const EventName, HandlerName: string);
begin
  Frame.Parent := CurrentFrame;
  Frame.Failure := nil;
  Frame.Origin := ComponentPath(Component);
  Frame.EventName := EventName;
  Frame.HandlerName := HandlerName;
  if Frame.Parent <> nil then
    Frame.Correlation := Frame.Parent.Correlation
  else
    Frame.Correlation := NewIdentifier;
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
  FLogFormat := slfJSON;
  FMinimumLevel := sllDebug;
  FMaskSensitiveData := True;
  FSensitiveFields := TStringList.Create;
  FSensitiveValues := TStringList.Create;
  FSensitiveFields.CommaText := 'password,passwd,pwd,senha,token,access_token,refresh_token,' +
    'authorization,api_key,apikey,secret,client_secret,cpf,cnpj,card,card_number,cvv,' +
    'conta,agencia,account,iban';
  FMaxFileSizeMB := 10;
  FRetentionDays := 30;
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
  FSensitiveFields.Free;
  FSensitiveValues.Free;
  inherited;
end;

function TSkyLog.GetRoot: TComponent;
begin
  if (Owner is TCustomForm) or (Owner is TDataModule) then
    Result := Owner
  else
    Result := nil;
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
  if MonitoredRoot = nil then
    Exit;
  while Component <> nil do
  begin
    if Component = MonitoredRoot then
      Exit(True);
    // Forms and DataModules are separate scopes, including nested owners.
    if (Component is TCustomForm) or (Component is TDataModule) then
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
  if ComponentState * [csDesigning, csLoading] <> [] then
  begin
    FEnabled := Value;
    Exit;
  end;
  if GetCurrentThreadId <> MainThreadID then
    raise EInvalidOperation.Create('SkyLog.Enabled deve ser alterado na thread principal.');
  FEnabled := Value;
  if Value then
  begin
    try
      Refresh;
    except
      FEnabled := False;
      raise;
    end;
  end
  else
    Detach;
end;

procedure TSkyLog.SetMaxFileSizeMB(const Value: Integer);
begin
  if Value < 0 then
    raise EArgumentOutOfRangeException.Create('MaxFileSizeMB nao pode ser negativo.');
  FMaxFileSizeMB := Value;
end;

procedure TSkyLog.SetRetentionDays(const Value: Integer);
begin
  if Value < 0 then
    raise EArgumentOutOfRangeException.Create('RetentionDays nao pode ser negativo.');
  FRetentionDays := Value;
end;

procedure TSkyLog.NotifyDiagnostics;
var
  I: Integer;
  Guard: TSkyHook;
begin
  if (FDiagnostics.Count = 0) or FNotifyingDiagnostics then
    Exit;
  Guard := TSkyHook.CreateHook(Self, Self);
  FNotifyingDiagnostics := True;
  try
    for I := 0 to FDiagnostics.Count - 1 do
      OutputDebugString(PChar('SkyLog Diagnostics: ' + FDiagnostics[I]));
    if Assigned(FOnDiagnostics) then
      try
        FOnDiagnostics(Self);
      except
        on E: Exception do
        begin
          if Guard.Logger = nil then
            Exit;
          FDiagnostics.Add(MaskText('OnDiagnostics: ' + E.ClassName + ': ' + E.Message));
          OutputDebugString(PChar('SkyLog: ' + FDiagnostics[FDiagnostics.Count - 1]));
        end;
      end;
  finally
    if Guard.Logger <> nil then
      Guard.Logger.FNotifyingDiagnostics := False;
    Guard.Free;
  end;
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
  if ComponentState * [csDesigning, csLoading, csDestroying] <> [] then
    Exit;
  if GetCurrentThreadId <> MainThreadID then
    raise EInvalidOperation.Create('SkyLog.Refresh deve executar na thread principal.');
  if not FEnabled then
  begin
    Detach;
    FDiagnostics.Clear;
    Exit;
  end;
  if MonitoredRoot = nil then
    raise EInvalidOperation.Create('O Owner do SkyLog deve ser o formulario ou DataModule monitorado.');
  for I := 0 to Owner.ComponentCount - 1 do
    if (Owner.Components[I] is TSkyLog) and (Owner.Components[I] <> Self) and
      TSkyLog(Owner.Components[I]).Enabled then
      raise EInvalidOperation.Create('Use apenas um SkyLog ativo por formulario ou DataModule.');
  // In every Delphi version, loading the package in the IDE needs no timer.
  if Retirement = nil then
    Retirement := TSkyRetirement.Create;
  Detach;
  FDiagnostics.Clear;
  try
    AttachTree(MonitoredRoot);
  except
    // Do not leave a half-attached tree after a fatal refresh failure.
    FEnabled := False;
    Detach;
    raise;
  end;
  NotifyDiagnostics;
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
          FDiagnostics.Add(MaskText(ComponentPath(Component) + '.' + string(Prop.Name) +
            ': ' + E.ClassName + ': ' + E.Message));
      end;
    end;
  finally
    FreeMem(Props);
  end;
  for I := 0 to Component.ComponentCount - 1 do
    AttachTree(Component.Components[I]);
end;

procedure TSkyLog.SetSensitiveFields(const Value: TStrings);
begin
  if Value <> FSensitiveFields then
    FSensitiveFields.Assign(Value);
end;

procedure TSkyLog.SetSensitiveValues(const Value: TStrings);
begin
  if Value <> FSensitiveValues then
    FSensitiveValues.Assign(Value);
end;

function TSkyLog.MaskText(const Value: string): string;
var
  Structured, Sanitized: TJSONValue;

  function MaskPlainText(const Text: string; IncludeFields: Boolean): string;
  var
    Covered: TArray<Boolean>;
    Secret, Field, Pattern: string;
    K, J, Position, Start: Integer;
    Matches: TMatchCollection;
    Builder: TStringBuilder;

    procedure MarkRange(Index, Count: Integer);
    var
      Offset: Integer;
    begin
      if Count = 0 then
        Exit;
      if Length(Covered) = 0 then
        SetLength(Covered, Length(Text));
      for Offset := Index to Index + Count - 1 do
        Covered[Offset - 1] := True;
    end;

  begin
    Result := Text;
    // Find every occurrence in the ORIGINAL text, including overlapping ones.
    // Replacing sequentially can expose suffixes and re-mask our own marker.
    for K := 0 to FSensitiveValues.Count - 1 do
    begin
      Secret := FSensitiveValues[K];
      if Secret = '' then
        Continue;
      Position := PosEx(Secret, Text, 1);
      while Position > 0 do
      begin
        MarkRange(Position, Length(Secret));
        Position := PosEx(Secret, Text, Position + 1);
      end;
    end;
    if IncludeFields then
    begin
      // Match fields against the original text too: a literal secret may
      // overlap a field name, but must not prevent masking that field's value.
      for K := 0 to FSensitiveFields.Count - 1 do
      begin
        Field := Trim(FSensitiveFields[K]);
        if Field = '' then
          Continue;
        Pattern := '(?i)(?<![\w])(["'']?' + TRegEx.Escape(Field) +
          '["'']?\s*[:=]\s*)("(?:\\.|[^"\\])*"|''(?:''''|[^''])*''|[^\r\n,;&|}\]]+)';
        Matches := TRegEx.Matches(Text, Pattern);
        for J := 0 to Matches.Count - 1 do
          MarkRange(Matches[J].Groups[2].Index, Matches[J].Groups[2].Length);
      end;
      Matches := TRegEx.Matches(Text,
        '(?<!\d)(?:\d{3}\.\d{3}\.\d{3}-\d{2}|\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2})(?!\d)');
      for J := 0 to Matches.Count - 1 do
        MarkRange(Matches[J].Index, Matches[J].Length);
    end;
    if Length(Covered) = 0 then
      Exit;
    Builder := TStringBuilder.Create;
    try
      Position := 0;
      while Position < Length(Text) do
      begin
        Start := Position;
        if Covered[Position] then
        begin
          while (Position < Length(Text)) and Covered[Position] do
            Inc(Position);
          Builder.Append('[REDACTED]');
        end
        else
        begin
          while (Position < Length(Text)) and not Covered[Position] do
            Inc(Position);
          Builder.Append(Copy(Text, Start + 1, Position - Start));
        end;
      end;
      Result := Builder.ToString;
    finally
      Builder.Free;
    end;
  end;

  function MaskJSON(Node: TJSONValue): TJSONValue;
  var
    Pair, NewPair: TJSONPair;
    Child: TJSONValue;
    K: Integer;
    Sensitive: Boolean;
  begin
    if Node is TJSONObject then
    begin
      Result := TJSONObject.Create;
      try
        for Pair in TJSONObject(Node) do
        begin
          Sensitive := False;
          for K := 0 to FSensitiveFields.Count - 1 do
            if (Trim(FSensitiveFields[K]) <> '') and
              SameText(Pair.JsonString.Value, Trim(FSensitiveFields[K])) then
            begin
              Sensitive := True;
              Break;
            end;
          // The string overload of AddPair ignores empty keys in older RTLs.
          NewPair := TJSONPair.Create(MaskPlainText(Pair.JsonString.Value, False),
            TJSONValue(nil));
          try
            if Sensitive then
              NewPair.JsonValue := TJSONString.Create('[REDACTED]')
            else
              NewPair.JsonValue := MaskJSON(Pair.JsonValue);
            TJSONObject(Result).AddPair(NewPair);
            NewPair := nil;
          finally
            NewPair.Free;
          end;
        end;
      except
        Result.Free;
        raise;
      end;
    end
    else if Node is TJSONArray then
    begin
      Result := TJSONArray.Create;
      try
        for Child in TJSONArray(Node) do
          TJSONArray(Result).AddElement(MaskJSON(Child));
      except
        Result.Free;
        raise;
      end;
    end
    // In Rio/Athens TJSONNumber inherits from TJSONString. Do not turn
    // ordinary numbers into strings or partially redact a numeric scalar.
    else if (Node is TJSONString) and not (Node is TJSONNumber) then
      Result := TJSONString.Create(MaskText(Node.Value))
    else if MaskPlainText(Node.ToJSON, False) <> Node.ToJSON then
      // A partial substitution would produce invalid JSON (e.g. 12[REDACTED]).
      // Mask the entire matching scalar, preserving other numbers/bools/nulls.
      Result := TJSONString.Create('[REDACTED]')
    else
      Result := Node.Clone as TJSONValue;
  end;

begin
  Result := Value;
  if not FMaskSensitiveData then
    Exit;
  try
    // Structured messages can contain sensitive arrays/objects, not just scalars.
    Structured := nil;
    if (Trim(Value) <> '') and CharInSet(Trim(Value)[1], ['{', '[']) then
      Structured := TJSONObject.ParseJSONValue(Value);
    try
      if (Structured is TJSONObject) or (Structured is TJSONArray) then
      begin
        Sanitized := MaskJSON(Structured);
        try
          Result := Sanitized.ToJSON;
        finally
          Sanitized.Free;
        end;
        Exit;
      end;
    finally
      Structured.Free;
    end;
    Result := MaskPlainText(Value, True);
  except
    // Never fall back to potentially sensitive text if redaction fails.
    Result := '[REDACTED]';
  end;
end;

procedure TSkyLog.WriteException(E: Exception; Component: TComponent;
  const EventName, HandlerName, Phase: string; Address: Pointer);
begin
  if (E = nil) or ((E is EAbort) and not FLogAbort) then
    Exit;
  WriteRecord(sllError, E.Message, E, Component, EventName, HandlerName, Phase, Address);
end;

procedure TSkyLog.WriteRecord(Level: TSkyLogLevel; const MessageText: string;
  E: Exception; Component: TComponent;
  const EventName, HandlerName, Phase: string; Address: Pointer);
const
  LevelNames: array[TSkyLogLevel] of string = ('Debug', 'Info', 'Warning', 'Error', 'Fatal');
var
  Stamp: TDateTime;
  Directory, FileName, Entry, Code, Chain, Extension: string;
  Timestamp, AppName, AppVersion, AppBuild, RecordID, Correlation: string;
  Trace, ProviderTrace, TraceError, CleanupFile, CleanupError: string;
  ScopeKind, FormName, ExceptionName, AddressText: string;
  Frame: PLogFrame;
  Frames: TList<PLogFrame>;
  DB: EFDDBEngineException;
  I: Integer;
  Bytes: TBytes;
  DirectoryAttributes: DWORD;
  Document, Item: TJSONObject;
  ContextItems, DatabaseItems: TJSONArray;
  Guard: TSkyHook;

  function V(const Text: string): string;
  begin
    Result := LogValue(MaskText(Text));
  end;

  procedure AddText(Obj: TJSONObject; const Key, Text: string);
  begin
    Obj.AddPair(Key, MaskText(Text));
  end;

begin
  // The component owns VCL hooks and mutable per-instance state. A file lock
  // alone does not make logging from worker threads safe.
  if GetCurrentThreadId <> MainThreadID then
    Exit;
  if (ComponentState * [csDesigning, csLoading, csDestroying] <> []) or
    not FEnabled or FWriting or (Level < FMinimumLevel) or
    not OwnsComponent(Component) then
    Exit;
  Guard := TSkyHook.CreateHook(Self, Component);
  FWriting := True;
  FileName := '';
  try
    try
      Timestamp := LogTimestamp(Stamp);
      System.TMonitor.Enter(FileLock);
      try
        EnsureProcessInfo;
      finally
        System.TMonitor.Exit(FileLock);
      end;
      AppName := FApplicationName;
      if AppName = '' then
        AppName := ExecutableName;
      AppVersion := FApplicationVersion;
      if AppVersion = '' then
        AppVersion := ExecutableVersion;
      AppBuild := FApplicationBuild;
      if AppBuild = '' then
        AppBuild := ExecutableBuild;
      RecordID := NewIdentifier;
      if CurrentFrame <> nil then
        Correlation := CurrentFrame.Correlation
      else
        Correlation := NewIdentifier;
      Directory := FLogDirectory;
      if Directory = '' then
        Directory := TPath.Combine(ExtractFilePath(ParamStr(0)), 'logs')
      else if not TPath.IsPathRooted(Directory) then
        Directory := TPath.Combine(ExtractFilePath(ParamStr(0)), Directory);
      Directory := TPath.Combine(ExpandFileName(Directory), StorageName);
      FileName := Directory;
      ScopeKind := 'DataModule';
      FormName := '';
      if MonitoredForm <> nil then
      begin
        ScopeKind := 'Form';
        FormName := MonitoredForm.Name;
      end;
      ExceptionName := '';
      if E <> nil then
        ExceptionName := E.ClassName;
      AddressText := '';
      if Address <> nil then
        AddressText := '0x' + IntToHex(NativeUInt(Address), SizeOf(Pointer) * 2);
      Code := '';
      DB := nil;
      if E is EFDDBEngineException then
        DB := EFDDBEngineException(E)
      else if E is EFDDBArrayExecuteError then
        DB := EFDDBArrayExecuteError(E).Exception;
      if DB <> nil then
        Code := IntToStr(DB.ErrorCode)
      else if E is EOSError then
        Code := IntToStr(EOSError(E).ErrorCode);
      Trace := '';
      TraceError := '';
      if E <> nil then
      begin
        try
          Trace := E.StackTrace;
        except
          on ProviderError: Exception do
            TraceError := 'Exception.StackTrace: ' + ProviderError.ClassName +
              ': ' + ProviderError.Message;
        end;
        if Assigned(FOnGetStackTrace) then
        begin
          ProviderTrace := Trace;
          try
            FOnGetStackTrace(Self, E, Address, ProviderTrace);
            Trace := ProviderTrace;
          except
            on ProviderError: Exception do
            begin
              if TraceError <> '' then
                TraceError := TraceError + '; ';
              TraceError := TraceError + 'OnGetStackTrace: ' + ProviderError.ClassName +
                ': ' + ProviderError.Message;
            end;
          end;
        end;
      end;
      // OnGetStackTrace is application code and can destroy the logger or
      // the component. FreeNotification lets us stop without dereferencing it.
      if (Guard.Logger = nil) or (Guard.Target = nil) then
        Exit;
      if FLogFormat = slfJSON then
      begin
        Extension := '.jsonl';
        Document := TJSONObject.Create;
        try
          Document.AddPair('formato', TJSONNumber.Create(2));
          AddText(Document, 'timestamp', Timestamp);
          AddText(Document, 'level', LevelNames[Level]);
          AddText(Document, 'aplicacao', AppName);
          AddText(Document, 'versao', AppVersion);
          AddText(Document, 'build', AppBuild);
          AddText(Document, 'execucao', ProcessSession);
          AddText(Document, 'origem', ComponentPath(Component));
          AddText(Document, 'escopo', MonitoredRoot.Name);
          AddText(Document, 'tipoEscopo', ScopeKind);
          AddText(Document, 'formulario', FormName);
          AddText(Document, 'componente', Component.Name);
          AddText(Document, 'classeComponente', Component.ClassName);
          AddText(Document, 'evento', EventName);
          AddText(Document, 'metodo', HandlerName);
          if E = nil then
            Document.AddPair('excecao', TJSONNull.Create)
          else
            AddText(Document, 'excecao', ExceptionName);
          if Code = '' then
            Document.AddPair('codigo', TJSONNull.Create)
          else
            Document.AddPair('codigo', TJSONNumber.Create(Code));
          AddText(Document, 'fase', Phase);
          Document.AddPair('pid', TJSONNumber.Create(Int64(GetCurrentProcessId)));
          Document.AddPair('thread', TJSONNumber.Create(Int64(GetCurrentThreadId)));
          AddText(Document, 'correlacao', Correlation);
          AddText(Document, 'registro', RecordID);
          AddText(Document, 'endereco', AddressText);
          AddText(Document, 'mensagem', MessageText);
          ContextItems := TJSONArray.Create;
          Document.AddPair('contexto', ContextItems);
          Frames := TList<PLogFrame>.Create;
          try
            Frame := CurrentFrame;
            while Frame <> nil do
            begin
              Frames.Add(Frame);
              Frame := Frame.Parent;
            end;
            for I := Frames.Count - 1 downto 0 do
            begin
              Item := TJSONObject.Create;
              ContextItems.AddElement(Item);
              AddText(Item, 'origem', Frames[I].Origin);
              AddText(Item, 'evento', Frames[I].EventName);
              AddText(Item, 'metodo', Frames[I].HandlerName);
            end;
          finally
            Frames.Free;
          end;
          DatabaseItems := TJSONArray.Create;
          Document.AddPair('banco', DatabaseItems);
          if DB <> nil then
            for I := 0 to DB.ErrorCount - 1 do
            begin
              Item := TJSONObject.Create;
              DatabaseItems.AddElement(Item);
              Item.AddPair('codigo', TJSONNumber.Create(DB.Errors[I].ErrorCode));
              AddText(Item, 'objeto', DB.Errors[I].ObjName);
              AddText(Item, 'mensagem', DB.Errors[I].Message);
            end;
          AddText(Document, 'stackTrace', Trace);
          if TraceError <> '' then
            AddText(Document, 'stackTraceErro', TraceError);
          Entry := Document.ToJSON + sLineBreak;
        finally
          Document.Free;
        end;
      end
      else
      begin
        Extension := '.log';
        Entry := '[' + Timestamp + '] Formato: 2' +
          ' | Level: ' + LevelNames[Level] +
          ' | Aplicacao: ' + V(AppName) + ' | Versao: ' + V(AppVersion) +
          ' | Build: ' + V(AppBuild) + ' | Execucao: ' + ProcessSession +
          ' | Origem: ' + V(ComponentPath(Component)) +
          ' | Escopo: ' + V(MonitoredRoot.Name) + ' | TipoEscopo: ' + ScopeKind +
          ' | Formulario: ' + V(FormName) +
          ' | Componente: ' + V(Component.Name) + ' (' + V(Component.ClassName) + ')' +
          ' | Evento: ' + V(EventName) + ' | Metodo: ' + V(HandlerName) +
          ' | Excecao: ' + V(ExceptionName) + ' | Codigo: ' + LogValue(Code) + ' | Fase: ' + V(Phase) +
          ' | PID: ' + UIntToStr(GetCurrentProcessId) +
          ' | Thread: ' + UIntToStr(GetCurrentThreadId) +
          ' | Correlacao: ' + Correlation + ' | Registro: ' + RecordID +
          ' | Endereco: ' + LogValue(AddressText);
        if E <> nil then
          Entry := Entry + ' | Erro: ' + V(MessageText) + sLineBreak
        else
          Entry := Entry + ' | Mensagem: ' + V(MessageText) + sLineBreak;
        Chain := '';
        Frame := CurrentFrame;
        while Frame <> nil do
        begin
          if Chain <> '' then
            Chain := ' -> ' + Chain;
          Chain := V(Frame.Origin) + '.' + V(Frame.EventName) +
            ' [' + V(Frame.HandlerName) + ']' + Chain;
          Frame := Frame.Parent;
        end;
        if Chain <> '' then
          Entry := Entry + '  Contexto: ' + Chain + sLineBreak;
        if DB <> nil then
          for I := 0 to DB.ErrorCount - 1 do
            Entry := Entry + Format('  Banco[%d]: Codigo=%d | Objeto=%s | Erro=%s',
              [I, DB.Errors[I].ErrorCode, V(DB.Errors[I].ObjName),
               V(DB.Errors[I].Message)]) + sLineBreak;
        Entry := Entry + '  StackTrace: ' + V(Trace) + sLineBreak;
        if TraceError <> '' then
          Entry := Entry + '  StackTraceErro: ' + V(TraceError) + sLineBreak;
      end;
      Bytes := TEncoding.UTF8.GetBytes(Entry);
      CleanupError := '';
      System.TMonitor.Enter(FileLock);
      try
        if not ForceDirectories(Directory) then
          raise EInOutError.Create('Nao foi possivel criar a pasta de logs: ' + Directory);
        DirectoryAttributes := GetFileAttributes(PChar(Directory));
        if DirectoryAttributes = INVALID_FILE_ATTRIBUTES then
          RaiseLastOSError;
        if DirectoryAttributes and FILE_ATTRIBUTE_REPARSE_POINT <> 0 then
          raise EInOutError.Create('A subpasta exclusiva do SkyLog nao pode ser um link: ' + Directory);
        AppendLog(Directory, 'skylog-' + FormatDateTime('yyyy-mm-dd', Stamp) +
          '_' + ProcessSession, Extension, Bytes, FMaxFileSizeMB, FileName);
        if CleanupLogs(Directory, Stamp, FRetentionDays, CleanupFile, CleanupError) then
          FLastCleanupError := MaskText(CleanupError);
      finally
        System.TMonitor.Exit(FileLock);
      end;
      FLastWriteError := '';
      if CleanupError <> '' then
      begin
        CleanupError := MaskText(CleanupError);
        OutputDebugString(PChar('SkyLog Cleanup: ' + CleanupError));
        if Assigned(FOnCleanupError) then
          try
            FOnCleanupError(Self, MaskText(CleanupFile), CleanupError);
          except
            // Maintenance and its notification never replace the original error.
          end;
      end;
    except
      on LogError: Exception do
      begin
        if Guard.Logger = nil then
          Exit;
        FLastWriteError := MaskText(LogError.ClassName + ': ' + LogError.Message);
        OutputDebugString(PChar('SkyLog: ' + FLastWriteError));
        if Assigned(FOnWriteError) then
          try
            FOnWriteError(Self, MaskText(FileName), FLastWriteError);
          except
            // A logging failure must never replace the application's exception.
          end;
      end;
    end;
  finally
    if Guard.Logger <> nil then
      Guard.Logger.FWriting := False;
    Guard.Free;
  end;
end;

procedure TSkyLog.Log(Level: TSkyLogLevel; const MessageText: string;
  Component: TComponent; const EventName: string);
begin
  if Component = nil then
    Component := MonitoredRoot;
  WriteRecord(Level, MessageText, nil, Component, EventName, '', 'Manual', nil);
end;

procedure TSkyLog.Debug(const MessageText: string; Component: TComponent);
begin
  Log(sllDebug, MessageText, Component);
end;

procedure TSkyLog.Info(const MessageText: string; Component: TComponent);
begin
  Log(sllInfo, MessageText, Component);
end;

procedure TSkyLog.Warning(const MessageText: string; Component: TComponent);
begin
  Log(sllWarning, MessageText, Component);
end;

procedure TSkyLog.Error(const MessageText: string; Component: TComponent);
begin
  Log(sllError, MessageText, Component);
end;

procedure TSkyLog.Fatal(const MessageText: string; Component: TComponent);
begin
  Log(sllFatal, MessageText, Component);
end;

procedure TSkyLog.LogException(E: Exception; Component: TComponent;
  const EventName, HandlerName: string);
var
  Address: Pointer;
begin
  if Component = nil then
    Component := MonitoredRoot;
  Address := nil;
  if (E <> nil) and (ExceptObject = E) then
    Address := ExceptAddr;
  WriteException(E, Component, EventName, HandlerName, 'Manual', Address);
end;

procedure TSkyLog.Execute(Component: TComponent; const EventName: string;
  const Action: TProc);
var
  Frame: TLogFrame;
  Guard: TSkyHook;
begin
  if GetCurrentThreadId <> MainThreadID then
    raise EInvalidOperation.Create('SkyLog.Execute deve executar na thread principal.');
  if not Assigned(Action) then
    raise EArgumentNilException.Create('Action');
  if Component = nil then
    Component := MonitoredRoot;
  if not OwnsComponent(Component) then
    raise EArgumentException.Create('O componente informado nao pertence ao escopo deste SkyLog.');
  Guard := TSkyHook.CreateHook(Self, Component);
  try
    EnterFrame(Frame, Component, EventName, '');
    try
      try
        Action();
        Frame.Failure := nil;
      except
        on E: Exception do
        begin
          if (Guard.Logger <> nil) and (Guard.Target <> nil) and
            (Frame.Failure <> E) then
            Guard.Logger.WriteException(E, Guard.Target, EventName, '', 'Operacao', ExceptAddr);
          Frame.Failure := E;
          raise;
        end;
      end;
    finally
      LeaveFrame(Frame);
    end;
  finally
    Guard.Free;
  end;
end;

initialization
  GroupDescendentsWith(TSkyLog, Vcl.Controls.TControl);
  RegisterClass(TSkyLog);
  RttiContext := TRttiContext.Create;
  FileLock := TObject.Create;
  FileParts := TDictionary<string, Integer>.Create;
  CleanupDates := TDictionary<string, TDateTime>.Create;

finalization
  UnRegisterClass(TSkyLog);
  Retirement.Free;
  CleanupDates.Free;
  FileParts.Free;
  FileLock.Free;
  RttiContext.Free;

end.
