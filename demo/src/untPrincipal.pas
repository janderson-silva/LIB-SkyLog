unit untPrincipal;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, SkyLog;

type
  TfrmPrincipal = class(TForm)
    btnConversao: TButton;
    SkyLog1: TSkyLog;
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
  end;

var
  frmPrincipal: TfrmPrincipal;

implementation

uses
  Winapi.ShellAPI, System.IOUtils;

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

end.
