# Makefile for condrv(em).sys

ifeq ($(notdir $(CURDIR)),src)
$(error do not execute make in src directory)
endif

AS	= has
ASFLAGS	= -c4
LD	= hlk
CC	= gcc2
CFLAGS	= -O2
SHELL	= fish

EDFLAGS	=
EMFLAGS	= -s__EMACS -s__EM_FONT_CR -s__BUF_POS -s__TAG_JMP
#	  -s__XCONC -s__UPPER -s__BUF_POS -s__TAG_JMP
#	  -s__EM_FONT_TAB -s__EM_FONT_CR -s__EM_FONT

SRCS	= condrv.s condrv_help.txt condrv_help_em.txt dumphelp.c gm_internal.mac
DOCS	= bg.txt condrv.txt condrv_if.txt

MKHELP	= dumphelp.x

SRC_ZIP	 = src.zip
COND_ZIP = cond_e.zip
ARCS	= $(SRC_ZIP) $(COND_ZIP)


all: condrv.sys condrvem.sys

condrv.sys: condrv.o
	$(LD) -o $@ $^

condrv.o: condrv.s condrv_help.s
	$(AS) $(ASFLAGS) $(EDFLAGS) -o $@ condrv.s

condrv_help.s: condrv_help.txt $(MKHELP)
	rm -f $@
	./$(MKHELP) < condrv_help.txt > $@

condrvem.sys: condrvem.o
	$(LD) -o $@ $^

condrvem.o: condrv.s condrv_help_em.s
	$(AS) $(ASFLAGS) $(EMFLAGS) -o $@ condrv.s

condrv_help_em.s: condrv_help_em.txt $(MKHELP)
	rm -f $@
	./$(MKHELP) < condrv_help_em.txt > $@

$(MKHELP): dumphelp.c
	$(CC) $(CFLAGS) -o $@ $^


$(SRC_ZIP): $(SRCS) Makefile
	rm -f $@
	zip -9 $@ $^

$(COND_ZIP): $(SRC_ZIP) $(DOCS) condrv.sys condrvem.sys
	rm -f $@
	zip -9 $@ $^


# EOF