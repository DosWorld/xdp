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

ExeRelocs : array[0..1023] of MZ_RELOC;
WriteExeRelocsCount : word;

StaticCodeData: array [0..65535] of Byte;
StaticStringData: array [0..MAXSTATICSTRDATASIZE - 1] of Char;
CodePosStack: array [0..1023] of LongInt;
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
function FindIdentUnsafe(VAR S: TName): PIdentifier;
function FindIdent(S: TName): PIdentifier;
procedure DisposeAll;

procedure Error(const Msg: string);

IMPLEMENTATION

USES xdscan;

CONST
Ident    : PIdentifier = NIL;

procedure DisposeIdent(i : PIdentifier);
var     j : integer;
begin
        IF i = NIL THEN EXIT;
        IF i^.Kind IN [PROC, FUNC] THEN BEGIN
                FOR j := 1 TO i^.NumParams DO Dispose(i^.Param[j]);
                i^.NumParams := 0;
        END;
        { FreeMem(i, SizeOf(TIdentifier));}
        Dispose(i);
end;

PROCEDURE KillAllIdent;
VAR     n : PIdentifier;
BEGIN
        WHILE Ident <> NIL DO BEGIN
                n := Ident;
                Ident := Ident^.next;
                DisposeIdent(n);
        END;
END;

PROCEDURE KillLastIdent;
VAR     n : PIdentifier;
BEGIN
        IF Ident <> NIL THEN BEGIN
                n := Ident;
                Ident := Ident^.next;
                DisposeIdent(n);
        END;
END;

procedure ZeroAll;
begin
        KillAllIdent;
        NumTypes := 0;
        NumBlocks := 0;
        BlockStackTop := 0;
        CodeSize := 0;
        CodePosStackTop := 0;
        NumStaticStrChars := 0;
        GlobalDataSize := 0;
        WriteExeRelocsCount := 0;
end;

FUNCTION strhash(s : STRING):WORD;
VAR     h : WORD;
        i : INTEGER;
BEGIN
        h := 0;
        FOR i := 1 TO LENGTH(s) DO h := h * 33 + ORD(s[i]);
        strhash := h;
END;

function CreateIdent(S : String): PIdentifier;
VAR     n : PIdentifier;
begin
        New(n);
        { GetMem(n, SizeOf(TIdentifier)); }
        FillChar(n^, SizeOf(TIdentifier), #0);
        n^.next := Ident;
        Ident := n;
        Ident^.Name := S;
        Ident^.hash := strhash(Ident^.Name);
        CreateIdent := Ident;
end;

function LastIdent: PIdentifier;
begin
        LastIdent := Ident;
end;

function FindIdentUnsafe(VAR S: TName): PIdentifier;
var     BlockStackIndex : Integer;
        h               : WORD;
        r               : PIdentifier;
        curIdx          : Integer;
BEGIN
        h := strhash(s);
        BlockStackIndex := BlockStackTop;
        r := NIL;
        WHILE (BlockStackIndex > 0) and (r = NIL) do begin
                curIdx := BlockStack[BlockStackIndex];
                r := Ident;
                while r <> NIL do begin
                        if (h = r^.hash) and (r^.Block = curIdx) then
                                if (r^.Name = S) then BREAK;
                        r := r^.next;
                end;
                Dec(BlockStackIndex);
        END;
        FindIdentUnsafe := r;
END;

function FindIdent(S: TName): PIdentifier;
VAR     r : PIdentifier;
begin
        r := FindIdentUnsafe(S);
        if r = nil then Error('Unknown identifier: ' + S);
        FindIdent := r;
end;

procedure DisposeAll;
var     i, j: Integer;
begin
        KillAllIdent;
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
