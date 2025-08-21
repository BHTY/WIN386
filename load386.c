/**
 * File: LOAD386.C
 * Loader for Windows/386 VDMM images
 * 
 * Changelog:
 * 03/18/25: Created
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "win386.h"

uint32_t dwObjOffset; /* offset of the start of the object */
uint32_t dwObjStart; /* start of the object */
uint32_t dwText16End; /* start of text section */

extern void cvtcoff(FILE* fp, uint8_t *pBuf);

uint32_t dump_obj_table(uint8_t* pBuf, uint32_t dwOffset) {
    PWIN386_OBJECT pObj = (PWIN386_OBJECT)(pBuf + dwOffset);

    int bFoundObject = 0;
    int bFoundSymbols = 0;

    while (!(bFoundObject && bFoundSymbols)) {
        printf("Type: %04X\n", pObj->wType);
        printf("Offset of contents from start of file: %08X\n", pObj->dwOffset);
        printf("Size of contents in file: %08X\n", pObj->dwPhysSize);

        if (pObj->wType == 0x02) {
            bFoundObject = 1;
            dwObjOffset = pObj->dwOffset;
            dwObjStart = pObj->dwVirtAddr;

            printf("Size of loaded object: %08X\n", pObj->dwVirtSize);
            printf("Linear address of loaded object: %08X\n", pObj->dwVirtAddr);

        } else {
            PWIN386_SYMBOL pSym = (PWIN386_SYMBOL)(pBuf + pObj->dwOffset);

            bFoundSymbols = 1;

            printf("\nSymbol Table Offset: %08X\n", pObj->dwOffset);
            printf("Size: %08X\n", pObj->dwPhysSize);

            while ((uintptr_t)(pSym) < (uintptr_t)(pBuf + pObj->dwOffset + pObj->dwPhysSize)) {
                if (strcmp(pSym->szName, "_TEXT") == 0) {
                    dwText16End = pSym->dwValue;
                }

                printf("\t%08X: %s\n", pSym->dwValue, pSym->szName);
                pSym = (PWIN386_SYMBOL)(((uint8_t*)(pSym)) + sizeof(WIN386_SYMBOL) + strlen(pSym->szName) );
            }
        }

        printf("\n");

        pObj++;
    }

    return dwOffset;
}

uint32_t dump_headers(uint8_t* pBuf) {
    PWIN386_HEADER pHeader = (PWIN386_HEADER)pBuf;
    PWIN386_HEADER_2 pHeader2 = (PWIN386_HEADER_2)(pHeader+1);

    printf("Size: %d\n", pHeader->dwSize[0] + pHeader->dwSize[1] + pHeader->dwSize[2]);
    printf("Entry point offset: %04X\n", pHeader->wOffEntry);
    /*printf("0x1Ch points to %02X (lower six bits = %02X)\n", pHeader->cUnknown, pHeader->cUnknown & 63);
    printf("0x1Eh points to %04X\n", pHeader->wUnknown2);*/
    printf("Object table offset: %p\n", pHeader2->dwOffset);
    printf("\n");

    return pHeader2->dwOffset;
}

int main(int argc, char** argv) {
    FILE* fp;
    size_t dwSize;
    uint8_t* buffer;
    
    if (argc < 2) {
        printf("Format: %s file.386\n", argv[0]);
        return -1;
    }

    fp = fopen(argv[1], "rb");

    if (fp == NULL) {
        printf("Error: Failed to open file %s\n", argv[1]);
        return -1;
    }

    printf("Windows/386 Binary Dump Utility v1.0\n");
    printf("By CaptainWillStarblazer\n\n");

    /* Determine size of file */
    fseek(fp, 0, SEEK_END);
    dwSize = ftell(fp);
    fseek(fp, 0, SEEK_SET);

    /* Allocate sufficiently sized buffer and read file in */
    buffer = malloc(dwSize);
    fread(buffer, 1, dwSize, fp);

    /* Close file */
    fclose(fp);

    dump_obj_table(buffer, dump_headers(buffer));

    /* Convert file to COFF format */
    fp = fopen("a.out", "wb");
    cvtcoff(fp, buffer);
    fclose(fp);

    printf("COFF file written to a.out\n");

    /* Write text16 section */
    fp = fopen("text16.bin", "wb");
    fwrite(buffer + dwObjOffset, 1, dwText16End - dwObjStart, fp);
    fclose(fp);

    printf("TEXT16 section written to text16.bin\n");

    return 0;
}
