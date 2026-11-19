# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# screens/transactions.sh - all transactions of the viewed month
#
# Depends on : data/transactions.sh, screens/common.sh, viz/blocks.sh
# Provides   : load_transactions row_transactions title_transactions viz_transactions

load_transactions() { load_month_tx; ROWS_DATA=("${TX[@]}"); SELECTABLE=1; }

row_transactions() { row_tx "$1"; }

title_transactions() { title_tx "Transactions - $MONTH_LABEL"; }

viz_transactions() { sel_cat; viz_pair "$VY" "$VH" TX; }
