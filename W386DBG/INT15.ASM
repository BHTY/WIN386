    .MODEL TINY
    .STACK 400H

    LOCALS @@
    .CODE
    .386P

INCLUDE DOS.INC

MEMSIZE     EQU 1000H
Old_Int15   DD 0

Cmos    PROC    NEAR
    MOV AL, 97H     ; Write to LSB of extended memory size
    OUT 70H, AL
    MOV AL, 00H   
    OUT 71H, AL

    MOV AL, 98H     ; Write to MSB of extended memory size
    OUT 70H, AL
    MOV AL, 10H
    OUT 71H, AL

    RET
Cmos    ENDP

Start   PROC    NEAR
    CLD
    MOV AX, CS
    MOV DS, AX

    ;CALL Cmos

    MOV AH, DOS_GETVECT       ; Get old INT 15H
    MOV AL, 15H
    INT 21H
    MOV WORD PTR [Old_Int15], BX
    MOV WORD PTR [Old_Int15+2], ES

    MOV DX, OFFSET Int15      ; Hook INT 15H
    MOV AH, DOS_SETVECT
    MOV AL, 15H
    INT 21H

    MOV AL, 0                   ; Terminate and stay resident
    MOV AH, DOS_TSR
    MOV DX, 00FFH
    INT 21H
Start   ENDP

Int15   PROC    FAR
    CMP AH, 88H
    JE @@ExtMem
    JMP DWORD PTR CS:[Old_Int15]

@@ExtMem:
    MOV AX, MEMSIZE
    IRET
Int15   ENDP

    END Start