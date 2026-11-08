#!/usr/bin/env bash
#
# ffmpeg-nvenc-legacy — 安装器
# 用打了「运行时 NVENC API 协商」补丁的 ffmpeg 替换系统包, 使 NVENC 在
# Maxwell/Pascal/Volta (580xx 驱动, NVENC API 13.0) 上恢复正常。
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

MAKEDEPENDS=(
  amf-headers
  avisynthplus
  clang
  frei0r-plugins
  ladspa
  mesa
  nasm
  opencl-headers
  spirv-headers
  vulkan-headers
)

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
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

command -v makepkg >/dev/null || die "需要 pacman 的 makepkg (base-devel)"
[ -f PKGBUILD ] || die "请在仓库根目录运行"
[ -f nvenc-runtime-api-version.patch ] || die "缺少 nvenc-runtime-api-version.patch"

missing=()
for p in "${MAKEDEPENDS[@]}"; do
	pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p")
done

if [ "${#missing[@]}" -gt 0 ]; then
	log "安装缺少的构建依赖: ${missing[*]}"
	as_root pacman -S --needed --asdeps --noconfirm "${missing[@]}"
fi

log "开始编译 ffmpeg (LTO, 6-8 核大约 10-25 分钟)"
makepkg -f --nocheck --nodeps --noconfirm

pkg=$(ls -t ffmpeg-*.pkg.tar.zst 2>/dev/null | head -n1 || true)
[ -n "$pkg" ] || die "没有找到构建产物"

log "安装 $pkg (会替换系统的 ffmpeg 包)"
as_root pacman -U --noconfirm "$pkg"

log "验证 NVENC"
if timeout 60 ffmpeg -hide_banner -loglevel warning \
	-f lavfi -i testsrc=size=320x240:rate=30 -t 1 \
	-c:v h264_nvenc -f null - 2>&1 | grep -qiE "error|does not support"; then
	warn "NVENC 测试编码失败, 请把上面的输出贴出来"
	exit 1
fi

echo
printf '\033[1;32m✔\033[0m ffmpeg %s 已安装, h264_nvenc 测试编码通过\n' "$(ffmpeg -version 2>/dev/null | head -n1 | cut -d' ' -f1-3)"
cat <<'EOF'

   现在依赖 ffmpeg 的程序 (Kdenlive / MLT、GPU Screen Recorder、mpv、OBS 的
   ffmpeg 系编码器等) 都可以正常使用 NVIDIA 硬件编码了。

   注意:
   - 一旦发行版推送新的 ffmpeg 包, pacman 会覆盖本包, 问题会复现;
     需要重新运行 ./install.sh 或先 `downgrade`/忽略升级。
   - 卸载/还原: ./uninstall.sh
EOF
