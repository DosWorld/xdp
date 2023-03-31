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
UNIT xdgen;

INTERFACE

USES xdtypes;

TYPE
TARGET_TYPE = (TARGET_86, TARGET_386);


CONST

TARGET : TARGET_TYPE = TARGET_386;

isGen386 : boolean = true;

{
procedure Gen(b: Byte);
procedure GenStr(str : string);
procedure GenAt(Pos: LongInt; b: Byte);
procedure GenWord(w: Integer);
procedure GenWordAt(Pos: LongInt; w: Integer);
procedure GenDWord(dw: LongInt);
}
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

USES xdglob, xdutils, xdg386, xdg86;

procedure PushConstInt(Value: Integer);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.PushConstInt(Value);
        TARGET_386: xdg386.PushConstInt(Value);
        END;
end;

procedure PushConstLong(Value: LongInt);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.PushConstLong(Value);
        TARGET_386: xdg386.PushConstLong(Value);
        END;
end;

procedure PushConst(Value: LongInt);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.PushConst(Value);
        TARGET_386: xdg386.PushConst(Value);
        END;
end;

procedure PushVarPtr(Addr: Integer; Scope: Byte; DeltaNesting: Byte);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.PushVarPtr(Addr, Scope, DeltaNesting);
        TARGET_386: xdg386.PushVarPtr(Addr, Scope, DeltaNesting);
        END;
end;

procedure DerefPtr(DataType: Byte);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.DerefPtr(DataType);
        TARGET_386: xdg386.DerefPtr(DataType);
        END;
end;

procedure GetArrayElementPtr(ArrType: Byte);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GetArrayElementPtr(ArrType);
        TARGET_386: xdg386.GetArrayElementPtr(ArrType);
        END;
end;

procedure GetFieldPtr(RecType: Byte; FieldIndex: Integer);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GetFieldPtr(RecType, FieldIndex);
        TARGET_386: xdg386.GetFieldPtr(RecType, FieldIndex);
        END;
end;

procedure SaveStackTop;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.SaveStackTop;
        TARGET_386: xdg386.SaveStackTop;
        END;
end;

procedure RestoreStackTop;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.RestoreStackTop;
        TARGET_386: xdg386.RestoreStackTop;
        END;
end;

procedure SaveFileHandle;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.SaveFileHandle;
        TARGET_386: xdg386.SaveFileHandle;
        END;
end;

procedure RestoreFileHandle;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.RestoreFileHandle;
        TARGET_386: xdg386.RestoreFileHandle;
        END;
end;

procedure GenerateIncDec(proc, Size: Byte);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateIncDec(proc, Size);
        TARGET_386: xdg386.GenerateIncDec(proc, Size);
        END;
end;

procedure GenerateInpOutp(proc: Byte);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateInpOutp(proc);
        TARGET_386: xdg386.GenerateInpOutp(proc);
        END;
end;

procedure GenerateNewDispose(proc: Byte; Size: Integer);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateNewDispose(proc, Size);
        TARGET_386: xdg386.GenerateNewDispose(proc, Size);
        END;
end;

procedure GenerateHalt(err: Byte);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateHalt(err);
        TARGET_386: xdg386.GenerateHalt(err);
        END;
end;

procedure GenerateInterrupt(IntNumber: Byte);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateInterrupt(IntNumber);
        TARGET_386: xdg386.GenerateInterrupt(IntNumber);
        END;
end;

procedure GenerateRound(TruncMode: Boolean);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateRound(TruncMode);
        TARGET_386: xdg386.GenerateRound(TruncMode);
        END;
end;

procedure GenerateFloat(Depth: Byte);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateFloat(Depth);
        TARGET_386: xdg386.GenerateFloat(Depth);
        END;
end;

procedure GenerateMathFunction(func, ResultType: Byte);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateMathFunction(func, ResultType);
        TARGET_386: xdg386.GenerateMathFunction(func, ResultType);
        END;
end;

procedure GenerateUnaryOperator(op: Byte; ResultType: Byte);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateUnaryOperator(op, ResultType);
        TARGET_386: xdg386.GenerateUnaryOperator(op, ResultType);
        END;
end;

procedure GenerateBinaryOperator(op: Byte; ResultType: Byte);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateBinaryOperator(op, ResultType);
        TARGET_386: xdg386.GenerateBinaryOperator(op, ResultType);
        END;
end;

procedure GenerateRelation(rel: Byte; ValType: Byte);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateRelation(rel, ValType);
        TARGET_386: xdg386.GenerateRelation(rel, ValType);
        END;
end;

procedure GenerateAssignment(DesignatorType: Byte);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateAssignment(DesignatorType);
        TARGET_386: xdg386.GenerateAssignment(DesignatorType);
        END;
end;

procedure GenerateStructuredAssignment(DesignatorType: Byte);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateStructuredAssignment(DesignatorType);
        TARGET_386: xdg386.GenerateStructuredAssignment(DesignatorType);
        END;
end;

procedure GenerateCall(EntryPoint: LongInt; DeltaNesting: Byte);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateCall(EntryPoint, DeltaNesting);
        TARGET_386: xdg386.GenerateCall(EntryPoint, DeltaNesting);
        END;
end;

procedure GenerateReturn(TotalParamsSize: Integer);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateReturn(TotalParamsSize);
        TARGET_386: xdg386.GenerateReturn(TotalParamsSize);
        END;
end;

procedure GenerateIfCondition;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateIfCondition;
        TARGET_386: xdg386.GenerateIfCondition;
        END;
end;

procedure GenerateWhileCondition;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateWhileCondition;
        TARGET_386: xdg386.GenerateWhileCondition;
        END;
end;

procedure GenerateRepeatCondition;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateRepeatCondition;
        TARGET_386: xdg386.GenerateRepeatCondition;
        END;
end;

procedure GenerateForCondition(CounterAddress: Integer; Scope, CounterSize: Byte; Down: Boolean);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateForCondition(CounterAddress, Scope, CounterSize, Down);
        TARGET_386: xdg386.GenerateForCondition(CounterAddress, Scope, CounterSize, Down);
        END;
end;

procedure GenerateIfProlog;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateIfProlog;
        TARGET_386: xdg386.GenerateIfProlog;
        END;
end;

procedure GenerateElseProlog;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateElseProlog;
        TARGET_386: xdg386.GenerateElseProlog;
        END;
end;

procedure GenerateIfElseEpilog;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateIfElseEpilog;
        TARGET_386: xdg386.GenerateIfElseEpilog;
        END;
end;

procedure GenerateCaseProlog;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateCaseProlog;
        TARGET_386: xdg386.GenerateCaseProlog;
        END;
end;

procedure GenerateCaseEpilog(NumCaseStatements: Integer);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateCaseEpilog(NumCaseStatements);
        TARGET_386: xdg386.GenerateCaseEpilog(NumCaseStatements);
        END;
end;

procedure GenerateCaseEqualityCheck(Value: LongInt);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateCaseEqualityCheck(Value);
        TARGET_386: xdg386.GenerateCaseEqualityCheck(Value);
        END;
end;

procedure GenerateCaseRangeCheck(Value1, Value2: LongInt);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateCaseRangeCheck(Value1, Value2);
        TARGET_386: xdg386.GenerateCaseRangeCheck(Value1, Value2);
        END;
end;

procedure GenerateCaseStatementProlog;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateCaseStatementProlog;
        TARGET_386: xdg386.GenerateCaseStatementProlog;
        END;
end;

procedure GenerateCaseStatementEpilog;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateCaseStatementEpilog;
        TARGET_386: xdg386.GenerateCaseStatementEpilog;
        END;
end;

procedure GenerateWhileEpilog;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateWhileEpilog;
        TARGET_386: xdg386.GenerateWhileEpilog;
        END;
end;

procedure GenerateRepeatProlog;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateRepeatProlog;
        TARGET_386: xdg386.GenerateRepeatProlog;
        END;
end;

procedure GenerateRepeatEpilog;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateRepeatEpilog;
        TARGET_386: xdg386.GenerateRepeatEpilog;
        END;
end;

procedure GenerateForEpilog(CounterAddress: Integer; Scope, CounterSize: Byte; Down: Boolean);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateForEpilog(CounterAddress, Scope, CounterSize, Down);
        TARGET_386: xdg386.GenerateForEpilog(CounterAddress, Scope, CounterSize, Down);
        END;
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
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateProgramProlog;
        TARGET_386: xdg386.GenerateProgramProlog;
        END;
end;

procedure GenerateProgramEpilog;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateProgramEpilog;
        TARGET_386: xdg386.GenerateProgramEpilog;
        END;
end;

procedure GenerateStackFrameProlog(TotalLocalVarsSize: Integer);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateStackFrameProlog(TotalLocalVarsSize);
        TARGET_386: xdg386.GenerateStackFrameProlog(TotalLocalVarsSize);
        END;
end;

procedure GenerateStackFrameEpilog;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateStackFrameEpilog;
        TARGET_386: xdg386.GenerateStackFrameEpilog;
        END;
end;

procedure GenerateForwardReference;
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateForwardReference;
        TARGET_386: xdg386.GenerateForwardReference;
        END;
end;

procedure GenerateForwardResolution(PIdent: PIdentifier);
begin
        CASE TARGET OF
        TARGET_86:  xdg86.GenerateForwardResolution(PIdent);
        TARGET_386: xdg386.GenerateForwardResolution(PIdent);
        END;
end;

end.

