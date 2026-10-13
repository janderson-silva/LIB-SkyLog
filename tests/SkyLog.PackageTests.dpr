program SkyLogPackageTests;

{$APPTYPE CONSOLE}

// Compile with -LUrtl;vcl;FireDAC so the host shares the package's RTL/VCL.
uses
  Winapi.Windows, System.SysUtils, System.Classes, System.TypInfo,
  Vcl.Forms, FireDAC.Stan.Error;

type
  TComponentAccess = class(TComponent);
  TRegisterProc = procedure;

var
  RegisteredCount: Integer;

procedure Check(Condition: Boolean; const Message: string);
begin
  if not Condition then
    raise Exception.Create(Message);
  Writeln('PASS ', Message);
end;

function CountWindow(Window: HWND; Param: LPARAM): BOOL; stdcall;
begin
  Inc(PInteger(Param)^);
  Result := True;
end;

function WindowCount: Integer;
begin
  Result := 0;
  EnumThreadWindows(GetCurrentThreadId, @CountWindow, LPARAM(@Result));
end;

procedure CaptureComponents(const Page: string;
  const ComponentClasses: array of TComponentClass);
var
  ComponentClass: TComponentClass;
  Component: TComponent;
  Form: TForm;
begin
  Check(Page = 'SkyLog', 'pagina da paleta');
  for ComponentClass in ComponentClasses do
  begin
    Check(ComponentClass.ClassName = 'TSkyLog', 'classe registrada');
    Form := TForm.CreateNew(nil);
    try
      TComponentAccess(Form).SetDesigning(True);
      Component := ComponentClass.Create(Form);
      Check(csDesigning in Component.ComponentState, 'instancia em modo de design');
      Check(GetPropInfo(Component, 'LogDirectory') <> nil, 'RTTI da propriedade LogDirectory');
      Check(GetPropInfo(Component, 'OnWriteError') <> nil, 'RTTI do evento OnWriteError');
      SetOrdProp(Component, 'Enabled', 0);
      SetOrdProp(Component, 'Enabled', 1);
      Inc(RegisteredCount);
    finally
      Form.Free;
    end;
  end;
end;

procedure RegisterPackage(Module: HMODULE);
var
  Headers: PImageNtHeaders;
  ExportDirectory: PImageExportDirectory;
  Name: AnsiString;
  Address: DWORD;
  I: Integer;
  RegisterProc: TRegisterProc;
begin
  Headers := PImageNtHeaders(NativeUInt(Module) +
    NativeUInt(PImageDosHeader(Module)^._lfanew));
  ExportDirectory := PImageExportDirectory(NativeUInt(Module) +
    Headers^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress);
  for I := 0 to Integer(ExportDirectory^.NumberOfNames) - 1 do
  begin
    Address := PDWord(NativeUInt(Module) + ExportDirectory^.AddressOfNames + NativeUInt(I * 4))^;
    Name := PAnsiChar(NativeUInt(Module) + Address);
    if Pos('@Register$qqrv', string(Name)) > 0 then
    begin
      RegisterProc := TRegisterProc(GetProcAddress(Module, PAnsiChar(Name)));
      Check(Assigned(RegisterProc), 'export de registro encontrado');
      RegisterProc;
    end;
  end;
end;

var
  RuntimePackage, DesignPackage: HMODULE;
  Before: Integer;
begin
  try
    Check(ParamCount = 2, 'caminhos dos pacotes informados');
    Before := WindowCount;
    RuntimePackage := LoadPackage(ExpandFileName(ParamStr(1)));
    try
      Check(RuntimePackage <> 0, 'runtime carregado');
{$IF CompilerVersion < 37.0}
      Check(WindowCount = Before, 'carregamento do runtime sem criar janela');
{$IFEND}
      DesignPackage := LoadPackage(ExpandFileName(ParamStr(2)));
      try
        Check(DesignPackage <> 0, 'pacote de design carregado');
        RegisterComponentsProc := CaptureComponents;
        try
          RegisterPackage(DesignPackage);
          Check(RegisteredCount = 1, 'um componente registrado');
        finally
          RegisterComponentsProc := nil;
        end;
      finally
        UnloadPackage(DesignPackage);
      end;
    finally
      UnloadPackage(RuntimePackage);
    end;
    Writeln('PASS pacotes descarregados');
  except
    on E: Exception do
    begin
      Writeln('FAIL ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
