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
UNIT xdutils;
{ ----- GENERAL ROUTINES ----- }
INTERFACE

USES xdtypes, xdscan;

FUNCTION BaseName(s : STRING):STRING;
FUNCTION GetPathName(s : STRING):STRING;
procedure ChangeExt(const InStr, Ext: TString; var OutStr: TString);

function GetKeyword(const S: TKeyName): Integer;

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

IMPLEMENTATION

USES xdglob;

FUNCTION BaseName(s : STRING):STRING;
VAR i : INTEGER;
BEGIN
        i := Length(s);
        WHILE i >= 0 DO BEGIN
                IF s[i] IN [':','\','/'] THEN BREAK;
                Dec(i);
        END;
        IF i <> 0 THEN s := Copy(s, i+1, Length(s) - i);
        BaseName := s;
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
        GetPathName := s;
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

function GetKeyword(const S: TKeyName): Integer;
var     Max, Mid, Min : Integer;
        Found         : Boolean;
begin
        // Binary search
        Min := 1;
        Max := NUMKEYWORDS;

        repeat
                Mid := (Min + Max) div 2;
                if S > Keyword[Mid] then Min := Mid + 1
                else Max := Mid - 1;
                Found := S = Keyword[Mid];
        until Found or (Min > Max);

        if Found then GetKeyword := NUMDELIMITERS + Mid
        ELSE GetKeyword := 0;
end;

  
function GetField(RecType: Byte; const S: TName): Integer;
var     FieldIndex: Integer;
begin
        FieldIndex := 1;
        while FieldIndex <= Types[RecType].NumFields do begin
                if Types[RecType].Field[FieldIndex]^.Name = S then begin
                        GetField := FieldIndex;
                        EXIT;
                end;
                Inc(FieldIndex);
        end;

        Error('Unknown field: ' + S);
        GetField := 0;
end;      




function GetSpelling(var Tok: TToken): TString;
var     r : TString;
begin
        r := 'unknown token';
        if Tok.Kind = 0 then r := 'no token'
        else if Tok.Kind <= NUMDELIMITERS then
                case Tok.Kind of
                OPARTOK:        r := '(';
                CPARTOK:        r := ')';
                MULTOK:         r := '*';
                PLUSTOK:        r := '+';
                COMMATOK:       r := ',';
                MINUSTOK:       r := '-';
                PERIODTOK:      r := '.';
                RANGETOK:       r := '..';
                DIVTOK:         r := '/';
                COLONTOK:       r := ':';
                ASSIGNTOK:      r := ':=';
                SEMICOLONTOK:   r := ';';
                LTTOK:          r := '<';
                LETOK:          r := '<=';
                NETOK:          r := '<>';
                EQTOK:          r := '=';
                GTTOK:          r := '>';
                GETOK:          r := '>=';
                ADDRESSTOK:     r := '@';
                OBRACKETTOK:    r := '[';
                CBRACKETTOK:    r := ']';
                DEREFERENCETOK: r := '^';
                end // case
        else if Tok.Kind <= NUMDELIMITERS + NUMKEYWORDS then
                r := Keyword[Tok.Kind - NUMDELIMITERS]
        else if Tok.Kind = IDENTTOK then
                r := 'identifier'
        else if (Tok.Kind = INTNUMBERTOK) or (Tok.Kind = FRACNUMBERTOK) then
                r := 'number'
        else if (Tok.Kind = CHARLITERALTOK) or (Tok.Kind = STRINGLITERALTOK) then
                r := 'literal';
        GetSpelling := r;
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
        case Types[DataType].TypeKind of
        INTEGERTYPE:  LowBound := Low(Integer);
        SMALLINTTYPE: LowBound := Low(SmallInt);
        SHORTINTTYPE: LowBound := Low(ShortInt);
        CHARTYPE:     LowBound := 0;
        BOOLEANTYPE:  LowBound := -1;
        SUBRANGETYPE: LowBound := Types[DataType].Low;
        else begin
                Error('Ordinal type expected');
                LowBound := 0;
        end;
        end;
end;

                        



function HighBound(DataType: Byte): Integer;
begin
        case Types[DataType].TypeKind of
        INTEGERTYPE:  HighBound := High(Integer);
        SMALLINTTYPE: HighBound := High(SmallInt);
        SHORTINTTYPE: HighBound := High(ShortInt);
        CHARTYPE:     HighBound := 255;
        BOOLEANTYPE:  HighBound := 0;
        SUBRANGETYPE: HighBound := Types[DataType].High;
        else begin
                Error('Ordinal type expected');
                HighBound := 0;
        end;
        end;
end;


function TypeSize(DataType: Byte): Integer;
var     i, r : Integer;
begin
        r := 0;
        case Types[DataType].TypeKind of
        INTEGERTYPE:  r := SizeOf(Integer);
        SMALLINTTYPE: r := SizeOf(SmallInt);
        SHORTINTTYPE: r := SizeOf(ShortInt);
        CHARTYPE:     r := SizeOf(Char);
        BOOLEANTYPE:  r := SizeOf(Boolean);
        REALTYPE:     r := SizeOf(Single);
        POINTERTYPE:  r := SizeOf(Pointer);
        TEXTTYPE:     r := SizeOf(Integer);
        ARRAYTYPE:    r := (HighBound(Types[DataType].IndexType) - LowBound(Types[DataType].IndexType) + 1) * TypeSize(Types[DataType].BaseType);
        RECORDTYPE:   begin
                for i := 1 to Types[DataType].NumFields do
                        r := r + TypeSize(Types[DataType].Field[i]^.DataType);
        end;
        SUBRANGETYPE: r := SizeOf(Integer);               
        else Error('Illegal type');
        end;
        TypeSize := r;
end;

function GetCompatibleType(LeftType, RightType: Byte): Byte;
VAR     r : BYTE;
begin
        r := 0;
        if LeftType = RightType then r := LeftType
        else begin
                { Untyped pointers compatible with any other pointers }
                if (Types[LeftType].TypeKind = POINTERTYPE) and (Types[RightType].TypeKind = POINTERTYPE) and
                ((Types[LeftType].BaseType = ANYTYPE) or (Types[RightType].BaseType = ANYTYPE)) then
                        r := LeftType
                else if Types[LeftType].TypeKind = SUBRANGETYPE then
                        r := GetCompatibleType(Types[LeftType].HostType, RightType)
                else if Types[RightType].TypeKind = SUBRANGETYPE then
                        r := GetCompatibleType(LeftType, Types[RightType].HostType)
                else if (Types[LeftType].TypeKind in IntegerTypes) and
                        (Types[RightType].TypeKind in IntegerTypes) then
                        r := LeftType
                else if (Types[LeftType].TypeKind = BOOLEANTYPE) and
                        (Types[RightType].TypeKind = BOOLEANTYPE) then
                        r := LeftType
                else if (Types[LeftType].TypeKind = CHARTYPE) and
                        (Types[RightType].TypeKind = CHARTYPE) then
                        r := LeftType;
        end;
        if r = 0 then Error('Incompatible types');  
        GetCompatibleType := r;
end;


function ConversionIsPossible(SrcType, DestType: Byte): Boolean;
begin
{ Implicit type conversion is possible if DestType is real
 and SrcType is integer or a subrange of integer }

        ConversionIsPossible := (Types[DestType].TypeKind = REALTYPE) and
        ((Types[SrcType].TypeKind in IntegerTypes) or
        ((Types[SrcType].TypeKind = SUBRANGETYPE) and
                (Types[Types[SrcType].HostType].TypeKind in IntegerTypes)));
end;





procedure AssertIdent;
begin
        if Tok.Kind <> IDENTTOK then Error('Identifier expected but ' + GetSpelling(Tok) + ' found');
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

end.


