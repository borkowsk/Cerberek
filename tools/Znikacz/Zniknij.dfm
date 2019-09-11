object ZniknijForm: TZniknijForm
  Left = 0
  Top = 0
  BorderIcons = [biMinimize]
  BorderStyle = bsSingle
  Caption = 'znk'
  ClientHeight = 59
  ClientWidth = 120
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnActivate = FormActivate
  OnDestroy = FormDestroy
  OnMouseEnter = FormMouseEnter
  OnMouseLeave = FormMouseLeave
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 34
    Top = 8
    Width = 52
    Height = 13
    Caption = '^*<..>*^'
  end
  object PIDBox: TEdit
    Left = 8
    Top = 30
    Width = 104
    Height = 21
    TabOrder = 0
    Text = 'PIDBox'
  end
  object MainTimer: TTimer
    Enabled = False
    OnTimer = MainTimerTimer
  end
end
