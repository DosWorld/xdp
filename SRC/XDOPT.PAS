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
{ ----- OPTIMIZER ----- }
UNIT xdopt;

INTERFACE

procedure MarkBlockNotDead(i: Integer);

IMPLEMENTATION

USES xdglob;

procedure MarkBlockNotDead(i: Integer);
var
  j: Integer;
begin
BlockIsNotDead[i] := TRUE;
for j := 1 to NumBlocks do
  if ((CallGraph[i, j div 8] and (1 shl (j mod 8))) <> 0) and not BlockIsNotDead[j] then
    MarkBlockNotDead(j);
end;

end.

