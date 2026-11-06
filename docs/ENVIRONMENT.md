# 环境检查记录（阶段 0）

> 记录时间：2026-11-06，主机 Windows 11 build 26200 / AMD64 / 32 核。
> 结论：本机是空白开发环境，Flutter、Android SDK、JDK、Git、Visual Studio C++ 均未安装；
> 所有工具链安装到本仓库的 `.toolchains/`（已在 `.gitignore` 中忽略），可整目录删除。

## 1. 仓库状态

| 项目 | 结果 |
| --- | --- |
| 工作区 | `C:\Users\yehui\Documents\deepseek-harness\default-workspace` |
| 原有内容 | 与本项目无关的脚本、图片、HTML、docx；**没有 Flutter 工程，没有 git 仓库** |
| 本工程位置 | `classroom-notes/`（`client/` Flutter、`server/` FastAPI、`docs/`、`scripts/`） |
| 待机视频 | 已从 `C:\Users\yehui\Pictures\01ea87554ac785e64f037001a020a5ca89_309_H264.mp4` 复制为 `client/assets/idle/idle_loop.mp4`（5.04 MB, H.264） |

## 2. 工具链

| 组件 | 检查结果 | 处理 |
| --- | --- | --- |
| Flutter / Dart | 未安装，PATH 与常见目录都没有 | 下载 stable 到 `.toolchains/flutter` |
| Git | 未安装 | MinGit 便携版到 `.toolchains/git` |
| JDK | 未安装，`JAVA_HOME` 为空 | Temurin 17 zip 到 `.toolchains/jdk` |
| Android SDK | 未安装，无 `adb`、无 platform-tools | cmdline-tools 到 `.toolchains/android-sdk`，再装 platform 35 / build-tools 35 |
| Visual Studio C++ | 未安装（无 vswhere、无 Windows SDK） | **用户自行安装**，用于 Windows 桌面构建 |
| Python | DSH 内置 3.12.14，缺 fastapi/uvicorn/websockets/pytest | 阶段 2 在 `server/.venv` 安装 |
| Node.js | DSH 内置 v24.21.0 | 仅用于下载脚本，不进入产品 |
| 浏览器 | Edge 已装，Chrome 未装 | Web 预览可用 Edge |

## 3. 网络

| 目标 | 结果 |
| --- | --- |
| pypi.org | 200（pip 正常） |
| pub.dev | 200 |
| storage.googleapis.com（Flutter 发行包） | 200 |
| dl.google.com（Android SDK） | 200 |
| api.deepgram.com | 401（无 key，符合预期） |
| api-free.deepl.com | 403（无 key，符合预期） |

注意：PowerShell 5.1 在沙箱下走 schannel，`Invoke-WebRequest` / `curl.exe` 会报
`SEC_E_NO_CREDENTIALS`，所以所有下载统一用 Node 的 `fetch` 完成。

## 4. 磁盘

C: 可用 338 GB / 500 GB；工具链与 Gradle 缓存预计占用 5–6 GB。

## 5. 尚缺的配置（不阻塞阶段 1）

1. `server/.env`（从 `.env.example` 复制）：`DEEPGRAM_API_KEY`、`DEEPL_API_KEY`、
   `DEEPL_API_URL`（Free 用 `https://api-free.deepl.com`，Pro 用 `https://api.deepl.com`）。
2. Android 真机：开启 USB 调试，型号与系统版本待补充。
3. Visual Studio Build Tools（Windows 桌面构建），由用户安装。

## 6. 工具链安装结果（2026-11-06 完成）

| 组件 | 结果 |
| --- | --- |
| Flutter | 3.47.9 stable，位于 `.toolchains/flutter`，Dart 3.13.7 |
| Git | MinGit 2.56.0.4，位于 `.toolchains/git`（Flutter 版本检测依赖它） |
| JDK | Microsoft OpenJDK 17.0.21，位于 `.toolchains/jdk` |
| Android SDK | `.toolchains/android-sdk`：platform-tools 37、platforms 35/36、build-tools 35/36 |
| Android 许可 | 已全部接受 |
| Gradle 缓存 | `.toolchains/gradle`（用 init 脚本把 Google Maven 指向 dl.google.com 镜像） |
| `flutter doctor` | Flutter / Windows / Android toolchain / 设备 均通过；Chrome、Visual Studio、网络检查有警告 |

`flutter doctor` 关键输出：

```
[√] Android toolchain - develop for Android devices (Android SDK version 36.0.0)
    • All Android licenses accepted.
[!] Visual Studio - develop Windows apps (Visual Studio 生成工具 2022 17.14.44)
    X missing: MSVC v142 - VS 2019 C++ x64/x86 build tools,
               C++ CMake tools for Windows, Windows 10 SDK
```

## 7. 本机踩坑与处理（后续阶段不要重复踩）

1. **沙箱禁止管道子进程**：Flutter 调 `git`/`dart`/`java`/Gradle 都走管道，普通
   workspace-write 下会报 `CreateFile failed 5`。所有 Flutter/Gradle 命令需
   `danger-full-access` 提权执行。
2. **用户目录写入被拦**：Flutter 写 `%APPDATA%\.flutter_tool_state`、Dart 写
   `%TEMP%`、sdkmanager 写 `C:\Users\yehui\.android\cache`。`scripts/env.ps1`
   已把 `APPDATA/LOCALAPPDATA/HOME/TMP/PUB_CACHE/GRADLE_USER_HOME/ANDROID_USER_HOME`
   全部指向 `.toolchains/state`，并额外创建了 `C:\Users\yehui\.android\cache` 兜底。
3. **PowerShell 执行策略**：每个新 shell 先
   `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force` 才能 dot-source
   `scripts/env.ps1`。
4. **最新 cmdline-tools 不可用**：16111833 版换成了实验性 Android CLI，安装 SDK 时报
   `Failed to create bin dir`。改用固定版 13114758（`scripts/fetch_cmdline_tools.mjs`）。
5. **MAX_PATH**：SDK 归档内含超长路径，`Remove-Item` 删不掉；脚本改用
   `cmd /c rd /s /q "\\?\..."`。
6. **maven.google.com 不可达**：`dl.google.com/dl/android/maven2` 可用。已在
   `.toolchains/gradle/init.d/google-mirror.gradle` 中做仓库重定向（gitiignore）。
7. **GitHub API 403**：MinGit 改从 npmmirror 镜像下载。
8. **Windows 插件符号链接**：`flutter pub get` 末尾会提示需要开发者模式；Android
   构建不受影响，Windows 构建需要开启。

## 8. 需要你完成的两件事（Windows 桌面端）

1. 打开 Visual Studio Installer → 修改 “Visual Studio 生成工具 2022” → 勾选
   **使用 C++ 的桌面开发**（Desktop development with C++），右侧确保包含：
   - MSVC v143 x64/x86 生成工具（最新）
   - MSVC v142 - VS 2019 C++ x64/x86 生成工具（`flutter doctor` 明确检查这一项）
   - 适用于 Windows 的 C++ CMake 工具
   - Windows 11 SDK（10.0.22621 或更新）
2. 设置 → 系统 → 开发者选项 → 打开 **开发者模式**（插件符号链接需要）。

完成后运行 `flutter doctor -v` 应看到 Visual Studio 项变为 `[√]`，再用
`flutter run -d windows` 验证桌面端。

