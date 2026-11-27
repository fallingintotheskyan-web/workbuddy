# 免费部署指南（Koyeb / Render）

> 背景：CloudBase 云托管体验版免费期 7 天，到期后服务被隔离（`SERVICE_FORBIDDEN: server is isolated`），
> 导致前端卡在「连接中」。本指南把后端迁到**真正免费的海外平台**，支持 WebSocket 长连接。
> 前端仍托管在 CloudBase 静态托管（不受影响，2026-11-27 复测 HTTP 200）。

## 架构

```
浏览器 (CloudBase 静态托管, HTTPS)
   │  wss://<你的服务域名>
   ▼
Koyeb / Render 免费容器 (FastAPI + WebSocket, Dockerfile 部署)
   │
   ├── Deepgram (流式 ASR)
   └── DeepL (翻译)
```

密钥通过平台的环境变量注入，**不进代码、不进 Git**（`server/.env` 已在 .gitignore / .dockerignore 中）。

---

## 第 0 步：把代码推送到 GitHub

仓库：`https://github.com/fallingintotheskyan-web/workbuddy.git`，分支 `main`。

```powershell
cd "C:/Users/yehui/Documents/deepseek-harness/default-workspace/classroom-notes"
git add -A
git commit -m "add free deployment configs"
git remote add origin https://github.com/fallingintotheskyan-web/workbuddy.git
git push -u origin main
```

> 2026-11-27：`git add` / `git commit` / `git remote add` 已由 WorkBuddy 完成（本地提交），
> 只需执行最后一条 `git push -u origin main`，会弹出 Git Credential Manager 让你登录 GitHub。
>
> `.gitignore` 已加固：`**/.env`、`**/.env.*`、`!**/.env.example`、`**/.venv/`；
> `.toolchains/`、`client/build/`、`submission/` 也都被忽略 —— 真实密钥与 4G 工具链不会入库。

---

## 方案 A：Koyeb（推荐，免费实例不休眠）

1. 打开 https://app.koyeb.com ，用 GitHub 账号注册登录。
2. **Create Service** → **GitHub** → 授权后选择 `workbuddy` 仓库。
3. Builder 选择 **Dockerfile**，路径 `server/Dockerfile`，Docker context 填 `server`。
4. **Environment variables** 添加（与 `server/.env` 一致）：
   - `DEEPGRAM_API_KEY` = 你的 key（标记为 Secret）
   - `DEEPL_API_KEY` = 你的 key（标记为 Secret）
   - 其余变量 `config.py` 已有默认值，可不填
5. **Instance** 选 **Nano (Free)**；Region 选 **Singapore**（离国内最近）。
6. **Port** 保持 `8000`，Health check 路径填 `/health`。
7. 部署完成后得到域名：`https://<app>-<org>.koyeb.app`
8. 验证：`curl https://<你的域名>/health` 应返回 `{"status":"ok",...}`

> Koyeb 免费档：1 个常驻 Nano 实例（512MB），**不休眠**，含 100GB 流量/月，支持 WebSocket。

## 方案 B：Render（当前采用，已手动创建服务 `workbuddy`）

在 Dashboard → `workbuddy` → **Settings** 配置：

| 设置项 | 值 | 说明 |
| --- | --- | --- |
| Environment / Runtime | **Docker** | 必须是 Docker，不是 Python 原生环境 |
| **Root Directory** | `server` | ⚠️ 关键：Dockerfile 里 `COPY requirements.txt .` 相对构建上下文，必须让上下文 = `server` |
| **Dockerfile Path** | `Dockerfile` | ⚠️ Render 的 Dockerfile 路径**相对于 Root Directory**；不要填 `server/Dockerfile`（会变成 `server/server/Dockerfile`） |
| **Docker Build Context** | `.`（默认） | 同样相对 Root Directory |
| Health Check Path | `/health` | |
| Region / Instance | Singapore / Free | |

**Environment 环境变量**（只需 3 个，其余 `server/app/config.py` 均有默认值）：

| Key | Value |
| --- | --- |
| `DEEPGRAM_API_KEY` | 从 `server/.env` 复制真实值，标记为 Secret |
| `DEEPL_API_KEY` | 从 `server/.env` 复制真实值，标记为 Secret |
| `PORT` | `10000`（防呆；Dockerfile 的 CMD 用 `${PORT}` 启动 uvicorn） |

> ⚠️ 密钥只在 Render 控制台填，**不要**写进 `render.yaml`、代码或 Git。
> 手动创建的服务不会读取仓库根目录的 `render.yaml`；若 Render 弹出 "Blueprint detected / Sync"，
> 不要点同步，否则会另建一个名为 `classroom-notes-api` 的服务。

**触发重新部署**：Settings 保存后通常会自动部署；也可在服务页右上角
**Manual Deploy → Deploy latest commit**（或左侧 **Deploys** 页）。
在 Deploys → Logs 里等到 `Application startup complete` / `Uvicorn running on ...`。

**验证**：`curl https://<你的域名>.onrender.com/health` → `{"status":"ok",...}`

> ⚠️ Render 免费档 **15 分钟无流量会休眠**，下次连接冷启动 30-60 秒（前端会自动重连，但首次等待明显）。
> 规避：用 https://cron-job.org 每 10 分钟 GET 一次 `/health`（免费，在 750 小时/月额度内）。
> 若课堂实测无法接受冷启动，改用方案 A Koyeb（不休眠）。

---

## 第 2 步：重新打包前端（必须）

后端地址是构建期编译进前端的（`--dart-define=WS_BASE`），拿到新域名后执行：

```bash
cd "C:/Users/yehui/Documents/deepseek-harness/default-workspace/classroom-notes"
TC="$PWD/.toolchains"
export FLUTTER_ROOT="$TC/flutter" PUB_CACHE="$TC/pub-cache" \
  APPDATA="$TC/state/Roaming" LOCALAPPDATA="$TC/state/Local" HOME="$TC/state/Home" \
  TMP="$TC/state/Temp" TEMP="$TC/state/Temp" PATH="$TC/flutter/bin:$TC/git/cmd:$PATH"
cd client
flutter build web --release --dart-define=WS_BASE=wss://workbuddy.onrender.com
```

> ⚠️ **WS_BASE 只填域名，绝对不要带 `/ws/asr`**！
> `client/lib/core/app_config.dart` 的 `asrEndpoint` 会自动拼 `'${base}/ws/asr'`。
> 若填了完整路径，会变成 `wss://xxx.onrender.com/ws/asr/ws/asr`，连接必然失败。

## 第 3 步：上传前端到 CloudBase 静态托管

```powershell
# 在含 config/mcporter.json 的工作区目录执行，或让 WorkBuddy 代劳：
npx mcporter call cloudbase.manageHosting --args '{"action":"upload","localPath":"C:/Users/yehui/Documents/deepseek-harness/default-workspace/classroom-notes/client/build/web","cloudPath":"/","isDir":true}' --output json
```

前端地址不变：https://educational-cheetah-d0bsf4e3c3a6-1527509554.tcloudbaseapp.com/

> 拿到新后端域名后，也可以直接把域名发给 WorkBuddy，让它一键完成「构建 + 上传」。

---

## 验证清单

1. `curl https://<后端域名>/health` → `{"status":"ok","asrProvider":"deepgram",...}`
2. 浏览器打开前端 → 开始录音 → 状态从「连接中」变为「正在聆听」并出现字幕
3. 打开翻译开关 → 字幕下方出现译文

## 故障排查

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| 一直「连接中」 | 后端没起来 / 域名填错 / Render 冷启动中 | 先 curl /health；Render 等 60s 重试 |
| 构建报 `requirements.txt not found` | Root Directory 设错或 Docker context 不对 | 按方案 B 表格改回 `server` / `Dockerfile` / `.` |
| 连上但无字幕 | Deepgram key 失效或额度用尽 | 看平台日志（Koyeb/Render 控制台 Logs） |
| 有字幕无翻译 | DeepL key 问题 | 同上，日志里有 `translation failed` |
| 手机浏览器无声音采集 | 未授权麦克风或非 HTTPS | 平台域名自带 HTTPS，检查浏览器权限 |
