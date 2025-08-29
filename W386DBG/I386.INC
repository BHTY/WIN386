;	I386.INC
;
;	Intel 80386 definitions
;
;	Copyright (c) 2024 by Will Klees

;
; 386 Descriptor Template
;
SZOF_DESC EQU (offset bas_24_31 - offset lim_0_15 + 1)
DESC    STRUC
    lim_0_15    DW  0   ; limit bits (0..15)
    bas_0_15    DW  0   ; base bits (0..15)
    bas_16_23   DB  0   ; base bits (16..23)
    access      DB  0   ; access byte
    gran        DB  0   ; granularity byte
    bas_24_31   DB  0   ; base bits (24..31)
DESC    ENDS

;
; 386 Interrupt Descriptor Template
;
SZOF_IDESC EQU (offset offs_16_31 - offset offs_0_15 + 2)
IDESC   STRUC
    offs_0_15   DW  0   ; offset bits (0..15)
    selector    DW  0   ; segment selector
    reserved    DB  0   ; reserved
    iaccess     DB  0   ; gate type, dpl, present bit
    offs_16_31  DW  0   ; offset bits (16..31)
IDESC   ENDS
