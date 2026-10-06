unit Demo.Main;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Forms, Vcl.Controls,
  Vcl.StdCtrls, FireDAC.Comp.Client, FireDAC.Stan.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Async, FireDAC.DApt, FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteWrapper.Stat, FireDAC.VCLUI.Wait, SkyLog;

type
  TfrmPrincipal = class(TForm)
    lblInfo: TLabel;
    btnErro: TButton;
    btnBanco: TButton;
    btnOutro: TButton;
    SkyLog1: TSkyLog;
    procedure FormCreate(Sender: TObject);
    procedure ErroClick(Sender: TObject);
    procedure BancoClick(Sender: TObject);
    procedure OutroClick(Sender: TObject);
  private
    Connection: TFDConnection;
    qrAux: TFDQuery;
  end;

implementation

{$R *.dfm}

procedure TfrmPrincipal.FormCreate(Sender: TObject);
begin
  // LogDirectory also accepts an absolute directory configured in the DFM.
  Connection := TFDConnection.Create(Self);
  Connection.Name := 'conBanco';
  Connection.LoginPrompt := False;
  Connection.Params.Values['DriverID'] := 'SQLite';
  Connection.Params.Values['Database'] := ':memory:';
  qrAux := TFDQuery.Create(Self);
  qrAux.Name := 'qrAux';
  qrAux.Connection := Connection;
  // Dynamic components/events must be registered after their configuration.
  SkyLog1.Refresh;
  Connection.Connected := True;
  Connection.ExecSQL('create table PELAGEM (CODIGO integer primary key, NOME varchar(80))');
  Connection.ExecSQL('insert into PELAGEM values (2, ''Curta'')');
  lblInfo.Caption := 'SkyLog: erros deste formulario em logs\yyyy-mm-dd.log.' + sLineBreak +
    'O banco de demonstracao e SQLite em memoria, sem servidor externo.';
end;

procedure TfrmPrincipal.ErroClick(Sender: TObject);
begin
  raise EInvalidOperation.Create('Exemplo de erro no evento ErroClick.');
end;

procedure TfrmPrincipal.BancoClick(Sender: TObject);
begin
  qrAux.SQL.Text := 'insert into PELAGEM values (2, ''Duplicada'')';
  qrAux.ExecSQL;
end;

procedure TfrmPrincipal.OutroClick(Sender: TObject);
var
  Other: TfrmPrincipal;
begin
  Other := TfrmPrincipal.Create(Self);
  try
    Other.Name := 'frmSemSkyLog';
    Other.Caption := 'Outro formulario - SkyLog desativado';
    Other.SkyLog1.Enabled := False;
    Other.btnOutro.Visible := False;
    Other.lblInfo.Caption := 'Os erros aqui nao sao registrados pelo SkyLog do formulario principal.';
    Other.ShowModal;
  finally
    Other.Free;
  end;
end;

end.
