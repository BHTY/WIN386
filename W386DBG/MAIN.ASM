;	MAIN.ASM
;
;	Main driver module of W386DBG
;
;	Copyright (c) 2024 by Will Klees

    TITLE W386DBG
    .MODEL TINY
    .STACK 400H

    LOCALS @@

INCLUDE WIN386.INC
INCLUDE DOS.INC
INCLUDE PRINT.INC
INCLUDE I386.INC

SEGMENT PROG_END
PROG_END ENDS

    .CODE
    .386P
W386_SymTab DW               0      ; The segment paragraph address of the symbol table
W386_Obj    WIN386_OBJECT    <?>    ; The current object header from the VDMM image (the size of this object is the size of the symtab)
W386_Hdr    WIN386_HEADER    <?>    ; The main header of the VDMM image
W386_Hdr2   WIN386_HEADER_2  <?>    ; The second header of the VDMM image

MSG_ENTRY  DB   "Windows/386 Kernel Debugger by Will Klees", 0AH, 0DH, 24H
MSG_MEM    DB   "%wH KB Extended Memory, reserving 132K at %w%w", 0AH, 0DH, 0
MSG_LOADED DB   "Debug TSR loaded. INT 69H hooked, ready to intrude.", 0AH, 0DH, 24H
MSG_GDTSEG DB   "GDT_Seg=%w  Page_Dir=%w", 0AH, 0DH, 0
MSG_ERROR  DB   "Error: ", 24H
ERR_PROC   DB   "Installed CPU not 80386.", 0AH, 0DH, 24H
ERR_PMODE  DB   "Protected-mode software already installed.", 0AH, 0DH, 24H
ERR_OPEN   DB   "Couldn't open WIN386.386.", 0AH, 0DH, 24H
ERR_MALLOC DB   "Couldn't allocate memory for symbol table (%w).", 0AH, 0DH, 0H
ERR_SYM    DB   "Couldn't load symbol table.", 0AH, 0DH, 24H
ERR_LOCATE DB   "Couldn't locate symbol GDT_Seg.", 0AH, 0DH, 24H
ERR_LOCPGD DB   "Couldn't locate symbol Page_Dir.", 0AH, 0DH, 24H
MSG_W386LD DB   "Aboot to switch into protected mode.", 0AH, 0DH, "System loaded at %w:0000", 0AH, 0DH, "Page_Dir: %w%w", 0AH, 0DH, "GDT_Seg: %w  IDTstart: %w%w", 0AH, 0DH, 0
MSG_XMS    DB   "Debugger image loaded at %w%w", 0AH, 0DH, "Page Table at %w%w", 0AH, 0DH, 0
MSG_IDTSEG DB   "IDT_Seg=%w", 0AH, 0DH, 0
MSG_SEP    DB   "====================================", 0AH, 0DH, 0
MSG_HKDIV  DB   "LinAddr of DivHandler=%w%w", 0AH, 0DH, 0
MSG_OLDI0  DB   "Old INT0 handler=%w%w", 0AH, 0DH, 0
FNAME_W386 DB   "WIN386.386", 0
GDTSEG_SYM DB   "GDT_Seg", 0
PAGDIR_SYM DB   "Page_Dir", 0

PA_Debug   DD   0               ; The physical address of the debugger binary
PA_Data    DD   0               ; The physical address of the data transfer section
PA_PgTbl   DD   0               ; The physical address of the page table
ExtMem     DW   0               ; Kilobytes of extended memory
MemBase    DD   0               ; 
Old_Int15  DD   0               ; 

PageTbl    DD   0                ; The PTE mapping in the first 4K of the EMS_Debug region

HFile_W386 DW   0               ; An open handle to the VDMM file
Win386_Seg DW   0               ; The segment paragraph address where WIN386 is loaded
GDT_Segoff DW   0               ; The offset within the segment where WIN386 is loaded of the WORD containing the paragraph address of the GDT
PageDiroff DW   0               ; The offset within the segment where WIN386 is loaded of the DWORD containing the physical address of the page directory
Page_Dir   DD   0               ; The physical address of the page directory
GDT_Seg    DW   0               ; The paragraph address of the GDT
IDT_Seg    DW   0               ; The paragraph address of the IDT
DivHndlr   DD   0               ; Linear address of the divide handler subroutine
IDT_OFFSET EQU  10H             ; The offset within the GDT of the descriptor pointing to the IDT


PMJump      DW      OFFSET PModeCopy
            DW      OFFSET CodeDesc - OFFSET NullDesc

NullDesc    DESC    <0, 0, 0, 0, 0, 0>
CodeDesc    DESC    <0FFFFH, ?, ?, 9AH, 0, 0>
DataDesc    DESC    <0FFFFH, 0, 0, 92H, 0CFH, 0> 

GDT_Desc    LABEL   WORD
    DW      OFFSET GDT_Desc - OFFSET NullDesc - 1
    DD      ?

; Takes input in ESI, EDI, ECX
; Make CS a use16 alias for the real CS
; Make ES/DS a flat 4GB segment
; Remember the almighty A20 line!
ExtMemCopy  PROC    NEAR
    CLI
    CALL Enable_A20

    ; Calculate linear address for GDT_Desc
    MOV EAX, CS
    SHL EAX, 4
    MOV BX, OFFSET NullDesc
    AND EBX, 0FFFFH
    ADD EAX, EBX
    MOV DWORD PTR [GDT_Desc+2], EAX
    SUB EAX, EBX

    ; Calculate linear address for CS base
    MOV CodeDesc.bas_0_15, AX
    SHR EAX, 10H
    MOV CodeDesc.bas_16_23, AL

    LGDT FWORD PTR [GDT_Desc]

    MOV EAX, CR0            ; Enable protected-mode
    OR EAX, 1
    MOV CR0, EAX

    JMP DWORD PTR [PMJump]
ExtMemCopy  ENDP


PModeRet    LABEL   FAR
    MOV AX, CS
    MOV ES, AX
    MOV DS, AX
    CALL Disable_A20
    STI
    RET

PModeCopy   PROC    NEAR
    MOV AX, 10H
    MOV ES, AX
    MOV DS, AX
    DB 67H
    REP MOVSB
    
    MOV EAX, CR0            ; Disable protected-mode
    AND EAX, 0FFFFFFFEH
    MOV CR0, EAX

    JMP _TEXT:PModeRet      ; Far jump into real-mode!
PModeCopy   ENDP


Enable_A20:
    MOV AH, 0DFH
    JMP Set_A20

Disable_A20:
    MOV AH, 0DDH
    JMP Set_A20

Set_A20     PROC    NEAR
    CALL Wait_A20
    JNZ @@Done
    MOV AL, 0D1H
    OUT 64H, AL
    CALL Wait_A20
    JNZ @@Done
    MOV AL, AH
    OUT 60H, AL
    CALL Wait_A20
    JNZ @@Done
    MOV AL, 0FFH
    OUT 64H, AL
    CALL Wait_A20
    JNZ @@Done
@@Done:
    RET
Set_A20     ENDP

Wait_A20    PROC    NEAR
    PUSH CX
    SUB CX, CX
@@Loop:
    IN AL,64H
    AND AL,2
    LOOPNE @@Loop
    POP CX
    RET
Wait_A20    ENDP



printf16: ; cdecl
    push bp
    mov bp, sp
    mov ecx, 1

    printf16_loop:
        movzx eax, word ptr [ebp+4]
        mov al, byte ptr [eax]
        inc word ptr [ebp+4]
        cmp al, 0
        je printf16_done
        cmp al, '%'
        je printf16_format
        push ax
        call putc16
        jmp printf16_loop

        printf16_format:
            movzx eax, word ptr [ebp+4]
            mov al, byte ptr [eax]
            push cx
            push word ptr [ebp+4+ecx*2]

            cmp al, 'c'
            je printf16_char
            cmp al, 's'
            je printf16_str
            cmp al, 'w'
            je printf16_word
            push '%'
            call putc16
            pop cx
            jmp printf16_loop

            printf16_char:
                call putc16
                jmp printf16_format_done

            printf16_str:
                call puts
                jmp printf16_format_done

            printf16_word:
                call print_word
                jmp printf16_format_done

            printf16_format_done:
                pop cx
                inc cx
                inc word ptr [ebp+4]
        
        jmp printf16_loop

    printf16_done:
        pop bp
        ret

putc16:
    push bp
    mov bp, sp
    mov ah, 0eh
    mov al, byte ptr [bp+4]
    int 10h
    pop bp
    ret 2

; Push string on the stack
puts:
    push bp
    mov bp, sp
    push si
    mov si, [bp+4]

    .loop:
        mov al, byte ptr [si]
        inc si
        cmp al, 0
        je .done
        mov ah, 0eh
        int 10h
        jmp .loop

    .done:
        pop si
        pop bp
        ret 2

print_word:
    push bp
    mov bp, sp
    mov ax, word ptr [bp+4]
    xor dx, dx
    mov cx, 1000h
    mov bx, offset charset

    print_word_loop:
        div cx
        mov ah, 0eh
        xlat
        int 10h
        mov ax, dx
        xor dx, dx
        shr cx, 4
        cmp cx, 0
        jne print_word_loop

    pop bp
    ret 2

charset db "0123456789ABCDEF"

;   StrCmp procedure - Returns if two strings are equal.
;
;   Parameters:
;   - DS:SI: Pointer to the first null-terminated string
;   - ES:DI: Pointer to the second null-terminated string
;
;   Return values:
;   - ZF: Clear if the strings are different, set if they're equal

StrCmp  PROC    NEAR
    PUSH SI

@@Loop:
    LODSB           
    CMP AL, ES:[DI] ; ZF = *psz1 == *psz2
    JNE @@Done      
    CMP AL, 0       ; Are we done with both?
    JE @@Done
    INC DI
    JMP @@Loop

@@Done:
    POP SI
    RET
StrCmp  ENDP


;
;
;
;
;

StrLen  PROC    NEAR
    XOR AX, AX

@@Loop:
    CMP BYTE PTR ES:[DI], 0
    JE @@Done
    INC AX
    INC DI
    JMP @@Loop

@@Done:
    RET
StrLen  ENDP


;   LocSym procedure - Searches the symbol table for the presence of a
;   given symbol.
;
;   Parameters:
;   - DS:SI: Pointer to null-terminated string containing the name of the
;     symbol to search for
;
;   Return values:
;   - CF: Clear if the symbol is found, set if it's missing
;   - DX:AX: The value of the symbol, if it's found

LocSym  PROC    NEAR
    MOV ES, W386_SymTab
    XOR DI, DI

@@Loop:
    PUSH DI
    ADD DI, OFFSET s32Name
    CALL StrCmp
    POP DI
    JE @@Found
    PUSH DI
    CALL StrLen
    POP DI
    ADD DI, AX
    ADD DI, SZOF_WIN386_SYMBOL
    CMP DI, W386_Obj.o32PhSzLow
    JB @@Loop

@@NotFound:
    STC
    RET

@@Found:
    MOV AX, ES:[DI.s32ValueLow]
    MOV DX, ES:[DI.s32ValueHigh]
    CLC
    RET
LocSym  ENDP


;
;
;
;
;

Start   PROC    FAR             ; Provide WIN386.386 on the command line for symbols, including GDTseg
    CLD
    MOV AX, CS
    MOV DS, AX

    MOV AH, DOS_SETBLK          ; Free memory
    MOV BX, PROG_END
    SUB BX, _TEXT
    ADD BX, 10H
    INT 21H

    MOV DX, OFFSET MSG_ENTRY    ; Print welcome message
    MOV AH, DOS_PRINT
    INT 21H

    SMSW AX                     ; Check if we're already in protected mode
    TEST AX, 1                    
    JNZ @@InPMode                  

    MOV AH, 88H                 ; Determine the amount of free memory
    INT 15H
    MOV ExtMem, AX
    SUB ExtMem, 132             ; Subtract 132K - the amount of memory we're reserving

    MOVZX EDX, ExtMem           ; Determine the start of the region we're reserving
    SHL EDX, 0AH                
    ADD EDX, 100000H
    MOV MemBase, EDX

    PUSH WORD PTR [MemBase]     ; Print out memory details
    PUSH WORD PTR [MemBase+2]
    PUSH AX
    PUSH OFFSET MSG_MEM
    CALL printf16
    ADD SP, 8

    MOV EAX, MemBase
    MOV PA_PgTbl, EAX
    ADD EAX, 1000H
    MOV PA_Debug, EAX
    ADD EAX, 10000H
    MOV PA_Data, EAX

                                ; Prep the page tables
    MOV EAX, PA_Debug
    OR EAX, 7
    MOV PageTbl, EAX

    MOV SI, CS
    MOVZX ESI, SI
    SHL ESI, 4
    MOV BX, OFFSET PageTbl
    MOVZX EBX, BX
    ADD ESI, EBX
    MOV EDI, PA_PgTbl
    MOV ECX, 4
    CALL ExtMemCopy

                                ; Load the debugger image
    MOV SI, CS
    MOVZX ESI, SI
    SHL ESI, 4
    MOV BX, OFFSET DivHandler
    MOVZX EBX, BX
    ADD ESI, EBX
    MOV EDI, PA_Debug
    MOV ECX, 40H
    CALL ExtMemCopy

    PUSH WORD PTR [PA_PgTbl]    ; And display the addresses of both
    PUSH WORD PTR [PA_PgTbl+2]
    PUSH WORD PTR [PA_Debug]
    PUSH WORD PTR [PA_Debug+2]
    PUSH OFFSET MSG_XMS
    CALL printf16
    ADD SP, 0AH

    MOV AH, DOS_OPEN            ; Try opening the VDMM for reading
    MOV AL, 00H
    MOV DX, OFFSET FNAME_W386
    INT 21H
    JC @@FailOpen
    MOV HFile_W386, AX

    MOV AH, DOS_READ            ; Read the first header into memory
    MOV BX, HFile_W386
    MOV CX, SZOF_WIN386_HEADER
    MOV DX, OFFSET W386_Hdr
    INT 21H
    JC @@FailRead               ; Did the call fail?
    CMP AX, SZOF_WIN386_HEADER  ; Did we read fewer bytes than expected?
    JB @@FailRead

    MOV AH, DOS_READ            ; Read the second header into memory
    MOV BX, HFile_W386
    MOV CX, SZOF_WIN386_HEADER_2
    MOV DX, OFFSET W386_Hdr2
    INT 21H
    JC @@FailRead               ; Did the call fail?
    CMP AX, SZOF_WIN386_HEADER_2; Did we read fewer bytes than expected?
    JB @@FailRead

    MOV AH, DOS_SEEK            ; Seek to the location of the object table
    MOV AL, SEEK_SET
    MOV BX, HFile_W386
    XOR CX, CX                  ; High WORD of bytes to move
    MOV DX, W386_Hdr2.h232OffsetLow
    INT 21H
    JC @@FailRead               ; Did the call fail?
    CMP AX, W386_Hdr2.h232OffsetLow
    JNE @@FailRead              ; Or did we not seek to where we expected?

@@Read_Objects:                 ; Read objects until we've read in the symbol table
    MOV AH, DOS_READ
    MOV BX, HFile_W386
    MOV CX, SZOF_WIN386_OBJECT
    MOV DX, OFFSET W386_Obj
    INT 21H
    JC @@FailRead               ; Did the call fail?
    CMP AX, SZOF_WIN386_OBJECT  ; Did we read fewer bytes than expected?
    JB @@FailRead
    CMP W386_Obj.o32Type, 3     ; Did we locate the symbol table?
    JE @@Found_SymTab
    JMP @@Read_Objects

@@Found_SymTab:
    MOV AH, DOS_ALLOC           ; Allocate memory to hold the symbol table
    MOV BX, W386_Obj.o32PhSzLow
    SHR BX, 4
    INC BX
    INT 21H
    JC @@FailAlloc
    MOV W386_SymTab, AX

    MOV AH, DOS_SEEK            ; Seek to the beginning of the symbol table
    MOV AL, SEEK_SET
    MOV BX, HFile_W386
    MOV CX, W386_Obj.o32OffHigh
    MOV DX, W386_Obj.o32OffLow
    INT 21H
    JC @@FailRead               ; Did the call fail?
    CMP DX, W386_Obj.o32OffHigh ; Did we seek to the right place?
    JNE @@FailRead
    CMP AX, W386_Obj.o32OffLow
    JNE @@FailRead

    MOV AH, DOS_READ            ; Read the symbol table into memory
    MOV BX, HFile_W386
    MOV CX, W386_Obj.o32PhSzLow
    MOV DS, W386_SymTab
    XOR DX, DX
    INT 21H
    MOV BX, CS                  ; Restore the old DS
    MOV DS, BX
    JC @@FailRead               ; Did the call fail?
    CMP AX, W386_Obj.o32PhSzLow ; Did we read fewer bytes than expected?
    JB @@FailRead

    MOV AH, DOS_CLOSE           ; Close the VDMM file
    MOV BX, HFile_W386
    INT 21H

    MOV SI, OFFSET GDTSEG_SYM   ; Locate the GDT segment symbol
    CALL LocSym
    JC @@FailFind               ; Did this fail?
    MOV GDT_Segoff, AX

    MOV SI, OFFSET PAGDIR_SYM   ; Locate the page directory symbol
    CALL LocSym
    JC @@FailFind               ; Did this fail?
    MOV PageDiroff, AX

    MOV AH, DOS_GETVECT         ; Get old INT 15H service vector
    MOV AL, 15H
    INT 21H
    MOV WORD PTR [Old_Int15], BX
    MOV WORD PTR [Old_Int15+2], ES

    MOV DX, OFFSET Int15        ; Hook INT 15H
    MOV AH, DOS_SETVECT         
    MOV AL, 15H
    INT 21H

    MOV DX, OFFSET Intrude      ; Hook INT 69H
    MOV AH, DOS_SETVECT
    MOV AL, 69H
    INT 21H

    PUSH PageDiroff
    PUSH GDT_Segoff
    PUSH OFFSET MSG_GDTSEG
    CALL printf16
    ADD SP, 4

    MOV DX, OFFSET MSG_LOADED   ; Tell the user that we loaded successfully
    MOV AH, DOS_PRINT
    INT 21H

    MOV AH, DOS_CLOSE           ; Close the VDMM file
    MOV BX, HFile_W386
    INT 21H

    MOV AL, 0                   ; Terminate and stay resident
    MOV AH, DOS_TSR
    MOV DX, 00FFH
    INT 21H

@@FailFind:
    MOV DX, OFFSET MSG_ERROR
    MOV AH, DOS_PRINT
    INT 21H

    MOV DX, OFFSET ERR_LOCATE
    MOV AH, DOS_PRINT
    INT 21H

    JMP @@Done

@@FailAlloc:
    PUSH AX
    
    MOV AH, DOS_CLOSE           ; Close the VDMM file
    MOV BX, HFile_W386
    INT 21H

    MOV DX, OFFSET MSG_ERROR
    MOV AH, DOS_PRINT
    INT 21H

    PUSH OFFSET ERR_MALLOC
    CALL printf16
    ADD SP, 4

    JMP @@Done

@@FailRead:
    MOV AH, DOS_CLOSE           ; Close the VDMM file
    MOV BX, HFile_W386
    INT 21H

    MOV DX, OFFSET MSG_ERROR
    MOV AH, DOS_PRINT
    INT 21H

    MOV DX, OFFSET ERR_SYM
    MOV AH, DOS_PRINT
    INT 21H

    JMP @@Done

@@FailOpen:
    MOV DX, OFFSET MSG_ERROR
    MOV AH, DOS_PRINT
    INT 21H

    MOV DX, OFFSET ERR_OPEN
    MOV AH, DOS_PRINT
    INT 21H

    JMP @@Done

@@InPMode:
    MOV DX, OFFSET MSG_ERROR
    MOV AH, DOS_PRINT
    INT 21H

    MOV DX, OFFSET ERR_PMODE
    MOV AH, DOS_PRINT
    INT 21H

    JMP @@Done

@@Done:
    MOV AH, DOS_EXIT
    INT 21H
Start   ENDP


;   Intrude procedure - Hijacks the loading process of Windows/386.
;
;   Called by way of an INT 68H interrupt just before Windows/386 enters
;   protected-mode, this outputs a string over the serial port (after setting
;   it up properly)
;
;   Hack ourselves into the IDT to hijack exception handlers and serial port irq
;   to point to the 32-bit part of the debugger
;
;   00H (Divide Error)
;   01H (Trace Interrupt)
;   02H (NMI)
;   03H (Breakpoint)
;   04H (Overflow)
;   05H (Bound)
;   06H (Invalid Opcode)
;   07H (Device Not Available)
;   08H (Double Fault)
;   0AH (Invalid TSS)
;   0BH (Segment Not Present)
;   0CH (Stack Segment Fault)
;   0DH (General Protection Fault)
;   0EH (Page Fault)
;   54H (IRQ4)
;

Intrude PROC    FAR
    PUSHA
    PUSH DS
    PUSH ES
    MOV BP, SP          ; Create stack frame
                        ; [BP+00] = ES
                        ; [BP+02] = DS
                        ; [BP+04] = DI
                        ; [BP+06] = SI
                        ; [BP+08] = BP
                        ; [BP+0A] = Temp SP
                        ; [BP+0C] = BX
                        ; [BP+0E] = DX
                        ; [BP+10] = CX
                        ; [BP+12] = AX
                        ; [BP+14] = IP
                        ; [BP+16] = CS
                        ; [BP+18] = FLAGS
    
    MOV AX, CS
    MOV DS, AX

    MOV AX, [BP+16H]    ; AX = Old CS
    MOV ES, AX          ; ES = Old CS
    MOV BX, PageDiroff
    MOV ECX, ES:[BX]
    MOV Page_Dir, ECX
    MOV BX, GDT_Segoff
    MOV BX, ES:[BX]
    MOV GDT_Seg, BX
    MOV ES, BX          ; ES = GDT_Seg

    MOV CX, ES:[IDT_OFFSET.bas_0_15]    ; CX = Low base
    MOV DL, ES:[IDT_OFFSET.bas_16_23]   ; DX = high base
    MOV DH, ES:[IDT_OFFSET.bas_24_31]

    PUSH CX                             ; ...
    PUSH DX                             ; Linear address of IDT
    PUSH GDT_Seg                        ; Segment address of GDT
    PUSH WORD PTR [Page_Dir]
    PUSH WORD PTR [Page_Dir+2]
    PUSH AX                             ; Segment loaded at
    PUSH OFFSET MSG_W386LD
    CALL printf16
    ADD SP, 0EH

    MOV CX, ES:[IDT_OFFSET.bas_0_15]    ; CX = Low base
    MOV DL, ES:[IDT_OFFSET.bas_16_23]   ; DX = high base
    MOV DH, ES:[IDT_OFFSET.bas_24_31]
    SHRD CX, DX, 4
    ADD CX, [BP+16H]
    MOV IDT_Seg, CX

    PUSH IDT_Seg
    PUSH OFFSET MSG_IDTSEG
    CALL printf16
    ADD SP, 4

    MOV AX, CS
    MOVZX EAX, AX
    SHL EAX, 4
    MOV BX, OFFSET DivHandler
    MOVZX EBX, BX
    ADD EAX, EBX
    MOV DivHndlr, EAX

    PUSH WORD PTR [DivHndlr]
    PUSH WORD PTR [DivHndlr+2]
    PUSH OFFSET MSG_HKDIV
    CALL printf16
    ADD SP, 6

    MOV EAX, Page_Dir
    SHR EAX, 4
    MOV ES, AX
    MOV EAX, PA_PgTbl
    OR EAX, 7
    MOV ES:[1CH], EAX 

    MOV ES, IDT_Seg
    PUSH WORD PTR ES:[OFFSET offs_0_15]
    PUSH WORD PTR ES:[OFFSET offs_16_31]
    PUSH OFFSET MSG_OLDI0
    CALL printf16
    ADD SP, 6

    MOV AX, WORD PTR [DivHndlr]
    MOV WORD PTR ES:[OFFSET offs_0_15], 0;AX
    MOV AX, WORD PTR [DivHndlr+2]
    MOV WORD PTR ES:[OFFSET offs_16_31], 1C0H;AX
    
    PUSH WORD PTR ES:[OFFSET offs_0_15]
    PUSH WORD PTR ES:[OFFSET offs_16_31]
    PUSH OFFSET MSG_OLDI0
    CALL printf16
    ADD SP, 6

    PUSH OFFSET MSG_SEP
    CALL printf16
    ADD SP, 2

    MOV AH, 0
    INT 16H

    POP ES
    POP DS
    POPA
    IRET

    JMP $





    PUSH BP             
    MOV BP, SP          ; Create stack frame
                        ; [BP+00] = Old BP
                        ; [BP+02] = Old IP
                        ; [BP+04] = Old CS
                        ; [BP+06] = Old FLAGS
    MOV AX, CS
    MOV DS, AX

    MOV AX, [BP+4]      ; AX = Old CS
    MOV ES, AX          ; ES = Old CS
    MOV BX, GDT_Segoff
    MOV BX, ES:[BX]     
    MOV GDT_Seg, BX
    MOV ES, BX          ; ES = GDT_Seg

    MOV CX, ES:[IDT_OFFSET.bas_0_15]    ; CX = Low base
    MOV DL, ES:[IDT_OFFSET.bas_16_23]   ; DX = high base
    MOV DH, ES:[IDT_OFFSET.bas_24_31]

    PUSH CX                             ; ...
    PUSH DX                             ; Linear address of IDT
    PUSH GDT_Seg                        ; Segment address of GDT
    PUSH AX                             ; Segment loaded at
    PUSH OFFSET MSG_W386LD
    CALL printf16
    ADD SP, 0AH

    JMP $
    IRET
Intrude ENDP


Int15   PROC    FAR
    CMP AH, 88H
    JE @@ExtMem
    JMP DWORD PTR CS:[Old_Int15]
@@ExtMem:
    MOV AX, CS:ExtMem
    IRET
Int15   ENDP


DivHandler  DB 66H, 0BBH, 30H, 00H                   ; MOV BX, 30H                      ; Set flat data selector into DS
            DB 8EH, 0DBH                             ; MOV DS, BX
            DB 0C6H, 05H, 00H, 80H, 0BH, 00H, 57H    ; MOV BYTE PTR [0B8000H], 'W'
            DB 0C6H, 05H, 02H, 80H, 0BH, 00H, 33H    ; MOV BYTE PTR [0B8002H], '3'
            DB 0C6H, 05H, 04H, 80H, 0BH, 00H, 38H    ; MOV BYTE PTR [0B8004H], '8'
            DB 0C6H, 05H, 06H, 80H, 0BH, 00H, 36H    ; MOV BYTE PTR [0B8006H], '6'
            DB 0C6H, 05H, 08H, 80H, 0BH, 00H, 44H    ; MOV BYTE PTR [0B8008H], 'D'
            DB 0C6H, 05H, 0AH, 80H, 0BH, 00H, 42H    ; MOV BYTE PTR [0B800AH], 'B'
            DB 0C6H, 05H, 0CH, 80H, 0BH, 00H, 47H    ; MOV BYTE PTR [0B800CH], 'G'
            DB 0EBH, 0FEH                            ; JMP $


    END Start