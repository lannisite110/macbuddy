# Unsloth：从零讲明白

## 1. 它到底是什么

前面五个（Cursor、Codex、WorkBuddy、Qoder、dsh）都是 **让模型去干活的壳**。  
Unsloth **不是 Agent**。它解决的是：**怎么让开源模型在你自己的机器上训练得动、跑得动、导得出去。**

可以想成两代产品叠在同一个名字下：

1. **Unsloth 库（Python）**  
   给 NVIDIA 显卡加速微调。改 Hugging Face 那套训练流程：同样一张卡，更快、更省显存。你写训练脚本，或后来用 Studio 网页点几下。

2. **Unsloth Desktop / Studio（桌面或本地网页）**  
   给不会写脚本的人：下载模型、聊天、可选微调、导出 GGUF。Mac 上背后主要是 **llama.cpp（Metal）** 和 **MLX**（苹果自己的机器学习库），不是那套 CUDA 训练内核。

所以：在 NVIDIA 上 Unsloth 的「魔法」是训练内核；在 Mac 上你更常碰到的是「帮你把模型跑起来的壳」，速度和 Ollama 往往同一档，因为底下都是 llama.cpp 一类东西。

## 2. 它想解决什么问题

开源模型有三道坎：

- **太大**：70 亿参数的完整精度模型，一张消费级显卡塞不下  
- **训练太贵**：全量微调要把所有权重更新，显存和带宽爆炸  
- **格式太多**：训练用一份权重，手机/Mac 推理要 GGUF、MLX、Ollama……

Unsloth 的产品句：

- 训练：少显存、更快、尽量不掉精度（他们强调手写反向传播，不用「差不多就行」的近似）  
- 推理：同一应用里聊、导出、给别的工具（Ollama、llama.cpp、vLLM）接着用  
- 后来 Desktop 还加上聊天、工具调用、搜索——那是壳的功能，**不是** Unsloth 名字最初的含义

## 3. 设计概念（改衣服，不重织布）

### 模型、量化、适配器

用做衣服比喻：

- **基座模型**：整匹布，很大。完整精度像用最贵的布，占地方。  
- **量化（Q4 等）**：把布变薄，颜色稍差一点，衣服还能穿。GGUF 的 Q4 就是常见薄布。  
- **LoRA（低秩适配）**：不重织整匹布，只缝一块可拆的补丁。训练时只更新补丁，小、省。  
- **QLoRA**：布本身已经量化变薄，再缝 LoRA 补丁。消费级显卡微调几乎都靠这个。

训练结束你可以：

- 只保存小小的 LoRA 补丁，推理时再贴回基座  
- 或 **融合** 进基座，再导出成一份 GGUF 给 Ollama / llama.cpp

### 为什么 NVIDIA 上能更快更省：融合内核

GPU 最怕的不是「算得慢」，而是 **来回搬内存**。  
普通训练像：炒一勺 → 把锅端进冰箱 → 再拿出来炒下一勺。每一次进出冰箱都很贵。

Unsloth 用 **Triton**（一种写 GPU 小核的语言）手写 **融合内核**：一勺里连续干完「反量化 + 矩阵乘 + LoRA 补丁 + 激活函数」，少进出冰箱。

他们还在运行时 **打补丁（monkey-patch）**：不 fork 整个 Hugging Face。你还是 `from_pretrained`，但 `FastLanguageModel` 把注意力、RMSNorm、交叉熵、LoRA 的 forward/backward 换成自己的实现。

层次可以记三层：

1. **算子级**：单个 RMSNorm、RoPE、交叉熵写得更快  
2. **层级数**：基座矩阵乘和 LoRA 补丁一次算完  
3. **模型级**：把 Hugging Face 某类模型的 `forward` 换成优化版  

### Mac 上完全是另一条河

苹果芯片是 **统一内存**（CPU/GPU 共用一池 RAM），没有独立的大 NVIDIA 显存。  
CUDA Triton 内核 **不能** 原样搬到 M5。

Mac 上常见两条推理河：

- **llama.cpp + Metal**：GGUF 文件，Ollama / LM Studio / Unsloth Desktop 都能走  
- **MLX**：苹果生态的权重格式和算子，有时更贴合 Apple Silicon  

Desktop 的意义是：帮你选量化档、估还能留多少内存给「上下文长度」、避免一次加载把 16GB 撑死。  
**训练** 在 16GB Mac 上非常受限：可以拿 MLX 做很小的 LoRA 实验，不要指望复现 NVIDIA 上 7B QLoRA 的舒适度。

## 4. 系统拆成哪些积木

### A. 训练库（NVIDIA 主场）

1. 用 `FastLanguageModel.from_pretrained(..., load_in_4bit=True)` 加载量化基座  
2. `get_peft_model` 注入 LoRA，目标模块一般是注意力和 MLP 的投影层  
3. 数据集 → Hugging Face TRL 的 `SFTTrainer`（监督微调）或他们支持的 RL 训练器  
4. 保存适配器，可选融合，导出 GGUF / 其他格式  

数据流：你的 jsonl 对话 → 拼成 token → 前向 → 损失（他们优化过交叉熵）→ 只对 LoRA 小矩阵反向 → 优化器更新补丁。

### B. Desktop 壳（跨平台）

公开描述里 Desktop 是独立应用（Mac/Windows/Linux），能力包括：模型中心下载、聊天、可选无代码训练、导出、本机 OpenAI 兼容 API、有时还带工具调用/搜索。  
对 MacBuddy 而言，它就是 **另一种本地模型供应商**，和 Ollama 并列，不是另一种 Agent 框架。

### C. 你真正要对接的接口

任何壳（MacBuddy、Cursor、dsh）要「用 Unsloth 跑起来的模型」，通常只需要：

- OpenAI 兼容的 `/v1/chat/completions`（Ollama、llama.cpp server、Unsloth 自带 API 都是这一类）  
- 或本地 CLI 出字流  

不需要引入 Triton，也不需要在 Swift 里加载 PyTorch。

## 5. 一次「微调」怎么走（库的路径）

```
准备几万到几十万行「问—答」或「指令—回复」（太少会过拟合乱说话）
    → 选基座（例如某个 3B/7B 指令模型）
    → 4bit 加载 + 加 LoRA
    → 训练 N 步，看损失下降、抽几条生成看像不像你的风格
    → 存 adapter
    → 导出 GGUF
    → ollama create 或 llama.cpp 加载
    → MacBuddy 的 LLM 基址仍指向 localhost，只是模型名换了
```

一次「只推理、不训练」更短：下载 Q4 GGUF → 用 Desktop 或 Ollama 聊。对 M5 16GB，要比较流畅（例如每秒二十多个 token 这种体感），公开经验是 **优先 ≤4B 的 Q4**；8B Q4 勉强；14B 以上当备用，别当默认聊天模型。

## 6. 从零开发：你要造的是哪一层？

先问自己三选一。大多数人只需要第 0 层。

**第 0 层（推荐给 MacBuddy 用户）：不要开发 Unsloth，只当运行时**  
安装 Ollama 或 Unsloth Desktop → `ollama pull` 小模型 → MacBuddy 填 `http://127.0.0.1:11434/v1`。  
你已经「用上 Unsloth 生态导出的 GGUF」了。

**第 1 层：自己做「模型管家」最小版**  
一个配置文件：模型路径、上下文长度、端口。拉起 `llama-server`，对外仍是 OpenAI 兼容 HTTP。学会 **按内存估量化档**：权重体积 + 上下文 KV 缓存 < 可用统一内存的大约 70%，留一点给系统和浏览器。

**第 2 层：最小 LoRA 训练（需要 NVIDIA 或接受 Mac 很慢/很小）**  
1. 十行 JSONL 数据集  
2. 官方 `FastLanguageModel` 示例脚本跑通  
3. 导出 GGUF  
4. 用同一提示词对比基座 vs 微调，确认真的学到了你的风格，而不是把训练损失背下来  

不要第一天写 Triton 内核。那是 Unsloth 团队按模型架构手写的，不是应用开发者的作业。

**第 3 层：Desktop 那种应用**  
等于再做一个 LM Studio：下载、磁盘管理、聊天 UI、起 API。和 Agent 循环无关，工作量是产品而不是算法。

## 7. 你不能省略的硬决定

- **训练数据隐私**：微调会把语料「揉进」补丁。公司文档不要随手拿去公有云训练。  
- **过拟合**：数据少、轮数多，模型会背答案，换个说法就不会。留几条测试题，训练时不要看见。  
- **量化档 vs 智商**：Q2 很瘦但容易胡话；Q4 是常见折中；Q8 更像原模型但更肥。16GB Mac 先选瘦的。  
- **训练设备**：想认真 QLoRA，用 NVIDIA。Mac 当 **推理和轻实验**。  
- **Agent 与模型分开**：工具循环写在 MacBuddy/dsh；模型只是 API 另一端。换 Unsloth 导出的模型不应改 Swift 业务逻辑。

## 8. 和 MacBuddy

MacBuddy 要的是 **稳定、够快、私有** 的聊天接口，不是再实现一套训练框架。

- 本机路径 B：Ollama / llama.cpp / Unsloth Desktop 提供 `/v1`  
- 小模型优先，保证菜单栏助手的体感  
- 若以后要「更像你们团队说话」：在有 GPU 的机器上用 Unsloth 库 LoRA，导出 GGUF，再拷回 Mac 用 Ollama 跑  
- 不要把 Desktop 里的聊天、搜索、MCP 再抄一遍进 MacBuddy；那些是模型应用商店，你们的差异化仍是 Mac 原生工作流 + 补丁预览
