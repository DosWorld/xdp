{ MIT No Attribution

Copyright 2010 Vasiliy Tereshkov

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

// Linear equations solver

program LinEq;

{$I samples\gauss.inc}

procedure Error;
begin
WriteLn;
WriteLn('Error: ', E, '.');
ReadLn;
Halt(1);
end;



var
  A: TMatrix;
  x: TVector;
  m, i, j: Integer;

  DatName, Comment: string;
  DatFile: Text;
  Err: Integer;



begin
WriteLn;
WriteLn('Linear equations solver');
WriteLn;
Write('File name   : '); ReadLn(DatName);
WriteLn;

Reset(DatFile, DatName);
Err := IOResult;
if Err <> 0 then
  begin
  WriteLn('Unable to open file: ', DatName, ' (error code ', Err, ')');
  ReadLn;
  Halt(1);
  end;

ReadLn(DatFile, Comment);
WriteLn('Comment     : ', Comment);
WriteLn;

ReadLn(DatFile, m);
WriteLn('System order: ', m);
WriteLn;

WriteLn('Augmented ', m, ' x ', m + 1, ' matrix: ');
WriteLn;

for i := 1 to m do
  begin
  for j := 1 to m + 1 do
    begin
    Read(DatFile, A[i, j]);
    Write(A[i, j], ' ');
    end;
  ReadLn(DatFile);  
  WriteLn;
  end;

Close(DatFile);

SolveLinearSystem(A, x, m);

WriteLn;
WriteLn('Triangularized matrix:');
WriteLn;

for i := 1 to m do
  begin
  for j := 1 to m + 1 do
    Write(A[i, j], ' ');
  WriteLn;
  end;

WriteLn;
WriteLn('Solution: ');
WriteLn;

for i := 1 to m do
  WriteLn('x', i, ' = ', x[i]);

WriteLn;
WriteLn('Done.');
ReadLn;
end.
