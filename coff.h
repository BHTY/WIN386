/**
 * File: COFF.H
 * 
 * Definitions for System V COFF executable image files.
 * 
 * Copyright (c) 2025 by Will Klees
 * 
 * Changelog:
 * 02/18/25: Created
 * 03/19/25: Updated to include more COFF symbol flags
 */

#ifndef _COFF_H_
#define _COFF_H_

#include <stdint.h>

#define IMAGE_FILE_MACHINE_I386     0x014C
#define ZMAGIC                      0x010B

#define F_RELFLG 1
#define F_EXEC 2
#define F_LNNO 4
#define F_LSYMS 8
#define F_AR32WR 0x100

typedef struct image_file_header {
    uint16_t f_magic;   /* machine type */
    uint16_t f_nscns;   /* number of sections */
    int32_t f_timdat;   /* time & date stamp */
    int32_t f_symptr;   /* file pointer to symbol table */
    int32_t f_nsyms;    /* number of symbols */
    uint16_t f_opthdr;  /* sizeof(Optional Header) */
    uint16_t f_flags;   /* flags */
} image_file_header_t;

typedef struct image_optional_header {
    uint16_t magic;         /* magic number */
    uint16_t vstamp;        /* version stamp */
    uint32_t tsize;         /* text size in bytes */
    uint32_t dsize;         /* initialized data size */
    uint32_t bsize;         /* uninitialized data size */
    uint32_t entry;         /* entry point */
    uint32_t text_start;    /* base of text */
    uint32_t data_start;    /* start of data */
} image_optional_header_t;

#define STYP_TEXT 0x20
#define STYP_DATA 0x40
#define STYP_BSS  0x80

typedef struct image_section_header {
    char s_name[8];         /* section name */
    int32_t s_paddr;        /* physical addresss */
    int32_t s_vaddr;        /* virtual address */
    int32_t s_size;         /* section size in bytes */
    int32_t s_scnptr;       /* file offset to section data */
    int32_t s_relptr;       /* file offset to relocation table */
    int32_t s_lnnoptr;      /* file offset to line number table */
    uint16_t s_nreloc;      /* number of relocation table entries */
    uint16_t s_nlnno;       /* number of line number table entries */
    int32_t s_flags;        /* flags for this section */
} image_section_header_t;

typedef struct image_reloc_entry {
    int32_t r_vaddr;        /* reference address */
    int32_t r_symndx;       /* symbol index */
    uint16_t r_type;        /* relocation type */
} image_reloc_entry_t;

typedef struct image_lnno_entry {
    union {
        int32_t l_symndx;   /* symbol index */
        int32_t l_paddr;    /* physical address */
    } l_addr;
    uint16_t l_lnno;    /* line number */
} image_lnno_entry_t;

#define N_UNDEF 0
#define N_ABS -1
#define N_DEBUG -2

#define C_EXT 2

#pragma pack(push,1)
typedef struct image_symbol_entry {
    union { /* symbol name or index to string table */
        char name[8];
        struct {
            uint32_t zeroes;
            uint32_t offset;
        } index;
    } s_name;
    int32_t n_value;    /* value of symbol */
    int16_t n_scnum;    /* section number */
    uint16_t n_type;    /* symbol type */
    uint8_t n_sclass;   /* storage class */
    uint8_t n_numaux;   /* auxiliary count */
} image_symbol_entry_t;
#pragma pack(pop)

int coff_load(uint8_t*);
/* stuff to get symbols */

extern uint32_t entry_point;

#endif /* _COFF_H_ */
