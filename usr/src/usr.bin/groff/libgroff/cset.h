// -*- C++ -*-
/* Copyright (C) 1989, 1990 Free Software Foundation, Inc.
     Written by James Clark (jjc@jclark.uucp)

This file is part of groff.

groff is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any later
version.

groff is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License along
with groff; see the file LICENSE.  If not, write to the Free Software
Foundation, 675 Mass Ave, Cambridge, MA 02139, USA. */

#ifndef UCHAR_MAX
#define UCHAR_MAX 255
#endif

enum cset_builtin { CSET_BUILTIN };

class cset {
public:
  cset();
  cset(cset_builtin);
  cset(const char *);
  cset(const unsigned char *);
  int operator()(unsigned char) const;

  cset &operator|=(const cset &);
  cset &operator|=(unsigned char);

  friend class cset_init;
private:
  char v[UCHAR_MAX+1];
  void clear();
};

inline int cset::operator()(unsigned char c) const
{
  return v[c];
}

inline cset &cset::operator|=(unsigned char c)
{
  v[c] = 1;
  return *this;
}

extern cset csalpha;
extern cset csupper;
extern cset cslower;
extern cset csdigit;
extern cset csxdigit;
extern cset csspace;
extern cset cspunct;
extern cset csalnum;
extern cset csprint;
extern cset csgraph;
extern cset cscntrl;

static class cset_init {
  static int initialised;
public:
  cset_init();
} _cset_init;
