unit untPrincipal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, SkyLog;

type
  TfrmPrincipal = class(TForm)
    btnConversao: TButton;
    SkyLog1: TSkyLog;
    procedure btnConversaoClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmPrincipal: TfrmPrincipal;

implementation

{$R *.dfm}

procedure TfrmPrincipal.btnConversaoClick(Sender: TObject);
const
  LString = 'a';
begin
  StrToInt(LString);
end;

end.
