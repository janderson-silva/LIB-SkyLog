unit SkyLog.Register;

interface

procedure Register;

implementation

uses
  System.Classes, SkyLog;

procedure Register;
begin
  RegisterComponents('SkyLog', [TSkyLog]);
end;

end.
