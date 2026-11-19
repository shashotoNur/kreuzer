# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# core/log.sh - fatal error reporting
#
# Provides : log_die

# Exits instead of returning: only used for startup and configuration errors,
# where continuing would run on half-initialised state.
log_die() { printf '%s: %s\n' "$APP" "$*" >&2; exit 1; }
