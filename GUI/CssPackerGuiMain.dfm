object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'CssPacker - Universal CSS Pack / Unpack Tool'
  ClientHeight = 720
  ClientWidth = 1100
  Color = 16119285
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 15
  object pnlInput: TPanel
    Left = 0
    Top = 0
    Width = 1100
    Height = 574
    Align = alClient
    BevelOuter = bvNone
    Color = 16777215
    ParentBackground = False
    TabOrder = 0
    object lblInput: TLabel
      Left = 1
      Top = 1
      Width = 1098
      Height = 24
      Align = alTop
      Caption = 'INPUT CSS'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 2977202
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object memInput: TMemo
      Left = 1
      Top = 25
      Width = 1098
      Height = 548
      Align = alClient
      Color = 16777215
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Consolas'
      Font.Style = []
      ParentFont = False
      ScrollBars = ssBoth
      TabOrder = 0
      WordWrap = False
    end
  end
  object splitter: TSplitter
    Left = 0
    Top = 0
    Width = 6
    Height = 574
    Align = alLeft
  end
  object pnlOutput: TPanel
    Left = 560
    Top = 0
    Width = 540
    Height = 574
    Align = alRight
    BevelOuter = bvNone
    Color = 16777215
    ParentBackground = False
    TabOrder = 1
    object lblOutput: TLabel
      Left = 1
      Top = 1
      Width = 538
      Height = 24
      Align = alTop
      Caption = 'OUTPUT CSS'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 2984509
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object memOutput: TMemo
      Left = 1
      Top = 25
      Width = 538
      Height = 548
      Align = alClient
      Color = 16777215
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Consolas'
      Font.Style = []
      ParentFont = False
      ScrollBars = ssBoth
      TabOrder = 0
      WordWrap = False
    end
  end
  object statusBar: TStatusBar
    Left = 0
    Top = 700
    Width = 1100
    Height = 20
    Align = alBottom
    Panels = <
      item
        Width = 300
      end
      item
        Width = 200
      end
      item
        Width = 200
      end
      item
        Width = 200
      end>
    SimplePanel = False
  end
  object pnlOptions: TPanel
    Left = 0
    Top = 0
    Width = 1100
    Height = 88
    Align = alTop
    BevelOuter = bvNone
    Color = 15397111
    ParentBackground = False
    TabOrder = 2
    object lblMode: TLabel
      Left = 10
      Top = 8
      Width = 33
      Height = 15
      Caption = 'Mode:'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object cboMode: TComboBox
      Left = 10
      Top = 28
      Width = 170
      Height = 23
      Style = csDropDownList
      ItemIndex = 0
      Items.Strings = (
        'auto  (detect)'
        'pack-safe  (minify)'
        'pack-fast  (aggressive)'
        'unpack  (pretty print)')
      TabOrder = 0
      OnChange = ModeChanged
    end
    object lblIndent: TLabel
      Left = 196
      Top = 8
      Width = 36
      Height = 15
      Caption = 'Indent:'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object cboIndent: TComboBox
      Left = 196
      Top = 28
      Width = 70
      Height = 23
      Style = csDropDownList
      ItemIndex = 1
      Items.Strings = (
        '1'
        '2'
        '3'
        '4'
        '5'
        '6'
        '7'
        '8'
        'tab')
      TabOrder = 1
    end
    object lblEOL: TLabel
      Left = 282
      Top = 8
      Width = 64
      Height = 15
      Caption = 'Line ending:'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object cboEOL: TComboBox
      Left = 282
      Top = 28
      Width = 100
      Height = 23
      Style = csDropDownList
      ItemIndex = 0
      Items.Strings = (
        'auto'
        'LF'
        'CRLF'
        'CR')
      TabOrder = 2
    end
    object chkKeepComments: TCheckBox
      Left = 400
      Top = 12
      Width = 120
      Height = 17
      Caption = 'Keep comments'
      TabOrder = 3
    end
    object chkLicense: TCheckBox
      Left = 400
      Top = 32
      Width = 120
      Height = 17
      Caption = 'Keep /*! license'
      Checked = True
      State = cbChecked
      TabOrder = 4
    end
    object chkHex: TCheckBox
      Left = 530
      Top = 12
      Width = 110
      Height = 17
      Caption = 'Shorten hex'
      TabOrder = 5
    end
    object chkZero: TCheckBox
      Left = 530
      Top = 32
      Width = 110
      Height = 17
      Caption = '0px -> 0'
      TabOrder = 6
    end
    object chkLeadingZero: TCheckBox
      Left = 650
      Top = 12
      Width = 110
      Height = 17
      Caption = '0.5 -> .5'
      TabOrder = 7
    end
    object chkFinalSemi: TCheckBox
      Left = 650
      Top = 32
      Width = 110
      Height = 17
      Caption = 'Drop last ;'
      TabOrder = 8
    end
    object chkCharset: TCheckBox
      Left = 770
      Top = 12
      Width = 110
      Height = 17
      Caption = 'Drop @charset'
      TabOrder = 9
    end
    object chkBlankLines: TCheckBox
      Left = 770
      Top = 32
      Width = 110
      Height = 17
      Caption = 'Blank lines'
      TabOrder = 10
    end
    object chkTabs: TCheckBox
      Left = 890
      Top = 12
      Width = 90
      Height = 17
      Caption = 'Use tabs'
      TabOrder = 11
    end
  end
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 1100
    Height = 58
    Align = alTop
    BevelOuter = bvNone
    Color = 2977202
    ParentBackground = False
    TabOrder = 3
    object btnOpen: TButton
      Left = 8
      Top = 12
      Width = 90
      Height = 34
      Caption = 'Open...'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      OnClick = ButtonOpenClick
    end
    object btnSave: TButton
      Left = 104
      Top = 12
      Width = 90
      Height = 34
      Caption = 'Save...'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 1
      OnClick = ButtonSaveClick
    end
    object btnProcess: TButton
      Left = 200
      Top = 12
      Width = 110
      Height = 34
      Caption = 'Process'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 2
      OnClick = ButtonProcessClick
    end
    object btnSwap: TButton
      Left = 318
      Top = 12
      Width = 80
      Height = 34
      Caption = 'Swap'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 3
      OnClick = ButtonSwapClick
    end
    object btnCopy: TButton
      Left = 404
      Top = 12
      Width = 110
      Height = 34
      Caption = 'Copy Output'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 4
      OnClick = ButtonCopyClick
    end
    object btnClear: TButton
      Left = 520
      Top = 12
      Width = 80
      Height = 34
      Caption = 'Clear'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      TabOrder = 5
      OnClick = ButtonClearClick
    end
    object lblLanguage: TLabel
      Left = 620
      Top = 22
      Width = 56
      Height = 15
      Caption = 'Language:'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object cboLanguage: TComboBox
      Left = 680
      Top = 15
      Width = 150
      Height = 23
      Style = csDropDownList
      TabOrder = 6
      OnChange = LanguageChanged
    end
  end
  object dlgOpen: TOpenDialog
    DefaultExt = 'css'
    Filter = 'CSS files (*.css)|*.css|All files (*.*)|*.*'
    Left = 400
    Top = 400
  end
  object dlgSave: TSaveDialog
    DefaultExt = 'css'
    Filter = 'CSS files (*.css)|*.css|All files (*.*)|*.*'
    Left = 464
    Top = 400
  end
end
