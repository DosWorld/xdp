{ MIT No Attribution

Copyright 2010 Vasiliy Tereshkov
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
{ ----- CODE GENERATOR ----- }
UNIT xdpgen;

INTERFACE

USES xdptype;

procedure Gen(b: Byte);
procedure GenStr(str : string);
procedure GenAt(Pos: LongInt; b: Byte);
procedure GenWord(w: Integer);
procedure GenWordAt(Pos: LongInt; w: Integer);
procedure GenDWord(dw: LongInt);

procedure PushConst(Value: LongInt);
procedure PushVarPtr(Addr: Integer; Scope: Byte; DeltaNesting: Byte);

procedure DerefPtr(DataType: Byte);
procedure GetArrayElementPtr(ArrType: Byte);
procedure GetFieldPtr(RecType: Byte; FieldIndex: Integer);
procedure SaveStackTop;
procedure RestoreStackTop;
procedure SaveFileHandle;
procedure RestoreFileHandle;

procedure GenerateIncDec(proc, Size: Byte);
procedure GenerateInpOutp(proc: Byte);
procedure GenerateNewDispose(proc: Byte; Size: Integer);
procedure GenerateHalt(err: Byte);
procedure GenerateInterrupt(IntNumber: Byte);
procedure GenerateRound(TruncMode: Boolean);

procedure GenerateFloat(Depth: Byte);
procedure GenerateMathFunction(func, ResultType: Byte);
procedure GenerateUnaryOperator(op: Byte; ResultType: Byte);
procedure GenerateBinaryOperator(op: Byte; ResultType: Byte);
procedure GenerateRelation(rel: Byte; ValType: Byte);

procedure GenerateAssignment(DesignatorType: Byte);
procedure GenerateStructuredAssignment(DesignatorType: Byte);
procedure GenerateCall(EntryPoint: LongInt; DeltaNesting: Byte);
procedure GenerateReturn(TotalParamsSize: Integer);
procedure GenerateIfCondition;
procedure GenerateWhileCondition;
procedure GenerateRepeatCondition;
procedure GenerateForCondition(CounterAddress: Integer; Scope, CounterSize: Byte; Down: Boolean);
procedure GenerateIfProlog;
procedure GenerateElseProlog;
procedure GenerateIfElseEpilog;
procedure GenerateCaseProlog;
procedure GenerateCaseEpilog(NumCaseStatements: Integer);
procedure GenerateCaseEqualityCheck(Value: LongInt);
procedure GenerateCaseRangeCheck(Value1, Value2: LongInt);
procedure GenerateCaseStatementProlog;
procedure GenerateCaseStatementEpilog;
procedure GenerateWhileEpilog;
procedure GenerateRepeatProlog;
procedure GenerateRepeatEpilog;
procedure GenerateForEpilog(CounterAddress: Integer; Scope, CounterSize: Byte; Down: Boolean);
procedure GenerateDeclarationProlog;
procedure GenerateDeclarationEpilog;
procedure GenerateProgramProlog;
procedure GenerateProgramEpilog;
procedure GenerateStackFrameProlog(TotalLocalVarsSize: Integer);
procedure GenerateStackFrameEpilog;
procedure GenerateForwardReference;
procedure GenerateForwardResolution(PIdent: PIdentifier);

IMPLEMENTATION

USES xdpglob, xdputils;

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




procedure PushConst(Value: LongInt);
begin
Gen($66); Gen($68); GenDWord(Value);                            // push Value
end;


procedure PushVarPtr(Addr: Integer; Scope: Byte; DeltaNesting: Byte);
const
  StaticLinkAddr = 2 * SizeOf(LongInt);
var
  i: Integer;  
begin
case Scope of
  GLOBAL:                                     // Global variable
    begin
    Gen($1E);                                                   // push ds
    Gen($68); GenWord(Addr);                                    // push Addr
    end;
  LOCAL:
    begin
    Gen($16);                                                   // push ss
    if DeltaNesting = 0 then                  // Strictly local variable
      begin
      Gen($8D); Gen($86); GenWord(Addr);                        // lea ax, [bp + Addr]
      end
    else                                      // Intermediate level variable
      begin
      Gen($8B); Gen($76); Gen(StaticLinkAddr);                  // mov si, [bp + StaticLinkAddr]
      for i := 1 to DeltaNesting - 1 do
        begin
        Gen($36); Gen($8B); Gen($74); Gen(StaticLinkAddr);      // mov si, ss:[si + StaticLinkAddr]
        end;
      Gen($8D); Gen($84); GenWord(Addr);                        // lea ax, [si + Addr]
      end;
    Gen($50);                                                   // push ax
    end;// if
end;// case
end;




procedure DerefPtr(DataType: Byte);
begin
Gen($5E);                                                       // pop si
Gen($07);                                                       // pop es

case TypeSize(DataType) of
  1: begin
     GenStr(#$26+#$8A+#$04+                           // mov al, es:[si]
     #$98+                                            // cbw
     #$66+#$98);                                      // cwde
     end;
  2: begin
     GenStr(#$26+#$8B+#$04+                           // mov ax, es:[si]
     #$66+#$98);                                      // cwde
     end;
  4: begin
     GenStr(#$66+#$26+#$8B+#$04);                     // mov eax, es:[si]
     end;
else
  Error('Internal fault: Illegal designator size');
end;

GenStr(#$66+#$50);                                    // push eax
end;


procedure GetArrayElementPtr(ArrType: Byte);

  function log2(x: LongWord): ShortInt;
  var
    i : Integer;
    r : ShortInt;
  begin
  r := -1;
  i := 0;
  while i <= 31 do begin
    if x = (1 shl i) then begin r := i; break; end;
    Inc(i);
    end;
    log2 := r;
  end;

var
  BaseTypeSize, IndexLowBound: Integer;
  Log2BaseTypeSize: ShortInt;

begin
Gen($66); Gen($58);                                             // pop eax           ; Array index

IndexLowBound := LowBound(Types[ArrType].IndexType);
if IndexLowBound = 1 then
  Gen($48)                                                      // dec ax
else if IndexLowBound <> 0 then
  begin
  Gen($2D); GenWord(IndexLowBound);                             // sub ax, IndexLowBound
  end;

BaseTypeSize := TypeSize(Types[ArrType].BaseType);
Log2BaseTypeSize := Log2(BaseTypeSize);

if Log2BaseTypeSize > 0 then
  begin
  Gen($C1); Gen($E0); Gen(Log2BaseTypeSize);                    // shl ax, Log2BaseTypeSize
  end
else if Log2BaseTypeSize < 0 then
  begin
  Gen($B9); GenWord(BaseTypeSize);                              // mov cx, BaseTypeSize
  Gen($F7); Gen($E1);                                           // mul cx
  end;

Gen($5B);                                                       // pop bx            ; Array base offset
Gen($03); Gen($D8);                                             // add bx, ax
Gen($53);                                                       // push bx
end;


procedure GetFieldPtr(RecType: Byte; FieldIndex: Integer);
var
  Offset: Integer;
begin
Offset := Types[RecType].Field[FieldIndex]^.Offset;
if Offset > 0 then
  begin
  Gen($58);                                                       // pop ax
  Gen($05); GenWord(Offset);                                      // add ax, Offset
  Gen($50);                                                       // push ax
  end;
end;




procedure SaveStackTop;
begin
GenStr(#$66+#$5A);        // pop edx
end;




procedure RestoreStackTop;
begin
GenStr(#$66+#$52);        // push edx
end;



procedure SaveFileHandle;
begin
GenStr(#$66+#$5F+            // pop edi
#$66+#$58+                   // pop eax  ; pop and discard unnecessary stream handle, i.e. 0
#$66+#$58);                  // pop eax  ; pop and discard unnecessary console handle, i.e. 0
end;




procedure RestoreFileHandle;
begin
GenStr(#$66+#$57);                                                   // push edi
end;



procedure GenerateIncDec(proc, Size: Byte);
begin
Gen($5E);                                                             // pop si
Gen($07);                                                             // pop es

case Size of
  1: begin
     Gen($26); Gen($FE);                                              // ... byte ptr es: ...
     end;
  2: begin
     Gen($26); Gen($FF);                                              // ... word ptr es: ...
     end;
  4: begin
     Gen($66); Gen($26); Gen($FF);                                    // ... dword ptr es: ...
     end;
  end;

case proc of
  INCPROC: Gen($04);                                                  // inc ... [si]
  DECPROC: Gen($0C);                                                  // dec ... [si]
  end;
end;




procedure GenerateInpOutp(proc: Byte);
begin
case proc of
  INPPROC:
    begin
    Gen($5E);                                                           // pop si
    Gen($07);                                                           // pop es
    Gen($66); Gen($5A);                                                 // pop edx
    Gen($EC);                                                           // in al, dx
    Gen($26); Gen($88); Gen($04);                                       // mov es:[si], al
    end;
  OUTPPROC:
    begin
    Gen($66); Gen($5B);                                                 // pop ebx
    Gen($66); Gen($5A);                                                 // pop edx
    Gen($8A); Gen($C3);                                                 // mov al, bl    
    Gen($EE);                                                           // out dx, al
    end;
end;// case
end;



procedure GenerateNewDispose(proc: Byte; Size: Integer);
begin
Gen($5E);                                                               // pop si
Gen($07);                                                               // pop es
case proc of
  NEWPROC:
    begin
    Gen($B4); Gen($48);                                                 // mov ah, 48h
    Gen($BB); GenWord((Size - 1) div 16 + 1);                           // mov bx, (Size - 1) div 16 + 1  ; paragraphs to allocate
    Gen($CD); Gen($21);                                                 // int 21h
    Gen($66); Gen($C1); Gen($E0); Gen(16);                              // shl eax, 16                    ; get total address from segment address
    Gen($66); Gen($26); Gen($89); Gen($04);                             // mov es:[si], eax
    end;
  DISPOSEPROC:
    begin
    Gen($B4); Gen($49);                                                 // mov ah, 49h
    Gen($26); Gen($C4); Gen($34);                                       // les si, es:[si]
    Gen($CD); Gen($21);                                                 // int 21h
    end;
end;// case
end;// GenerateNewDispose    




procedure GenerateHalt(err: Byte);
begin
Gen($B4); Gen($4C);                                                     // mov ah, 4Ch
Gen($B0); Gen(err);                                                     // mov al, err
Gen($CD); Gen($21);                                                     // int 21h
end;// GenerateHalt




procedure GenerateInterrupt(IntNumber: Byte);
begin
        Gen($5E);                     // pop     si
        Gen($07);                     // pop     es
        Gen($1E);                     // push    ds
        Gen($55);                     // push    bp
        Gen($89); Gen($F5);           // mov     bp,si
        Gen($26);
        Gen($FF); Gen($76); Gen($1C); // push    word ptr es:[bp+1Ch]
        Gen($26);
        Gen($8B); Gen($46); Gen($18); // mov     ax,es:[bp+18h]
        Gen($8E); Gen($D8);           // mov     ds,ax
        Gen($26);
        Gen($8B); Gen($46); Gen($00); // mov     ax,es:[bp]
        Gen($26);
        Gen($8B); Gen($5E); Gen($04); // mov     bx,es:[bp+4]
        Gen($26);
        Gen($8B); Gen($4E); Gen($08); // mov     cx,es:[bp+8]
        Gen($26);
        Gen($8B); Gen($56); Gen($0C); // mov     dx,es:[bp+0Ch]
        Gen($26);
        Gen($8B); Gen($7E); Gen($10); // mov     di,es:[bp+10h]
        Gen($26);
        Gen($8B); Gen($76); Gen($14); // mov     si,es:[bp+14h]
        Gen($9D);                     // popf 
        Gen($CD); Gen(IntNumber);     // int InterruptNumber
        Gen($9C);                     // pushf 
        Gen($26);
        Gen($89); Gen($46); Gen($00); // mov     es:[bp],ax
        Gen($26);
        Gen($89); Gen($5E); Gen($04); // mov     es:[bp+4],bx
        Gen($26);
        Gen($89); Gen($4E); Gen($08); // mov     es:[bp+8],cx
        Gen($26);
        Gen($89); Gen($56); Gen($0C); // mov     es:[bp+0Ch],dx
        Gen($26);
        Gen($89); Gen($7E); Gen($10); // mov     es:[bp+10h],di
        Gen($26);
        Gen($89); Gen($76); Gen($14); // mov     es:[bp+14h],si
        Gen($26);
        Gen($8F); Gen($46); Gen($1C); // pop     word ptr es:[bp+1Ch]
        Gen($5D);                     // pop     bp
        Gen($1F);                     // pop     ds
end;// GenerateInterrupt




procedure GenerateRound(TruncMode: Boolean);
begin
Gen($8B); Gen($DC);                                                   // mov bx, sp
Gen($36); Gen($D9); Gen($07);                                         // fld ss:[bx]   ;  st := operand
if TruncMode then
  begin
  Gen($36); Gen($C7); Gen($87); GenWord(-4); GenWord($0F7F);          // mov ss:[bx - 4], 0F7Fh
  Gen($36); Gen($D9); Gen($AF); GenWord(-4);                          // fldcw ss:[bx - 4]
  end;
Gen($36); Gen($DB); Gen($1F);                                         // fistp ss:[bx] ;  ss:[bx] := round(result);  pop
if TruncMode then
  begin
  Gen($36); Gen($C7); Gen($87); GenWord(-4); GenWord($037F);          // mov ss:[bx - 4], 037Fh
  Gen($36); Gen($D9); Gen($AF); GenWord(-4);                          // fldcw ss:[bx - 4]
  end;
end;// GenerateRound




procedure GenerateFloat(Depth: Byte);
begin
Gen($8B); Gen($DC);                                                   // mov bx, sp

if Depth > 0 then
  begin
  Gen($83); Gen($C3); Gen(Depth);                                     // add bx, Depth
  end;

Gen($36); Gen($DB); Gen($07);                                         // fild ss:[bx]  ;  st := float(operand)
Gen($36); Gen($D9); Gen($1F);                                         // fstp ss:[bx]  ;  ss:[bx] := result;  pop
end;// GenerateFloat

procedure GenerateMathFunction(func, ResultType: Byte);
begin
if Types[ResultType].TypeKind = REALTYPE then       // Real type
  begin
  Gen($8B); Gen($DC);                                                 // mov bx, sp
  Gen($36); Gen($D9); Gen($07);                                       // fld ss:[bx]  ;  st := x
  case func of
    ABSFUNC:
      begin
      Gen($D9); Gen($E1);                                             // fabs
      end;
    SQRFUNC:
      begin
      Gen($DC); Gen($C8);                                             // fmul st, st
      end;
    SINFUNC:
      begin
      Gen($D9); Gen($FE);                                             // fsin
      end;
    COSFUNC:
      begin
      Gen($D9); Gen($FF);                                             // fcos
      end;
    ARCTANFUNC:
      begin
      Gen($D9); Gen($E8);                                             // fld1
      Gen($D9); Gen($F3);                                             // fpatan    ; st := arctan(x / 1.0)
      end;
    EXPFUNC:
      begin
      Gen($D9); Gen($EA);                                             // fldl2e
      Gen($DE); Gen($C9);                                             // fmul
      Gen($D9); Gen($C0);                                             // fld st
      Gen($D9); Gen($FC);                                             // frndint
      Gen($DD); Gen($D2);                                             // fst st(2) ; st(2) := round(x * log2(e))
      Gen($DE); Gen($E9);                                             // fsub
      Gen($D9); Gen($F0);                                             // f2xm1     ; st := 2 ^ frac(x * log2(e)) - 1
      Gen($D9); Gen($E8);                                             // fld1
      Gen($DE); Gen($C1);                                             // fadd
      Gen($D9); Gen($FD);                                             // fscale    ; st := 2 ^ frac(x * log2(e)) * 2 ^ round(x * log2(e)) = exp(x)
      end;
    LNFUNC:
      begin
      Gen($D9); Gen($ED);                                             // fldln2
      Gen($D9); Gen($C9);                                             // fxch
      Gen($D9); Gen($F1);                                             // fyl2x     ; st := ln(2) * log2(x) = ln(x)
      end;
    SQRTFUNC:
      begin
      Gen($D9); Gen($FA);                                             // fsqrt
      end;

  end;// case

  Gen($36); Gen($D9); Gen($1F);                                       // fstp ss:[bx] ;  ss:[bx] := result;  pop
  end
else                                // Ordinal types
  case func of
    ABSFUNC:
      begin
      Gen($66); Gen($58);                                             // pop eax
      Gen($66); Gen($83); Gen($F8); Gen($00);                         // cmp eax, 0
      Gen($7D); Gen($03);                                             // jge +3
      Gen($66); Gen($F7); Gen($D8);                                   // neg eax
      Gen($66); Gen($50);                                             // push eax
      end;
    SQRFUNC:
      begin
      Gen($66); Gen($58);                                             // pop eax
      Gen($66); Gen($F7); Gen($E8);                                   // imul eax
      Gen($66); Gen($50);                                             // push eax
      end;
  end;// case
end;// GenerateMathFunction





procedure GenerateUnaryOperator(op: Byte; ResultType: Byte);
begin
if Types[ResultType].TypeKind = REALTYPE then     // Real type
  begin
  if op = MINUSTOK then
    begin
    Gen($8B); Gen($DC);                                                 // mov bx, sp
    Gen($36); Gen($D9); Gen($07);                                       // fld ss:[bx]  ;  st := operand
    Gen($D9); Gen($E0);                                                 // fchs
    Gen($36); Gen($D9); Gen($1F);                                       // fstp ss:[bx] ;  ss:[bx] := result;  pop
    end;
  end
else                                              // Ordinal types
  begin
  Gen($66); Gen($58);                                                   // pop eax
  case op of
    MINUSTOK:
      begin
      Gen($66); Gen($F7); Gen($D8);                                     // neg eax
      end;
    NOTTOK:
      begin
      Gen($66); Gen($F7); Gen($D0);                                     // not eax
      end;
  end;// case
  Gen($66); Gen($50);                                                   // push eax
  end;// else
  
end;




procedure GenerateBinaryOperator(op: Byte; ResultType: Byte);
begin
if Types[ResultType].TypeKind = REALTYPE then     // Real type
  begin
  Gen($8B); Gen($DC);                                                   // mov bx, sp
  Gen($36); Gen($D9); Gen($07);                                         // fld ss:[bx]  ;  st := operand2
  Gen($66); Gen($58);                                                   // pop eax
  Gen($8B); Gen($DC);                                                   // mov bx, sp
  Gen($36); Gen($D9); Gen($07);                                         // fld ss:[bx]  ;  st(1) := operand2;  st := operand1
  Gen($D9); Gen($C9);                                                   // fxch         ;  st := operand2;  st(1) := operand1

  case op of
    PLUSTOK:
      begin
      GenStr(#$DE+#$C1);                                               // fadd  ;  st(1) := st(1) + st;  pop
      end;
    MINUSTOK:
      begin
      GenStr(#$DE+#$E9);                                               // fsub  ;  st(1) := st(1) - st;  pop
      end;
    MULTOK:
      begin
      GenStr(#$DE+#$C9);                                               // fmul  ;  st(1) := st(1) * st;  pop
      end;
    DIVTOK:
      begin
      GenStr(#$DE+#$F9);                                               // fdiv  ;  st(1) := st(1) / st;  pop
      end;
  end;// case

  GenStr(#$36+#$D9+#$1F);                                         // fstp ss:[bx]  ;  ss:[bx] := result;  pop

  end // if
else                              // Ordinal types
  begin
  Gen($66); Gen($59);                                                   // pop ecx
  Gen($66); Gen($58);                                                   // pop eax

  case op of
    PLUSTOK:
      begin
      Gen($66); Gen($03); Gen($C1);                                     // add eax, ecx
      end;
    MINUSTOK:
      begin
      Gen($66); Gen($2B); Gen($C1);                                     // sub eax, ecx
      end;
    MULTOK:
      begin
      Gen($66); Gen($F7); Gen($E9);                                     // imul ecx
      end;
    IDIVTOK, MODTOK:
      begin
      Gen($66); Gen($99);                                               // cdq
      Gen($66); Gen($F7); Gen($F9);                                     // idiv ecx
      if op = MODTOK then
        begin
        Gen($66); Gen($8B); Gen($C2);                                   // mov eax, edx         ; save remainder
        end;
      end;
    SHLTOK:
      begin
      Gen($66); Gen($D3); Gen($E0);                                     // shl eax, cl
      end;
    SHRTOK:
      begin
      Gen($66); Gen($D3); Gen($E8);                                     // shr eax, cl
      end;
    ANDTOK:
      begin
      Gen($66); Gen($23); Gen($C1);                                     // and eax, ecx
      end;
    ORTOK:
      begin
      Gen($66); Gen($0B); Gen($C1);                                     // or eax, ecx
      end;
    XORTOK:
      begin
      Gen($66); Gen($33); Gen($C1);                                     // xor eax, ecx
      end;

  end;// case

  Gen($66); Gen($50);                                                   // push eax
  end;// else
end;




procedure GenerateRelation(rel: Byte; ValType: Byte);
begin
if Types[ValType].TypeKind = REALTYPE then        // Real type
  begin
  Gen($8B); Gen($DC);                                                   // mov bx, sp
  Gen($36); Gen($D9); Gen($07);                                         // fld ss:[bx]    ;  st := operand2
  Gen($66); Gen($58);                                                   // pop eax
  Gen($8B); Gen($DC);                                                   // mov bx, sp
  Gen($36); Gen($D9); Gen($07);                                         // fld ss:[bx]    ;  st(1) := operand2;  st := operand1
  Gen($66); Gen($58);                                                   // pop eax
  Gen($8B); Gen($DC);                                                   // mov bx, sp
  Gen($DE); Gen($D9);                                                   // fcompp         ;  test st - st(1)
  Gen($DF); Gen($E0);                                                   // fstsw ax
  Gen($66); Gen($68); GenDWord(-1);                                     // push FFFFFFFFh ;  TRUE
  Gen($9E);                                                             // sahf
  case rel of
    EQTOK: Gen($74);                                                    // je  ...
    NETOK: Gen($75);                                                    // jne ...
    GTTOK: Gen($77);                                                    // ja  ...
    GETOK: Gen($73);                                                    // jae ...
    LTTOK: Gen($72);                                                    // jb  ...
    LETOK: Gen($76);                                                    // jbe ...
  end;// case
  end
else                              // Ordinal types
  begin
  Gen($66); Gen($59);                                                   // pop ecx
  Gen($66); Gen($58);                                                   // pop eax
  Gen($66); Gen($68); GenDWord(-1);                                     // push FFFFFFFFh ;  TRUE
  Gen($66); Gen($3B); Gen($C1);                                         // cmp eax, ecx
  case rel of
    EQTOK: Gen($74);                                                    // je  ...
    NETOK: Gen($75);                                                    // jne ...
    GTTOK: Gen($7F);                                                    // jg  ...
    GETOK: Gen($7D);                                                    // jge ...
    LTTOK: Gen($7C);                                                    // jl  ...
    LETOK: Gen($7E);                                                    // jle ...
  end;// case
  end;// else

Gen($08);                                                               // ... +8
Gen($66); Gen($59);                                                     // pop ecx
Gen($66); Gen($68); GenDWord(0);                                        // push 00000000h ;  FALSE
end;





procedure GenerateAssignment(DesignatorType: Byte);
begin
// EDX should be preserved

// Source value
GenStr(#$66+#$58+                                                     // pop eax
// Destination address
#$5E+                                                               // pop si
#$07);                                                               // pop es

case TypeSize(DesignatorType) of
  1: begin
     Gen($26); Gen($88); Gen($04);                                      // mov es:[si], al
     end;
  2: begin
     Gen($26); Gen($89); Gen($04);                                      // mov es:[si], ax
     end;
  4: begin
     Gen($66); Gen($26); Gen($89); Gen($04);                            // mov es:[si], eax
     end;
else
  Error('Internal fault: Illegal designator size');
end;

end;




procedure GenerateStructuredAssignment(DesignatorType: Byte);
begin
Gen($8C); Gen($D8);                                                     // mov ax, ds
Gen($8B); Gen($DF);                                                     // mov bx, di   ; edi is used in Write, Read, etc. and should be preserved

// Source address
Gen($5E);                                                               // pop si
Gen($1F);                                                               // pop ds
// Destination address
Gen($5F);                                                               // pop di
Gen($07);                                                               // pop es

// Copy source to destination
Gen($B9); GenWord(TypeSize(DesignatorType));                            // mov cx, TypeSize(DesignatorType)
Gen($FC);                                                               // cld          ; increment si, di after each step
Gen($F3); Gen($A4);                                                     // rep movsb

Gen($8E); Gen($D8);                                                     // mov ds, ax
Gen($8B); Gen($FB);                                                     // mov di, bx
end;






procedure GenerateCall(EntryPoint: LongInt; DeltaNesting: Byte);
const
  StaticLinkAddr = 2 * SizeOf(LongInt);
var
  CodePos: Integer;
  i: Integer;
begin
// Push routine static link as the last hidden parameter (needed for nested routines)
if DeltaNesting = 0 then                       // The caller and the callee's enclosing routine are at the same nesting level
  begin
  Gen($66); Gen($55);                                                   // push ebp
  end
else                                           // The caller is deeper
  begin
  Gen($8B); Gen($76); Gen(StaticLinkAddr);                              // mov si, [bp + StaticLinkAddr]
  for i := 1 to DeltaNesting - 1 do
    begin
    Gen($36); Gen($8B); Gen($74); Gen(StaticLinkAddr);                  // mov si, ss:[si + StaticLinkAddr]
    end;
  Gen($66); Gen($56);                                                   // push esi
  end;

// Call the routine  
Gen($50);                                                               // push ax     ; align stack data on 32-bit bound
CodePos := CodeSize;
Gen($E8); GenWord(EntryPoint - (CodePos + 3));                          // call EntryPoint
Gen($58);                                                               // pop ax      ; align stack data on 32-bit bound
end;




procedure GenerateReturn(TotalParamsSize: Integer);
begin
Gen($C2); GenWord(TotalParamsSize + SizeOf(LongInt));                   // ret TotalParamsSize + 4   ; + 4 is for static link
end;




procedure GenerateIfCondition;
begin
Gen($66); Gen($58);                                         // pop eax
Gen($66); Gen($83); Gen($F8); Gen($00);                     // cmp eax, 0
Gen($75); Gen($03);                                         // jne +3
end;




procedure GenerateWhileCondition;
begin
GenerateIfCondition;
end;



procedure GenerateRepeatCondition;
begin
GenerateIfCondition;
end;




procedure GenerateForCondition(CounterAddress: Integer; Scope, CounterSize: Byte; Down: Boolean);
begin
Gen($66); Gen($59);                                         // pop ecx
Gen($66); Gen($51);                                         // push ecx             ; The final value of the counter will be removed from stack by GenerateForEpilog  
case Scope of
  GLOBAL:
    case CounterSize of
      1: begin
         Gen($A0);                                          // mov al, [...]
         end;
      2: begin
         Gen($A1);                                          // mov ax, [...]
         end;
      4: begin
         Gen($66); Gen($A1);                                // mov eax, [...]
         end;
      end;
  LOCAL:
    case CounterSize of
      1: begin
         Gen($8A); Gen($86);                                // mov al, [bp + ...]
         end;
      2: begin
         Gen($8B); Gen($86);                                // mov ax, [bp + ...]
         end;
      4: begin
         Gen($66); Gen($8B); Gen($86);                      // mov eax, [bp + ...]
         end;
      end;
    end;
    
GenWord(CounterAddress);                                    // ... CounterAddress ...

if CounterSize < 2 then
  Gen($98);                                                 // cbw
if CounterSize < 4 then
  begin
  Gen($66); Gen($98);                                       // cwde
  end;

Gen($66); Gen($3B); Gen($C1);                               // cmp eax, ecx
if Down then
  begin
  Gen($7D); Gen($03);                                       // jge +3
  end
else
  begin
  Gen($7E); Gen($03);                                       // jle +3
  end;
end;




procedure GenerateIfProlog;
begin
Inc(CodePosStackTop);
CodePosStack[CodePosStackTop] := CodeSize;
{
Gen($90);                                                   // nop   ; jump to the IF block end will be inserted here
Gen($90);                                                   // nop
Gen($90);                                                   // nop
}
GenStr(#$90+#$90+#$90);
end;




procedure GenerateElseProlog;
var
  CodePos: Integer;
begin
CodePos := CodePosStack[CodePosStackTop];
Dec(CodePosStackTop);

GenAt(CodePos, $E9); GenWordAt(CodePos + 1, CodeSize - (CodePos + 3) + 3);  // jmp (IF..THEN block end)

GenerateIfProlog;
end;




procedure GenerateIfElseEpilog;
var
  CodePos: Integer;
begin
CodePos := CodePosStack[CodePosStackTop];
Dec(CodePosStackTop);

GenAt(CodePos, $E9); GenWordAt(CodePos + 1, CodeSize - (CodePos + 3));      // jmp (IF..THEN block end)
end;




procedure GenerateCaseProlog;
begin
Gen($66); Gen($59);                                         // pop ecx           ; CASE switch value
Gen($B0); Gen($00);                                         // mov al, 00h       ; initial flag mask
end;




procedure GenerateCaseEpilog(NumCaseStatements: Integer);
var
  i: Integer;
begin
for i := 1 to NumCaseStatements do
  GenerateIfElseEpilog;
end;




procedure GenerateCaseEqualityCheck(Value: LongInt);
begin
Gen($66); Gen($81); Gen($F9); GenDWord(Value);              // cmp ecx, Value
Gen($9F);                                                   // lahf
Gen($0A); Gen($C4);                                         // or al, ah
end;





procedure GenerateCaseRangeCheck(Value1, Value2: LongInt);
begin
Gen($66); Gen($81); Gen($F9); GenDWord(Value1);             // cmp ecx, Value1
Gen($7C); Gen($0B);                                         // jl +11
Gen($66); Gen($81); Gen($F9); GenDWord(Value2);             // cmp ecx, Value2
Gen($7F); Gen($02);                                         // jg +2
Gen($0C); Gen($40);                                         // or al, 40h     ; set zero flag on success
end;




procedure GenerateCaseStatementProlog;
begin
Gen($24); Gen($40);                                         // and al, 40h    ; test zero flag
Gen($75); Gen($03);                                         // jnz +3         ; if set, jump to the case statement
GenerateIfProlog;
end;




procedure GenerateCaseStatementEpilog;
var
  StoredCodeSize: LongInt;
begin
StoredCodeSize := CodeSize;

Gen($90);                                                   // nop   ; jump to the CASE block end will be inserted here
Gen($90);                                                   // nop
Gen($90);                                                   // nop

GenerateIfElseEpilog;

Inc(CodePosStackTop);
CodePosStack[CodePosStackTop] := StoredCodeSize;
end;




procedure GenerateWhileEpilog;
var
  CodePos, CurPos, ReturnPos: Integer;
begin
CodePos := CodePosStack[CodePosStackTop];
Dec(CodePosStackTop);

GenAt(CodePos, $E9); GenWordAt(CodePos + 1, CodeSize - (CodePos + 3) + 3);  // jmp (WHILE..DO block end)

ReturnPos := CodePosStack[CodePosStackTop];
Dec(CodePosStackTop);

CurPos := CodeSize;

Gen($E9); GenWord(ReturnPos - (CurPos + 3));                                // jmp ReturnPos
end;




procedure GenerateRepeatProlog;
begin
Inc(CodePosStackTop);
CodePosStack[CodePosStackTop] := CodeSize;
end;




procedure GenerateRepeatEpilog;
var
  CurPos, ReturnPos: Integer;
begin
ReturnPos := CodePosStack[CodePosStackTop];
Dec(CodePosStackTop);

CurPos := CodeSize;

Gen($E9); GenWord(ReturnPos - (CurPos + 3));                // jmp ReturnPos
end;






procedure GenerateForEpilog(CounterAddress: Integer; Scope, CounterSize: Byte; Down: Boolean);
begin
PushVarPtr(CounterAddress, Scope, 0);
if Down then
  GenerateIncDec(DECPROC, CounterSize)
else
  GenerateIncDec(INCPROC, CounterSize);
GenerateWhileEpilog;

Gen($66); Gen($59);                                         // pop ecx    ; Remove the final value of the counter from the stack
end;




procedure GenerateDeclarationProlog;
begin
GenerateIfProlog;
end;




procedure GenerateDeclarationEpilog;
begin
GenerateIfElseEpilog;
end;




procedure GenerateProgramProlog;
begin
// Initialize segment registers
{ B80000                   mov     ax,0000h
  50                       push    ax
  50                       push    ax
  1F                       pop     ds
  07                       pop     es }
        GenStr(#$B8+#$00+#$00+#$50+#$50+#$1F+#$07);
        ExeRelocs[ExeHeader.relocs_count].seg := 0;
        ExeRelocs[ExeHeader.relocs_count].ofs := 1;
        Inc(ExeHeader.relocs_count);
// Initialize FPU
        GenStr(#$DB+#$E3); // finit
end;


procedure GenerateProgramEpilog;
var     CodeSegmentSize: Integer;
begin
        GenerateHalt(0);
// End of pure code
        while (CodeSize and $0f) <> 0 do Gen($90); // nop

// Complete program prolog
        CodeSegmentSize := CodeSize shr 4; // in paragraphs

        GenAt(1, CodeSegmentSize and $ff);
        GenAt(2, (CodeSegmentSize shr 8) and $ff);

// Build static string data table at the end of the executable file (i.e. at the beginning of data segment)
        while (NumStaticStrChars and $0f) <> 0 do begin
                StaticStringData[NumStaticStrChars] := #0;
                Inc(NumStaticStrChars);
        end;
        ExeHeader.ss := CodeSegmentSize + $1000;
        WriteExeRlocsCount := ExeHeader.relocs_count;
        while (SizeOf(MZ_HEADER) + SizeOf(MZ_RELOC) * WriteExeRlocsCount) and $0f <> 0 do begin
                ExeRelocs[WriteExeRlocsCount].seg := 0;
                ExeRelocs[WriteExeRlocsCount].ofs := 0;
                Inc(WriteExeRlocsCount);
        end;
        ExeHeader.header_par := (SizeOf(MZ_HEADER) + SizeOf(MZ_RELOC) * WriteExeRlocsCount) shr 4;
        ExeHeader.blk_count := ((CodeSize + NumStaticStrChars) SHR 9) + 1;
        ExeHeader.lblk_size := ((CodeSize + NumStaticStrChars) AND $1FF);
        ExeHeader.relocs_ofs := SizeOf(MZ_HEADER);
        ExeHeader.min_ext_par := $2000 - (NumStaticStrChars shr 4);
        ExeHeader.max_ext_par := ExeHeader.min_ext_par;
end;




procedure GenerateStackFrameProlog(TotalLocalVarsSize: Integer);
begin
{ // push ebp
  // mov ebp, esp
  // sub esp, TotalLocalVarsSize }
        GenStr(#$66+#$55+#$66+#$8B+#$EC+#$66+#$81+#$EC);
        GenDWord(TotalLocalVarsSize);
end;

procedure GenerateStackFrameEpilog;
begin
{ // mov esp, ebp
  // pop ebp }
        GenStr(#$66+#$8B+#$E5+#$66+#$5D);
end;




procedure GenerateForwardReference;
begin
GenStr(#$90+#$90+#$90); // 3*nop   ; jump to the procedure entry point will be inserted here
end;




procedure GenerateForwardResolution(PIdent: PIdentifier);
var
  CodePos: Integer;
begin
CodePos := PIdent^.Value;
GenAt(CodePos, $E9); GenWordAt(CodePos + 1, CodeSize - (CodePos + 3));      // jmp Ident[IdentIndex].Value
end;

end.

