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
- **A small fish prompt of its own**: two lines, git status computed in the background, configured with one command,
  no plugin manager (see [The prompt](#the-prompt)). Or keep fish's own, or your own plugin.
- **Cheatsheet**: a markdown table of your keys, generated for exactly the setup you chose.
- **Packs**: optional terminal setups on top of the base. Included: `git` and `docker`. Each pack only drops files into
  places the tools already read, and `./pack remove` takes them out again.
- **Non-interactive**: every question has a flag, so it also works in scripts and on a new machine.
- **Safe**: a stable core outside the repository, validation before anything is applied, a snapshot (generation) per
  install with `--rollback`, `--check`, `--uninstall`, your old config carried over, `.bak` backups, `--dry-run`, no silent
  overrides of your git settings (see [Safe by design](#safe-by-design)).

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
./install.sh --only prompt                           # just the prompt, leave Ghostty and the editor alone
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
| Shell prompt | `boosh`, `default` | `boosh`: the prompt described [below](#the-prompt). `default`: fish's own, nothing is installed. |
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
  git      available  fish abbreviations (gst, gd, gl...), safe git defaults, git status for fish's own prompt

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

Included packs: **git** (abbreviations such as `gst`, `gd`, `gcm`, `gl`, git status for fish's own prompt (the boosh prompt has its own), and a few
safe settings: `init.defaultBranch`, `push.autoSetupRemote`, `fetch.prune`, `rerere.enabled`) and **docker**
(abbreviations such as `d`, `dps`, `dex`, `dcup`, `dcl`; `docker compose` vs `docker-compose` is detected when you press
space, so shell startup stays fast).

## The prompt

boosh ships its own small prompt for fish (`fish/prompt/`, a few hundred lines with comments and the settings command). No plugin manager.

```
~/app main ⇡1 ⇣1 +2 !1 ?3 ✖1 *1 5s
❯
```

- **Line 1**: path, git status, and the time of a slow command (3 s or more). **Line 2**: the symbol; after a failed
  command it turns red and shows the exit code (`✘1 ❯`). An empty line separates each prompt from the previous
  command's output (not before the very first one).
- **Git is computed in the background.** One `git status --porcelain=v2` call runs in a separate process, so the prompt
  never waits for it; the information appears a moment later and the prompt repaints itself. Markers: `⇡ ⇣` commits to
  push / pull, `+` staged, `!` modified, `?` untracked, `✖` conflicts, `*` stashes. A detached HEAD shows `@abc1234`.
- **Cost.** In one run here (fish start plus the work before a prompt, small repo / 30 000-file repo) it took 26 / 27 ms,
  [Hydro](https://github.com/jorgebucaran/hydro) 28 / 30 ms: equal within the noise of that measurement, and it does not
  grow with the size of the repository. fish's own synchronous git prompt took 36 / 50 ms.
- **Configure it with one command**, `boosh-prompt` (tab completion included). Changes apply to the next prompt in
  every open terminal and stay after a restart; a wrong flag changes nothing:

  | Command | What it does |
  |---|---|
  | `boosh-prompt` | show the current settings (`*` marks what you changed) |
  | `--lines 1\|2` | one or two lines |
  | `--gap N` | empty lines between prompts, 0 to 5 |
  | `--symbol TEXT` | the last-line character, for example `">"` or `"λ"` |
  | `--path short\|full` | `~/a/b/c` shortened or in full |
  | `--git on\|off` | git information; `off` also stops the background job completely |
  | `--fields LIST` | git parts, comma separated, **in the order you give**: `branch ahead behind staged modified untracked conflicts stash` |
  | `--time on\|off`, `--time-after 3s` | the time of slow commands, and what "slow" means (`3s` or `3000` ms) |
  | `--status on\|off` | the exit code (`✘1`) after a failed command |
  | `--reset` | back to the defaults |

  Flags can be combined: `boosh-prompt --lines 1 --gap 0 --fields branch,modified,untracked`.
  Settings are the universal variables `boosh_prompt_*`; symbols and colours of the git part are in one function,
  `__boosh_git_format`.
- **Install / remove**: `./install.sh --only prompt`, or `--prompt default` to go back to fish's own prompt. If Hydro,
  Tide or Pure is installed, boosh does not fight over `fish_prompt`: it tells you to remove that plugin first.
- The technique (result delivered by a signal, then a repaint) is the one Hydro uses; the code is separate.

## Safe by design

What the shell and Ghostty read lives in a **stable core**, not in your checkout of this repository:

```
~/.local/share/booosh/
├── core -> generations/0007-...     the current snapshot; everything installed points behind it
├── generations/0006-..., 0007-...   one complete snapshot per install (the last 5 are kept)
├── packs/git, packs/docker          snapshots of the installed packs
└── manifest                         what boosh put where
```

- **The repository is only the source.** Switching branches, moving, renaming or deleting it cannot break an installed
  setup (the tests install from a copy of the repository, delete the copy, and check that every link still resolves).
- **Build, validate, then apply.** `install.sh` builds the whole snapshot in a staging folder, checks it (`ghostty
  +validate-config` with your `local.conf` included, `fish --no-execute` for every prompt file) and only then makes it
  current and touches your files. A mistake stops before anything on your machine has changed.
- **Your files stay yours.** `~/.config/ghostty/local.conf` is created once and never overwritten; it is loaded last, so
  anything in it wins. If you already have a Ghostty config, boosh keeps it as that `local.conf` (so your settings keep
  applying on top of the boosh ones) and also leaves a `.bak` copy. `--import-config no` only backs it up.
- **Everything is reversible.**

| Command | What it does |
|---|---|
| `./install.sh --check` | health check: broken links, files you edited, repository ahead of what is installed (exit code 1 on problems) |
| `./install.sh --generations` | list the generations (`*` = current) |
| `./install.sh --rollback` | go back to the previous generation (config, prompt, style sheet) |
| `./install.sh --uninstall` | remove what boosh installed and put your backed-up originals back; a `local.conf` you edited is kept |

The data folder is `$XDG_DATA_HOME/booosh` (default `~/.local/share/booosh`); set `BOOSH_HOME` to move it and
`BOOSH_KEEP_GENERATIONS` to keep more or fewer snapshots. Not covered yet: the editor files (`~/.vimrc`, `~/.nanorc`)
still link into the repository; `--check` says so.

## What gets written where

| Path | Written by | What |
|---|---|---|
| `~/.config/ghostty/config` | `install.sh` | **generated**; do not edit |
| `~/.config/ghostty/local.conf` | `install.sh` (once) | **yours**: created once, never overwritten, loaded last (your old config is carried over here) |
| `~/.config/ghostty/gtk.css` | `install.sh` (link into the core, Linux, `minimal`) | thin title bar styling |
| `~/.config/ghostty/cheatsheet.md` | `install.sh` | your cheatsheet |
| `~/.config/ghostty/.install-choices` | `install.sh` | last answers (the next run's defaults) |
| `~/.config/fish/conf.d/00-boosh-core.fish` | `install.sh` | `set -gx EDITOR ...` |
| `~/.config/fish/functions/` (`fish_prompt`, `boosh-prompt`, helpers), `conf.d/boosh_prompt.fish`, `completions/boosh-prompt.fish` | `install.sh` (links into the core) | the boosh prompt |
| `~/.vimrc` or `~/.nanorc` | `install.sh` (symlink) | editor config |
| `~/.config/fish/conf.d/pack-<name>.fish` | `pack` (link into the pack's snapshot) | abbreviations |
| `~/.config/git/pack-<name>*.conf` + `include.path` in `~/.gitconfig` | `pack` | git settings |
| `~/.config/boosh/packs` | `pack` | list of installed packs (per machine) |
| `~/.local/share/booosh/` | `install.sh`, `pack` | the stable core, generations, pack snapshots and the manifest (see above) |

Anything that already exists is moved to `<name>.bak` (or `.bak.1`, ...) before being replaced. `~/.bashrc`,
`~/.profile` and your git identity are never touched.

Per-machine tweaks belong in `~/.config/ghostty/local.conf` (yours); the generated `config` is rewritten on every run.

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
- Fish abbreviations with a cursor marker need fish 3.6 or newer. The prompt uses the `path` builtin (fish 3.5+, by the
  documentation); it was tested on fish 4.9.3 only.
- The font glyphs themselves cannot be previewed: a terminal draws all text in one font, so only details are shown.
- There is no `uninstall` command yet: remove the symlinks listed above and restore the `.bak` files.

## Tests

```bash
bash tests/smoke.sh                       # runs in a throw-away $HOME
BOOSH_TEST_PTY=1 bash tests/smoke.sh      # also drives the arrow-key menu through a pty (Linux)
```

The suite covers the installer flags and validation, idempotence, `--dry-run`, the cheatsheet, and the whole pack
lifecycle (including conflicts and the `delta` safeguard), the prompt install and the prompt's git parser (dirty, detached
HEAD, merge conflict, not a repo), the stable core (generations, rollback, importing an old config, uninstall, `--check`, and
that everything keeps working after the repository is deleted), formatting, command time and, with the pty flag, the asynchronous repaint in a live fish. It does not need `ghostty` or `fish`; checks that need them
are skipped.

## License

[MIT](LICENSE)
