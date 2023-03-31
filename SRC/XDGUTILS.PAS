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
UNIT xdgutils;

INTERFACE

USES xdtypes;

const isGen386 : boolean = true;

procedure Gen(b: Byte);
procedure GenStr(str : string);
procedure GenAt(Pos: LongInt; b: Byte);
procedure GenWord(w: Integer);
procedure GenWordAt(Pos: LongInt; w: Integer);
procedure GenDWord(dw: LongInt);

IMPLEMENTATION

USES xdglob, xdutils;

procedure Gen(b: Byte);
begin
        if (Pass = CALLDETERMPASS) or BlockIsNotDead[BlockStack[BlockStackTop]] then begin
                if Pass = CODEGENERATIONPASS then begin
                        if CodeSize > SEGMENTSIZE then Error('Maximum code size exceeded');
                        StaticCodeData[CodeSize] := b;
                end;
                Inc(CodeSize);
        end;
end;

procedure GenStr(str : string);
var i : integer;
begin
        if (Pass = CALLDETERMPASS) or BlockIsNotDead[BlockStack[BlockStackTop]] then begin
                if Pass = CODEGENERATIONPASS then begin
                        if CodeSize + length(str) > SEGMENTSIZE then Error('Maximum code size exceeded');
                        for i:=1 to length(str) do begin
                                StaticCodeData[CodeSize] := ord(str[i]);
                                Inc(CodeSize);
                        end;
                end else CodeSize := CodeSize + length(str);
        end;
end;

procedure GenAt(Pos: LongInt; b: Byte);
begin
        if (Pass = CODEGENERATIONPASS) and BlockIsNotDead[BlockStack[BlockStackTop]] then begin
                StaticCodeData[Pos] := b;
        end;
end;

procedure GenWord(w: Integer);
begin
        Gen(w and $ff); Gen((w shr 8) and $ff);
end;

procedure GenWordAt(Pos: LongInt; w: Integer);
begin
        GenAt(Pos, w and $ff); GenAt(Pos + 1, (w shr 8) and $ff);
end;

procedure GenDWord(dw: LongInt);
begin
        Gen(dw and $ff); Gen((dw shr 8) and $ff);
        dw := dw shr 16;
        Gen(dw and $ff); Gen((dw shr 8) and $ff);
end;

end.

