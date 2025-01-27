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
UNIT xdtypes;

INTERFACE

CONST
NUMDELIMITERS         = 22;
NUMKEYWORDS           = 33;

{ Standard token codes }

OPARTOK               = 1;
CPARTOK               = 2;
MULTOK                = 3;
PLUSTOK               = 4;
COMMATOK              = 5;
MINUSTOK              = 6;
PERIODTOK             = 7;
RANGETOK              = 8;
DIVTOK                = 9;
COLONTOK              = 10;
ASSIGNTOK             = 11;
SEMICOLONTOK          = 12;
LTTOK                 = 13;
LETOK                 = 14;
NETOK                 = 15;
EQTOK                 = 16;
GTTOK                 = 17;
GETOK                 = 18;
ADDRESSTOK            = 19;
OBRACKETTOK           = 20;
CBRACKETTOK           = 21;
DEREFERENCETOK        = 22;

ANDTOK                = 23;
ARRAYTOK              = 24;
BEGINTOK              = 25;
CASETOK               = 26;
CONSTTOK              = 27;
IDIVTOK               = 28;
DOTOK                 = 29;
DOWNTOTOK             = 30;
ELSETOK               = 31;
ENDTOK                = 32;
EXTERNALTOK           = 33;
FORTOK                = 34;
FUNCTIONTOK           = 35;
IFTOK                 = 36;
INLINETOK             = 37;
MODTOK                = 38;
NILTOK                = 39;
NOTTOK                = 40;
OFTOK                 = 41;
ORTOK                 = 42;
PROCEDURETOK          = 43;
PROGRAMTOK            = 44;
RECORDTOK             = 45;
REPEATTOK             = 46;
SHLTOK                = 47;
SHRTOK                = 48;
THENTOK               = 49;
TOTOK                 = 50;
TYPETOK               = 51;
UNTILTOK              = 52;
VARTOK                = 53;
WHILETOK              = 54;
XORTOK                = 55;

{ Non-standard token codes }

IDENTTOK              = 101;
INTNUMBERTOK          = 102;
FRACNUMBERTOK         = 103;
CHARLITERALTOK        = 104;
STRINGLITERALTOK      = 105;

{ Identifier kind codes }

CONSTANT              = 1;
USERTYPE              = 2;
VARIABLE              = 3;
PROC                  = 4;
FUNC                  = 5;

{ Type kinds }

ANYTYPE               = 1;
INTEGERTYPE           = 2;
SMALLINTTYPE          = 3;
SHORTINTTYPE          = 4;
CHARTYPE              = 5;
BOOLEANTYPE           = 6;
REALTYPE              = 7;
POINTERTYPE           = 8;
TEXTTYPE              = 9;
ARRAYTYPE             = 10;
RECORDTYPE            = 11;
SUBRANGETYPE          = 12;
FORWARDTYPE           = 101;

IntegerTypes          = [INTEGERTYPE, SMALLINTTYPE, SHORTINTTYPE];
OrdinalTypes          = IntegerTypes + [CHARTYPE, BOOLEANTYPE, SUBRANGETYPE];

{ Type indices }

ANYTYPEINDEX          = 1;      { Base type for untyped pointers }
INTEGERTYPEINDEX      = 2;
SMALLINTTYPEINDEX     = 3;
SHORTINTTYPEINDEX     = 4;
CHARTYPEINDEX         = 5;
BOOLEANTYPEINDEX      = 6;
REALTYPEINDEX         = 7;
POINTERTYPEINDEX      = 8;      { Untyped pointer, compatible with any other }
TEXTTYPEINDEX         = 9;      { Universal file type }
STRINGTYPEINDEX       = 10;

{ Predefined routine codes }

INCPROC               = 1;
DECPROC               = 2;
READPROC              = 3;
WRITEPROC             = 4;
READLNPROC            = 5;
WRITELNPROC           = 6;
INPPROC               = 7;      { Read from a port }
OUTPPROC              = 8;      { Write to a port }
NEWPROC               = 9;
DISPOSEPROC           = 10;
HALTPROC              = 11;
INTRPROC              = 12;

SIZEOFFUNC            = 15;
ORDFUNC               = 16;
CHRFUNC               = 17;
PREDFUNC              = 18;
SUCCFUNC              = 19;
ROUNDFUNC             = 20;
TRUNCFUNC             = 21;
ABSFUNC               = 22;
SQRFUNC               = 23;
SINFUNC               = 24;
COSFUNC               = 25;
ARCTANFUNC            = 26;
EXPFUNC               = 27;
LNFUNC                = 28;
SQRTFUNC              = 29;

{ Compiler parameters }

MAXSTRLENGTH          = 80;
MAXSTDTOKENLENGTH     = 9;
MAXNAMELENGTH         = 16;
{MAXIDENTS             = 1000;}
MAXTYPES              = 512;
MAXBLOCKS             = 64;    { Must be a multiple of 8 }
MAXNESTING            = 10;
MAXPARAMS             = 32;
MAXUNITNESTING        = 5;
MAXFIELDS             = 128;

SEGMENTSIZE           = $10000;
MAXSTATICSTRDATASIZE  = $FF00;

{ Compilation pass codes }

CALLDETERMPASS        = 1;
CODEGENERATIONPASS    = 2;

{ Scope levels }

GLOBAL                = 1;
LOCAL                 = 2;

{ Parameter passing }

VALPASSING            = 1;
CONSTPASSING          = 2;
VARPASSING            = 3;

SYSTEM_PAS            = '_system.pas';

TYPE

TString  = STRING[MAXSTRLENGTH];
TKeyName = STRING[MAXSTDTOKENLENGTH];
TName    = STRING[MAXNAMELENGTH];

PUnit = ^TUnit;
TUnit = RECORD
        FileName  : TString;
        Pos, Line : LongInt;
END;

PParam = ^TParam;
TParam = RECORD
        Name       : TName;
        DataType   : Byte;
        PassMethod : Byte;
END;

PField = ^TField;
TField = RECORD
        Name     : TName;
        DataType : Byte;
        Offset   : Integer;
END;

PType = ^TType;
TType = RECORD
        Block: BYTE;
        CASE TypeKind: BYTE OF
        SUBRANGETYPE: (HostType: BYTE;
                        Low, High: INTEGER);
        POINTERTYPE, ARRAYTYPE: (BaseType, IndexType: BYTE);
        RECORDTYPE:   (NumFields: Integer;
                        Field: array [1..MAXFIELDS] of ^TField);
        FORWARDTYPE:  (TypeIdentName: TName);   
END;

PConst = ^TConst;
TConst = RECORD
        CASE Kind : BYTE OF
        INTNUMBERTOK:  (Value: LONGINT);
        FRACNUMBERTOK: (FracValue: SINGLE);
END;

PIdentifier = ^TIdentifier;
TIdentifier = RECORD
        Kind                : BYTE;
        Name                : TName;
        Value               : LONGINT; { Value for a constant, address for a variable, procedure or function }
        FracValue           : SINGLE;
        Block               : BYTE;    { Index of a block in which the identifier is defined }
        NestingLevel        : BYTE;
        DataType            : BYTE;
        RecType             : BYTE;    { Parent record type code for a field }
        Scope               : BYTE;
        PassMethod          : BYTE;    { Value, CONST or VAR parameter status }
        NumParams           : BYTE;
        Param               : ARRAY [1..MAXPARAMS] OF PParam;
        ProcAsBlock         : BYTE;
        PredefIndex         : BYTE;
        IsUnresolvedForward : BOOLEAN;
        hash                : WORD;
        next                : PIdentifier;
END;

MZ_RELOC = RECORD
        ofs : WORD;
        seg : WORD;
END;


IMPLEMENTATION

END.

