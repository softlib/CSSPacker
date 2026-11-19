unit CssPacker.Lang;

{------------------------------------------------------------------------------
  CssPacker.Lang.pas

  Lightweight localisation engine used by the CssPacker GUI.

  Features
    - Nine built-in languages (en, zh-CN, zh-TW, ja, ko, de, fr, es, ru).
    - Runtime language switching: no restart, no recompilation.
    - External language packs: drop an INI file into the "lang" folder next to
      the executable to add a brand-new language or override existing strings.
    - Automatic detection of the operating system UI language.
    - All translated texts are looked up by stable string IDs (TXT_*).

  External pack format (e.g. lang/it.ini):

    [Lang]
    Name=Italiano
    Code=it
    [Strings]
    btn.open=Apri...
    btn.save=Salva...
    ...

  Only the keys you want to change need to be present; missing keys fall back
  to English and then to the raw key name.
------------------------------------------------------------------------------}

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.IniFiles;

const
  { ---- string IDs ---- }
  TXT_AppTitle        = 'app.title';
  TXT_BtnOpen         = 'btn.open';
  TXT_BtnSave         = 'btn.save';
  TXT_BtnProcess      = 'btn.process';
  TXT_BtnSwap         = 'btn.swap';
  TXT_BtnCopy         = 'btn.copy';
  TXT_BtnClear        = 'btn.clear';
  TXT_LblLanguage     = 'lbl.language';
  TXT_LblInput        = 'lbl.input';
  TXT_LblOutput       = 'lbl.output';
  TXT_OptMode         = 'opt.mode';
  TXT_ModeAuto        = 'opt.mode.auto';
  TXT_ModePackSafe    = 'opt.mode.packsafe';
  TXT_ModePackFast    = 'opt.mode.packfast';
  TXT_ModeUnpack      = 'opt.mode.unpack';
  TXT_OptIndent       = 'opt.indent';
  TXT_OptTab          = 'opt.tab';
  TXT_OptEOL          = 'opt.eol';
  TXT_KeepComments    = 'opt.keepcomments';
  TXT_KeepLicense     = 'opt.license';
  TXT_ShortHex        = 'opt.hex';
  TXT_ZeroUnits       = 'opt.zero';
  TXT_LeadingZero     = 'opt.leadingzero';
  TXT_FinalSemi       = 'opt.finalsemi';
  TXT_DropCharset     = 'opt.charset';
  TXT_BlankLines      = 'opt.blanklines';
  TXT_UseTabs         = 'opt.tabs';
  TXT_StatusReady     = 'status.ready';
  TXT_StatusLoaded    = 'status.loaded';
  TXT_StatusSaved     = 'status.saved';
  TXT_StatusDone      = 'status.done';
  TXT_PctSaved        = 'fmt.saved';
  TXT_StatusLines     = 'status.lines';
  TXT_StatusDecls     = 'status.declarations';
  TXT_StatusComments  = 'status.comments';
  TXT_StatusCopied    = 'status.copied';
  TXT_StatusSwapped   = 'status.swapped';
  TXT_StatusCleared   = 'status.cleared';
  TXT_StatusEmpty     = 'status.emptyinput';
  TXT_MsgNothingToSave= 'msg.nothingtosave';
  TXT_MsgOpenFailed   = 'msg.openfailed';
  TXT_MsgSaveFailed   = 'msg.savefailed';
  TXT_MsgProcessFailed= 'msg.processfailed';
  TXT_DlgCssFiles     = 'dlg.cssfiles';
  TXT_DlgAllFiles     = 'dlg.allfiles';
  TXT_OpAuto          = 'op.auto';
  TXT_OpPackSafe      = 'op.packsafe';
  TXT_OpPackFast      = 'op.packfast';
  TXT_OpUnpack        = 'op.unpack';

type
  TCssLang = class
  private
    class var FCurrentCode: string;
    class var FCodes: TStringList;
    class var FNames: TDictionary<string, string>;
    class var FStrings: TDictionary<string, string>;
    class procedure AddLanguage(const Code, Name: string; const Pairs: array of string); static;
    class procedure LoadBuiltIn; static;
    class procedure LoadExternalPacks; static;
  public
    class constructor Create;
    class destructor Destroy;
    class function Codes: TStringList; static;
    class function IsValidCode(const Code: string): Boolean; static;
    class function NormalizeCode(const Code: string): string; static;
    class function DetectSystem: string; static;
    class procedure SetLanguage(const Code: string); static;
    class function CurrentCode: string; static;
    class function CurrentName: string; static;
    class function DisplayName(const Code: string): string; static;
    class function T(const ID: string): string; static;
    class function TFormat(const ID: string; const Args: array of string): string; static;
  end;

implementation

{ TCssLang }

class constructor TCssLang.Create;
begin
  FCodes := TStringList.Create;
  FCodes.CaseSensitive := False;
  FNames := TDictionary<string, string>.Create;
  FStrings := TDictionary<string, string>.Create;
  FCurrentCode := 'en';
  LoadBuiltIn;
  LoadExternalPacks;
end;

class destructor TCssLang.Destroy;
begin
  FStrings.Free;
  FNames.Free;
  FCodes.Free;
end;

class procedure TCssLang.AddLanguage(const Code, Name: string;
  const Pairs: array of string);
var
  I: Integer;
  Key: string;
begin
  if FCodes.IndexOf(Code) < 0 then
    FCodes.Add(Code);
  FNames.AddOrSetValue(Code, Name);
  I := 0;
  while I + 1 <= High(Pairs) do
  begin
    Key := Code + '|' + Pairs[I];
    FStrings.AddOrSetValue(Key, Pairs[I + 1]);
    Inc(I, 2);
  end;
end;

class function TCssLang.Codes: TStringList;
begin
  Result := FCodes;
end;

class function TCssLang.NormalizeCode(const Code: string): string;
var
  C: string;
  I: Integer;
begin
  C := LowerCase(Trim(Code));
  C := StringReplace(C, '_', '-', [rfReplaceAll]);
  if C = 'zh-hans' then C := 'zh-cn'
  else if C = 'zh-hant' then C := 'zh-tw'
  else if C = 'zh' then C := 'zh-cn';
  for I := 0 to FCodes.Count - 1 do
    if LowerCase(FCodes[I]) = C then
      Exit(FCodes[I]);
  Result := Code;
end;

class function TCssLang.IsValidCode(const Code: string): Boolean;
begin
  Result := FCodes.IndexOf(NormalizeCode(Code)) >= 0;
end;

class function TCssLang.DetectSystem: string;
var
  Buf: array[0..85] of Char;
  Len: Integer;
  S, Primary: string;
  P: Integer;
begin
  Result := 'en';
  Len := GetLocaleInfo(LOCALE_USER_DEFAULT, LOCALE_SNAME, Buf, Length(Buf));
  if Len <= 1 then Exit;
  S := string(Buf);
  Result := NormalizeCode(S);
  if IsValidCode(Result) then Exit;
  P := Pos('-', S);
  if P > 0 then Primary := Copy(S, 1, P - 1) else Primary := S;
  Result := NormalizeCode(Primary);
  if not IsValidCode(Result) then Result := 'en';
end;

class procedure TCssLang.SetLanguage(const Code: string);
begin
  if IsValidCode(Code) then
    FCurrentCode := NormalizeCode(Code);
end;

class function TCssLang.CurrentCode: string;
begin
  Result := FCurrentCode;
end;

class function TCssLang.CurrentName: string;
begin
  Result := DisplayName(FCurrentCode);
end;

class function TCssLang.DisplayName(const Code: string): string;
begin
  if not FNames.TryGetValue(Code, Result) then
    Result := Code;
end;

class function TCssLang.T(const ID: string): string;
begin
  if not FStrings.TryGetValue(FCurrentCode + '|' + ID, Result) then
    if not FStrings.TryGetValue('en|' + ID, Result) then
      Result := ID;
end;

class function TCssLang.TFormat(const ID: string; const Args: array of string): string;
var
  V: array of TVarRec;
  I: Integer;
begin
  SetLength(V, Length(Args));
  for I := 0 to High(Args) do
  begin
    V[I].VType := vtUnicodeString;
    V[I].VUnicodeString := PChar(Args[I]);
  end;
  Result := Format(T(ID), V);
end;

class procedure TCssLang.LoadExternalPacks;
var
  Dir: string;
  Files, Values: TStringList;
  Ini: TMemIniFile;
  I, J: Integer;
  FileName, Code, Name: string;
  Pairs: TArray<string>;
begin
  Dir := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'lang';
  if not DirectoryExists(Dir) then Exit;
  Files := TStringList.Create;
  Values := TStringList.Create;
  try
    Files.AddStrings(TDirectory.GetFiles(Dir, '*.ini'));
    for I := 0 to Files.Count - 1 do
    begin
      FileName := Files[I];
      Code := ChangeFileExt(ExtractFileName(FileName), '');
      try
        Ini := TMemIniFile.Create(FileName, TEncoding.UTF8);
        try
          Name := Ini.ReadString('Lang', 'Name', '');
          if Ini.ValueExists('Lang', 'Code') then
            Code := Ini.ReadString('Lang', 'Code', Code);
          if Name = '' then Name := Code;
          Values.Clear;
          Ini.ReadSectionValues('Strings', Values);
          SetLength(Pairs, Values.Count * 2);
          J := 0;
          for var K := 0 to Values.Count - 1 do
          begin
            Pairs[J] := Values.Names[K];
            Pairs[J + 1] := Values.ValueFromIndex[K];
            Inc(J, 2);
          end;
          AddLanguage(Code, Name, Pairs);
        finally
          Ini.Free;
        end;
      except
        { an invalid language pack must never prevent the application from starting }
      end;
    end;
  finally
    Values.Free;
    Files.Free;
  end;
end;

class procedure TCssLang.LoadBuiltIn;
begin
  { ---------------------------------- English -------------------------------- }
  AddLanguage('en', 'English', [
    TXT_AppTitle, 'CssPacker - Universal CSS Pack / Unpack Tool  [%s]',
    TXT_BtnOpen, 'Open...',
    TXT_BtnSave, 'Save...',
    TXT_BtnProcess, 'Process',
    TXT_BtnSwap, 'Swap',
    TXT_BtnCopy, 'Copy Output',
    TXT_BtnClear, 'Clear',
    TXT_LblLanguage, 'Language:',
    TXT_LblInput, 'INPUT CSS',
    TXT_LblOutput, 'OUTPUT CSS',
    TXT_OptMode, 'Mode:',
    TXT_ModeAuto, 'auto  (detect)',
    TXT_ModePackSafe, 'pack-safe  (minify)',
    TXT_ModePackFast, 'pack-fast  (aggressive)',
    TXT_ModeUnpack, 'unpack  (pretty print)',
    TXT_OptIndent, 'Indent:',
    TXT_OptTab, 'tab',
    TXT_OptEOL, 'Line ending:',
    TXT_KeepComments, 'Keep comments',
    TXT_KeepLicense, 'Keep /*! license',
    TXT_ShortHex, 'Shorten hex',
    TXT_ZeroUnits, '0px -> 0',
    TXT_LeadingZero, '0.5 -> .5',
    TXT_FinalSemi, 'Drop last ;',
    TXT_DropCharset, 'Drop @charset',
    TXT_BlankLines, 'Blank lines',
    TXT_UseTabs, 'Use tabs',
    TXT_StatusReady, 'Ready - load a CSS file or paste CSS into the input pane.',
    TXT_StatusLoaded, 'Loaded: %s  (%s chars)',
    TXT_StatusSaved, 'Saved: %s',
    TXT_StatusDone, 'Done: %s | %s -> %s bytes (%s) | %s rules | %s ms',
    TXT_PctSaved, '%s%% saved',
    TXT_StatusLines, 'Lines: %s -> %s',
    TXT_StatusDecls, 'Declarations: %s',
    TXT_StatusComments, 'Comments: %s',
    TXT_StatusCopied, 'Output copied to clipboard.',
    TXT_StatusSwapped, 'Input / output swapped.',
    TXT_StatusCleared, 'Cleared.',
    TXT_StatusEmpty, 'Input is empty.',
    TXT_MsgNothingToSave, 'Nothing to save. Run Process first.',
    TXT_MsgOpenFailed, 'Open failed: %s',
    TXT_MsgSaveFailed, 'Save failed: %s',
    TXT_MsgProcessFailed, 'Processing failed: %s',
    TXT_DlgCssFiles, 'CSS files (*.css)',
    TXT_DlgAllFiles, 'All files (*.*)',
    TXT_OpAuto, 'auto',
    TXT_OpPackSafe, 'pack-safe',
    TXT_OpPackFast, 'pack-fast',
    TXT_OpUnpack, 'unpack'
  ]);

  { ---------------------------- Simplified Chinese --------------------------- }
  AddLanguage('zh-CN', '简体中文', [
    TXT_AppTitle, 'CssPacker - 通用 CSS 压缩 / 解压工具  [%s]',
    TXT_BtnOpen, '打开...',
    TXT_BtnSave, '保存...',
    TXT_BtnProcess, '处理',
    TXT_BtnSwap, '交换',
    TXT_BtnCopy, '复制结果',
    TXT_BtnClear, '清空',
    TXT_LblLanguage, '语言：',
    TXT_LblInput, '输入 CSS',
    TXT_LblOutput, '输出 CSS',
    TXT_OptMode, '模式：',
    TXT_ModeAuto, '自动（检测）',
    TXT_ModePackSafe, '安全压缩（精简）',
    TXT_ModePackFast, '快速压缩（激进）',
    TXT_ModeUnpack, '解压（格式化）',
    TXT_OptIndent, '缩进：',
    TXT_OptTab, '制表符',
    TXT_OptEOL, '换行符：',
    TXT_KeepComments, '保留注释',
    TXT_KeepLicense, '保留 /*! 许可',
    TXT_ShortHex, '缩短颜色值',
    TXT_ZeroUnits, '0px → 0',
    TXT_LeadingZero, '0.5 → .5',
    TXT_FinalSemi, '去掉末尾分号',
    TXT_DropCharset, '去掉 @charset',
    TXT_BlankLines, '规则间空行',
    TXT_UseTabs, '使用制表符',
    TXT_StatusReady, '就绪 - 打开 CSS 文件或将 CSS 粘贴到输入区。',
    TXT_StatusLoaded, '已加载：%s（%s 字符）',
    TXT_StatusSaved, '已保存：%s',
    TXT_StatusDone, '完成：%s | %s → %s 字节（%s） | %s 条规则 | %s 毫秒',
    TXT_PctSaved, '节省 %s%%',
    TXT_StatusLines, '行数：%s → %s',
    TXT_StatusDecls, '声明：%s',
    TXT_StatusComments, '注释：%s',
    TXT_StatusCopied, '结果已复制到剪贴板。',
    TXT_StatusSwapped, '已交换输入 / 输出。',
    TXT_StatusCleared, '已清空。',
    TXT_StatusEmpty, '输入为空。',
    TXT_MsgNothingToSave, '没有可保存的内容，请先执行“处理”。',
    TXT_MsgOpenFailed, '打开失败：%s',
    TXT_MsgSaveFailed, '保存失败：%s',
    TXT_MsgProcessFailed, '处理失败：%s',
    TXT_DlgCssFiles, 'CSS 文件 (*.css)',
    TXT_DlgAllFiles, '所有文件 (*.*)',
    TXT_OpAuto, '自动',
    TXT_OpPackSafe, '安全压缩',
    TXT_OpPackFast, '快速压缩',
    TXT_OpUnpack, '格式化'
  ]);

  { ---------------------------- Traditional Chinese -------------------------- }
  AddLanguage('zh-TW', '繁體中文', [
    TXT_AppTitle, 'CssPacker - 通用 CSS 壓縮 / 解壓工具  [%s]',
    TXT_BtnOpen, '開啟...',
    TXT_BtnSave, '儲存...',
    TXT_BtnProcess, '處理',
    TXT_BtnSwap, '交換',
    TXT_BtnCopy, '複製結果',
    TXT_BtnClear, '清空',
    TXT_LblLanguage, '語言：',
    TXT_LblInput, '輸入 CSS',
    TXT_LblOutput, '輸出 CSS',
    TXT_OptMode, '模式：',
    TXT_ModeAuto, '自動（偵測）',
    TXT_ModePackSafe, '安全壓縮（精簡）',
    TXT_ModePackFast, '快速壓縮（積極）',
    TXT_ModeUnpack, '解壓（格式化）',
    TXT_OptIndent, '縮排：',
    TXT_OptTab, '定位點',
    TXT_OptEOL, '換行符：',
    TXT_KeepComments, '保留註解',
    TXT_KeepLicense, '保留 /*! 授權',
    TXT_ShortHex, '縮短色碼',
    TXT_ZeroUnits, '0px → 0',
    TXT_LeadingZero, '0.5 → .5',
    TXT_FinalSemi, '移除末尾分號',
    TXT_DropCharset, '移除 @charset',
    TXT_BlankLines, '規則間空行',
    TXT_UseTabs, '使用定位點',
    TXT_StatusReady, '就緒 - 開啟 CSS 檔案或將 CSS 貼到輸入區。',
    TXT_StatusLoaded, '已載入：%s（%s 字元）',
    TXT_StatusSaved, '已儲存：%s',
    TXT_StatusDone, '完成：%s | %s → %s 位元組（%s） | %s 條規則 | %s 毫秒',
    TXT_PctSaved, '節省 %s%%',
    TXT_StatusLines, '行數：%s → %s',
    TXT_StatusDecls, '宣告：%s',
    TXT_StatusComments, '註解：%s',
    TXT_StatusCopied, '結果已複製到剪貼簿。',
    TXT_StatusSwapped, '已交換輸入 / 輸出。',
    TXT_StatusCleared, '已清空。',
    TXT_StatusEmpty, '輸入為空。',
    TXT_MsgNothingToSave, '沒有可儲存的內容，請先執行「處理」。',
    TXT_MsgOpenFailed, '開啟失敗：%s',
    TXT_MsgSaveFailed, '儲存失敗：%s',
    TXT_MsgProcessFailed, '處理失敗：%s',
    TXT_DlgCssFiles, 'CSS 檔案 (*.css)',
    TXT_DlgAllFiles, '所有檔案 (*.*)',
    TXT_OpAuto, '自動',
    TXT_OpPackSafe, '安全壓縮',
    TXT_OpPackFast, '快速壓縮',
    TXT_OpUnpack, '格式化'
  ]);

  { ---------------------------------- Japanese ------------------------------- }
  AddLanguage('ja', '日本語', [
    TXT_AppTitle, 'CssPacker - 汎用 CSS 圧縮 / 展開ツール  [%s]',
    TXT_BtnOpen, '開く...',
    TXT_BtnSave, '保存...',
    TXT_BtnProcess, '実行',
    TXT_BtnSwap, '入替',
    TXT_BtnCopy, '結果をコピー',
    TXT_BtnClear, 'クリア',
    TXT_LblLanguage, '言語：',
    TXT_LblInput, '入力 CSS',
    TXT_LblOutput, '出力 CSS',
    TXT_OptMode, 'モード：',
    TXT_ModeAuto, '自動（検出）',
    TXT_ModePackSafe, '安全圧縮（最小化）',
    TXT_ModePackFast, '高速圧縮（積極）',
    TXT_ModeUnpack, '展開（整形）',
    TXT_OptIndent, 'インデント：',
    TXT_OptTab, 'タブ',
    TXT_OptEOL, '改行コード：',
    TXT_KeepComments, 'コメントを保持',
    TXT_KeepLicense, '/*! ライセンスを保持',
    TXT_ShortHex, '16進数を短縮',
    TXT_ZeroUnits, '0px → 0',
    TXT_LeadingZero, '0.5 → .5',
    TXT_FinalSemi, '末尾の ; を削除',
    TXT_DropCharset, '@charset を削除',
    TXT_BlankLines, 'ルール間に空行',
    TXT_UseTabs, 'タブを使用',
    TXT_StatusReady, '準備完了 - CSS ファイルを開くか、入力欄に貼り付けてください。',
    TXT_StatusLoaded, '読み込み：%s（%s 文字）',
    TXT_StatusSaved, '保存：%s',
    TXT_StatusDone, '完了：%s | %s → %s バイト（%s） | %s ルール | %s ms',
    TXT_PctSaved, '%s%% 削減',
    TXT_StatusLines, '行数：%s → %s',
    TXT_StatusDecls, '宣言：%s',
    TXT_StatusComments, 'コメント：%s',
    TXT_StatusCopied, '結果をクリップボードにコピーしました。',
    TXT_StatusSwapped, '入力 / 出力を入れ替えました。',
    TXT_StatusCleared, 'クリアしました。',
    TXT_StatusEmpty, '入力が空です。',
    TXT_MsgNothingToSave, '保存する内容がありません。先に「実行」してください。',
    TXT_MsgOpenFailed, '開けませんでした：%s',
    TXT_MsgSaveFailed, '保存できませんでした：%s',
    TXT_MsgProcessFailed, '処理に失敗しました：%s',
    TXT_DlgCssFiles, 'CSS ファイル (*.css)',
    TXT_DlgAllFiles, 'すべてのファイル (*.*)',
    TXT_OpAuto, '自動',
    TXT_OpPackSafe, '安全圧縮',
    TXT_OpPackFast, '高速圧縮',
    TXT_OpUnpack, '整形'
  ]);

  { ----------------------------------- Korean -------------------------------- }
  AddLanguage('ko', '한국어', [
    TXT_AppTitle, 'CssPacker - 범용 CSS 압축 / 해제 도구  [%s]',
    TXT_BtnOpen, '열기...',
    TXT_BtnSave, '저장...',
    TXT_BtnProcess, '실행',
    TXT_BtnSwap, '교환',
    TXT_BtnCopy, '결과 복사',
    TXT_BtnClear, '지우기',
    TXT_LblLanguage, '언어:',
    TXT_LblInput, '입력 CSS',
    TXT_LblOutput, '출력 CSS',
    TXT_OptMode, '모드:',
    TXT_ModeAuto, '자동 (감지)',
    TXT_ModePackSafe, '안전 압축 (최소화)',
    TXT_ModePackFast, '고속 압축 (적극적)',
    TXT_ModeUnpack, '해제 (정렬)',
    TXT_OptIndent, '들여쓰기:',
    TXT_OptTab, '탭',
    TXT_OptEOL, '줄바꿈:',
    TXT_KeepComments, '주석 유지',
    TXT_KeepLicense, '/*! 라이선스 유지',
    TXT_ShortHex, '16진수 단축',
    TXT_ZeroUnits, '0px → 0',
    TXT_LeadingZero, '0.5 → .5',
    TXT_FinalSemi, '마지막 ; 제거',
    TXT_DropCharset, '@charset 제거',
    TXT_BlankLines, '규칙 사이 빈 줄',
    TXT_UseTabs, '탭 사용',
    TXT_StatusReady, '준비 - CSS 파일을 열거나 입력란에 붙여넣으세요.',
    TXT_StatusLoaded, '열음: %s (%s자)',
    TXT_StatusSaved, '저장함: %s',
    TXT_StatusDone, '완료: %s | %s → %s바이트 (%s) | %s개 규칙 | %sms',
    TXT_PctSaved, '%s%% 절약',
    TXT_StatusLines, '줄: %s → %s',
    TXT_StatusDecls, '선언: %s',
    TXT_StatusComments, '주석: %s',
    TXT_StatusCopied, '결과를 클립보드에 복사했습니다.',
    TXT_StatusSwapped, '입력 / 출력을 교환했습니다.',
    TXT_StatusCleared, '지웠습니다.',
    TXT_StatusEmpty, '입력이 비어 있습니다.',
    TXT_MsgNothingToSave, '저장할 내용이 없습니다. 먼저 "실행"하세요.',
    TXT_MsgOpenFailed, '열기 실패: %s',
    TXT_MsgSaveFailed, '저장 실패: %s',
    TXT_MsgProcessFailed, '처리 실패: %s',
    TXT_DlgCssFiles, 'CSS 파일 (*.css)',
    TXT_DlgAllFiles, '모든 파일 (*.*)',
    TXT_OpAuto, '자동',
    TXT_OpPackSafe, '안전 압축',
    TXT_OpPackFast, '고속 압축',
    TXT_OpUnpack, '정렬'
  ]);

  { ----------------------------------- German -------------------------------- }
  AddLanguage('de', 'Deutsch', [
    TXT_AppTitle, 'CssPacker - Universelles CSS-Pack-/Entpack-Werkzeug  [%s]',
    TXT_BtnOpen, 'Öffnen...',
    TXT_BtnSave, 'Speichern...',
    TXT_BtnProcess, 'Ausführen',
    TXT_BtnSwap, 'Tauschen',
    TXT_BtnCopy, 'Ausgabe kopieren',
    TXT_BtnClear, 'Leeren',
    TXT_LblLanguage, 'Sprache:',
    TXT_LblInput, 'EINGABE-CSS',
    TXT_LblOutput, 'AUSGABE-CSS',
    TXT_OptMode, 'Modus:',
    TXT_ModeAuto, 'auto (erkennen)',
    TXT_ModePackSafe, 'sicher komprimieren',
    TXT_ModePackFast, 'schnell komprimieren',
    TXT_ModeUnpack, 'entpacken (formatieren)',
    TXT_OptIndent, 'Einrückung:',
    TXT_OptTab, 'Tab',
    TXT_OptEOL, 'Zeilenende:',
    TXT_KeepComments, 'Kommentare behalten',
    TXT_KeepLicense, '/*! Lizenz behalten',
    TXT_ShortHex, 'Hex-Farben kürzen',
    TXT_ZeroUnits, '0px -> 0',
    TXT_LeadingZero, '0.5 -> .5',
    TXT_FinalSemi, 'letztes ; entfernen',
    TXT_DropCharset, '@charset entfernen',
    TXT_BlankLines, 'Leerzeilen zwischen Regeln',
    TXT_UseTabs, 'Tabs verwenden',
    TXT_StatusReady, 'Bereit - CSS-Datei öffnen oder CSS in das Eingabefeld einfügen.',
    TXT_StatusLoaded, 'Geladen: %s (%s Zeichen)',
    TXT_StatusSaved, 'Gespeichert: %s',
    TXT_StatusDone, 'Fertig: %s | %s -> %s Bytes (%s) | %s Regeln | %s ms',
    TXT_PctSaved, '%s%% gespart',
    TXT_StatusLines, 'Zeilen: %s -> %s',
    TXT_StatusDecls, 'Deklarationen: %s',
    TXT_StatusComments, 'Kommentare: %s',
    TXT_StatusCopied, 'Ausgabe in die Zwischenablage kopiert.',
    TXT_StatusSwapped, 'Eingabe / Ausgabe getauscht.',
    TXT_StatusCleared, 'Geleert.',
    TXT_StatusEmpty, 'Eingabe ist leer.',
    TXT_MsgNothingToSave, 'Nichts zu speichern. Zuerst "Ausführen" klicken.',
    TXT_MsgOpenFailed, 'Öffnen fehlgeschlagen: %s',
    TXT_MsgSaveFailed, 'Speichern fehlgeschlagen: %s',
    TXT_MsgProcessFailed, 'Verarbeitung fehlgeschlagen: %s',
    TXT_DlgCssFiles, 'CSS-Dateien (*.css)',
    TXT_DlgAllFiles, 'Alle Dateien (*.*)',
    TXT_OpAuto, 'Auto',
    TXT_OpPackSafe, 'Sicher',
    TXT_OpPackFast, 'Schnell',
    TXT_OpUnpack, 'Formatiert'
  ]);

  { ----------------------------------- French -------------------------------- }
  AddLanguage('fr', 'Français', [
    TXT_AppTitle, 'CssPacker - Outil universel de compression / décompression CSS  [%s]',
    TXT_BtnOpen, 'Ouvrir...',
    TXT_BtnSave, 'Enregistrer...',
    TXT_BtnProcess, 'Traiter',
    TXT_BtnSwap, 'Échanger',
    TXT_BtnCopy, 'Copier la sortie',
    TXT_BtnClear, 'Effacer',
    TXT_LblLanguage, 'Langue :',
    TXT_LblInput, 'CSS D''ENTRÉE',
    TXT_LblOutput, 'CSS DE SORTIE',
    TXT_OptMode, 'Mode :',
    TXT_ModeAuto, 'auto (détection)',
    TXT_ModePackSafe, 'compression sûre',
    TXT_ModePackFast, 'compression rapide',
    TXT_ModeUnpack, 'décompression (formatage)',
    TXT_OptIndent, 'Indentation :',
    TXT_OptTab, 'Tab',
    TXT_OptEOL, 'Fin de ligne :',
    TXT_KeepComments, 'Conserver les commentaires',
    TXT_KeepLicense, 'Conserver /*! licence',
    TXT_ShortHex, 'Raccourcir les couleurs hex',
    TXT_ZeroUnits, '0px -> 0',
    TXT_LeadingZero, '0.5 -> .5',
    TXT_FinalSemi, 'Supprimer le dernier ;',
    TXT_DropCharset, 'Supprimer @charset',
    TXT_BlankLines, 'Lignes vides entre règles',
    TXT_UseTabs, 'Utiliser des tabulations',
    TXT_StatusReady, 'Prêt - ouvrez un fichier CSS ou collez du CSS dans la zone de saisie.',
    TXT_StatusLoaded, 'Chargé : %s (%s caractères)',
    TXT_StatusSaved, 'Enregistré : %s',
    TXT_StatusDone, 'Terminé : %s | %s -> %s octets (%s) | %s règles | %s ms',
    TXT_PctSaved, '%s%% économisés',
    TXT_StatusLines, 'Lignes : %s -> %s',
    TXT_StatusDecls, 'Déclarations : %s',
    TXT_StatusComments, 'Commentaires : %s',
    TXT_StatusCopied, 'Sortie copiée dans le presse-papiers.',
    TXT_StatusSwapped, 'Entrée / sortie échangées.',
    TXT_StatusCleared, 'Effacé.',
    TXT_StatusEmpty, 'L''entrée est vide.',
    TXT_MsgNothingToSave, 'Rien à enregistrer. Lancez d''abord le traitement.',
    TXT_MsgOpenFailed, 'Échec de l''ouverture : %s',
    TXT_MsgSaveFailed, 'Échec de l''enregistrement : %s',
    TXT_MsgProcessFailed, 'Échec du traitement : %s',
    TXT_DlgCssFiles, 'Fichiers CSS (*.css)',
    TXT_DlgAllFiles, 'Tous les fichiers (*.*)',
    TXT_OpAuto, 'Auto',
    TXT_OpPackSafe, 'Sûr',
    TXT_OpPackFast, 'Rapide',
    TXT_OpUnpack, 'Formaté'
  ]);

  { ----------------------------------- Spanish ------------------------------- }
  AddLanguage('es', 'Español', [
    TXT_AppTitle, 'CssPacker - Herramienta universal de compresión / descompresión CSS  [%s]',
    TXT_BtnOpen, 'Abrir...',
    TXT_BtnSave, 'Guardar...',
    TXT_BtnProcess, 'Procesar',
    TXT_BtnSwap, 'Intercambiar',
    TXT_BtnCopy, 'Copiar salida',
    TXT_BtnClear, 'Limpiar',
    TXT_LblLanguage, 'Idioma:',
    TXT_LblInput, 'CSS DE ENTRADA',
    TXT_LblOutput, 'CSS DE SALIDA',
    TXT_OptMode, 'Modo:',
    TXT_ModeAuto, 'auto (detectar)',
    TXT_ModePackSafe, 'compresión segura',
    TXT_ModePackFast, 'compresión rápida',
    TXT_ModeUnpack, 'descomprimir (formatear)',
    TXT_OptIndent, 'Sangría:',
    TXT_OptTab, 'Tab',
    TXT_OptEOL, 'Fin de línea:',
    TXT_KeepComments, 'Conservar comentarios',
    TXT_KeepLicense, 'Conservar /*! licencia',
    TXT_ShortHex, 'Acortar colores hex',
    TXT_ZeroUnits, '0px -> 0',
    TXT_LeadingZero, '0.5 -> .5',
    TXT_FinalSemi, 'Quitar el último ;',
    TXT_DropCharset, 'Quitar @charset',
    TXT_BlankLines, 'Líneas en blanco entre reglas',
    TXT_UseTabs, 'Usar tabulaciones',
    TXT_StatusReady, 'Listo - abra un archivo CSS o pegue CSS en el área de entrada.',
    TXT_StatusLoaded, 'Cargado: %s (%s caracteres)',
    TXT_StatusSaved, 'Guardado: %s',
    TXT_StatusDone, 'Listo: %s | %s -> %s bytes (%s) | %s reglas | %s ms',
    TXT_PctSaved, '%s%% ahorrados',
    TXT_StatusLines, 'Líneas: %s -> %s',
    TXT_StatusDecls, 'Declaraciones: %s',
    TXT_StatusComments, 'Comentarios: %s',
    TXT_StatusCopied, 'Salida copiada al portapapeles.',
    TXT_StatusSwapped, 'Entrada / salida intercambiadas.',
    TXT_StatusCleared, 'Limpiado.',
    TXT_StatusEmpty, 'La entrada está vacía.',
    TXT_MsgNothingToSave, 'Nada que guardar. Ejecute el procesamiento primero.',
    TXT_MsgOpenFailed, 'Error al abrir: %s',
    TXT_MsgSaveFailed, 'Error al guardar: %s',
    TXT_MsgProcessFailed, 'Error al procesar: %s',
    TXT_DlgCssFiles, 'Archivos CSS (*.css)',
    TXT_DlgAllFiles, 'Todos los archivos (*.*)',
    TXT_OpAuto, 'Auto',
    TXT_OpPackSafe, 'Seguro',
    TXT_OpPackFast, 'Rápido',
    TXT_OpUnpack, 'Formateado'
  ]);

  { ----------------------------------- Russian ------------------------------- }
  AddLanguage('ru', 'Русский', [
    TXT_AppTitle, 'CssPacker - Универсальный инструмент упаковки / распаковки CSS  [%s]',
    TXT_BtnOpen, 'Открыть...',
    TXT_BtnSave, 'Сохранить...',
    TXT_BtnProcess, 'Обработать',
    TXT_BtnSwap, 'Поменять',
    TXT_BtnCopy, 'Копировать результат',
    TXT_BtnClear, 'Очистить',
    TXT_LblLanguage, 'Язык:',
    TXT_LblInput, 'ВХОДНОЙ CSS',
    TXT_LblOutput, 'ВЫХОДНОЙ CSS',
    TXT_OptMode, 'Режим:',
    TXT_ModeAuto, 'авто (определение)',
    TXT_ModePackSafe, 'безопасное сжатие',
    TXT_ModePackFast, 'быстрое сжатие',
    TXT_ModeUnpack, 'распаковка (форматирование)',
    TXT_OptIndent, 'Отступ:',
    TXT_OptTab, 'Таб',
    TXT_OptEOL, 'Перевод строки:',
    TXT_KeepComments, 'Сохранять комментарии',
    TXT_KeepLicense, 'Сохранять /*! лицензию',
    TXT_ShortHex, 'Сокращать hex-цвета',
    TXT_ZeroUnits, '0px -> 0',
    TXT_LeadingZero, '0.5 -> .5',
    TXT_FinalSemi, 'Убрать последний ;',
    TXT_DropCharset, 'Убрать @charset',
    TXT_BlankLines, 'Пустые строки между правилами',
    TXT_UseTabs, 'Использовать табуляцию',
    TXT_StatusReady, 'Готово - откройте CSS-файл или вставьте CSS в поле ввода.',
    TXT_StatusLoaded, 'Загружен: %s (%s символов)',
    TXT_StatusSaved, 'Сохранён: %s',
    TXT_StatusDone, 'Готово: %s | %s -> %s байт (%s) | %s правил | %s мс',
    TXT_PctSaved, 'экономия %s%%',
    TXT_StatusLines, 'Строки: %s -> %s',
    TXT_StatusDecls, 'Объявления: %s',
    TXT_StatusComments, 'Комментарии: %s',
    TXT_StatusCopied, 'Результат скопирован в буфер обмена.',
    TXT_StatusSwapped, 'Ввод / вывод поменяны местами.',
    TXT_StatusCleared, 'Очищено.',
    TXT_StatusEmpty, 'Ввод пуст.',
    TXT_MsgNothingToSave, 'Нечего сохранять. Сначала нажмите «Обработать».',
    TXT_MsgOpenFailed, 'Ошибка открытия: %s',
    TXT_MsgSaveFailed, 'Ошибка сохранения: %s',
    TXT_MsgProcessFailed, 'Ошибка обработки: %s',
    TXT_DlgCssFiles, 'Файлы CSS (*.css)',
    TXT_DlgAllFiles, 'Все файлы (*.*)',
    TXT_OpAuto, 'Авто',
    TXT_OpPackSafe, 'Безопасное',
    TXT_OpPackFast, 'Быстрое',
    TXT_OpUnpack, 'Форматирование'
  ]);
end;

end.
