# boosh

> A friendly installer for a minimal **Ghostty + fish** terminal: pick a look, keys, theme, font, cursor and editor
> from arrow-key menus **with live previews**, then add optional setups ("packs") for git and docker.

*[Читать по-русски](README.ru.md)*

```
Cursor style: (↑/↓ move, Enter select)
    block         filled box, the classic terminal cursor
    bar           thin vertical line, like in text editors
  ❯ underline     a line under the character
    block_hollow  outline of a box (shown when the window is unfocused)
  ┌─ preview ──────────────────────────────────
  │  live: your real cursor, underline, steady
  │   ~/app main $ git status
  │  blinking follows the next question (now: no)
  └────────────────────────────────────────────
```

`boosh` generates your Ghostty config from small, readable pieces (an appearance preset, a keybind preset and a few
parameters), links an editor config, and keeps everything reversible: it validates the result (when Ghostty is installed) with
`ghostty +validate-config` before writing, backs up what it replaces, and never edits your `~/.bashrc`.

## Features

- **Arrow-key menus in plain bash.** No dependencies (no `fzf`, no `gum`). Works with bash 3.2+ as far as the code goes
  (see [Compatibility](#compatibility)).
- **Live previews** under the choices:
  - *theme*: framed colour samples read from Ghostty's own theme files, light and dark side by side;
  - *keybinds*: example keys for the highlighted preset;
  - *cursor style and blinking*: your **real terminal cursor** changes shape and blinks while you move;
  - *font family*: styles and file of the installed font;
  - *ligatures* and *background opacity*: illustrations (opacity is a blend of the theme background over a "desktop").
- **Sliders** for font size (8–32, step 0.5) and background opacity (0.3–1, step 0.05).
- **Presets**: three appearances (`minimal`, `classic`, `borderless`) and two keybind sets (`alt`, `default`).
- **Editor choice**: `vim` or `nano` (a ready config for each), or none. Adding another editor is one folder.
- **Cheatsheet**: a markdown table of your keys, generated for exactly the setup you chose.
- **Packs**: optional terminal setups on top of the base. Included: `git` and `docker`. Each pack only drops files into
  places the tools already read, and `./pack remove` takes them out again.
- **Non-interactive**: every question has a flag, so it also works in scripts and on a new machine.
- **Safe**: `--dry-run`, validation before writing, `.bak` backups, no silent overrides of your git settings.

## Quick start

```bash
git clone https://github.com/Bopster410/booosh.git
cd booosh

./bootstrap.sh --dry-run     # optional: see what would be installed (fish, vim)
./install.sh                 # interactive menu
./pack list                  # optional setups for git, docker, ...
```

Reload Ghostty with `ctrl+shift+,` (or restart it). Run `./install.sh` again at any time to change your choices; the
previous ones are the defaults in the menu.

Non-interactive examples:

```bash
./install.sh --yes                                   # last saved choices, else defaults
./install.sh --preset borderless --theme nord --font-size 15 --editor nano
./install.sh --keys default                          # stock Ghostty keys only
./install.sh --print                                 # show the generated config, write nothing
./install.sh --cheatsheet                            # print the keybind cheatsheet
./pack add git docker --no-tools                     # packs without installing extra programs
```

## What you choose

| Question | Options | Notes |
|---|---|---|
| Appearance preset | `minimal`, `classic`, `borderless` | `minimal`: thin title bar with the working directory, tab bar at the bottom. `classic`: close to stock Ghostty. `borderless`: no title bar or frame. |
| Keybind preset | `alt`, `default` | `alt` **adds** short keys on `Alt` (e.g. `Alt+→` split, `Alt+T` new tab) next to the stock ones. `default` adds nothing. |
| Colour theme | `auto`, `mocha`, `rose-pine`, `kanagawa`, `tokyonight`, `gruvbox`, `nord`, any Ghostty theme | `auto` = Catppuccin Latte/Mocha following the system light/dark setting. |
| Font family | built-in JetBrains Mono, installed monospace fonts, or a typed name | An unknown name falls back to JetBrains Mono. |
| Font size | 8 – 32, step 0.5 | slider |
| Programming ligatures | yes / no | `no` adds `font-feature = -calt`. |
| Cursor style | `block`, `bar`, `underline`, `block_hollow` | live preview |
| Blinking cursor | yes / no | live preview |
| Background opacity | 0.3 – 1.0 | slider; needs a compositor |
| Default editor | `vim`, `nano`, `none` | links the config and sets `EDITOR` in fish |

The `alt` preset's modifier is not in the menu; use `--mod super` (for example on a Mac) or `--mod ctrl+alt`. See
[`docs/example-cheatsheet.md`](docs/example-cheatsheet.md) for what the generated cheatsheet looks like.

### Keybind presets by example

| Action | Stock Ghostty (in both presets) | Added by `alt` |
|---|---|---|
| Split | `Ctrl+Shift+O` / `Ctrl+Shift+E` | `Alt+←↑↓→` |
| Focus a pane | `Ctrl+Alt+←↑↓→` | `Alt+Shift+←↑↓→` |
| Resize a pane | `Super+Ctrl+Shift+←↑↓→` | `Alt+R`, then an arrow |
| Zoom a pane | `Ctrl+Shift+Enter` | `Alt+Z` |
| New tab | `Ctrl+Shift+T` | `Alt+T` |
| Close a pane | (none in the list) | `Alt+W` |
| Switch tab | `Ctrl+PgUp` / `Ctrl+PgDn` | `Alt+[` / `Alt+]` |

Letter shortcuts are bound to **physical keys**, so they work on any layout (for example Russian).
Trade-off: with `alt`, `Alt`+arrows no longer reach the shell (in fish they are directory history and history-token
search); `Ctrl`+arrows still move by word.

## Packs

```
$ ./pack list
  docker   available  fish abbreviations for docker and compose (d, dps, dcup, dcl...)
  git      available  fish abbreviations (gst, gd, gl...), git status in the prompt, safe git defaults

$ ./pack add git          # asks (default: no) before installing lazygit / delta
$ ./pack status           # health check
$ ./pack remove git       # removes the files again; installed programs are left alone
```

A pack is a folder in `packs/<name>/`:

| File | What it does |
|---|---|
| `pack.conf` | `DESCRIPTION=...` and optional `TOOL=command\|brew package\|apt package\|description` lines. |
| `fish.fish` | linked to `~/.config/fish/conf.d/pack-<name>.fish` (abbreviations, functions). |
| `gitconfig` | linked to `~/.config/git/pack-<name>.conf` and pulled in with one `include.path` line. |
| `gitconfig.<tool>` | the same, but **only while `<tool>` is on `PATH`** (for example `delta` as git's pager). |

Safety rules built into `pack`:

- A git setting you already set to a different value is **reported**, and left alone unless you pass `--yes`.
- `delta` is configured in its own file, so removing the program cannot leave `git diff` broken; `./pack status` warns
  and `./pack add git` switches that file off.
- Files that are not yours to touch (a regular file in the way, a symlink pointing elsewhere) are backed up or skipped.
- Optional tools are installed with Homebrew if present, otherwise with `apt` when the package exists there;
  otherwise you are told to install it yourself.

Included packs: **git** (abbreviations such as `gst`, `gd`, `gcm`, `gl`, a git status in the fish prompt, and a few
safe settings: `init.defaultBranch`, `push.autoSetupRemote`, `fetch.prune`, `rerere.enabled`) and **docker**
(abbreviations such as `d`, `dps`, `dex`, `dcup`, `dcl`; `docker compose` vs `docker-compose` is detected when you press
space, so shell startup stays fast).

## What gets written where

| Path | Written by | What |
|---|---|---|
| `~/.config/ghostty/config` | `install.sh` | **generated**; do not edit |
| `~/.config/ghostty/local.conf` | `install.sh` (symlink) | per-OS overrides, loaded last (`command`, `macos-option-as-alt`) |
| `~/.config/ghostty/gtk.css` | `install.sh` (symlink, Linux, `minimal`) | thin title bar styling |
| `~/.config/ghostty/cheatsheet.md` | `install.sh` | your cheatsheet |
| `~/.config/ghostty/.install-choices` | `install.sh` | last answers (the next run's defaults) |
| `~/.config/fish/conf.d/00-boosh-core.fish` | `install.sh` | `set -gx EDITOR ...` |
| `~/.vimrc` or `~/.nanorc` | `install.sh` (symlink) | editor config |
| `~/.config/fish/conf.d/pack-<name>.fish` | `pack` (symlink) | abbreviations |
| `~/.config/git/pack-<name>*.conf` + `include.path` in `~/.gitconfig` | `pack` | git settings |
| `~/.config/boosh/packs` | `pack` | list of installed packs (per machine) |

Anything that already exists is moved to `<name>.bak` (or `.bak.1`, ...) before being replaced. `~/.bashrc`,
`~/.profile` and your git identity are never touched.

Per-machine tweaks belong in `~/.config/ghostty/local.conf`; the generated `config` is rewritten on every run.

## Extending

- **Editor**: create `editors/<name>/` with an `editor.conf` (`DESCRIPTION`, `COMMAND`, `FILE`, `TARGET`) and the
  config file. It shows up in the menu by itself.
- **Pack**: create `packs/<name>/` as described above. `./pack list` finds it by itself.
- **Appearance preset**: add `ghostty/appearance/<name>.conf` and the name to `PRESETS` in `install.sh`
  (plus a hint in `menu_desc`).
- **Keybind preset**: add `ghostty/keys/<name>.conf` (use `@MOD@` for the modifier) and the name to `KEYSETS`.
- **Theme shortcut**: one line in `theme_spec` in `install.sh`; any Ghostty theme name already works with `--theme`.

## Compatibility

Developed and tested on **Ubuntu 24.04, GNOME (Wayland), Ghostty 1.3.1, fish 4.9.3, bash 5.2**.

- **macOS**: the macOS branches (`local.macos.conf`, Homebrew, `macos-titlebar-style`) were written from Ghostty's
  documentation and **have not been run on a Mac**. The code avoids bash 4 features so the system bash 3.2 should
  work, but that is also untested.
- **Windows**: use WSL2 and run everything inside it.
- The live cursor and the colour previews need a terminal that honours `DECSCUSR` and 24-bit colour; Ghostty does.
- Fish abbreviations with a cursor marker need fish 3.6 or newer.
- The font glyphs themselves cannot be previewed: a terminal draws all text in one font, so only details are shown.
- There is no `uninstall` command yet: remove the symlinks listed above and restore the `.bak` files.

## Tests

```bash
bash tests/smoke.sh                       # runs in a throw-away $HOME
BOOSH_TEST_PTY=1 bash tests/smoke.sh      # also drives the arrow-key menu through a pty (Linux)
```

The suite covers the installer flags and validation, idempotence, `--dry-run`, the cheatsheet, and the whole pack
lifecycle (including conflicts and the `delta` safeguard). It does not need `ghostty` or `fish`; checks that need them
are skipped.

## License

[MIT](LICENSE)
