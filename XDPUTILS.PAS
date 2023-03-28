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
UNIT xdputils;
// ----- GENERAL ROUTINES -----
INTERFACE

USES xdptype;

FUNCTION BaseName(s : STRING):STRING;
FUNCTION GetPathName(s : STRING):STRING;
procedure ChangeExt(const InStr, Ext: TString; var OutStr: TString);

procedure DisposeAll;  
procedure Error(const Msg: string);
function GetKeyword(const S: TKeyName): Integer;
function FindIdentUnsafe(const S: TName): PIdentifier;
function FindIdent(const S: TName): PIdentifier;

function GetField(RecType: Byte; const S: TName): Integer;
function GetSpelling(var Tok: TToken): TString;
procedure DefineStaticString(var Tok: TToken; const StrValue: TString);
function LowBound(DataType: Byte): Integer;
function HighBound(DataType: Byte): Integer;
function TypeSize(DataType: Byte): Integer;
function GetCompatibleType(LeftType, RightType: Byte): Byte;
function ConversionIsPossible(SrcType, DestType: Byte): Boolean;
procedure AssertIdent;
procedure CheckOperator(op: Byte; DataType: Byte);
procedure AddCallGraphChild(ParentBlock, ChildBlock: Integer);

FUNCTION strhash(s : STRING):WORD;

IMPLEMENTATION

USES xdpglob;

FUNCTION BaseName(s : STRING):STRING;
VAR i : INTEGER;
BEGIN
        i := Length(s);
        WHILE i >= 0 DO BEGIN
                IF s[i] IN [':','\','/'] THEN BREAK;
                Dec(i);
        END;
        IF i <> 0 THEN s := Copy(s, i+1, Length(s) - i);
        Result := s;
END;

FUNCTION GetPathName(s : STRING):STRING;
VAR i : INTEGER;
BEGIN
        i := Length(s);
        WHILE i >= 0 DO BEGIN
                IF s[i] IN [':','\','/'] THEN BREAK;
                Dec(i);
        END;
        IF i <> 0 THEN s := Copy(s, 1, i);
        Result := s;
END;

procedure ChangeExt(const InStr, Ext: TString; var OutStr: TString);
var     i, DotPos: Integer;
begin
        i := Length(InStr);
        DotPos := 0;
        
        while (i > 0) and (DotPos = 0) do begin
                if InStr[i] = '.' then DotPos := i;
                Dec(i);
        end;
        
        if DotPos > 0 then OutStr := Copy(InStr, 1, DotPos) + Ext
        else OutStr := InStr + Ext;
end;

procedure DisposeAll;
var
  i, j: Integer;
begin
// Dispose dynamically allocated parameter data
for i := 1 to NumIdent do
  if Ident[i].Kind in [PROC, FUNC] then
    for j := 1 to Ident[i].NumParams do
      Dispose(Ident[i].Param[j]);

// Dispose dynamically allocated field data
for i := 1 to NumTypes do
  if Types[i].TypeKind = RECORDTYPE then
    for j := 1 to Types[i].NumFields do
      Dispose(Types[i].Field[j]);
end;




procedure Error(const Msg: string);
begin
        WriteLn(BaseName(UnitStack[UnitStackTop].FileName), '(', Line, '): ', Msg);
        DisposeAll;
        Close(InFile);
        Close(OutFile);
        Halt(1);
end;




function GetKeyword(const S: TKeyName): Integer;
var     Max, Mid, Min : Integer;
        Found         : Boolean;
begin
        Result := 0;

        // Binary search
        Min := 1;
        Max := NUMKEYWORDS;

        repeat
                Mid := (Min + Max) div 2;
                if S > Keyword[Mid] then Min := Mid + 1
                else Max := Mid - 1;
                Found := S = Keyword[Mid];
        until Found or (Min > Max);

        if Found then Result := NUMDELIMITERS + Mid;
end;


function FindIdentUnsafe(const S: TName): PIdentifier;
var     IdentIndex, BlockStackIndex : Integer;
        h                           : WORD;
begin
        Result := nil;

        h := strhash(s);
        BlockStackIndex := BlockStackTop;
        while BlockStackIndex > 0 do begin
                IdentIndex := NumIdent;
                while IdentIndex > 0 do begin
                                if h = Ident[IdentIndex].hash then
                                        if (Ident[IdentIndex].Name = S)
                                                and (Ident[IdentIndex].Block = BlockStack[BlockStackIndex]) then begin
                                                        Result := @Ident[IdentIndex];
                                                        exit;
                                end;
                        Dec(IdentIndex);
                end;
                Dec(BlockStackIndex);
        end;
end;

function FindIdent(const S: TName): PIdentifier;
begin
        Result := FindIdentUnsafe(S);
        if Result = nil then Error('Unknown identifier: ' + S);
end;


function GetField(RecType: Byte; const S: TName): Integer;
var     FieldIndex: Integer;
begin
        Result := 0;

        FieldIndex := 1;
        while (FieldIndex <= Types[RecType].NumFields) and (Result = 0) do begin
                if Types[RecType].Field[FieldIndex]^.Name = S then Result := FieldIndex;
                Inc(FieldIndex);
        end;

        if Result = 0 then Error('Unknown field: ' + S);
end;      




function GetSpelling(var Tok: TToken): TString;
begin
        Result := 'unknown token';
        if Tok.Kind = 0 then Result := 'no token'
        else if Tok.Kind <= NUMDELIMITERS then
                case Tok.Kind of
                OPARTOK:        Result := '(';
                CPARTOK:        Result := ')';
                MULTOK:         Result := '*';
                PLUSTOK:        Result := '+';
                COMMATOK:       Result := ',';
                MINUSTOK:       Result := '-';
                PERIODTOK:      Result := '.';
                RANGETOK:       Result := '..';
                DIVTOK:         Result := '/';
                COLONTOK:       Result := ':';
                ASSIGNTOK:      Result := ':=';
                SEMICOLONTOK:   Result := ';';
                LTTOK:          Result := '<';
                LETOK:          Result := '<=';
                NETOK:          Result := '<>';
                EQTOK:          Result := '=';
                GTTOK:          Result := '>';
                GETOK:          Result := '>=';
                ADDRESSTOK:     Result := '@';
                OBRACKETTOK:    Result := '[';
                CBRACKETTOK:    Result := ']';
                DEREFERENCETOK: Result := '^';
                end // case
        else if Tok.Kind <= NUMDELIMITERS + NUMKEYWORDS then
                Result := Keyword[Tok.Kind - NUMDELIMITERS]
        else if Tok.Kind = IDENTTOK then
                Result := 'identifier'
        else if (Tok.Kind = INTNUMBERTOK) or (Tok.Kind = FRACNUMBERTOK) then
                Result := 'number'
        else if (Tok.Kind = CHARLITERALTOK) or (Tok.Kind = STRINGLITERALTOK) then
                Result := 'literal';
end;



procedure DefineStaticString(var Tok: TToken; const StrValue: TString);
var
  i: Integer;
begin
Tok.StrAddress := NumStaticStrChars;
Tok.StrLength := Length(StrValue);

for i := 1 to Length(StrValue) do
  begin
  StaticStringData[NumStaticStrChars] := StrValue[i];
  Inc(NumStaticStrChars);
  if NumStaticStrChars > MAXSTATICSTRDATASIZE - 1 then
    Error('Maximum string data size exceeded');
  end;

// Add string termination character
StaticStringData[NumStaticStrChars] := #0;
Inc(NumStaticStrChars);
end;





function LowBound(DataType: Byte): Integer;
begin
Result := 0;
case Types[DataType].TypeKind of
  INTEGERTYPE:  Result := Low(Integer);
  SMALLINTTYPE: Result := Low(SmallInt);
  SHORTINTTYPE: Result := Low(ShortInt);
  CHARTYPE:     Result := 0;
  BOOLEANTYPE:  Result := -1;
  SUBRANGETYPE: Result := Types[DataType].Low;
else
  Error('Ordinal type expected');
end;// case
end;

                        



function HighBound(DataType: Byte): Integer;
begin
Result := 0;
case Types[DataType].TypeKind of
  INTEGERTYPE:  Result := High(Integer);
  SMALLINTTYPE: Result := High(SmallInt);
  SHORTINTTYPE: Result := High(ShortInt);
  CHARTYPE:     Result := 255;
  BOOLEANTYPE:  Result := 0;
  SUBRANGETYPE: Result := Types[DataType].High;
else
  Error('Ordinal type expected');
end;// case
end;


function TypeSize(DataType: Byte): Integer;
var
  i: Integer;
begin
Result := 0;
case Types[DataType].TypeKind of
  INTEGERTYPE:  Result := SizeOf(Integer);
  SMALLINTTYPE: Result := SizeOf(SmallInt);
  SHORTINTTYPE: Result := SizeOf(ShortInt);
  CHARTYPE:     Result := SizeOf(Char);
  BOOLEANTYPE:  Result := SizeOf(Boolean);
  REALTYPE:     Result := SizeOf(Single);
  POINTERTYPE:  Result := SizeOf(Pointer);
  TEXTTYPE:     Result := SizeOf(Integer);
  ARRAYTYPE:    Result := (HighBound(Types[DataType].IndexType) - LowBound(Types[DataType].IndexType) + 1) * TypeSize(Types[DataType].BaseType);
  RECORDTYPE:   begin
                Result := 0;
                for i := 1 to Types[DataType].NumFields do
                  Result := Result + TypeSize(Types[DataType].Field[i]^.DataType);
                end;
  SUBRANGETYPE: Result := SizeOf(Integer);               
else
  Error('Illegal type');
end;// case
end;    

function GetCompatibleType(LeftType, RightType: Byte): Byte;
begin
Result := 0;

if LeftType = RightType then                 // General rule
  Result := LeftType
else                                         // Special cases
  begin
  // Untyped pointers compatible with any other pointers
  if (Types[LeftType].TypeKind = POINTERTYPE) and (Types[RightType].TypeKind = POINTERTYPE) and
     ((Types[LeftType].BaseType = ANYTYPE) or (Types[RightType].BaseType = ANYTYPE)) then
    Result := LeftType;

  // Subranges compatible with their host types
  if Types[LeftType].TypeKind = SUBRANGETYPE then
    Result := GetCompatibleType(Types[LeftType].HostType, RightType);
  if Types[RightType].TypeKind = SUBRANGETYPE then
    Result := GetCompatibleType(LeftType, Types[RightType].HostType);

  // Integers
  if (Types[LeftType].TypeKind in IntegerTypes) and
     (Types[RightType].TypeKind in IntegerTypes) then
    Result := LeftType;

  // Booleans
  if (Types[LeftType].TypeKind = BOOLEANTYPE) and
     (Types[RightType].TypeKind = BOOLEANTYPE) then
    Result := LeftType;

  // Characters
  if (Types[LeftType].TypeKind = CHARTYPE) and
     (Types[RightType].TypeKind = CHARTYPE) then
    Result := LeftType;
  end;// if

if Result = 0 then
  Error('Incompatible types');  
end;


function ConversionIsPossible(SrcType, DestType: Byte): Boolean;
begin
// Implicit type conversion is possible if DestType is real and SrcType is integer or a subrange of integer
Result := (Types[DestType].TypeKind = REALTYPE) and
          ((Types[SrcType].TypeKind in IntegerTypes) or
           ((Types[SrcType].TypeKind = SUBRANGETYPE) and (Types[Types[SrcType].HostType].TypeKind in IntegerTypes)));
end;





procedure AssertIdent;
begin
if Tok.Kind <> IDENTTOK then
  Error('Identifier expected but ' + GetSpelling(Tok) + ' found');
end;




procedure CheckOperator(op: Byte; DataType: Byte);
begin
if Types[DataType].TypeKind = SUBRANGETYPE then
  CheckOperator(op, Types[DataType].HostType)
else if (not (Types[DataType].TypeKind in (OrdinalTypes + [REALTYPE, POINTERTYPE]))) or
   ((Types[DataType].TypeKind = REALTYPE) and
       not (op in [MULTOK, DIVTOK, PLUSTOK, MINUSTOK, GTTOK, GETOK, EQTOK, NETOK, LETOK, LTTOK])) or
   ((Types[DataType].TypeKind in IntegerTypes) and
       not (op in [MULTOK, IDIVTOK, MODTOK, SHLTOK, SHRTOK, ANDTOK, PLUSTOK, MINUSTOK, ORTOK, XORTOK, NOTTOK, GTTOK, GETOK, EQTOK, NETOK, LETOK, LTTOK])) or
   ((Types[DataType].TypeKind = CHARTYPE) and
       not (op in [GTTOK, GETOK, EQTOK, NETOK, LETOK, LTTOK])) or
   ((Types[DataType].TypeKind = BOOLEANTYPE) and
       not (op in [ANDTOK, ORTOK, XORTOK, NOTTOK, GTTOK, GETOK, EQTOK, NETOK, LETOK, LTTOK])) or
   ((Types[DataType].TypeKind = POINTERTYPE) and
       not (op in [GTTOK, GETOK, EQTOK, NETOK, LETOK, LTTOK]))
then
  Error('Operator is not applicable');
end;  




procedure AddCallGraphChild(ParentBlock, ChildBlock: Integer);
begin
// Set bit at ParentBlock row, ChildBlock column
CallGraph[ParentBlock, ChildBlock div 8] := CallGraph[ParentBlock, ChildBlock div 8] or (1 shl (ChildBlock mod 8));
end;

FUNCTION strhash(s : STRING):WORD;
VAR     h : WORD;
        i : INTEGER;
BEGIN
        h := 0;
        FOR i := 1 TO LENGTH(s) DO h := h * 33 + ORD(s[i]);
        strhash := h;
END;

end.


