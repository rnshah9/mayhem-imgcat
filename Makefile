# Copyright (c) 2014–2019, Eddie Antonio Santos <easantos@ualberta.ca>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

# Outputs
BIN = imgcat
MAN = docs/imgcat.1

# Variables for installing
PREFIX = /usr/local
BINDIR = $(PREFIX)/bin
MANDIR = $(PREFIX)/share/man/man1

# Build
DISTRIBUTION = $(BIN)-$(PACKAGE_VERSION)
GENERATED_FILES = config.mk src/cimg_config.h src/config.h

# Generated by ./configure
include config.mk

# Compilation
# Determine supported standard
ifeq ($(CC),gcc)
CSTD = -std=c1x
CXXSTD = -std=c++0x
else
CSTD = -std=c11
CXXSTD = -std=c++11
endif

CFLAGS += $(CSTD) -Wall
CXXFLAGS += $(CXXSTD) -Wall

# the -M* options produce .d files in addition to .o files,
# to keep track of header dependencies (see: $(DEPS)).
OUTPUT_OPTION = -MMD -MP -o $@

# Use the C++ compiler to link, because we're using one C++ file!
LD = $(CXX)

# CImg requires pthread, for some reason
LDLIBS = $(LIBS) -ltermcap -lm -lpthread

# Get the source files.
SOURCES = $(wildcard src/*.c) $(wildcard src/*.cc)
OBJS = $(addsuffix .o,$(basename $(SOURCES)))
DEPS = $(OBJS:.o=.d)

################################ Phony rules #################################

.PHONY: all clean clean-all dist install test

all: $(BIN) $(MAN)

clean:
	$(RM) $(BIN) $(OBJS)

clean-all: clean
	$(RM) $(GENERATED_FILES)

dist: $(DISTRIBUTION).tar.gz

install: $(BIN) $(MAN)
	install -d $(BINDIR) $(MANDIR)
	install -s $(BIN) $(BINDIR)
	install -m 644 $(MAN) $(MANDIR)

test: $(BIN)
	tests/run $<


############################## Specific targets ##############################

# Create the main executable:
$(BIN): $(OBJS)
	$(LD) $(LDFLAGS) $^ $(LOADLIBES) $(LDLIBS) -o $@

# Use ./configure to generate all requisite files
$(GENERATED_FILES): configure VERSION
	./$<

# XXX: The CImg.h file uses arr['char'] as subscripts, which Clang doesn't
# like, so enable this flag JUST for the file that includes it!
src/load_image.o: CXXFLAGS+=-Wno-char-subscripts -I./CImg
src/load_image.o:

# Automatically clone CImg if not found:
CImg/CImg.h:
	git submodule update --init

$(DISTRIBUTION):
	mkdir -p $(DISTRIBUTION)/
	cp -r src Makefile configure README.md LICENSE VERSION $(DISTRIBUTION)/
	mkdir -p $(DISTRIBUTION)/CImg
	cp CImg/CImg.h $(DISTRIBUTION)/CImg/
	mkdir -p $(DISTRIBUTION)/docs
	cp $(MAN) $(DISTRIBUTION)/$(MAN)

$(DISTRIBUTION).tar.gz: $(DISTRIBUTION)
	tar czvf $@ $^

.PHONY: $(DISTRIBUTION)

# Dependency files (generated by -M in compilation)
-include $(DEPS)

############################### Pattern rules ################################

%.1: %.1.md
	$(PANDOC) --standalone --to=man $(PANDOCFLAGS) \
		-Vdate='$(shell date +'%B %d, %Y')' $< -o $@
