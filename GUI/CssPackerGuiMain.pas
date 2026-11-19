unit CssPackerGuiMain;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.IOUtils,
  System.IniFiles,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Clipbrd,
  CssPacker.Core,
  CssPacker.Lang;

type
  TfrmMain = class(TForm)
    pnlTop: TPanel;
    btnOpen: TButton;
    btnSave: TButton;
    btnProcess: TButton;
    btnSwap: TButton;
    btnCopy: TButton;
    btnClear: TButton;
    pnlOptions: TPanel;
    lblMode: TLabel;
    cboMode: TComboBox;
    lblIndent: TLabel;
    cboIndent: TComboBox;
    lblEOL: TLabel;
    cboEOL: TComboBox;
    chkKeepComments: TCheckBox;
    chkLicense: TCheckBox;
    chkHex: TCheckBox;
    chkZero: TCheckBox;
    chkLeadingZero: TCheckBox;
    chkFinalSemi: TCheckBox;
    chkCharset: TCheckBox;
    chkBlankLines: TCheckBox;
    chkTabs: TCheckBox;
    pnlInput: TPanel;
    lblInput: TLabel;
    memInput: TMemo;
    splitter: TSplitter;
    pnlOutput: TPanel;
    lblOutput: TLabel;
    memOutput: TMemo;
    statusBar: TStatusBar;
    dlgOpen: TOpenDialog;
    dlgSave: TSaveDialog;
    lblLanguage: TLabel;
    cboLanguage: TComboBox;
    procedure ButtonOpenClick(Sender: TObject);
    procedure ButtonSaveClick(Sender: TObject);
    procedure ButtonProcessClick(Sender: TObject);
    procedure ButtonCopyClick(Sender: TObject);
    procedure ButtonSwapClick(Sender: TObject);
    procedure ButtonClearClick(Sender: TObject);
    procedure ModeChanged(Sender: TObject);
    procedure LanguageChanged(Sender: TObject);
  private
    CurrentFile: string;
    FStatusID: string;
    FStatusArgs: TArray<string>;
    FApplyingLanguage: Boolean;
    FHasStats: Boolean;
    FLastStats: TCssStats;
    function GetOptions: TCssOptions;
    procedure ApplyLanguage;
    procedure ApplyDialogFilters;
    procedure SetStatus(const ID: string; const Args: array of string);
    procedure RenderStatus;
    procedure RenderStatusPanels;
    function SettingsFileName: string;
    procedure LoadLanguagePreference;
    procedure SaveLanguagePreference;
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

{ Replace the items of a drop-down list while keeping the user's selection. }
procedure SetComboItems(ACombo: TComboBox; const AItems: array of string;
  AIndex: Integer);
var
  I: Integer;
begin
  ACombo.Items.BeginUpdate;
  try
    ACombo.Items.Clear;
    for I := 0 to High(AItems) do
      ACombo.Items.Add(AItems[I]);
    if (AIndex >= 0) and (AIndex < ACombo.Items.Count) then
      ACombo.ItemIndex := AIndex;
  finally
    ACombo.Items.EndUpdate;
  end;
end;

constructor TfrmMain.Create(AOwner: TComponent);
var
  I, Idx: Integer;
  Code: string;
begin
  inherited Create(AOwner);

  { populate language selector - names are shown in their own language, which
    is the conventional behaviour for language pickers }
  cboLanguage.Items.Clear;
  for I := 0 to TCssLang.Codes.Count - 1 do
    cboLanguage.Items.Add(TCssLang.DisplayName(TCssLang.Codes[I]));

  LoadLanguagePreference;
  if cboLanguage.ItemIndex < 0 then
  begin
    Code := TCssLang.NormalizeCode(TCssLang.DetectSystem);
    Idx := TCssLang.Codes.IndexOf(Code);
    if Idx < 0 then Idx := TCssLang.Codes.IndexOf('en');
    if Idx < 0 then Idx := 0;
    cboLanguage.ItemIndex := Idx;
  end;
  TCssLang.SetLanguage(TCssLang.Codes[cboLanguage.ItemIndex]);

  ApplyLanguage;
  SetStatus(TXT_StatusReady, []);
end;

function TfrmMain.SettingsFileName: string;
var
  Base, Dir: string;
begin
  Base := GetEnvironmentVariable('LOCALAPPDATA');
  if Base = '' then
    Base := TPath.GetHomePath;
  Dir := TPath.Combine(Base, 'CssPacker');
  ForceDirectories(Dir);
  Result := TPath.Combine(Dir, 'settings.ini');
end;

procedure TfrmMain.LoadLanguagePreference;
var
  Ini: TIniFile;
  Code: string;
  Idx: Integer;
begin
  try
    Ini := TIniFile.Create(SettingsFileName);
    try
      Code := Ini.ReadString('UI', 'Language', '');
    finally
      Ini.Free;
    end;
    if Code <> '' then
    begin
      Idx := TCssLang.Codes.IndexOf(TCssLang.NormalizeCode(Code));
      if Idx >= 0 then cboLanguage.ItemIndex := Idx;
    end;
  except
    { keep the auto-detected language if the settings file cannot be read }
  end;
end;

procedure TfrmMain.SaveLanguagePreference;
var
  Ini: TIniFile;
begin
  try
    Ini := TIniFile.Create(SettingsFileName);
    try
      Ini.WriteString('UI', 'Language', TCssLang.CurrentCode);
    finally
      Ini.Free;
    end;
  except
    { preferences are a convenience, never a fatal error }
  end;
end;

procedure TfrmMain.ApplyLanguage;
var
  ModeIdx, IndentIdx, EOLIdx: Integer;
begin
  FApplyingLanguage := True;
  try
    ModeIdx := cboMode.ItemIndex;
    IndentIdx := cboIndent.ItemIndex;
    EOLIdx := cboEOL.ItemIndex;

    Caption := TCssLang.TFormat(TXT_AppTitle, [TCssPacker.Version]);

    btnOpen.Caption := TCssLang.T(TXT_BtnOpen);
    btnSave.Caption := TCssLang.T(TXT_BtnSave);
    btnProcess.Caption := TCssLang.T(TXT_BtnProcess);
    btnSwap.Caption := TCssLang.T(TXT_BtnSwap);
    btnCopy.Caption := TCssLang.T(TXT_BtnCopy);
    btnClear.Caption := TCssLang.T(TXT_BtnClear);

    lblLanguage.Caption := TCssLang.T(TXT_LblLanguage);
    lblInput.Caption := TCssLang.T(TXT_LblInput);
    lblOutput.Caption := TCssLang.T(TXT_LblOutput);
    lblMode.Caption := TCssLang.T(TXT_OptMode);
    lblIndent.Caption := TCssLang.T(TXT_OptIndent);
    lblEOL.Caption := TCssLang.T(TXT_OptEOL);

    SetComboItems(cboMode, [
      TCssLang.T(TXT_ModeAuto),
      TCssLang.T(TXT_ModePackSafe),
      TCssLang.T(TXT_ModePackFast),
      TCssLang.T(TXT_ModeUnpack)
    ], ModeIdx);
    SetComboItems(cboIndent, [
      '1', '2', '3', '4', '5', '6', '7', '8',
      TCssLang.T(TXT_OptTab)
    ], IndentIdx);
    SetComboItems(cboEOL, [
      TCssLang.T(TXT_OpAuto), 'LF', 'CRLF', 'CR'
    ], EOLIdx);

    chkKeepComments.Caption := TCssLang.T(TXT_KeepComments);
    chkLicense.Caption := TCssLang.T(TXT_KeepLicense);
    chkHex.Caption := TCssLang.T(TXT_ShortHex);
    chkZero.Caption := TCssLang.T(TXT_ZeroUnits);
    chkLeadingZero.Caption := TCssLang.T(TXT_LeadingZero);
    chkFinalSemi.Caption := TCssLang.T(TXT_FinalSemi);
    chkCharset.Caption := TCssLang.T(TXT_DropCharset);
    chkBlankLines.Caption := TCssLang.T(TXT_BlankLines);
    chkTabs.Caption := TCssLang.T(TXT_UseTabs);

    ApplyDialogFilters;
    RenderStatus;
    RenderStatusPanels;
  finally
    FApplyingLanguage := False;
  end;
end;

procedure TfrmMain.ApplyDialogFilters;
var
  Filter: string;
begin
  Filter := TCssLang.T(TXT_DlgCssFiles) + '|*.css|' +
            TCssLang.T(TXT_DlgAllFiles) + '|*.*';
  dlgOpen.Filter := Filter;
  dlgSave.Filter := Filter;
end;

procedure TfrmMain.LanguageChanged(Sender: TObject);
begin
  if FApplyingLanguage or (cboLanguage.ItemIndex < 0) then Exit;
  TCssLang.SetLanguage(TCssLang.Codes[cboLanguage.ItemIndex]);
  ApplyLanguage;
  SaveLanguagePreference;
end;

procedure TfrmMain.SetStatus(const ID: string; const Args: array of string);
var
  I: Integer;
begin
  FStatusID := ID;
  SetLength(FStatusArgs, Length(Args));
  for I := 0 to High(Args) do
    FStatusArgs[I] := Args[I];
  RenderStatus;
end;

procedure TfrmMain.RenderStatus;
begin
  if FStatusID <> '' then
    statusBar.Panels[0].Text := TCssLang.TFormat(FStatusID, FStatusArgs);
end;

procedure TfrmMain.RenderStatusPanels;
begin
  if not FHasStats then
  begin
    statusBar.Panels[1].Text := '';
    statusBar.Panels[2].Text := '';
    statusBar.Panels[3].Text := '';
    Exit;
  end;
  statusBar.Panels[1].Text := TCssLang.TFormat(TXT_StatusLines, [
    IntToStr(FLastStats.InputLines), IntToStr(FLastStats.OutputLines)]);
  statusBar.Panels[2].Text := TCssLang.TFormat(TXT_StatusDecls, [
    IntToStr(FLastStats.DeclarationCount)]);
  statusBar.Panels[3].Text := TCssLang.TFormat(TXT_StatusComments, [
    IntToStr(FLastStats.CommentCount)]);
end;

function TfrmMain.GetOptions: TCssOptions;
begin
  Result := TCssOptions.Default;
  case cboMode.ItemIndex of
    1: Result.Operation := coPackSafe;
    2: Result.Operation := coPackAggressive;
    3: Result.Operation := coUnpackPretty;
  else
    Result.Operation := coAuto;
  end;

  if cboIndent.ItemIndex = cboIndent.Items.Count - 1 then
  begin
    Result.UseTabs := True;
    Result.IndentSize := 1;
  end
  else
    Result.IndentSize := StrToIntDef(cboIndent.Text, 2);
  Result.UseTabs := Result.UseTabs or chkTabs.Checked;

  case cboEOL.ItemIndex of
    1: Result.LineEnding := #10;
    2: Result.LineEnding := #13#10;
    3: Result.LineEnding := #13;
  else
    Result.LineEnding := sLineBreak;
  end;

  Result.RemoveComments := not chkKeepComments.Checked;
  Result.KeepLicenseComments := chkLicense.Checked;
  Result.ShortenHexColors := chkHex.Checked;
  Result.RemoveZeroUnits := chkZero.Checked;
  Result.RemoveLeadingZero := chkLeadingZero.Checked;
  Result.RemoveFinalSemicolon := chkFinalSemi.Checked;
  Result.RemoveCharset := chkCharset.Checked;
  Result.BlankLineBetweenRules := chkBlankLines.Checked;
end;

procedure TfrmMain.ModeChanged(Sender: TObject);
begin
  if FApplyingLanguage then Exit;
  case cboMode.ItemIndex of
    2:  { pack-fast: enable optimisations }
      begin
        chkHex.Checked := True;
        chkZero.Checked := True;
        chkLeadingZero.Checked := True;
      end;
  end;
end;

procedure TfrmMain.ButtonOpenClick(Sender: TObject);
var
  Enc: TEncoding;
  HasBOM: Boolean;
  Text: string;
begin
  if not dlgOpen.Execute then Exit;
  try
    Text := TCssPacker.ReadTextFile(dlgOpen.FileName, Enc, HasBOM);
    memInput.Text := Text;
    CurrentFile := dlgOpen.FileName;
    SetStatus(TXT_StatusLoaded, [
      ExtractFileName(CurrentFile), IntToStr(Length(Text))]);
    Caption := 'CssPacker - ' + ExtractFileName(CurrentFile);
  except
    on E: Exception do
      ShowMessage(TCssLang.TFormat(TXT_MsgOpenFailed, [E.Message]));
  end;
end;

procedure TfrmMain.ButtonSaveClick(Sender: TObject);
var
  Enc: TEncoding;
  HasBOM: Boolean;
  Dummy: string;
begin
  if memOutput.Text = '' then
  begin
    ShowMessage(TCssLang.T(TXT_MsgNothingToSave));
    Exit;
  end;
  if not dlgSave.Execute then Exit;
  try
    if (CurrentFile <> '') and FileExists(CurrentFile) then
      Dummy := TCssPacker.ReadTextFile(CurrentFile, Enc, HasBOM)
    else
    begin
      Enc := TEncoding.UTF8;
      HasBOM := False;
    end;
    TCssPacker.WriteTextFile(dlgSave.FileName, memOutput.Text, Enc, HasBOM);
    SetStatus(TXT_StatusSaved, [ExtractFileName(dlgSave.FileName)]);
  except
    on E: Exception do
      ShowMessage(TCssLang.TFormat(TXT_MsgSaveFailed, [E.Message]));
  end;
end;

procedure TfrmMain.ButtonProcessClick(Sender: TObject);
var
  Opts: TCssOptions;
  Stats: TCssStats;
  Output: string;
  EffectiveOp: TCssOperation;
  OpKey: string;
begin
  if memInput.Text = '' then
  begin
    SetStatus(TXT_StatusEmpty, []);
    Exit;
  end;
  try
    Opts := GetOptions;
    Output := TCssPacker.Format(memInput.Text, Opts, Stats);
    memOutput.Text := Output;
    EffectiveOp := Opts.Operation;
    if EffectiveOp = coAuto then
      EffectiveOp := TCssPacker.DetectOperation(memInput.Text);
    case EffectiveOp of
      coPackSafe:      OpKey := TXT_OpPackSafe;
      coPackAggressive: OpKey := TXT_OpPackFast;
      coUnpackPretty:  OpKey := TXT_OpUnpack;
    else
      OpKey := TXT_OpAuto;
    end;
    SetStatus(TXT_StatusDone, [
      TCssLang.T(OpKey),
      IntToStr(Stats.InputBytes),
      IntToStr(Stats.OutputBytes),
      TCssLang.TFormat(TXT_PctSaved, [FormatFloat('0.0', Stats.CompressionPercent)]),
      IntToStr(Stats.RuleCount),
      IntToStr(Stats.ElapsedMs)]);
    FLastStats := Stats;
    FHasStats := True;
    RenderStatusPanels;
  except
    on E: Exception do
      ShowMessage(TCssLang.TFormat(TXT_MsgProcessFailed, [E.Message]));
  end;
end;

procedure TfrmMain.ButtonCopyClick(Sender: TObject);
begin
  if memOutput.Text = '' then Exit;
  Clipboard.AsText := memOutput.Text;
  SetStatus(TXT_StatusCopied, []);
end;

procedure TfrmMain.ButtonSwapClick(Sender: TObject);
var
  T: string;
begin
  T := memInput.Text;
  memInput.Text := memOutput.Text;
  memOutput.Text := T;
  SetStatus(TXT_StatusSwapped, []);
end;

procedure TfrmMain.ButtonClearClick(Sender: TObject);
begin
  memInput.Clear;
  memOutput.Clear;
  CurrentFile := '';
  FHasStats := False;
  Caption := TCssLang.TFormat(TXT_AppTitle, [TCssPacker.Version]);
  SetStatus(TXT_StatusCleared, []);
  RenderStatusPanels;
end;

end.
