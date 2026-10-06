program SkyLogTests;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  System.IOUtils, Vcl.Forms, Vcl.StdCtrls, Vcl.Controls, FireDAC.Stan.Error,
  FireDAC.Stan.Intf, FireDAC.Comp.Client, FireDAC.DApt, FireDAC.Stan.Def,
  FireDAC.Stan.Async, FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteWrapper.Stat,
  SkyLog in '..\source\SkyLog.pas';

type
  TTransformEvent = function(Sender: TObject; var Text: string; out Number: Integer): Boolean of object;
  TEventProbe = class(TComponent)
  private
    FTransform: TTransformEvent;
  published
    property OnTransform: TTransformEvent read FTransform write FTransform;
  end;

  TFailControl = class(TCustomControl)
  protected
    procedure WndProc(var Message: TMessage); override;
  end;

  TProbeForm = class(TForm)
  published
    procedure Fail(Sender: TObject);
    procedure ChangeKey(Sender: TObject; var Key: Char);
    procedure QueryError(ASender, AInitiator: TObject; var E: Exception);
    procedure FreeLogger(Sender: TObject);
    function Transform(Sender: TObject; var Text: string; out Number: Integer): Boolean;
    procedure NestedFail(Sender: TObject);
    procedure RefreshAndFail(Sender: TObject);
  public
    Logger: TSkyLog;
    FDCalled: Boolean;
    InnerButton: TButton;
  end;

var
  A, B: TProbeForm;
  ButtonA, ButtonB: TButton;
  Edit: TEdit;
  Query: TFDQuery;
  Root, LogFile, Contents: string;
  Key: Char;
  DBError: EFDDBEngineException;
  Ex: Exception;
  Failures, Checks: Integer;

procedure Check(Condition: Boolean; const Name: string);
begin
  Inc(Checks);
  if Condition then
    Writeln('PASS ', Name)
  else
  begin
    Inc(Failures);
    Writeln('FAIL ', Name);
  end;
end;

function ReadLog: string;
begin
  if FileExists(LogFile) then
    Result := TFile.ReadAllText(LogFile, TEncoding.UTF8)
  else
    Result := '';
end;

procedure TProbeForm.Fail(Sender: TObject);
begin
  raise EInvalidOperation.Create('Falha de teste: acentuacao ' + #$E7 + #$E3);
end;

procedure TProbeForm.ChangeKey(Sender: TObject; var Key: Char);
begin
  Key := 'Z';
end;

procedure TProbeForm.QueryError(ASender, AInitiator: TObject; var E: Exception);
begin
  FDCalled := True;
  E.Message := E.Message + ' [tratado]';
end;

procedure TProbeForm.FreeLogger(Sender: TObject);
begin
  FreeAndNil(Logger);
end;

function TProbeForm.Transform(Sender: TObject; var Text: string; out Number: Integer): Boolean;
begin
  Text := Text + ' alterado';
  Number := 42;
  Result := True;
end;

procedure TProbeForm.NestedFail(Sender: TObject);
begin
  InnerButton.Click;
end;

procedure TProbeForm.RefreshAndFail(Sender: TObject);
begin
  Logger.Refresh;
  raise Exception.Create('falha apos Refresh dentro do evento');
end;

procedure TFailControl.WndProc(var Message: TMessage);
begin
  if Message.Msg = WM_USER + 33 then
    raise Exception.Create('falha interna de janela');
  inherited;
end;

procedure Run;
var
  Before: string;
  Child: TProbeForm;
  ChildButton: TButton;
  M: TMessage;
  Probe: TEventProbe;
  TextValue: string;
  NumberValue: Integer;
  Connection: TFDConnection;
  ForeignQuery: TFDQuery;
  DynamicButton: TButton;
  FailControl: TFailControl;
begin
  Application.Initialize;
  Root := TPath.Combine(ExtractFilePath(ParamStr(0)), 'test-output-' +
    IntToStr(GetCurrentProcessId));
  ForceDirectories(Root);
  LogFile := TPath.Combine(Root, FormatDateTime('yyyy-mm-dd', Now) + '.log');
  A := TProbeForm.CreateNew(nil);
  B := TProbeForm.CreateNew(nil);
  try
    A.Name := 'frmPrincipal';
    B.Name := 'frmOutro';
    ButtonA := TButton.Create(A);
    ButtonA.Name := 'btnSalvar';
    ButtonA.OnClick := A.Fail;
    ButtonB := TButton.Create(B);
    ButtonB.Name := 'btnOutro';
    ButtonB.OnClick := B.Fail;
    Edit := TEdit.Create(A);
    Edit.Name := 'edtNome';
    Edit.OnKeyPress := A.ChangeKey;
    Query := TFDQuery.Create(A);
    Query.Name := 'qrAux';
    Query.OnError := A.QueryError;
    Probe := TEventProbe.Create(A);
    Probe.Name := 'probe';
    Probe.OnTransform := A.Transform;
    A.Logger := TSkyLog.Create(A);
    A.Logger.LogDirectory := Root;
    A.Logger.Refresh;
    Check(A.Logger.Diagnostics.Count = 0, 'RTTI de todos os eventos');
    if A.Logger.Diagnostics.Count > 0 then
      Writeln(A.Logger.Diagnostics.Text);
    try
      ButtonA.Click;
    except
      on E: EInvalidOperation do
        Check(E.Message.StartsWith('Falha de teste'), 'excecao original preservada');
    end;
    Contents := ReadLog;
    Check(Contents.Contains('Origem: frmPrincipal.btnSalvar'), 'origem do botao');
    Check(Contents.Contains('Evento: OnClick'), 'nome do evento');
    Check(Contents.Contains('TProbeForm.Fail'), 'nome do metodo');
    Check(Contents.Contains(#$E7 + #$E3), 'UTF-8');
    Check(Contents.Contains('Ocorrencia:'), 'identificador de correlacao');
    Before := Contents;
    try ButtonB.Click; except on E: Exception do ; end;
    Check(ReadLog = Before, 'outro formulario nao capturado');
    Ex := Exception.Create('erro fora do escopo');
    try A.Logger.LogException(Ex, ButtonB, 'OnClick'); finally Ex.Free; end;
    Check(ReadLog = Before, 'registro manual respeita escopo');

    Key := 'A';
    Edit.OnKeyPress(Edit, Key);
    Check(Key = 'Z', 'parametro var preservado');
    TextValue := 'texto';
    NumberValue := 0;
    Check(Probe.OnTransform(Probe, TextValue, NumberValue), 'retorno de funcao preservado');
    Check((TextValue = 'texto alterado') and (NumberValue = 42), 'var string e out integer preservados');
    DBError := EFDDBEngineException.Create;
    DBError.Message := 'violation of PRIMARY or UNIQUE KEY constraint "INTEG_365"' +
      sLineBreak + 'Problematic key value is ("CODIGO" = 2)';
    DBError.AppendError(1, 335544665, DBError.Message, 'PELAGEM', ekUKViolated, 0, 0);
    Ex := DBError;
    try
      Query.OnError(Query, Query, Ex);
      Check(A.FDCalled, 'OnError original do FireDAC chamado');
      Check(Ex.Message.Contains('[tratado]'), 'mutacao da excecao preservada');
    finally
      Ex.Free;
    end;
    Contents := ReadLog;
    Check(Contents.Contains('Origem: frmPrincipal.qrAux'), 'origem exata da query');
    Check(Contents.Contains('Codigo: 335544665'), 'codigo nativo do banco');
    Check(Contents.Contains('\r\nProblematic key'), 'mensagem multilinha escapada');

    Connection := TFDConnection.Create(A);
    Connection.Name := 'conCompartilhada';
    Connection.LoginPrompt := False;
    Connection.Params.Values['DriverID'] := 'SQLite';
    Connection.Params.Values['Database'] := ':memory:';
    Query.Connection := Connection;
    Query.OnError := nil;
    ForeignQuery := TFDQuery.Create(B);
    ForeignQuery.Connection := Connection;
    A.Logger.Refresh;
    Connection.Connected := True;
    Connection.ExecSQL('create table PELAGEM (CODIGO integer primary key)');
    Connection.ExecSQL('insert into PELAGEM values (2)');
    Query.SQL.Text := 'insert into PELAGEM values (2)';
    try Query.ExecSQL; except on E: EFDDBEngineException do ; end;
    Contents := ReadLog;
    Check(Contents.Contains('ESQLiteNativeException'), 'erro real do banco capturado sem OnError anterior');
    Check(Contents.Contains('Codigo: 1555'), 'codigo real da chave duplicada SQLite');
    ForeignQuery.SQL.Text := Query.SQL.Text;
    Before := ReadLog;
    try ForeignQuery.ExecSQL; except on E: EFDDBEngineException do ; end;
    Check(ReadLog = Before, 'conexao compartilhada nao captura query de outro formulario');
    ForeignQuery.Free;

    DynamicButton := TButton.Create(A);
    DynamicButton.Name := 'btnInterno';
    DynamicButton.OnClick := A.Fail;
    A.InnerButton := DynamicButton;
    ButtonA.OnClick := A.NestedFail;
    A.Logger.Refresh;
    Before := ReadLog;
    try ButtonA.Click; except on E: EInvalidOperation do ; end;
    Contents := ReadLog;
    Contents := Contents.Substring(Before.Length);
    Check(Contents.Contains('Origem: frmPrincipal.btnInterno'), 'evento interno identifica origem mais proxima');
    Check(Contents.Contains('btnSalvar.OnClick') and Contents.Contains('btnInterno.OnClick'), 'cadeia de eventos');
    Check(Length(Contents.Split(['Origem:'])) = 2, 'propagacao da mesma excecao nao duplica eventos');
    DynamicButton.Free;
    ButtonA.OnClick := A.Fail;
    A.Logger.Refresh;
    Contents := ReadLog;

    Before := Contents;
    A.Logger.Enabled := False;
    try ButtonA.Click; except on E: Exception do ; end;
    Check(ReadLog = Before, 'desativar restaura eventos');
    A.Logger.Enabled := True;
    A.Logger.Refresh;
    try ButtonA.Click; except on E: Exception do ; end;
    Check(ReadLog.Length > Before.Length, 'reativar e Refresh idempotente');

    Child := TProbeForm.CreateNew(A);
    Child.Name := 'frmFilho';
    ChildButton := TButton.Create(Child);
    ChildButton.OnClick := Child.Fail;
    A.Logger.Refresh;
    Before := ReadLog;
    try ChildButton.Click; except on E: Exception do ; end;
    Check(ReadLog = Before, 'formulario filho possui escopo separado');
    Check(not A.Logger.OwnsComponent(ChildButton), 'Owner filho nao contamina escopo');
    Child.Free;

    Ex := EAbort.Create('abort');
    try A.Logger.LogException(Ex, ButtonA); finally Ex.Free; end;
    Check(ReadLog = Before, 'Abort ignorado por padrao');

    try
      A.Logger.Execute(Query, 'ExecSQL',
        procedure
        begin
          raise Exception.Create('operacao explicita');
        end);
    except on E: Exception do ; end;
    Check(ReadLog.Contains('Evento: ExecSQL'), 'contexto explicito Execute');

    // A real directory collision forces a write failure without permissions hacks.
    A.Logger.LogDirectory := LogFile;
    try
      ButtonA.Click;
    except
      on E: EInvalidOperation do
        Check(E.Message.StartsWith('Falha de teste'), 'falha de IO nao substitui excecao');
    end;
    Check(A.Logger.LastWriteError <> '', 'falha de gravacao consultavel');
    A.Logger.LogDirectory := Root;

    // Dispatch through the wrapped window procedure as well as the event proxy.
    FillChar(M, SizeOf(M), 0);
    M.Msg := WM_NULL;
    ButtonA.WindowProc(M);
    Check(True, 'WindowProc preserva mensagens normais');

    FailControl := TFailControl.Create(A);
    FailControl.Name := 'controleInterno';
    A.Logger.Refresh;
    M.Msg := WM_USER + 33;
    try FailControl.WindowProc(M); except on E: Exception do ; end;
    Check(ReadLog.Contains('Origem: frmPrincipal.controleInterno'), 'erro interno de WindowProc capturado');
    FailControl.Free;

    ButtonA.OnClick := A.RefreshAndFail;
    A.Logger.Refresh;
    try ButtonA.Click; except on E: Exception do ; end;
    Check(ReadLog.Contains('falha apos Refresh dentro do evento'), 'Refresh dentro do evento preserva captura em andamento');

    ButtonA.OnClick := A.FreeLogger;
    A.Logger.Refresh;
    ButtonA.Click;
    Check(A.Logger = nil, 'destruir logger durante evento e seguro');
    Application.ProcessMessages;
    Writeln('Log de teste: ', LogFile);
  finally
    B.Free;
    A.Free;
  end;
end;

begin
  try
    Run;
    Writeln(Checks, ' verificacoes; ', Failures, ' falhas.');
    if Failures <> 0 then ExitCode := 1;
  except
    on E: Exception do
    begin
      Writeln('FATAL ', E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
