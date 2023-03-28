{ MIT No Attribution

Copyright 2010 Vasiliy Tereshkov
Copyright 2023 DosWorld

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or
sell copies of the Software, and to permit persons to whom
the Software is furnished to do so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.}
{$I-,R-,S-}
{ ----- SCANNER ----- }
UNIT xdscan;

INTERFACE

USES xdtypes;

procedure InitScanner;
procedure EnterIncludedFile(const Name: TString);
procedure LeaveIncludedFile(var ch: Char);
procedure NextTok;
procedure CheckTok(ExpectedTokKind: Byte);
procedure EatTok(ExpectedTokKind: Byte);

IMPLEMENTATION

USES xdglob, xdutils;

procedure InitScanner;
begin
        EndOfProgram := FALSE;
        UnitStackTop := 1;
        UnitStack[UnitStackTop].FileName := ProgramName;
        Assign(InFile, ProgramName);
        Reset(InFile);

        if IOResult <> 0 then
                Error('Unable to open source file ' + ProgramName);

        Line := 1;

        ch  := ' ';
        ch2 := ' ';
end;




procedure EnterIncludedFile(const Name: TString);
begin
        UnitStack[UnitStackTop].Pos := FilePos(InFile);
        UnitStack[UnitStackTop].Line := Line;

        Close(InFile);
        Assign(InFile, Name);
        Reset(InFile);

        if IOResult <> 0 then begin
                Assign(InFile, basename(Name));
                Reset(InFile);
                if IOResult <> 0 then begin
                        Assign(InFile, syspath + basename(Name));
                        Reset(InFile);
                        if IOResult <> 0 then Error('Unable to open source file ' + Name);
                end;
        end;

        Inc(UnitStackTop);
        UnitStack[UnitStackTop].FileName := Name;

        Line := 1;
end;




procedure LeaveIncludedFile(var ch: Char);
begin
        if UnitStackTop > 1 then begin
                Dec(UnitStackTop);
                Assign(InFile, UnitStack[UnitStackTop].FileName);
                Reset(InFile);
                Seek(InFile, UnitStack[UnitStackTop].Pos);
                Line := UnitStack[UnitStackTop].Line;
                Read(InFile, ch);
        end else begin
                EndOfProgram := TRUE;
                ch := #0;
        end;
end;




procedure ReadChar(var ch: Char);
begin
        if EndOfProgram then ch := #0
        else if EOF(InFile) then begin
                Close(InFile);
                LeaveIncludedFile(ch);
        end else Read(InFile, ch);
        if ch = #10 then Inc(Line); // End of line found
end;



procedure ReadValidChar(var ch: Char);
begin
        ReadChar(ch);
        ch := UpCase(ch);
end;



procedure ReadLiteralChar(var ch: Char);
begin
        ReadChar(ch);
        if (ch = #0) or (ch = #10) then Error('Unterminated string');
end;




procedure ReadSingleLineComment;
begin
        while (ch <> #10) and not EndOfProgram do ReadChar(ch);
end;




procedure ReadMultiLineComment;
begin
        while (ch <> '}') and not EndOfProgram do ReadChar(ch);
end;


procedure ReadDirective;
var     Text: TString;
begin
        ReadChar(ch);
        if UpCase(ch) = 'I' then begin // Include directive found
                Text := '';
                ReadChar(ch);
                while (ch <> '}') and not EndOfProgram do begin
                        if not (ch in [#1..#31, ' ']) then Text := Text + ch;
                        ReadChar(ch);
                end;
                EnterIncludedFile(Text);
        end else Error('Unknown compiler directive');
end;



procedure ReadHexadecimalNumber;
var
  Num: Integer;
  NumFound: Boolean;
begin
Num := 0;

NumFound := FALSE;
while ch in ['0'..'9', 'A'..'F'] do
  begin
  if ch in ['0'..'9'] then
    Num := 16 * Num + Ord(ch) - Ord('0')
  else
    Num := 16 * Num + Ord(ch) - Ord('A') + 10;
  NumFound := TRUE;
  ReadValidChar(ch);
  end;

if not NumFound then
  Error('Hexadecimal constant is not found');

Tok.Kind := INTNUMBERTOK;
Tok.Value := Num;
end;



procedure ReadDecimalNumber;
var
  Num, Expon: Integer;
  Frac, FracWeight: Single;
  NegExpon, RangeFound, ExponFound: Boolean;
begin
Num := 0;
Frac := 0;
Expon := 0;
NegExpon := FALSE;

while ch in ['0'..'9'] do
  begin
  Num := 10 * Num + Ord(ch) - Ord('0');
  ReadValidChar(ch);
  end;

if (ch <> '.') and (ch <> 'E') then                                   // Integer number
  begin
  Tok.Kind := INTNUMBERTOK;
  Tok.Value := Num;
  end
else
  begin

  // Check for '..' token
  RangeFound := FALSE;
  if ch = '.' then
    begin
    ReadValidChar(ch2);
    if ch2 = '.' then                                                 // Integer number followed by '..' token
      begin
      Tok.Kind := INTNUMBERTOK;
      Tok.Value := Num;
      RangeFound := TRUE;
      end;
    if not EndOfProgram then Seek(InFile, FilePos(InFile) - 1);
    end; // if ch = '.'
    
  if not RangeFound then                                              // Fractional number
    begin

    // Check for fractional part
    if ch = '.' then
      begin
      FracWeight := 0.1;
      ReadValidChar(ch);

      while ch in ['0'..'9'] do
        begin
        Frac := Frac + FracWeight * (Ord(ch) - Ord('0'));
        FracWeight := FracWeight / 10;
        ReadValidChar(ch);
        end;
      end; // if ch = '.'

    // Check for exponent
    if ch = 'E' then
      begin
      ReadValidChar(ch);

      // Check for exponent sign
      if ch = '+' then
        ReadValidChar(ch)
      else if ch = '-' then
        begin
        NegExpon := TRUE;
        ReadValidChar(ch);
        end;

      ExponFound := FALSE;
      while ch in ['0'..'9'] do
        begin
        Expon := 10 * Expon + Ord(ch) - Ord('0');
        ReadValidChar(ch);
        ExponFound := TRUE;
        end;

      if not ExponFound then
        Error('Exponent is not found');

      if NegExpon then Expon := -Expon;
      end; // if ch = 'E'

    Tok.Kind := FRACNUMBERTOK;
    Tok.FracValue := (Num + Frac) * exp(Expon * ln(10));
    end; // if not RangeFound
  end; // else
end;


procedure ReadNumber;
begin
if ch = '$' then
  begin
  ReadValidChar(ch);
  ReadHexadecimalNumber;
  end
else
  ReadDecimalNumber;
end;    




procedure ReadCharCode;
begin
ReadValidChar(ch);

if not (ch in ['0'..'9', '$']) then
  Error('Character code is not found');

ReadNumber;

if Tok.Kind = FRACNUMBERTOK then
  Error('Integer character code expected');

Tok.Kind := CHARLITERALTOK;
end;


procedure ReadKeywordOrIdentifier;
var
  Text: TString;
  CurToken: Integer;
begin
Text := '';
repeat
  Text := Text + ch;
  ReadValidChar(ch);
until not (ch in ['A'..'Z', '_', '0'..'9']);

CurToken := GetKeyword(Text);
if CurToken <> 0 then               // Keyword found
  Tok.Kind := CurToken
else
  begin                             // Identifier found
  Tok.Kind := IDENTTOK;
  Tok.Name := Text;
  end;
end;



procedure ReadCharOrStringLiteral;
var
  Text: TString;
  EndOfLiteral: Boolean;
begin
Text := '';
EndOfLiteral := FALSE;

repeat
  ReadLiteralChar(ch);
  if ch <> '''' then
    Text := Text + ch
  else
    begin
    Read(InFile, ch2);
    if ch2 = '''' then                                                      // Apostrophe character found
      Text := Text + ch
    else
      begin
      if not EndOfProgram then Seek(InFile, FilePos(InFile) - 1);           // Discard ch2
      EndOfLiteral := TRUE;
      end;
    end;
until EndOfLiteral;

if Length(Text) = 1 then
  begin
  Tok.Kind := CHARLITERALTOK;
  Tok.Value := Ord(Text[1]);
  end
else
  Tok.Kind := STRINGLITERALTOK;

DefineStaticString(Tok, Text);    // A character literal is also copied to a single-character static string so this string can be passed to subroutines

ReadValidChar(ch);
end;




procedure NextTok;
var
  DivFound: Boolean;
begin
Tok.Kind := 0;

// Skip spaces, comments, directives
DivFound := FALSE;
while (ch in [#1..#31, ' ', '{']) or ((ch = '/') and not DivFound) do
  begin
  if ch = '{' then                                                      // Multi-line comment or directive
    begin
    ReadValidChar(ch);
    if ch = '$' then ReadDirective else ReadMultiLineComment;
    end
  else if ch = '/' then
    begin
    ReadValidChar(ch2);
    if ch2 = '/' then
      ReadSingleLineComment                                             // Single-line comment
    else
      begin
      if not EndOfProgram then Seek(InFile, FilePos(InFile) - 2);       // Discard ch and ch2
      DivFound := TRUE;
      end;
    end;
  ReadValidChar(ch);
  end;

// Read token
case ch of
  '0'..'9', '$':
    ReadNumber;
  '#':
    ReadCharCode;
  'A'..'Z', '_':
    ReadKeywordOrIdentifier;
  '''':
    ReadCharOrStringLiteral;
  ':':                              // Single- or double-character tokens
    begin
    Tok.Kind := COLONTOK;
    ReadValidChar(ch);
    if ch = '=' then
      begin
      Tok.Kind := ASSIGNTOK;
      ReadValidChar(ch);
      end;
    end;
  '>':
    begin
    Tok.Kind := GTTOK;
    ReadValidChar(ch);
    if ch = '=' then
      begin
      Tok.Kind := GETOK;
      ReadValidChar(ch);
      end;
    end;
  '<':
    begin
    Tok.Kind := LTTOK;
    ReadValidChar(ch);
    if ch = '=' then
      begin
      Tok.Kind := LETOK;
      ReadValidChar(ch);
      end
    else if ch = '>' then
      begin
      Tok.Kind := NETOK;
      ReadValidChar(ch);
      end;
    end;
  '.':
    begin
    Tok.Kind := PERIODTOK;
    ReadValidChar(ch);
    if ch = '.' then
      begin
      Tok.Kind := RANGETOK;
      ReadValidChar(ch);
      end;
    end;
else                                // Single-character tokens
  case ch of
    '=': Tok.Kind := EQTOK;
    ',': Tok.Kind := COMMATOK;
    ';': Tok.Kind := SEMICOLONTOK;
    '(': Tok.Kind := OPARTOK;
    ')': Tok.Kind := CPARTOK;
    '*': Tok.Kind := MULTOK;
    '/': Tok.Kind := DIVTOK;
    '+': Tok.Kind := PLUSTOK;
    '-': Tok.Kind := MINUSTOK;
    '^': Tok.Kind := DEREFERENCETOK;
    '@': Tok.Kind := ADDRESSTOK;
    '[': Tok.Kind := OBRACKETTOK;
    ']': Tok.Kind := CBRACKETTOK;
  else
    Error('Unexpected end of program');
  end; // case

  ReadValidChar(ch);
end; // case

end; // NextTok




procedure CheckTok(ExpectedTokKind: Byte);
var     ExpectedTok: TToken;
begin
        if Tok.Kind <> ExpectedTokKind then begin
                ExpectedTok.Kind := ExpectedTokKind;
                Error(GetSpelling(ExpectedTok) + ' expected but ' + GetSpelling(Tok) + ' found');
        end;
end;



procedure EatTok(ExpectedTokKind: Byte);
begin
        CheckTok(ExpectedTokKind);
        NextTok;
end;


end.
