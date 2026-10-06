program SkyLogDemo;

{$IFDEF SMOKE_CONSOLE}
{$APPTYPE CONSOLE}
{$ENDIF}

uses
  System.SysUtils, System.Classes, System.IOUtils, FireDAC.Stan.Error,
  Vcl.Forms,
  SkyLog in '..\source\SkyLog.pas',
  Demo.Main in 'Demo.Main.pas' {frmPrincipal};

type
  TSmokeErrors = class
    procedure OnException(Sender: TObject; E: Exception);
  end;

procedure TSmokeErrors.OnException(Sender: TObject; E: Exception);
begin
  TFile.AppendAllText(ExtractFilePath(ParamStr(0)) + 'smoke-errors.txt',
    E.ClassName + ': ' + E.Message + sLineBreak, TEncoding.UTF8);
  ExitCode := 1;
end;

var
  MainForm: TfrmPrincipal;
  SmokeErrors: TSmokeErrors;
  LogFile, Captured: string;
  LogStart: Integer;

begin
  Application.Initialize;
  SmokeErrors := nil;
  if FindCmdLineSwitch('smoke') then
  begin
    TFile.WriteAllText(ExtractFilePath(ParamStr(0)) + 'smoke-errors.txt', '', TEncoding.UTF8);
    SmokeErrors := TSmokeErrors.Create;
    Application.OnException := SmokeErrors.OnException;
  end;
  try
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmPrincipal, MainForm);
  if FindCmdLineSwitch('smoke') then
  begin
    LogFile := ExtractFilePath(ParamStr(0)) + 'logs\' + FormatDateTime('yyyy-mm-dd', Now) + '.log';
    LogStart := 0;
    if FileExists(LogFile) then
      LogStart := TFile.ReadAllText(LogFile, TEncoding.UTF8).Length;
    try MainForm.btnErro.Click; except on E: Exception do ; end;
    try MainForm.btnBanco.Click; except on E: EFDDBEngineException do ; end;
    Captured := TFile.ReadAllText(LogFile, TEncoding.UTF8);
    Captured := Captured.Substring(LogStart);
    if not Captured.Contains('Origem: frmPrincipal.btnErro') or
      not Captured.Contains('Origem: frmPrincipal.qrAux') or
      not Captured.Contains('Codigo: 1555') then
      raise Exception.Create('Smoke: log dos eventos DFM ou erro real do banco ausente.');
    if MainForm.SkyLog1.Diagnostics.Count > 0 then
      ExitCode := 1;
    MainForm.Free;
  end
  else
    Application.Run;
  except
    on E: Exception do
      if SmokeErrors <> nil then
        SmokeErrors.OnException(nil, E)
      else
        raise;
  end;
  Application.OnException := nil;
  SmokeErrors.Free;
end.
