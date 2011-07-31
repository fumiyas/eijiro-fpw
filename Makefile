#
# Makefile for FreePWING version of EIJIRO
# $Id: Makefile 1.0.0.3 2000/10/08 14:40:51 rei Exp $
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
EIJIROVER = 37
SRCDIR = .
SRCFILE := $(wildcard ${SRCDIR}/EIJI${EIJIROVER}??.TXT)
#SRCFILE = test.txt

#
# NKF:
# kanji-code convertor to generate the catalogs.txt file. if not specified,
# catalogs.sjis is copied to catalogs.txt as it is. so leave this variable
# undefined on Windows.
#
#NKF = nkf -eSd

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
PACKAGE = eijiro-fpw1.0b
ARCHIVEEXTRA = readme.sjis copyright.sjis COPYING ${CATSRC}
CLEANEXTRA = catalogs.txt
DIR = eijiro

FPWPARSER = eijiro-fpw.pl
FPWPARSERFLAGS = -- --charset=${CHARSET} ${SRCFILE}

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

catalogs.txt: ${CATSRC}
	rm -f $@
ifdef NKF
	${NKF} ${CATSRC} > catalogs.txt
else
	cp ${CATSRC} catalogs.txt
endif

# EOF
