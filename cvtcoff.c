/**
 * File: CVTCOFF.C
 * 386 to COFF format converter
 * 
 * Changelog:
 * 03/19/25: Created
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "win386.h"
#include "coff.h"

void cvtcoff(FILE* fp, uint8_t *pBuf) {
    PWIN386_HEADER pHeader = (PWIN386_HEADER)pBuf;
    PWIN386_HEADER_2 pHeader2 = (PWIN386_HEADER_2)(pHeader+1);
    PWIN386_OBJECT pObjTable = (PWIN386_OBJECT)(pBuf + pHeader2->dwOffset);
    PWIN386_SYMBOL pSym, pSymTable;
    uint8_t* pObject; /* pointer to the actual object data */

    uint32_t dwObjVirtAddr;
    size_t dwObjPhysSize;
    size_t dwObjVirtSize;

    int bFoundObject = 0;
    int bFoundSymbols = 0;
    
    uint32_t dwNumSyms;

    uintptr_t dwSymEnd;

    uint32_t dwBssStart;
    uint32_t dwTextStart;
    uint32_t dwDataStart;

    uint32_t nSyms = 0;

    uint32_t dwNameOffset = 4;

    /* parse object table */
    while (!(bFoundObject && bFoundSymbols)) {
        if (pObjTable->wType == 0x02) {
            bFoundObject = 1;
            pObject = pBuf + pObjTable->dwOffset;
            dwObjPhysSize = pObjTable->dwPhysSize;
            dwObjVirtSize = pObjTable->dwVirtSize;
            dwObjVirtAddr = pObjTable->dwVirtAddr;

        } else {
            pSymTable = (PWIN386_SYMBOL)(pBuf + pObjTable->dwOffset);
            bFoundSymbols = 1;
            dwSymEnd = (uintptr_t)(pBuf + pObjTable->dwOffset + pObjTable->dwPhysSize);
        }

        pObjTable++;
    }

    /* parse symbol table */
    pSym = pSymTable;
    while ((uintptr_t)(pSym) < dwSymEnd) {
        if (strcmp(pSym->szName, "_BSS") == 0) {
            dwBssStart = pSym->dwValue;
        } else if (strcmp(pSym->szName, "_TEXT") == 0) {
            dwTextStart = pSym->dwValue;
        } else if (strcmp(pSym->szName, "_DATA") == 0) {
            dwDataStart = pSym->dwValue;
        }

        pSym = (PWIN386_SYMBOL)(((uint8_t*)(pSym)) + sizeof(WIN386_SYMBOL) + strlen(pSym->szName) );
        nSyms++;
    }

    /* Write file header */
    {
        image_file_header_t file_hdr;

        file_hdr.f_magic = IMAGE_FILE_MACHINE_I386;
        file_hdr.f_nscns = 4;
        file_hdr.f_timdat = 0;
        file_hdr.f_symptr = sizeof(image_file_header_t) + sizeof(image_optional_header_t) + 4 * sizeof(image_section_header_t) + dwObjPhysSize;
        file_hdr.f_nsyms = nSyms;
        file_hdr.f_opthdr = sizeof(image_optional_header_t);
        file_hdr.f_flags = F_EXEC;

        fwrite(&file_hdr, 1, sizeof(file_hdr), fp);
    }

    /* Write optional header */
    {
        image_optional_header_t opt_hdr;

        opt_hdr.magic = ZMAGIC;
        opt_hdr.vstamp = 0;
        opt_hdr.tsize = dwDataStart - dwTextStart;
        opt_hdr.dsize = dwBssStart - dwDataStart;
        opt_hdr.bsize = dwObjVirtSize - dwObjPhysSize;
        opt_hdr.entry = dwObjVirtAddr + pHeader->wOffEntry;
        opt_hdr.text_start = dwTextStart;
        opt_hdr.data_start = dwDataStart;

        fwrite(&opt_hdr, 1, sizeof(opt_hdr), fp);
    }

    /* Write .text16 section header */
    {
        image_section_header_t sec_hdr;

        strcpy(sec_hdr.s_name, ".text16");
        sec_hdr.s_paddr = dwObjVirtAddr;
        sec_hdr.s_vaddr = dwObjVirtAddr;
        sec_hdr.s_size = dwTextStart - dwObjVirtAddr;
        sec_hdr.s_scnptr = sizeof(image_file_header_t) + sizeof(image_optional_header_t) + 4 * sizeof(image_section_header_t);
        sec_hdr.s_relptr = 0;
        sec_hdr.s_lnnoptr = 0;
        sec_hdr.s_nreloc = 0;
        sec_hdr.s_nlnno = 0;
        sec_hdr.s_flags = STYP_TEXT;

        fwrite(&sec_hdr, 1, sizeof(sec_hdr), fp);
    }

    /* Write .text section header */
    {
        image_section_header_t sec_hdr;

        strcpy(sec_hdr.s_name, ".text");
        sec_hdr.s_paddr = dwTextStart;
        sec_hdr.s_vaddr = dwTextStart;
        sec_hdr.s_size = dwDataStart - dwTextStart;
        sec_hdr.s_scnptr = sizeof(image_file_header_t) + sizeof(image_optional_header_t) + 4 * sizeof(image_section_header_t) + dwTextStart - dwObjVirtAddr;
        sec_hdr.s_relptr = 0;
        sec_hdr.s_lnnoptr = 0;
        sec_hdr.s_nreloc = 0;
        sec_hdr.s_nlnno = 0;
        sec_hdr.s_flags = STYP_TEXT;

        fwrite(&sec_hdr, 1, sizeof(sec_hdr), fp);
    }

    /* Write .data section header */
    {
        image_section_header_t sec_hdr;

        strcpy(sec_hdr.s_name, ".data");
        sec_hdr.s_paddr = dwDataStart;
        sec_hdr.s_vaddr = dwDataStart;
        sec_hdr.s_size = dwBssStart - dwDataStart;
        sec_hdr.s_scnptr = sizeof(image_file_header_t) + sizeof(image_optional_header_t) + 4 * sizeof(image_section_header_t) + dwDataStart - dwObjVirtAddr;
        sec_hdr.s_relptr = 0;
        sec_hdr.s_lnnoptr = 0;
        sec_hdr.s_nreloc = 0;
        sec_hdr.s_nlnno = 0;
        sec_hdr.s_flags = STYP_DATA;

        fwrite(&sec_hdr, 1, sizeof(sec_hdr), fp);
    }

    /* Write .bss section header */
    {
        image_section_header_t sec_hdr;

        strcpy(sec_hdr.s_name, ".bss");
        sec_hdr.s_paddr = dwObjVirtSize - dwObjPhysSize;
        sec_hdr.s_vaddr = dwBssStart;
        sec_hdr.s_size = 0;//dwObjVirtSize - dwObjPhysSize;
        sec_hdr.s_scnptr = 0;
        sec_hdr.s_relptr = 0;
        sec_hdr.s_lnnoptr = 0;
        sec_hdr.s_nreloc = 0;
        sec_hdr.s_nlnno = 0;
        sec_hdr.s_flags = STYP_BSS;

        fwrite(&sec_hdr, 1, sizeof(sec_hdr), fp);
    }

    /* Write object */
    fwrite(pObject, 1, dwObjPhysSize, fp);

    /* Write symbol table */
    pSym = pSymTable;
    while ((uintptr_t)(pSym) < dwSymEnd) {
        image_symbol_entry_t sym;

        sym.s_name.index.zeroes = 0;
        sym.s_name.index.offset = dwNameOffset;
        sym.n_type = 0;
        sym.n_sclass = C_EXT;
        sym.n_numaux = 0;

        if (pSym->dwValue >= dwBssStart) { /* BSS section */
            sym.n_scnum = 4;
            sym.n_value = pSym->dwValue - dwBssStart;

        } else if (pSym->dwValue >= dwDataStart) { /* Data section */
            sym.n_scnum = 3;
            sym.n_value = pSym->dwValue - dwDataStart;

        } else if (pSym->dwValue >= dwTextStart) { /* Text section */
            sym.n_scnum = 2;
            sym.n_value = pSym->dwValue - dwTextStart;

        } else if (pSym->dwValue >= dwObjVirtAddr) { /* Text16 section */
            sym.n_scnum = 1;
            sym.n_value = pSym->dwValue - dwObjVirtAddr;

        } else { /* Absolute symbol */
            sym.n_scnum = N_ABS;
            sym.n_value = pSym->dwValue;
        }

        dwNameOffset += strlen(pSym->szName) + 1;

        fwrite(&sym, 1, sizeof(sym), fp);

        pSym = (PWIN386_SYMBOL)(((uint8_t*)(pSym)) + sizeof(WIN386_SYMBOL) + strlen(pSym->szName) );
    }

    /* Write string table */
    fputc(dwNameOffset, fp);
    fputc(dwNameOffset >> 8, fp);
    fputc(dwNameOffset >> 16, fp);
    fputc(dwNameOffset >> 24, fp);

    pSym = pSymTable;

    while ((uintptr_t)(pSym) < dwSymEnd) {
        fwrite(pSym->szName, 1, strlen(pSym->szName), fp);
        fputc(0, fp);

        pSym = (PWIN386_SYMBOL)(((uint8_t*)(pSym)) + sizeof(WIN386_SYMBOL) + strlen(pSym->szName) );
    }
}