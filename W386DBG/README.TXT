The Windows/386 debugger here works on a very simple principle. By first 
loading a TSR that locates the IDT within the WIN386.386 image and then
hooks INT 69H, it leaves itself resident within the machine's memory.
Then, WIN386.386's real-mode entry point is patched to invoke INT 69H
just before entering protected-mode (space is made for this by
removing Fast A20 line support), allowing the debugger to take control
of some of the vectors within Windows/386's IDT. Patch instructions will
be made available below:

At _TEXT16:01B7, there is a line of code called during Init that looks like this:
Enable_A20:
    01B7    803EBD00F8  CMP BYTE PTR [Computer_Type], 0F8H      ; Check for fast A20 support
    01BC    7707        JA Enable_A20_Slow
    01BE    E492        IN AL, 92H                              ; Fast A20 enable
    01C0    0C02        OR AL, 2                                ; Set bit 1 (A20 line control)
    01C2    E692        OUT 92H, AL                             ; Output back to port 92H
    01C4    C3          RET
Enable_A20_Slow:
    01C5    B4DF        MOV AH, 0DFH
    01C7    EB12        JMP Set_A20

The patch works by replacing the instruction at _TEXT16:01B7 with an INT 69H (CD 69)
Since the original instruction is 5 bytes long, the remaining three are padded with NOP (90)
The instruction at _TEXT16:01BC is then altered to be an unconditional jump (EB) to always
invoke the slow A20 line control.

Since the loaded object begins at offset 400H in the file, the changes are
    5B7:    80 -> CD
    5B8:    3E -> 69
    5B9:    BD -> 90
    5BA:    00 -> 90
    5BB:    F8 -> 90
    5BC:    77 -> EB

Currently, W386DBG just hooks the INT00 service vector to write some data to VRAM and hang
the machine. THIS WILL NOT TAKE OVER SOFTWARE INTERRUPT 0 FROM PROTECTED MODE! THAT VECTORS
THROUGH THE GPF HANDLER!!!!!!!! IT WILL ONLY CATCH INT0 FROM PROTECTED-MODE OR ACTUAL DIVIDE
EXCEPTIONS!

Future improvements
- Write the debugger lol
- Place breakpoint at Init32
- Serial port routines
- Load the debugger's 32-bit code into extended memory, map it to a fixed address in the page directory
    Simple idea: Allocate a single XMS handle large enough to hold the executable. Then load the flat
    binary image into it. This is done by loading chunks of it into a transfer buffer which is then
    copied into the XMS buffer. Close the file and save the XMS handle.
    When Win/386 is being loaded, lock the XMS handle and use its physical address in the page
    directory.
    Properly speaking, we probably want to allocate a 4K chunk of extended memory to store a page table
    too.


LOADING PROCESS
To protect itself from errant programs executing in conventional memory, W386DBG loads all of the data
required to be accessed while Windows/386 is active (including the 32-bit code and data) into extended
memory. 

The memory is allocated using the INT 15H AH=88H method (i.e. "top-down") where the program determines
the amount of installed extended memory, allocates its memory from the top of that, and reduces the
amount of extended memory reported to other programs by hooking the INT 15H BIOS service vector. This
is done as opposed to XMS memory as HIMEM.SYS allocates from the bottom-up (starting just above the
HMA), but even Windows/386 2.1x (which introduced HIMEM.SYS) does not respect XMS allocations made
before Windows loads, or consider them off-limits for its own allocations; when Windows/386 
initializes the memory manager, its memory test overwrites the first two DWORDs of every 64K block
of extended memory, and of course all available extended memory is subject to allocation by the
system.

The INT 15H interface can (on some systems) report up to 64MB of installed extended memory, which can
both be convenient and complicated. On the one hand, Windows/386 is only capable of utilizing up to
16MB of memory (the ceiling on AT-class machines, and the max reported by INT 15H on many machines,
including Compaq EISA systems), so memory above 16MB can be used for the debugger without fear of
reducing what is available to Windows/386. The challenge of using memory above 16MB, however, is that
the AT BIOS INT 15H AH=87H function to move memory blocks into extended memory only supports addresses
up to 16MB. Note that practically, few Windows/386 machines would have more than 16MB installed.

As a result, this neccessitates W386DBG to use its own routines to copy into extended memory. This is
accomplished on the 80386 by disabling interrupts, switching into protected-mode, loading 4GB segment
limits, performing the copy, and switching back to real-mode. It is conceptually similar to the 
"unreal mode" trick performed by HIMEM.SYS, but stays in protected-mode for the duration of the copy
rather than switching back to real-mode with extended segment limits to reduce interrupt latency. 

The nature of how this copy functions forces you to load W386DBG before any 386 memory managers such
as EMM386 which place the machine into Virtual 8086 Mode. W386DBG can be loaded at the same time as
extended memory drivers such as HIMEM.SYS as long as they execute in real-mode, but must be loaded
before any XMS allocations are made, as those, which allocate from bottom-up in the VDISK style,
cause INT 15H AH=88H to report no installed extended memory.

W386DBG allocates 132K of extended memory, divided into three sections:
Base + 00000000 => Page Table (4KB)
Base + 00001000 => 32-bit Code (64KB) -- the flat binary image of the debugger
Base + 00011000 => 32-bit Data (64KB) -- data provided by the 16-bit side, including the symbol table

The page table is inserted into Windows/386's page directory (also found via symbol lookup) while
Windows/386 is loading, mapping the 32-bit code and data starting at linear address 1C00000H.