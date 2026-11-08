# Maintainer: Eefung <eefung@tuta.io>
#
# 基于 Arch Linux 官方 ffmpeg PKGBUILD (Maintainer: Maxime Gauduin <alucryd@archlinux.org>)。
# 与官方包的两处差异:
#   1. 新增 nvenc-runtime-api-version.patch: 编译期不再写死 NVENC API 版本,
#      改为运行时与驱动协商, 使同一份 ffmpeg 能在老驱动 (570/580 系列) 上工作;
#   2. 使用 nv-codec-headers 13.0.19.1 构建 (该补丁只对 13.0 结构布局做过验证)。
#
pkgname=ffmpeg
pkgver=9.0.2
pkgrel=3.1
epoch=2
pkgdesc='Complete solution to record, convert and stream audio and video (NVENC runtime API negotiation)'
arch=(x86_64)
url=https://ffmpeg.org
license=(GPL-3.0-only)
depends=(
  alsa-lib
  aom
  bzip2
  cairo
  dav1d
  fontconfig
  freetype2
  fribidi
  glib2
  glibc
  gmp
  gnutls
  gsm
  harfbuzz
  jack
  lame
  lcms2
  libass
  libavc1394
  libbluray
  libbs2b
  libdrm
  libdvdnav
  libdvdread
  libgcc
  libgl
  libiec61883
  libjxl
  libmodplug
  libopenmpt
  libplacebo
  libpulse
  libraw1394
  librsvg
  libsoxr
  libssh
  libtheora
  libva
  libvdpau
  libvorbis
  libvpx
  libwebp
  libx11
  libxcb
  libxext
  libxml2
  libxv
  ocl-icd
  onevpl
  opencore-amr
  openjpeg2
  opus
  rav1e
  rubberband
  sdl2
  snappy
  sndio
  speex
  srt
  svt-av1
  v4l-utils
  vapoursynth
  vid.stab
  vmaf
  vulkan-icd-loader
  x264
  x265
  xvidcore
  xz
  zeromq
  zimg
  zlib
)
makedepends=(
  amf-headers
  avisynthplus
  clang
  frei0r-plugins
  git
  ladspa
  mesa
  nasm
  opencl-headers
  spirv-headers
  vulkan-headers
)
optdepends=(
  'avisynthplus: AviSynthPlus support'
  'frei0r-plugins: Frei0r video effects support'
  'intel-media-sdk: Intel QuickSync support (legacy)'
  'ladspa: LADSPA filters'
  'nvidia-utils: Nvidia NVDEC/NVENC support'
  'onevpl-intel-gpu: Intel QuickSync support'
)
provides=(
  libavcodec.so
  libavdevice.so
  libavfilter.so
  libavformat.so
  libavutil.so
  libswresample.so
  libswscale.so
)
source=(
  "https://ffmpeg.org/releases/ffmpeg-$pkgver.tar.xz"
  0001-Add-av_stream_get_first_dts-for-Chromium.patch
  nv-codec-headers-13.0.19.1.tar.gz::https://github.com/FFmpeg/nv-codec-headers/archive/refs/tags/n13.0.19.1.tar.gz
  nvenc-runtime-api-version.patch
)
sha256sums=(
  '8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e'
  'f865d677f8ad39c79dde69186629cb6468c2b289c4156dbb8dec8e68b0131b40'
  'c293161bd92dac53f2f8fab08abcd4f96773c3644a57b23c2260b4be2311ab2f'
  'SKIP'
)

prepare() {
  cd "ffmpeg-$pkgver"

  # https://crbug.com/1251779
  patch -Np1 -i ../0001-Add-av_stream_get_first_dts-for-Chromium.patch

  # 运行时 NVENC API 版本协商 (参考 gpu-screen-recorder 的补丁)
  patch -Np1 -i ../nvenc-runtime-api-version.patch
}

build() {
  # 补丁只对 nv-codec-headers 13.0.x 的结构体布局做过验证
  ( cd nv-codec-headers-n13.0.19.1 && make -s PREFIX="$srcdir/nvch" install )

  export PKG_CONFIG_PATH="$srcdir/nvch/lib/pkgconfig"
  export CFLAGS="$CFLAGS -I$srcdir/nvch/include"

  cd "ffmpeg-$pkgver"
  ./configure \
    --prefix=/usr \
    --disable-debug \
    --disable-static \
    --disable-stripping \
    --enable-amf \
    --enable-avisynth \
    --enable-cuda-llvm \
    --enable-lto \
    --enable-fontconfig \
    --enable-frei0r \
    --enable-gmp \
    --enable-gnutls \
    --enable-gpl \
    --enable-ladspa \
    --enable-lcms2 \
    --enable-libaom \
    --enable-libass \
    --enable-libbluray \
    --enable-libbs2b \
    --enable-libdav1d \
    --enable-libdrm \
    --enable-libdvdnav \
    --enable-libdvdread \
    --enable-libfreetype \
    --enable-libfribidi \
    --enable-libgsm \
    --enable-libharfbuzz \
    --enable-libiec61883 \
    --enable-libjack \
    --enable-libjxl \
    --enable-libmodplug \
    --enable-libmp3lame \
    --enable-libopencore_amrnb \
    --enable-libopencore_amrwb \
    --enable-libopenjpeg \
    --enable-libopenmpt \
    --enable-libopus \
    --enable-libplacebo \
    --enable-libpulse \
    --enable-librav1e \
    --enable-librsvg \
    --enable-librubberband \
    --enable-libsnappy \
    --enable-libsoxr \
    --enable-libspeex \
    --enable-libsrt \
    --enable-libssh \
    --enable-libsvtav1 \
    --enable-libtheora \
    --enable-libv4l2 \
    --enable-libvidstab \
    --enable-libvmaf \
    --enable-libvorbis \
    --enable-libvpl \
    --enable-libvpx \
    --enable-libwebp \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libxcb \
    --enable-libxml2 \
    --enable-libxvid \
    --enable-libzimg \
    --enable-libzmq \
    --enable-nvdec \
    --enable-nvenc \
    --enable-opencl \
    --enable-opengl \
    --enable-shared \
    --enable-vapoursynth \
    --enable-version3 \
    --enable-vulkan \
    --disable-decoder=magicyuv # pixelsmash
  make
  make tools/qt-faststart
  make doc/ff{mpeg,play}.1
}

package() {
  make DESTDIR="$pkgdir" -C "ffmpeg-$pkgver" install install-man
  install -Dm 755 "ffmpeg-$pkgver/tools/qt-faststart" "$pkgdir"/usr/bin/
}

# vim: ts=2 sw=2 et:
