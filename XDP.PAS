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
program XDP;

USES xdptype, xdpglob, xdputils, xdpscan, xdppars, xdpopt;

CONST
VERSION = '0.7.13';

VAR     BlockIndex: Integer;

BEGIN
        IF ParamCount <> 1 THEN BEGIN
                WriteLn('Copyright 2010 Vasiliy Tereshkov');
                WriteLn('Copyright 2023 DosWorld');
                WriteLn('XD Pascal compiler Version ', VERSION, '/dw');
                WriteLn;
                WriteLn('Usage:');
                WriteLn(#9, BaseName(ParamStr(0)),' file.pas');
                Halt(1);
        END;

        syspath := GetPathName(ParamStr(0));

        ProgramName := ParamStr(1);

        ChangeExt(ProgramName, 'exe', ExeName);
        Assign(OutFile, ExeName);

        FOR BlockIndex := 1 TO MAXBLOCKS DO BlockIsNotDead[BlockIndex] := FALSE;
        
        { Preliminary pass: compile the program and build the call graph }
        VarDataOrigin := 0;
        ZeroAll;
        
        Pass := CALLDETERMPASS;
        
        InitScanner;
        CompileProgram;
        
        { Visit the call graph nodes and mark all procedures
          that are called as not dead }
        MarkBlockNotDead(1);
        
        VarDataOrigin := NumStaticStrChars;

        { Final pass: compile the program and generate output
          (BlockIsNotDead array is preserved) }

        ZeroAll;
        Pass := CODEGENERATIONPASS;

        Rewrite(OutFile);
        IF IOResult <> 0 THEN Error('Could not write ' + ExeName);
        InitScanner;
        CompileProgram;
        BlockWrite(OutFile, ExeHeader, SizeOf(MZ_HEADER));
        BlockWrite(OutFile, ExeRelocs, SizeOf(MZ_RELOC) * WriteExeRlocsCount);
        BlockWrite(OutFile, StaticCodeData, CodeSize);
        BlockWrite(OutFile, StaticStringData, NumStaticStrChars);

        Close(OutFile);
END.

