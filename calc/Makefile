SRCDIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PLUGINDIR ?= $(HOME)/.local/lib/rofi
SCRIPT ?= $(SRCDIR)/sleek_calc.py
CC ?= gcc
CFLAGS ?= -O2 -g
PKGS := rofi glib-2.0 gmodule-2.0 cairo
override CFLAGS += -std=gnu11 -Wall -Wextra -fPIC $(shell pkg-config --cflags $(PKGS))
LDLIBS += $(shell pkg-config --libs glib-2.0 gmodule-2.0) -pthread

all: $(SRCDIR)/sleekcalc.so

$(SRCDIR)/sleekcalc.so: $(SRCDIR)/rofi-sleek-calc.c
	$(CC) $(CFLAGS) -DSLEEK_CALC_SCRIPT='"$(SCRIPT)"' -shared -o $@ $< $(LDFLAGS) $(LDLIBS)

install: $(SRCDIR)/sleekcalc.so
	install -d $(PLUGINDIR)
	install -m 0755 $(SRCDIR)/sleekcalc.so $(PLUGINDIR)/sleekcalc.so

uninstall:
	rm -f $(PLUGINDIR)/sleekcalc.so

clean:
	rm -f $(SRCDIR)/sleekcalc.so

.PHONY: all install uninstall clean
