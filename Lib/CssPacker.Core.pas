unit CssPacker.Core;

{------------------------------------------------------------------------------
  CssPacker.Core - Universal CSS pack / unpack engine for Delphi 12.2

  Design goals
    * Semantic-safe minification (whitespace, comments, strings, URLs, calc)
    * Optional Bootstrap-style aggressive optimisations
    * Stable, readable pretty printing (nested at-rules, keyframes, etc.)
    * Encoding / BOM aware file IO
    * Rich statistics and reusable class API for any application scenario

  The original Source\cssunpack.pas is kept and used as the legacy engine
  (TCssPacker.LegacyFormat) so existing code built on TCSSTools.FormatCSS2
  keeps working. The default engine is the robust implementation below.
------------------------------------------------------------------------------}

interface

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.Character,
  System.Types;

type
  ECssPacker = class(Exception);

  TCssOperation = (
    coPackSafe,        { conservative minification, never changes semantics }
    coPackAggressive,  { safe minification + bootstrap-style optimisations }
    coUnpackPretty,    { readable, indented output }
    coAuto             { detect from input }
  );

  TCssOptions = record
    Operation: TCssOperation;
    IndentSize: Integer;
    UseTabs: Boolean;
    LineEnding: string;
    RemoveComments: Boolean;
    KeepLicenseComments: Boolean;   { preserve /*! ... */ blocks }
    ShortenHexColors: Boolean;
    RemoveZeroUnits: Boolean;
    RemoveLeadingZero: Boolean;
    RemoveFinalSemicolon: Boolean;
    RemoveCharset: Boolean;
    BlankLineBetweenRules: Boolean;
    class function Default: TCssOptions; static;
  end;

  TCssStats = record
    InputBytes: Int64;
    OutputBytes: Int64;
    InputLines: Integer;
    OutputLines: Integer;
    RuleCount: Integer;
    DeclarationCount: Integer;
    CommentCount: Integer;
    ElapsedMs: Int64;
    function CompressionPercent: Double;
    function ChangePercent: Double;
    function ToString: string;
  end;

  TCssPacker = class
  public
    { --- string API ------------------------------------------------------- }
    class function Format(const CSS: string; const Options: TCssOptions): string; overload; static;
    class function Format(const CSS: string; const Options: TCssOptions; out Stats: TCssStats): string; overload; static;
    class function Pack(const CSS: string; const Options: TCssOptions): string; static;
    class function Unpack(const CSS: string; const Options: TCssOptions): string; static;
    class function DetectOperation(const CSS: string): TCssOperation; static;

    { --- file API --------------------------------------------------------- }
    class function ReadTextFile(const FileName: string; out Encoding: TEncoding;
      out HasBOM: Boolean): string; static;
    class procedure WriteTextFile(const FileName, Text: string; Encoding: TEncoding;
      HasBOM: Boolean); static;
    class function ProcessFile(const InFile, OutFile: string;
      const Options: TCssOptions): TCssStats; static;

    { --- legacy bridge to Source\cssunpack.pas ---------------------------- }
    class function LegacyFormat(const CSS: string; Operation: TCssOperation): string; static;

    { --- helpers ---------------------------------------------------------- }
    class function OperationName(Operation: TCssOperation): string; static;
    class function OperationFromName(const Name: string; out Operation: TCssOperation): Boolean; static;
    class function Version: string; static;
  end;

implementation

uses
  cssunpack;

const
  CSSPACKER_VERSION = '1.0.0 (Delphi 12.2)';

{ TCssOptions }

class function TCssOptions.Default: TCssOptions;
begin
  Result.Operation                := coAuto;
  Result.IndentSize               := 2;
  Result.UseTabs                  := False;
  Result.LineEnding               := sLineBreak;
  Result.RemoveComments           := True;
  Result.KeepLicenseComments      := True;
  Result.ShortenHexColors         := False;
  Result.RemoveZeroUnits          := False;
  Result.RemoveLeadingZero        := False;
  Result.RemoveFinalSemicolon     := False;
  Result.RemoveCharset            := False;
  Result.BlankLineBetweenRules    := False;
end;

{ TCssStats }

function TCssStats.CompressionPercent: Double;
begin
  if InputBytes <= 0 then
    Result := 0
  else
    Result := (1 - OutputBytes / InputBytes) * 100;
end;

function TCssStats.ChangePercent: Double;
begin
  Result := CompressionPercent;
end;

function TCssStats.ToString: string;
begin
  Result := Format(
    'in=%d B / %d lines, out=%d B / %d lines, saved=%.1f%%, rules=%d, decls=%d, comments=%d, time=%d ms',
    [InputBytes, InputLines, OutputBytes, OutputLines, CompressionPercent,
     RuleCount, DeclarationCount, CommentCount, ElapsedMs]);
end;

{ -------------------------------------------------------------------------- }
{ Character helpers                                                           }
{ -------------------------------------------------------------------------- }

function IsWordChar(C: Char): Boolean; inline;
begin
  Result := (C > #127) or TCharacter.IsLetterOrDigit(C) or (C in ['_', '-', '%', '.', '#', '@', '*']);
end;

function IsValueEnd(C: Char): Boolean; inline;
begin
  Result := IsWordChar(C) or (C in [')', ']', '''', '"']);
end;

function IsValueStart(C: Char): Boolean; inline;
begin
  Result := IsWordChar(C) or (C in ['(', '[', '-', '''', '"']);
end;

function IsHexDigit(C: Char): Boolean; inline;
begin
  Result := (C in ['0'..'9']) or (C in ['a'..'f']) or (C in ['A'..'F']);
end;

function IsLengthUnitAt(const S: string; Index: Integer; out ULen: Integer): Boolean;
const
  Units: array[0..17] of string = (
    'px','em','rem','%','vh','vw','vmin','vmax','ch','ex',
    'cm','mm','in','pt','pc','q','fr','svh');
var
  U: string;
begin
  for U in Units do
    if SameText(Copy(S, Index, Length(U)), U) then
    begin
      ULen := Length(U);
      Exit(True);
    end;
  Result := False;
end;

function IsMathFunction(const Name: string): Boolean; inline;
begin
  Result := SameText(Name, 'calc') or SameText(Name, 'min') or
            SameText(Name, 'max') or SameText(Name, 'clamp');
end;

function IsVerbatimFunction(const Name: string): Boolean; inline;
begin
  { url() must never be altered: data URIs, spaces in file names, escaped chars }
  Result := SameText(Name, 'url');
end;

function IsPunct(C: Char): Boolean; inline;
begin
  Result := C in ['{', '}', ':', ';', ',', '>', '+', '~', '*', '/', '[', ']',
                  '(', ')', '=', '|', '^', '$', '!', '?'];
end;

procedure TrimTrailingSpaces(SB: TStringBuilder); inline;
begin
  while (SB.Length > 0) and (SB.Chars[SB.Length - 1] = ' ') do
    SB.Length := SB.Length - 1;
end;

function EndsWithText(SB: TStringBuilder; const S: string): Boolean;
var
  I, J: Integer;
begin
  Result := False;
  if Length(S) > SB.Length then Exit;
  J := SB.Length - Length(S);
  for I := 1 to Length(S) do
    if SB.Chars[J + I - 1] <> S[I] then Exit;
  Result := True;
end;

{ -------------------------------------------------------------------------- }
{ PACK                                                                        }
{ -------------------------------------------------------------------------- }

class function TCssPacker.Pack(const CSS: string; const Options: TCssOptions): string;
type
  TState = (psNormal, psString, psComment, psUrl, psFunction);
var
  SB: TStringBuilder;
  I, L, FuncDepth: Integer;
  C, Quote, LastChar: Char;
  State: TState;
  PendingSpace: Boolean;
  LastWord, WordBuf, FuncName, Hex: string;
  InValue, MathFunc: Boolean;
  ULen: Integer;
  DropComment: Boolean;

  procedure FlushSpace;
  begin
    if not PendingSpace then Exit;
    PendingSpace := False;
    if (SB.Length > 0) and IsValueEnd(LastChar) and (C <> #0) then
      if IsValueStart(C) then
        SB.Append(' ');
  end;

  procedure EnterFunction(const Name: string);
  begin
    FuncName := Name;
    MathFunc := IsMathFunction(Name);
    SB.Append('(');
    LastChar := '(';
    FuncDepth := 1;
    if IsVerbatimFunction(Name) then
      State := psUrl
    else
      State := psFunction;
    WordBuf := '';
  end;

begin
  L := Length(CSS);
  SB := TStringBuilder.Create(L);
  try
    State := psNormal;
    Quote := #0;
    LastChar := #0;
    PendingSpace := False;
    LastWord := '';
    WordBuf := '';
    FuncName := '';
    FuncDepth := 0;
    InValue := False;
    MathFunc := False;
    DropComment := False;
    I := 1;

    if Options.RemoveCharset and SameText(Copy(CSS, 1, 8), '@charset') then
    begin
      while (I <= L) and (CSS[I] <> ';') do Inc(I);
      if I <= L then Inc(I);
    end;

    while I <= L do
    begin
      C := CSS[I];

      case State of

        psString:
          begin
            SB.Append(C);
            if (C = Quote) and ((I = 1) or (CSS[I - 1] <> '\')) then
            begin
              State := psNormal;
              Quote := #0;
            end;
            LastChar := C;
            Inc(I);
          end;

        psComment:
          begin
            if (C = '*') and (I < L) and (CSS[I + 1] = '/') then
            begin
              State := psNormal;
              if not DropComment then SB.Append('*/');
              Inc(I, 2);
            end
            else
            begin
              if not DropComment then SB.Append(C);
              Inc(I);
            end;
          end;

        psUrl:
          begin
            { copy everything verbatim until the matching ')' }
            SB.Append(C);
            if C = '(' then Inc(FuncDepth);
            if C = ')' then
            begin
              Dec(FuncDepth);
              if FuncDepth = 0 then State := psNormal;
            end;
            LastChar := C;
            Inc(I);
          end;

        psFunction:
          begin
            if (C = '''') or (C = '"') then
            begin
              Quote := C;
              SB.Append(C);
              LastChar := C;
              Inc(I);
              while I <= L do
              begin
                SB.Append(CSS[I]);
                if (CSS[I] = Quote) and (CSS[I - 1] <> '\') then
                begin
                  LastChar := Quote;
                  Inc(I);
                  Break;
                end;
                Inc(I);
              end;
              Quote := #0;
              Continue;
            end
            else if C = '(' then
            begin
              TrimTrailingSpaces(SB);
              SB.Append('(');
              Inc(FuncDepth);
              LastChar := '(';
              Inc(I);
            end
            else if C = ')' then
            begin
              TrimTrailingSpaces(SB);
              SB.Append(')');
              Dec(FuncDepth);
              LastChar := ')';
              Inc(I);
              if FuncDepth <= 0 then State := psNormal;
            end
            else if TCharacter.IsWhiteSpace(C) then
            begin
              PendingSpace := True;
              Inc(I);
            end
            else if C in [',', '/', ':'] then
            begin
              TrimTrailingSpaces(SB);
              SB.Append(C);
              LastChar := C;
              PendingSpace := False;
              Inc(I);
            end
            else
            begin
              if PendingSpace then
              begin
                PendingSpace := False;
                if MathFunc and ((C = '+') or (C = '-') or
                   (LastChar = '+') or (LastChar = '-')) then
                  SB.Append(' ')
                else if IsValueEnd(LastChar) and IsValueStart(C) then
                  SB.Append(' ');
              end;
              SB.Append(C);
              LastChar := C;
              Inc(I);
            end;
          end;

        psNormal:
          begin
            { aggressive: aggressive hex shortening in declaration values }
            if Options.ShortenHexColors and InValue and (C = '#') and
               (I + 6 <= L) and (LastChar <> #0) then
            begin
              Hex := Copy(CSS, I + 1, 6);
              if IsHexDigit(Hex[1]) and IsHexDigit(Hex[2]) and IsHexDigit(Hex[3]) and
                 IsHexDigit(Hex[4]) and IsHexDigit(Hex[5]) and IsHexDigit(Hex[6]) and
                 (Hex[1] = Hex[2]) and (Hex[3] = Hex[4]) and (Hex[5] = Hex[6]) then
              begin
                FlushSpace;
                SB.Append('#' + Hex[1] + Hex[3] + Hex[5]);
                LastChar := Hex[5];
                Inc(I, 7);
                Continue;
              end;
            end;

            { aggressive: 0px -> 0 }
            if Options.RemoveZeroUnits and InValue and (C = '0') and (I < L) then
            begin
              if ((I = 1) or not TCharacter.IsDigit(CSS[I - 1])) and
                 (CSS[I - 1] <> '.') and IsLengthUnitAt(CSS, I + 1, ULen) then
              begin
                if (I + 1 + ULen > L) or (not IsWordChar(CSS[I + 1 + ULen])) then
                begin
                  FlushSpace;
                  SB.Append('0');
                  LastChar := '0';
                  Inc(I, ULen + 1);
                  Continue;
                end;
              end;
            end;

            { aggressive: 0.5 -> .5 }
            if Options.RemoveLeadingZero and InValue and (C = '0') and
               (I < L) and (CSS[I + 1] = '.') and (I + 2 <= L) and
               TCharacter.IsDigit(CSS[I + 2]) and
               ((I = 1) or (not (TCharacter.IsDigit(CSS[I - 1]) or (CSS[I - 1] = '.')))) then
            begin
              FlushSpace;
              SB.Append('.');
              LastChar := '.';
              Inc(I, 2);
              Continue;
            end;

            { comments }
            if (C = '/') and (I < L) and (CSS[I + 1] = '*') then
            begin
              DropComment := False;
              if Options.RemoveComments then
              begin
                { preserve /*! license comments */}
                if Options.KeepLicenseComments and (I + 2 <= L) and (CSS[I + 2] = '!') then
                begin
                  SB.Append('/*!');
                  State := psComment;
                  Inc(I, 3);
                end
                else
                begin
                  State := psComment;
                  DropComment := True;
                  Inc(I, 2);
                end;
              end
              else
              begin
                SB.Append('/*');
                State := psComment;
                Inc(I, 2);
              end;
              Continue;
            end;

            { strings }
            if (C = '''') or (C = '"') then
            begin
              FlushSpace;
              Quote := C;
              SB.Append(C);
              State := psString;
              LastChar := C;
              Inc(I);
              Continue;
            end;

            { functions }
            if C = '(' then
            begin
              if LastWord <> '' then
              begin
                EnterFunction(LastWord);
                Inc(I);   { EnterFunction already emitted the '(' }
              end
              else
              begin
                TrimTrailingSpaces(SB);
                SB.Append('(');
                LastChar := '(';
                Inc(I);
              end;
              Continue;
            end;

            { whitespace }
            if TCharacter.IsWhiteSpace(C) then
            begin
              PendingSpace := True;
              Inc(I);
              Continue;
            end;

            FlushSpace;

            { delimiters - no surrounding whitespace }
            if C in ['{', '}', ':', ';', ',', '>', '+', '~'] then
            begin
              TrimTrailingSpaces(SB);
              if C = '}' then
              begin
                if Options.RemoveFinalSemicolon and (SB.Length > 0) and
                   (SB.Chars[SB.Length - 1] = ';') then
                  SB.Length := SB.Length - 1;
              end;
              SB.Append(C);
              LastChar := C;
              WordBuf := '';
              LastWord := '';
              if C = '{' then InValue := False;
              if C = ':' then InValue := True;
              if (C = ';') or (C = '}') then InValue := False;
              Inc(I);
              Continue;
            end;

            { other punctuation }
            if IsPunct(C) then
            begin
              TrimTrailingSpaces(SB);
              SB.Append(C);
              LastChar := C;
              WordBuf := '';
              LastWord := '';
              Inc(I);
              Continue;
            end;

            { regular character }
            SB.Append(C);
            LastChar := C;
            if IsWordChar(C) then
            begin
              WordBuf := WordBuf + C;
              LastWord := WordBuf;
            end
            else
            begin
              WordBuf := '';
              LastWord := '';
            end;
            Inc(I);
          end;
      end;
    end;

    Result := SB.ToString.Trim;
  finally
    SB.Free;
  end;
end;

{ -------------------------------------------------------------------------- }
{ UNPACK (pretty printer)                                                     }
{ -------------------------------------------------------------------------- }

class function TCssPacker.Unpack(const CSS: string; const Options: TCssOptions): string;
type
  TState = (usNormal, usString, usComment, usUrl);
var
  SB: TStringBuilder;
  I, L, Indent, Depth: Integer;
  C, Quote: Char;
  State: TState;
  LineHasContent: Boolean;
  LastChar: Char;
  PendingSpace: Boolean;
  WordBuf: string;
  AfterCloseBrace: Boolean;

  function IndentText: string;
  begin
    if Options.UseTabs then
      Result := StringOfChar(#9, Indent)
    else
      Result := StringOfChar(' ', Indent * Options.IndentSize);
  end;

  procedure NewLine;
  begin
    TrimTrailingSpaces(SB);
    if not EndsWithText(SB, Options.LineEnding) then
      SB.Append(Options.LineEnding);
    SB.Append(IndentText);
    LineHasContent := False;
    PendingSpace := False;
  end;

  procedure EnsureLineContent;
  begin
    if not LineHasContent then
    begin
      SB.Append(IndentText);
      LineHasContent := True;
    end;
  end;

  function NextNonSpace(Index: Integer): Char;
  begin
    while (Index <= L) and TCharacter.IsWhiteSpace(CSS[Index]) do Inc(Index);
    if Index <= L then Result := CSS[Index] else Result := #0;
  end;

  { Distinguish a pseudo-class colon (a:hover) from a declaration colon
    (color:red). Scan forward to the next structural character, ignoring
    strings/comments/parenthesised groups: an opening brace means pseudo,
    a semicolon or closing brace means declaration separator. }
  function IsPseudoColon(Index: Integer): Boolean;
  var
    J, PDepth, Scanned: Integer;
    Ch, Q: Char;
  begin
    Result := False;
    J := Index + 1;
    PDepth := 0;
    Q := #0;
    Scanned := 0;
    while (J <= L) and (Scanned < 4096) do
    begin
      Ch := CSS[J];
      Inc(Scanned);
      if Q <> #0 then
      begin
        if (Ch = Q) and (CSS[J - 1] <> '\') then Q := #0;
        Inc(J);
        Continue;
      end;
      if (Ch = '/') and (J < L) and (CSS[J + 1] = '*') then
      begin
        Inc(J, 2);
        while (J < L) and not ((CSS[J] = '*') and (J < L) and (CSS[J + 1] = '/')) do Inc(J);
        Inc(J, 2);
        Continue;
      end;
      case Ch of
        '''', '"': begin Q := Ch; Inc(J); end;
        '(': begin Inc(PDepth); Inc(J); end;
        ')': begin if PDepth > 0 then Dec(PDepth); Inc(J); end;
        '{': if PDepth = 0 then Exit(True) else Inc(J);
        ';', '}': if PDepth = 0 then Exit(False) else Inc(J);
      else
        Inc(J);
      end;
    end;
  end;

begin
  L := Length(CSS);
  SB := TStringBuilder.Create(L + 64);
  try
    State := usNormal;
    Quote := #0;
    Indent := 0;
    Depth := 0;
    LineHasContent := False;
    LastChar := #0;
    PendingSpace := False;
    WordBuf := '';
    AfterCloseBrace := False;
    I := 1;

    SB.Append(IndentText);
    LineHasContent := False;

    while I <= L do
    begin
      C := CSS[I];

      case State of

        usString:
          begin
            SB.Append(C);
            LineHasContent := True;
            if (C = Quote) and ((I = 1) or (CSS[I - 1] <> '\')) then State := usNormal;
            LastChar := C;
            Inc(I);
          end;

        usComment:
          begin
            SB.Append(C);
            LineHasContent := True;
            if (C = '*') and (I < L) and (CSS[I + 1] = '/') then
            begin
              SB.Append('/');
              State := usNormal;
              Inc(I, 2);
              NewLine;
            end
            else
              Inc(I);
          end;

        usUrl:
          begin
            SB.Append(C);
            LineHasContent := True;
            if C = '(' then Inc(Depth);
            if C = ')' then
            begin
              Dec(Depth);
              if Depth = 0 then State := usNormal;
            end;
            LastChar := C;
            Inc(I);
          end;

        usNormal:
          begin
            { comments }
            if (C = '/') and (I < L) and (CSS[I + 1] = '*') then
            begin
              TrimTrailingSpaces(SB);
              if SB.Length > 0 then
              begin
                SB.Append(' ');
                SB.Append('/*');
                LineHasContent := True;
                State := usComment;
                Inc(I, 2);
              end
              else
              begin
                SB.Append('/*');
                LineHasContent := True;
                State := usComment;
                Inc(I, 2);
              end;
              Continue;
            end;

            { strings }
            if (C = '''') or (C = '"') then
            begin
              if PendingSpace and LineHasContent then SB.Append(' ');
              PendingSpace := False;
              Quote := C;
              SB.Append(C);
              State := usString;
              LineHasContent := True;
              LastChar := C;
              Inc(I);
              Continue;
            end;

            { url() verbatim }
            if SameText(Copy(CSS, I, 4), 'url(') then
            begin
              if PendingSpace and LineHasContent then SB.Append(' ');
              PendingSpace := False;
              SB.Append('url(');
              State := usUrl;
              Depth := 1;
              LineHasContent := True;
              LastChar := '(';
              Inc(I, 4);
              Continue;
            end;

            { whitespace }
            if TCharacter.IsWhiteSpace(C) then
            begin
              PendingSpace := True;
              Inc(I);
              Continue;
            end;

            { opening brace }
            if C = '{' then
            begin
              TrimTrailingSpaces(SB);
              SB.Append(' {');
              Inc(Indent);
              Inc(Depth);
              NewLine;
              Inc(I);
              Continue;
            end;

            { closing brace }
            if C = '}' then
            begin
              TrimTrailingSpaces(SB);
              if Indent > 0 then Dec(Indent);
              if Depth > 0 then Dec(Depth);
              if not EndsWithText(SB, Options.LineEnding) then NewLine;
              SB.Append('}');
              LineHasContent := True;
              LastChar := '}';
              Inc(I);
              AfterCloseBrace := True;
              Continue;
            end;

            { declaration separator }
            if C = ';' then
            begin
              TrimTrailingSpaces(SB);
              SB.Append(';');
              LineHasContent := True;
              LastChar := ';';
              NewLine;
              Inc(I);
              AfterCloseBrace := False;
              Continue;
            end;

            { property / value separator (or pseudo-class colon) }
            if C = ':' then
            begin
              var IsPseudo := IsPseudoColon(I);
              TrimTrailingSpaces(SB);
              SB.Append(':');
              LineHasContent := True;
              LastChar := ':';
              PendingSpace := False;
              if not IsPseudo then
              begin
                { skip existing whitespace, add exactly one }
                while (I < L) and TCharacter.IsWhiteSpace(CSS[I + 1]) do Inc(I);
                if (I < L) and not (CSS[I + 1] in [';', '}']) then
                  SB.Append(' ');
              end;
              Inc(I);
              Continue;
            end;

            { comma in value lists }
            if C = ',' then
            begin
              TrimTrailingSpaces(SB);
              SB.Append(',');
              LineHasContent := True;
              LastChar := ',';
              while (I < L) and TCharacter.IsWhiteSpace(CSS[I + 1]) do Inc(I);
              if (I < L) and (CSS[I + 1] <> '}') then SB.Append(' ');
              Inc(I);
              Continue;
            end;

            { regular character }
            if PendingSpace and LineHasContent and (LastChar <> #0) then
            begin
              if IsValueEnd(LastChar) and IsValueStart(C) then
                SB.Append(' ');
            end;
            PendingSpace := False;

            if AfterCloseBrace then
            begin
              if TCharacter.IsWhiteSpace(C) then
              begin
                Inc(I);
                Continue;
              end;
              if (C = ';') then
              begin
                SB.Append(';');
                NewLine;
                Inc(I);
                Continue;
              end;
              if Options.BlankLineBetweenRules and (Indent = 0) then
                SB.Append(Options.LineEnding);
              AfterCloseBrace := False;
              NewLine;
            end;

            SB.Append(C);
            LineHasContent := True;
            LastChar := C;
            if IsWordChar(C) then WordBuf := WordBuf + C else WordBuf := '';
            Inc(I);
          end;
      end;
    end;

    Result := SB.ToString.Trim;
    if not Result.EndsWith(Options.LineEnding) then
      Result := Result + Options.LineEnding;
  finally
    SB.Free;
  end;
end;

{ -------------------------------------------------------------------------- }
{ FORMAT / DETECT                                                             }
{ -------------------------------------------------------------------------- }

class function TCssPacker.DetectOperation(const CSS: string): TCssOperation;
var
  I, LineCount, MaxLineLen, CurLen, BraceCount, SpaceCount, TotalChars: Integer;
begin
  LineCount := 1;
  MaxLineLen := 0;
  CurLen := 0;
  BraceCount := 0;
  SpaceCount := 0;
  TotalChars := Length(CSS);
  for I := 1 to TotalChars do
  begin
    case CSS[I] of
      #10:
        begin
          Inc(LineCount);
          if CurLen > MaxLineLen then MaxLineLen := CurLen;
          CurLen := 0;
        end;
      '{': Inc(BraceCount);
      ' ': Inc(SpaceCount);
    else
      Inc(CurLen);
    end;
  end;
  if CurLen > MaxLineLen then MaxLineLen := CurLen;

  { a dense, long-line input is almost certainly minified }
  if (TotalChars > 0) and (MaxLineLen > 200) and (BraceCount > 0) then
    Exit(coUnpackPretty);
  if (LineCount > 1) and (MaxLineLen <= 160) and (BraceCount > 0) then
    Exit(coPackSafe);
  if (TotalChars > 0) and (SpaceCount div TotalChars > 0) and (MaxLineLen > 200) then
    Exit(coUnpackPretty);
  Result := coPackSafe;
end;

class function TCssPacker.Format(const CSS: string;
  const Options: TCssOptions): string;
var
  Dummy: TCssStats;
begin
  Result := Format(CSS, Options, Dummy);
end;

class function TCssPacker.Format(const CSS: string; const Options: TCssOptions;
  out Stats: TCssStats): string;
var
  StartTick, StopTick: Int64;
  Op: TCssOperation;
  I: Integer;
begin
  StartTick := TThread.GetTickCount64;
  FillChar(Stats, SizeOf(Stats), 0);
  Stats.InputBytes := Length(CSS) * SizeOf(Char);
  Stats.InputLines := 1;
  for I := 1 to Length(CSS) do
    if CSS[I] = #10 then Inc(Stats.InputLines);

  Op := Options.Operation;
  if Op = coAuto then Op := DetectOperation(CSS);

  { cheap structural stats }
  Stats.RuleCount := 0;
  Stats.DeclarationCount := 0;
  Stats.CommentCount := 0;
  I := 1;
  while I <= Length(CSS) do
  begin
    if (CSS[I] = '/') and (I < Length(CSS)) and (CSS[I + 1] = '*') then
    begin
      Inc(Stats.CommentCount);
      Inc(I, 2);
    end
    else
    begin
      if CSS[I] = '{' then Inc(Stats.RuleCount);
      if CSS[I] = ';' then Inc(Stats.DeclarationCount);
      Inc(I);
    end;
  end;

  case Op of
    coPackSafe, coPackAggressive: Result := Pack(CSS, Options);
    coUnpackPretty: Result := Unpack(CSS, Options);
  else
    Result := CSS;
  end;

  Stats.OutputBytes := Length(Result) * SizeOf(Char);
  Stats.OutputLines := 1;
  for I := 1 to Length(Result) do
    if Result[I] = #10 then Inc(Stats.OutputLines);
  StopTick := TThread.GetTickCount64;
  Stats.ElapsedMs := StopTick - StartTick;
end;

{ -------------------------------------------------------------------------- }
{ FILE IO                                                                     }
{ -------------------------------------------------------------------------- }

class function TCssPacker.ReadTextFile(const FileName: string;
  out Encoding: TEncoding; out HasBOM: Boolean): string;
var
  Stream: TFileStream;
  Reader: TStreamReader;
  BOM: TBytes;
  N: Integer;
begin
  if not FileExists(FileName) then
    raise ECssPacker.CreateFmt('File not found: %s', [FileName]);

  HasBOM := False;
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(BOM, 4);
    N := Stream.Read(BOM[0], 4);
    Stream.Position := 0;
    if (N >= 3) and (BOM[0] = $EF) and (BOM[1] = $BB) and (BOM[2] = $BF) then
      HasBOM := True
    else if (N >= 2) and ((BOM[0] = $FF) and (BOM[1] = $FE) or
                          (BOM[0] = $FE) and (BOM[1] = $FF)) then
      HasBOM := True;

    Reader := TStreamReader.Create(Stream, TEncoding.UTF8, True, 4096);
    try
      Result := Reader.ReadToEnd;
      Encoding := Reader.CurrentEncoding;
    finally
      Reader.Free;
    end;
  finally
    Stream.Free;
  end;
end;

class procedure TCssPacker.WriteTextFile(const FileName, Text: string;
  Encoding: TEncoding; HasBOM: Boolean);
var
  Stream: TFileStream;
  Data, Preamble: TBytes;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    if HasBOM then
    begin
      Preamble := Encoding.GetPreamble;
      if Length(Preamble) > 0 then
        Stream.WriteBuffer(Preamble[0], Length(Preamble));
    end;
    Data := Encoding.GetBytes(Text);
    if Length(Data) > 0 then
      Stream.WriteBuffer(Data[0], Length(Data));
  finally
    Stream.Free;
  end;
end;

class function TCssPacker.ProcessFile(const InFile, OutFile: string;
  const Options: TCssOptions): TCssStats;
var
  Encoding: TEncoding;
  HasBOM: Boolean;
  Input, Output: string;
begin
  Input := ReadTextFile(InFile, Encoding, HasBOM);
  Output := Format(Input, Options, Result);
  WriteTextFile(OutFile, Output, Encoding, HasBOM);
end;

{ -------------------------------------------------------------------------- }
{ LEGACY BRIDGE - uses the provided Source\cssunpack.pas                       }
{ -------------------------------------------------------------------------- }

class function TCssPacker.LegacyFormat(const CSS: string;
  Operation: TCssOperation): string;
var
  Mode: TCssFormatMode;
begin
  case Operation of
    coPackSafe:       Mode := cssPackSafe;
    coPackAggressive: Mode := cssPackBootstrap;
    coUnpackPretty:   Mode := cssUnpackPretty;
  else
    Mode := cssPackSafe;
  end;
  Result := TCSSTools.FormatCSS2(CSS, Mode);
end;

{ -------------------------------------------------------------------------- }
{ METADATA                                                                    }
{ -------------------------------------------------------------------------- }

class function TCssPacker.OperationName(Operation: TCssOperation): string;
begin
  case Operation of
    coPackSafe:       Result := 'pack-safe';
    coPackAggressive: Result := 'pack-fast';
    coUnpackPretty:   Result := 'unpack';
    coAuto:           Result := 'auto';
  else
    Result := 'unknown';
  end;
end;

class function TCssPacker.OperationFromName(const Name: string;
  out Operation: TCssOperation): Boolean;
var
  N: string;
begin
  N := LowerCase(Name);
  if (N = 'pack') or (N = 'safe') or (N = 'minify') or (N = 'pack-safe') then
    Operation := coPackSafe
  else if (N = 'fast') or (N = 'bootstrap') or (N = 'aggressive') or (N = 'pack-fast') then
    Operation := coPackAggressive
  else if (N = 'unpack') or (N = 'pretty') or (N = 'format') then
    Operation := coUnpackPretty
  else if N = 'auto' then
    Operation := coAuto
  else
    Exit(False);
  Result := True;
end;

class function TCssPacker.Version: string;
begin
  Result := CSSPACKER_VERSION;
end;

end.
