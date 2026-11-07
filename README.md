# 课堂速记（Classroom Live Notes）

课堂实时录音 → 流式字幕 → 可选翻译的跨平台 App。Flutter 客户端（Android / Windows），
FastAPI 负责代理 ASR 与翻译，密钥只存在后端 `.env`。

> 当前进度：**阶段 4 已完成**（翻译开关、目标语言切换、DeepL final-only 翻译 + 缓存、译文 UI）。
> Deepgram / DeepL 均已用真实 key 端到端自测通过。阶段 5 收尾（指标日志、README、验收清单、密钥扫描）。

## 目录

```
classroom-notes/
├─ client/                 Flutter 客户端
│  ├─ lib/
│  │  ├─ config/           待机视频配置解析
│  │  ├─ core/             主题、全局常量
│  │  ├─ features/idle/    待机页（循环静音视频）
│  │  ├─ features/recording/ 录音页（状态、字幕、翻译开关）
│  │  ├─ models/          语言、字幕行、会话状态
│  │  └─ state/           字幕控制器、会话接口、演示会话
│  ├─ assets/idle/         idle_loop.mp4（待机视频）
│  ├─ config/idle_video.json
│  └─ test/               单元测试与 widget 测试
├─ server/                 FastAPI 后端（阶段 2 起填充）
├─ scripts/                工具链下载 / 安装 / 环境脚本
└─ docs/                   环境记录等
```

## 环境与工具链（本机自包含）

所有工具链安装在仓库内的 `.toolchains/`（已 gitignore），无需管理员权限，可整目录删除重建。

```powershell
cd classroom-notes
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\scripts\install_toolchains.ps1    # 首次：解压 Flutter/JDK/MinGit，安装 Android SDK
. .\scripts\env.ps1                 # 每个新终端：把工具链放进 PATH，并重定向状态目录
```

`env.ps1` 会把 `APPDATA/LOCALAPPDATA/TMP/PUB_CACHE/GRADLE_USER_HOME` 等全部指向
`.toolchains/state`，避免 Flutter/Dart/Gradle 写入仓库外被文件沙箱拦截。

已固定的版本：Flutter 3.47.9（Dart 3.13.7）、Temurin/Microsoft JDK 17、Android platform 35/36。

## 运行

先起后端（无 key 时用 fake provider 验证链路）：

```powershell
cd server
Copy-Item .env.example .env     # 首次：填入 DEEPGRAM_API_KEY / DEEPL_API_KEY
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
# 没有 key：$env:ASR_PROVIDER = "fake" 后再启动
```

再起客户端（USB 真机先 `adb reverse tcp:8000 tcp:8000`，客户端默认连 localhost）：

```powershell
. .\scripts\env.ps1
cd client
flutter pub get
flutter run -d <android-id>     # adb devices 查看
flutter run -d windows          # 需要 Visual Studio C++ 工具链 + 开发者模式
flutter build apk --debug

# 局域网访问后端（不放行防火墙时用上面的 adb reverse 即可）
flutter run --dart-define=WS_BASE=ws://192.168.1.20:8000
# 不连后端、只看 UI：
flutter run --dart-define=DEMO=true
```

> **Windows 桌面端前置条件（需你手动完成）**
> 本机已装 “Visual Studio 生成工具 2022”，但缺少 C++ 组件，请在 Visual Studio Installer 中
> 修改安装并勾选 **使用 C++ 的桌面开发**，确认包含：MSVC v143、MSVC v142（VS 2019 生成工具）、
> 适用于 Windows 的 C++ CMake 工具、Windows 11 SDK。另需打开
> 设置 → 系统 → 开发者选项 → **开发者模式**（Flutter 插件需要符号链接权限）。
> 未满足时 `flutter analyze` / `flutter test` / Android 构建都不受影响，仅 Windows 构建不可用。

构建网络：本机 `maven.google.com` 不可达，`scripts/install_android_sdk.ps1` 与
`.toolchains/gradle/init.d/google-mirror.gradle` 已把 Google Maven 重定向到
`https://dl.google.com/dl/android/maven2`。换机器构建时如遇同样问题，把该 init 脚本
复制到对应 `GRADLE_USER_HOME/init.d/` 即可。

## 待机视频

`client/config/idle_video.json` 支持两种来源：

```json
{ "type": "asset", "value": "assets/idle/idle_loop.mp4" }
{ "type": "url",   "value": "https://example.com/loop.mp4" }
```

当前仓库内置的 `assets/idle/idle_loop.mp4` 来自
`C:\Users\yehui\Pictures\01ea87554ac785e64f037001a020a5ca89_309_H264.mp4`（5.04 MB, H.264）。
**替换待机视频**：覆盖该文件，或把 `idle_video.json` 改成 `url` 类型。
文件缺失时待机页自动降级为渐变背景并显示可重试的错误提示，不会崩溃。

视频行为：全屏 `BoxFit.cover`、循环、静音、无控制条；开始录音时暂停，返回待机页恢复播放。

## 输入输出约定（阶段 2 起）

- 音频：16 kHz、单声道、16-bit little-endian PCM，20 ms 一帧（640 字节）。
- 握手：`start` → 二进制帧 → `flush`（静音锁定句子）→ `stop`，控制消息为 JSON。
- 服务端回推：`ready / partial / final / translation / status / error / metrics`。
- 翻译只对 `final` 调用；关闭开关时服务端直接短路，不产生翻译请求。
- 客户端源码中不允许出现任何 API Key；`server/.env.example` 提供模板。

## 安全

- 密钥仅存于 `server/.env`（已 gitignore）。
- 仓库内提供密钥扫描脚本（阶段 5 固化到验收流程）。
- 手机连本机后端推荐 `adb reverse tcp:8000 tcp:8000`，避免 Windows 防火墙放行。

## 阶段计划

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| 0 | 环境检查、工具链、待机视频落地 | ✅ |
| 1 | Flutter 壳、待机视频页、录音页 UI 状态切换 | ✅ |
| 2 | 16 kHz PCM 采集、WebSocket 代理、Deepgram partial/final | ✅ |
| 3 | VAD 静音暂停、300 ms 预缓冲、断线重连 | ✅ |
| 4 | 翻译开关 / 目标语言 / DeepL / final-only 缓存 | ✅ |
| 5 | 指标日志、README、验收清单、密钥扫描 | ⏳ |

## 已知限制

- 阶段 1 的字幕来自演示会话，不是真实识别结果（页面有“演示数据”角标）。
- Google / Azure ASR 适配器目前只是接口占位，尚未联调。
- macOS / Linux 未在本机验证；Windows 桌面端依赖上面的 VS 与开发者模式。
