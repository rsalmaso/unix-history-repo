/*
 * Copyright (c) 1995 Andrew McRae.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * $Id: enabler.c,v 1.4 1996/04/18 04:24:53 nate Exp $
 */
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/ioctl.h>

#include <pccard/card.h>
#include <pccard/cis.h>

void    usage();

int
enabler_main(argc, argv)
	int     argc;
	char   *argv[];
{
	struct drv_desc drv;
	struct mem_desc mem;
	struct io_desc io;
	int     fd, slot, i, card_addr;
	char    name[32];
	char   *p;

	bzero(&drv, sizeof(drv));
	if (argc < 3)
		usage("arg count");
	slot = atoi(argv[1]);
	if (slot < 0 || slot >= MAXSLOT)
		usage("Illegal slot number");
	p = argv[2];
	while (*p && (*p < '0' || *p > '9'))
		p++;
	if (*p == 0)
		usage("No unit on device name");
	drv.unit = atoi(p);
	*p = 0;
	strcpy(drv.name, argv[2]);
	argv += 3;
	argc -= 3;
	while (argc > 1) {
		if (strcmp(argv[0], "-m") == 0) {
			if (argc < 4)
				usage("Memory argument error");
			if (sscanf(argv[1], "%x", &card_addr) != 1)
				usage("Bad card address");
			if (sscanf(argv[2], "%lx", &drv.mem) != 1)
				usage("Bad memory address");
			if (sscanf(argv[3], "%d", &i) != 1)
				usage("Bad memory size");
			drv.memsize = i * 1024;
			argc -= 2;
			argv += 2;
		} else if (strcmp(argv[0], "-f") == 0) {
			if (sscanf(argv[1], "%x", &drv.flags) != 1)
				usage("Bad driver flags");
		} else if (strcmp(argv[0], "-a") == 0) {
			if (sscanf(argv[1], "%x", &drv.iobase) != 1)
				usage("Bad I/O address");
		} else if (strcmp(argv[0], "-i") == 0) {
			if (sscanf(argv[1], "%d", &i) != 1 || i < 1 || i > 15)
				usage("Illegal IRQ");
			drv.irqmask = 1 << i;
		}
		argc -= 2;
		argv += 2;
	}
	if (argc)
		usage("no parameter for argument");
	printf("drv %s%d, mem 0x%lx, size %d, io %d, irq 0x%x, flags 0x%x\n",
		drv.name, drv.unit, drv.mem, drv.memsize, drv.iobase,
		drv.irqmask, drv.flags);
	sprintf(name, CARD_DEVICE, slot);
	fd = open(name, 2);
	if (fd < 0) {
		perror(name);
		exit(1);
	}

	/* Map the memory and I/O contexts. */
	if (drv.mem) {
		mem.window = 0;
		mem.flags = MDF_ACTIVE | MDF_16BITS;
		mem.start = (caddr_t)drv.mem;
		mem.size = drv.memsize;
		mem.card = card_addr;
		if (ioctl(fd, PIOCSMEM, &mem)) {
			perror("Set memory context");
			exit(1);
		}
	}
	if (drv.iobase) {
		io.window = 0;
		io.flags = IODF_ACTIVE | IODF_CS16;
		io.start = drv.iobase;
		io.size = 32;	/* Blah... */
		if (ioctl(fd, PIOCSIO, &io)) {
			perror("Set I/O context");
			exit(1);
		}
	}
	if (ioctl(fd, PIOCSDRV, &drv))
		perror("set driver");
	close(fd);
	return 0;
}

/*
 *	usage - print usage and exit
 */
void
usage(msg)
	char   *msg;
{
	fprintf(stderr, "enabler: %s\n", msg);
	fprintf(stderr,
	    "Usage: enabler slot driver [ -m addr size ] [ -a iobase ] [ -i irq ]\n");
	fprintf(stderr,
	    "    -m card addr size : Card address (hex), host address (hex) & size (Kb)\n");
	fprintf(stderr,
	    "    -a iobase         : I/O port address (hex)\n");
	fprintf(stderr,
	    "    -i irq            : Interrupt request number (1-15)\n");
	fprintf(stderr,
	    "   Example:  enabler 0 ed0 -m 2000 d4000 16 -a 300 -i 3\n");
	exit(1);
}
