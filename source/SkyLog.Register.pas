unit SkyLog.Register;

interface

procedure Register;

implementation

uses
  System.Classes, DesignIntf, SkyLog;

{$R '..\resources\SkyLogIcons.dcr'}

procedure Register;
begin
  // Keep this small design package loaded: the form reader must be able to
  // resolve TSkyLog even before the first component is dropped on a form.
  ForceDemandLoadState(dlDisable);
  RegisterComponents('SkyLog', [TSkyLog]);
end;

end.
