UNIT xddict;

INTERFACE

TYPE
PDictEntry = ^TDictEntry;
TDictEntry = RECORD
        name  : STRING[64];
        value : INTEGER;
        hash  : WORD;
        next  : PDictEntry;
END;

FUNCTION addDict(e : PDictEntry; name : STRING; value : INTEGER) : PDictEntry;
FUNCTION lookupDict(e : PDictEntry; name : STRING) : INTEGER;
FUNCTION FreeDict(e : PDictEntry) : PDictEntry;

IMPLEMENTATION

FUNCTION strhash(VAR s : STRING):WORD;
VAR     h : WORD;
        i : INTEGER;
BEGIN
        h := 0;
        FOR i := 1 TO LENGTH(s) DO h := h * 33 + ORD(s[i]);
        strhash := h;
END;

FUNCTION addDict(e : PDictEntry; name : STRING; value : INTEGER) : PDictEntry;
VAR     r : PDictEntry;
BEGIN
        New(r);
        r^.next := e;
        r^.name := name;
        r^.value := value;
        r^.hash := strhash(r^.name);
        addDict := r;
END;

FUNCTION FreeDict(e : PDictEntry) : PDictEntry;
VAR     r : PDictEntry;
BEGIN
        WHILE e <> NIL DO BEGIN
                r := e;
                e := e^.next;
                Dispose(r);
        END;
        FreeDict := e;
END;

FUNCTION lookupDict(e : PDictEntry; name : STRING) : INTEGER;
VAR     r : INTEGER;
        h : WORD;
BEGIN
        r := -1;
        h := strhash(name);
        WHILE e <> NIL DO BEGIN
                IF h = e^.hash THEN
                        IF e^.name = name THEN BEGIN
                                r := e^.value;
                                BREAK;
                        END;
                e := e^.next;
        END;
        lookupDict := r;
END;

END.


