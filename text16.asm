; Windows/386 WIN386.386 Virtual DOS Machine Manager Disassembly
; by Will Klees (Captain Will Starblazer)

; 16-bit Real-Mode Entry Stub


_TEXT16:

;	The Windows/386 exit procedure
;	This is called when exiting protected mode
;	
;	Calling Environment:
;	- CS = 0xB0 (it's definitely a 16-bit CS with the base of where we're loaded, limit of 64K?)
; 	- EBX
;		Low word (BX) = Real mode segment (probably the data segment in the WIN386.EXE loader and the code segment to return to)
;		High word = Something...? It ends up in BX when we're done
;	- CX = Instruction pointer to return to (inside of WIN386.EXE?)
;	- EDX = 16:16 far pointer to real-mode stack

TermW386:
01400000  E82D00            call RetReal				; Switch back into real mode
01400003  8EDB              mov ds,bx					; Store BX into DS and ES
01400005  8EC3              mov es,bx

; Set up interrupt stack frame to return from/to
01400007  6A00              push byte +0x0				; Entirely cleared FLAGS
01400009  53                push bx						; Code segment 
0140000A  51                push cx						; Instruction pointer

0140000B  66C1EB10          shr ebx,0x10				; Shift EBX right by 16... we want BX to be 
0140000F  660FB7C0          movzx eax,ax				; Mask off the top words of all GPRs
01400013  660FB7DB          movzx ebx,bx
01400017  660FB7C9          movzx ecx,cx
0140001B  660FB7D2          movzx edx,dx
0140001F  660FB7FF          movzx edi,di
01400023  660FB7F6          movzx esi,si
01400027  660FB7ED          movzx ebp,bp
0140002B  660FB7E4          movzx esp,sp
0140002F  CF                iretw						; Exit from the VDMM


;	RetReal procedure
;	This is called from TermW386 in protected-mode to switch back into real mode
;
;	Parameters:
;	- EDX: 16:16 far pointer to real-mode stack

RetReal:
01400030  5D                pop bp						; Store return address in BP
01400031  FC                cld							; Clear direction flag for string instructions
01400032  B80800            mov ax,0x8					
01400035  8EC0              mov es,ax					; Load ES with selector 0x08... does that point to the GDT?
01400037  2680262500FD      and byte [es:0x25],0xfd		; 	in which case we're clearing the RW bit of the access byte for the TSS segment descriptor?
0140003D  B8B800            mov ax,0xb8					; Load DS, ES, SS, FS, GS with 16-bit data selectors pointing to the base address we're loaded at
01400040  8ED8              mov ds,ax
01400042  8EC0              mov es,ax
01400044  8ED0              mov ss,ax
01400046  8EE0              mov fs,ax
01400048  8EE8              mov gs,ax

0140004A  660F20C0          o32 mov eax,cr0				; Load CR0 into EAX to modify
0140004E  6625FFFFFF7F      and eax,0x7fffffff			; Disable paging
01400054  660F22C0          o32 mov cr0,eax				; Set back into EAX

01400058  660F20D8          o32 mov eax,cr3				; Load page directory address into EAX
0140005C  660F22D8          o32 mov cr3,eax				; Store page directory address back into CR3 (TLB flush?)

01400060  660F20C0          o32 mov eax,cr0				; Load CR0 into EAX to modify
01400064  6625FEFFFF7F      and eax,0x7ffffffe			; Disable paging and protected-mode
0140006A  660F22C0          o32 mov cr0,eax				; Set back into EAX

; Real_Seg points in the middle of this instruction
RM_JUMP:
Real_Seg equ RM_JUMP + 3
0140006E  EA73000000        jmp word 0x0:RMODE_ENTRY	; Far jump back into real mode at the segment where this was loaded

RMODE_ENTRY:
01400073  662E0F011EB500    o32 lidt [cs:RM_IDTR]		; Load a real-mode IDT
0140007A  8BE2              mov sp,dx					; Load SP with the offset portion of the real-mode stack
0140007C  66C1EA10          shr edx,0x10				; Shift left by 16 to put the segment into DX
01400080  8ED2              mov ss,dx					; And load that into SS
01400082  55                push bp						; Push the return address back onto the real-mode stack
01400083  8CC8              mov ax,cs					; Reload segment descriptor cache by loading real-mode segments for tiny memory model
01400085  8ED8              mov ds,ax					
01400087  8EC0              mov es,ax					
01400089  8EE0              mov fs,ax					
0140008B  8EE8              mov gs,ax
0140008D  E83901            call DISABLE_A20
01400090  C3                ret

Init32_Ptr:
.Offset:
01400091  7C02              dw Init32			; 0x027C
.Segment:
01400093  3F00              dw 0x003F

01400095  28				db 0x00
01400096  00				db 0x00

GDTR_Lin:
.LIMIT:
01400097  0000				dw 0x00
.BASE:
01400099  00000000			dd 0x00

IDTR_Lin:
.LIMIT:
0140009D  0000				dw 0x00
.BASE:
0140009F  00000000			dd 0x00

GDTR:													; This is the GDT descriptor
.LIMIT:
014000A3  0000				dw 0
.BASE:
014000A5  00000000			dd 0

IDTR:													; This is the IDT descriptor
.LIMIT:
014000A9  0000				dw 0
.BASE:
014000AB  00000000			dd 0

GDT_Seg:												; The segment paragraph that contains the GDT, placed here by the WIN386.EXE loader
014000AF  0000				dw 0x00

Page_Dir:												; The physical linear address of the page directory, placed here by the WIN386.EXE loader
014000B1  00000000         	dd 0x00

RM_IDTR:												; The IDTR we load in switching back to real mode
.LIMIT:
014000B5  FFFF				dw 0xFFFF					; Shouldn't this be 0x03FF? Maybe it doesn't matter or gets overwritten later
.BASE:
014000B7  00000000			dd 0x00000000

014000BB  0000				dw 0x00 

COMPUTER_TYPE:
014000BD  00                db 0x00


; The entry point to WIN386.386
; Executes as 16-bit real-mode code
; SS:SP and CS:IP are prepared by the WIN386.EXE loader

Init:
; set up small memory model
014000BE  8CC8              mov ax,cs
014000C0  8ED8              mov ds,ax
014000C2  8EC0              mov es,ax
014000C4  A37100            mov [Real_Seg],ax			; Store segment register into the segment portion of the far jump at CS:6Eh
014000C7  1E                push ds						; Preserve DS
014000C8  B800F0            mov ax,0xf000				; Load F000h into DS
014000CB  8ED8              mov ds,ax
014000CD  A0FEFF            mov al,[0xfffe]				; Read the computer type from the ROM BIOS (byte at F000h:FFFEh)
014000D0  1F                pop ds						; Restore DS
014000D1  A2BD00            mov [COMPUTER_TYPE],al
014000D4  FA                cli							; Disable interrupts
014000D5  E8DF00            call ENABLE_A20
014000D8  66A1B100          mov eax,[Page_Dir]			; Load the page directory address into CR3
014000DC  660F22D8          o32 mov cr3,eax

014000E0  1E                push ds						; Preserve DS
014000E1  A1AF00            mov ax,[GDT_Seg]			; Set DS to point to the GDT
014000E4  8ED8              mov ds,ax

014000E6  66A10800          mov eax,[0x8]				; Load the low DWORD of GDT Entry #1
014000EA  2666A3A300        mov [es:GDTR.LIMIT],eax		; Store the low word of the limit into the GDTR limit and the low word of the base into the low word of the GDTR base
014000EF  26A39700          mov [es:GDTR_Lin.LIMIT],ax	; Store the GDTR limit into GDTR_Lin.LIMIT
014000F3  66A10C00          mov eax,[0xc]				; Load the high DWORD of GDT Entry #1
014000F7  26A2A700          mov [es:GDTR.BASE+2],al		; Store the third byte of the GDT entry base into the GDTR base
014000FB  66C1E818          shr eax,0x18				; Shift right by 24 to get the most significant byte of the GDT entry base into AL
014000FF  26A2A800          mov [es:GDTR.BASE+3],al		; Store that into the most significant byte of the GDTR base

01400103  2666A1A500        mov eax,[es:GDTR.BASE]		; Load linear address of GDT base into EAX
01400108  662D00004001      sub eax,_TEXT16				; Subtract the virtual load address of the image
0140010E  26660FB71E7100    movzx ebx,word [es:Real_Seg]; Get the paragraph we're loaded at into EBX
01400115  66C1E304          shl ebx,0x4					; Shift left by 4 to convert the paragraph to a linear address
01400119  6603C3            add eax,ebx					; Add to EAX to get the physical linear address of the GDT base
0140011C  2666A39900        mov [es:GDTR_Lin.BASE],eax	; Store the linear address to GDTR_Lin.BASE

01400121  66A11000          mov eax,[0x10]				; Load the low DWORD of GDT Entry #2
01400125  2666A3A900        mov [es:IDTR.LIMIT],eax		; Store the low word of the limit into the IDTR limit and the low word of the base into the low word of the IDTR base
0140012A  26A39D00          mov [es:IDTR_Lin.LIMIT],ax	; Store the GDTR limit into GDTR_Lin.LIMIT
0140012E  66A11400          mov eax,[0x14]				; Load the high DWORD of GDT Entry #2
01400132  26A2AD00          mov [es:IDTR.BASE+2],al		; Store the third byte of the GDT entry base into the GDTR base
01400136  66C1E818          shr eax,0x18				; Shift right by 24 to get the most significant byte of the GDT entry base into AL
0140013A  26A2AE00          mov [es:IDTR.Base+3],al		; Store that into the most significant byte of the IDTR base

0140013E  2666A1AB00        mov eax,[es:IDTR.BASE]		; Load linear address of IDT base into EAX
01400143  662D00004001      sub eax,_TEXT16				; Subtract the virtual load address of the image
01400149  26660FB71E7100    movzx ebx,word [es:Real_Seg]; Get the paragraph we're loaded at into EBX
01400150  66C1E304          shl ebx,0x4					; Shift left by 4 to convert the paragraph to a linear address
01400154  6603C3            add eax,ebx					; Add to EAX to get the physical linear address of the IDT base
01400157  2666A39F00        mov [es:IDTR_Lin.BASE],eax	; Store the linear address to IDTR_Lin.BASE

; What is the purpose of the IDTR_Lin and GDTR_Lin structures?

0140015C  1F                pop ds						; Restore DS

0140015D  669C              pushfd						; Put EFLAGS into EAX to modify
0140015F  6658              pop eax
01400161  6625FFBFFEFF      and eax,0xfffebfff			; Clear Nested Task and Resume flags
01400167  660D00300000      or eax,0x3000				; Set IOPL to 3
0140016D  6650              push eax					; Put this back into EFLAGS
0140016F  669D              popfd

; We constructed the GDT and IDT in memory, time to load them
01400171  660F0116A300      o32 lgdt [GDTR]
01400177  660F011EA900      o32 lidt [IDTR]

0140017D  660F20C0          o32 mov eax,cr0				; Set bits in CR0 to enable protected mode and paging
01400181  660D01000080      or eax,0x80000001
01400187  660F22C0          o32 mov cr0,eax
0140018B  EA9001B000        jmp word 0xb0:PMODE_ENTRY	; Far jump into 16-bit protected mode


; The entry point into protected-mode
; 
; Windows/386 GDT Structure
; 0x00 - Null Selector (and LDT?!)
; 0x20 - TSS
; 0x30 - Flat? Data Selector
; 0x3C - 32-bit(?) code selector in LDT (loaded at Ring 3 at 0x3F?!) with base address 01400000
; 0xA8 - Stack Selector
; 0xB0 - 16-bit Code Selector (base address = segment base we're loaded at, base = 64K?)
; 0xB8 - 16-bit Data Selector (base address = segment base we're loaded at, base = 64K?)

PMODE_ENTRY:
01400190  B82000            mov ax,0x20					; Segment selector 0x20 contains the TSS
01400193  0F00D8            ltr ax					
01400196  33C0              xor ax,ax					; Clear AX
01400198  0F00D0            lldt ax						; Load LDT with null selector??????
0140019B  B83000            mov ax,0x30					; Set up mostly flat memory model with 0x30 for DS, ES, FS, GS
0140019E  8ED8              mov ds,ax
014001A0  8EC0              mov es,ax
014001A2  8EE0              mov fs,ax
014001A4  8EE8              mov gs,ax
014001A6  B8A800            mov ax,0xa8					; Load selector 0xA8 into SS
014001A9  8ED0              mov ss,ax
014001AB  66BCE00F0000      mov esp,0xfe0
014001B1  662EFF2E9100      jmp dword far [cs:Init32_Ptr]	; Far jump to 003F:Init32

ENABLE_A20:
014001B7  803EBD00F8        cmp byte [COMPUTER_TYPE],0xf8	; Check if computer supports fast A20
014001BC  7707              ja ENABLE_A20_SLOW
014001BE  E492              in al,0x92						; Fast A20 enable
014001C0  0C02              or al,0x2						; Set bit 1 (A20 line control)
014001C2  E692              out 0x92,al						; Output back to port 0x92
014001C4  C3                ret

ENABLE_A20_SLOW:
014001C5  B4DF              mov ah,0xdf
014001C7  EB12              jmp SET_A20

DISABLE_A20:
014001C9  803EBD00F8        cmp byte [COMPUTER_TYPE],0xf8	; Check if computer suports fast A20
014001CE  7707              ja DISABLE_A20_SLOW
014001D0  E492              in al,0x92						; Fast A20 disable
014001D2  24FD              and al,0xfd						; Mask off bit 1 (A20 line control)
014001D4  E692              out 0x92,al						; Output back to port 0x92
014001D6  C3                ret

DISABLE_A20_SLOW:
014001D7  B4DD              mov ah,0xdd
014001D9  EB00              jmp SET_A20


;	SET_A20 code block
;	Called to set the status of the A20 line through the keyboard controller
;
;	Parameters:
;	- AH: Value to set into the keyboard controller

SET_A20:
014001DB  E81E00            call WAIT_A20
014001DE  751B              jnz .done
014001E0  B0D1              mov al,0xd1
014001E2  E664              out 0x64,al
014001E4  E81500            call WAIT_A20
014001E7  7512              jnz .done
014001E9  8AC4              mov al,ah
014001EB  E660              out 0x60,al
014001ED  E80C00            call WAIT_A20
014001F0  7509              jnz .done
014001F2  B0FF              mov al,0xff
014001F4  E664              out 0x64,al
014001F6  E80300            call WAIT_A20
014001F9  7500              jnz .done
.done:
014001FB  C3                ret


;	WAIT_A20 procedure
;	Keep polling, looping until the keyboard controller is ready

WAIT_A20:
014001FC  51                push cx							; Preserve CS
014001FD  2BC9              sub cx,cx						; Zero out CX
.loop:
014001FF  E464              in al,0x64						; Read status register
01400201  2402              and al,0x2						; Test if input buffer is clear
01400203  E0FA              loopne .loop					; And keep looping if it's full and the keyboard controller isn't done
01400205  59                pop cx							; Restore CS
01400206  C3                ret
01400207  00                db 0x00