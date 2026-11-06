# 后端：ASR / 翻译代理

FastAPI 服务：接收客户端 16 kHz / 单声道 / 16-bit PCM，转发给 ASR 供应商，把
partial / final 事件回推给客户端。密钥只存在本目录的 `.env`。

## 安装

```powershell
cd server
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item .env.example .env
```

国内网络如果 pypi 很慢，加镜像：

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
```

## 配置

编辑 `server/.env`：

```
ASR_PROVIDER=deepgram
DEEPGRAM_API_KEY=...
DEEPL_API_KEY=...
DEEPL_API_URL=https://api-free.deepl.com
```

没有 key 时用伪造 provider 验证链路：

```powershell
$env:ASR_PROVIDER = "fake"
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## 运行

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- `GET /health` → `{"status":"ok","asrProvider":"deepgram",...}`
- `WS  /ws/asr` → 实时识别

冒烟测试（另开一个终端）：

```powershell
.\.venv\Scripts\python.exe tools\smoke_ws.py
```

单元测试：

```powershell
.\.venv\Scripts\python.exe -m pytest
```

## 协议

客户端 → 服务端：

| 消息 | 说明 |
| --- | --- |
| `{"type":"start","sourceLanguage":"auto|zh|en|ru","sampleRate":16000,"channels":1,"encoding":"pcm_s16le"}` | 必须是首条消息，10 秒超时 |
| 二进制帧 | 16 kHz 单声道 s16le PCM，建议 20 ms（640 B）一帧 |
| `{"type":"flush"}` | 静音触发，要求立即锁定当前句子 |
| `{"type":"configure","translate":{"enabled":true,"target":"en"}}` | 翻译开关 / 目标语言（阶段 4 生效） |
| `{"type":"stop"}` | 结束会话 |
| `{"type":"ping"}` | 保活探测 |

服务端 → 客户端：

| 消息 | 说明 |
| --- | --- |
| `{"type":"ready","sessionId":"...","provider":"deepgram","sampleRate":16000,...}` | 握手完成 |
| `{"type":"partial","text":"..."}` | 临时字幕，可被覆盖 |
| `{"type":"final","id":"...","text":"...","seq":1}` | 锁定句子；`id` 用于挂翻译 |
| `{"type":"translation","id":"...","text":"...","target":"en"}` | 阶段 4 |
| `{"type":"error","message":"..."}` | 参数或上游错误 |

## 手机连接

USB 调试连接时用端口反向，避免 Windows 防火墙：

```powershell
adb reverse tcp:8000 tcp:8000
```

客户端默认 `ws://127.0.0.1:8000`，因此无需改配置。若走局域网，用
`--dart-define=WS_BASE=ws://<电脑IP>:8000` 重新构建，并放行 8000 端口。

## 目录

```
app/
├─ main.py        FastAPI 入口与 /health
├─ ws.py          WebSocket 协议与会话编排
├─ config.py      .env 配置
└─ asr/
   ├─ base.py     AsrProvider 接口
   ├─ deepgram.py Deepgram 流式实现
   ├─ fake.py     无 key 的可测试 provider
   ├─ google.py   Google 适配器骨架
   ├─ azure.py    Azure 适配器骨架
   └─ factory.py  provider 选择
```
