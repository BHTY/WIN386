;   WIN386.INC
;
;   Structure of WIN386 VDMM executable file
;   
;   Copyright (c) 2025 by Will Klees

SZOF_WIN386_HEADER equ (offset h32Unknown7 - offset h32Unknown1 + 2)
WIN386_HEADER STRUC         ; The main file header of the VDMM executable
    h32Unknown1     DD ?    ; 00
    h32Size1        DD ?    ; 04 - Sum must fit in memory
    h32Size2        DD ?
    h32Size3        DD ?
    h32Unknown2     DD ?    ; 10
    h32Unknown3     DD ?    ; 14
    h32EntryOffset  DW ?    ; 18 - relative to object base
    h32Unknown4     DW ?    ; 1A
    h32Unknown5     DB ?    ; 1C - low 6 bits must be 0AH
    h32Unknown6     DB ?    ; 1D
    h32Unknown7     DW ?    ; 1E - 0800H bit must be set
WIN386_HEADER ENDS

SZOF_WIN386_HEADER_2 equ (offset h232Unknown10 - offset h232Unknown1 + 4)
WIN386_HEADER_2 STRUC       ; The second part of the VDMM executable header
    h232Unknown1    DD ?    ; 00
    h232Unknown2    DD ?    ; 04
    h232Unknown3    DD ?    ; 08
    h232Unknown4    DD ?    ; 0C
    h232Unknown5    DD ?    ; 10
    h232OffsetLow   DW ?    ; 14 - Offset of object table from start of file
    h232OffsetHigh  DW ?    ; 16 - ^^^^^^^^ 
    h232Unknown6    DD ?    ; 18
    h232Unknown7    DD ?    ; 1C
    h232Unknown8    DD ?    ; 20
    h232Unknown9    DD ?    ; 24
    h232Unknown10   DD ?    ; 28
WIN386_HEADER_2 ENDS

SZOF_WIN386_OBJECT equ (offset o32Unknown4 - offset o32Type + 4)
WIN386_OBJECT STRUC         ; An entry in the VDMM object table
    o32Type         DW ?    ; 00 - Only 0002H or 0003H
    o32Flags        DB ?    ; 02 - Type 0002H only
    o32Unknown1     DB ?    ; 03
    o32Unknown2     DD ?    ; 04
    o32OffLow       DW ?    ; 08 - Type 0002H or 0003H only, offset from file start
    o32OffHigh      DW ?    ; 0A - ^^^^
    o32PhSzLow      DW ?    ; 0C - Type 0002H or 0003H only, size of contents in file
    o32PhSzHigh     DW ?    ; 0E - ^^^^
    o32VirtSize     DD ?    ; 10 - Type 0002H only, size of loaded object in memory
    o32VirtAddr     DD ?    ; 14 - Type 0002H only, linear address of loaded object
    o32Unknown3     DD ?    ; 18
    o32Unknown4     DD ?    ; 1C
WIN386_OBJECT ENDS

SZOF_WIN386_SYMBOL equ (offset s32Unknown1 - offset s32Unknown1 + 1)
WIN386_SYMBOL STRUC         ; An entry in the VDMM symbol table
    s32Unknown1     DD ?    ; 00
    s32ValueLow     DW ?    ; 04 - Linear address
    s32ValueHigh    DW ?
    s32Name         DB ?    ; 08 - Null-terminated string
WIN386_SYMBOL ENDS
