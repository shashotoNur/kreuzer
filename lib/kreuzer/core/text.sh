# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# core/text.sh - string helpers for fixed-width terminal layout
#
# Depends on : nothing
# Provides   : trim pad rpad rep
# Out-vars   : TRIM PAD RP REP
#
# All helpers return through globals. The draw loop calls them hundreds of times
# per frame, and $(...) would fork each time.

# Unused leftover of the original script, kept until the cleanup in Stage 2.
printf -v SPACES '%*s' 400 ''

# Pure parameter expansion: no sed/xargs fork, and no surprises with backslashes.
trim() { local s=$1; s=${s#"${s%%[![:space:]]*}"}; s=${s%"${s##*[![:space:]]}"}; TRIM=$s; }

# Left-aligned, cut or padded to exactly w columns. printf -v builds the padding
# without a subshell.
pad() { local s=$1 w=$2 n sp; ((w < 0)) && w=0; s=${s:0:w}; n=$((w - ${#s})); PAD=$s
  if ((n > 0)); then printf -v sp '%*s' "$n" ''; PAD+=$sp; fi; }

# Right-aligned (for amounts). On overflow it keeps the right end of the text so
# the decimals stay visible.
rpad() { local s=$1 w=$2 n; ((${#s} > w)) && s=${s: -w}; n=$((w - ${#s})); RP=$s
  if ((n > 0)); then printf -v RP '%*s' "$n" ''; RP+=$s; fi; }

# Repeat a (possibly multibyte) character n times. Padding with spaces and then
# substituting is much cheaper than a loop, and works for characters like '─'.
rep() { local s n=$2; ((n < 0)) && n=0; printf -v s '%*s' "$n" ''; REP=${s// /$1}; }
