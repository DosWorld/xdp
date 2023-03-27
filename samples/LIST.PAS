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

// Linked list operations demo

program List;

type
  PPerson = ^TPerson;

  TPerson = record
    Next: PPerson;
    Name, Surname: string;
    Born: SmallInt;
  end;


var
  Head, Node, NewNode: PPerson;
  ch: Char;



begin
WriteLn;
WriteLn('Linked list operations demo');
WriteLn;

New(Node);
Head := Node;


// Fill the list
repeat
  Write('Add new record? (Y/N): '); ReadLn(ch);
  WriteLn;

  if (ch = 'y') or (ch = 'Y') then
    begin
    New(NewNode);
    Node^.Next := NewNode;
    Node := NewNode;
    Node^.Next := nil;
    Write('Name    : '); ReadLn(Node^.Name);
    Write('Surname : '); ReadLn(Node^.Surname);
    Write('Born in : '); ReadLn(Node^.Born);
    WriteLn; 
    end;
until (ch = 'n') or (ch = 'N');


WriteLn;
WriteLn('Record list: ');
WriteLn;


// Traverse the list
Node := Head^.Next;

while Node <> nil do
  begin
  WriteLn(Node^.Name, ' ', Node^.Surname, ', b. ', Node^.Born);
  Node := Node^.Next;
  end;


// Clear the list
Node := Head;

while Node <> nil do
  begin
  NewNode := Node^.Next;
  Dispose(Node);
  Node := NewNode;
  end;

WriteLn;
WriteLn('Done.');

ReadLn;
end.




