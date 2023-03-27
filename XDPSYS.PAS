{ MIT No Attribution

Copyright 2010 Vasiliy Tereshkov
Copyright 2023 DosWorld

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software AND associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, AND/or
sell copies of the Software, AND to permit persons to whom
the Software is furnished to do so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.}

// System library

CONST
PI = 3.1415927;

SEEKSTART = 0;  
SEEKCUR   = 1;  
SEEKEND   = 2;

TYPE

LongInt = Integer;
Single  = Real;
PChar   = ^Char;

TStream = RECORD
        Data  : PChar;
        Index : Integer;
END;
PStream = ^TStream;  

TRegisters = RECORD
        AX, BX, CX, DX, DI, SI, DS, Flags: Integer;
END;  

VAR     RandSeed     : Integer;
        IOError      : Integer;
        LastReadChar : Char;

// System timer AND keyboard state

FUNCTION Timer: Integer;
VAR     Reg: TRegisters;
BEGIN
        Reg.AX := 0;
        Reg.CX := 0;
        Reg.DX := 0;
        Intr($1A, @Reg);
        Result := Reg.CX SHL 16 + Reg.DX;
END;
          
FUNCTION KeyPressed: Boolean;
VAR     Reg: TRegisters;
BEGIN
        Reg.AX := $0B00;
        Intr($21, @Reg);
        Result := (Reg.AX AND $FF) <> 0;
END;

// Mathematical routines

PROCEDURE Randomize;
BEGIN
        RandSeed := Timer;
END;

FUNCTION Random: Real;
BEGIN
        RandSeed := 1975433173 * RandSeed;
        Result := 0.5 * (RandSeed / $7FFFFFFF + 1.0);
END;

FUNCTION Min(x, y: Real): Real;
BEGIN
        IF x < y THEN Result := x ELSE Result := y;
END;

FUNCTION IMin(x, y: Integer): Integer;
BEGIN
        IF x < y THEN Result := x ELSE Result := y;
END;

FUNCTION Max(x, y: Real): Real;
BEGIN
        IF x > y THEN Result := x ELSE Result := y;
END;

FUNCTION IMax(x, y: Integer): Integer;
BEGIN
        IF x > y THEN Result := x ELSE Result := y;
END;

// File AND console I/O routines

PROCEDURE ReadConsole(VAR Ch: Char);
VAR     Reg: TRegisters;
BEGIN
        Reg.AX := $0100;
        Intr($21, @Reg);
        Ch := Char(Reg.AX AND $FF);
END;

PROCEDURE WriteConsole(Ch: Char);
VAR     Reg: TRegisters;
BEGIN
        Reg.AX := $0200;
        Reg.DX := Integer(Ch);
        Intr($21, @Reg);
END;

PROCEDURE ReWrite(VAR F: Text; CONST Name: string);
VAR     Reg: TRegisters;
BEGIN
        IOError := 0;

        Reg.SI := Integer(@Name) AND $FFFF;
        Reg.DS := Integer(@Name) SHR 16;
        Reg.BX := $22;
        Reg.DX := $12;
        Reg.CX := 0;
        Reg.DI := 0;
        Reg.Flags := 1;
        Reg.AX := $716C;
        Intr($21, @Reg);
        IF Reg.Flags AND 1 <> 0 THEN BEGIN
                Reg.AX := $3C00;
                Reg.CX := $0000;
                Reg.DX := Integer(@Name) AND $FFFF;
                Reg.DS := Integer(@Name) SHR 16;
                Intr($21, @Reg);
        END;
        IF Reg.Flags AND 1 <> 0 THEN IOError := Reg.AX ELSE F := Text(Reg.AX);
END;

PROCEDURE Reset(VAR F: Text; CONST Name: string);
VAR     Reg: TRegisters;
BEGIN
        IOError := 0;

        Reg.SI := Integer(@Name) AND $FFFF;
        Reg.DS := Integer(@Name) SHR 16;
        Reg.BX := $22;
        Reg.DX := $1;
        Reg.CX := 0;
        Reg.DI := 0;
        Reg.Flags := 1;
        Reg.AX := $716C;
        Intr($21, @Reg);
        IF Reg.Flags AND 1 <> 0 THEN BEGIN
                Reg.AX := $3D02;
                Reg.DX := Integer(@Name) AND $FFFF;
                Reg.DS := Integer(@Name) SHR 16;
                Intr($21, @Reg);
        END;
        IF Reg.Flags AND 1 <> 0 THEN IOError := Reg.AX ELSE F := Text(Reg.AX);
END;

PROCEDURE Close(F: Text);
VAR     Reg: TRegisters;
BEGIN
        IOError := 0;
        Reg.AX := $3E00;
        Reg.BX := Integer(F);
        Intr($21, @Reg);
END;

PROCEDURE BlockRead(F: Text; Buf: PChar; Len: SmallInt; VAR LenRead: SmallInt);
VAR     Reg: TRegisters;
BEGIN
        IOError := 0;
        Reg.AX := $3F00;
        Reg.BX := Integer(F);
        Reg.CX := Len;
        Reg.DX := Integer(Buf) AND $FFFF;
        Reg.DS := Integer(Buf) SHR 16;
        Intr($21, @Reg);
        LenRead := Reg.AX;
END;

PROCEDURE BlockWrite(F: Text; Buf: PChar; Len: SmallInt);
VAR     Reg: TRegisters;
BEGIN
        IOError := 0;
        Reg.AX := $4000;
        Reg.BX := Integer(F);
        Reg.CX := Len;
        Reg.DX := Integer(Buf) AND $FFFF;
        Reg.DS := Integer(Buf) SHR 16;
        Intr($21, @Reg);
END;

PROCEDURE DeleteFile(CONST Name: string);
VAR     Reg: TRegisters;
BEGIN
        IOError := 0;
        Reg.DI := Integer(@Name) AND $FFFF;
        Reg.DS := Integer(@Name) SHR 16;
        Reg.CX := 0;
        Reg.SI := 0;
        Reg.Flags := 1;
        Reg.AX := $7141;
        Intr($21, @Reg);
        IF Reg.Flags AND 1 <> 0 THEN BEGIN
                Reg.AX := $4100;
                Reg.DX := Integer(@Name) AND $FFFF;
                Reg.DS := Integer(@Name) SHR 16;
                Intr($21, @Reg);
        END;
END;

FUNCTION SeekFile(F: Text; Pos: Integer; Mode: ShortInt): Integer;
VAR     Reg: TRegisters;
BEGIN
        IOError := 0;
        Reg.AX := $4200 + Mode;
        Reg.BX := Integer(F);
        Reg.CX := Pos SHR 16;
        Reg.DX := Pos AND $FFFF;
        Intr($21, @Reg);
        Result :=  Reg.DX SHL 16 + Reg.AX;
        IF Reg.Flags AND 1 = 1 THEN IOError := Reg.AX;    // Error code
END;

PROCEDURE Seek(F: Text; Pos: Integer);
VAR     NewPos: Integer;
BEGIN
        NewPos := SeekFile(F, Pos, SEEKSTART);
        IF NewPos <> Pos THEN IOError := 1 ELSE IOError := 0;
END;

FUNCTION FilePos(F: Text): Integer;
BEGIN
        Result := SeekFile(F, 0, SEEKCUR);
END;

FUNCTION EOF(F: Text): Boolean;
VAR     OldPos: Integer;
BEGIN
        IF Integer(F) = 0 THEN Result := FALSE
        ELSE BEGIN  
                OldPos := SeekFile(F, 0, SEEKCUR);
                Result := SeekFile(F, 0, SEEKEND) = OldPos;
                OldPos := SeekFile(F, OldPos, SEEKSTART);
        END;
END;

FUNCTION IOResult: Integer;
BEGIN
        Result := IOError;
        IOError := 0;
END;

PROCEDURE WriteCh(F: Text; P: PStream; ch: Char);
VAR     Dest: PChar;
BEGIN
        IF P <> nil THEN BEGIN                      
                // String stream output
                Dest := PChar(Integer(P^.Data) + P^.Index);
                Dest^ := ch;
                Inc(P^.Index);
        END ELSE IF Integer(F) = 0 THEN WriteConsole(ch) // Console output
        ELSE BlockWrite(F, @ch, 1); // File output
END;

PROCEDURE WriteInt(F: Text; P: PStream; Number: Integer);
VAR     Digit, Weight : Integer;
        Skip          : Boolean;
BEGIN
        IF Number = 0 THEN WriteCh(F, P,  '0')
        ELSE BEGIN
                IF Number < 0 THEN BEGIN
                        WriteCh(F, P,  '-');
                        Number := -Number;
                END;

                Weight := 1000000000;
                Skip := TRUE;

                WHILE Weight >= 1 DO BEGIN
                        IF Number >= Weight THEN Skip := FALSE;

                        IF not Skip THEN BEGIN
                                Digit := Number DIV Weight;
                                WriteCh(F, P,  Char(ShortInt('0') + Digit));
                                Number := Number - Weight * Digit;
                        END;

                        Weight := Weight DIV 10;
                END; // WHILE
        END; // ELSE
END;

PROCEDURE WriteHex(F: Text; P: PStream; Number: Integer; Digits: ShortInt);
VAR     i, Digit: ShortInt;
BEGIN
        FOR i := Digits - 1 DOWNTO 0 DO BEGIN
                Digit := (Number SHR (i SHL 2)) AND $0F;
                IF Digit <= 9 THEN Digit := ShortInt('0') + Digit
                ELSE Digit := ShortInt('A') + Digit - 10;
                WriteCh(F, P,  Char(Digit));
        END; 
END;

PROCEDURE WritePointer(F: Text; P: PStream; Number: Integer);
BEGIN
        WriteHex(F, P, Number, 8);
END;

PROCEDURE WriteReal(F: Text; P: PStream; Number: Real);
CONST
FracBits = 16;

VAR     Integ, Frac, InvWeight, Digit, IntegExpon: Integer;
        Expon: Real;

BEGIN
        // Write sign
        IF Number < 0 THEN BEGIN
                WriteCh(F, P,  '-');
                Number := -Number;
        END;

        // Normalize number
        IF Number = 0 THEN Expon := 0 ELSE Expon := ln(Number) / ln(10);
        IF (Expon > 8) or (Expon < -3) THEN BEGIN
                IntegExpon := Trunc(Expon);
                IF IntegExpon < 0 THEN Dec(IntegExpon);
                Number := Number / exp(IntegExpon * ln(10));
        END ELSE IntegExpon := 0;  

        // Write integer part
        Integ := Trunc(Number);
        Frac  := Round((Number - Integ) * (1 SHL FracBits));

        WriteInt(F, P, Integ);  WriteCh(F, P, '.');

        // Write fractional part
        InvWeight := 10;

        WHILE InvWeight <= 10000 DO BEGIN
                Digit := (Frac * InvWeight) SHR FracBits;
                IF Digit > 9 THEN Digit := 9;
                WriteCh(F, P,  Char(ShortInt('0') + Digit));
                Frac := Frac - (Digit SHL FracBits) DIV InvWeight;
                InvWeight := InvWeight * 10;
        END; // WHILE

        // Write exponent
        IF IntegExpon <> 0 THEN  BEGIN
                WriteCh(F, P, 'e');  WriteInt(F, P, IntegExpon);
        END;
END;

PROCEDURE WriteString(F: Text; P: PStream; CONST s: string);
VAR     i: Integer;
BEGIN
        i := 0;
        WHILE s[i] <> #0 DO BEGIN
                WriteCh(F, P, s[i]);
                Inc(i);
        END; 
END;

PROCEDURE WriteBoolean(F: Text; P: PStream; Flag: Boolean);
BEGIN
        IF Flag THEN WriteString(F, P, 'TRUE') ELSE WriteString(F, P, 'FALSE');
END;

PROCEDURE WriteNewLine(F: Text; P: PStream);
BEGIN
        WriteCh(F, P, #13);  WriteCh(F, P, #10);
END;

PROCEDURE ReadCh(F: Text; P: PStream; VAR ch: Char);
VAR     Len  : SmallInt;
        Dest : PChar;
BEGIN
        IF P <> nil THEN BEGIN
                // String stream input
                Dest := PChar(Integer(P^.Data) + P^.Index);
                ch := Dest^;
                Inc(P^.Index);
        END ELSE IF Integer(F) = 0 THEN BEGIN
                // Console input
                ReadConsole(ch);
                IF ch = #13 THEN WriteConsole(#10);
        END  ELSE BEGIN
                // File input
                BlockRead(F, @ch, 1, Len);
                IF ch = #10 THEN BlockRead(F, @ch, 1, Len);
                IF Len <> 1 THEN ch := #0;
        END;
        LastReadChar := ch; // Required by ReadNewLine
END;

PROCEDURE ReadInt(F: Text; P: PStream; VAR Number: Integer);
VAR     Ch       : Char;
        Negative : Boolean;
BEGIN
        Number := 0;
        
        // Read sign
        Negative := FALSE;
        ReadCh(F, P, Ch);
        IF Ch = '+' THEN ReadCh(F, P, Ch)
        ELSE IF Ch = '-' THEN BEGIN
                Negative := TRUE;
                ReadCh(F, P, Ch);
        END;

        // Read number
        WHILE (Ch >= '0') AND (Ch <= '9') DO BEGIN
                Number := Number * 10 + ShortInt(Ch) - ShortInt('0');
                ReadCh(F, P, Ch);
        END; 

        IF Negative THEN Number := -Number;
END;

PROCEDURE ReadReal(F: Text; P: PStream; VAR Number: Real);
VAR     Ch       : Char;
        Negative, ExponNegative: Boolean;
        Weight   : Real;
        Expon    : Integer;
BEGIN
        Number := 0;
        Expon := 0;

        // Read sign
        Negative := FALSE;
        ReadCh(F, P, Ch);
        IF Ch = '+' THEN ReadCh(F, P, Ch)
        ELSE IF Ch = '-' THEN    BEGIN
                Negative := TRUE;
                ReadCh(F, P, Ch);
        END;

        // Read integer part
        WHILE (Ch >= '0') AND (Ch <= '9') DO BEGIN
                Number := Number * 10 + ShortInt(Ch) - ShortInt('0');
                ReadCh(F, P, Ch);
        END;

        IF Ch = '.' THEN BEGIN
                // Fractional part found
                ReadCh(F, P, Ch);

                // Read fractional part
                Weight := 0.1;
                WHILE (Ch >= '0') AND (Ch <= '9') DO BEGIN
                        Number := Number + Weight * (ShortInt(Ch) - ShortInt('0'));
                        Weight := Weight / 10;
                        ReadCh(F, P, Ch);
                END;
        END;

        IF (Ch = 'E') or (Ch = 'e') THEN BEGIN
                // Exponent found
                // Read exponent sign
                ExponNegative := FALSE;
                ReadCh(F, P, Ch);
                IF Ch = '+' THEN ReadCh(F, P, Ch)
                ELSE IF Ch = '-' THEN BEGIN
                        ExponNegative := TRUE;
                        ReadCh(F, P, Ch);
                END;

                // Read exponent
                WHILE (Ch >= '0') AND (Ch <= '9') DO BEGIN
                        Expon := Expon * 10 + ShortInt(Ch) - ShortInt('0');
                        ReadCh(F, P, Ch);
                END;

                IF ExponNegative THEN Expon := -Expon;
        END;

        IF Expon <> 0 THEN Number := Number * exp(Expon * ln(10));
        IF Negative THEN Number := -Number;
END;

PROCEDURE ReadString(F: Text; P: PStream; CONST s: string);
VAR     i  : Integer;
        Ch : Char;
BEGIN
        i := 0;
        ReadCh(F, P, Ch);

        WHILE Ch <> #10 DO BEGIN
                IF Ch <> #13 THEN BEGIN
                        s[i] := Ch;
                        Inc(i);
                END;
                ReadCh(F, P, Ch);
        END;

        s[i] := #0;
END;

PROCEDURE ReadNewLine(F: Text; P: PStream);
VAR     Ch: Char;
BEGIN
        Ch := LastReadChar;
        WHILE not EOF(F) AND (Ch <> #10) DO ReadCh(F, P, Ch);
        LastReadChar := #0;
END;

// String manipulation routines
FUNCTION StrLen(CONST s: string): SmallInt;
BEGIN
        Result := 0;
        WHILE s[Result] <> #0 DO Inc(Result);
END;

PROCEDURE StrCopy(VAR Dest: string; CONST Source: string);
VAR     i: Integer;
BEGIN
        i := -1;
        REPEAT
                Inc(i);
                Dest[i] := Source[i];
        UNTIL Source[i] = #0;
END;

PROCEDURE StrCat(VAR Dest: string; CONST Source: string);
VAR     i, j : Integer;
BEGIN
        i := 0;
        WHILE Dest[i] <> #0 DO Inc(i);
        j := -1;
        REPEAT 
                Inc(j);
                Dest[i + j] := Source[j];
        UNTIL Source[j] = #0;
END;

FUNCTION StrComp(CONST s1, s2: string): Integer;
VAR     i : Integer;
BEGIN
        Result := 0;
        i := -1;
        REPEAT 
                Inc(i);
                Result := Integer(s1[i]) - Integer(s2[i]);
        UNTIL (s1[i] = #0) or (s2[i] = #0) or (Result <> 0);
END;

PROCEDURE Val(CONST s: string; VAR Number: Real; VAR Code: Integer);
VAR     Stream : TStream;
BEGIN
        Stream.Data := @s;
        Stream.Index := 0;
        
        ReadReal(Text(0), @Stream, Number);
        
        IF Stream.Index - 1 <> StrLen(s) THEN Code := Stream.Index - 1
        ELSE Code := 0;
END;

PROCEDURE Str(Number: Real; VAR s: string);
VAR     Stream: TStream;
BEGIN
        Stream.Data := @s;
        Stream.Index := 0;

        WriteReal(Text(0), @Stream, Number);
        s[Stream.Index] := #0;
END;

PROCEDURE IVal(CONST s: string; VAR Number: Integer; VAR Code: Integer);
VAR     Stream: TStream;
BEGIN
        Stream.Data := @s;
        Stream.Index := 0;

        ReadInt(Text(0), @Stream, Number);

        IF Stream.Index - 1 <> StrLen(s) THEN Code := Stream.Index - 1
        ELSE Code := 0;
END;

PROCEDURE IStr(Number: Integer; VAR s: string);
VAR     Stream: TStream;
BEGIN
        Stream.Data := @s;
        Stream.Index := 0;

        WriteInt(Text(0), @Stream, Number);
        s[Stream.Index] := #0;
END;

// Graphics routines

PROCEDURE SetScreenMode(mode: Integer);
VAR     Reg: TRegisters;
BEGIN
        Reg.AX := $00 SHL 8 + mode;
        Intr($10, @Reg);
END;

PROCEDURE PutPixel(x, y, clr: Integer);
VAR     Reg: TRegisters;
BEGIN
        Reg.AX := $0C SHL 8 + clr;
        Reg.BX := 0;
        Reg.CX := x;
        Reg.DX := y;
        Intr($10, @Reg);
END;

PROCEDURE Line(x1, y1, x2, y2, clr: Integer);
VAR     x, y, xMax, xMin, yMax, yMin: Integer;
BEGIN
        IF x1 > x2 THEN BEGIN
                xMax := x1;
                xMin := x2;
        END ELSE BEGIN
                xMax := x2;
                xMin := x1;
        END;

        IF y1 > y2 THEN BEGIN
                yMax := y1;
                yMin := y2;
        END ELSE BEGIN
                yMax := y2;
                yMin := y1;
        END; 
 
        IF x1 = x2 THEN FOR y := yMin TO yMax DO PutPixel(x1, y, clr)
        ELSE IF y1 = y2 THEN FOR x := xMin TO xMax DO PutPixel(x, y1, clr)
        ELSE IF abs(yMax - yMin) < abs(xMax - xMin) THEN BEGIN
                FOR x := xMin TO xMax DO BEGIN
                        y := y1 + (y2 - y1) * (x - x1) DIV (x2 - x1); 
                        PutPixel(x, y, clr);
                END;
        END ELSE FOR y := yMin TO yMax DO BEGIN
                x := x1 + (x2 - x1) * (y - y1) DIV (y2 - y1); 
                PutPixel(x, y, clr);
        END
END;

PROCEDURE Circle(x, y, r, clr: Integer);
VAR     t, dt  : Real;
        dx, dy : Integer;
BEGIN
        t := 0;  dt := 0.5 / r;

        WHILE t < Pi / 2 DO BEGIN
                dx := Round(r * cos(t));
                dy := Round(r * sin(t));
                PutPixel(x + dx, y + dy, clr);
                PutPixel(x - dx, y + dy, clr);
                PutPixel(x - dx, y - dy, clr);
                PutPixel(x + dx, y - dy, clr);
                t := t + dt;
        END;
END;

PROCEDURE OutCharXY(x, y, clr: Integer; ch: Char);
CONST
CharSetOrigin = $F000 SHL 16 + $FA6E;

TYPE
TCharBitmap = ARRAY [0..7] of ShortInt;
PCharBitmap = ^TCharBitmap;
  
VAR     CharBitmap : PCharBitmap;
        i, j       : Integer;
BEGIN
        CharBitmap := PCharBitmap(CharSetOrigin + Integer(ch) SHL 3);

        FOR i := 0 TO 7 DO
                FOR j := 0 TO 7 DO
                        IF (CharBitmap^[i] AND (1 SHL j)) <> 0 THEN
                                PutPixel(x + 7 - j, y + i, clr);
END;

PROCEDURE OutTextXY(x, y, clr: Integer; CONST s: string);
VAR     i : Integer;
BEGIN
        i := 0;
        WHILE s[i] <> #0 DO BEGIN
                OutCharXY(x, y, clr, s[i]);
                x := x + 8;
                Inc(i);
        END;
END; 

