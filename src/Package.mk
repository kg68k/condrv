# Makefile for condrv (create archive file)
#  usage: mkdir pkgtmp; make -C pkgtmp -f ../Package.mk

SRCDIR_MK = ../../srcdir.mk
SRC_DIR = ../../src
-include $(SRCDIR_MK)

ROOT_DIR = $(SRC_DIR)/..
BUILD_DIR = ..

CP_P = cp -p
U8TOSJ = u8tosj

COND_ZIP = $(BUILD_DIR)/cond_e.zip

DOCS = bg.txt condrv.txt condrv_if.txt CHANGELOG.txt

PROGRAM = condrv.sys condrvem.sys

FILES = $(DOCS) $(PROGRAM)

.PHONY: all

all: $(COND_ZIP)

CHANGELOG.txt: $(ROOT_DIR)/CHANGELOG.md
	$(U8TOSJ) < $^ >! $@

%.txt: $(ROOT_DIR)/%.txt
	$(U8TOSJ) < $^ >! $@

%.sys: $(BUILD_DIR)/%.sys
	rm -f $@
	$(CP_P) $^ $@

$(COND_ZIP): $(FILES)
	rm -f $@
	zip -9 $@ $^


# EOF
