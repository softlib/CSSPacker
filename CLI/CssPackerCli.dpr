program CssPackerCli;

{$APPTYPE CONSOLE}

{------------------------------------------------------------------------------
  CssPacker CLI - command-line front end for the universal CSS pack/unpack tool

  Usage:
    CssPackerCli [options] [input] [output]

  If no input is given, stdin is read. If no output is given, stdout is written.
------------------------------------------------------------------------------}

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.IOUtils,
  System.Types,
  Winapi.Windows,
  CssPacker.Core in '..\Lib\CssPacker.Core.pas';

const
  EXIT_OK         = 0;
  EXIT_USAGE      = 1;
  EXIT_IO         = 2;
  EXIT_PROCESSING = 3;

type
  TAppConfig = record
    Operation: TCssOperation;
    Options: TCssOptions;
    InputFile: string;
    OutputFile: string;
    Recursive: Boolean;
    Backup: Boolean;
    Pattern: string;
    Stats: Boolean;
    Quiet: Boolean;
    Verbose: Boolean;
    DryRun: Boolean;
    Force: Boolean;
    UseLegacy: Boolean;
    ShowHelp: Boolean;
    ShowVersion: Boolean;
  end;

var
  Config: TAppConfig;
  TotalStats: TCssStats;
  ProcessedCount: Integer;

procedure WriteOut(const S: string);
begin
  WriteLn(S);
end;

procedure WriteErr(const S: string);
begin
  WriteLn(ErrOutput, S);
end;

procedure ShowLogo;
begin
  if Config.Quiet then Exit;
  WriteErr('CssPacker ' + TCssPacker.Version + ' - Universal CSS pack/unpack tool');
end;

procedure ShowHelp;
begin
  WriteOut('CssPacker ' + TCssPacker.Version + ' - Universal CSS pack/unpack tool');
  WriteOut('');
  WriteOut('Usage:');
  WriteOut('  CssPackerCli [options] [input] [output]');
  WriteOut('');
  WriteOut('Input / Output:');
  WriteOut('  input               File, directory, or "-" for stdin (default: stdin)');
  WriteOut('  output              File or "-" for stdout (default: stdout)');
  WriteOut('');
  WriteOut('Operation modes:');
  WriteOut('  -m, --mode <name>   pack-safe | pack-fast | unpack | auto (default: auto)');
  WriteOut('      pack-safe       Conservative minification (never changes semantics)');
  WriteOut('      pack-fast       Bootstrap-style minification + optimisations');
  WriteOut('      unpack          Pretty-print into readable, indented CSS');
  WriteOut('      auto            Detect whether input is packed or readable');
  WriteOut('');
  WriteOut('Formatting options:');
  WriteOut('  -i, --indent <n>    Indent size for unpack (default: 2)');
  WriteOut('  -t, --tabs          Use tabs instead of spaces for indentation');
  WriteOut('      --eol <type>    Line ending: auto | lf | crlf | cr (default: auto)');
  WriteOut('      --keep-comments Keep /* comments */ when packing');
  WriteOut('      --no-license    Do not preserve /*! license comments */');
  WriteOut('      --hex           Shorten #aabbcc to #abc (pack-fast style)');
  WriteOut('      --zero          Convert 0px to 0');
  WriteOut('      --leading-zero  Convert 0.5 to .5');
  WriteOut('      --no-final-semi Remove the last semicolon before }');
  WriteOut('      --charset       Remove @charset declaration');
  WriteOut('      --blank-lines   Add blank lines between rules when unpacking');
  WriteOut('');
  WriteOut('Batch / file options:');
  WriteOut('  -r, --recursive     Recurse into subdirectories');
  WriteOut('  -p, --pattern <pat> File mask for directories (default: *.css)');
  WriteOut('  -b, --backup        Create .bak backup before overwriting');
  WriteOut('  -f, --force         Overwrite existing output without prompting');
  WriteOut('      --dry-run       Show what would be done without writing');
  WriteOut('      --legacy        Use the original Source\cssunpack.pas engine');
  WriteOut('');
  WriteOut('Output control:');
  WriteOut('  -s, --stats         Print processing statistics');
  WriteOut('  -v, --verbose       Verbose messages');
  WriteOut('  -q, --quiet         Suppress non-essential messages');
  WriteOut('  -h, --help          Show this help');
  WriteOut('      --version       Show version');
  WriteOut('');
  WriteOut('Examples:');
  WriteOut('  CssPackerCli -m unpack site.min.css site.css');
  WriteOut('  CssPackerCli -m pack-fast --hex --zero -b site.css');
  WriteOut('  type site.css | CssPackerCli -m pack-safe > site.min.css');
  WriteOut('  CssPackerCli -r -p *.css -m pack-safe -b .\css');
  WriteOut('  CssPackerCli -m auto --stats input.css output.css');
end;

procedure ParseArgs;
var
  I: Integer;
  A, Next: string;
  N: Integer;
  Op: TCssOperation;
begin
  Config.Options := TCssOptions.Default;
  Config.Operation := coAuto;
  Config.Options.Operation := coAuto;
  Config.Pattern := '*.css';
  Config.InputFile := '';
  Config.OutputFile := '';
  Config.Recursive := False;
  Config.Backup := False;
  Config.Stats := False;
  Config.Quiet := False;
  Config.Verbose := False;
  Config.DryRun := False;
  Config.Force := False;
  Config.UseLegacy := False;
  Config.ShowHelp := False;
  Config.ShowVersion := False;

  I := 1;
  while I <= ParamCount do
  begin
    A := ParamStr(I);
    Next := '';
    if I < ParamCount then Next := ParamStr(I + 1);

    if (A = '-h') or (A = '--help') then Config.ShowHelp := True
    else if A = '--version' then Config.ShowVersion := True
    else if (A = '-m') or (A = '--mode') then
    begin
      if (Next = '') or (Next[1] = '-') then
        raise ECssPacker.Create('Missing value for --mode');
      if not TCssPacker.OperationFromName(Next, Op) then
        raise ECssPacker.CreateFmt('Unknown mode: %s', [Next]);
      Config.Operation := Op;
      Config.Options.Operation := Op;
      Inc(I);
    end
    else if (A = '-i') or (A = '--indent') then
    begin
      if (Next = '') or not TryStrToInt(Next, N) or (N < 0) or (N > 16) then
        raise ECssPacker.Create('Invalid value for --indent');
      Config.Options.IndentSize := N;
      Inc(I);
    end
    else if (A = '-t') or (A = '--tabs') then Config.Options.UseTabs := True
    else if A = '--eol' then
    begin
      if Next = '' then raise ECssPacker.Create('Missing value for --eol');
      if Next = 'lf' then Config.Options.LineEnding := #10
      else if Next = 'crlf' then Config.Options.LineEnding := #13#10
      else if Next = 'cr' then Config.Options.LineEnding := #13
      else if Next = 'auto' then Config.Options.LineEnding := sLineBreak
      else raise ECssPacker.CreateFmt('Unknown line ending: %s', [Next]);
      Inc(I);
    end
    else if A = '--keep-comments' then Config.Options.RemoveComments := False
    else if A = '--no-license' then Config.Options.KeepLicenseComments := False
    else if A = '--hex' then Config.Options.ShortenHexColors := True
    else if A = '--zero' then Config.Options.RemoveZeroUnits := True
    else if A = '--leading-zero' then Config.Options.RemoveLeadingZero := True
    else if A = '--no-final-semi' then Config.Options.RemoveFinalSemicolon := True
    else if A = '--charset' then Config.Options.RemoveCharset := True
    else if A = '--blank-lines' then Config.Options.BlankLineBetweenRules := True
    else if (A = '-r') or (A = '--recursive') then Config.Recursive := True
    else if (A = '-p') or (A = '--pattern') then
    begin
      if Next = '' then raise ECssPacker.Create('Missing value for --pattern');
      Config.Pattern := Next;
      Inc(I);
    end
    else if (A = '-b') or (A = '--backup') then Config.Backup := True
    else if (A = '-f') or (A = '--force') then Config.Force := True
    else if A = '--dry-run' then Config.DryRun := True
    else if A = '--legacy' then Config.UseLegacy := True
    else if (A = '-s') or (A = '--stats') then Config.Stats := True
    else if (A = '-v') or (A = '--verbose') then Config.Verbose := True
    else if (A = '-q') or (A = '--quiet') then Config.Quiet := True
    else if A = '-' then
    begin
      if Config.InputFile = '' then Config.InputFile := '-'
      else if Config.OutputFile = '' then Config.OutputFile := '-'
      else raise ECssPacker.Create('Too many arguments');
    end
    else if (A <> '') and (A[1] = '-') then
      raise ECssPacker.CreateFmt('Unknown option: %s', [A])
    else
    begin
      if Config.InputFile = '' then Config.InputFile := A
      else if Config.OutputFile = '' then Config.OutputFile := A
      else raise ECssPacker.CreateFmt('Unexpected argument: %s', [A]);
    end;

    Inc(I);
  end;

  { aggressive mode options imply pack-fast when mode not explicitly set }
  if (Config.Operation = coAuto) and
     (Config.Options.ShortenHexColors or Config.Options.RemoveZeroUnits or
      Config.Options.RemoveLeadingZero or Config.Options.RemoveFinalSemicolon or
      Config.Options.RemoveCharset) then
  begin
    Config.Operation := coPackAggressive;
    Config.Options.Operation := coPackAggressive;
  end;
end;

function ReadStdIn: string;
var
  Stream: THandleStream;
  Reader: TStreamReader;
begin
  Stream := THandleStream.Create(GetStdHandle(STD_INPUT_HANDLE));
  try
    Reader := TStreamReader.Create(Stream, TEncoding.UTF8, True, 4096);
    try
      Result := Reader.ReadToEnd;
    finally
      Reader.Free;
    end;
  finally
    Stream.Free;
  end;
end;

procedure WriteStdOut(const S: string);
var
  Stream: THandleStream;
  Writer: TStreamWriter;
begin
  Stream := THandleStream.Create(GetStdHandle(STD_OUTPUT_HANDLE));
  try
    Writer := TStreamWriter.Create(Stream, TEncoding.UTF8, 4096);
    try
      Writer.Write(S);
      Writer.Flush;
    finally
      Writer.Free;
    end;
  finally
    Stream.Free;
  end;
end;

function FormatText(const CSS: string; out Stats: TCssStats): string;
var
  Op: TCssOperation;
  Opts: TCssOptions;
begin
  Op := Config.Operation;
  Opts := Config.Options;
  if Op = coAuto then Op := TCssPacker.DetectOperation(CSS);
  Opts.Operation := Op;

  if Config.UseLegacy then
  begin
    Result := TCssPacker.LegacyFormat(CSS, Op);
    FillChar(Stats, SizeOf(Stats), 0);
    Stats.InputBytes := Length(CSS) * SizeOf(Char);
    Stats.OutputBytes := Length(Result) * SizeOf(Char);
    Stats.InputLines := 1 + CSS.CountChar(#10);
    Stats.OutputLines := 1 + Result.CountChar(#10);
  end
  else
    Result := TCssPacker.Format(CSS, Opts, Stats);
end;

procedure ProcessOne(const InFile, OutFile: string);
var
  Enc: TEncoding;
  HasBOM: Boolean;
  Input, Output: string;
  Stats: TCssStats;
  BackupFile: string;
begin
  if Config.Verbose and not Config.Quiet then
    WriteErr('Processing: ' + InFile + ' -> ' + OutFile);

  Input := TCssPacker.ReadTextFile(InFile, Enc, HasBOM);
  Output := FormatText(Input, Stats);

  Inc(TotalStats.InputBytes, Stats.InputBytes);
  Inc(TotalStats.OutputBytes, Stats.OutputBytes);
  Inc(TotalStats.InputLines, Stats.InputLines);
  Inc(TotalStats.OutputLines, Stats.OutputLines);
  Inc(TotalStats.RuleCount, Stats.RuleCount);
  Inc(TotalStats.DeclarationCount, Stats.DeclarationCount);
  Inc(TotalStats.CommentCount, Stats.CommentCount);
  Inc(TotalStats.ElapsedMs, Stats.ElapsedMs);
  Inc(ProcessedCount);

  if Config.DryRun then
  begin
    if not Config.Quiet then
      WriteErr('[dry-run] ' + InFile + ' -> ' + OutFile + '  (' + Stats.ToString + ')');
    Exit;
  end;

  { backup before overwriting }
  if Config.Backup and FileExists(OutFile) then
  begin
    BackupFile := OutFile + '.bak';
    TFile.Copy(OutFile, BackupFile, True);
    if Config.Verbose and not Config.Quiet then
      WriteErr('Backup created: ' + BackupFile);
  end;

  if (OutFile = '') or (OutFile = '-') then
    WriteStdOut(Output)
  else
  begin
    if FileExists(OutFile) and not Config.Force and not Config.Backup then
      raise ECssPacker.CreateFmt('Output already exists: %s (use -f to overwrite)', [OutFile]);
    TCssPacker.WriteTextFile(OutFile, Output, Enc, HasBOM);
  end;

  if Config.Stats and not Config.Quiet then
    WriteErr('[' + ExtractFileName(InFile) + '] ' + Stats.ToString);
end;

procedure ProcessStdIO;
var
  Input, Output: string;
  Stats: TCssStats;
begin
  Input := ReadStdIn;
  Output := FormatText(Input, Stats);

  if Config.Stats and not Config.Quiet then
    WriteErr(Stats.ToString);

  if (Config.OutputFile = '') or (Config.OutputFile = '-') then
    WriteStdOut(Output)
  else
    TCssPacker.WriteTextFile(Config.OutputFile, Output, TEncoding.UTF8, False);
end;

procedure ProcessDirectory(const Dir: string);
var
  Files: TStringDynArray;
  F, OutFile, Rel: string;
begin
  Files := TDirectory.GetFiles(Dir, Config.Pattern,
    TSearchOption.soAllDirectories);
  if not Config.Recursive then
    Files := TDirectory.GetFiles(Dir, Config.Pattern,
      TSearchOption.soTopDirectoryOnly);

  if Length(Files) = 0 then
  begin
    if not Config.Quiet then
      WriteErr('No files matching ' + Config.Pattern + ' in ' + Dir);
    Exit;
  end;

  for F in Files do
  begin
    if Config.OutputFile = '' then
      OutFile := F
    else if DirectoryExists(Config.OutputFile) then
    begin
      Rel := ExtractRelativePath(IncludeTrailingPathDelimiter(Dir), F);
      OutFile := TPath.Combine(Config.OutputFile, Rel);
      ForceDirectories(ExtractFilePath(OutFile));
    end
    else
      OutFile := ChangeFileExt(Config.OutputFile, ExtractFileExt(F));
    ProcessOne(F, OutFile);
  end;
end;

procedure Run;
begin
  ParseArgs;

  if Config.ShowVersion then
  begin
    WriteOut(TCssPacker.Version);
    Exit;
  end;
  if Config.ShowHelp then
  begin
    ShowHelp;
    Exit;
  end;

  ShowLogo;

  if (Config.InputFile = '') or (Config.InputFile = '-') then
    ProcessStdIO
  else if DirectoryExists(Config.InputFile) then
    ProcessDirectory(Config.InputFile)
  else if FileExists(Config.InputFile) then
  begin
    if Config.OutputFile = '' then
      ProcessOne(Config.InputFile, '')
    else
      ProcessOne(Config.InputFile, Config.OutputFile);
  end
  else
    raise ECssPacker.CreateFmt('Input not found: %s', [Config.InputFile]);

  if Config.Stats and (ProcessedCount > 1) and not Config.Quiet then
    WriteErr('TOTAL: ' + TotalStats.ToString + '  files=' + IntToStr(ProcessedCount));
end;

begin
  FillChar(Config, SizeOf(Config), 0);
  FillChar(TotalStats, SizeOf(TotalStats), 0);
  ProcessedCount := 0;
  try
    try
      Run;
      Halt(EXIT_OK);
    except
      on E: ECssPacker do
      begin
        WriteErr('CssPacker error: ' + E.Message);
        Halt(EXIT_PROCESSING);
      end;
      on E: Exception do
      begin
        WriteErr('Unexpected error: ' + E.ClassName + ': ' + E.Message);
        Halt(EXIT_PROCESSING);
      end;
    end;
  except
    Halt(EXIT_IO);
  end;
end.
