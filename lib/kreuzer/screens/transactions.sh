# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# screens/transactions.sh - all transactions of the viewed month
#
# Depends on : data/transactions.sh, screens/common.sh, viz/blocks.sh
# Provides   : screen_transactions_load screen_transactions_row screen_transactions_title screen_transactions_viz

screen_transactions_load() { tx_load_month; ROWS_DATA=("${TX[@]}"); SELECTABLE=1; }

screen_transactions_row() { screen_row_tx "$1"; }

screen_transactions_title() { screen_title_tx "Transactions - $MONTH_LABEL"; }

screen_transactions_viz() { pie_selected_category; block_pies "$VY" "$VH" TX; }
