/*
 * Copyright (c) 1988 Mark Nudleman
 * Copyright (c) 1988 Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms are permitted
 * provided that the above copyright notice and this paragraph are
 * duplicated in all such forms and that any documentation,
 * advertising materials, and other materials related to such
 * distribution and use acknowledge that the software was developed
 * by Mark Nudleman and the University of California, Berkeley.  The
 * name of Mark Nudleman or the
 * University may not be used to endorse or promote products derived
 * from this software without specific prior written permission.
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
 * WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 */

#ifndef lint
char copyright[] =
"@(#) Copyright (c) 1988 Mark Nudleman.\n\
@(#) Copyright (c) 1988 Regents of the University of California.\n\
 All rights reserved.\n";
#endif /* not lint */

#ifndef lint
static char sccsid[] = "@(#)main.c	5.8 (Berkeley) %G%";
#endif /* not lint */

/*
 * Entry point, initialization, miscellaneous routines.
 */

#include "less.h"
#include "position.h"

public int	ispipe;
public char *	first_cmd;
public char *	every_first_cmd;
public int	new_file;
public int	is_tty;
public char 	*current_file;
public char 	*previous_file;
public POSITION	prev_pos;
public int	any_display;
public int	scroll;
public int	ac;
public char **	av;
public int 	curr_ac;
public int	quitting;

extern int	file;
extern int	quit_at_eof;
extern int	cbufs;
extern int	errmsgs;

extern char *	tagfile;
extern char *	tagpattern;
extern int	tagoption;

/*
 * Edit a new file.
 * Filename "-" means standard input.
 * No filename means the "current" file, from the command line.
 */
	public void
edit(filename)
	register char *filename;
{
	register int f;
	register char *m;
	POSITION initial_pos;
	char message[100];
	static int didpipe;

	initial_pos = NULL_POSITION;
	if (filename == NULL || *filename == '\0')
	{
		if (curr_ac >= ac)
		{
			error("No current file");
			return;
		}
		filename = save(av[curr_ac]);
	} else if (strcmp(filename, "#") == 0)
	{
		if (*previous_file == '\0')
		{
			error("no previous file");
			return;
		}
		filename = save(previous_file);
		initial_pos = prev_pos;
	} else
		filename = save(filename);

	if (strcmp(filename, "-") == 0)
	{
		/* 
		 * Use standard input.
		 */
		if (didpipe)
		{
			error("Can view standard input only once");
			return;
		}
		f = 0;
	} else if ((m = bad_file(filename, message, sizeof(message))) != NULL)
	{
		error(m);
		free(filename);
		return;
	} else if ((f = open(filename, 0)) < 0)
	{
		error(errno_message(filename, message, sizeof(message)));
		free(filename);
		return;
	}

	if (isatty(f))
	{
		/*
		 * Not really necessary to call this an error,
		 * but if the control terminal (for commands)
		 * and the input file (for data) are the same,
		 * we get weird results at best.
		 */
		error("Can't take input from a terminal");
		if (f > 0)
			close(f);
		free(filename);
		return;
	}

	/*
	 * We are now committed to using the new file.
	 * Close the current input file and set up to use the new one.
	 */
	if (file > 0)
		close(file);
	new_file = 1;
	if (previous_file != NULL)
		free(previous_file);
	previous_file = current_file;
	current_file = filename;
	prev_pos = position(TOP);
	ispipe = (f == 0);
	if (ispipe)
		didpipe = 1;
	file = f;
	ch_init(cbufs, 0);
	init_mark();

	if (every_first_cmd != NULL)
		first_cmd = every_first_cmd;

	if (is_tty)
	{
		int no_display = !any_display;
		any_display = 1;
		if (no_display && errmsgs > 0)
		{
			/*
			 * We displayed some messages on error output
			 * (file descriptor 2; see error() function).
			 * Before erasing the screen contents,
			 * display the file name and wait for a keystroke.
			 */
			error(filename);
		}
		/*
		 * Indicate there is nothing displayed yet.
		 */
		pos_clear();
		if (initial_pos != NULL_POSITION)
			jump_loc(initial_pos);
		clr_linenum();
	}
}

/*
 * Edit the next file in the command line list.
 */
	public void
next_file(n)
	int n;
{
	if (curr_ac + n >= ac)
	{
		if (quit_at_eof)
			quit();
		error("No (N-th) next file");
	} else
		edit(av[curr_ac += n]);
}

/*
 * Edit the previous file in the command line list.
 */
	public void
prev_file(n)
	int n;
{
	if (curr_ac - n < 0)
		error("No (N-th) previous file");
	else
		edit(av[curr_ac -= n]);
}

/*
 * Copy a file directly to standard output.
 * Used if standard output is not a tty.
 */
	static void
cat_file()
{
	register int c;

	while ((c = ch_forw_get()) != EOI)
		putchr(c);
	flush();
}

/*
 * Entry point.
 */
main(argc, argv)
	int argc;
	char *argv[];
{
	char *getenv();


	/*
	 * Process command line arguments and LESS environment arguments.
	 * Command line arguments override environment arguments.
	 */
	init_prompt();
	init_option();
	scan_option(getenv("LESS"));
	argv++;
	while ( (--argc > 0) && 
		(argv[0][0] == '-' || argv[0][0] == '+') && 
		argv[0][1] != '\0')
		scan_option(*argv++);

	/*
	 * Set up list of files to be examined.
	 */
	ac = argc;
	av = argv;
	curr_ac = 0;

	/*
	 * Set up terminal, etc.
	 */
	is_tty = isatty(1);
	if (!is_tty)
	{
		/*
		 * Output is not a tty.
		 * Just copy the input file(s) to output.
		 */
		if (ac < 1)
		{
			edit("-");
			cat_file();
		} else
		{
			do
			{
				edit((char *)NULL);
				if (file >= 0)
					cat_file();
			} while (++curr_ac < ac);
		}
		exit(0);
	}

	raw_mode(1);
	get_term();
	open_getchr();
	init();
	init_cmd();

	init_signals(1);

	/*
	 * Select the first file to examine.
	 */
	if (tagoption)
	{
		/*
		 * A -t option was given.
		 * Verify that no filenames were also given.
		 * Edit the file selected by the "tags" search,
		 * and search for the proper line in the file.
		 */
		if (ac > 0)
		{
			error("No filenames allowed with -t option");
			quit();
		}
		if (tagfile == NULL)
			quit();
		edit(tagfile);
		if (file < 0)
			quit();
		if (tagsearch())
			quit();
	} else
	if (ac < 1)
		edit("-");	/* Standard input */
	else 
	{
		/*
		 * Try all the files named as command arguments.
		 * We are simply looking for one which can be
		 * opened without error.
		 */
		do
		{
			edit((char *)NULL);
		} while (file < 0 && ++curr_ac < ac);
	}

	if (file >= 0)
		commands();
	quit();
	/*NOTREACHED*/
}

/*
 * Copy a string, truncating to the specified length if necessary.
 * Unlike strncpy(), the resulting string is guaranteed to be null-terminated.
 */
	public void
strtcpy(to, from, len)
	char *to;
	char *from;
	unsigned int len;
{
	strncpy(to, from, len);
	to[len-1] = '\0';
}

/*
 * Copy a string to a "safe" place
 * (that is, to a buffer allocated by malloc).
 */
	public char *
save(s)
	char *s;
{
	char *p, *strcpy(), *malloc();

	p = malloc((u_int)strlen(s)+1);
	if (p == NULL)
	{
		error("cannot allocate memory");
		quit();
	}
	return(strcpy(p, s));
}

/*
 * Exit the program.
 */
	public void
quit()
{
	/*
	 * Put cursor at bottom left corner, clear the line,
	 * reset the terminal modes, and exit.
	 */
	quitting = 1;
	lower_left();
	clear_eol();
	deinit();
	flush();
	raw_mode(0);
	exit(0);
}
