#!/usr/bin/env bash
#
# ffmpeg-nvenc-legacy — 卸载: 用发行版官方包覆盖回本地构建的 ffmpeg
#
set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

as_root() {
	if [ "$(id -u)" -eq 0 ]; then
		"$@"
	elif sudo -n true 2>/dev/null; then
		sudo "$@"
	elif [ -t 0 ] && command -v sudo >/dev/null 2>&1; then
		sudo "$@"
	elif command -v pkexec >/dev/null 2>&1; then
		pkexec "$@"
	elif command -v sudo >/dev/null 2>&1; then
		sudo "$@"
	else
		die "需要 root 权限, 但系统里没有 sudo / pkexec"
	fi
}

log "用仓库里的官方 ffmpeg 覆盖本地构建"
as_root pacman -S --noconfirm ffmpeg

log "当前版本: $(pacman -Q ffmpeg)"
log "完成。注意发行版版本低于本地构建时 pacman 会提示 \"downgrading\"。"
