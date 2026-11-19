# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# ui/state.sh - mutable application state shared by screens, forms and drawing
#
# Depends on : nothing
# Globals    : declared and documented below
#
# Declared in one place so there is a single list of what can change at runtime.
# Terminal geometry lives in ui/term.sh, chart caches in viz/*.

# Screen registry, in sidebar order. A screen NAME needs screen_NAME_load, screen_NAME_row and
# screen_NAME_viz functions (see the screens/ directory).
SCREENS=(dashboard transactions daily categories wallets budget search trash)
SCR_LABEL=(Dashboard Transactions Daily Categories Wallets Budget Search Trash)

SCREEN=dashboard   # current screen name
MODE=list          # list or form
SEL=0              # selected row index within ROWS_DATA
TOPROW=0           # first visible row index
QUIT=0
TUI=0              # 1 while the alternate screen is active
RESIZED=0          # set by the WINCH trap, handled in draw
CANCEL=0
printf -v MONTH '%(%Y-%m)T' -1   # month being viewed, YYYY-MM
printf -v DAY '%(%F)T' -1        # day shown on the Daily screen, YYYY-MM-DD
SHOWVIZ=0          # toggled by the user; meaning depends on terminal width
BUF=""             # frame buffer, flushed once per draw
VIZBUF=""
MSG=""             # one-line message above the footer
VIZFN=""

TXSORT=date; TXREV=1       # transaction list sort key and direction (1 = descending)
CATSORT=manual; CATREV=0
WALSORT=manual; WALREV=0
QUERY=""                   # last search query

ROWS_DATA=()   # raw rows of the current list screen
TX=()          # transactions behind the current charts
TXV=()
WB=()          # wallets with balances: id name balance lower upper
CS=()          # categories with spent and quota: id kind name spent quota
FL=(); FV=(); FA=()   # form labels, values, field types
PVL=()                # form preview lines
ALERTS=()             # pending popup messages, "W:" warning or "G:" good news
PICK=()               # picker items: "id<TAB>label"
SELECTABLE=1
FPREVFN=""; FVALID=""; FCUR=-1
BUDMONTH=""
NW_TXT=""      # formatted net worth for the header
WMAX=1         # largest wallet balance, scale for wallet bars
