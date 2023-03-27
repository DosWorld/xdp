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

// Factorization demo

program Factor;

var
  LowBound, HighBound, Number, Dividend, Divisor, MaxDivisor: Integer;
  DivisorFound: Boolean;


begin
WriteLn;
WriteLn('Integer factorization demo');
WriteLn;
Write('From number: '); ReadLn(LowBound);
Write('To number  : '); ReadLn(HighBound);
WriteLn;

if LowBound < 2 then
  begin
  WriteLn('Numbers should be greater than 2');
  ReadLn;
  Halt(1);
  end;

for Number := LowBound to HighBound do
  begin
  Write(Number, ' = ');
  
  Dividend := Number;
  while Dividend > 1 do
    begin
    MaxDivisor := IMin(Round(Sqrt(Dividend)), Dividend - 1);
    Divisor := 1;
    DivisorFound := FALSE;
    
    while (Divisor <= MaxDivisor) and not DivisorFound do
      begin
      Inc(Divisor);
      if Dividend mod Divisor = 0 then DivisorFound := TRUE;
      end;
   
    if not DivisorFound then Divisor := Dividend;                // Prime number

    Write(Divisor, ' ');
    Dividend := Dividend div Divisor;
    end; // while
    
  WriteLn;  
  end; // for     

WriteLn;
WriteLn('Done.');

ReadLn;
end.
