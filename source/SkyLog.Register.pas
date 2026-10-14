unit SkyLog.Register;

interface

procedure Register;

implementation

uses
  System.Classes, SkyLog;

{$R '..\resources\SkyLogIcons.dcr'}

procedure Register;
begin
  RegisterComponents('SkyLog', [TSkyLog]);
end;

end.
