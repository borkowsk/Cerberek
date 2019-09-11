program CerberekProject;

uses
  Forms,
  Cerberek in 'Cerberek.pas' {MainForm},
  MyMessage in 'MyMessage.pas' {MessageForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TMessageForm, MessageForm);
  Application.Run;
end.
