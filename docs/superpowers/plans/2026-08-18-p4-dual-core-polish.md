# P4 Dual-Core Polish — Plan

**Goal:** Incremental index (toggle off by default), workflow templates, PluginHost, optional account quota, perf regression suite.

**Shipped:**
- `IncrementalIndex` in CodeEngine (persisted path+mtime, off by default)
- `PluginHost` — manifest + SHA256 validation, zero plugins by default
- `WorkflowTemplates` — 4 built-in workflows, menu + Settings tab
- `FeatureSettings` — index toggle, account email, monthly quota
- `Scripts/perf/regression.sh` — all package tests + build + launch bench
