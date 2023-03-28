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
{$I-}
{$MODE DELPHI}
program XDP;

USES xdptype, xdpglob, xdputils, xdpscan, xdppars, xdpopt;

const
  VERSION               = '0.7.13dw';
  
// ----- MAIN PROGRAM -----


procedure ZeroAll;
begin
        NumIdent := 0;
        NumTypes := 0;
        NumBlocks := 0;
        BlockStackTop := 0;
        CodeSize := 0;
        CodePosStackTop := 0;
        NumStaticStrChars := 0;
        GlobalDataSize := 0;
        WriteExeRlocsCount := 0;
        FillChar(ExeHeader, SizeOf(MZ_HEADER), #0);
        ExeHeader.sign := MZ_SIGN;
        ExeHeader.sp := $FFFE;
end;

procedure ChangeExt(const InStr, Ext: TString; var OutStr: TString);
var     i, DotPos: Integer;
begin
        i := Length(InStr);
        DotPos := 0;
        
        while (i > 0) and (DotPos = 0) do begin
                if InStr[i] = '.' then DotPos := i;
                Dec(i);
        end;
        
        if DotPos > 0 then OutStr := Copy(InStr, 1, DotPos) + Ext
        else OutStr := InStr + Ext;
end;  

var     BlockIndex: Integer;

begin
        if ParamCount < 1 then begin
                WriteLn('XD Pascal compiler v. ', VERSION, '.');
                WriteLn('Copyright 2010 Vasiliy Tereshkov');
                WriteLn('Copyright 2023 DosWorld');
                WriteLn;
                WriteLn('Usage: xdp <file.pas>');
                Halt(1);
        end;

        syspath := GetPathName(ParamStr(0));

        ProgramName := ParamStr(1);

        ChangeExt(ProgramName, 'exe', ExeName);
        Assign(OutFile, ExeName);

        // Default mode
        for BlockIndex := 1 to MAXBLOCKS do BlockIsNotDead[BlockIndex] := FALSE;
        
        // Preliminary pass: compile the program and build the call graph
        VarDataOrigin := 0;
        ZeroAll;
        
        Pass := CALLDETERMPASS;
        
        InitScanner;
        CompileProgram;
        
        // Visit the call graph nodes and mark all procedures that are called as not dead
        MarkBlockNotDead(1);
        
        VarDataOrigin := NumStaticStrChars;

// Final pass: compile the program and generate output (BlockIsNotDead array is preserved)

        ZeroAll;
        Pass := CODEGENERATIONPASS;

        Rewrite(OutFile);
        if IOResult <> 0 then Error('Unable to open output file ' + ExeName);
        InitScanner;
        CompileProgram;
        BlockWrite(OutFile, ExeHeader, SizeOf(MZ_HEADER));
        BlockWrite(OutFile, ExeRelocs, SizeOf(MZ_RELOC) * WriteExeRlocsCount);
        BlockWrite(OutFile, StaticCodeData, CodeSize);
        BlockWrite(OutFile, StaticStringData, NumStaticStrChars);

        Close(OutFile);
end.

