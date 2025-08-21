/**
 * File: WIN386.H
 * Definitions for WIN386.386 executable format.
 * Reference: https://www.geoffchappell.com/notes/windows/retro/win386.htm
 * 
 * Changelog:
 * 03/18/25: Created
 */

#ifndef _WIN386_H_
#define _WIN386_H_

#include <stdint.h>

/* The main file header of a 386 format executable */
typedef struct _WIN386_HEADER {
    uint32_t dwUnknown1;      /* 0x00 */
    uint32_t dwSize[3];       /* 0x04 - sum must fit in memory */
    uint32_t dwUnknown2[2];   /* 0x10 */
    uint16_t wOffEntry;       /* 0x18 - relative to object base */
    uint16_t wUnknown1;
    uint8_t  cUnknown;        /* 0x1C - low six bits must be 0Ah */
    uint16_t wUnknown2;       /* 0x1E - 0800h bit must be set */
} WIN386_HEADER, *PWIN386_HEADER;

/* The second part of the WIN386 file header */
typedef struct _WIN386_HEADER_2 {
    uint32_t dwUnknown1[5];
    uint32_t dwOffset;      /* 0x14 - offset of object table from start of file */
    uint32_t dwUnknown2[5];
} WIN386_HEADER_2, *PWIN386_HEADER_2;

/* An entry in the WIN386 object table */
typedef struct _WIN386_OBJECT {
    uint16_t wType;         /* 0x00 - only 0002h or 0003h */
    uint8_t  cFlags;        /* 0x02 - type 0002h only */
    uint8_t  cUnknown;
    uint32_t dwUnknown1;
    uint32_t dwOffset;      /* 0x08 - type 0002h or 0003h only, offset from file start */
    uint32_t dwPhysSize;    /* 0x0C - type 0002h or 0003h only, size of contents in file */
    uint32_t dwVirtSize;    /* 0x10 - type 0002h only, size of loaded object in memory */
                                /* This should be equal to the sum of Header.dwSize */
    uint32_t dwVirtAddr;    /* 0x14 - type 0002h only, linear address of loaded object */
    uint32_t dwUnknown2[2];
} WIN386_OBJECT, *PWIN386_OBJECT;

#pragma pack(push,1)
/* An entry in the WIN386 symbol table */
typedef struct _WIN386_SYMBOL {
    uint32_t dwUnknown;
    uint32_t dwValue;       /* 0x04 - linear address */
    char     szName[1];     /* 0x08 - null-terminated string */
} WIN386_SYMBOL, *PWIN386_SYMBOL;
#pragma pack(pop)

#endif /* _WIN386_H_ */
