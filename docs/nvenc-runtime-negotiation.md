# 补丁原理与维护

## 为什么需要补丁

NVENC 驱动会严格校验客户端提交的 API 版本字：

- `nvEncodeAPICreateInstance(NV_ENCODE_API_FUNCTION_LIST_VER)` —— 函数表版本字；
- `nvEncOpenEncodeSessionEx(...apiVersion=NVENCAPI_VERSION)` —— 会话 API 版本；
- 每个结构体（`NV_ENC_INITIALIZE_PARAMS.ver`、`NV_ENC_CONFIG.ver`、`NV_ENC_PIC_PARAMS_VER`……）自带 `.version` 字段。

ffmpeg 把这些值在编译期从 `nv-codec-headers` 写死进二进制。头文件是 13.1、驱动只到 13.0 时，`nvEncOpenEncodeSessionEx` 直接返回 `NV_ENC_ERR_INVALID_VERSION`，ffmpeg 打印 `Required: 13.1 Found: 13.0` 后放弃。

## 补丁怎么改的

1. **版本表**：`nvenc_api_versions[]` 逐一列出各 SDK（11.1 → 13.0）的完整版本字集合，包含 API 字、函数表、各结构体版本，以及是否带 `NVENCAPI_STRUCT_VERSION` 的最高位（`0x80000000`）。
2. **协商**：`nvenc_load_libraries()` 里调用 `NvEncodeAPIGetMaxSupportedVersion()`，取「驱动支持的最高版本 ≤ 本二进制支持的最高版本」，存进 `ctx->api_version` / `ctx->api_vers`。
3. **替换**：所有原本使用 `NVENCAPI_VERSION` / `*_VER` 宏的位置改用 `ctx->api_vers->*`；`NVENC_API_AT_LEAST(ctx, major, minor)` 用于关闭新版本才有的功能（AV1 特性、新码率控制、`init_encode_params` 布局差异等）。
4. **兼容填充**：12.2 之前 `NV_ENC_INITIALIZE_PARAMS` 比 12.2+ 大 8 字节，因此在结构体后保留 `init_encode_params_compat_pad[2]` 并保证清零，避免驱动按旧布局读取时越界。
5. **`#error` 保护**：`#if !NVENCAPI_CHECK_VERSION(13, 0) || NVENCAPI_CHECK_VERSION(13, 1)` —— 只允许用 13.0.x 头文件编译。因为结构体布局是逐字段对照 13.0.19.x 验证的，换头文件必须重新核对。

## 为什么仍然用 13.0 头文件

- Pascal/Maxwell/Volta 的驱动上限就是 13.0，13.1 的字段它们永远用不到；
- 补丁的版本表以 13.0 为「最高行」，编译期用 13.1 头文件会让 `_Static_assert` 与表项不一致（补丁有意阻止）。

代价：13.1 新增的能力（新的 AV1 参数、部分码率控制）在本包中不存在。对 580xx 驱动无实际损失。

## ffmpeg 版本升级时怎么处理

1. 改 `PKGBUILD` 的 `pkgver`（及 `sha256sums` 中 ffmpeg tarball 的哈希）；
2. `makepkg -o` 看补丁能否 `patch -Np1` 应用；
3. 若有 hunk 失败，对照 `libavcodec/nvenc.c` 新版本的对应位置手工合并——补丁改动集中在：
   - `nvenc_print_driver_requirement()` 附近（插入版本表与协商函数）；
   - `nvenc_load_libraries()`（调用协商、写入 `ctx->api_vers`）；
   - 所有 `NVENCAPI_VERSION` / `NV_ENC_*_VER` 使用点（改用表项）；
   - `libavcodec/nvenc.h`（`NvencApiVersion` 结构、`api_vers`、`api_version`、兼容填充）。
4. 上游若哪天自己实现了运行时协商（值得关注 ffmpeg 的 nvenc 相关提交），直接删掉本项目补丁即可。

## 已知副作用

- `ffmpeg -buildconf` 里 `--enable-nvenc` 依旧存在，但实际能力由运行时协商决定；
- `-v verbose` 时会多一行 `Driver supports nvenc API up to 13.0 (compiled for 13.0), ...`，可用于排错；
- 与官方包的 ABI 完全一致（同版本号编译、同 soname），其它依赖 `libavcodec.so.63` 的程序无需重编。
