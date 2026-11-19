# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# ui/theme.sh - colour palette (soft pastels) and NO_COLOR handling
#
# Depends on : nothing
# Globals    : RST BOLD C_* BG_SEL PAL GRAYC NOCOL
#
# All colours are truecolor escapes. Every other module uses these names and
# never writes a raw escape for colour, so the palette can be changed in one place.

RST=$'\e[0m'; BOLD=$'\e[1m'

# Per https://no-color.org: any non-empty NO_COLOR disables colour. Selection
# falls back to reverse video so it stays visible.
NOCOL=0
if [[ -n ${NO_COLOR:-} ]]; then
  NOCOL=1
  C_TXT= C_DIM= C_ACC= C_OK= C_WARN= C_BAD= C_INC= C_EXP= C_XFR=; BG_SEL=$'\e[7m'
else
  C_TXT=$'\e[38;2;205;210;222m'; C_DIM=$'\e[38;2;122;128;146m'; C_ACC=$'\e[38;2;150;190;232m'
  C_OK=$'\e[38;2;168;218;168m'; C_WARN=$'\e[38;2;236;204;146m'; C_BAD=$'\e[38;2;236;156;156m'
  C_INC=$C_OK; C_EXP=$C_BAD; C_XFR=$'\e[38;2;178;170;230m'; BG_SEL=$'\e[48;2;52;60;80m'
fi

# Chart slice colours as "R;G;B" strings so they can go straight into escapes
# built by awk. GRAYC marks DELETED categories.
PAL=("240;160;160" "244;196;150" "238;222;150" "182;220;165" "150;212;200" "150;190;232"
  "190;172;232" "232;172;208" "208;190;165" "168;200;196" "200;204;232" "226;200;200")
GRAYC="150;150;160"
