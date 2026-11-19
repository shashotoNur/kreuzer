# kreuzer - check, install, uninstall (test and dist targets arrive in Stage 3)

NAME    := kreuzer
PREFIX  ?= /usr/local
DESTDIR ?=
BINDIR  := $(DESTDIR)$(PREFIX)/bin
LIBDIR  := $(DESTDIR)$(PREFIX)/lib/$(NAME)
SOURCES := bin/$(NAME) $(shell find lib -name '*.sh' | sort)

# Recipes start with '>' instead of a tab: tabs are silently converted to spaces
# by many editors and by copy-paste, which breaks make with a confusing error.
.RECIPEPREFIX := >

.PHONY: check install uninstall

# SC2154/SC2034 are disabled because modules deliberately share globals
# (out-variables), which shellcheck cannot see across files.
check:
> @for f in $(SOURCES); do bash -n "$$f" || exit 1; done; echo "syntax ok: $(words $(SOURCES)) files"
> @if command -v shellcheck >/dev/null; then shellcheck -x -S warning -e SC2154,SC2034 $(SOURCES); else echo "shellcheck not found, skipped"; fi

install:
> install -Dm755 bin/$(NAME) "$(BINDIR)/$(NAME)"
> cd lib/$(NAME) && find . -name '*.sh' -exec install -Dm644 {} "$(LIBDIR)/{}" \;

uninstall:
> rm -f "$(BINDIR)/$(NAME)"
> rm -rf "$(LIBDIR)"
