unit untPrincipal;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, FireDAC.Comp.UI, SkyLog,
  FireDAC.UI.Intf, FireDAC.VCLUI.Wait, FireDAC.Stan.Intf,   Winapi.ShellAPI, System.IOUtils, FireDAC.Comp.Client,
  FireDAC.Stan.Def, FireDAC.Stan.Async, FireDAC.DApt,
  FireDAC.Phys.SQLite
{$IF CompilerVersion >= 36.0}
  , FireDAC.Phys.SQLiteWrapper.Stat
{$IFEND}
  ;

type
  TfrmPrincipal = class(TForm)
    btnConversao: TButton;
    SkyLog1: TSkyLog;
    FDGUIxWaitCursor1: TFDGUIxWaitCursor;
    pagCenarios: TPageControl;
    tabGerais: TTabSheet;
    tabBanco: TTabSheet;
    tabSensivel: TTabSheet;
    lblBanco: TLabel;
    lblSensivel: TLabel;
    btnSQL: TButton;
    btnTabela: TButton;
    btnDuplicado: TButton;
    btnObrigatorio: TButton;
    btnBancoSensivel: TButton;
    btnSensivelTexto: TButton;
    btnSensivelJSON: TButton;
    btnSensivelLiteral: TButton;
    pnlHeader: TPanel;
    lblTitle: TLabel;
    lblSubtitle: TLabel;
    grpErrors: TGroupBox;
    lblInstructions: TLabel;
    btnDivisao: TButton;
    btnLista: TButton;
    btnData: TButton;
    btnNegocio: TButton;
    btnTratado: TButton;
    grpLogs: TGroupBox;
    lblLogs: TLabel;
    btnAbrirLogs: TButton;
    lblDebugger: TLabel;
    procedure btnConversaoClick(Sender: TObject);
    procedure btnDivisaoClick(Sender: TObject);
    procedure btnListaClick(Sender: TObject);
    procedure btnDataClick(Sender: TObject);
    procedure btnNegocioClick(Sender: TObject);
    procedure btnTratadoClick(Sender: TObject);
    procedure btnAbrirLogsClick(Sender: TObject);
    procedure btnSQLClick(Sender: TObject);
    procedure btnTabelaClick(Sender: TObject);
    procedure btnDuplicadoClick(Sender: TObject);
    procedure btnObrigatorioClick(Sender: TObject);
    procedure btnBancoSensivelClick(Sender: TObject);
    procedure btnSensivelTextoClick(Sender: TObject);
    procedure btnSensivelJSONClick(Sender: TObject);
    procedure btnSensivelLiteralClick(Sender: TObject);
  private
    procedure ExecutarErroBanco(const SQL: string);
  end;

var
  frmPrincipal: TfrmPrincipal;

implementation

{$R *.dfm}

procedure TfrmPrincipal.btnConversaoClick(Sender: TObject);
begin
  StrToInt('a');
end;

procedure TfrmPrincipal.btnDivisaoClick(Sender: TObject);
var
  Divisor: Integer;
begin
  Divisor := StrToInt('0');
  ShowMessage(IntToStr(10 div Divisor));
end;

procedure TfrmPrincipal.btnListaClick(Sender: TObject);
var
  Lista: TStringList;
begin
  Lista := TStringList.Create;
  try
    Lista.Add('Primeiro item');
    ShowMessage(Lista[5]);
  finally
    Lista.Free;
  end;
end;

procedure TfrmPrincipal.btnDataClick(Sender: TObject);
begin
  ShowMessage(DateToStr(EncodeDate(2026, 2, 30)));
end;

procedure TfrmPrincipal.btnNegocioClick(Sender: TObject);
begin
  raise EInvalidOperation.Create(
    'DemoSkyLog: pedido nao pode ser concluido sem itens.');
end;

procedure TfrmPrincipal.btnTratadoClick(Sender: TObject);
begin
  // Excecoes consumidas pelo except precisam de registro explicito.
  try
    raise Exception.Create('DemoSkyLog: falha tratada e registrada manualmente.');
  except
    on E: Exception do
      SkyLog1.LogException(E, btnTratado, 'OnClick', 'btnTratadoClick');
  end;
  if SkyLog1.LastWriteError <> '' then
    ShowMessage('Falha ao gravar o log: ' + SkyLog1.LastWriteError)
  else
    ShowMessage('Excecao tratada. Consulte o registro na pasta de logs.');
end;

procedure TfrmPrincipal.btnAbrirLogsClick(Sender: TObject);
var
  Pasta: string;
begin
  Pasta := SkyLog1.LogDirectory;
  if Pasta = '' then
    Pasta := 'logs';
  if not TPath.IsPathRooted(Pasta) then
    Pasta := TPath.Combine(ExtractFilePath(ParamStr(0)), Pasta);
  Pasta := ExpandFileName(Pasta);
  if not DirectoryExists(Pasta) then
  begin
    ShowMessage('A pasta de logs ainda nao existe. Execute um teste primeiro.');
    Exit;
  end;
  if NativeInt(ShellExecute(Handle, 'open', PChar(Pasta), nil, nil,
    SW_SHOWNORMAL)) <= 32 then
    ShowMessage('Nao foi possivel abrir a pasta: ' + Pasta);
end;


procedure TfrmPrincipal.ExecutarErroBanco(const SQL: string);
var
  Conexao: TFDConnection;
begin
  // Banco isolado por clique: nenhum arquivo ou servidor e alterado.
  Conexao := TFDConnection.Create(nil);
  try
    Conexao.LoginPrompt := False;
    Conexao.Params.Values['DriverID'] := 'SQLite';
    Conexao.Params.Values['Database'] := ':memory:';
    Conexao.Connected := True;
    Conexao.ExecSQL('CREATE TABLE clientes (id INTEGER PRIMARY KEY, nome TEXT NOT NULL)');
    Conexao.ExecSQL('INSERT INTO clientes (id, nome) VALUES (1, ''Cliente Demo'')');
    Conexao.ExecSQL(SQL);
  finally
    Conexao.Free;
  end;
end;

procedure TfrmPrincipal.btnSQLClick(Sender: TObject);
begin
  ExecutarErroBanco('SELEC id FROM clientes');
end;

procedure TfrmPrincipal.btnTabelaClick(Sender: TObject);
begin
  ExecutarErroBanco('SELECT * FROM tabela_inexistente');
end;

procedure TfrmPrincipal.btnDuplicadoClick(Sender: TObject);
begin
  ExecutarErroBanco('INSERT INTO clientes (id, nome) VALUES (1, ''Duplicado'')');
end;

procedure TfrmPrincipal.btnObrigatorioClick(Sender: TObject);
begin
  ExecutarErroBanco('INSERT INTO clientes (id, nome) VALUES (2, NULL)');
end;

procedure TfrmPrincipal.btnBancoSensivelClick(Sender: TObject);
var
  Conexao: TFDConnection;
begin
  Conexao := TFDConnection.Create(nil);
  try
    Conexao.LoginPrompt := False;
    Conexao.Params.Values['DriverID'] := 'SQLite';
    Conexao.Params.Values['Database'] := ':memory:';
    Conexao.Connected := True;
    Conexao.ExecSQL('CREATE TABLE autenticacao (id INTEGER)');
    // Trigger gera uma excecao real do driver com credenciais ficticias.
    Conexao.ExecSQL('CREATE TRIGGER negar_acesso BEFORE INSERT ON autenticacao ' +
      'BEGIN SELECT RAISE(ABORT, ''password=SenhaDemo!2026; token=token-demo-xyz''); END');
    Conexao.ExecSQL('INSERT INTO autenticacao VALUES (1)');
  finally
    Conexao.Free;
  end;
end;

procedure TfrmPrincipal.btnSensivelTextoClick(Sender: TObject);
begin
  raise Exception.Create('Dados FICTICIOS: senha=SenhaDemo!2026; ' +
    'token=token-demo-xyz; cpf=000.000.000-00; card_number=4111111111111111; cvv=000');
end;

procedure TfrmPrincipal.btnSensivelJSONClick(Sender: TObject);
begin
  raise Exception.Create('{"cenario":"Dados ficticios","usuario":{"password":' +
    '"SenhaDemo!2026","cpf":"000.000.000-00"},"token":"token-demo-xyz",' +
    '"card_number":"4111111111111111","cvv":"000"}');
end;

procedure TfrmPrincipal.btnSensivelLiteralClick(Sender: TObject);
begin
  // Valores conhecidos tambem sao mascarados sem chave como senha= ou token=.
  raise Exception.Create('Credencial ficticia recebida: segredo-literal-demo-2026');
end;

end.
