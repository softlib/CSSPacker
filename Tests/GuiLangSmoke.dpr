program GuiLangSmoke;

{$APPTYPE CONSOLE}

{ Creates the real VCL form, switches the UI language at runtime, and dumps
  the resulting captions so the DFM + localisation wiring can be verified. }

uses
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  CssPackerGuiMain in '..\GUI\CssPackerGuiMain.pas',
  CssPacker.Lang in '..\Lib\CssPacker.Lang.pas';

var
  F: TfrmMain;
  L: TStringList;
  Idx: Integer;

procedure SwitchTo(const Code, Tag: string);
begin
  Idx := TCssLang.Codes.IndexOf(Code);
  if Idx < 0 then raise Exception.Create('missing language: ' + Code);
  F.cboLanguage.ItemIndex := Idx;
  F.cboLanguage.OnChange(F.cboLanguage);
  L.Add(Tag + '_btnopen=' + F.btnOpen.Caption);
  L.Add(Tag + '_lblinput=' + F.lblInput.Caption);
  L.Add(Tag + '_status=' + F.statusBar.Panels[0].Text);
end;

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, F);
  L := TStringList.Create;
  try
    L.Add('lang_count=' + IntToStr(F.cboLanguage.Items.Count));
    L.Add('initial_btnopen=' + F.btnOpen.Caption);
    SwitchTo('zh-CN', 'zh');
    SwitchTo('ja', 'ja');
    SwitchTo('it', 'it');
    L.Add('ja_mode0=' + F.cboMode.Items[0]);
    L.SaveToFile(ChangeFileExt(ParamStr(0), '.txt'));
  finally
    L.Free;
    F.Free;
    Application.Terminate;
  end;
end.
