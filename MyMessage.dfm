object MessageForm: TMessageForm
  Left = 0
  Top = 0
  Caption = 'WA'#379'NY KOMUNIKAT'
  ClientHeight = 74
  ClientWidth = 492
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnActivate = FormActivate
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 24
    Top = 16
    Width = 83
    Height = 13
    Caption = 'Tresc komunikatu'
  end
  object Button1: TButton
    Left = 208
    Top = 41
    Width = 75
    Height = 25
    Caption = 'OK'
    TabOrder = 0
    OnClick = Button1Click
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 5000
    OnTimer = Timer1Timer
    Left = 448
    Top = 32
  end
end
