{ MIT No Attribution

Copyright 2010 Vasiliy Tereshkov vtereshkov@mail.ru

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

// Implementation of Gauss' method for linear systems

const
  MAXSIZE = 10;

type
  TVector = array [1..MAXSIZE] of Real;
  TMatrix = array [1..MAXSIZE] of TVector;



procedure Error(const E: string); forward;     // To be defined in the main module



procedure SolveLinearSystem(var T: TMatrix; var x: TVector; m: Integer);
var
  i, j, k: Integer;
  s: Real;

  procedure TriangularizeMatrix(var T: TMatrix; m: Integer);
  var
    i, j, k: Integer;
    r: Real;
  begin
  for k := 1 to m - 1 do
    for i := k + 1 to m do
      begin
      if T[k, k] = 0 then Error('Diagonal element is zero');

      r := -T[i, k] / T[k, k];

      for j := k to m + 1 do
        T[i, j] := T[i, j] + r * T[k, j];
      end;
  end;

begin
TriangularizeMatrix(T, m);

for i := m downto 1 do
  begin
  s := T[i, m + 1];
  for j := m downto i + 1 do
    s := s - T[i, j] * x[j];

  if T[i, i] = 0 then Error('Singular matrix');

  x[i] := s / T[i, i];
  end; // for

end;

