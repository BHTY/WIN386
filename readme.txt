Windows/386 Disassembly

Several parts of the MS-DOS v4.0 source code seem to be relevant to Windows/386, mainly the parts for MEMM (Microsoft Expanded Memory Manager). MEMM is apparently an early name for EMM386, in contrast to CEMM (Compaq Expanded Memory Manager) with which it shares code - Compaq made the first 386 machines, and Win386 even specifically calls out CEMM in addition to EMM386. MEMM (later MEMM386 and then EMM386) and CEMM are almost like MS-DOS and PC-DOS, though CEMM seems to have eventually been entirely replaced with generic EMM386.

These files include:
https://github.com/microsoft/MS-DOS/blob/main/v4.0/src/MEMM/MEMM/RETREAL.ASM
https://github.com/microsoft/MS-DOS/blob/main/v4.0/src/MEMM/MEMM/VMINST.ASM
https://github.com/microsoft/MS-DOS/blob/main/v4.0/src/MEMM/MEMM/INIT.ASM
https://github.com/microsoft/MS-DOS/blob/2d04cacc5322951f187bb17e017c12920ac8ebe2/v4.0/src/MEMM/EMM/EMMP.ASM#L108
https://github.com/microsoft/MS-DOS/blob/main/v4.0/src/MEMM/EMM/EMMSUP.ASM
https://github.com/microsoft/MS-DOS/blob/2d04cacc5322951f187bb17e017c12920ac8ebe2/v4.0/src/MEMM/EMM/EMMFUNCT.C#L374
https://github.com/microsoft/MS-DOS/blob/2d04cacc5322951f187bb17e017c12920ac8ebe2/v4.0/src/MEMM/EMM/EMM40.C#L233

They all have identical function names to parts of Windows/386 (especially the EMS emulation portion, though not exclusively, as much V86 monitor code is also shared), and in many cases, the implementations are identical or at least very similar to Win386. Of note is the copious amounts of macros used to implement 386 instructions; the assembler (apparently MASM 4.00) seems to have at best minimal 386 support (some files do make proper use of 386 instructions and include .386p directives, as you'd expect in MASM 5.xx). Also, most of the application seems to be implemented in 16-bit segmented code with far pointers as opposed to 32-bit flat model code like in the Win386 VDMM. 

As seemed apparent from the leading underscore and __cdecl calling convention, parts of the EMS emulator are written in C. This is confirmed by two C files composing part of MEMM here. This is very interesting because Microsoft's 386 C compiler would be in its infancy when Win386 is being written (though given that Xenix 386 - a user of the compiler - came out around the same time as Win386, it's not entirely far-fetched). The code seems to line up with what is in Microsoft's repository, though of course the code in MEMM was compiled for a 16-bit x86 architecture with 16:16 far pointers. Recompiling C code intended for far pointers isn't always as simple as just switching out your compiler, but it isn't always too tough and often can be accomplished just by ifdef'ing far to nothing in simple situations. Converting segmented to flat-model assembly, on the other hand, is decidedly nontrivial.

Code comments make reference to the sharing with Win386.


GEMMIS is documented:
http://dgi_il.tripod.com/gemmis.txt
https://jacobfilipp.com/DrDobbs/articles/DDJ/1994/9409/9409m/9409m.htm
https://board.flatassembler.net/topic.php?t=21286
https://fd.lod.bz/rbil/interrup/windows/2f1605.html#table-02634
The INT 2Fh AX=1605h is sufficient to get the v86->rm entry point, but obtaining the EMM import structures requires more work.

A debugger is in development, it works on a simple premise. Write a real-mode TSR that hooks INT 69h. Patch the real-mode entry point of WIN386.386 to do an INT69 just before entering protected-mode (replace the fast A20 support code). At this point, the TSR is in control and can patch the IDT that WIN386 is about to load to insert itself into key interrupt handlers.

Windows/386 appears to have debugging hooks via INT 68H, just like Windows 3.0. WIN386.EXE does an INT 68H call with AH=43 (D386_Identify), but doesn't seem to make any other recognizable calls. Evidently, the API is different. EMM386 appears to have hooks for a debugger called Deb386 that uses the same API as WDeb386.
