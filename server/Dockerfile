# 通用 Dockerfile — 兼容 CloudBase CloudRun / Render / Koyeb / 任意容器平台
# 平台约定：通过 PORT 环境变量注入对外端口（Render=10000，Koyeb=8000，CloudRun=8000）
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

ENV PORT=8000
EXPOSE 8000

# --proxy-headers：正确识别平台反向代理后的真实协议/IP
CMD ["sh", "-c", "python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT} --proxy-headers"]
