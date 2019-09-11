program Znikacz;

uses
  Forms,
  Zniknij in 'Zniknij.pas' {ZniknijForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'SelfControl';
  Application.CreateForm(TZniknijForm, ZniknijForm);
  Application.Run;
end.
