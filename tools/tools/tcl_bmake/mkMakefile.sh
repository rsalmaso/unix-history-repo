#! /bin/sh
# $Id: mkMakefile.sh,v 1.9 1996/09/05 19:05:57 peter Exp $
#
# This script generates a bmake Makefile for src/lib/libtcl
#

set -ex

# SETME: what versions the  shared library should have.
SHLIB_MAJOR=75
SHLIB_MINOR=0

# SETME: where is the tcl stuff relative to this script
SRCDIR=../../../contrib/tcl

# SETME: where is the tcl stuff relative to src/lib/libtcl
LIBTCL=../../../lib/libtcl/

mkdir -p ${LIBTCL}

(cd ${SRCDIR}/unix ; sh configure --enable-shared --prefix=/usr) || true

echo "include ${SRCDIR}/unix/Makefile" > m.x
echo '
foo:
	@echo ${OBJS}
bar:
	@echo ${AC_FLAGS}
' >> m.x

# Put a RCS Id  in the file, but not the one from this file :-)
echo -n '# $' > ${LIBTCL}Makefile
echo -n 'Id' >> ${LIBTCL}Makefile
echo '$' >> ${LIBTCL}Makefile

# Tell 'em !
echo '#
# This file is generated automatically, do not edit it here!
#
# Please change src/tools/tools/tcl_bmake/mkMakefile.sh instead
#
# Generated by src/tools/tools/tcl_bmake/mkMakefile.sh version:
# $Id: mkMakefile.sh,v 1.9 1996/09/05 19:05:57 peter Exp $
#
' | tr -d '$' >> ${LIBTCL}Makefile

# Tell make(1) to pick up stuff from here
echo 'TCLDIST=${.CURDIR}/../../contrib/tcl' >> ${LIBTCL}Makefile

echo  >> ${LIBTCL}Makefile

echo '.PATH: ${TCLDIST}/generic' >> ${LIBTCL}Makefile
echo '.PATH: ${TCLDIST}/unix' >> ${LIBTCL}Makefile
echo '.PATH: ${TCLDIST}/doc' >> ${LIBTCL}Makefile

echo  >> ${LIBTCL}Makefile

# Tell cpp(1) to pick up stuff from here
echo 'CFLAGS+=  -I${TCLDIST}/generic' >> ${LIBTCL}Makefile
echo 'CFLAGS+=  -I${TCLDIST}/unix' >> ${LIBTCL}Makefile

echo  >> ${LIBTCL}Makefile

# Pick up some more global info
echo "TCL_LIBRARY=	/usr/libdata/tcl" >> ${LIBTCL}Makefile
echo "SHLIB_MAJOR=	${SHLIB_MAJOR}"     >> ${LIBTCL}Makefile
echo "SHLIB_MINOR=	${SHLIB_MINOR}"     >> ${LIBTCL}Makefile

# Set the name of the library
echo '
LIB=    tcl

.if !defined(NOPIC)
LINKS+=	${SHLIBDIR}/lib${LIB}.so.${SHLIB_MAJOR}.${SHLIB_MINOR} \
	${SHLIBDIR}/lib${LIB}${SHLIB_MAJOR}.so.1.0
.endif
LINKS+=	${LIBDIR}/lib${LIB}.a ${LIBDIR}/lib${LIB}${SHLIB_MAJOR}.a
' >> ${LIBTCL}Makefile

# some needed CFLAGS
echo "CFLAGS+=" `make -f m.x bar` >> ${LIBTCL}Makefile

# some more needed CFLAGS
echo "CFLAGS+=	-DTCL_LIBRARY=\\\"\${TCL_LIBRARY}\\\"" >> ${LIBTCL}Makefile

echo '
LDADD+= -lm
DPADD+= ${LIBM}
' >>  ${LIBTCL}Makefile

# The sources
make -f m.x foo | fmt 60 65 | sed '
s/^/	/
s/$/ \\/
s/\.o/.c/g
1s/	/SRCS=	/
$s/ \\$//
' >> ${LIBTCL}Makefile

echo '
HEADERS=generic/patchlevel.h generic/tclInt.h generic/tclPort.h \
	generic/tclRegexp.h unix/tclUnixPort.h

beforeinstall:
	${INSTALL} -C -o ${BINOWN} -g ${BINGRP} -m 444 \
		${TCLDIST}/generic/tcl.h ${DESTDIR}/usr/include
	${INSTALL} -c -o ${BINOWN} -g ${BINGRP} -m 444 \
		${TCLDIST}/library/[a-z]* ${DESTDIR}${TCL_LIBRARY}
	${INSTALL} -c -o ${BINOWN} -g ${BINGRP} -m 444 \
		${TCLDIST}/unix/tclAppInit.c ${DESTDIR}${TCL_LIBRARY}
	${INSTALL} -c -o ${BINOWN} -g ${BINGRP} -m 444 \
		${TCLDIST}/doc/man.macros ${DESTDIR}/usr/share/tmac/tcl.macros
	${INSTALL} -c -o ${BINOWN} -g ${BINGRP} -m 444 \
		${.CURDIR}/tclConfig.sh ${DESTDIR}${TCL_LIBRARY}
.for m in ${HEADERS}
	${INSTALL} -C -o ${BINOWN} -g ${BINGRP} -m 444 ${TCLDIST}/$m \
		${DESTDIR}/usr/include/tcl/$m
.endfor


MANFILTER=sed "/\.so *man.macros/s;.*;.so /usr/share/tmac/tcl.macros;"
' >> ${LIBTCL}Makefile

# The (n) manpages
(cd ${SRCDIR}/doc; echo *.n) | fmt 60 65 | sed '
s/^/	/
s/$/ \\/
1s/	/MANn+=	/
$s/ \\$//
' >> ${LIBTCL}Makefile

echo  >>  ${LIBTCL}Makefile

# The (3) manpages
for i in ${SRCDIR}/doc/*.3
do
	sed '
	1,/^.SH NAME/d
	/^.SH SYNOPSIS/,$d
	' $i | sed -n '
	1s/[, \\].*/.3/p
	'
done | fmt 60 65 | sed '
s/^/	/
s/$/ \\/
1s/	/MAN3+=	/
$s/ \\$//
' >> ${LIBTCL}Makefile

echo  >>  ${LIBTCL}Makefile

for i in ${SRCDIR}/doc/*.3
do
	sed '
	1,/^.SH NAME/d
	/^.SH SYNOPSIS/,$d
	s/,//g
	' $i | sed -n '
	1s/\\-.*//p
	' | awk '
		{
		for (i = 2 ; i <= NF ; i++)
			print "MLINKS+= " $1 ".3 " $i ".3 "
		}
	' >> ${LIBTCL}Makefile
done

echo '
# Ugly, I know, but what else can I do?!?
' >> ${LIBTCL}Makefile

for i in ${SRCDIR}/doc/*.3
do
	sed '
	1,/^.SH NAME/d
	/^.SH SYNOPSIS/,$d
	s/,//g
	' $i | sed -n '
	1s/\\-.*//p
	' | awk '
		{
		print ""
		print $1 ".3: ${TCLDIST}/doc/" B  ".3"
		print "\tln -s \${.ALLSRC} \${.TARGET}"
		}
        ' B=`basename $i .3` >> ${LIBTCL}Makefile
done

echo '

.include <bsd.lib.mk>
' >> ${LIBTCL}Makefile

sed -e '/^TCL.*_LIB_SPEC=/s/-L.* //' < ${SRCDIR}/unix/tclConfig.sh > ${LIBTCL}/tclConfig.sh

rm -f m.x ${SRCDIR}/unix/config.log ${SRCDIR}/unix/Makefile ${SRCDIR}/unix/config.cache ${SRCDIR}/unix/config.status ${SRCDIR}/unix/tclConfig.sh


