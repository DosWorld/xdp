{ MIT No Attribution

Copyright 2010 Vasiliy Tereshkov vtereshkov@mail.ru
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
UNIT xdglob;

INTERFACE

USES xdtypes;

CONST
  Keyword: array [1..NUMKEYWORDS] of TKeyName =
    (
    'AND',
    'ARRAY',
    'BEGIN',
    'CASE',
    'CONST',
    'DIV',
    'DO',
    'DOWNTO',
    'ELSE',
    'END',
    'EXTERNAL',
    'FOR',
    'FUNCTION',
    'IF',
    'INLINE',
    'MOD',
    'NIL',
    'NOT',
    'OF',
    'OR',
    'PROCEDURE',
    'PROGRAM',
    'RECORD',
    'REPEAT',
    'SHL',
    'SHR',
    'THEN',
    'TO',
    'TYPE',
    'UNTIL',
    'VAR',
    'WHILE',
    'XOR'
    );


VAR
Types: array [1..MAXTYPES] of TType;
UnitStack: array [1..MAXUNITNESTING] of TUnit;
ExeHeader : MZ_HEADER;
ExeRelocs : array[0..1023] of MZ_RELOC;
WriteExeRlocsCount : integer;
StaticCodeData: array [0..65535] of Byte;
StaticStringData: array [0..MAXSTATICSTRDATASIZE - 1] of Char;
CodePosStack: array [0..1023] of Integer;
BlockStack: array [1..MAXNESTING] of Byte;
CallGraph: array [0..MAXBLOCKS - 1, 0..MAXBLOCKS div 8 - 1] of Byte;    // Rows are callers, columns are callees
BlockIsNotDead: array [1..MAXBLOCKS] of Boolean;


NumTypes, VarDataOrigin, NumBlocks, BlockStackTop,
CodePosStackTop,
Pass, UnitStackTop, Line: Integer;
CodeSize, NumStaticStrChars, GlobalDataSize : LongInt;

syspath : string;

procedure ZeroAll;
function CreateIdent(S : String): PIdentifier;
function LastIdent: PIdentifier;
procedure KillLastIdent;
function FindIdentUnsafe(const S: TName): PIdentifier;
function FindIdent(const S: TName): PIdentifier;
procedure DisposeAll;

procedure Error(const Msg: string);

IMPLEMENTATION

USES xdscan;

VAR
Ident    : array [1..MAXIDENTS] of TIdentifier;
NumIdent : INTEGER;

procedure ZeroAll;
begin
        NumIdent := 0;
        NumTypes := 0;
        NumBlocks := 0;
        BlockStackTop := 0;
        CodeSize := 0;
        CodePosStackTop := 0;
        NumStaticStrChars := 0;
        GlobalDataSize := 0;
        WriteExeRlocsCount := 0;
        FillChar(ExeHeader, SizeOf(MZ_HEADER), #0);
        ExeHeader.sign := MZ_SIGN;
        ExeHeader.sp := $FFFE;
end;

FUNCTION strhash(s : STRING):WORD;
VAR     h : WORD;
        i : INTEGER;
BEGIN
        h := 0;
        FOR i := 1 TO LENGTH(s) DO h := h * 33 + ORD(s[i]);
        strhash := h;
END;

procedure DisposeIdent(PIdent : PIdentifier);
var     j : integer;
begin
        if PIdent = nil then exit;
        if PIdent^.Kind in [PROC, FUNC] then
                for j := 1 to PIdent^.NumParams do
                        Dispose(PIdent^.Param[j]);
        Dispose(PIdent);
end;

function CreateIdent(S : String): PIdentifier;
begin
        Inc(NumIdent);
        Ident[NumIdent].Name := S;
        Ident[NumIdent].hash := strhash(Ident[NumIdent].Name);
        CreateIdent := @Ident[NumIdent];
end;

function LastIdent: PIdentifier;
begin
        if NumIdent > 0 then LastIdent := @Ident[NumIdent]
        else LastIdent := nil;
end;

procedure KillLastIdent;
begin
        IF NumIdent > 0 THEN Dec(NumIdent);
end;

function FindIdentUnsafe(const S: TName): PIdentifier;
var     IdentIndex, BlockStackIndex : Integer;
        h                           : WORD;
begin
        h := strhash(s);
        BlockStackIndex := BlockStackTop;
        while BlockStackIndex > 0 do begin
                IdentIndex := NumIdent;
                while IdentIndex > 0 do begin
                                if h = Ident[IdentIndex].hash then
                                        if (Ident[IdentIndex].Name = S)
                                                and (Ident[IdentIndex].Block = BlockStack[BlockStackIndex]) then begin
                                                        FindIdentUnsafe := @Ident[IdentIndex];
                                                        EXIT;
                                end;
                        Dec(IdentIndex);
                end;
                Dec(BlockStackIndex);
        end;
        FindIdentUnsafe := nil;
end;

function FindIdent(const S: TName): PIdentifier;
VAR     r : PIdentifier;
begin
        r := FindIdentUnsafe(S);
        if r = nil then Error('Unknown identifier: ' + S);
        FindIdent := r;
end;

procedure DisposeAll;
var     i, j: Integer;
begin
{ Dispose dynamically allocated parameter data }
for i := 1 to NumIdent do
  if Ident[i].Kind in [PROC, FUNC] then
    for j := 1 to Ident[i].NumParams do
      Dispose(Ident[i].Param[j]);

{ Dispose dynamically allocated field data }
for i := 1 to NumTypes do
  if Types[i].TypeKind = RECORDTYPE then
    for j := 1 to Types[i].NumFields do
      Dispose(Types[i].Field[j]);
end;


procedure Error(const Msg: string);
begin
        WriteLn(UnitStack[UnitStackTop].FileName, '(', Line, '): ', Msg);
        DisposeAll;
        DestroyScanner;
        Halt(1);
end;

END.
