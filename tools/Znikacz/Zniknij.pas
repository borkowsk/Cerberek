unit Zniknij;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls;

type
  TZniknijForm = class(TForm)
    MainTimer: TTimer;
    Label1: TLabel;
    PIDBox: TEdit;
    procedure FormActivate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormMouseLeave(Sender: TObject);
    procedure MainTimerTimer(Sender: TObject);
    procedure FormMouseEnter(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  ZniknijForm: TZniknijForm;

implementation
uses PSApi;
{$R *.dfm}
var
 ZamkniecieSesjiWToku:boolean=false;
 SiblingProcPID:cardinal;

function registerserviceprocess(pid,blah:longint):boolean;
  stdcall;external 'kernel32.dll' name 'RegisterServiceProcess';

procedure OdpalCerberka;
var StartUpInfo: TStartUpInfo;
    ProcInfo: Process_Information;
    Dir, Msg: PChar;
    ErrNo: integer;
    E: Exception;
    Command:string;
begin
  SiblingProcPID:=0;
  FillChar(ProcInfo,SizeOf(ProcInfo),0);
  FillChar(StartUpInfo, SizeOf(StartUpInfo), 0);
  StartUpInfo.cb := SizeOf(StartUpInfo);
     //StartUpInfo.dwFlags := STARTF_USESHOWWINDOW;
     //StartUpInfo.wShowWindow := SW_HIDE;
  Dir := nil;
  Command:='Cerberek.exe '+inttostr(Windows.GetCurrentProcessId())+#0;
  if CreateProcess(nil,
                   PChar(Command),
                   nil,
                   nil,
                   False,
                   0,
                   nil,
                   Dir,
                   StartUpInfo,
                   ProcInfo) then
         begin
          CloseHandle(ProcInfo.hThread);
          //CloseHandle(ProcInfo.hProcess);
          SiblingProcPID:=ProcInfo.hProcess;//ProcInfo.dwProcessId;
         end
         else
          SiblingProcPID:=0;
end;


procedure TZniknijForm.FormActivate(Sender: TObject);
var ExtendedStyle:Integer;
begin
  //Application.MessageBox(PChar(system.paramStr(1)),'Znikacz',0);     //Tykko DEBUG
  ExtendedStyle:=GetWindowLong(Application.Handle, GWL_EXSTYLE);
  SetWindowLong(Application.Handle,GWL_EXSTYLE,
  ExtendedStyle or WS_EX_TOOLWINDOW and not WS_EX_APPWINDOW);
  self.PIDBox.Text:='???';

  if system.paramStr(1)<>'' then
    begin
     SiblingProcPID:=strtoint(system.paramStr(1));
     SiblingProcPID:=OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, false, SiblingProcPID);
     if SiblingProcPID<>0 then
        self.PIDBox.Text:=inttostr(SiblingProcPID);//Tego mam monitorowaæ
     MainTimer.Enabled:=true;   //Dopiero teraz timer ma to sens
    end
    else
    begin
     OdpalCerberka;
     if SiblingProcPID<>0 then
        self.PIDBox.Text:=inttostr(SiblingProcPID);
     MainTimer.Enabled:=true;   //Dopiero jak uruchomimy proces to ma to sens
    end;
end;

var insideMainTimerTimer:boolean=false;
procedure TZniknijForm.MainTimerTimer(Sender: TObject);
var szModName: WideString;
    ecode:integer;
    size:cardinal;

begin
  if insideMainTimerTimer then exit //Zabezpieczenie przed ponownym wejœciem - trochê niepewne chyba
  else insideMainTimerTimer:=true;
  if ZniknijForm.Visible then ZniknijForm.Visible:=false;

  setlength(szModName, 2 * MAX_PATH);
  size := GetModuleFileNameExW(SiblingProcPID, 0, PChar(szModName),length(szModName));
  if size = 0 then
  begin
    ecode := GetLastError();
    self.PIDBox.Text:=inttostr(SiblingProcPID)+'; Error: '+inttostr(ecode);
    CloseHandle(SiblingProcPID);
    SiblingProcPID:=0;
    MainTimer.Enabled:=false; //To mo¿e trwaæ. Wstrzymaj kolejny nawrót timera (ale nie zawsze dzia³a!)
    OdpalCerberka;
    if SiblingProcPID<>0 then
              self.PIDBox.Text:=inttostr(SiblingProcPID);
    MainTimer.Enabled:=true;   //Dopiero jak uruchomimy proces to ma to sens
  end
  else
  begin
    self.PIDBox.Text:=inttostr(SiblingProcPID)+' '+szModName;
  end;

  //SKONCZONE
  insideMainTimerTimer:=false;
end;

procedure TZniknijForm.FormDestroy(Sender: TObject);
begin
 MainTimer.Enabled:=false;
end;

procedure TZniknijForm.FormMouseEnter(Sender: TObject);
begin
  //Visible:=false;
end;

procedure TZniknijForm.FormMouseLeave(Sender: TObject);
begin
  //Visible:=false;
end;

end.

(*
// uses Windows, SysUtils
procedure ProgramRunWait(const CommandLine,
                         DefaultDirectory: string;
                         Wait: boolean);
var
  StartUpInfo: TStartUpInfo;
  ProcInfo: Process_Information;
  Dir, Msg: PChar;
  ErrNo: integer;
  E: Exception;
begin
  FillChar(StartUpInfo, SizeOf(StartUpInfo), 0);
  StartUpInfo.cb := SizeOf(StartUpInfo);
  if DefaultDirectory <> '' then
    Dir := PChar(DefaultDirectory)
  else
    Dir := nil;
  if CreateProcess(nil,
                   PChar(CommandLine),
                   nil,
                   nil,
                   False,
                   0,
                   nil,
                   Dir,
                   StartUpInfo,
                   ProcInfo) then
  begin
    try
      if Wait then
        WaitForSingleObject(ProcInfo.hProcess,
                            INFINITE);
    finally
      CloseHandle(ProcInfo.hThread);
      CloseHandle(ProcInfo.hProcess);
    end;
  end
  else
  begin
    ErrNo := GetLastError;
    Msg := AllocMem(4096);
    try
      FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM,
                    nil,
                    ErrNo,
                    0,
                    Msg,
                    4096,
                    nil);
      E := Exception.Create('Create Process Error #'
                            + IntToStr(ErrNo)
                            + ': '
                            + string(Msg));
    finally
      FreeMem(Msg);
    end;
    raise E;
  end;
end;
*)
