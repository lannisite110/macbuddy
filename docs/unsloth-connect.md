# 接入 Unsloth Desktop（本机模型）

MacBuddy **不会内嵌 Unsloth**，也不下载权重。它只做 OpenAI 兼容客户端：指向 Unsloth 的本地 API，用你在 Desktop 里已经加载的模型。

## 前提

1. 已安装并打开 [Unsloth Desktop](https://unsloth.ai/download)（Mac）。
2. 在 Unsloth 里下载并 **加载** 一个模型（例如 Gemma 4 E2B）。
3. Unsloth API 默认端口一般是 **8888**（被占用时会换端口，以 Unsloth 窗口提示为准）。

## 在 Unsloth 里创建 API Key

1. 点左下角头像 → **Settings** → **API**  
2. 起名 → **Create** → 复制一次性显示的 `sk-unsloth-…`  
3. 可选：浏览器打开 `http://127.0.0.1:8888/v1/models`（带 Header `Authorization: Bearer sk-unsloth-…`）确认模型 id

## 在 MacBuddy 里接入

1. 菜单栏 **MB → Settings → General**  
2. **Provider** 选 **Unsloth Desktop**（会填入 Base URL `http://127.0.0.1:8888/v1`）  
3. **Model** 填 Unsloth 里实际 id（可先试 `default`；不准就改成 `/v1/models` 返回的名字，例如 `unsloth/gemma-4-E2B-it-GGUF`）  
4. **API Key** 粘贴 `sk-unsloth-…`  
5. **Save** → 热键开面板发一句试试  

## 和 Ollama 的区别

| | Ollama | Unsloth Desktop |
|---|---|---|
| Base URL | `http://127.0.0.1:11434/v1` | `http://127.0.0.1:8888/v1` |
| API Key | 通常空 | 需要 `sk-unsloth-…` |
| 模型从哪来 | `ollama pull` | Desktop 模型中心下载/加载 |

两端都走同一套 `POST /v1/chat/completions`（SSE 流式）。

## 我（Agent）能不能替你「自己接入」？

- **Cloud Agent**：跑在远端，**碰不到**你 Mac 上的 Unsloth，无法替你点 Desktop、也不能读你本机已下的权重。  
- **能做的**：在 MacBuddy 加 Unsloth 预设（已做），你本机按上面 5 步保存即可。  
- 若端口不是 8888：看 Unsloth 启动日志里的实际端口，把 Base URL 改成对应的 `/v1`。

## 排错

- 连不上：先确认 Unsloth 在跑；`curl http://127.0.0.1:8888/v1/models -H "Authorization: Bearer sk-unsloth-…"`  
- 401：Key 错了或没填  
- 模型名 404：Model 字段必须和 `/v1/models` 一致  
- 很慢/OOM：16GB Mac 优先小模型（如 E2B / ≤4B Q4）
