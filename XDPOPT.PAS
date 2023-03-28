{$MODE DELPHI}
// ----- OPTIMIZER -----
UNIT xdpopt;

INTERFACE

procedure MarkBlockNotDead(i: Integer);

IMPLEMENTATION

USES xdpglob;

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

