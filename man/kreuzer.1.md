---
title: KREUZER
section: 1
header: User Commands
---

# NAME

kreuzer - income, expense and budget tracker for the terminal

# SYNOPSIS

**kreuzer** [*command*]

# DESCRIPTION

**kreuzer** is a full-screen terminal application for recording income and expenses across several wallets, tracking category quotas and a monthly budget, and visualising them with charts. Data is stored as plain tab-separated files, one per month.

Without a command it starts the interactive interface. Press **?** inside it for the key list.

# COMMANDS

**export** [*YYYY-MM*]
:   Print a month as CSV on standard output. Defaults to the current month. Expenses and outgoing transfers are negative.

**backup**
:   Write a timestamped `.tar.gz` of the data directory next to it and print its path.

**\--dump-keys**
:   Print the key bindings in effect, in configuration file syntax.

**\--check**
:   Verify required tools and show the configuration and data paths.

**-V**, **\--version**
:   Print the version.

**-h**, **\--help**
:   Print a short usage text.

# FILES

*~/.config/kreuzer/kreuzer.conf*
:   Settings (`[general]`) and key bindings (`[keys]`). Created on first run. `$XDG_CONFIG_HOME` is honoured.

*~/Documents/kreuzer/*
:   Data directory, changeable with `data_dir` in the configuration. Holds one `YYYY-MM.tsv` file per month, a `meta/` directory, and a lock file.

# ENVIRONMENT

**NO_COLOR**
:   When set and non-empty, colours are disabled and chart slices use distinct glyphs.

**XDG_CONFIG_HOME**
:   Base directory for the configuration file.

**KREUZER_LIBDIR**
:   Override the library directory (development and tests).

# CONFIGURATION

The `[general]` section accepts `data_dir`, `currency`, `currency_pos` (`prefix` or `suffix`), `thousands`, `decimal`, `pie_aspect` (terminal cell height divided by width, usually 2.0) and `auto_purge_days` (0 disables). The `[keys]` section maps each action to one or more comma-separated keys. Two actions bound to the same key are rejected at startup.

# EXIT STATUS

**0** on success, **1** on an error such as a missing dependency, an invalid configuration, or a data directory already in use by another instance.

# REQUIREMENTS

bash 4.4 or newer, GNU awk, coreutils, util-linux, findutils, grep and tar. A UTF-8 terminal with truecolor support, at least 70 columns by 20 rows.

# SEE ALSO

The documentation in */usr/share/doc/kreuzer* (architecture, data format and key bindings).
