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

// Cannabola plot program

program Cannabis;

const
  dt0 = 0.003;
  scale = 120;


var
  r, rold, rdot, t, dt, x, y: Real;


begin
SetScreenMode($10);   // 640 x 350 pixels, 16 colors

t    := 0;
dt   := dt0;
rold := 0;

while t <= 2 * pi do
  begin
  r := (1 + sin(t)) * (1 + 0.9 * cos(8 * t)) * (1 + 0.1 * cos(24 * t)) * (0.5 + 0.05 * cos(200 * t));

  x := r * cos(t);
  y := r * sin(t);

  rdot := abs(r - rold) / dt;

  dt := dt0 / (1 + rdot);

  PutPixel(320 + Round(scale * x), 290 - Round(scale * y), 10);
  
  t := t + dt;
  rold := r;
  end;

repeat until KeyPressed;
SetScreenMode($03);
end.
