# ffmpeg-nvenc-legacy

让 **Maxwell / Pascal / Volta**（GTX 900/10xx、Quadro M/P 系列）在 **NVIDIA 580xx 驱动** 下重新使用 **NVENC 硬件编码**——不只是 OBS，而是整条 ffmpeg 生态：**Kdenlive / MLT(melt)**、GPU Screen Recorder、mpv、HandBrake 系工具、浏览器视频编码等。

> 症状：`[h264_nvenc] Driver does not support the required nvenc API version. Required: 13.1 Found: 13.0`
> 　　Kdenlive 渲染日志：`Driver does not support the required nvenc API version... minimum required Nvidia driver for nvenc is 610.00 or newer`

## 问题本质

| | |
|---|---|
| ffmpeg 9.x | 直接用 nv-codec-headers **13.1** 的头文件编译，`NVENCAPI_VERSION`（含每个 `NV_ENC_*_PARAMS` 的 `.version` 字段）**写死在二进制里** |
| 驱动 580xx | Maxwell/Pascal/Volta 的最后一个驱动分支，最高只支持 NVENC API **13.0** |
| 610+ 分支 | 已放弃这些架构，无法靠升级驱动解决 |
| 结果 | 驱动完全有能力编码，但 ffmpeg 一开口就报「版本太新」，`nvEncodeOpenEncodeSessionEx` 直接被拒 |

降级 ffmpeg 能绕过去，但代价是丢掉 9.x 的解码器/滤镜与新特性，而且下次更新又坏。

## 本项目的做法

给 ffmpeg 打 **运行时 NVENC API 版本协商** 补丁（来自 [gpu-screen-recorder](https://git.dec05eba.com/gpu-screen-recorder) 的做法，GPL-3.0）：

- 启动时用 `NvEncodeAPIGetMaxSupportedVersion()` 问驱动「你最高支持哪版」；
- 从内置的版本表里选 **驱动与本二进制都支持的最高版本**（本机 = 13.0），按该版本填写所有结构体的 `.version` 字；
- 版本不足时自动关闭对应的新特性（`NVENC_API_AT_LEAST()` 判断），而不是整体失败；
- 结果：**一份二进制同时兼容老驱动（570/580）和新驱动**，无需降级 ffmpeg。

打包方式沿用 Arch 官方 `ffmpeg` PKGBUILD（同样的 configure 开关，功能不打折），只改两处：加补丁、改用 nv-codec-headers **13.0.19.1**（补丁只对 13.0 的结构体布局做过逐字段验证）。

## 用法

需要 Arch 系发行版（pacman / makepkg）。

```bash
git clone https://github.com/Eefung/ffmpeg-nvenc-legacy.git
cd ffmpeg-nvenc-legacy
./install.sh          # 装构建依赖 → 编译(LTO, 10-25 分钟) → pacman -U 安装 → 自测
```

装完立即生效（新进程加载新的 `libavcodec.so.63`；已打开的 Kdenlive 需要重启）。

卸载 / 还原官方包：

```bash
./uninstall.sh
```

手动构建（不用 install.sh）：

```bash
makepkg -f --nocheck --nodeps
sudo pacman -U ffmpeg-9.0.2-3.1-x86_64.pkg.tar.zst
```

## 验证

```bash
# 1. 命令行
ffmpeg -hide_banner -f lavfi -i testsrc=size=1280x720:rate=30 -t 2 \
       -c:v h264_nvenc -f null -

# 2. Kdenlive 的渲染后端 (MLT)
melt-7 color:black out=60 -consumer avformat:/tmp/nvenc-test.mp4 vcodec=h264_nvenc

# 3. 确认用的是本项目的包
pacman -Q ffmpeg          # 版本应为 2:9.0.2-3.1 (或更高 pkgrel)
ffmpeg -hide_banner -encoders | grep nvenc
```

Kdenlive 里验证：项目设置 → 渲染 → 编码器选 `h264_nvenc (NVIDIA NVENC H.264)`，渲染不再报 13.1。

## 已验证环境

| 项目 | 版本 |
|---|---|
| 发行版 | CachyOS (Arch 系), kernel 7.3.3, KDE Wayland |
| GPU | NVIDIA GeForce GTX 1060 6GB (GP106, Pascal) |
| 驱动 | nvidia-580xx 580.196.07（NVENC API 13.0） |
| ffmpeg | 9.0.2（本项目：2:9.0.2-3.1） |
| 结果 | `h264_nvenc` / `hevc_nvenc` CLI 编码通过；Kdenlive 经 melt 调用 NVENC 渲染成功 |

## 维护须知

- **发行版升级 ffmpeg 会覆盖本包**，问题复现时重新 `./install.sh` 即可（源码与补丁随仓库走，只会被重新编译一次约 15 分钟；也可以考虑 `IgnorePkg = ffmpeg`，代价是拿不到安全更新）。
- 本项目与 [obs-nvenc-legacy](https://github.com/Eefung/obs-nvenc-legacy) 互补：OBS 的 NVENC 插件自带一套头文件，不吃系统 ffmpeg；但两者都用 NVENC 13.0 能力集，可以同时安装。
- 编译期使用 13.0 头文件意味着 13.1 才有的新特性（新 AV1 参数等）不会出现在本包里；对 580xx 驱动来说这些特性本来也用不了，故无实际损失。
- 补丁对 ffmpeg 版本敏感：升级 ffmpeg 前先确认补丁能 `patch -Np1` 应用（CI 会对 pinned 版本做校验）。

## 致谢与许可

- PKGBUILD 派生自 Arch Linux 官方 `ffmpeg` 包（Maintainer: Maxime Gauduin），保留原始结构。
- NVENC 运行时版本协商补丁来自 [gpu-screen-recorder](https://git.dec05eba.com/gpu-screen-recorder)（dec05eba，GPL-3.0），仅做了上下文偏移适配。
- 本项目整体以 **GPL-3.0-only** 发布，见 [LICENSE](LICENSE)。
