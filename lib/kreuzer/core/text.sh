# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# core/text.sh - string helpers for fixed-width terminal layout
#
# Provides : text_trim text_pad text_rpad text_repeat
# Out-vars : TRIM PAD RP REP
#
# Results come back through globals: the draw loop calls these hundreds of times
# per frame, and $(...) would fork each time.

# Parameter expansion only: no sed fork, no trouble with backslashes.
text_trim() { local s=$1; s=${s#"${s%%[![:space:]]*}"}; s=${s%"${s##*[![:space:]]}"}; TRIM=$s; }

# Left-aligned, cut or padded to exactly w columns.
text_pad() { local s=$1 w=$2 n sp; ((w < 0)) && w=0; s=${s:0:w}; n=$((w - ${#s})); PAD=$s
  if ((n > 0)); then printf -v sp '%*s' "$n" ''; PAD+=$sp; fi; }

# Right-aligned. On overflow the right end is kept, so decimals stay visible.
text_rpad() { local s=$1 w=$2 n; ((${#s} > w)) && s=${s: -w}; n=$((w - ${#s})); RP=$s
  if ((n > 0)); then printf -v RP '%*s' "$n" ''; RP+=$s; fi; }

# Spaces then substitution is cheaper than a loop and handles multibyte
# characters such as the box-drawing rule.
text_repeat() { local s n=$2; ((n < 0)) && n=0; printf -v s '%*s' "$n" ''; REP=${s// /$1}; }
