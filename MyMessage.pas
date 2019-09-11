unit MyMessage;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls;

type
  TMessageForm = class(TForm)
    Label1: TLabel;
    Button1: TButton;
    Timer1: TTimer;
    procedure Button1Click(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  MessageForm: TMessageForm;

implementation

{$R *.dfm}

procedure TMessageForm.Button1Click(Sender: TObject);
begin
Close;
end;

procedure TMessageForm.FormActivate(Sender: TObject);
begin
Timer1.Enabled:=true;
end;

procedure TMessageForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
Timer1.Enabled:=false;
end;

procedure TMessageForm.FormCreate(Sender: TObject);
begin
Timer1.Enabled:=false;
end;

procedure TMessageForm.Timer1Timer(Sender: TObject);
begin
Label1.Caption:='Hawk!';
 if Visible then
     Close;
end;

end.
