program CssPackerGui;

uses
  Vcl.Forms,
  System.SysUtils,
  CssPackerGuiMain in 'CssPackerGuiMain.pas',
  CssPacker.Core in '..\Lib\CssPacker.Core.pas';

{$R *.res}

var
  frmMain: TfrmMain;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'CssPacker';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
