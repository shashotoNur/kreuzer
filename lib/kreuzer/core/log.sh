# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# core/log.sh - fatal error reporting
#
# Depends on : $APP (set by main.sh)
# Provides   : die

# exit, not return: die is only used for startup and configuration errors,
# where continuing would run on half-initialised state. If the UI is already
# up, the EXIT trap from ui/term restores the screen.
die() { printf '%s: %s\n' "$APP" "$*" >&2; exit 1; }
