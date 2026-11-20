# Key bindings

These are the defaults. Change them in the `[keys]` section of `~/.config/kreuzer/kreuzer.conf`: one line per action, `action=key1,key2`. Special names: `ENTER ESC TAB UP DOWN LEFT RIGHT SPACE COMMA BACKSPACE`. Startup fails with a clear message if two actions share a key. `kreuzer --dump-keys` prints the bindings in effect and is the authority if this page is out of date.

| Action | Default | Effect |
|---|---|---|
| `up` | `k`, Up | move up |
| `down` | `j`, Down | move down |
| `top` | `g` | first item |
| `bottom` | `G` | last item |
| `select` | Enter | open or edit |
| `back` | Esc | return to the dashboard |
| `next_screen` | Tab | next screen |
| `goto_dashboard` | `1` | Dashboard |
| `goto_transactions` | `2` | Transactions |
| `goto_daily` | `3` | Daily |
| `goto_categories` | `4` | Categories |
| `goto_wallets` | `5` | Wallets |
| `goto_budget` | `6` | Budget |
| `goto_search` | `7` | Search |
| `goto_trash` | `8` | Trash |
| `prev_month` | `[` | previous month |
| `next_month` | `]` | next month |
| `prev_day` | `h`, Left | previous day (previous month outside Daily) |
| `next_day` | `l`, Right | next day (next month outside Daily) |
| `add` | `a` | add an item for the current screen |
| `add_income` | `i` | quick income |
| `add_expense` | `x` | quick expense |
| `add_transfer` | `t` | quick transfer |
| `edit` | `e` | edit the selected item |
| `delete` | `d` | move the selected item to the trash |
| `move_up` | `K` | move item up (manual order only) |
| `move_down` | `J` | move item down (manual order only) |
| `sort` | `s` | next sort key |
| `sort_reverse` | `S` | reverse the sort |
| `search` | `/` | search all months |
| `restore` | `r` | restore (Trash) |
| `purge` | `D` | delete forever (Trash) |
| `empty_trash` | `E` | empty the trash |
| `toggle_viz` | `v` | show or hide the charts |
| `settings` | `C` | settings |
| `help` | `?` | key help |
| `quit` | `q` | quit |

Fixed keys that cannot be rebound: Page Up, Page Down, Home and End scroll lists. In forms, Tab and Shift-Tab move between fields, Enter edits or chooses, and Esc cancels. In text fields: Left, Right, Home, End, Backspace, Delete, `Ctrl-A`, `Ctrl-E`, `Ctrl-K` and `Ctrl-U` work as usual.

Search syntax: free words match category, wallet and note. `from:DD/MM/YYYY`, `to:DD/MM/YYYY`, `min:12.50` and `max:99` filter. A word wrapped in slashes, such as `/rent|food/`, is a regular expression.
