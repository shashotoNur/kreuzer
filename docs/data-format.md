# Data format

All files are UTF-8, tab-separated, one record per line, under the data directory (default `~/Documents/kreuzer`). Amounts are integer cents. Dates are `YYYY-MM-DD`. A field with no value is `-`, never empty. Tabs and newlines in notes are replaced by spaces on save.

```text
~/Documents/kreuzer/
├── 2026-11.tsv        one file per month of transactions
├── meta/
│   ├── categories.tsv
│   ├── wallets.tsv
│   ├── quotas.tsv
│   ├── budget.tsv
│   ├── trash.tsv
│   └── seq            last id handed out
└── .lock              held while the app runs
```

## Month file `YYYY-MM.tsv`

| Column | Content |
|---|---|
| 1 | id |
| 2 | date |
| 3 | time `HH:MM` or `-` |
| 4 | kind: `I` income, `E` expense, `TO` transfer out, `TI` transfer in |
| 5 | amount in cents, always positive |
| 6 | category id, `-` for transfer legs |
| 7 | wallet id |
| 8 | transfer id, `-` when not part of a transfer |
| 9 | note, `-` when empty |

A transfer is a `TO` row, a `TI` row, and optionally an `E` row for the fee (in the `Transfer fees` category). All share the transfer id in column 8. Transfers never count as income or expense.

## `meta/categories.tsv`

`id`, `kind` (`I` or `E`), `name`, `sort_order`. The kind never changes after creation.

## `meta/wallets.tsv`

`id`, `name`, `opening_cents`, `opening_date`, `lower`, `upper`, `sort_order`. `lower` and `upper` are cents or `-`. A wallet balance is its opening balance plus all its movements on or after the opening date, across all month files. It is computed on demand and never stored.

## `meta/quotas.tsv` and `meta/budget.tsv`

- Quotas: `effective_month`, `category_id`, `cents`.
- Budget: `effective_month`, `cents`.

Both are "effective from" records. The value for a month is the latest record at or before it, so changing a value never rewrites earlier months.

## `meta/trash.tsv`

`trash_id`, `deleted_at` (epoch seconds), `kind` (`T` transaction, `C` category, `W` wallet), `source_file` (the month file for `T`, otherwise `-`), then the original record verbatim. Restoring copies the record back with its original id. All rows of a transfer are trashed and restored together.

## Names are resolved at read time

Month files store ids only. Category and wallet names are looked up when displaying or exporting, so renames apply to old entries, and an id missing from the tables shows as `DELETED`.
