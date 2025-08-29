;	XMS.INC
;
;	Extended Memory Specification API
;
;	Copyright (c) 2025 by Will Klees

; INT 2FH multiplex (43H)
XMS_INSTALLED           EQU 4300H
XMS_GET_ENTRY           EQU 4310H

; Entry points
XMS_GET_VER             EQU 00H     ; Get XMS Version Number
XMS_REQ_HMA             EQU 01H     ; Request High Memory Area
XMS_REL_HMA             EQU 02H     ; Release High Memory Area
XMS_GLOBAL_ENABLE_A20   EQU 03H     ; Global Enable A20
XMS_GLOBAL_DISABLE_A20  EQU 04H     ; Global Disable A20
XMS_LOCAL_ENABLE_A20    EQU 05H     ; Local Enable A20
XMS_LOCAL_DISABLE_A20   EQU 06H     ; Local Disable A20
XMS_QUERY_A20           EQU 07H     ; Query A20
XMS_QUERY_FREE_EXT_MEM  EQU 08H     ; Query Free Extended Memory
XMS_ALLOC_EMB           EQU 09H     ; Allocate Extended Memory Block
XMS_FREE_EMB            EQU 0AH     ; Free Extended Memory Block
XMS_MOVE_EMB            EQU 0BH     ; Move Extended Memory Block
XMS_LOCK_EMB            EQU 0CH     ; Lock Extended Memory Block
XMS_UNLOCK_EMB          EQU 0DH     ; Unlock Extended Memory Block
XMS_HANDLE_INFO         EQU 0EH     ; Get EMB Handle Information
XMS_REALLOC_EMB         EQU 0FH     ; Reallocate Extended memory Block
XMS_REQ_UMB             EQU 10H     ; Request Upper Memory Block
XMS_REL_UMB             EQU 11H     ; Release Upper Memory Block
XMS_REALLOC_UMB         EQU 12H     ; Reallocate Upper Memory Block

; Data structures
ExtMemMoveStruct    struc
    Length          dd  ?   ; 32-bit number of bytes to transfer    
    SourceHandle    dw  ?   ; Handle of source block
    SourceOffset    dd  ?   ; 32-bit offset into source
    DestHandle      dw  ?   ; Handle of destination block
    DestOffset      dd  ?   ; 32-bit offset into destination
ExtMemMoveStruct    ends

; Error codes
XMS_ERR_NOTIMPL     EQU 80H     ; The function is not implemented
XMS_ERR_VDISK       EQU 81H     ; VDISK device detected
XMS_ERR_A20         EQU 82H     ; A20 error occured
XMS_ERR_GENERAL     EQU 8EH     ; A general driver error occured
XMS_ERR_UNRECOVER   EQU 8FH     ; An unrecoverable error occured
XMS_ERR_HMA_EXIST   EQU 90H     ; The HMA doesn't exist
XMS_ERR_HMA_INUSE   EQU 91H     ; The HMA is already in use
; 92H
XMS_ERR_HMA_ALLOC   EQU 93H     ; The HMA is not allocated
XMS_ERR_A20_ENABLED EQU 94H     ; The A20 line is still enabled
XMS_ERR_NO_MEM      EQU 0A0H    ; All extended memory is allocated
XMS_ERR_NO_HANDLES  EQU 0A1H    ; All available extended memory handles in use
XMS_ERR_INV_HANDLE  EQU 0A2H    ; The handle is invalid
XMS_ERR_INV_LENGTH  EQU 0A7H    ; The length is invalid
XMS_ERR_OVERLAP     EQU 0A8H    ; The move has an invalid overlap
XMS_ERR_PARITY      EQU 0A9H    ; Parity error
XMS_ERR_NOT_LOCKED  EQU 0AAH    ; The block is not locked
XMS_ERR_LOCKED      EQU 0ABH    ; The block is not locked
XMS_ERR_LOCK_CNT    EQU 0ACH    ; The block's lock count overflowed
XMS_ERR_LOCK_FAIL   EQU 0ADH    ; The lock failed
XMS_ERR_SML_AVAIL   EQU 0B0H    ; A smaller UMB is available
XMS_ERR_NO_UMBS     EQU 0B1H    ; No UMBs available
XMS_ERR_INV_SEG     EQU 0B2H    ; Invalid UMB segment number
