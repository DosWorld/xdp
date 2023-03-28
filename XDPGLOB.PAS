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
{$I-}
{$MODE DELPHI}
UNIT xdpglob;

INTERFACE

USES xdptype;

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
    'FOR',
    'FUNCTION',
    'IF',
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
Ident: array [1..MAXIDENTS] of TIdentifier;
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

Tok: TToken;

NumIdent, NumTypes, NumStaticStrChars, VarDataOrigin, NumBlocks, BlockStackTop,
CodeSize, CodePosStackTop, GlobalDataSize,
Pass, UnitStackTop, Line: Integer;

ProgramName, ExeName: TString;

InFile: file of Char;
OutFile: file of Byte;

EndOfProgram: Boolean;

ch, ch2: Char;
syspath : string;

procedure ZeroAll;

IMPLEMENTATION
  
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

END.
