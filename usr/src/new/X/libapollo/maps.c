#ifndef lint
static char *rcsid_maps_c = "$Header: maps.c,v 10.1 86/11/29 13:52:20 jg Rel $";
#endif	lint
/* Copyright 1985, Massachusetts Institute of Technology */

/* foreground/background map */

char FBMap[] = {0x0, 0x0, 0x0, 0x0, 0x5, 0x5, 0x5, 0x5,
		0xa, 0xa, 0xa, 0xa, 0xf, 0xf, 0xf, 0xf,

		0x0, 0x4, 0x8, 0xc, 0x1, 0x5, 0x9, 0xd,
		0x2, 0x6, 0xa, 0xe, 0x3, 0x7, 0xb, 0xf,

		0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7,
		0x8, 0x9, 0xa, 0xb, 0xc, 0xd, 0xe, 0xf,

		0x0, 0x5, 0xa, 0xf, 0x0, 0x5, 0xa, 0xf,
		0x0, 0x5, 0xa, 0xf, 0x0, 0x5, 0xa, 0xf};

/* single source map */

char SSMap[] = {0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7,
		0x8, 0x9, 0xa, 0xb, 0xc, 0xd, 0xe, 0xf,

		0x0, 0x4, 0x8, 0xc, 0x1, 0x5, 0x9, 0xd,
		0x2, 0x6, 0xa, 0xe, 0x3, 0x7, 0xb, 0xf};
