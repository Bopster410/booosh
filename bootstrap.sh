#!/usr/bin/env bash
# Install fish + full vim (with +eval) using whatever package manager the box has.
# Usage: ./bootstrap.sh [--dry-run] [--chsh]
#   --dry-run  print what would run, change nothing
#   --chsh     also make fish the login shell (asks for your password)
# Windows: use WSL2 and run this inside it (fish has no native Windows build).
set -euo pipefail

DRY=0; CHSH=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --chsh)    CHSH=1 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }
run() { if [ "$DRY" = 1 ]; then echo "+ $*"; else "$@"; fi; }

# vim is only useful here if it has +eval (Debian/Ubuntu's `vi` is vim.tiny, which has not).
vim_ok() { command -v vim >/dev/null 2>&1 && vim --version 2>/dev/null | grep -q '+eval'; }
fish_ok() { command -v fish >/dev/null 2>&1; }

if fish_ok && vim_ok; then
  echo "fish and vim(+eval) already installed, nothing to install."
else
  need_fish=0; need_vim=0
  fish_ok || need_fish=1
  vim_ok  || need_vim=1

  SUDO=""
  if [ "$(id -u)" -ne 0 ] && [ "$(uname -s)" != Darwin ]; then
    command -v sudo >/dev/null 2>&1 || die "not root and no sudo; run as root"
    SUDO=sudo
  fi

  if [ "$(uname -s)" = Darwin ]; then
    command -v brew >/dev/null 2>&1 || die "Homebrew not found. Install it from https://brew.sh, then re-run."
    pkgs=(); [ $need_fish = 1 ] && pkgs+=(fish); [ $need_vim = 1 ] && pkgs+=(vim)
    run brew install "${pkgs[@]}"
  elif command -v apt-get >/dev/null 2>&1; then
    pkgs=(); [ $need_fish = 1 ] && pkgs+=(fish); [ $need_vim = 1 ] && pkgs+=(vim)
    run $SUDO apt-get update
    run $SUDO apt-get install -y "${pkgs[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    pkgs=(); [ $need_fish = 1 ] && pkgs+=(fish); [ $need_vim = 1 ] && pkgs+=(vim-enhanced)
    run $SUDO dnf install -y "${pkgs[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    pkgs=(); [ $need_fish = 1 ] && pkgs+=(fish); [ $need_vim = 1 ] && pkgs+=(vim)
    run $SUDO pacman -S --needed --noconfirm "${pkgs[@]}"
  elif command -v zypper >/dev/null 2>&1; then
    pkgs=(); [ $need_fish = 1 ] && pkgs+=(fish); [ $need_vim = 1 ] && pkgs+=(vim)
    run $SUDO zypper --non-interactive install "${pkgs[@]}"
  elif command -v apk >/dev/null 2>&1; then
    pkgs=(); [ $need_fish = 1 ] && pkgs+=(fish); [ $need_vim = 1 ] && pkgs+=(vim)
    run $SUDO apk add "${pkgs[@]}"
  else
    die "no supported package manager (brew/apt/dnf/pacman/zypper/apk)"
  fi
fi

if [ "$DRY" = 0 ]; then
  fish_ok || die "fish still missing after install"
  vim_ok  || echo "warning: vim installed but has no +eval; check which one 'vim' resolves to." >&2
  echo "fish: $(fish --version)"
  echo "vim : $(vim --version | head -1)"
  command -v vi >/dev/null 2>&1 && ! vi --version 2>/dev/null | grep -q '+eval' \
    && echo "note: 'vi' is still a minimal build; use 'vim', or on Debian/Ubuntu: sudo update-alternatives --config vi"
fi

if [ "$CHSH" = 1 ]; then
  FISH="$(command -v fish || true)"
  [ -n "$FISH" ] || [ "$DRY" = 1 ] || die "fish not found for chsh"
  FISH="${FISH:-/usr/bin/fish}"
  if ! grep -qx "$FISH" /etc/shells 2>/dev/null; then
    echo "adding $FISH to /etc/shells"
    if [ "$DRY" = 1 ]; then echo "+ echo $FISH | sudo tee -a /etc/shells"
    else echo "$FISH" | ${SUDO} tee -a /etc/shells >/dev/null; fi
  fi
  run chsh -s "$FISH"
  echo "login shell changes after you log out and back in."
fi
