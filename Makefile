#
# Makefile for FreePWING version of EIJIRO
#
# this makefile is designed for GNU make.
# copyright (c) 2000, Rei <rei@wdic.org>. all rights reserved.
#

#
# customizable values.
# pls change to fit your environment or as you like.
#

#
# EIJIROVER, SRCDIR, SRCFILE:
# the EIJIRO files to be converted.
#
EIJIROVER = 130
SRCDIR = .
SRCFILE := ${SRCDIR}/EIJI-${EIJIROVER}.TXT
#SRCFILE = test.txt

#
# CHARSET:
# specify the charset for the output strings. it is just used to print
# progress. if not specified, 'sjis' is used on Windows or 'euc' on other
# environment. possible charsets are same as Jcode.pm.
#
#CHARSET = euc

#
# end of customizable variables.
#

CATSRC = catalogs.sjis
PACKAGE = eijiro-fpw-1.1
ARCHIVEEXTRA = readme.txt copyright.txt COPYING ChangeLog ${CATSRC}
CLEANEXTRA =
DIR = eijiro

FPWPARSER = eijiro-fpw.pl
FPWPARSERFLAGS = -c "${CHARSET}" "${SRCFILE}"

# fpwutils.mk must be located in one of the make include directories or
# you should user -I option.
include fpwutils.mk

#
# define other targets.
#
package:
	@echo
	@echo You cannot redistribute EIJIRO, so target \'package\' is disabled.
	@echo

