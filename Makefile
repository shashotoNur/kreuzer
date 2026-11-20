# kreuzer - check, test, build, install

NAME    := kreuzer
VERSION := $(shell sed -n 's/^VERSION="\(.*\)"$$/\1/p' lib/$(NAME)/main.sh)
PREFIX  ?= /usr/local
DESTDIR ?=
BINDIR  := $(DESTDIR)$(PREFIX)/bin
LIBDIR  := $(DESTDIR)$(PREFIX)/lib/$(NAME)
MANDIR  := $(DESTDIR)$(PREFIX)/share/man/man1
DOCDIR  := $(DESTDIR)$(PREFIX)/share/doc/$(NAME)
SOURCES := bin/$(NAME) $(shell find lib tools -name '*.sh' | sort)

SHELL := bash
# Recipes start with '>' instead of a tab: editors and copy-paste silently turn
# tabs into spaces, which breaks make with a confusing error.
.RECIPEPREFIX := >

.PHONY: check test dist man install uninstall clean

# SC2154/SC2034 are disabled because modules deliberately share globals
# (out-variables), which shellcheck cannot follow across files.
check:
> @for f in $(SOURCES) tests/*.sh; do bash -n "$$f" || exit 1; done; echo "syntax ok: $(words $(SOURCES)) files"
> @if command -v shellcheck >/dev/null; then shellcheck -x -S warning -e SC2154,SC2034 $(SOURCES); else echo "shellcheck not found, skipped"; fi

test:
> @if command -v bats >/dev/null; then bats tests/bats; \
>  else echo "bats not found, running smoke tests only"; \
>  for t in tests/smoke_*.sh; do bash "$$t" >/dev/null || { echo "FAILED: $$t"; exit 1; }; echo "ok $$t"; done; fi

# One standalone script, for sharing or copying onto a machine without the tree.
dist:
> bash tools/dist.sh dist/$(NAME)
> @echo "built dist/$(NAME) ($(VERSION))"

# The generated page is committed, so building a package needs no pandoc.
man: man/$(NAME).1

man/$(NAME).1: man/$(NAME).1.md lib/$(NAME)/main.sh
> @command -v pandoc >/dev/null || { echo "pandoc not found: sudo pacman -S pandoc"; exit 1; }
> pandoc -s -t man -M footer="$(NAME) $(VERSION)" man/$(NAME).1.md -o $@

install:
> install -Dm755 bin/$(NAME) "$(BINDIR)/$(NAME)"
> cd lib/$(NAME) && find . -name '*.sh' -exec install -Dm644 {} "$(LIBDIR)/{}" \;
> if [ -f man/$(NAME).1 ]; then install -Dm644 man/$(NAME).1 "$(MANDIR)/$(NAME).1"; fi
> install -Dm644 README.md "$(DOCDIR)/README.md"
> install -Dm644 docs/architecture.md "$(DOCDIR)/architecture.md"
> install -Dm644 docs/data-format.md "$(DOCDIR)/data-format.md"
> install -Dm644 docs/keybindings.md "$(DOCDIR)/keybindings.md"

uninstall:
> rm -f "$(BINDIR)/$(NAME)" "$(MANDIR)/$(NAME).1"
> rm -rf "$(LIBDIR)" "$(DOCDIR)"

clean:
> rm -rf dist
