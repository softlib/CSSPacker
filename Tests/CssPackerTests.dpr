program CssPackerTests;

{$APPTYPE CONSOLE}

{------------------------------------------------------------------------------
  CssPacker test suite - validates the three modes, round-trips, semantics and
  edge cases (strings, comments, URLs, calc, nested at-rules, data URIs).
------------------------------------------------------------------------------}

uses
  System.SysUtils,
  System.StrUtils,
  System.IOUtils,
  CssPacker.Core in '..\Lib\CssPacker.Core.pas',
  CssPacker.Lang in '..\Lib\CssPacker.Lang.pas';

var
  Passed, Failed: Integer;

procedure Check(const Name: string; Condition: Boolean; const Detail: string = '');
begin
  if Condition then
  begin
    Inc(Passed);
    WriteLn('  [PASS] ', Name);
  end
  else
  begin
    Inc(Failed);
    WriteLn('  [FAIL] ', Name, '   ', Detail);
  end;
end;

procedure CheckEqual(const Name, Actual, Expected: string);
begin
  Check(Name, Actual = Expected,
    Format('expected <%s> got <%s>', [Expected, Actual]));
end;

function Contains(const S, Sub: string): Boolean;
begin
  Result := Pos(Sub, S) > 0;
end;

procedure TestPackSafeWhitespace;
var
  O: TCssOptions;
  Outp: string;
begin
  WriteLn('Test: pack-safe whitespace and delimiters');
  O := TCssOptions.Default;
  O.Operation := coPackSafe;

  Outp := TCssPacker.Pack('body { color : red ;  margin: 0px  auto ; }', O);
  CheckEqual('single-line minify', 'body{color:red;margin:0px auto;}', Outp);

  Outp := TCssPacker.Pack('a:hover, b > c { content: "hello world"; }', O);
  Check('selector combinators preserved', Contains(Outp, 'a:hover,b>c'), Outp);
  Check('string preserved', Contains(Outp, '"hello world"'), Outp);

  Outp := TCssPacker.Pack('div   span{ color:red }', O);
  Check('descendant combinator kept', Contains(Outp, 'div span'), Outp);
end;

procedure TestPackSafeSemantics;
var
  O: TCssOptions;
  Outp: string;
begin
  WriteLn('Test: pack-safe preserves semantics');
  O := TCssOptions.Default;
  O.Operation := coPackSafe;

  Outp := TCssPacker.Pack('a { margin: calc(100% - 20px); }', O);
  Check('calc operators spaced', Contains(Outp, 'calc(100% - 20px)'), Outp);

  Outp := TCssPacker.Pack('a { background: url(data:image/png;base64,AAA==) no-repeat; }', O);
  Check('data URI untouched', Contains(Outp, 'url(data:image/png;base64,AAA==)'), Outp);

  Outp := TCssPacker.Pack('a { font: 12pt/14pt sans-serif; }', O);
  Check('slash in font shorthand', Contains(Outp, '12pt/14pt'), Outp);

  Outp := TCssPacker.Pack('a { margin: 0 -5px; }', O);
  Check('negative value spaced', Contains(Outp, '0 -5px'), Outp);
end;

procedure TestComments;
var
  O: TCssOptions;
  Outp: string;
begin
  WriteLn('Test: comment handling');
  O := TCssOptions.Default;
  O.Operation := coPackSafe;

  Outp := TCssPacker.Pack('/* regular */ a{color:red}', O);
  Check('comment removed', not Contains(Outp, 'regular'), Outp);
  Check('no leftover comment body', not Contains(Outp, '/*'), Outp);

  Outp := TCssPacker.Pack('/*! license */ a{color:red}', O);
  Check('license comment preserved', Contains(Outp, '/*! license */'), Outp);

  O.KeepLicenseComments := False;
  Outp := TCssPacker.Pack('/*! license */ a{color:red}', O);
  Check('license removal optional', not Contains(Outp, 'license'), Outp);

  O.RemoveComments := False;
  Outp := TCssPacker.Pack('/* keep me */ a{color:red}', O);
  Check('keep-comments option', Contains(Outp, '/* keep me */'), Outp);
end;

procedure TestAggressive;
var
  O: TCssOptions;
  Outp: string;
begin
  WriteLn('Test: aggressive (bootstrap-style) optimisations');
  O := TCssOptions.Default;
  O.Operation := coPackAggressive;
  O.ShortenHexColors := True;
  O.RemoveZeroUnits := True;
  O.RemoveLeadingZero := True;
  O.RemoveFinalSemicolon := True;

  Outp := TCssPacker.Pack('a{color:#aabbcc}', O);
  CheckEqual('hex shortened', 'a{color:#abc}', Outp);

  Outp := TCssPacker.Pack('a{margin:0px}', O);
  CheckEqual('zero unit removed', 'a{margin:0}', Outp);

  Outp := TCssPacker.Pack('a{opacity:0.5}', O);
  CheckEqual('leading zero removed', 'a{opacity:.5}', Outp);

  Outp := TCssPacker.Pack('a{color:red;}', O);
  CheckEqual('final semicolon dropped', 'a{color:red}', Outp);

  { hex shortening must NOT change ID selectors }
  Outp := TCssPacker.Pack('#aabbcc{color:red}', O);
  Check('ID selector untouched', Contains(Outp, '#aabbcc'), Outp);

  { hex shortening must NOT change strings }
  Outp := TCssPacker.Pack('a{content:"#aabbcc"}', O);
  Check('string hex untouched', Contains(Outp, '"#aabbcc"'), Outp);
end;

procedure TestUnpackPretty;
var
  O: TCssOptions;
  Outp: string;
begin
  WriteLn('Test: unpack pretty printing');
  O := TCssOptions.Default;
  O.Operation := coUnpackPretty;
  O.LineEnding := #10;

  Outp := TCssPacker.Unpack('body{background:black;color:#80c0c0}a:link{color:#ff8080}', O);
  Check('opening brace formatted', Contains(Outp, 'body {'#10), Outp);
  Check('declaration indented', Contains(Outp, '  background: black;'), Outp);
  Check('pseudo-class not spaced', Contains(Outp, 'a:link {'), Outp);
  Check('closing brace on own line', Contains(Outp, #10'}'), Outp);

  Outp := TCssPacker.Unpack('@media screen and (max-width:600px){.a{color:red}}', O);
  Check('nested at-rule indent', Contains(Outp, '  .a {'), Outp);
  Check('media query intact', Contains(Outp, 'max-width:600px'), Outp);
end;

procedure TestRoundTrip;
var
  O: TCssOptions;
  Original, PackedText, Pretty, Repacked: string;
begin
  WriteLn('Test: round-trip packing');
  O := TCssOptions.Default;
  O.Operation := coPackSafe;

  Original := 'div.foo{color:#aabbcc;margin:10px 20px}a:hover{background:url(x.png) no-repeat}';
  PackedText := TCssPacker.Pack(Original, O);
  Pretty := TCssPacker.Unpack(PackedText, O);
  Repacked := TCssPacker.Pack(Pretty, O);
  CheckEqual('pack(unpack(pack(x))) == pack(x)', Repacked, PackedText);

  { packing twice must be idempotent }
  CheckEqual('pack is idempotent', TCssPacker.Pack(PackedText, O), PackedText);
end;

procedure TestAutoDetect;
begin
  WriteLn('Test: auto detection');
  Check('long single line => unpack',
    TCssPacker.DetectOperation('a{color:red}b{color:blue}' + StringOfChar('x', 400)) = coUnpackPretty, '');
  Check('multi-line indented => pack',
    TCssPacker.DetectOperation('a {'#10'  color: red;'#10'}'#10) = coPackSafe, '');
end;

procedure TestFileIO;
var
  O: TCssOptions;
  InFile, OutFile: string;
  Stats: TCssStats;
  Text: string;
begin
  WriteLn('Test: file IO');
  O := TCssOptions.Default;
  O.Operation := coPackSafe;
  InFile := IncludeTrailingPathDelimiter(GetCurrentDir) + 'TestData' + PathDelim + 'Example.css';
  OutFile := IncludeTrailingPathDelimiter(GetCurrentDir) + 'TestData' + PathDelim + 'Example.test.min.css';

  if FileExists(InFile) then
  begin
    Stats := TCssPacker.ProcessFile(InFile, OutFile, O);
    Check('output file created', FileExists(OutFile), OutFile);
    Check('stats have input bytes', Stats.InputBytes > 0, Stats.ToString);
    Text := TFile.ReadAllText(OutFile);
    Check('output is minified', (Pos('body{', Text) > 0) and (Pos(#10, Text) = 0), '');
    DeleteFile(OutFile);
  end
  else
    WriteLn('  [SKIP] file IO test (Example.css not found)');
end;

procedure TestLegacyBridge;
var
  Outp: string;
begin
  WriteLn('Test: legacy cssunpack.pas bridge');
  Outp := TCssPacker.LegacyFormat('a{color:red}', coUnpackPretty);
  Check('legacy engine callable', Length(Outp) > 0, Outp);
  Check('legacy output has newline', Pos(#10, Outp) > 0, Outp);
end;

procedure TestLocalisation;
const
  BuiltInCodes: array[0..8] of string = (
    'en', 'zh-CN', 'zh-TW', 'ja', 'ko', 'de', 'fr', 'es', 'ru');
  IDs: array[0..48] of string = (
    TXT_AppTitle, TXT_BtnOpen, TXT_BtnSave, TXT_BtnProcess, TXT_BtnSwap,
    TXT_BtnCopy, TXT_BtnClear, TXT_LblLanguage, TXT_LblInput, TXT_LblOutput,
    TXT_OptMode, TXT_ModeAuto, TXT_ModePackSafe, TXT_ModePackFast,
    TXT_ModeUnpack, TXT_OptIndent, TXT_OptTab, TXT_OptEOL, TXT_KeepComments,
    TXT_KeepLicense, TXT_ShortHex, TXT_ZeroUnits, TXT_LeadingZero,
    TXT_FinalSemi, TXT_DropCharset, TXT_BlankLines, TXT_UseTabs,
    TXT_StatusReady, TXT_StatusLoaded, TXT_StatusSaved, TXT_StatusDone,
    TXT_PctSaved, TXT_StatusLines, TXT_StatusDecls, TXT_StatusComments,
    TXT_StatusCopied, TXT_StatusSwapped, TXT_StatusCleared, TXT_StatusEmpty,
    TXT_MsgNothingToSave, TXT_MsgOpenFailed, TXT_MsgSaveFailed,
    TXT_MsgProcessFailed, TXT_DlgCssFiles, TXT_DlgAllFiles,
    TXT_OpAuto, TXT_OpPackSafe, TXT_OpPackFast, TXT_OpUnpack
  );
var
  I, J, Missing: Integer;
  Code, S, Fmt: string;
begin
  WriteLn('Test: localisation engine');
  Check('built-in languages present', TCssLang.Codes.Count >= 9,
    IntToStr(TCssLang.Codes.Count));
  Check('system language resolves', TCssLang.IsValidCode(TCssLang.DetectSystem),
    TCssLang.DetectSystem);
  for I := 0 to High(BuiltInCodes) do
  begin
    Code := BuiltInCodes[I];
    TCssLang.SetLanguage(Code);
    Missing := 0;
    for J := 0 to High(IDs) do
    begin
      S := TCssLang.T(IDs[J]);
      if (S = '') or (S = IDs[J]) then Inc(Missing);
    end;
    Check('all strings translated: ' + Code, Missing = 0,
      IntToStr(Missing) + ' missing');
  end;
  TCssLang.SetLanguage('en');
  Fmt := TCssLang.TFormat(TXT_StatusLoaded, ['a.css', '123']);
  Check('format substitutes all args',
    (Pos('a.css', Fmt) > 0) and (Pos('123', Fmt) > 0) and (Pos('%s', Fmt) = 0), Fmt);
  TCssLang.SetLanguage('zh-CN');
  Fmt := TCssLang.TFormat(TXT_StatusLoaded, ['a.css', '123']);
  Check('format works for CJK translations',
    (Pos('a.css', Fmt) > 0) and (Pos('%s', Fmt) = 0), Fmt);
  TCssLang.SetLanguage('it');
  Check('external UTF-8 language pack loaded',
    TCssLang.IsValidCode('it') and (TCssLang.T(TXT_BtnOpen) = 'Apri...'),
    TCssLang.T(TXT_BtnOpen));
  TCssLang.SetLanguage('en');
end;

begin
  WriteLn('============================================================');
  WriteLn('CssPacker test suite  [', TCssPacker.Version, ']');
  WriteLn('============================================================');
  Passed := 0;
  Failed := 0;

  TestPackSafeWhitespace;
  TestPackSafeSemantics;
  TestComments;
  TestAggressive;
  TestUnpackPretty;
  TestRoundTrip;
  TestAutoDetect;
  TestFileIO;
  TestLegacyBridge;
  TestLocalisation;

  WriteLn('============================================================');
  WriteLn(Format('Results: %d passed, %d failed', [Passed, Failed]));
  WriteLn('============================================================');

  if Failed > 0 then Halt(1);
end.
