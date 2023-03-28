{$MODE DELPHI}
UNIT xdpglob;

INTERFACE

USES xdptype;

const
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


var
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

IMPLEMENTATION

END.
