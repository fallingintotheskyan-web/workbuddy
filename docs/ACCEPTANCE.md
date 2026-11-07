# 验收测试清单

每阶段完成后的可复现验证步骤，以及需要真机完成的验收项。

## 环境准备

```powershell
cd classroom-notes
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
. .\scripts\env.ps1

# 后端（真实 key）
cd server
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000

# Android 真机 USB 端口反向（客户端默认连 localhost）
adb reverse tcp:8000 tcp:8000
```

## 自动化验证（本机可跑）

```powershell
# 后端
cd server; .\.venv\Scripts\python.exe -m pytest

# 客户端
cd client; flutter analyze; flutter test; flutter build apk --debug

# 密钥扫描（必须通过）
cd classroom-notes; pwsh -ExecutionPolicy Bypass -File scripts\check_no_secrets.ps1
```

## 验收标准 ↔ 验证方法

| # | 验收标准 | 验证方法 | 状态 |
| --- | --- | --- | --- |
| 1 | 授权 RECORD_AUDIO 后 1–2 s 内出 partial，停顿后 final 锁定 | 真机 + 真实 Deepgram：说话观察 | ⏳ 待真机 |
| 2 | 静音约 1.5 s 停止送 ASR；恢复说话继续且不丢首字 | 真机：顶部状态在“正在听/已暂停”间切换 | ⏳ 待真机 |
| 3 | 关闭翻译只显示原文且无翻译 API 调用；开启后中→英/英→中/俄→中，final 后约 2 s 出译文；切目标只影响后续 | 后端 `test_translation.py`（已过）+ 真机 | 🟡 服务端已过，真机待验 |
| 4 | 待机视频循环；开始进字幕页；停止回待机；缺视频有降级 | 真机 | ⏳ 待真机 |
| 5 | 电脑端可运行同一套代码；客户端无 API Key | `flutter build windows --debug` + `check_no_secrets.ps1` | 🟡 Windows 待开发者模式 |
| 6 | 每阶段 flutter analyze / 后端测试通过 | 见上“自动化验证” | ✅ 1–4 阶段均已过 |

## 真机验证步骤（装 app-debug.apk 后）

1. 首次进入 → 授权麦克风；拒绝授权应显示错误提示而不是崩溃。
2. 待机页：视频全屏循环、静音、无控制条；点“开始录音”进入字幕页。
3. 说话 → 约 1–2 s 出现灰色斜体 partial；停 1.5 s → 变 normal 并锁定，顶部显示“已暂停”。
4. 再开口 → 回“正在听”，首字不丢。
5. 打开“翻译”→ 选目标语言；说话停顿后 2 s 内原文下方出现译文；关闭翻译后不再出现译文。
6. 杀后端 → “网络不稳”；重启后端 → 自动重连续传。
7. 点“停止录音”→ 回待机页，视频恢复播放。
8. 删除 `assets/idle/idle_loop.mp4`（或改坏 `config/idle_video.json`）→ 待机页渐变降级 + 错误提示 + 重试。
