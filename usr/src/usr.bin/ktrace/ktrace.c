/*
 * Copyright (c) 1988 The Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms are permitted
 * provided that the above copyright notice and this paragraph are
 * duplicated in all such forms and that any documentation,
 * advertising materials, and other materials related to such
 * distribution and use acknowledge that the software was developed
 * by the University of California, Berkeley.  The name of the
 * University may not be used to endorse or promote products derived
 * from this software without specific prior written permission.
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
 * WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 */

#ifndef lint
char copyright[] =
"@(#) Copyright (c) 1988 The Regents of the University of California.\n\
 All rights reserved.\n";
#endif /* not lint */

#ifndef lint
static char sccsid[] = "@(#)ktrace.c	1.1 (Berkeley) %G%";
#endif /* not lint */

/*#include <time.h>*/
#include <sys/param.h>
#include <sys/file.h>
#include <sys/dir.h>
#include <sys/user.h>
#include <sys/ktrace.h>
#include <stdio.h>

main(argc, argv)
	char *argv[];
{
	extern int optind;
	extern char *optarg;
	int ops = 0;
	int facs = KTRFAC_SYSCALL | KTRFAC_SYSRET | KTRFAC_NAMEI;
	int pid;
	int ch;

	while ((ch = getopt(argc,argv,"cp:g:i")) != EOF)
		switch((char)ch) {
			case 'c':
				ops |= KTROP_CLEARFILE;
				break;
			case 'p':
				pid = atoi(optarg);
				break;
			case 'g':
				pid = -atoi(optarg);
				break;
			case 'i':
				ops |= KTROP_INHERITFLAG;
				break;
			default:
				fprintf(stderr,"usage: \n",*argv);
				exit(-1);
		}
	argv += optind, argc -= optind;
	
	if ((ops&0x3) == KTROP_CLEARFILE) {
		ktrace("trace.out", ops, facs, -1);
		exit(0);
	}
	open("trace.out", O_WRONLY|O_CREAT, 0777);
	if (!*argv) {
		if (ktrace("trace.out", ops, facs, pid) < 0) {
			perror("ktrace");
			exit(1);
		}
	} else {
		pid = getpid();
		if (ktrace("trace.out", ops, facs, pid) < 0) {
			perror("ktrace");
			exit(1);
		}
		execvp(argv[0], &argv[0]);
		perror("ktrace: exec failed");
	}

	exit(0);
}
