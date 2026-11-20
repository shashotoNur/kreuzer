# Contributing

## Setup

```bash
git clone <repo> && cd kreuzer
ln -sf "$PWD/bin/kreuzer" ~/.local/bin/kreuzer
sudo pacman -S shellcheck bats pandoc     # optional but recommended
```

## Before you submit

```bash
make check     # bash -n on every file, then shellcheck
make test      # bats suite (falls back to the smoke scripts)
```

Both must pass. If you changed `main.sh` or the module list, also run `make dist` and `bash dist/kreuzer --version`.

## Style

- Follow the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html), except that names use plain underscores (`module_verb`) and indentation is two spaces.
- Start each file with the standard header: purpose, `Depends on`, `Provides`, and any globals it sets. Keep it accurate.
- Respect the layer order in [docs/architecture.md](docs/architecture.md). `data/` and `domain/` must not call UI code.
- Return values through documented out-variables, not `$(...)`, in anything called from the draw loop.
- Money is integer cents. Never use floating point for amounts.
- Write `-` for empty data fields.
- Quote everything. The `set -f` in `main.sh` guards the few intentional unquoted expansions.

## Comments

Comment why, not what. Good targets: a non-obvious ordering, a workaround, a format constraint, a trade-off. Do not restate the code. A function name and a short header already say what it does.

## Tests

- Library behaviour: add checks to a `tests/smoke_*.sh` script. They use throwaway directories and never touch real data.
- Command-line behaviour: add a `@test` to `tests/bats/kreuzer.bats`. It runs the real launcher with a temporary config.
- Screens and forms need a terminal, so they are checked by hand. Describe what you clicked through in the pull request.

## Commits

One logical change per commit, with a short imperative subject. Update `CHANGELOG.md` for anything user-visible.


## Releasing

1. Set `VERSION` in `lib/kreuzer/main.sh` and add a section to `CHANGELOG.md`.
2. Run `make check test man` and commit, including `man/kreuzer.1`.
3. Tag and push: `git tag -a vX.Y.Z -m "kreuzer X.Y.Z" && git push origin main vX.Y.Z`.
4. In `packaging/kreuzer`: set `pkgver`, reset `pkgrel=1`, run `updpkgsums`, then `makepkg --printsrcinfo > .SRCINFO`.
5. Build with `makepkg -f`, run `namcap`, and copy `PKGBUILD` and `.SRCINFO` into the AUR repository.
