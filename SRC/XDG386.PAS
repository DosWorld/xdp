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
{ ----- CODE GENERATOR ----- }
UNIT xdg386;

INTERFACE

USES xdtypes;

const isGen386 : boolean = true;

procedure PushConstInt(Value: Integer);
procedure PushConstLong(Value: LongInt);
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

USES xdglob, xdutils, xdgutils;

CONST
REG_AX = 0;
REG_CX = 1;
REG_DX = 2;
REG_BX = 3;
REG_SP = 4;
REG_BP = 5;
REG_SI = 6;
REG_DI = 7;

REG_ES = 0;
REG_CS = 1;
REG_SS = 2;
REG_DS = 3;

OP_NOP   = $90;
OP_CLD   = $FC;
OP_CBW   = $98;
OP_JMP   = $E9;
OP_CALL  = $E8;
OP_FINIT = #$DB+#$E3;

procedure GenNopNopNop;
begin
        GenStr(chr(OP_NOP)+chr(OP_NOP)+chr(OP_NOP));
end;

procedure GenJmp(op : BYTE; target : INTEGER);
begin
        Gen(op);
        GenWord(target - (CodeSize + 2));
end;

procedure GenPop(reg : BYTE);
begin
        Gen($58 + reg);
end;

procedure GenPush(reg : BYTE);
begin
        Gen($50 + reg);
end;

procedure GenPushSeg(reg : BYTE);
begin
{ 06 push    es 00000110
  0E push    cs 00001110
  16 push    ss 00010110
  1E push    ds 00011110 }
        Gen($06 + (reg SHL 3));
end;

procedure GenPopSeg(reg : BYTE);
begin
{ 07 pop     es 00000111
  17 pop     ss 00010111
  1F pop     ds 00011111 }
        Gen($07 + (reg SHL 3));
end;

procedure GenOperand(r1, r2 : BYTE);
begin
        Gen($C0 OR (r2 SHL 3) OR r1);
end;

procedure GenXorReg16Reg16(r1, r2 : BYTE);
begin
{ 33C0   xor ax,ax 11000000
  33C9   xor cx,cx 11001001
  33D2   xor dx,dx 11010010
  33DB   xor bx,bx 11011011
  33E4   xor sp,sp 11100100
  33ED   xor bp,bp 11101101
  33F6   xor si,si 11110110
  33FF   xor di,di 11111111
}
        Gen($33);
        GenOperand(r1, r2);
end;

procedure GenAddReg16Reg16(r1, r2 : BYTE);
begin
{ 03C0 add  ax,ax 11000000
  03D2 add  dx,dx 11010010
  03CA add  cx,dx 11001010
  03D1 add  dx,cx 11010001 }
        Gen($03);
        GenOperand(r2, r1);
end;

procedure GenMovReg16Val16(reg : BYTE; canxor : boolean; val : INTEGER);
begin
        IF canxor and (val = 0) THEN GenXorReg16Reg16(reg, reg)
        ELSE BEGIN
                Gen($B8 + reg);
                GenWord(val);
        END;
end;

procedure GenMovReg16Reg16(r1, r2 : BYTE);
begin
{ 89C0 mov     ax,ax
  89D1 mov     cx,dx }
        IF r1 <> r2 THEN BEGIN
                Gen($89);
                GenOperand(r1, r2);
        END;
end;

procedure GenAddReg16Val16(reg : BYTE; val : INTEGER);
begin
        IF val = 0 THEN EXIT
        ELSE IF val = 1 THEN Gen($40 + reg)
        ELSE IF reg = REG_AX THEN BEGIN
                Gen($05);
                GenWord(val);
        END ELSE BEGIN
                Gen($81);
                GenOperand(reg, 0);
                GenWord(val);
        END;
end;

procedure GenSubReg16Val16(reg : BYTE; val : INTEGER);
begin
        IF val = 0 THEN EXIT
        ELSE IF val = 1 THEN Gen($48 + reg)
        ELSE IF reg = REG_AX THEN BEGIN
                Gen($2D);
                GenWord(val);
        END ELSE BEGIN
                Gen($81);
                Gen($E8 + reg);
                GenWord(val);
        END;
end;

procedure GenMovReg16Param16(reg : BYTE; val : INTEGER);
begin
{
8B863012   mov     ax,[bp+1230h]
8B8E3112   mov     cx,[bp+1231h]
8B963212   mov     dx,[bp+1232h]
8B9E3312   mov     bx,[bp+1233h]
8BA63412   mov     sp,[bp+1234h]
8BAE3512   mov     bp,[bp+1235h]
8BB63612   mov     si,[bp+1236h]
8BBE3712   mov     di,[bp+1237h]
}

                Gen($8B);
                Gen($86 OR (reg SHL 3));
                GenWord(val);
end;

procedure PushConstInt(Value: Integer);
begin
        IF isGen386 THEN BEGIN
                Gen($68); GenWord(Value); { PUSH, ??? }
        END ELSE BEGIN
                GenMovReg16Val16(REG_AX, TRUE, Value);
                GenPush(REG_AX);
        END;
end;

procedure PushConstLong(Value: LongInt);
var     v1, v2 : integer;
begin
        IF isGen386 THEN BEGIN
                Gen($66); Gen($68); GenDWord(Value);  { push Value }
        END ELSE BEGIN
                v1 := (Value SHR 6) AND $FFFF;
                v2 := Value AND $FFFF;
                IF v1 <> v2 THEN BEGIN
                        GenMovReg16Val16(REG_AX, TRUE, v1);
                        GenPush(REG_AX);
                        GenMovReg16Val16(REG_AX, TRUE, v2);
                        GenPush(REG_AX);
                END ELSE BEGIN
                        GenMovReg16Val16(REG_AX, TRUE, v1);
                        GenPush(REG_AX);
                        GenPush(REG_AX);
                END;
        END;
end;

procedure PushConst(Value: LongInt);
begin
        PushConstLong(Value);
end;

procedure PushVarPtr(Addr: Integer; Scope: Byte; DeltaNesting: Byte);
const
StaticLinkAddr = 2 * SizeOf(LongInt);
var     i: Integer;  
begin
        case Scope of
        GLOBAL: begin
                { Global variable }
                GenPushSeg(REG_DS);
                PushConstInt(Addr);
        end;
        LOCAL: begin
                GenPushSeg(REG_SS);
                if DeltaNesting = 0 then begin
                        { Strictly local variable }
                        Gen($8D); Gen($86); GenWord(Addr); { lea ax, [bp + Addr] }
                end else begin
                        { Intermediate level variable }
                        Gen($8B); Gen($76); Gen(StaticLinkAddr);  { mov si, [bp + StaticLinkAddr] }
                        for i := 1 to DeltaNesting - 1 do begin
                                Gen($36); Gen($8B); Gen($74); Gen(StaticLinkAddr);
                                { mov si, ss:[si + StaticLinkAddr] }
                        end;
                        Gen($8D); Gen($84); GenWord(Addr); { lea ax, [si + Addr] }
                end;
                GenPush(REG_AX);
        end;
        end;
end;

procedure DerefPtr(DataType: Byte);
begin
        GenPop(REG_SI);
        GenPopSeg(REG_ES);
        case TypeSize(DataType) of
        1: GenStr(#$26+#$8A+#$04+       { mov al, es:[si] }
                #$98+                   { cbw }
                #$66+#$98);             { cwde }
        2: GenStr(#$26+#$8B+#$04+       { mov ax, es:[si] }
                #$66+#$98);             { cwde }
        4: GenStr(#$66+#$26+#$8B+#$04); { mov eax, es:[si] }
        else Error('Internal fault: Illegal designator size');
        end;
        GenStr(#$66+#$50); { push eax }
end;

function log2(x: LongWord): ShortInt;
var     i : Integer;
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

procedure GetArrayElementPtr(ArrType: Byte);
var     BaseTypeSize, IndexLowBound: Integer;
        Log2BaseTypeSize: ShortInt;
begin
        Gen($66); Gen($58);  { pop eax  ; Array index }
        IndexLowBound := LowBound(Types[ArrType].IndexType);
        GenSubReg16Val16(REG_AX, IndexLowBound);

        BaseTypeSize := TypeSize(Types[ArrType].BaseType);
        Log2BaseTypeSize := Log2(BaseTypeSize);

        if Log2BaseTypeSize > 0 then begin
                Gen($C1); Gen($E0); Gen(Log2BaseTypeSize);
                { shl ax, Log2BaseTypeSize }
        end else if Log2BaseTypeSize < 0 then begin
                GenMovReg16Val16(REG_CX, TRUE, BaseTypeSize);
                Gen($F7); Gen($E1);  { mul cx }
        end;

        GenPop(REG_BX);
        GenAddReg16Reg16(REG_BX, REG_AX);
        GenPush(REG_BX);
end;


procedure GetFieldPtr(RecType: Byte; FieldIndex: Integer);
var     Offset: Integer;
begin
        Offset := Types[RecType].Field[FieldIndex]^.Offset;
        GenPop(REG_AX);
        GenAddReg16Val16(REG_AX, Offset);
        GenPush(REG_AX);
end;

procedure SaveStackTop;
begin
        GenStr(#$66+#$5A); { pop edx }
end;

procedure RestoreStackTop;
begin
        GenStr(#$66+#$52); { push edx }
end;

procedure SaveFileHandle;
begin
        GenStr(#$66+#$5F+  { pop edi }
        #$66+#$58+         { pop eax  ; pop and discard unnecessary stream handle, i.e. 0 }
        #$66+#$58);        { pop eax  ; pop and discard unnecessary console handle, i.e. 0 }
end;

procedure RestoreFileHandle;
begin
        GenStr(#$66+#$57); { push edi }
end;

procedure GenerateIncDec(proc, Size: Byte);
begin
        GenPop(REG_SI);
        GenPopSeg(REG_ES);

        case Size of
        1: begin
        Gen($26); Gen($FE);  { ... byte ptr es: ... }
        end;
        2: begin
        Gen($26); Gen($FF);  { ... word ptr es: ... }
        end;
        4: begin
        Gen($66); Gen($26); Gen($FF); { ... dword ptr es: ... }
        end;
        end;

        case proc of
        INCPROC: Gen($04); { inc ... [si] }
        DECPROC: Gen($0C); { dec ... [si] }
        end;
end;

procedure GenerateInpOutp(proc: Byte);
begin
        case proc of
        INPPROC: begin
                GenPop(REG_SI);
                GenPopSeg(REG_ES);
                Gen($66); Gen($5A);             { pop edx }
                Gen($EC);                       { in al, dx }
                Gen($26); Gen($88); Gen($04);   { mov es:[si], al }
        end;
        OUTPPROC: begin
                Gen($66); Gen($5B); { pop ebx }
                Gen($66); Gen($5A); { pop edx }
                Gen($8A); Gen($C3); { mov al, bl }
                Gen($EE);           { out dx, al }
        end;
        end;
end;

procedure GenerateNewDispose(proc: Byte; Size: Integer);
begin
        GenPop(REG_SI);
        GenPopSeg(REG_ES);
        case proc of
        NEWPROC: begin
                Gen($B4); Gen($48);                        { mov ah, 48h }
                GenMovReg16Val16(REG_BX, TRUE, (Size - 1) div 16 + 1);  { paragraphs to allocate }
                Gen($CD); Gen($21);                        { int 21h }
                Gen($66); Gen($C1); Gen($E0); Gen(16);     { shl eax, 16 ; get total address from segment address }
                Gen($66); Gen($26); Gen($89); Gen($04);    { mov es:[si], eax }
        end;
        DISPOSEPROC: begin
                Gen($B4); Gen($49);            { mov ah, 49h }
                Gen($26); Gen($C4); Gen($34);  { les si, es:[si] }
                Gen($CD); Gen($21);            { int 21h }
        end;
        end;
end;

procedure GenerateHalt(err: Byte);
begin
        GenMovReg16Val16(REG_AX, TRUE, $4C00 OR err);
        Gen($CD); Gen($21); { int 21h }
end;

procedure GenerateInterrupt(IntNumber: Byte);
begin
        GenPop(REG_SI);
        GenPopSeg(REG_ES);
        GenPushSeg(REG_DS);
        GenPush(REG_BP);
        GenMovReg16Reg16(REG_BP, REG_SI);
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
        GenPop(REG_BP);
        GenPopSeg(REG_DS);
end;

procedure GenerateRound(TruncMode: Boolean);
begin
        GenMovReg16Reg16(REG_BX, REG_SP);
        Gen($36); Gen($D9); Gen($07);       // fld ss:[bx]   ;  st := operand
        if TruncMode then begin
                GenStr(#$36+#$C7+#$87); GenWord(-4); GenWord($0F7F); // mov ss:[bx - 4], 0F7Fh
                GenStr(#$36+#$D9+#$AF); GenWord(-4);                 // fldcw ss:[bx - 4]
        end;
        Gen($36); Gen($DB); Gen($1F); // fistp ss:[bx] ;  ss:[bx] := round(result);  pop
        if TruncMode then begin
                Gen($36); Gen($C7); Gen($87); GenWord(-4); GenWord($037F); // mov ss:[bx - 4], 037Fh
                Gen($36); Gen($D9); Gen($AF); GenWord(-4);                 // fldcw ss:[bx - 4]
        end;
end;

procedure GenerateFloat(Depth: Byte);
begin
        GenMovReg16Reg16(REG_BX, REG_SP);
        GenAddReg16Val16(REG_BX, Depth);
        Gen($36); Gen($DB); Gen($07);  { fild ss:[bx]  ;  st := float(operand) }
        Gen($36); Gen($D9); Gen($1F);  { fstp ss:[bx]  ;  ss:[bx] := result;  pop }
end;

procedure GenerateMathFunction(func, ResultType: Byte);
begin
        if Types[ResultType].TypeKind = REALTYPE then begin
                GenMovReg16Reg16(REG_BX, REG_SP);
                Gen($36); Gen($D9); Gen($07);  { fld ss:[bx]  ;  st := x }
                case func of
                ABSFUNC: GenStr(#$D9+#$E1);  { fabs }
                SQRFUNC: GenStr(#$DC+#$C8);  { fmul st, st }
                SINFUNC: GenStr(#$D9+#$FE);  { fsin }
                COSFUNC: GenStr(#$D9+#$FF);  { fcos }
                ARCTANFUNC: begin
                        GenStr(#$D9+#$E8);         { fld1 }
                        GenStr(#$D9+#$F3);         { fpatan    ; st := arctan(x / 1.0) }
                end;
                EXPFUNC: begin
                        Gen($D9); Gen($EA);    // fldl2e
                        Gen($DE); Gen($C9);    // fmul
                        Gen($D9); Gen($C0);    // fld st
                        Gen($D9); Gen($FC);    // frndint
                        Gen($DD); Gen($D2);    // fst st(2) ; st(2) := round(x * log2(e))
                        Gen($DE); Gen($E9);    // fsub
                        Gen($D9); Gen($F0);    // f2xm1     ; st := 2 ^ frac(x * log2(e)) - 1
                        Gen($D9); Gen($E8);    // fld1
                        Gen($DE); Gen($C1);    // fadd
                        Gen($D9); Gen($FD);    // fscale    ; st := 2 ^ frac(x * log2(e)) * 2 ^ round(x * log2(e)) = exp(x)
                end;
                LNFUNC: begin
                        Gen($D9); Gen($ED);  // fldln2
                        Gen($D9); Gen($C9);  // fxch
                        Gen($D9); Gen($F1);  // fyl2x     ; st := ln(2) * log2(x) = ln(x)
                end;
                SQRTFUNC: GenStr(#$D9+#$FA);  // fsqrt
                end;
                Gen($36); Gen($D9); Gen($1F); // fstp ss:[bx] ;  ss:[bx] := result;  pop
        end else case func of
                ABSFUNC: begin
                        Gen($66); Gen($58);                      // pop eax
                        Gen($66); Gen($83); Gen($F8); Gen($00);  // cmp eax, 0
                        Gen($7D); Gen($03);                      // jge +3
                        Gen($66); Gen($F7); Gen($D8);            // neg eax
                        Gen($66); Gen($50);                      // push eax
                end;
                SQRFUNC: begin
                        Gen($66); Gen($58);            // pop eax
                        Gen($66); Gen($F7); Gen($E8);  // imul eax
                        Gen($66); Gen($50);            // push eax
                end;
                end;
end;

procedure GenerateUnaryOperator(op: Byte; ResultType: Byte);
begin
        if Types[ResultType].TypeKind = REALTYPE then begin
                if op = MINUSTOK then begin
                        GenMovReg16Reg16(REG_BX, REG_SP);
                        Gen($36); Gen($D9); Gen($07);  { fld ss:[bx]  ;  st := operand }
                        Gen($D9); Gen($E0);            { fchs }
                        Gen($36); Gen($D9); Gen($1F);  { fstp ss:[bx] ;  ss:[bx] := result;  pop }
                end;
        end else begin
                Gen($66); Gen($58); { pop eax }
                case op of
                MINUSTOK: GenStr(#$66+#$F7+#$D8); { neg eax }
                NOTTOK: GenStr(#$66+#$F7+#$D0); { not eax }
                end;
                Gen($66); Gen($50); { push eax }
        end;
end;

procedure GenerateBinaryOperator(op: Byte; ResultType: Byte);
begin
        if Types[ResultType].TypeKind = REALTYPE then begin
                GenMovReg16Reg16(REG_BX, REG_SP);
                Gen($36); Gen($D9); Gen($07);  { fld ss:[bx]  ;  st := operand2 }
                Gen($66); Gen($58);            { pop eax }
                Gen($8B); Gen($DC);            { mov bx, sp }
                Gen($36); Gen($D9); Gen($07);  { fld ss:[bx]  ;  st(1) := operand2;  st := operand1 }
                Gen($D9); Gen($C9);            { fxch         ;  st := operand2;  st(1) := operand1 }

                case op of
                PLUSTOK: GenStr(#$DE+#$C1);    { fadd  ;  st(1) := st(1) + st;  pop }
                MINUSTOK: GenStr(#$DE+#$E9);   { fsub  ;  st(1) := st(1) - st;  pop }
                MULTOK: GenStr(#$DE+#$C9);     { fmul  ;  st(1) := st(1) * st;  pop }
                DIVTOK: GenStr(#$DE+#$F9);     { fdiv  ;  st(1) := st(1) / st;  pop }
                end;

                GenStr(#$36+#$D9+#$1F);        { fstp ss:[bx]  ;  ss:[bx] := result;  pop }

        end else begin
                Gen($66); Gen($59); { pop ecx }
                Gen($66); Gen($58); { pop eax }

                case op of
                PLUSTOK: GenStr(#$66+#$03+#$C1);    // add eax, ecx
                MINUSTOK: GenStr(#$66+#$2B+#$C1);   // sub eax, ecx
                MULTOK: GenStr(#$66+#$F7+#$E9);     // imul ecx
                IDIVTOK, MODTOK: begin
                        Gen($66); Gen($99);             // cdq
                        GenStr(#$66+#$F7+#$F9);         // idiv ecx
                        if op = MODTOK then GenStr(#$66+#$8B+#$C2);   // mov eax, edx  ; save remainder
                end;
                SHLTOK: GenStr(#$66+#$D3+#$E0);     // shl eax, cl
                SHRTOK: GenStr(#$66+#$D3+#$E8);     // shr eax, cl
                ANDTOK: GenStr(#$66+#$23+#$C1);     // and eax, ecx
                ORTOK:  GenStr(#$66+#$0B+#$C1);     // or eax, ecx
                XORTOK: GenStr(#$66+#$33+#$C1);     // xor eax, ecx
                end;

                Gen($66); Gen($50);  { push eax }
        end;
end;

procedure GenerateRelation(rel: Byte; ValType: Byte);
begin
        if Types[ValType].TypeKind = REALTYPE then begin
                GenMovReg16Reg16(REG_BX, REG_SP);
                Gen($36); Gen($D9); Gen($07);      // fld ss:[bx]    ;  st := operand2
                Gen($66); Gen($58);                // pop eax
                GenMovReg16Reg16(REG_BX, REG_SP);
                Gen($36); Gen($D9); Gen($07);      // fld ss:[bx]    ;  st(1) := operand2;  st := operand1
                Gen($66); Gen($58);                // pop eax
                GenMovReg16Reg16(REG_BX, REG_SP);
                Gen($DE); Gen($D9);                // fcompp         ;  test st - st(1)
                Gen($DF); Gen($E0);                // fstsw ax
                Gen($66); Gen($68); GenDWord(-1);  // push FFFFFFFFh ;  TRUE
                Gen($9E);                          // sahf
                case rel of
                EQTOK: Gen($74);  // je  ...
                NETOK: Gen($75);  // jne ...
                GTTOK: Gen($77);  // ja  ...
                GETOK: Gen($73);  // jae ...
                LTTOK: Gen($72);  // jb  ...
                LETOK: Gen($76);  // jbe ...
                end;
        end else begin
                Gen($66); Gen($59);   // pop ecx
                Gen($66); Gen($58);   // pop eax
                PushConstLong(-1);
                Gen($66); Gen($3B); Gen($C1);  { cmp eax, ecx }
                case rel of
                EQTOK: Gen($74);  // je  ...
                NETOK: Gen($75);  // jne ...
                GTTOK: Gen($7F);  // jg  ...
                GETOK: Gen($7D);  // jge ...
                LTTOK: Gen($7C);  // jl  ...
                LETOK: Gen($7E);  // jle ...
                end;
        end;
        Gen($08);             // ... +8
        Gen($66); Gen($59);   // pop ecx
        PushConstLong(0);
end;

procedure GenerateAssignment(DesignatorType: Byte);
begin
        { EDX should be preserved }
        GenStr(#$66+#$58); { pop eax }
        GenPop(REG_SI);
        GenPopSeg(REG_ES);
        case TypeSize(DesignatorType) of
        1: GenStr(#$26+#$88+#$04); { mov es:[si], al }
        2: GenStr(#$26+#$89+#$04); { mov es:[si], ax }
        4: GenStr(#$66+#$26+#$89+#$04); { mov es:[si], eax }
        else Error('Internal fault: Illegal designator size');
        end;
end;

procedure GenerateStructuredAssignment(DesignatorType: Byte);
begin
        Gen($8C); Gen($D8);   { mov ax, ds }
        GenMovReg16Reg16(REG_BX, REG_DI);
        { Source address }
        GenPop(REG_SI);
        GenPopSeg(REG_DS);
        { Destination address }
        GenPop(REG_DI);
        GenPopSeg(REG_ES);
        { Copy source to destination }
        GenMovReg16Val16(REG_CX, TRUE, TypeSize(DesignatorType));
        Gen(OP_CLD);
        Gen($F3); Gen($A4); { rep movsb }
        Gen($8E); Gen($D8); { mov ds, ax }
        GenMovReg16Reg16(REG_DI, REG_BX);
end;

procedure GenerateCall(EntryPoint: LongInt; DeltaNesting: Byte);
const
StaticLinkAddr = 2 * SizeOf(LongInt);
var     i : Integer;
begin
        { Push routine static link as the last hidden parameter
          (needed for nested routines) }
        if DeltaNesting = 0 then begin
                { The caller and the callee's enclosing routine
                  are at the same nesting level }
                Gen($66); Gen($55);   { push ebp }
        end else begin
                { The caller is deeper }
                Gen($8B); Gen($76); Gen(StaticLinkAddr); { mov si, [bp + StaticLinkAddr] }
                for i := 1 to DeltaNesting - 1 do begin
                        Gen($36); Gen($8B); Gen($74); Gen(StaticLinkAddr);
                        { mov si, ss:[si + StaticLinkAddr] }
                end;
                Gen($66); Gen($56);                      { push esi }
        end;

        { Call the routine }
        GenPush(REG_AX);
        GenJmp(OP_CALL, EntryPoint);
        GenPop(REG_AX);
end;

procedure GenerateReturn(TotalParamsSize: Integer);
begin
        Gen($C2); GenWord(TotalParamsSize + SizeOf(LongInt));
        { ret TotalParamsSize + 4   ; + 4 is for static link }
end;

procedure GenerateIfCondition;
begin
        Gen($66); Gen($58);                          // pop eax
        Gen($66); Gen($83); Gen($F8); Gen($00);      // cmp eax, 0
        Gen($75); Gen($03);                          // jne +3
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
        { pop ecx }
        Gen($66); Gen($59);
        { push ecx  ; The final value of the counter will be removed from stack by GenerateForEpilog }  
        Gen($66); Gen($51);
        case Scope of
        GLOBAL: case CounterSize of
                1: Gen($A0);                  // mov al, [...]
                2: Gen($A1);                  // mov ax, [...]
                4: GenStr(#$66+#$A1);         // mov eax, [...]
                end;
        LOCAL: case CounterSize of
                1: GenStr(#$8A+#$86);        { mov al, [bp + ...] }
                2: GenStr(#$8B+#$86);        { mov ax, [bp + ...] }
                4: GenStr(#$66+#$8B+#$86);   { mov eax, [bp + ...] }
        end;
        end;
    
        GenWord(CounterAddress);   { ... CounterAddress ... }

        if CounterSize < 2 then Gen(OP_CBW);
        if CounterSize < 4 then GenStr(#$66+#$98);  { cwde }

        GenStr(#$66+#$3B+#$C1);          { cmp eax, ecx }
        if Down then GenStr(#$7D+#$03)   { jge +3 }
        else GenStr(#$7E+#$03);          { jle +3 }
end;

procedure GenerateIfProlog;
begin
        Inc(CodePosStackTop);
        CodePosStack[CodePosStackTop] := CodeSize;
        GenNopNopNop;
end;

procedure GenerateElseProlog;
var     CodePos: LongInt;
begin
        CodePos := CodePosStack[CodePosStackTop];
        Dec(CodePosStackTop);
        GenAt(CodePos, OP_JMP); GenWordAt(CodePos + 1, CodeSize - (CodePos + 3) + 3);  { jmp (IF..THEN block end) }
        GenerateIfProlog;
end;

procedure GenerateIfElseEpilog;
var     CodePos: LongInt;
begin
        CodePos := CodePosStack[CodePosStackTop];
        Dec(CodePosStackTop);
        GenAt(CodePos, OP_JMP);
        GenWordAt(CodePos + 1, CodeSize - (CodePos + 3)); { jmp (IF..THEN block end) }
end;

procedure GenerateCaseProlog;
begin
        Gen($66); Gen($59);  { pop ecx           ; CASE switch value }
        Gen($B0); Gen($00);  { mov al, 00h       ; initial flag mask }
end;

procedure GenerateCaseEpilog(NumCaseStatements: Integer);
var     i: Integer;
begin
        for i := 1 to NumCaseStatements do GenerateIfElseEpilog;
end;

procedure GenerateCaseEqualityCheck(Value: LongInt);
begin
        Gen($66); Gen($81); Gen($F9); GenDWord(Value); { cmp ecx, Value }
        Gen($9F);                                      { lahf }
        Gen($0A); Gen($C4);                            { or al, ah }
end;

procedure GenerateCaseRangeCheck(Value1, Value2: LongInt);
begin
        Gen($66); Gen($81); Gen($F9); GenDWord(Value1);  { cmp ecx, Value1 }
        Gen($7C); Gen($0B);                              { jl +11 }
        Gen($66); Gen($81); Gen($F9); GenDWord(Value2);  { cmp ecx, Value2 }
        Gen($7F); Gen($02);                              { jg +2 }
        Gen($0C); Gen($40);                              { or al, 40h     ; set zero flag on success }
end;

procedure GenerateCaseStatementProlog;
begin
        Gen($24); Gen($40);    { and al, 40h    ; test zero flag }
        Gen($75); Gen($03);    { jnz +3         ; if set, jump to the case statement }
        GenerateIfProlog;
end;

procedure GenerateCaseStatementEpilog;
var     StoredCodeSize: LongInt;
begin
        StoredCodeSize := CodeSize;
        GenNopNopNop;
        GenerateIfElseEpilog;
        Inc(CodePosStackTop);
        CodePosStack[CodePosStackTop] := StoredCodeSize;
end;

procedure GenerateWhileEpilog;
var     CodePos : Integer;
begin
        CodePos := CodePosStack[CodePosStackTop];
        Dec(CodePosStackTop);
        GenAt(CodePos, OP_JMP); GenWordAt(CodePos + 1, CodeSize - (CodePos + 3) + 3);  { jmp (WHILE..DO block end) }
        GenJmp(OP_JMP, CodePosStack[CodePosStackTop]);
        Dec(CodePosStackTop);
end;

procedure GenerateRepeatProlog;
begin
        Inc(CodePosStackTop);
        CodePosStack[CodePosStackTop] := CodeSize;
end;

procedure GenerateRepeatEpilog;
begin
        GenJmp(OP_JMP, CodePosStack[CodePosStackTop]);
        Dec(CodePosStackTop);
end;

procedure GenerateForEpilog(CounterAddress: Integer; Scope, CounterSize: Byte; Down: Boolean);
begin
        PushVarPtr(CounterAddress, Scope, 0);
        if Down then GenerateIncDec(DECPROC, CounterSize)
        else GenerateIncDec(INCPROC, CounterSize);
        GenerateWhileEpilog;
        { pop ecx    ; Remove the final value of the counter from the stack }
        Gen($66); Gen($59);
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
        GenMovReg16Val16(REG_AX, FALSE, 0);
        GenPush(REG_AX);
        GenPush(REG_AX);
        GenPopSeg(REG_DS);
        GenPopSeg(REG_ES);
        GenStr(OP_FINIT);
        Gen(OP_CLD);
end;

procedure GenerateProgramEpilog;
var     CodeSegmentSize: WORD;
begin
        GenerateHalt(0);

        ExeRelocs[WriteExeRelocsCount].seg := 0;
        ExeRelocs[WriteExeRelocsCount].ofs := 1;
        Inc(WriteExeRelocsCount);

        WHILE (CodeSize AND $0F) <> 0 DO Gen(OP_NOP);
        WHILE (NumStaticStrChars AND $0F) <> 0 DO BEGIN
                StaticStringData[NumStaticStrChars] := #0;
                Inc(NumStaticStrChars);
        END;

        CodeSegmentSize := CodeSize shr 4;
        GenAt(1, CodeSegmentSize and $ff);
        GenAt(2, (CodeSegmentSize shr 8) and $ff);
end;

procedure GenerateStackFrameProlog(TotalLocalVarsSize: Integer);
begin
{ push ebp
  mov ebp, esp
  sub esp, TotalLocalVarsSize }
        GenStr(#$66+#$55+#$66+#$8B+#$EC+#$66+#$81+#$EC);
        GenDWord(TotalLocalVarsSize);
end;

procedure GenerateStackFrameEpilog;
begin
{ mov esp, ebp
  pop ebp }
        GenStr(#$66+#$8B+#$E5+#$66+#$5D);
end;




procedure GenerateForwardReference;
begin
        GenNopNopNop;
end;

procedure GenerateForwardResolution(PIdent: PIdentifier);
var 
        CodePos: Integer;
begin
        { jmp Ident[IdentIndex].Value }
        CodePos := PIdent^.Value;
        GenAt(CodePos, OP_JMP);
        GenWordAt(CodePos + 1, CodeSize - (CodePos + 3));
end;

end.

