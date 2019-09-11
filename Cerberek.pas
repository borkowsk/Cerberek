unit Cerberek;

interface

uses
  Windows, PSApi, Messages, SysUtils, Variants, Classes, Graphics, Controls,
  Forms,
  Dialogs, StdCtrls, ExtCtrls, MMSystem,ShellAPI;

type
  TMainForm = class(TForm)
    ZalogowanyLabel: TLabel;
    Wyloguj: TButton;
    Zablokuj: TButton;
    Zmien: TButton;
    Historia: TLabel;
    Timer1: TTimer;
    Czas: TLabel;
    Aktywny: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure WylogujClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure ZablokujClick(Sender: TObject);
    procedure ZmienClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure FormMouseEnter(Sender: TObject);
    procedure FormMouseLeave(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ZalogowanyLabelClick(Sender: TObject);
    procedure WylogujMouseEnter(Sender: TObject);
    // procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
    function ScreenSaverEnable: bool;
    function ScreenSaverTimeOut: Integer;
    function SecondsIdle: DWord;
    function ScreenSaverRunning: bool;
    function WithWindowActive: Integer;
    procedure WndProc(var Message: TMessage);override;

  public
    { Public declarations }
    TimeCount: LongWord;
    AcveCount: LongWord;
    StartTime: TDateTime;
    LastTime: TDateTime;
    CurrTOSVersionInfo:TOSVersionInfo;
  end;

var
  MainForm: TMainForm;

implementation
   uses MyMessage;
{$R *.dfm}
  type prog_action=record
                    pattern:string;
                    action:integer;
                   end;
var
  Title:String='^*o*^ ^*o*^';
  CompleteTitle:String='';
  Witaj:String = 'Witaj.wav';
  Przerwa: String = 'Przerwa.wav';//'Przerwa.wma';//'C:\WINDOWS\MEDIA\TADA.WAV';
  Koniec:String = 'Koniec.wav';//'C:\WINDOWS\MEDIA\notify.wav';//'TADA.WAV';////'Windows Logoff Sound.wav';
  LogFile: Text;
  DataFile: Text;
  LimitFile: Text;
  Restrictions: Text;

  DefaultLimit:integer=3600*7;//Ile godzin aktywnoœci tygodniowo
  DniLimitu:integer=7; //Co ile dni reset limitu
  SwitchUser: String = 'tsdiscon.exe'; //tsdiscon.exe
  staranazwa: string = 'cerberek start';   //Stara nazwa okna
  staryexec: string = 'cerberek start';    //Stara nazwa execa
  TimeStamp: LongWord = 0;
  ActiStamp: LongWord = 0;
  lastIOError: string = ''; // Na b³êdy wejœcia wyjœcia, których siê nie da zapisaæ do logu w danej chwili
  lastIOCode:integer=0;
  SiblingProcPID:cardinal; //PID znikacza-pilnowacza
  ZamkniecieSesjiWToku:boolean=false;

  exerestrictions:array[1..100] of prog_action;
  exeresnum:word=0;
  winrestrictions:array[1..100] of prog_action;
  winresnum:word=0;

function DajRestrykcje(const sciezka:string;CzyOkno:boolean):integer;
var i:integer;
begin
if CzyOkno then
 begin
 for i := 1 to winresnum do
   if Pos(winrestrictions[i].pattern,sciezka)<>0 then
          begin
            result:=winrestrictions[i].action;
            exit;
          end;
  end
  else
  begin
  for i := 1 to exeresnum do
   if Pos(exerestrictions[i].pattern,sciezka)<>0 then
          begin
            result:=exerestrictions[i].action;
            exit;
          end;
  end;
  DajRestrykcje:=0;
end;

procedure LoadRestrictions(var ResFile:Text);
var typ,dummy1,dummy2:char;
    akcja:string[5];
    patern:string;
    function Decode(const name:string):integer;
    begin
    if name='MINIM' then Decode:=WM_SYSCOMMAND else
    if name='CLOSE' then Decode:=WM_CLOSE else
    if name='DESTR' then Decode:=WM_DESTROY else
    if name='_QUIT' then Decode:=WM_QUIT else
    if name='_KILL' then Decode:=-9 else
    Decode:=strtoint(name);
    end;
begin
  while not eof(ResFile) do
   begin
    readln(ResFile,typ,dummy1,akcja,dummy2,patern);
    if dummy1<>dummy2 then
        begin
          ShowMessage('B³êdna linia dla '+patern);
          halt;
        end;
    if typ='W' then
      begin
        inc(winresnum);
        winrestrictions[winresnum].pattern:=patern;
        winrestrictions[winresnum].action:=Decode(akcja);
      end
      else
      begin
        inc(exeresnum);
        exerestrictions[exeresnum].pattern:=patern;
        exerestrictions[exeresnum].action:=Decode(akcja);
      end;
   end;
end;



function StringSystemError(Error: LongWord): string;
var
  lpMsgBuf: PChar;
  i: word;
begin
  FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_FROM_SYSTEM or
      FORMAT_MESSAGE_IGNORE_INSERTS, nil, Error,
    LANG_NEUTRAL or (SUBLANG_DEFAULT shl 10), PChar(@lpMsgBuf), 0, nil);
  result := string(lpMsgBuf);
  for i := 1 to length(result) do
    if (result[i] = #10) or (result[i] = #13) or (result[i] = #9) then
      result[i] := #32;
  LocalFree(Cardinal(lpMsgBuf));
end;



procedure machine_lock;
// function LockWorkStation: boolean; stdcall; external 'user32.dll' name 'LockWorkStation';
begin
  if not LockWorkStation then
    begin
    MessageDlg('NIE UDA£O SIÊ ZABLOKOWAÆ KONSOLI.', mtWarning, [mbOK], 0);
    writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, '!!ERROR98',
      #9, 'LockWorkStation ZAWIOD£A. KOD:', #9,
      GetLastError(), ' ');
    end;
end;

procedure TMainForm.FormMouseEnter(Sender: TObject);
begin
  Color := clWhite;
end;

procedure TMainForm.FormMouseLeave(Sender: TObject);
begin
  Color := clSilver;
end;

procedure TMainForm.WylogujMouseEnter(Sender: TObject);
begin
  Color := clYellow;
end;

procedure TMainForm.ZalogowanyLabelClick(Sender: TObject);
begin
 if (BorderStyle<>bsSingle)or(Color<>clWhite) then
  begin
  Color := clWhite;
  if (CurrTOSVersionInfo.dwMajorVersion>=6)and(CurrTOSVersionInfo.dwMinorVersion>=1) then
        BorderStyle := bsSizeable;
  end
  else
  begin
   if (CurrTOSVersionInfo.dwMajorVersion>=6)and(CurrTOSVersionInfo.dwMinorVersion>=1) then
        BorderStyle := bsNone;
   Color := clSilver;
  end;
end;

procedure TMainForm.WndProc(var Message: TMessage);
var tekst:string;
begin
tekst:='';
if Message.Msg = WM_QUERYENDSESSION then
  begin
  writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, '!END.SES.QU', #9,
    'GOTOWY NA KONIEC SESJI');
  //ZamkniecieSesjiWToku:=true; //Tu jest na to chyba za wczesnie
  tekst:='WM_QUERYENDSESSION';
  end
  else
  case Message.Msg of
  WM_ENDSESSION:begin tekst:='WM_ENDSESSION';
                if not ZamkniecieSesjiWToku then
                      ZamkniecieSesjiWToku:=true;
                end;
  WM_CLOSE:     begin tekst:='WM_CLOSE';
                if not ZamkniecieSesjiWToku then
                        exit;(* NIE przekazuje!!! *)
                end;
  WM_QUIT:tekst:='WM_QUIT';
  WM_DESTROY:tekst:='WM_DESTROY';
 // 15,20:tekst:=''; //Zwyk³e WM_PAINT itp.
  else tekst:='???'; //Inne
  end;
(*
if tekst<>'' then
        if tekst='???' then
            begin
              tekst:='!!!';
            end
          else
          ;//
ShowMessage(tekst);
*)
inherited WndProc(Message);
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, '!CLO.QUERY',
    #9, 'Cerberek - PYTANIE O ZAMKNIECIE');

  if not PlaySound(PChar(Koniec),0,SND_FILENAME) then
    begin
    writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, '!!ERROR174',
      #9,Koniec,'NIE ODTWORZONO ',Koniec,#9,'BO', #9,
      StringSystemError(GetLastError()), ' ');
    end;

  flush(LogFile);
  //ShowMessage('FormCloseQuery');
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Timer1.Destroy;
  PlaySound(nil, 0, SND_SYNC);
  writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, '!THEEND', #9,
    'Cerberek - ZAMKNIECIE FORMY');
   flush(LogFile);
   //ShowMessage('FormClose');
end;

//type   TTerminateProc = function: Boolean;
function CerberekTerminate:boolean;
begin   //FAKTYCZNIE ZAMKNIÊCIE JU¯ TU¯.
{$IOCHECKS OFF}
 writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, '!TERMINATE', #9,
    'ZAMKNIECIE PROCESU');
 writeln(LogFile);
 //OStatni ZAPIS
 closeFile(DataFile);
 rewrite(DataFile);
 writeln(DataFile,MainForm.TimeCount);
 writeln(DataFile,MainForm.AcveCount);
 closeFile(DataFile);
 closeFile(LogFile);
 closeFile(LimitFile);
 closeFile(Restrictions);
 CerberekTerminate:=true;    //AddTerminateProc(CerberekTerminate);
 //ShowMessage('CerberekTerminate');
{$IOCHECKS ON}
end;

(*
procedure OpenCriticalFiles(const user:string);
begin

end;
*)

procedure OdpalZnikacz;
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
  StartUpInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartUpInfo.wShowWindow := SW_HIDE;
  Dir := nil;
  Command:='Znikacz.exe '+inttostr(Windows.GetCurrentProcessId())+#0;
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

procedure TMainForm.FormCreate(Sender: TObject);
var
  bufor: string;
  FileName:string;
  size: DWord;
  ecode: Integer;
begin
  //Application.MessageBox(PChar(system.paramStr(1)),'Cerberek',0);     //Tylko DEBUG
  ZalogowanyLabel.Caption := 'WHO_ARE_MY_OWNER?';
  setlength(bufor, 256);
  size := 256;
  if not Windows.GetUserName(PChar(bufor), size) then
  begin
    ecode := GetLastError();
    ShowMessage('Nie mo¿na ustaliæ nazwy u¿ytkownika' + #10 + StringSystemError(ecode));
  end
  else
  begin
    setlength(bufor, size - 1); // BO ZERO NA KONCU!!!
    ZalogowanyLabel.Caption := bufor;
  end;

{$IOCHECKS OFF}
  // PLIK LOGU ZDARZEN: LogFile
  FileName := concat(bufor, '.log'); // 'cerberek.log';
  AssignFile(LogFile, FileName);
  system.Append(LogFile);
  ecode := IOResult;
  if ecode <> 0 then // Pewnie go nie ma
    system.Rewrite(LogFile);
  ecode := IOResult;
  if ecode <> 0 then
  begin
    Timer1.Destroy;
    ShowMessage('Nie mo¿na otworzyæ wa¿nego pliku' + #10 + StringSystemError
        (ecode));
    writeln(LogFile, DateToStr(Date), #9, TimeToStr(StartTime), #9, '!BLAD1@START',
        #9,FileName,#9,StringSystemError(ecode) );  //A nó¿ siê zapisze bo nie o to chodzi³o?
    Halt; // !!!!!!!
  end;

  //PLIK LIMITU
  FileName := concat(bufor, '.lim'); // Wa¿ne dane  LIMITy !!!
  AssignFile(LimitFile,FileName);
  system.Reset(LimitFile);
  ecode := IOResult;
  if ecode <> 0 then
  begin
    Timer1.Destroy;
    ShowMessage('Nie mo¿na otworzyæ krytycznego pliku' + #10 + StringSystemError(ecode));
    writeln(LogFile, DateToStr(Date), #9, TimeToStr(StartTime), #9, '!BLAD2@START',
    #9,FileName,#9,StringSystemError(ecode) );
    Halt; // !!!!!!!
  end;

  FileName := concat(bufor, '.tmp'); // Wa¿ne dane  - CZASY
  AssignFile(DataFile, FileName); // LogFile
  system.Reset(DataFile);
  ecode := IOResult;
  if ecode <> 0 then // Pewnie go nie ma
    begin
    system.Rewrite(DataFile);
    writeln(DataFile,0);
    writeln(DataFile,0);
    system.Close(DataFile);
    system.Reset(DataFile);
    end;
  ecode := IOResult;
  if ecode <> 0 then
  begin
    Timer1.Destroy;
    ShowMessage('Nie mo¿na otworzyæ wa¿nego pliku' + #10 + StringSystemError
        (ecode));
    writeln(LogFile, DateToStr(Date), #9, TimeToStr(StartTime), #9, '!BLAD3@START',
    #9,FileName,#9,StringSystemError(ecode) );
    Halt; // !!!!!!!
  end;

  readln(LimitFile, DefaultLimit);
  readln(DataFile,TimeCount); //   TimeCount := 0;
  readln(DataFile,AcveCount); //    AcveCount := 0;
  ecode := IOResult;
  if ecode <> 0 then
  begin
    Timer1.Destroy;
    ShowMessage('B³¹d czytania z krytycznego pliku' + #10 + StringSystemError
        (ecode));
    writeln(LogFile, DateToStr(Date), #9, TimeToStr(StartTime), #9, '!BLAD4@START',
    #9,'DANElubLIMITy',#9,StringSystemError(ecode) );
    Halt; // !!!!!!!
  end;
{$IOCHECKS ON}
  AddTerminateProc(CerberekTerminate);
  TimeStamp:=TimeCount;
  ActiStamp:=AcveCount;
  StartTime := Now;
  LastTime := StartTime;
  CurrTOSVersionInfo.dwOSVersionInfoSize:=sizeof(CurrTOSVersionInfo);
  if GetVersionEx(CurrTOSVersionInfo) then
    if (CurrTOSVersionInfo.dwMajorVersion>=6)and(CurrTOSVersionInfo.dwMinorVersion>=1) then
    begin
      self.Zmien.Enabled:=true;
      SetWindowRgn(Handle, CreateRoundRectRgn(0, 0, width, height, 40, 40), true);
    end;
  Historia.Caption := '';
  Czas.Caption := '';
  Czas.Caption := inttostr(TimeCount);
  Aktywny.Caption := inttostr(AcveCount);

//Jak siê uda³o otworzyæ plik to siê przecie¿ tu zapisze chyba?
  writeln(LogFile, DateToStr(Date), #9, TimeToStr(StartTime), #9, '!START',
    #9, 'Cerberek - OTWARCIE');
  SetWindowText(Handle, Title);
  CompleteTitle:=Title;

  if system.paramStr(1)<>'' then
    begin
     SiblingProcPID:=strtoint(system.paramStr(1));
     SiblingProcPID:=OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, false, SiblingProcPID);
    end
    else
    begin
     OdpalZnikacz; //W wersji DEBUG tylko tu próbuje odpaliæ znikacz
              //W wersji docelowej bêdzie te¿ sprawdza³ w pêtli i odpala³
    end;

  writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, '!USER', #9,
          ZalogowanyLabel.Caption, #9,'SYSTEM',#9,
          CurrTOSVersionInfo.dwMajorVersion,'.',
          CurrTOSVersionInfo.dwMinorVersion ,#9, 'PRZY AKTYWACJI. CZASY:', #9,
                TimeCount,#9, #9, AcveCount,#9,'ZNK',#9,SiblingProcPID);

  {$IOCHECKS OFF}
  FileName := concat(bufor, '.rtr'); // Wa¿ne dane  - restrykcje na tytu³y okien i exeki
  AssignFile(Restrictions,FileName);
  system.Reset(Restrictions);
  ecode := IOResult;
  {$IOCHECKS ON}

  Application.BringToFront;
  if ecode <> 0 then
  begin
    writeln(LogFile, DateToStr(Date), #9, TimeToStr(StartTime), #9, '!BLAD3@START',
    #9,FileName,#9,StringSystemError(ecode) );
  end
  else
  begin
    LoadRestrictions(Restrictions);
  end;

  //DOPIERO TERAZ MO¯E STARTOWAÆ G£ÓWNY TIMER!
  Timer1.Enabled:=true;
end;

procedure TMainForm.FormActivate(Sender: TObject);
begin
  SndPlaySound(PChar(Witaj), snd_ASync);    //Powitanie lub napomnienie na poczatek
  if (CurrTOSVersionInfo.dwMajorVersion>=6)and(CurrTOSVersionInfo.dwMinorVersion>=1) then
       BorderStyle:=bsNone;
  writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, '!REAC!', #9,
    'Cerberek');
end;

procedure TMainForm.Timer1Timer(Sender: TObject);
var
  bufor: string;
  len,d,g,m,s: Integer;
  ecode:Integer;
  DateTime1,DateTime2,Diff:TDateTime;

  procedure DniGodzinyMinuty(sek:cardinal;var d,g,m,s:integer);
  const minuty=60;
        godziny=minuty*60;
        dni=godziny*24;
  begin
    d:=sek div dni;
    sek:=sek - d * dni;
    g:=sek div godziny;
    sek:=sek - g * godziny;
    m:=sek div minuty;
    sek:=sek - m * minuty;
    s:=sek;
  end;

begin
  inc(TimeCount);
  Czas.Caption := inttostr(TimeCount);
  len:=round(AcveCount/DefaultLimit*100);
  Aktywny.Caption := inttostr(AcveCount)+' '+inttostr(len)+'%'; // Z poprzedniego
  DniGodzinyMinuty(AcveCount,d,g,m,s);
  bufor:=inttostr(d)+'d '+inttostr(g)+':'+inttostr(m)(*+':'+inttostr(s)*)+' '+Title;
  if bufor<>CompleteTitle then
      begin
        SetWindowText(Handle, bufor);
        CompleteTitle:=bufor;
      end;
  bufor := Historia.Caption;
  len := length(bufor);
  if len >= 60 then
    bufor := copy(bufor, 2, len);

  if SecondsIdle <= 1 then
  begin
    // NA PEWNO USER DZIALA
    inc(AcveCount);
    Historia.Caption := bufor + '!'
  end
  else
  begin
    // MOZE DZIA£A A MOZE NIE
    if not ScreenSaverEnable then
    begin
      // JAK COS WY£¥CZY£O SCREENSAVER TO PRZYJMUJEMY ZE SIÊ USER NA PEWNO "GAPI"
      //Choæ mo¿e np. na prezentacje PPointa
      inc(AcveCount);
      Historia.Caption := bufor + 'V'
    end
    else
    begin
      // MO¯E BYÆ SCREEN SAVER - DALEJ SZUKAMY
      if ScreenSaverRunning then
        Historia.Caption := bufor + 's'
      else
      // JAK SCREENSAVER MA BARDZO D£UGI TIMEOUT TO TE¯ SIÊ "GAPI¥"
        if ScreenSaverTimeOut > 30 * 60 then // To jest w sekundach!
      begin
        inc(AcveCount);
        Historia.Caption := bufor + 'T'
      end
      else
        // BEZCZYNNOŒÆ        ???
        Historia.Caption := bufor + '-'
    end
  end;

  //Sprawdzenia i akcje co jakiœ czas
  //////////////////////////////////////////////////////////////
   if TimeCount mod 10 = 0 then
    begin //robienie okna mniej widocznym
    if (BorderStyle=bsSizeable)and(CurrTOSVersionInfo.dwMajorVersion>=6)and(CurrTOSVersionInfo.dwMinorVersion>=1) then
        BorderStyle := bsNone;
    if Color<>clSilver then
        Color := clSilver;
    end;

  if AcveCount mod 3600 = 0 then // Co godzinê aktywnoœci
    begin  //Informacja ¿e ju¿ siê d³ugo siedzi
    SndPlaySound(PChar(Przerwa), snd_ASync); // PlaySound('SystemStart', 0, SND_SYNC);    //SND_FILMENAME???
    inc(AcveCount); //¯eby nie powtarza³
    end;

  if (TimeCount mod 360 = 0)   //Sprawdzanie resetu limitu normalnie 10 minut,
    or( (AcveCount>DefaultLimit)and(TimeCount mod 60 = 0)) //albo co minutê jak ju¿ przekroczony
    then
     begin
      bufor:=concat(ZalogowanyLabel.Caption,'.lim');
      len:=FileAge(bufor);
      DateTime2:=Now; //Czas aktualny
      DateTime1:=FileDateToDateTime(len); //Czas od utworzenia pliku
      Diff:=DateTime2-DateTime1;
      //Resetowanie licznika raz na "DniLimitu" dni
      if Diff>=DniLimitu then
          begin
          Timer1.Enabled:=false;
          Timer1.Interval:=100000;

          writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, '!LIMIT', #9,
              ZalogowanyLabel.Caption, #9, #9, #9, ' NOWY LIMIT. AKTUALNE CZASY:', #9,
              TimeCount, #9, AcveCount);
          TimeCount:=0;
          AcveCount:=AcveCount-ActiStamp;//Zostaje to co nie zosta³o policzone poprzednio
          TimeStamp:=0;  //Ostatnio zarejestrowany program bêdzie zani¿ony niestety
          ActiStamp:=0;
         {$IOCHECKS OFF}
          closeFile(LimitFile);
          AssignFile(LimitFile,bufor);
          system.Rewrite(LimitFile);
          if ecode <> 0 then
              begin
              Timer1.Destroy;
              ShowMessage('Nie mo¿na otworzyæ krytycznego pliku' + #10 + StringSystemError(ecode));
              writeln(LogFile, DateToStr(Date), #9, TimeToStr(StartTime), #9, '!BLAD2@START',
                        #9,bufor,#9,StringSystemError(ecode) );
              Halt; // !!!!!!!
              end;
          writeln(LimitFile, DefaultLimit); //Rozumiem ¿e zmienia czas
          flush(LimitFile);//Ale zostawia otwarte
          {$IOCHECKS ON}
          Application.BringToFront;
          MessageForm.Label1.Caption:='Ustawiono nowy limit czasu!';
          MessageForm.Show;
          Application.ProcessMessages;

          Timer1.Interval:=1000;
          Timer1.Enabled:=true;
          end
      end;

  if (TimeCount mod 60 = 0)and(AcveCount>DefaultLimit) then //Sprawdzanie limitu
    begin //Przekroczenie dopuszczalnego limitu  - pozwala pracowaæ minutê
    Timer1.Enabled:=false;
    Timer1.Interval:=10000;

    Application.BringToFront;
    MessageForm.Label1.Caption:='Przekroczy³eœ swój okresowy limit!';
    MessageForm.Show;
    Application.ProcessMessages;
    writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, '!!LIMIT', #9,
          ZalogowanyLabel.Caption, #9, #9, #9, ' PRZEKROCZONY LIMIT. CZASY:', #9,
          TimeCount, #9, AcveCount);

    SndPlaySound(PChar(Koniec), snd_ASync);
    Sleep(2500);
    machine_lock;     //!!!!!!!!!!!!!!!!!

    Timer1.Interval:=1000;
    Timer1.Enabled:=true;
    end;

  {$IOCHECKS OFF}   //ZAPIS STANU LICZNIKÓW - musi byæ na koñcu na wypadek resetu liczników
  if TimeCount mod 120 = 0 then //Co dwie minuty
   begin //Zapis czasu u¿ycia do osobnego pliku
   closeFile(DataFile); //Do zapisu trzeba otworzyæ. A trzyma siê otwarty ¿eby by³ niekasowalny
   rewrite(DataFile);
   writeln(DataFile,TimeCount);
   writeln(DataFile,AcveCount);
   flush(DataFile);
   ecode:=IOResult;
   if ecode <> 0 then
    begin
    Timer1.Destroy;
    ShowMessage('B³¹d pisania do krytycznego pliku' + #10 + StringSystemError
        (ecode));
    Halt; // !!!!!!!
    end;
  end;
  {$IOCHECKS ON}

  // Rejestrator u¿ycia programów
  WithWindowActive;
end;

function TMainForm.WithWindowActive: Integer;
var
  uchwyt_okna: HWND;
  IDprocesu: Cardinal;
  uchwyt_proc: THandle;
  winnametab: array [0 .. 1024] of WideChar;
  winname: WideString;
  szModName: WideString;
  result1, result2, ecode, size: Integer;
  NewTime: TDateTime;
  DiffTime: TDateTime;

const
  MaleSekundy: TDateTime = 0.00003;

  function max(a, b: longint): Integer;
  begin
    if a > b then
      result := a
    else
      result := b;
  end;

  function min(a, b: longint): Integer;
  begin
    if a < b then
      result := a
    else
      result := b;
  end;

  procedure replacechar(var s:string;co:char;naco:char);
  var i:integer;//Dla lokalnej petli
  begin
    for i := 1 to length(s) do
       if s[i]=co then
            s[i]:=naco;
  end;

  function BardzoNierowne(const a,b:string):boolean;
  var la,lb,i,licznik:integer;
  begin
    la:=length(a);
    lb:=length(b);
    if abs(la-lb)>2 then
        begin
        BardzoNierowne:=true;
        exit;
        end
        else
        begin //Sprawdzamy
        licznik:=0;
        for i := 1 to min(la,lb) do
           begin
            if a[i]<>b[i] then
                  inc(licznik);
            if licznik>2 then
                begin
                BardzoNierowne:=true;
                exit;
                end;
           end;
        end;
    BardzoNierowne:=false;
  end;

begin
{$IOCHECKS OFF} // Ca³a funkcja ma wy³¹czon¹ kontrolê b³êdów - bo te b³êdy mog¹ byæ chwilowe
  uchwyt_proc := 0;
  winnametab[0] := #0;
  uchwyt_okna := 0;
  szModName := '';

  // WYKRYCIE SNU I PRZECI¥¯EN
  NewTime := Now;
  DiffTime := NewTime - LastTime;
  if DiffTime > MaleSekundy then // Raczej spa³ lub by³o coœ dziwnego
    writeln(LogFile, DateToStr(Date), #9, TimeToStr(NewTime), #9, '!SLEEP',
      #9, 'WYKRYTO PRZERWÊ', #9, 'SLP:'#9, '???', #9, 'CZAS', #9,
      TimeToStr(DiffTime));
  LastTime := NewTime;

  // Obsluga aktualnego okna
  uchwyt_okna := GetForegroundWindow(); // zwraca  uchwyt aktywnego okna.
  if uchwyt_okna = 0 then
  begin
    winname := '!LOST FOCUS'; // BRAK OKNA PIERWSZOPLANOWEGO, MO¯E PRZE£ACZENIE USERA?
  end
  else
  begin       //Odzyskuje nazwê okna
    size := getwindowtext(uchwyt_okna, winnametab, SizeOf(winnametab));// Czasem daje 0. Trudno?

    if size = 0 then
    begin // Okno bez tytu³u albo jakieœ obce
      ecode := GetLastError();
      winname := '!TYTU£ OKNA: ' + inttostr(uchwyt_okna) + ' ??? ';
      if ecode <> 0 then
        winname := winname + ' KOD:' + inttostr(ecode) + ' ' + StringSystemError
          (ecode)
    end
    else
      winname := winnametab;

    if GetWindowThreadProcessId(uchwyt_okna, @IDprocesu) = 0 then
      begin
        ecode := GetLastError();
        if ecode <> 5 then // Odmowa dostêpu jest dosyæ typowa, jak proces Admina lub jakoœ tak
          writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9,
            '!!!ERROR612', #9, winname, #9, ecode, #9,
            '<-KOD. GetWindowThreadProcessId ZAWIOD£A.', #9);
        szModName := '!PID  ??? ! KOD:' + inttostr(ecode)
          + ' ' + StringSystemError(ecode)
      end
      else
      begin
        uchwyt_proc := OpenProcess
          (PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, false, IDprocesu);
        if uchwyt_proc = 0 then
        begin
          ecode := GetLastError();
          if ecode <> 5 then // Odmowa dostêpu jest dosyæ typowa, jak proces Admina lub jakoœ tak
          writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9,
            '!!ERROR626', #9, winname, #9, ecode, #9,
            '<-KOD. OpenProcess(PROCESS_QUERY_INFORMATION) ZAWIOD£A.');
          szModName := '!UCHWYT PROCESU  ???  KOD:' + inttostr(ecode)
            + ' ' + StringSystemError(ecode)
        end
        else
        begin
          setlength(szModName, 2 * MAX_PATH);
          size := GetModuleFileNameExW(uchwyt_proc, 0, PChar(szModName),length(szModName));

          if size = 0 then
          begin
            ecode := GetLastError();

            if (ecode <> 299) and (ecode <> 6) then // Niektóre b³êdy ignorujemy bo s¹ typowe
            begin
              writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9,
                '!!ERROR643', #9, winname, #9, ecode, #9,
                '<-KOD. Funkcja pobrania nazwy EXE ZAWIOD£A.', #9,
                StringSystemError(ecode));
            end;

            szModName := '!NAZWA EXE  ???  KOD:' + inttostr(ecode)
              + ' ' + StringSystemError(ecode)
          end
          else
            setlength(szModName, size);
        end;

        if uchwyt_proc <> 0 then
          if not CloseHandle(uchwyt_proc) then
          begin
            ecode := GetLastError();
            writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9,
              '!!ERROR660', #9, winname, #9, ecode, #9,
              '<-KOD. CloseHandle(uchwyt_proc) ZAWIOD£A.', #9,
              StringSystemError(ecode))
          end;
      end;
  end; // Dla sytuacji ze jest aktywne okno

  if BardzoNierowne(staranazwa,winname) then
  begin
    result1 := TimeCount - TimeStamp;
    result2 := AcveCount - ActiStamp;
    if staranazwa <> '' then // Tylko jak faktycznie by³o jakieœ okno
      writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, 'WIND',
        #9,'"', staranazwa,'"', #9, 'PRC:', #9, staryexec, #9'CZASY: UZYCIA=', #9,
        result1, #9, 'AKTYW', #9, result2, #9, 'LHIST:', #9,'"',
        copy(Historia.Caption, max(0, length(Historia.Caption) - result1),
          length(Historia.Caption)),'"');

    flush(LogFile);
    staranazwa := winname;
    staryexec := szModName;
    Czas.Caption := winname;
    TimeStamp := TimeCount;
    ActiStamp := AcveCount;
    result := result2;
  end
  else
    result := 1; // Awaryjnie

  ecode := IOResult;
  if ecode <> 0 then
  begin
    // Timer1.Destroy;
    if ecode<>lastIOCode then //Nowy b³¹d
      begin
        lastIOError := DateToStr(Date) + #9 + TimeToStr(GetTime)
          + #10 + '!ERROR696' + #9 + 'Okresowy(?) b³¹d zapisu do pliku' + #10 +
        StringSystemError(ecode);
        lastIOCode:=ecode;
        ShowMessage(lastIOError);
        lastIOError:=lastIOError+#9;
        replacechar(lastIOError,#10,#9)
      end
      else
      lastIOError:=lastIOError+'Ag';
  end
  else // ==0
    if lastIOError <> '' then // By³ poprzednio jakis b³¹d - próbuje zapisaæ
      begin
        writeln(LogFile, lastIOError);
        lastIOError := '';
      end;
{$IOCHECKS ON}
  //Implementacja restrykcji
 if Random(5)=0 then //Mniej wiêcej raz na piêæ sekund sprawdza
  begin
   result1:=DajRestrykcje(winname,true);
   if result1<>0 then
   begin
    if result1<>-9 then SendMessage(uchwyt_okna,result1,SC_MINIMIZE,0);//Parametr nie przeszkadza
    ecode:=GetLastError();
    writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, 'W.RESTR',
        #9,'"', winname,'"', #9, 'ACT:', #9, result1,#9, StringSystemError(ecode));
   end;

   result2:=DajRestrykcje(szModName,false);
   if result2<>0 then
   begin
     if result1<>-9 then SendMessage(uchwyt_okna,result2,SC_MINIMIZE,0);
     ecode:=GetLastError();
     writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, 'E.RESTR',
        #9,'"', szModName,'"', #9, 'ACT:', #9, result2,#9,StringSystemError(ecode));
   end;
  end;
end;

function TMainForm.SecondsIdle: DWord;
var
  liInfo: TLastInputInfo;
begin
  liInfo.cbSize := SizeOf(TLastInputInfo);
  GetLastInputInfo(liInfo);
  result := (GetTickCount - liInfo.dwTime) DIV 1000;
end;

// SystemParametersInfo(SPI_SCREENSAVERRUNNING,1, nil,0);
// SPI_GETSCREENSAVERRUNNING
// SPI_GETSCREENSAVEACTIVE
// SPI_GETSCREENSAVETIMEOUT
function TMainForm.ScreenSaverEnable: bool;
var
  ret: bool;
begin
  ret := false;
  if not SystemParametersInfo(SPI_GETSCREENSAVEACTIVE, 0, @ret, 0) then
    writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, '!!ERROR734',
      #9, 'SPI_GETSCREENSAVEACTIVE failed ZAWIOD£A. KOD:', #9,
      GetLastError(), ' ');

  result := ret;
end;

function TMainForm.ScreenSaverTimeOut: Integer;
var
  ret: Integer;
begin
  ret := 0;
  if not SystemParametersInfo(SPI_GETSCREENSAVETIMEOUT, 0, @ret, 0) then
    writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, '!!ERROR747',
      #9, 'SPI_GETSCREENSAVETIMEOUT ZAWIOD£A. KOD:', #9,
      GetLastError(), ' ');

  result := ret;
end;

function TMainForm.ScreenSaverRunning: bool;
var
  ret: bool;
begin
  ret := false;
  if not SystemParametersInfo(SPI_GETSCREENSAVERRUNNING, 0, @ret, 0) then
    writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, '!!ERROR760',
      #9, 'SPI_GETSCREENSAVERRUNNING ZAWIOD£A. KOD:', #9,
      GetLastError(), ' ');

  result := ret;
end;

procedure TMainForm.ZablokujClick(Sender: TObject);
begin
  machine_lock;
end;

procedure TMainForm.ZmienClick(Sender: TObject);
var ret:THandle;
begin
  // windows.LogonUser()
  //WinExec(@SwitchUser, 0);
  ret:=ShellExecute (Application.MainForm.Handle, PChar('open'),PChar(SwitchUser(*'tsdiscon.exe'*)), nil ,nil , SW_SHOWDEFAULT);
  if ret<=32 then
    begin
     MessageDlg('PRZE£¥CZENIE NIE UDA£O SIÊ', mtWarning, [mbOK], 0);
     writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, '!!ERROR781',
      #9,SwitchUser,'NIE UDALO SIE.',#9,'BO', #9,
      StringSystemError(ret), ' ');
    end;
end;

procedure TMainForm.WylogujClick(Sender: TObject);
begin
  if MessageBox(0,'Na pewno chcesz siê wylogowaæ?','Koñczenie sesji',1)=1 then
     //ShowMessage('No to jazda!');
  if not ExitWindowsEx(EWX_LOGOFF { or ENDSESSION_LOGOFF or EWX_FORCE}, 0) then
  begin
    writeln(LogFile, DateToStr(Date), #9, TimeToStr(GetTime), #9, '!USER:', #9,
      ZalogowanyLabel.Caption, #9, ' NIEPOWODZENIE WYLOGOWANIA:', #9,
      TimeCount, #9, AcveCount);
    ShowMessage('Masz (nie-)farta, nie uda³o siê wylogowaæ');
  end; // QUERY_SHUTDOWN
    {
    Value Meaning
    EWX_FORCE Forces processes to terminate. When this flag is set, Windows does not send the messages WM_QUERYENDSESSION and WM_ENDSESSION to the applications currently running in the system. This can cause the applications to lose data. Therefore, you should only use this flag in an emergency.
    EWX_LOGOFF Shuts down all processes running in the security context of the process that called the ExitWindowsEx function. Then it logs the user off.
    EWX_POWEROFF Shuts down the system and turns off the power. The system must support the power-off feature.Windows NT: The calling process must have the SE_SHUTDOWN_NAME privilege. For more information, see the following Remarks section. Windows 95: Security privileges are not supported or required.
    EWX_REBOOT Shuts down the system and then restarts the system. Windows NT: The calling process must have the SE_SHUTDOWN_NAME privilege. For more information, see the following Remarks section. Windows 95: Security privileges are not supported or required.
    EWX_SHUTDOWN Shuts down the system to a point at which it is safe to turn off the power. All file buffers have been flushed to disk, and all running processes have stopped. Windows NT: The calling process must have the SE_SHUTDOWN_NAME privilege. For more information, see the following Remarks section. Windows 95: Security privileges are not supported or required.
    }
end;


// !!! ENUMERACJA MODU£ÓW: ms-help://embarcadero.rs2010/DllProc/base/enumerating_all_processes.htm

(*
  type PHMODULE = ^HMODULE;

  function EnumProcesses(
  pProcessIds: PDWORD;
  cb: DWORD;
  out pBytesReturned: DWORD
  ): boolean; stdcall; external 'Psapi.dll';

  function EnumProcessModules(
  hProcess: THandle;
  lphModule: PHMODULE;
  cb: DWORD;
  out lpcbNeeded: DWORD
  ): boolean; stdcall; external 'Psapi.dll';

  function GetModuleFileNameEx(
  hProcess: THandle;
  hModule: HMODULE;
  lpFilename: PChar;
  nSize: DWORD
  ): DWORD; stdcall; external 'Psapi.dll' name 'GetModuleFileNameExA'; //use "W" for unicode Delphi, 2009+

  //if not QueryFullProcessImageName(uchwyt_proc,0,@procname,sizeof(procname)) then
  //if GetProcessImageFileNameW(uchwyt_proc,@procname,sizeof(procname))=0 then
*)

{
  11. Jak ukryæ program by nie by³ wyœwietlany na pasku zadañ ?

  uses Windows;
  var
  ExtendedStyle:Integer;
  begin
  ExtendedStyle:=GetWindowLong(Application.Handle, GWL_EXSTYLE);
  SetWindowLong(Application.Handle,GWL_EXSTYLE,
  ExtendedStyle or WS_EX_TOOLWINDOW and not WS_EX_APPWINDOW);
  end;

  79. Jak najproœciej odtworzyæ dŸwiêk WAV ?

  uses mmsystem;

  procedure TForm1.Button1Click(Sender: TObject);
  begin
  SndPlaySound('C:WINDOWSMEDIATADA.WAV', snd_ASync);
  end;

  80. Jak odegraæ dŸwiêk b³êdu ?

  Najproœciej bedzie u¿yæ beepera. Wprawdzie pojawi³o siê du¿o komponentów zastêpuj¹cych beeper, ale my u¿yjemy standardowego systemowego beepu. A to bardzo prosta procedura:

  beep;

  81. Jak odegraæ muzyczkê startow¹ systemu ?

  Oto najprostrza funkcji:
  PlaySound('SystemStart', 0, SND_SYNC);

  50. Jak rysowaæ po pulpicie ?

  Wystarczy u¿ywaæ pulpitu jako Canvas.
  Funkcja GetDesktopWindow zwraca uchwyt pulpitu.

  Canvas.Handle:=GetWindowDC(GetDesktopWindow);
  //tutaj u¿ywamy funkcji Canvas'a do rysowania

  //a teraz zwalniamy uchwyt
  ReleaseDC(GetDesktopWindow,Canvas.Handle);

  55. Jak zmieniæ kszta³t formy i komponentów ?

  procedure TForm1.Button1Click(Sender:TObject);
  begin
  SetWindowRgn(Handle,CreateRoundRectRgn(0,0,width,height,50,50),true);
  //tworzy formê bardziej zaokr¹glon¹
  end;

  SetWindowRgn(Handle,CreateEllipticRgn(0, 0, Width, Height), True); //tworzy z formy elipsê

  Funkcja CreatePolygonRgn(.......) tworzy bardziej z³o¿one kszta³ty

  Zamiast uchwytu do formy ( Handle ) mozesz wykorzystac uchwyt do innych komponentow np. Button1.Handle

  //http://michalive.socjum.pl/forum/temat/2
  function EnumChildProc(uchwyt:Hwnd;p:pointer):boolean;stdcall;
  var winname,cname:array[0..144]of WideChar;
  begin
  result:=true;
  getwindowtextW(uchwyt,winname,144);
  //getclassname(uchwyt,cname,144);
  MainForm.Czas.Caption:=winname;
  //Form1.Memo1.Lines.Append('POTOMEK: TEXT:'+strpas(winname)+' KLASA: '+strpas(cname)+' '+IntToStr(uchwyt));
  end;

  function EnumWindowProc(uchwyt:HWnd;p:pointer):boolean;stdcall;
  var
  winname,cname:array[0..144]of WideChar;
  begin
  result:=true;
  getwindowtextW(uchwyt,winname,144);
  //getclassname(uchwyt,cname,144);
  MainForm.Czas.Caption:=winname;
  //MainForm.sh
  //Form1.Memo1.Lines.Append('OKNO: TEXT:'+strpas(winname)+' KLASA: '+strpas(cname)+' '+IntToStr(uchwyt));
  enumchildwindows(uchwyt,@enumchildproc,0);
  end;

  procedure TMainForm.Button1Click(Sender: TObject);
  begin
  EnumWindows(@enumwindowproc,0);
  end;


  14. Jak uzyskaæ informacjê o katalogach : Windows'a, systemu i obecnego ?

  Dodaj komponent TListBox do formy

  var
  Sciezka:array[0..MAX_PATH] of char;
  begin
  GetWindowsDirectory(Sciezka,sizeof(Sciezka)); //katalog Windows'a
  ListBox1.Items.Add(Sciezka);
  GetSystemDirectory(Sciezka,sizeof(Sciezka)); // katalog systemowy
  ListBox1.Items.Add(Sciezka);
  GetCurrentDirectory(sizeof(Sciezka),Sciezka); // katalog bie¿¹cy
  ListBox1.Items.Add(Sciezka);
  end;

  15. Jak uzyskaæ informacjê o konfiguracji sprzêtowej ?

  Dodaj komponent TListBox do formy

  var Sys:TSystemInfo;
  begin
  GetSystemInfo(Sys);
  with ListBox1.Items,Sys do begin
  Add('Architektura procesora : Intel');
  Add('Rozmiar strony : '+inttostr(dwPageSize)+' bajtów');
  Add('Min. adres aplikacji : '+StrPas(lpMinimumApplicationAddress));
  Add('Max. adres aplikacji : '+StrPas(lpMaximumApplicationAddress));
  Add('Liczba procesorów : '+inttostr(dwNumberOfProcessors));

  Add('Granulacja przydzia³u : '+inttostr(dwAllocationGranularity)+' bajtów');
  case wProcessorLevel of
  3: Add('Poziom procesora : 80386');
  4: Add('Poziom procesora : 80486');
  5: Add('Poziom procesora : Pentium');
  6: Add('Poziom procesora : Pentium Pro');
  else Add('Poziom procesora : '+inttostr(wProcessorLevel));
  end; end; end;

  16. Jak odczytaæ zmienne œrodowiskowe ?

  Dodaj komponent TListBox do formy

  var ZmienneChar;
  begin
  Zmienne:=GetEnvironmentStrings;
  repeat
  ListBox1.Items.Add(StrPas(Zmienne));
  inc(Zmienne,StrLen(Zmienne)+1);
  until Zmienne^=#0;
  FreeEnvironmentStrings(Zmienne);
  end;

  18. Jak pobraæ œcie¿ki do folderów Windows'a (Fonts, Pulpit, Menu Start ....) ?

  Mo¿na czytaæ z rejestru Windows'a. Lecz ³atwiejsz¹ metod¹ jest funkcja
  SHGetSpecjalFolderPath(hwndOnwer: HWND; lpszPath: PChar; nFolder: Integer; fCreate: BOOL): BOOL; stdcall;

  uses ShlObj;

  function GetP(Folder: Integer): String;
  var FilePath: array[0..MAX_PATH] of char;
  begin
  SHGetSpecialFolderPath(0, FilePath, Folder , False);
  Result:=FilePath;
  end;

  24. Jak tworzyæ pliki *.LNK ( skrót na pulpicie i w Menu Start )

  uses ShlObj, ActiveX, ComObj, Registry;

  procedure TForm1.Button1Click(Sender: TObject);
  var MyObject : IUnknown;
  MySLink : IShellLink;
  MyPFile : IPersistFile;
  FileName : String;
  Directory : String;
  WFileName : WideString;
  MyReg : TRegIniFile;

  begin
  MyObject:=CreateComObject(CLSID_ShellLink);
  MySLink:=MyObject as IShellLink;
  MyPFile:=MyObject as IPersistFile;
  FileName:='NOTEPAD.EXE';
  with MySLink do
  begin
  SetArguments('C:AUTOEXEC.BAT');
  SetPath(PChar(FileName));
  SetWorkingDirectory(PChar(ExtractFilePath(FileName)));
  end;

  MyReg := TRegIniFile.Create('SoftwareMicroSoftWindowsCurrentVersionExplorer');

  // Poni¿sze dodaje skrót do desktopu
  Directory := MyReg.ReadString('Shell Folders','Desktop','');

  // A to do menu Start
  Directory := MyReg.ReadString('Shell Folders','Start Menu','')+ 'Microspace';
  // CreateDir(Directory);

  WFileName := Directory+'Oglodek.lnk';
  MyPFile.Save(PWChar(WFileName),False);
  MyReg.Free;
  end;

  71. Jak zrobiæ najszybszy zrzut ekranu ?

  Oto fragment kodu, który robi wiele ma³ych zrzutów, a nastêpnie wyœwietla w postacji itmapy:

  const cTileSize = 50;
  function TForm1.GetScreenShot: TBitmap;
  var X, Y, XS, YS : Integer;
  Locked : Boolean;
  Canvas : TCanvas;
  R : TRect;
  begin
  Result := TBitmap.Create;
  Result.Width := Screen.Width;
  Result.Height := Screen.Height;
  Canvas := TCanvas.Create;
  Canvas.Handle := GetDC(0);
  Locked := Canvas.TryLock;
  try
  XS := Pred(Screen.Width div cTileSize);
  if Screen.Width mod cTileSize > 0 then
  Inc(XS);
  YS := Pred(Screen.Height div cTileSize);
  if Screen.Height mod cTileSize > 0 then
  Inc(YS);
  for X := 0 to XS do
  for Y := 0 to YS do
  begin
  R := Rect(
  X * cTileSize, Y * cTileSize, Succ(X) * cTileSize,
  Succ(Y) * cTileSize);
  Result.Canvas.CopyRect(R, Canvas, R);
  end;
  finally
  if Locked then
  Canvas.Unlock;
  ReleaseDC(0, Canvas.Handle);
  Canvas.Free;
  end;
  end;

  92. Jak w Delphi 4 u¿ywaæ polskich liter ?

  Nale¿y w rejestrze systemu w kluczu HKEY_CURRENT_USERSoftwareBorlandDelphi4.0EditorOptions dodaæ now¹ wartoœæ ci¹gu o nazwie NoCtrlAltKeys z wartoœci¹ 1

  Mo¿na do tego u¿yæ programu Regedit lub zrobiæ to za pomoc¹ Delphi

  uses Registry;
  procedure TForm1.FormCreate(Sender: TObject);
  var Rejestr:TRegistry;
  begin
  Rejestr:=TRegistry.Create;
  Rejestr.OpenKey('SoftwareBorlandDelphi4.0EditorOptions',True);
  Rejestr.WriteString('NoCtrlAltKeys','1');
  Rejestr.Free;
  end;

  112. Jak wyœwietliæ okno prowadzania danych tekstowych ?

  Nale¿y u¿yæ funkcji InputBox:

  Label1.Caption := InputBox('Okno z danymi','WprowadŸ coœ','');
  // 1 Parametr: Caption okna
  // 2 Parametr: Tekst zachêcaj¹cy
  // 3 Parametr: Domyœlny ³añcuch w polu edycyjnym

  121. Jak wykonaæ jak¹œ procedurê podczas pierwszego uruchaminia ?

  procedure TMainForm.FormCreate(Sender: TObject);
  var Reg : TRegistry; KeyExists : Boolean;
  begin
  Reg := TRegistry.Create;
  try
  KeyExists := Reg.OpenKey('SoftwareRegApp', False); // otworz klucz
  if not KeyExists then
  begin
  //kod wykonywany przy pierwszym uruchomieniu
  end;
  finally
  Reg.Free;
  end;
  end;

  122. Jak skasowaæ wartoœæ z rejestru ?

  uses Registry;

  var Rejestr : TRegistry;
  begin
  Rejestr:=TRegistry.Create;
  Rejestr.OpenKey('Nazwa klucza w którym jest wartoœæ do skasowania jezeli
  jest w innej ga³êzi ni¿ HKEY_CURRENT_USER nalezy zmienic RootKey',False);
  Rejestr.DeleteValue('Nazwa wartoœci do skasowania');
  Rejestr.Free;
  end;
  }
(*
  123. Jak odczytaæ wartoœæ binarn¹ z rejestru ?

  O ile z odczytem wartoœci typu String i Integer nie powininno byæ problemu, o tyle odczyt wartoœci binarnej mo¿e przynieœæ trochê problemów - poni¿sza procedura za³atwi t¹ sprawê.

  uses Registry;

  procedure TForm1.Button1Click(Sender: TObject);
  var Rejestr : TRegistry;
  Buff : array [0..4096] of Char;
  x, i : Integer;
  begin
  Rejestr := TRegistry.Create;
  Rejestr.RootKey:=HKEY_LOCAL_MACHINE;
  Rejestr.OpenKey('Config', False);
  i := Rejestr.ReadBinaryData('Jardo', Buff, SizeOf(Buff));
  Edit1.Text := '';
  Edit2.Text := '';
  for x := 0 to i-1 do
  begin
  {hexowo - tak przedstawiane sa dane w edytorze rejestru}
  Edit1.Text := Edit1.Text + ' ' + IntToHex( Ord(Buff[x]), 2 );
  {tekstowo - tak rowniez, ale tylko w trybie edycji}
  Edit2.Text := Edit2.text + Buff[x];
  end;
  Rejestr.Free;
  end;

  Lub mo¿na to zrobiæ w ten sposób:

  uses Registry;
  var Rejestr : TRegistry;
  Zmienna : Integer;
  begin
  Rejestr:=TRegistry.Create;
  Rejestr.OpenKey('Nazwa klucza w którym jest wartoœæ binarna',False);
  Rejestr.ReadBinary('Nazwa wartoœci',Zmienna,SizeOf(Zmienna));
  Rejestr.Free;
  end;


  127. Jak uruchomiæ przegl¹darkê lub klienta poczty z wpisanym adresem ?

  ShellExecute(Handle,'open','http://www.delphi.qs.pl',nil,nil,SW_SHOWNORMAL);
  //otwiera stronê internetow¹

  ShellExecute(Handle,'open','mailto:delphi@koti.pl',nil,nil,SW_SHOWNORMAL);
  //otwiera program pocztowy

  ShellExecute(Handle, 'open', 'mailto:email@serwer.pl?subject=Temat wiadomosci&body=Pierwsza linia

  Druga linia', NIL, NIL, SW_SHOWNORMAL);
  //otwiera program pocztowy z tematem i treœci¹

  129. Jak pobieraæ pliki z sieci ?

  Nale¿y u¿yæ modu³u URLMon:

  Uses URLMon;

  procedure TForm1.Button1Click(Sender: TObject);
  begin
  if URLDownloadToFile(Nil,'http://co.cos/cos.zip','c:cos.zip',0,Nil) <> 0 then
  ShowMessage('Wyst¹pi³ jakiœ b³¹d przy pobieraniu!');
  end;

  http://4programmers.net/Delphi/FAQ/Jak_zrobi%C4%87_zrzut_z_ekranu

  Jak zrobiæ zrzut z ekranu
  Oto kod:


  var
  Can: TCanvas;
  B: TBitmap;
  begin
  try
  { tworzenie zmiennej }
  Can := TCanvas.Create;
  { przechwycenie uchwytu ekrnau }
  Can.Handle := GetWindowDC(GetDesktopWindow);

  { tworzenie bitmapy }
  B := TBitmap.Create;
  B.Width := Screen.Width;
  B.Height := Screen.Height;
  B.Canvas.CopyRect(Rect(0, 0, Screen.Width, Screen.Height), Can, Rect(0, 0, Screen.Width, Screen.Height));
  try // zapisz plik
  B.SaveToFile('C:\\plik.bmp');
  except // w wyniku bledu...
  raise Exception.Create('B³ad w zapisie pliku...');
  end;

  finally
  Can.Free;
  B.Free;
  end;


*)
{
  http://www.tek-tips.com/faqs.cfm?fid=6881
  procedure machine_standby;
  begin
  if IsPwrSuspendAllowed then
  SetSuspendState(false, false, false)
  else
  MessageDlg('System Standby not supported on this system.', mtWarning, [mbOK], 0);
  end;



  procedure machine_shutdown;
  const
  SE_SHUTDOWN_NAME = 'SeShutdownPrivilege';
  begin
  NTSetPrivilege(SE_SHUTDOWN_NAME, True);
  ExitWindowsEx(EWX_SHUTDOWN or EWX_FORCE, 0);
  end;

  the first parm value is obvious, the second is not.  In the Win32 help dll, the following is said about EWX_FORCE:
  Quote:
  Forces processes to terminate. Instead of bringing up the "application not responding"
  dialog box for the user, this value forces an application to terminate if it does
  not respond.
}

(*
  Delphi

  procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  begin
  CanClose:=FALSE;  // tu mo¿esz dodaæ prosty warunek, aby program wiedzia³ kiedy mo¿e siê zamkn¹æ...
  end;

  Mo¿e spróbuj ukryæ proces w systemie rolleyes.gif

  Np. tak:

  Delphi

  unit Unit1;

  interface

  uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs;

  type
  TForm1 = class(TForm)
  procedure FormCreate(Sender: TObject);
  private
  { Private declarations }
  public
  { Public declarations }
  end;

  function registerserviceprocess(pid,blah:longint):boolean;
  stdcall;external 'kernel32.dll' name 'RegisterServiceProcess';

  var
  Form1: TForm1;

  implementation

  {$R *.DFM}

  procedure TForm1.FormCreate(Sender: TObject);
  begin
  registerserviceprocess(0,1);
  end;

  end.

*)
//  ????       ¯EBY WY£APAÆ "KILL"!?
begin
///HookSignal???
end.
