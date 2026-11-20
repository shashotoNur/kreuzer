# kreuzer

A terminal tracker for income, expenses and budgets. Full-screen, keyboard driven, written in bash. Data is plain tab-separated files, one per month, so it stays readable and easy to back up.

## Features

- Income and expense categories, with an optional monthly quota per expense category.
- A monthly budget that every expense counts toward. Quotas may add up to more than the budget; you get a warning, never a block.
- Several wallets with transfers between them, optional transfer fees, and lower and upper bounds that trigger warnings or a congratulation.
- Pie charts for income and expenses per month and per day, quota and budget bars, and wallet sparklines. Entry forms show live previews.
- Trash for everything you remove, with restore and permanent delete. Orphaned transactions show `DELETED` until their category or wallet is restored.
- Search across all months, sortable lists, manual reordering, configurable key bindings.

## Requirements

bash 4.4 or newer, GNU awk, and coreutils, util-linux (`flock`), findutils, grep and tar. A UTF-8 terminal with truecolor and at least 70x20 characters. Run `kreuzer --check` to verify.

On Arch and CachyOS: `sudo pacman -S gawk coreutils util-linux findutils grep tar`.

## Install

From a checkout:

```bash
ln -sf "$PWD/bin/kreuzer" ~/.local/bin/kreuzer
```

System-wide:

```bash
sudo make install            # PREFIX=/usr/local by default
```

As one file, with no library directory:

```bash
make dist && install -Dm755 dist/kreuzer ~/.local/bin/kreuzer
```

## Usage

```text
kreuzer                start the interface
kreuzer export [YYYY-MM]   print a month as CSV
kreuzer backup             write a .tar.gz of the data directory
kreuzer --dump-keys        print the active key bindings
kreuzer --check            check dependencies and show paths
```

Press `?` inside the app for the key list. The screens are numbered 1 to 8 (dashboard, transactions, daily, categories, wallets, budget, search, trash). `i`, `x` and `t` add an income, expense or transfer from anywhere. See [docs/keybindings.md](docs/keybindings.md).

## Files

- Config: `~/.config/kreuzer/kreuzer.conf` (settings and key bindings).
- Data: `~/Documents/kreuzer/` (change with `data_dir` in the config). Format: [docs/data-format.md](docs/data-format.md).

The first start asks for your currency and creates a first wallet and starter categories.

## Documentation

- [docs/architecture.md](docs/architecture.md): layers, conventions, how to add a screen.
- [docs/data-format.md](docs/data-format.md): file layouts.
- [docs/keybindings.md](docs/keybindings.md): default keys.
- [CONTRIBUTING.md](CONTRIBUTING.md) and [CHANGELOG.md](CHANGELOG.md).
- `man kreuzer` after `make install`.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
