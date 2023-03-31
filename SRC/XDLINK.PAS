{ MIT No Attribution

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
UNIT xdlink;

INTERFACE

USES xdtypes, xdgen;

PROCEDURE Link(pname : TString);

IMPLEMENTATION

USES xdglob, xdutils;

CONST MZ_SIGN = $5A4D;

TYPE
{$PACKRECORDS 1}
MZ_HEADER = RECORD
        sign         : WORD;
        lblk_size    : WORD;
        blk_count    : WORD;
        relocs_count : WORD;
        header_par   : WORD;
        min_ext_par  : WORD;
        max_ext_par  : WORD;
        ss           : WORD;
        sp           : WORD;
        chksum       : WORD;
        ip           : WORD;
        cs           : WORD;
        relocs_ofs   : WORD;
        overlay_num  : WORD;
END;

PROCEDURE FileAlign(VAR f : File);
VAR     buf       : ARRAY [0..15] OF BYTE;
        count     : INTEGER;
BEGIN
        FillChar(buf, SizeOf(buf), #0);
        count := $10 - (FilePos(f) AND $0F);
        BlockWrite(f, buf, count and $0F);
END;

PROCEDURE LinkMZ(ExeName : TString);
VAR     OutFile   : File;
        ExeHeader : MZ_HEADER;
        headerSize: LONGINT;
        textSize  : LONGINT;
        dataSize  : LONGINT;
        imageSize : LONGINT;
BEGIN
        Assign(OutFile, ExeName);
        Rewrite(OutFile, 1);
        IF IOResult <> 0 THEN Error('Could not write ' + ExeName);

        WriteLn('Write ', BaseName(ExeName), ': ', CodeSize, ' bytes code, ', NumStaticStrChars, ' bytes data.');

        FillChar(ExeHeader, SizeOf(MZ_HEADER), #0);
        BlockWrite(OutFile, ExeHeader, SizeOf(MZ_HEADER));

        BlockWrite(OutFile, ExeRelocs, SizeOf(MZ_RELOC) * WriteExeRelocsCount);
        FileAlign(OutFile);
        headerSize := FilePos(OutFile);

        BlockWrite(OutFile, StaticCodeData, CodeSize);
        textSize := FilePos(OutFile) - headerSize;

        BlockWrite(OutFile, StaticStringData, NumStaticStrChars);
        dataSize := FilePos(OutFile) - headerSize - textSize;

        imageSize := dataSize + textSize;

        ExeHeader.sign := MZ_SIGN;
        ExeHeader.header_par := headerSize shr 4;
        ExeHeader.blk_count := (imageSize SHR 9) + 1;
        ExeHeader.lblk_size := imageSize AND $1FF;
        ExeHeader.relocs_ofs := SizeOf(MZ_HEADER);
        ExeHeader.min_ext_par := $2000 - (dataSize shr 4);
        ExeHeader.max_ext_par := ExeHeader.min_ext_par;
        ExeHeader.relocs_count := WriteExeRelocsCount;
        ExeHeader.sp := $FFFE;
        ExeHeader.ss := (imageSize shr 4) + $1000;
        Seek(OutFile, 0);
        BlockWrite(OutFile, ExeHeader, SizeOf(MZ_HEADER));
        Close(OutFile);
END;

PROCEDURE Link(pname : TString);
VAR     ExeName   : TString;
BEGIN
        CASE TARGET OF
        TARGET_86, TARGET_386: ChangeExt(pname, '.exe', ExeName);
        ELSE ChangeExt(pname, '', ExeName);
        END;

        CASE TARGET OF
        TARGET_86:  LinkMZ(ExeName);
        TARGET_386: LinkMZ(ExeName);
        END;
END;

END.

