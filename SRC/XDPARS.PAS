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
{ ----- PARSER ----- }
UNIT xdpars;

INTERFACE

procedure CompileProgram;

IMPLEMENTATION

USES xdtypes, xdglob, xdutils, xdgen, xdscan;

procedure CompileConstExpression(var ConstVal: TConst; var ConstValType: Byte); forward;
procedure CompileDesignator(var ValType: Byte); forward;
procedure CompileExpression(var ValType: Byte); forward;
procedure CompileStatement; forward;
procedure CompileType(var DataType: Byte); forward;

procedure CompileConstFactor(var ConstVal: TConst; var ConstValType: Byte);
var     PIdent : PIdentifier;
begin
        case Tok.Kind of
        IDENTTOK: begin
                PIdent := FindIdent(Tok.Name);
                if PIdent^.Kind <> CONSTANT then
                        Error('Constant expected but ' + PIdent^.Name + ' found')
                else begin
                        ConstValType := PIdent^.DataType;
                        if Types[ConstValType].TypeKind = REALTYPE then
                                ConstVal.FracValue := PIdent^.FracValue
                        else ConstVal.Value := PIdent^.Value;
                        NextTok;
                        end;
        end;
        INTNUMBERTOK: begin
                ConstVal.Value := Tok.Value;
                ConstValType := INTEGERTYPEINDEX;
                NextTok;
        end;
        FRACNUMBERTOK: begin
                ConstVal.FracValue := Tok.FracValue;
                ConstValType := REALTYPEINDEX;
                NextTok;
        end;
        CHARLITERALTOK: begin
                ConstVal.Value := Tok.Value;
                ConstValType := CHARTYPEINDEX;
                NextTok;
        end;
        OPARTOK: begin
                NextTok;
                CompileConstExpression(ConstVal, ConstValType);
                EatTok(CPARTOK);
        end;
        NOTTOK: begin
                CompileConstFactor(ConstVal, ConstValType);
                ConstVal.Value := not ConstVal.Value;
        end; 
        else Error('Expression expected but ' + GetSpelling(Tok) + ' found');
        end;
end;




procedure CompileConstTerm(var ConstVal: TConst; var ConstValType: Byte);
var     OpTok             : TToken;
        RightConstVal     : TConst;
        RightConstValType : Byte;
begin
        CompileConstFactor(ConstVal, ConstValType);
        while Tok.Kind in [MULTOK, DIVTOK, IDIVTOK, MODTOK, SHLTOK, SHRTOK, ANDTOK] do begin
                OpTok := Tok;
                NextTok;
                CompileConstFactor(RightConstVal, RightConstValType);

                if ConversionIsPossible(ConstValType, RightConstValType) then begin
                        ConstVal.FracValue := ConstVal.Value;
                        ConstValType := REALTYPEINDEX;
                end;
                if ConversionIsPossible(RightConstValType, ConstValType) then begin
                        RightConstVal.FracValue := RightConstVal.Value;
                        RightConstValType := REALTYPEINDEX;
                end;

                { Special case: real division of two integers }
                if (OpTok.Kind = DIVTOK) and ConversionIsPossible(ConstValType, REALTYPEINDEX) and ConversionIsPossible(RightConstValType, REALTYPEINDEX) then begin
                        ConstVal.FracValue := ConstVal.Value;
                        RightConstVal.FracValue := RightConstVal.Value;
                        ConstValType := REALTYPEINDEX;
                        RightConstValType := REALTYPEINDEX;
                end;

                ConstValType := GetCompatibleType(ConstValType, RightConstValType);
                CheckOperator(OpTok.Kind, ConstValType);

  if Types[ConstValType].TypeKind = REALTYPE then
    case OpTok.Kind of
      MULTOK:  ConstVal.FracValue := ConstVal.FracValue * RightConstVal.FracValue;
      DIVTOK:  if RightConstVal.FracValue <> 0 then
                 ConstVal.FracValue := ConstVal.FracValue / RightConstVal.FracValue
               else Error('Constant division by zero');
  end else
    case OpTok.Kind of             
      MULTOK:  ConstVal.Value := ConstVal.Value * RightConstVal.Value;
      IDIVTOK: if RightConstVal.Value <> 0 then
                 ConstVal.Value := ConstVal.Value div RightConstVal.Value
               else  Error('Constant division by zero');  
      MODTOK:  if RightConstVal.Value <> 0 then
                 ConstVal.Value := ConstVal.Value mod RightConstVal.Value
               else Error('Constant division by zero');
      SHLTOK:  ConstVal.Value := ConstVal.Value shl RightConstVal.Value;
      SHRTOK:  ConstVal.Value := ConstVal.Value shr RightConstVal.Value;
      ANDTOK:  ConstVal.Value := ConstVal.Value and RightConstVal.Value;
    end;

        end;
end;



procedure CompileSimpleConstExpression(var ConstVal: TConst; var ConstValType: Byte);
var     UnaryOpTok, OpTok : TToken;
        RightConstVal     : TConst;
        RightConstValType : Byte;
begin
        UnaryOpTok := Tok;
        if UnaryOpTok.Kind in [PLUSTOK, MINUSTOK] then NextTok;

        CompileConstTerm(ConstVal, ConstValType);

        if UnaryOpTok.Kind in [PLUSTOK, MINUSTOK] then CheckOperator(UnaryOpTok.Kind, ConstValType);

        if UnaryOpTok.Kind = MINUSTOK then begin
                if Types[ConstValType].TypeKind = REALTYPE then
                        ConstVal.FracValue := -ConstVal.FracValue
                else
                        ConstVal.Value := -ConstVal.Value;
        end;

        while Tok.Kind in [PLUSTOK, MINUSTOK, ORTOK, XORTOK] do begin
                OpTok := Tok;
                NextTok;
                CompileConstTerm(RightConstVal, RightConstValType);

                if ConversionIsPossible(ConstValType, RightConstValType) then begin
                        ConstVal.FracValue := ConstVal.Value;
                        ConstValType := REALTYPEINDEX;
                end;
                if ConversionIsPossible(RightConstValType, ConstValType) then begin
                        RightConstVal.FracValue := RightConstVal.Value;
                        RightConstValType := REALTYPEINDEX;
                end;  

                ConstValType := GetCompatibleType(ConstValType, RightConstValType);
                CheckOperator(OpTok.Kind, ConstValType);

  if Types[ConstValType].TypeKind = REALTYPE then
    case OpTok.Kind of
      PLUSTOK:  ConstVal.FracValue := ConstVal.FracValue  +  RightConstVal.FracValue;
      MINUSTOK: ConstVal.FracValue := ConstVal.FracValue  -  RightConstVal.FracValue;
    end
  else
    case OpTok.Kind of
      PLUSTOK:  ConstVal.Value := ConstVal.Value  +  RightConstVal.Value;
      MINUSTOK: ConstVal.Value := ConstVal.Value  -  RightConstVal.Value;
      ORTOK:    ConstVal.Value := ConstVal.Value  or RightConstVal.Value;
      XORTOK:   ConstVal.Value := ConstVal.Value xor RightConstVal.Value;
    end;

  end;

end;



procedure CompileConstExpression(var ConstVal: TConst; var ConstValType: Byte);
var     OpTok             : TToken;
        RightConstVal     : TConst;
        RightConstValType : Byte;
        Yes               : Boolean;
begin
        Yes := FALSE;
        CompileSimpleConstExpression(ConstVal, ConstValType);

        if Tok.Kind in [EQTOK, NETOK, LTTOK, LETOK, GTTOK, GETOK] then begin
                OpTok := Tok;
                NextTok;
                CompileSimpleConstExpression(RightConstVal, RightConstValType);

                if ConversionIsPossible(ConstValType, RightConstValType) then begin
                        ConstVal.FracValue := ConstVal.Value;
                        ConstValType := REALTYPEINDEX;
                end;
                if ConversionIsPossible(RightConstValType, ConstValType) then begin
                        RightConstVal.FracValue := RightConstVal.Value;
                        RightConstValType := REALTYPEINDEX;
                end;

                GetCompatibleType(ConstValType, RightConstValType);
                CheckOperator(OpTok.Kind, ConstValType);

                if Types[ConstValType].TypeKind = REALTYPE then
                        case OpTok.Kind of
                        EQTOK: Yes := ConstVal.FracValue =  RightConstVal.FracValue;
                        NETOK: Yes := ConstVal.FracValue <> RightConstVal.FracValue;
                        LTTOK: Yes := ConstVal.FracValue <  RightConstVal.FracValue;
                        LETOK: Yes := ConstVal.FracValue <= RightConstVal.FracValue;
                        GTTOK: Yes := ConstVal.FracValue >  RightConstVal.FracValue;
                        GETOK: Yes := ConstVal.FracValue >= RightConstVal.FracValue;
                end else case OpTok.Kind of
                        EQTOK: Yes := ConstVal.Value =  RightConstVal.Value;
                        NETOK: Yes := ConstVal.Value <> RightConstVal.Value;
                        LTTOK: Yes := ConstVal.Value <  RightConstVal.Value;
                        LETOK: Yes := ConstVal.Value <= RightConstVal.Value;
                        GTTOK: Yes := ConstVal.Value >  RightConstVal.Value;
                        GETOK: Yes := ConstVal.Value >= RightConstVal.Value;
                end;

                if Yes then ConstVal.Value := -1 else ConstVal.Value := 0;
  
                ConstValType := BOOLEANTYPEINDEX;
        end;

end;


procedure CompilePredefinedProc(proc: Byte);
var     DesignatorType, ExpressionType, ActualParamType: Byte;
        InterruptNumber, ErrorCode: TConst;
        LibProcIdent : PIdentifier;
        IsFirstParam, FileSpecified: Boolean;
begin
        NextTok;

        case proc of
        INCPROC, DECPROC: begin
                EatTok(OPARTOK);
                AssertIdent;
                CompileDesignator(DesignatorType);
                GetCompatibleType(DesignatorType, INTEGERTYPEINDEX);
                GenerateIncDec(proc, TypeSize(DesignatorType));
                EatTok(CPARTOK);
        end;
        READPROC, READLNPROC: begin
                FileSpecified := FALSE;
                IsFirstParam := TRUE;

                if Tok.Kind = OPARTOK then begin
                        NextTok;
                        WHILE TRUE DO BEGIN
                                // 1st argument - file handle
                                if FileSpecified then RestoreFileHandle
                                else PushConst(0);
                                // 2nd argument - string stream handle
                                PushConst(0);
                                // 3rd argument - designator
                                CompileDesignator(DesignatorType);
        
                                if Types[DesignatorType].TypeKind = TEXTTYPE then begin
                                        if not IsFirstParam then Error('Incompatible types');
                                        FileSpecified := TRUE;
                                        DerefPtr(DesignatorType);
                                        SaveFileHandle;
                                end else begin
                                        LibProcIdent := nil;

          if (Types[DesignatorType].TypeKind in IntegerTypes) or
            ((Types[DesignatorType].TypeKind = SUBRANGETYPE) and
             (Types[Types[DesignatorType].HostType].TypeKind in IntegerTypes)) then
                LibProcIdent := FindIdent('READINT')
          else if (Types[DesignatorType].TypeKind = CHARTYPE) or
            ((Types[DesignatorType].TypeKind = SUBRANGETYPE) and
             (Types[Types[DesignatorType].HostType].TypeKind = CHARTYPE)) then
                LibProcIdent := FindIdent('READCH')
          else if Types[DesignatorType].TypeKind = REALTYPE then
                LibProcIdent := FindIdent('READREAL')
          else if (Types[DesignatorType].TypeKind = ARRAYTYPE) and (Types[DesignatorType].BaseType = CHARTYPEINDEX) then
                LibProcIdent := FindIdent('READSTRING')
          else Error('Incompatible types');

          { Call the specific output subroutine. Interface: FileHandle; StreamHandle; var Designator }
          if Pass = CALLDETERMPASS then AddCallGraphChild(BlockStack[BlockStackTop], LibProcIdent^.ProcAsBlock);
          GenerateCall(LibProcIdent^.Value, BlockStackTop - LibProcIdent^.NestingLevel);
                                end;
        
                                IsFirstParam := FALSE;
                                if Tok.Kind = COMMATOK then NextTok
                                else BREAK;
                        END;
                        EatTok(CPARTOK);
                end; // if OPARTOR
      
    // Add CR+LF, if necessary
                if proc = READLNPROC then begin
                        LibProcIdent := FindIdent('READNEWLINE');
                        // 1st argument - file handle
                        if FileSpecified then RestoreFileHandle
                        else PushConst(0);
                        // 2nd argument - string stream handle
                        PushConst(0);

                        if Pass = CALLDETERMPASS then AddCallGraphChild(BlockStack[BlockStackTop], LibProcIdent^.ProcAsBlock);
                        GenerateCall(LibProcIdent^.Value, BlockStackTop - LibProcIdent^.NestingLevel);
                end;
        end;


        WRITEPROC, WRITELNPROC: begin
                FileSpecified := FALSE;
                IsFirstParam := TRUE;

                if Tok.Kind = OPARTOK then begin
                        NextTok;
                        WHILE TRUE DO BEGIN
        // 1st argument - file handle
        if FileSpecified then RestoreFileHandle
        else PushConst(0);

        // 2nd argument - string stream handle
        PushConst(0);

        // 3rd argument - expression
        CompileExpression(ExpressionType);

        if Types[ExpressionType].TypeKind = TEXTTYPE then begin
          if not IsFirstParam then Error('Incompatible types');
          FileSpecified := TRUE;
          SaveFileHandle;
          end
        else begin
          LibProcIdent := nil;
          
          if (Types[ExpressionType].TypeKind in IntegerTypes) or
            ((Types[ExpressionType].TypeKind = SUBRANGETYPE) and
             (Types[Types[ExpressionType].HostType].TypeKind in IntegerTypes)) then
                LibProcIdent := FindIdent('WRITEINT')
          else if (Types[ExpressionType].TypeKind = BOOLEANTYPE) or
            ((Types[ExpressionType].TypeKind = SUBRANGETYPE) and
             (Types[Types[ExpressionType].HostType].TypeKind = BOOLEANTYPE)) then
                LibProcIdent := FindIdent('WRITEBOOLEAN')
          else if (Types[ExpressionType].TypeKind = CHARTYPE) or
            ((Types[ExpressionType].TypeKind = SUBRANGETYPE) and
             (Types[Types[ExpressionType].HostType].TypeKind = CHARTYPE)) then
                LibProcIdent := FindIdent('WRITECH')
          else if Types[ExpressionType].TypeKind = REALTYPE then
                LibProcIdent := FindIdent('WRITEREAL')
          else if Types[ExpressionType].TypeKind = POINTERTYPE then
                LibProcIdent := FindIdent('WRITEPOINTER')
          else if (Types[ExpressionType].TypeKind = ARRAYTYPE) and (Types[ExpressionType].BaseType = CHARTYPEINDEX) then
                LibProcIdent := FindIdent('WRITESTRING')
          else Error('Incompatible types');

          { Call the specific output subroutine. Interface: FileHandle; StreamHandle; Expression }
          if Pass = CALLDETERMPASS then AddCallGraphChild(BlockStack[BlockStackTop], LibProcIdent^.ProcAsBlock);
          GenerateCall(LibProcIdent^.Value, BlockStackTop - LibProcIdent^.NestingLevel);
          end;

        IsFirstParam := FALSE;

        if Tok.Kind = COMMATOK then NextTok else BREAK;
      END;
      EatTok(CPARTOK);
      end; // if OPARTOR
      
    // Add CR+LF, if necessary
    if proc = WRITELNPROC then begin
      LibProcIdent := FindIdent('WRITENEWLINE');
      
      // 1st argument - file handle
      if FileSpecified then RestoreFileHandle
      else PushConst(0);

      // 2nd argument - string stream handle
      PushConst(0);

      if Pass = CALLDETERMPASS then AddCallGraphChild(BlockStack[BlockStackTop], LibProcIdent^.ProcAsBlock);
      GenerateCall(LibProcIdent^.Value, BlockStackTop - LibProcIdent^.NestingLevel);
      end;

    end;
  INPPROC, OUTPPROC: begin
    EatTok(OPARTOK);
    CompileExpression(ExpressionType);
    GetCompatibleType(ExpressionType, INTEGERTYPEINDEX);
    EatTok(COMMATOK);
    if proc = INPPROC then
      CompileDesignator(ExpressionType)
    else
      CompileExpression(ExpressionType);
    GetCompatibleType(ExpressionType, SHORTINTTYPEINDEX);
    GenerateInpOutp(proc);
    EatTok(CPARTOK);
    end;

  NEWPROC, DISPOSEPROC: begin
    EatTok(OPARTOK);
    AssertIdent;
    CompileDesignator(DesignatorType);
    GetCompatibleType(DesignatorType, POINTERTYPEINDEX);
    GenerateNewDispose(proc, TypeSize(Types[DesignatorType].BaseType));
    EatTok(CPARTOK);
    end;

  HALTPROC: begin
    if Tok.Kind = OPARTOK then begin
      NextTok;
      CompileConstExpression(ErrorCode, ExpressionType);
      GetCompatibleType(ExpressionType, INTEGERTYPEINDEX);
      EatTok(CPARTOK);
      end
    else
      ErrorCode.Value := 0;
    GenerateHalt(ErrorCode.Value);
    end;

        INTRPROC: begin
                EatTok(OPARTOK);
                CompileConstExpression(InterruptNumber, ActualParamType);
                GetCompatibleType(ActualParamType, INTEGERTYPEINDEX);
                EatTok(COMMATOK);
                CompileExpression(ActualParamType);
                GetCompatibleType(ActualParamType, POINTERTYPEINDEX);
                GenerateInterrupt(InterruptNumber.Value);
                EatTok(CPARTOK);
        end;
        end;

end;



procedure CompilePredefinedFunc(func: Byte; var ValType: Byte);
var
  PIdent : PIdentifier;
begin
        NextTok;
        EatTok(OPARTOK);

        case func of
        SIZEOFFUNC: begin
                AssertIdent;
                PIdent := FindIdent(Tok.Name);
                if PIdent^.Kind = USERTYPE then begin
                        NextTok;
                        PushConst(TypeSize(PIdent^.DataType));
                end else begin
                        CompileDesignator(ValType);
                        SaveStackTop;                        // Save result to EDX
                        PushConst(TypeSize(ValType));
                end;
                ValType := INTEGERTYPEINDEX;
        end;
        ROUNDFUNC, TRUNCFUNC: begin
                CompileExpression(ValType);

                // Try to convert integer to real
                if ConversionIsPossible(ValType, REALTYPEINDEX) then begin
                        GenerateFloat(0);
                        ValType := REALTYPEINDEX;
                end;

                GetCompatibleType(ValType, REALTYPEINDEX);
                GenerateRound(func = TRUNCFUNC);
                ValType := INTEGERTYPEINDEX;
        end;
        ORDFUNC: begin
                CompileExpression(ValType);
                if not (Types[ValType].TypeKind in OrdinalTypes) then Error('Ordinal type expected');
                ValType := INTEGERTYPEINDEX;
        end;
        CHRFUNC: begin
                CompileExpression(ValType);
                GetCompatibleType(ValType, INTEGERTYPEINDEX);
                ValType := CHARTYPEINDEX;
        end;
        PREDFUNC, SUCCFUNC: begin
                CompileExpression(ValType);
                if not (Types[ValType].TypeKind in OrdinalTypes) then
                        Error('Ordinal type expected');
                if func = SUCCFUNC then PushConst(1)
                else PushConst(-1);
                GenerateBinaryOperator(PLUSTOK, INTEGERTYPEINDEX);
        end;
        ABSFUNC, SQRFUNC, SINFUNC, COSFUNC, ARCTANFUNC, EXPFUNC, LNFUNC, SQRTFUNC: begin
                CompileExpression(ValType);
                if func in [ABSFUNC, SQRFUNC] then begin
                        // Abs and Sqr accept real or integer parameters
                        if not ((Types[ValType].TypeKind in (IntegerTypes + [REALTYPE])) or
                        ((Types[ValType].TypeKind = SUBRANGETYPE) and
                        (Types[Types[ValType].HostType].TypeKind in IntegerTypes))) then
                        Error('Numeric type expected')
                end else begin
                        // Try to convert integer to real
                        if ConversionIsPossible(ValType, REALTYPEINDEX) then begin
                                GenerateFloat(0);
                                ValType := REALTYPEINDEX;
                        end;

                        GetCompatibleType(ValType, REALTYPEINDEX);
                end;

                GenerateMathFunction(func, ValType);
        end;
        end;// case
        EatTok(CPARTOK);
end;





procedure CompileDesignator(var ValType: Byte);
var     FieldIndex: Integer;
        PIdent : PIdentifier;
        ArrayIndexType: Byte;
        IsRefParam: Boolean;
begin
        AssertIdent;

        PIdent := FindIdent(Tok.Name);

        if PIdent^.Kind <> VARIABLE then
                Error('Variable expected but ' + Tok.Name + ' found');

        PushVarPtr(PIdent^.Value, PIdent^.Scope, BlockStackTop - PIdent^.NestingLevel);
        ValType := PIdent^.DataType;


if Types[PIdent^.DataType].TypeKind in [ARRAYTYPE, RECORDTYPE] then
  IsRefParam := PIdent^.PassMethod in [CONSTPASSING, VARPASSING]    // For structured parameters, CONST is equivalent to VAR
else
  IsRefParam := PIdent^.PassMethod = VARPASSING;                    // For scalar parameters, CONST is equivalent to passing by value

if IsRefParam then DerefPtr(POINTERTYPEINDEX);                                // Parameter is passed by reference


NextTok;

while Tok.Kind in [DEREFERENCETOK, OBRACKETTOK, PERIODTOK] do
  if Tok.Kind = DEREFERENCETOK then                           // Pointer dereferencing
    begin
    if (Types[ValType].TypeKind <> POINTERTYPE) or (Types[ValType].BaseType = ANYTYPEINDEX) then
      Error('Typed pointer expected');
    DerefPtr(ValType);
    ValType := Types[ValType].BaseType;
    NextTok;
    end
  else if Tok.Kind = OBRACKETTOK then                         // Array element access
    begin
    repeat
      if Types[ValType].TypeKind <> ARRAYTYPE then
        Error('Array expected');
      NextTok;
      CompileExpression(ArrayIndexType);                        // Array index
      GetCompatibleType(ArrayIndexType, Types[ValType].IndexType);
      GetArrayElementPtr(ValType);
      ValType := Types[ValType].BaseType;
    until Tok.Kind <> COMMATOK;
    EatTok(CBRACKETTOK);
    end
  else if Tok.Kind = PERIODTOK then                           // Record field access
    begin
    if Types[ValType].TypeKind <> RECORDTYPE then
      Error('Record expected');
    NextTok;
    AssertIdent;
    FieldIndex := GetField(ValType, Tok.Name);
    GetFieldPtr(ValType, FieldIndex);
    ValType := Types[ValType].Field[FieldIndex]^.DataType;
    NextTok;   
    end;
end; // CompileDesignator




procedure CompileActualParameters(PIdent : PIdentifier);
var     NumActualParams: Integer;
        ActualParamType: Byte;
        IsRefParam, TreatCharAsString: Boolean;
        CurParam: PParam;
begin
NumActualParams := 0;

if Tok.Kind = OPARTOK then begin
  repeat
    NextTok;

    if NumActualParams + 1 > PIdent^.NumParams then
      Error('Too many actual parameters');

    CurParam := PIdent^.Param[NumActualParams + 1];

    // Evaluate actual parameters and push them onto the stack

    TreatCharAsString := (Tok.Kind = CHARLITERALTOK) and (CurParam^.DataType = STRINGTYPEINDEX);

    if (Tok.Kind = STRINGLITERALTOK) or TreatCharAsString then begin
      if CurParam^.PassMethod <> CONSTPASSING then
        Error('String literals can be passed as CONST only');
      IsRefParam := FALSE;
      end
    else
      if Types[CurParam^.DataType].TypeKind in [ARRAYTYPE, RECORDTYPE] then
        IsRefParam := CurParam^.PassMethod in [CONSTPASSING, VARPASSING]    // For structured parameters, CONST is equivalent to VAR
      else
        IsRefParam := CurParam^.PassMethod = VARPASSING;                    // For scalar parameters, CONST is equivalent to passing by value

    if TreatCharAsString then
      begin                                     // Special case
      PushVarPtr(Tok.StrAddress, GLOBAL, 0);
      ActualParamType := STRINGTYPEINDEX;
      NextTok;
      end
    else
      if IsRefParam then                        // General rule
        CompileDesignator(ActualParamType)
      else
        CompileExpression(ActualParamType);

    Inc(NumActualParams);

    // Try to convert integer to real
    if ConversionIsPossible(ActualParamType, CurParam^.DataType) and not IsRefParam then begin
      GenerateFloat(0);
      ActualParamType := REALTYPEINDEX;
      end;

    GetCompatibleType(CurParam^.DataType, ActualParamType);
  until Tok.Kind <> COMMATOK;

  EatTok(CPARTOK);
  end;// if Tok.Kind = OPARTOR

        if NumActualParams < PIdent^.NumParams then Error('Too few actual parameters');
  
end;

        



procedure CompileFactor(var ValType: Byte);
var     PIdent : PIdentifier;
begin
        case Tok.Kind of
        IDENTTOK: begin
                PIdent := FindIdent(Tok.Name);
    if PIdent^.Kind = PROC then
      Error('Expression expected but procedure ' + PIdent^.Name + ' found')
    else if PIdent^.Kind = FUNC then                                      // Function call
      if PIdent^.PredefIndex <> 0 then                                    // Predefined function call
        CompilePredefinedFunc(PIdent^.PredefIndex, ValType)
      else                                                                          // User-defined function call
        begin
        NextTok;
        CompileActualParameters(PIdent);
        if Pass = CALLDETERMPASS then AddCallGraphChild(BlockStack[BlockStackTop], PIdent^.ProcAsBlock);
        GenerateCall(PIdent^.Value, BlockStackTop - PIdent^.NestingLevel);
        RestoreStackTop;
        ValType := PIdent^.DataType;
        end // FUNC
    else if PIdent^.Kind = VARIABLE then            // Designator
      begin
      CompileDesignator(ValType);
      if not (Types[ValType].TypeKind in [ARRAYTYPE, RECORDTYPE]) then  // Factors of type 'array' or 'record' should contain a pointer to them
        DerefPtr(ValType);
      end
    else if PIdent^.Kind = CONSTANT then            // Constant
      begin
      ValType := PIdent^.DataType;
      if ValType = REALTYPE then
        PushConst(Integer((Pointer(@PIdent^.FracValue))^))
      else
        PushConst(PIdent^.Value);
      NextTok;
      end
    else                                                      // Type cast
      begin
      NextTok;
      EatTok(OPARTOK);
      CompileExpression(ValType);
      EatTok(CPARTOK);

      if not ((Types[PIdent^.DataType].TypeKind in OrdinalTypes + [TEXTTYPE, POINTERTYPE]) and
              (Types[ValType].TypeKind in OrdinalTypes + [TEXTTYPE, POINTERTYPE])) then
        Error('Invalid typecast');

      ValType := PIdent^.DataType;
      end;
    end;
        ADDRESSTOK: begin
                NextTok;
                CompileDesignator(ValType);
                ValType := POINTERTYPEINDEX;
        end;
        INTNUMBERTOK: begin
                PushConst(Tok.Value);
                ValType := INTEGERTYPEINDEX;
                NextTok;
        end;
        FRACNUMBERTOK: begin
                PushConst(Integer((Pointer(@Tok.FracValue))^));
                ValType := REALTYPEINDEX;
                NextTok;
        end;
        CHARLITERALTOK: begin
                PushConst(Tok.Value);
                ValType := CHARTYPEINDEX;
                NextTok;
        end;
        STRINGLITERALTOK: begin
                PushVarPtr(Tok.StrAddress, GLOBAL, 0);
                ValType := STRINGTYPEINDEX;
                NextTok;
        end;
        OPARTOK: begin
                NextTok;
                CompileExpression(ValType);
                EatTok(CPARTOK);
        end;
        NOTTOK: begin
                NextTok;
                CompileFactor(ValType);
                CheckOperator(NOTTOK, ValType);
                GenerateUnaryOperator(NOTTOK, ValType);
        end;
        NILTOK: begin
                PushConst(0);
                ValType := POINTERTYPEINDEX;
                NextTok;
        end;
        else Error('Expression expected but ' + GetSpelling(Tok) + ' found');
        end;
end;

procedure CompileTerm(var ValType: Byte);
var     OpTok        : TToken;
        RightValType : Byte;
begin
        CompileFactor(ValType);

        while Tok.Kind in [MULTOK, DIVTOK, IDIVTOK, MODTOK, SHLTOK, SHRTOK, ANDTOK] do begin
                OpTok := Tok;
                NextTok;
                CompileFactor(RightValType);

                if ConversionIsPossible(ValType, RightValType) then begin
                        GenerateFloat(SizeOf(Single));
                        ValType := REALTYPEINDEX;
                end;
                if ConversionIsPossible(RightValType, ValType) then begin
                        GenerateFloat(0);
                        RightValType := REALTYPEINDEX;
                end;

                if (OpTok.Kind = DIVTOK) and ConversionIsPossible(ValType, REALTYPEINDEX) and ConversionIsPossible(RightValType, REALTYPEINDEX) then begin
                        GenerateFloat(SizeOf(Single));
                        GenerateFloat(0);
                        ValType := REALTYPEINDEX;
                        RightValType := REALTYPEINDEX;
                end;
                ValType := GetCompatibleType(ValType, RightValType);
                CheckOperator(OpTok.Kind, ValType);
                GenerateBinaryOperator(OpTok.Kind, ValType);
        end;
end;

procedure CompileSimpleExpression(var ValType: Byte);
var     UnaryOpTok, OpTok: TToken;
        RightValType: Byte;
begin
        UnaryOpTok := Tok;
        if UnaryOpTok.Kind in [PLUSTOK, MINUSTOK] then NextTok;

        CompileTerm(ValType);

        if UnaryOpTok.Kind in [PLUSTOK, MINUSTOK] then
                CheckOperator(UnaryOpTok.Kind, ValType);

        if UnaryOpTok.Kind = MINUSTOK then GenerateUnaryOperator(MINUSTOK, ValType);     // Unary minus

        while Tok.Kind in [PLUSTOK, MINUSTOK, ORTOK, XORTOK] do begin
                OpTok := Tok;
                NextTok;
                CompileTerm(RightValType);
                if ConversionIsPossible(ValType, RightValType) then begin
                        GenerateFloat(SizeOf(Single));
                        ValType := REALTYPEINDEX;
                end;
                if ConversionIsPossible(RightValType, ValType) then begin
                        GenerateFloat(0);
                        RightValType := REALTYPEINDEX;
                end;
                ValType := GetCompatibleType(ValType, RightValType);
                CheckOperator(OpTok.Kind, ValType);
                GenerateBinaryOperator(OpTok.Kind, ValType);
        end;
end;

procedure CompileExpression(var ValType: Byte);
var     OpTok        : TToken;
        RightValType : Byte;
begin
        CompileSimpleExpression(ValType);
        if Tok.Kind in [EQTOK, NETOK, LTTOK, LETOK, GTTOK, GETOK] then begin
                OpTok := Tok;
                NextTok;
                CompileSimpleExpression(RightValType);
                if ConversionIsPossible(ValType, RightValType) then begin
                        GenerateFloat(SizeOf(Single));
                        ValType := REALTYPEINDEX;
                end;
                if ConversionIsPossible(RightValType, ValType) then begin
                        GenerateFloat(0);
                        RightValType := REALTYPEINDEX;
                end;
                GetCompatibleType(ValType, RightValType);
                CheckOperator(OpTok.Kind, ValType);
                ValType := BOOLEANTYPEINDEX;
                GenerateRelation(OpTok.Kind, RightValType);
        end;
end;

procedure CompileStatementList;
begin
        CompileStatement;
        while Tok.Kind = SEMICOLONTOK do begin
                NextTok;
                CompileStatement;
        end;
end;

procedure CompileCompoundStatement;
begin
        EatTok(BEGINTOK);
        CompileStatementList;
        EatTok(ENDTOK);
end;

procedure CompileStatement;
var     NumCaseStatements: Integer;
        ConstVal, ConstVal2: TConst;
        ExpressionType, DesignatorType, ConstValType, SelectorType: Byte;
        Down, TreatCharAsString: Boolean;
        PIdent, ResultIdent : PIdentifier;
begin

case Tok.Kind of
  IDENTTOK: begin
    PIdent := FindIdent(Tok.Name);
    case PIdent^.Kind of
      VARIABLE, FUNC:                                                 // Variable or function result assignment
        begin
        if PIdent^.Kind = VARIABLE then
          CompileDesignator(DesignatorType)
        else
          begin
          if PIdent^.ProcAsBlock <> BlockStack[BlockStackTop] then
            Error('Current function name expected but ' + PIdent^.Name + ' found');

          ResultIdent := FindIdent('RESULT');
          PushVarPtr(ResultIdent^.Value, LOCAL, 0);
          DesignatorType := ResultIdent^.DataType;

          NextTok;
          end;    

        EatTok(ASSIGNTOK);

        TreatCharAsString := (Tok.Kind = CHARLITERALTOK) and (DesignatorType = STRINGTYPEINDEX);
        if TreatCharAsString then
          begin                                                       // Special case
          PushVarPtr(Tok.StrAddress, GLOBAL, 0);
          ExpressionType := STRINGTYPEINDEX;
          NextTok;
          end else CompileExpression(ExpressionType); // General rule - right-hand side expression

        // Try to convert integer to real
        if ConversionIsPossible(ExpressionType, DesignatorType) then
          begin
          GenerateFloat(0);
          ExpressionType := REALTYPEINDEX;
          end;

        GetCompatibleType(DesignatorType, ExpressionType);

        if Types[DesignatorType].TypeKind in [ARRAYTYPE, RECORDTYPE] then
          GenerateStructuredAssignment(DesignatorType)
        else
          GenerateAssignment(DesignatorType);
        end;// VARIABLE

      PROC:                                                           // Procedure call
        if PIdent^.PredefIndex <> 0 then                    // Predefined procedure call
          CompilePredefinedProc(PIdent^.PredefIndex)
        else                                                          // User-defined procedure call
          begin
          NextTok;
          CompileActualParameters(PIdent);
          if Pass = CALLDETERMPASS then AddCallGraphChild(BlockStack[BlockStackTop], PIdent^.ProcAsBlock);
          GenerateCall(PIdent^.Value, BlockStackTop - PIdent^.NestingLevel);
          end;// PROC
    else
      Error('Statement expected but ' + PIdent^.Name + ' found');
    end// case PIdent^.Kind
    end;

  BEGINTOK: CompileCompoundStatement;

  IFTOK: begin
    NextTok;
    CompileExpression(ExpressionType);
    GetCompatibleType(ExpressionType, BOOLEANTYPEINDEX);
    EatTok(THENTOK);

    GenerateIfCondition;              // Satisfied if expression is not zero
    GenerateIfProlog;
    CompileStatement;

        if Tok.Kind = ELSETOK then begin
                NextTok;
                GenerateElseProlog;                 
                CompileStatement;
        end;

    GenerateIfElseEpilog;
    end;

  CASETOK: begin
    NextTok;
    CompileExpression(SelectorType);
    if not (Types[SelectorType].TypeKind in OrdinalTypes) then
      Error('Ordinal variable expected as CASE selector');
    EatTok(OFTOK);

    GenerateCaseProlog;  

    NumCaseStatements := 0;

    WHILE TRUE DO BEGIN

      WHILE TRUE DO BEGIN
        CompileConstExpression(ConstVal, ConstValType);
        GetCompatibleType(ConstValType, SelectorType);

        if Tok.Kind = RANGETOK then begin
          NextTok;
          CompileConstExpression(ConstVal2, ConstValType);
          GetCompatibleType(ConstValType, SelectorType);
          GenerateCaseRangeCheck(ConstVal.Value, ConstVal2.Value);
          end else
          GenerateCaseEqualityCheck(ConstVal.Value);                     // Equality check

        if Tok.Kind = COMMATOK then NextTok
        else BREAK;
      END;

      EatTok(COLONTOK);

      GenerateCaseStatementProlog;
      CompileStatement;
      GenerateCaseStatementEpilog;

      Inc(NumCaseStatements);

      if Tok.Kind <> SEMICOLONTOK then begin
        if Tok.Kind = ELSETOK then begin
          NextTok;
          CompileStatementList;
          end;
        BREAK;
        end else begin
        NextTok;
        if Tok.Kind = ENDTOK then BREAK;
        end
    END; { while }

    EatTok(ENDTOK);

    GenerateCaseEpilog(NumCaseStatements);
    end;  

  WHILETOK: begin
    Inc(CodePosStackTop);
    CodePosStack[CodePosStackTop] := CodeSize;      // Save return address used by GenerateWhileEpilog

    NextTok;
    CompileExpression(ExpressionType);
    GetCompatibleType(ExpressionType, BOOLEANTYPEINDEX);
    EatTok(DOTOK);

    GenerateWhileCondition;                         // Satisfied if expression is not zero
    GenerateIfProlog;
    CompileStatement;
    GenerateWhileEpilog;
    end;

  REPEATTOK: begin
    GenerateRepeatProlog;

    NextTok;
    CompileStatementList;

    EatTok(UNTILTOK);

    CompileExpression(ExpressionType);
    GetCompatibleType(ExpressionType, BOOLEANTYPEINDEX);
    GenerateRepeatCondition;
    GenerateRepeatEpilog;
    end;

  FORTOK: begin
    NextTok;
    AssertIdent;
    PIdent := FindIdent(Tok.Name);

    if (PIdent^.Kind <> VARIABLE) or
      ((PIdent^.NestingLevel <> 1) and (PIdent^.NestingLevel <> BlockStackTop)) or
       (PIdent^.PassMethod <> VALPASSING) then
      Error('Simple local variable expected as FOR loop counter');

    if not (Types[PIdent^.DataType].TypeKind in OrdinalTypes) then
      Error('Ordinal variable expected as FOR loop counter');

    PushVarPtr(PIdent^.Value, PIdent^.Scope, 0);

    NextTok;
    EatTok(ASSIGNTOK);
    CompileExpression(ExpressionType);
    GetCompatibleType(ExpressionType, PIdent^.DataType);

    if not (Tok.Kind in [TOTOK, DOWNTOTOK]) then
      Error('TO or DOWNTO expected but ' + GetSpelling(Tok) + ' found');

    Down := Tok.Kind = DOWNTOTOK;

    NextTok;
    CompileExpression(ExpressionType);
    GetCompatibleType(ExpressionType, PIdent^.DataType);

    SaveStackTop;                           // Save final value
    GenerateAssignment(PIdent^.DataType);   // Assign initial value to the counter
    RestoreStackTop;                        // Restore final value

    Inc(CodePosStackTop);
    CodePosStack[CodePosStackTop] := CodeSize;                // Save return address used by GenerateForEpilog

    GenerateForCondition(PIdent^.Value, PIdent^.Scope, TypeSize(PIdent^.DataType), Down);  // Satisfied if counter does not reach the second expression value

    EatTok(DOTOK);

    GenerateIfProlog;
    CompileStatement;
    GenerateForEpilog(PIdent^.Value, PIdent^.Scope, TypeSize(PIdent^.DataType), Down);
    end;

end;// case

end;



procedure CompileType(var DataType: Byte);
var
  FieldInListName: array [1..MAXFIELDS] of TName;
  NumFieldsInList, FieldInListIndex: LongInt;
  NestedDataType, LowBoundType, HighBoundType, ArrType, IndexType, FieldType: Byte;
  ConstVal: TConst;
  TypeNameGiven, ExitLoop: Boolean;
  PIdent : PIdentifier;

  procedure DeclareField(const Name: TName; RecType, FieldType: Byte);
  var
    i: Integer;
  begin
  for i := 1 to Types[RecType].NumFields do
    if Types[RecType].Field[i]^.Name = Name then
      Error('Duplicate field');

  // Add new field
  Inc(Types[RecType].NumFields);
  New(Types[RecType].Field[Types[RecType].NumFields]);
  
  Types[RecType].Field[Types[RecType].NumFields]^.Name     := Name;
  Types[RecType].Field[Types[RecType].NumFields]^.DataType := FieldType;
  Types[RecType].Field[Types[RecType].NumFields]^.Offset   := TypeSize(RecType) - TypeSize(FieldType);
  end;


begin
if Tok.Kind = DEREFERENCETOK then                                 // Typed pointer
  begin
  // Add new anonymous type
  Inc(NumTypes);
  Types[NumTypes].TypeKind := POINTERTYPE;
  DataType := NumTypes;

  // Compile pointer base type
  NextTok;
  AssertIdent;
  PIdent := FindIdentUnsafe(Tok.Name);                         
  
  if PIdent = nil then                                          // Check for a forward-referenced base type
    begin
    // Add new forward-referenced type
    Inc(NumTypes);
    Types[NumTypes].TypeKind := FORWARDTYPE;
    Types[NumTypes].TypeIdentName := Tok.Name;
    Types[NumTypes].Block := BlockStack[BlockStackTop];
    NestedDataType := NumTypes;
    end
  else
    begin
    if PIdent^.Kind <> USERTYPE then
      Error('Type name expected');
    NestedDataType := PIdent^.DataType;                 // Usual base type
    end;

  Types[DataType].BaseType := NestedDataType;
  Types[DataType].Block := BlockStack[BlockStackTop];

  NextTok;
  end// if DEREFERENCETOK
else if Tok.Kind = ARRAYTOK then                                  // Array
  begin
  NextTok;
  EatTok(OBRACKETTOK);

  DataType := NumTypes + 1;

  repeat
    // Add new anonymous type
    Inc(NumTypes);
    Types[NumTypes].TypeKind := ARRAYTYPE;
    Types[NumTypes].Block := BlockStack[BlockStackTop];
    ArrType := NumTypes;

    CompileType(IndexType);
    if not (Types[IndexType].TypeKind in OrdinalTypes) then
      Error('Ordinal type expected');
    Types[ArrType].IndexType := IndexType;

    ExitLoop := FALSE;
    if Tok.Kind = COMMATOK then
      begin
      Types[ArrType].BaseType := NumTypes + 1;
      NextTok;
      end
    else
      ExitLoop := TRUE;
  until ExitLoop;

  EatTok(CBRACKETTOK);
  EatTok(OFTOK);

  CompileType(NestedDataType);
  Types[ArrType].BaseType := NestedDataType;
  end // if ARRAYTOK
else if Tok.Kind = RECORDTOK then begin
  // Add new anonymous type
  Inc(NumTypes);
  Types[NumTypes].TypeKind := RECORDTYPE;
  DataType := NumTypes;

  NextTok;

  Types[DataType].NumFields := 0;
  repeat
    NumFieldsInList := 0;
    repeat
      AssertIdent;

      Inc(NumFieldsInList);
      FieldInListName[NumFieldsInList] := Tok.Name;

      NextTok;

      ExitLoop := FALSE;
      if Tok.Kind = COMMATOK then
        NextTok
      else
        ExitLoop := TRUE;
    until ExitLoop;

    EatTok(COLONTOK);

    CompileType(FieldType);

    for FieldInListIndex := 1 to NumFieldsInList do
      DeclareField(FieldInListName[FieldInListIndex], DataType, FieldType);

    ExitLoop := FALSE;
    if Tok.Kind <> SEMICOLONTOK then
      ExitLoop := TRUE
    else begin
      NextTok;
      if Tok.Kind = ENDTOK then ExitLoop := TRUE;
      end
  until ExitLoop;

  EatTok(ENDTOK);

  Types[DataType].Block := BlockStack[BlockStackTop];
  end// if RECORDTOK
else begin
  TypeNameGiven := FALSE;
  PIdent := nil;
  if Tok.Kind = IDENTTOK then begin
    PIdent := FindIdent(Tok.Name);
    if PIdent^.Kind = USERTYPE then TypeNameGiven := TRUE;
    end;

  if TypeNameGiven then begin
    DataType := PIdent^.DataType;
    NextTok;
    end else begin
    // Subrange
    // Add new anonymous type
    Inc(NumTypes);
    Types[NumTypes].TypeKind := SUBRANGETYPE;
    DataType := NumTypes;

    CompileConstExpression(ConstVal, LowBoundType);                               // Subrange lower bound
    if not (Types[LowBoundType].TypeKind in (OrdinalTypes - [SUBRANGETYPE])) then
      Error('Ordinal type expected');
    Types[DataType].Low := ConstVal.Value;

    EatTok(RANGETOK);

    CompileConstExpression(ConstVal, HighBoundType);                              // Subrange upper bound
    if not (Types[HighBoundType].TypeKind in (OrdinalTypes - [SUBRANGETYPE])) then
      Error('Ordinal type expected');
    Types[DataType].High := ConstVal.Value;

    GetCompatibleType(LowBoundType, HighBoundType);

    if Types[DataType].High < Types[DataType].Low then
      Error('Illegal subrange bounds');

    Types[DataType].HostType := LowBoundType;
    Types[DataType].Block := BlockStack[BlockStackTop];
    end;// else
  end;// else  

end;// CompileType





procedure CompileBlock(BlockIdent: PIdentifier);
var
  NameTok, ProcFuncTok: TToken;
  IdentInListName: array [1..MAXPARAMS] of TName;
  LocalDataSize, ParamDataSize: LongInt;
  NumIdentInList, IdentInListIndex, ParamIndex, FieldIndex, TypeIndex: Integer;
  ConstVal: TConst;
  ExitLoop: Boolean;
  ListPassMethod: Byte;
  VarType, ConstValType: Byte;
  newIdent, ForwardIdent, PIdent : PIdentifier;

  procedure DeclareId(const Name: TName; Kind: Byte; TotalNumParams: Integer; DataType: Byte; PassMethod: Byte; ConstValue: LongInt; FracConstValue: Single; PredefIndex: Byte);
  var
    i: PIdentifier;
    Scope: Byte;
  begin
  if BlockStack[BlockStackTop] = 1 then Scope := GLOBAL else Scope := LOCAL;

  i := FindIdentUnsafe(Name);

  if i <> nil then
     if i^.Block = BlockStack[BlockStackTop] then Error('Duplicate identifier: ' + Name);

  newIdent := CreateIdent(Name);
  newIdent^.Kind := Kind;
  newIdent^.Scope := Scope;
  newIdent^.DataType := DataType;
  newIdent^.Block := BlockStack[BlockStackTop];
  newIdent^.NestingLevel := BlockStackTop;
  newIdent^.NumParams := 0;
  newIdent^.PassMethod := PassMethod;
  newIdent^.IsUnresolvedForward := FALSE;
  
  case Kind of
    PROC, FUNC:
      if PredefIndex = 0 then
        newIdent^.Value := CodeSize                                // Routine entry point address
      else
        newIdent^.PredefIndex := PredefIndex;                      // Predefined routine index

    VARIABLE:
      if (Pass = CALLDETERMPASS) or BlockIsNotDead[BlockStack[BlockStackTop]] then
        case Scope of
          GLOBAL:
            begin
            newIdent^.Value := VarDataOrigin + GlobalDataSize;     // Variable address
            GlobalDataSize := GlobalDataSize + TypeSize(DataType);
            end;// else

          LOCAL:
            if TotalNumParams > 0 then begin
              ParamDataSize := ParamDataSize + SizeOf(LongInt);                                 // Parameters always occupy 4 bytes each
              newIdent^.Value := (3 + TotalNumParams) * SizeOf(LongInt) - ParamDataSize;  // Parameter offset from bp (>0); the last (hidden) parameter is the static link
              end
            else
              begin
              newIdent^.Value := -LocalDataSize - TypeSize(DataType);                     // Local variable offset from bp (<0)
              LocalDataSize := LocalDataSize + TypeSize(DataType);
              end;
        end// case
      else
        newIdent^.Value := 0;

    CONSTANT:
      if Types[DataType].TypeKind = REALTYPE then
        newIdent^.FracValue := FracConstValue                     // Real constant value
      else
        newIdent^.Value := ConstValue;                            // Ordinal constant value

  end;// case

  if VarDataOrigin + GlobalDataSize > SEGMENTSIZE then
    Error('Maximum global data size exceeded');

  if LocalDataSize > SEGMENTSIZE then
    Error('Maximum local data size exceeded');

  if ParamDataSize > SEGMENTSIZE then
    Error('Maximum parameter data size exceeded');

  end;// DeclareId



  procedure DeclarePredefinedIdents;
  begin
  // Constants
  DeclareId('TRUE',  CONSTANT, 0, BOOLEANTYPEINDEX, VALPASSING, -1, 0.0, 0);
  DeclareId('FALSE', CONSTANT, 0, BOOLEANTYPEINDEX, VALPASSING,  0, 0.0, 0);

  // Types
  DeclareId('INTEGER',  USERTYPE, 0, INTEGERTYPEINDEX,  VALPASSING, 0, 0.0, 0);
  DeclareId('SMALLINT', USERTYPE, 0, SMALLINTTYPEINDEX, VALPASSING, 0, 0.0, 0);
  DeclareId('SHORTINT', USERTYPE, 0, SHORTINTTYPEINDEX, VALPASSING, 0, 0.0, 0);
  DeclareId('CHAR',     USERTYPE, 0, CHARTYPEINDEX,     VALPASSING, 0, 0.0, 0);
  DeclareId('BOOLEAN',  USERTYPE, 0, BOOLEANTYPEINDEX,  VALPASSING, 0, 0.0, 0);
  DeclareId('REAL',     USERTYPE, 0, REALTYPEINDEX,     VALPASSING, 0, 0.0, 0);
  DeclareId('POINTER',  USERTYPE, 0, POINTERTYPEINDEX,  VALPASSING, 0, 0.0, 0);
  DeclareId('TEXT',     USERTYPE, 0, TEXTTYPEINDEX,     VALPASSING, 0, 0.0, 0);
  DeclareId('STRING',   USERTYPE, 0, STRINGTYPEINDEX,   VALPASSING, 0, 0.0, 0);

  // Procedures
  DeclareId('INC',      PROC, 0, 0, VALPASSING, 0, 0.0, INCPROC);
  DeclareId('DEC',      PROC, 0, 0, VALPASSING, 0, 0.0, DECPROC);
  DeclareId('READ',     PROC, 0, 0, VALPASSING, 0, 0.0, READPROC);
  DeclareId('WRITE',    PROC, 0, 0, VALPASSING, 0, 0.0, WRITEPROC);
  DeclareId('READLN',   PROC, 0, 0, VALPASSING, 0, 0.0, READLNPROC);
  DeclareId('WRITELN',  PROC, 0, 0, VALPASSING, 0, 0.0, WRITELNPROC);
  DeclareId('INP',      PROC, 0, 0, VALPASSING, 0, 0.0, INPPROC);
  DeclareId('OUTP',     PROC, 0, 0, VALPASSING, 0, 0.0, OUTPPROC);
  DeclareId('NEW',      PROC, 0, 0, VALPASSING, 0, 0.0, NEWPROC);
  DeclareId('DISPOSE',  PROC, 0, 0, VALPASSING, 0, 0.0, DISPOSEPROC);
  DeclareId('HALT',     PROC, 0, 0, VALPASSING, 0, 0.0, HALTPROC);
  DeclareId('INTR',     PROC, 0, 0, VALPASSING, 0, 0.0, INTRPROC);

  // Functions
  DeclareId('SIZEOF', FUNC, 0, 0, VALPASSING, 0, 0.0, SIZEOFFUNC);
  DeclareId('ORD',    FUNC, 0, 0, VALPASSING, 0, 0.0, ORDFUNC);
  DeclareId('CHR',    FUNC, 0, 0, VALPASSING, 0, 0.0, CHRFUNC);
  DeclareId('PRED',   FUNC, 0, 0, VALPASSING, 0, 0.0, PREDFUNC);
  DeclareId('SUCC',   FUNC, 0, 0, VALPASSING, 0, 0.0, SUCCFUNC);
  DeclareId('ROUND',  FUNC, 0, 0, VALPASSING, 0, 0.0, ROUNDFUNC);
  DeclareId('TRUNC',  FUNC, 0, 0, VALPASSING, 0, 0.0, TRUNCFUNC);
  DeclareId('ABS',    FUNC, 0, 0, VALPASSING, 0, 0.0, ABSFUNC);
  DeclareId('SQR',    FUNC, 0, 0, VALPASSING, 0, 0.0, SQRFUNC);
  DeclareId('SIN',    FUNC, 0, 0, VALPASSING, 0, 0.0, SINFUNC);
  DeclareId('COS',    FUNC, 0, 0, VALPASSING, 0, 0.0, COSFUNC);
  DeclareId('ARCTAN', FUNC, 0, 0, VALPASSING, 0, 0.0, ARCTANFUNC);
  DeclareId('EXP',    FUNC, 0, 0, VALPASSING, 0, 0.0, EXPFUNC);
  DeclareId('LN',     FUNC, 0, 0, VALPASSING, 0, 0.0, LNFUNC);
  DeclareId('SQRT',   FUNC, 0, 0, VALPASSING, 0, 0.0, SQRTFUNC);
  end;



  procedure DeclarePredefinedTypes;
  begin
  NumTypes := STRINGTYPEINDEX;

  Types[ANYTYPEINDEX].TypeKind      := ANYTYPE;
  Types[INTEGERTYPEINDEX].TypeKind  := INTEGERTYPE;
  Types[SMALLINTTYPEINDEX].TypeKind := SMALLINTTYPE;
  Types[SHORTINTTYPEINDEX].TypeKind := SHORTINTTYPE;
  Types[CHARTYPEINDEX].TypeKind     := CHARTYPE;
  Types[BOOLEANTYPEINDEX].TypeKind  := BOOLEANTYPE;
  Types[REALTYPEINDEX].TypeKind     := REALTYPE;
  Types[POINTERTYPEINDEX].TypeKind  := POINTERTYPE;
  Types[TEXTTYPEINDEX].TypeKind     := TEXTTYPE;
  Types[STRINGTYPEINDEX].TypeKind   := ARRAYTYPE;

  Types[POINTERTYPEINDEX].BaseType  := ANYTYPEINDEX;

  // Add new anonymous type: 0..MAXSTRLENGTH
  Inc(NumTypes);
  Types[NumTypes].TypeKind := SUBRANGETYPE;
  Types[NumTypes].HostType := INTEGERTYPEINDEX;
  Types[NumTypes].Low      := 0;
  Types[NumTypes].High     := MAXSTRLENGTH;
  Types[NumTypes].Block    := BlockStack[BlockStackTop];

  Types[STRINGTYPEINDEX].BaseType  := CHARTYPEINDEX;
  Types[STRINGTYPEINDEX].IndexType := NumTypes;
  end;// DeclarePredefinedTypes



  procedure CheckForwardResolutions;
  var
    TypeIndex: Integer;
  begin
  // Search for unresolved forward references
  for TypeIndex := 1 to NumTypes do
    if (Types[TypeIndex].TypeKind = FORWARDTYPE) and
       (Types[TypeIndex].Block = BlockStack[BlockStackTop]) then
      Error('Unresolved forward reference to type ' + Types[TypeIndex].TypeIdentName);
  end; // CheckForwardResolutions


// DeclareId
begin
        Inc(BlockStackTop);

        if BlockIdent = nil then BlockStack[BlockStackTop] := 1
        else BlockStack[BlockStackTop] := BlockIdent^.ProcAsBlock;

        ParamDataSize := 0;
        LocalDataSize := 0;

        if BlockStack[BlockStackTop] = 1 then begin
                // Main program
                DeclarePredefinedTypes;
                DeclarePredefinedIdents;
                GenerateProgramProlog;
        end else begin
                // DeclareId parameters like local variables
                for ParamIndex := 1 to BlockIdent^.NumParams do
                        DeclareId(BlockIdent^.Param[ParamIndex]^.Name,
                                VARIABLE,
                                BlockIdent^.NumParams,
                                BlockIdent^.Param[ParamIndex]^.DataType,
                                BlockIdent^.Param[ParamIndex]^.PassMethod,
                                0,
                                0.0,
                                0);

                // Allocate Result variable if the current block is a function
                if BlockIdent^.Kind = FUNC then DeclareId('RESULT', VARIABLE,
                        0, BlockIdent^.DataType, VALPASSING, 0, 0.0, 0);
                end;// else

                GenerateDeclarationProlog;


                while Tok.Kind in [CONSTTOK, TYPETOK, VARTOK, PROCEDURETOK, FUNCTIONTOK] do begin
                        if Tok.Kind = CONSTTOK then begin
                                NextTok;
                                repeat
                                        AssertIdent;

                                        NameTok := Tok;
                                        NextTok;
                                        EatTok(EQTOK);

                                        CompileConstExpression(ConstVal, ConstValType);
                                        DeclareId(NameTok.Name, CONSTANT,
                                                0, ConstValType,
                                                VALPASSING, ConstVal.Value,
                                                ConstVal.FracValue, 0);
                                        EatTok(SEMICOLONTOK);
                                until Tok.Kind <> IDENTTOK;

                        end;// if CONSTTOK
                        if Tok.Kind = TYPETOK then begin
                                NextTok;
                                repeat
                                        AssertIdent;
                                        NameTok := Tok;
                                        NextTok;
                                        EatTok(EQTOK);
                                        CompileType(VarType);
                                        DeclareId(NameTok.Name, USERTYPE,
                                                0, VarType,
                                                VALPASSING,
                                                0, 0.0, 0);

      // Check if this type was forward-referenced
      for TypeIndex := 1 to NumTypes do
        if (Types[TypeIndex].TypeKind = FORWARDTYPE) and
           (Types[TypeIndex].TypeIdentName = NameTok.Name) and
           (Types[TypeIndex].Block = BlockStack[BlockStackTop]) then
          begin
          // Forward type reference resolution
          Types[TypeIndex] := Types[VarType];
          if Types[VarType].TypeKind = RECORDTYPE then
            for FieldIndex := 1 to Types[VarType].NumFields do
              begin
              New(Types[TypeIndex].Field[FieldIndex]);
              Types[TypeIndex].Field[FieldIndex]^ := Types[VarType].Field[FieldIndex]^;
              end;
          end;// if    

      EatTok(SEMICOLONTOK);
                                until Tok.Kind <> IDENTTOK;

    CheckForwardResolutions;

    end;// if TYPETOK


  if Tok.Kind = VARTOK then begin
    NextTok;
    repeat
      NumIdentInList := 0;
      WHILE TRUE DO BEGIN
        AssertIdent;
        Inc(NumIdentInList);
        IdentInListName[NumIdentInList] := Tok.Name;
        NextTok;
        if Tok.Kind = COMMATOK then NextTok
        else BREAK;
      END;

      EatTok(COLONTOK);

      CompileType(VarType);

      for IdentInListIndex := 1 to NumIdentInList do
        DeclareId(IdentInListName[IdentInListIndex], VARIABLE, 0, VarType, VALPASSING, 0, 0.0, 0);

      EatTok(SEMICOLONTOK);
    until Tok.Kind <> IDENTTOK;

    CheckForwardResolutions;

    end;// if VARTOK


  if Tok.Kind in [PROCEDURETOK, FUNCTIONTOK] then begin
    ProcFuncTok := Tok;
    NextTok;

    AssertIdent;

    // Check for forward declaration resolution
    ForwardIdent := FindIdentUnsafe(Tok.Name);
    if ForwardIdent <> nil then
      if not ForwardIdent^.IsUnresolvedForward or
         (ForwardIdent^.Block <> BlockStack[BlockStackTop]) or
         ((ProcFuncTok.Kind = PROCEDURETOK) and (ForwardIdent^.Kind <> PROC)) or
         ((ProcFuncTok.Kind = FUNCTIONTOK) and (ForwardIdent^.Kind <> FUNC)) then
       ForwardIdent := nil;                                      // Found an identifier of another kind or scope, or it is already resolved

    if ForwardIdent = nil then begin

      if ProcFuncTok.Kind = PROCEDURETOK then
        DeclareId(Tok.Name, PROC, 0, 0, VALPASSING, 0, 0.0, 0)
      else
        DeclareId(Tok.Name, FUNC, 0, 0, VALPASSING, 0, 0.0, 0);

      NextTok;

      if Tok.Kind = OPARTOK then begin
      // Formal parameter list found
        NextTok;
        repeat
          NumIdentInList := 0;
          ListPassMethod := VALPASSING;

          if Tok.Kind = CONSTTOK then begin
            ListPassMethod := CONSTPASSING;
            NextTok;
            end
          else if Tok.Kind = VARTOK then begin
            ListPassMethod := VARPASSING;
            NextTok;
            end;

          repeat
            AssertIdent;

            Inc(NumIdentInList);
            IdentInListName[NumIdentInList] := Tok.Name;

            NextTok;

            ExitLoop := FALSE;
            if Tok.Kind = COMMATOK then
              NextTok
            else
              ExitLoop := TRUE;
          until ExitLoop;

          EatTok(COLONTOK);

          // Only type names are allowed for formal parameters
          AssertIdent;
          PIdent := FindIdent(Tok.Name);
          if PIdent^.Kind = USERTYPE then
            VarType := PIdent^.DataType
          else
            Error('Type name expected');
          NextTok;


          if (ListPassMethod = VALPASSING) and (Types[VarType].TypeKind in [ARRAYTYPE, RECORDTYPE]) then
            Error('Structured parameters cannot be passed by value');

          for IdentInListIndex := 1 to NumIdentInList do
            begin
            Inc(LastIdent^.NumParams);

            if LastIdent^.NumParams > MAXPARAMS then
              Error('Too many formal parameters in ' + LastIdent^.Name);

            New(LastIdent^.Param[LastIdent^.NumParams]);

            LastIdent^.Param[LastIdent^.NumParams]^.DataType   := VarType;
            LastIdent^.Param[LastIdent^.NumParams]^.PassMethod := ListPassMethod;
            LastIdent^.Param[LastIdent^.NumParams]^.Name       := IdentInListName[IdentInListIndex];
            end;// for

          ExitLoop := FALSE;
          if Tok.Kind = SEMICOLONTOK then
            NextTok
          else
            ExitLoop := TRUE;
        until ExitLoop;

        EatTok(CPARTOK);
        end;// if Tok.Kind = OPARTOR

      LastIdent^.DataType := 0;

      if ProcFuncTok.Kind = FUNCTIONTOK then begin
        EatTok(COLONTOK);

        // Only type names are allowed for function results
        AssertIdent;
        PIdent := FindIdent(Tok.Name);
        if PIdent^.Kind = USERTYPE then
          VarType := PIdent^.DataType
        else
          Error('Type name expected');
        NextTok;

        if Types[VarType].TypeKind in [ARRAYTYPE, RECORDTYPE] then
          Error('Structured result is not allowed');

        LastIdent^.DataType := VarType;
        end;// if IsNestedFunction

      end// if ForwardIdentIndex = 0
    else
      NextTok;

    EatTok(SEMICOLONTOK);

    // Check for a FORWARD directive (it is not a reserved word)
    if (ForwardIdent = nil) and (Tok.Kind = IDENTTOK) and (Tok.Name = 'FORWARD') then  // Forward declaration
      begin
      Inc(NumBlocks);
      LastIdent^.ProcAsBlock := NumBlocks;
      LastIdent^.IsUnresolvedForward := TRUE;
      GenerateForwardReference;
      NextTok;
      end else begin
      if ForwardIdent = nil then begin
      // New declaration
        Inc(NumBlocks);
        LastIdent^.ProcAsBlock := NumBlocks;
        CompileBlock(LastIdent);
        end else begin
        // Forward declaration resolution
        GenerateForwardResolution(ForwardIdent);
        CompileBlock(ForwardIdent);
        ForwardIdent^.IsUnresolvedForward := FALSE;
        end;

      end;

    EatTok(SEMICOLONTOK);
    end;// if Tok.Kind in [PROCEDURETOK, FUNCTIONTOK]

  end;// while

GenerateDeclarationEpilog;  // Make jump to block entry point

if BlockStack[BlockStackTop] <> 1 then
  GenerateStackFrameProlog(LocalDataSize);

CompileCompoundStatement;

// If function, return Result value via the EDX register
if (BlockStack[BlockStackTop] <> 1) and (BlockIdent^.Kind = FUNC) then begin
  PushVarPtr(FindIdent('RESULT')^.Value, LOCAL, 0);
  DerefPtr(BlockIdent^.DataType);
  SaveStackTop;
  end;

if BlockStack[BlockStackTop] = 1 then          // Main program
  GenerateProgramEpilog
else begin
  GenerateStackFrameEpilog;
  GenerateReturn(BlockIdent^.NumParams * SizeOf(LongInt));
  end;

// Delete local identifiers and types from the tables to save space
while (LastIdent <> nil) and (LastIdent^.Block = BlockStack[BlockStackTop]) do begin
  // If procedure or function, delete parameters first
  if LastIdent^.Kind in [PROC, FUNC] then begin
    if LastIdent^.IsUnresolvedForward then
      Error('Unresolved forward declaration of ' + LastIdent^.Name);

    for ParamIndex := 1 to LastIdent^.NumParams do
      Dispose(LastIdent^.Param[ParamIndex]);
    end;  

        // Delete identifier itself
        KillLastIdent;
        end;
  
        while (NumTypes > 0) and (Types[NumTypes].Block = BlockStack[BlockStackTop]) do begin
                // If record, delete fields first
                if Types[NumTypes].TypeKind = RECORDTYPE then
                        for FieldIndex := 1 to Types[NumTypes].NumFields do
                        Dispose(Types[NumTypes].Field[FieldIndex]);

                // Delete type itself
                Dec(NumTypes);
        end;    

        Dec(BlockStackTop);
end;





procedure CompileProgram;
begin
        NextTok;
        EatTok(PROGRAMTOK);
        AssertIdent;
        NextTok;
        CheckTok(SEMICOLONTOK);

        EnterIncludedFile('_system.pas');
        NextTok;

        Inc(NumBlocks);
        CompileBlock(nil);

        CheckTok(PERIODTOK);
end;


end.
