# 05. Llama Stack
### Agent Standardization, Tool Calling, Memory, and Orchestration

---

## 1. What Is Llama Stack?
**Llama Stack** is Meta's official set of specifications and standardized APIs for the generative-AI ecosystem. It solves AI code fragmentation with a unified interface for:
* **Model Inference:** Provider-agnostic abstraction for running Llama/Muse models locally or via cloud providers.
* **Tool Calling:** Standardized deterministic function calls.
* **Memory & RAG:** Vector and context-retrieval management.
* **Safety & Guardrails:** Native layer with Llama Guard to filter hallucinations and unsafe responses.

---

## 2. Specific Role in FlutterGuard-AI
In FlutterGuard-AI, Llama Stack acts as the **Central Agentic Connectivity Bus**:
1. **Harness Tool Standardization:** Instead of ad-hoc proprietary integrations, FlutterGuard tools (e.g. `run_flutter_test`, `analyze_dart_ast`, `capture_widget_screenshot`) are exposed as formal tools under the Llama Stack Tool Calling standard.
2. **Provider-Agnostic Integration:** Lets FlutterGuard run both against Meta cloud APIs provided during the Hackathon and against local Llama 3 instances via Ollama or vLLM in the local dev environment.
3. **Safety Guardrails (Llama Guard):** Stops the model from generating vulnerable code with unsafe data injection or mishandled client credentials in Flutter.

---

## 3. Llama Stack Architecture in FlutterGuard-AI

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTERGUARD CLI (ORCHESTRATOR)          │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                LLAMA STACK CLIENT / RUNTIME                 │
│  ├── Tool Calling: run_flutter_test(), check_ast()          │
│  ├── Memory: failure history and canonical recipes          │
│  └── Safety: Llama Guard                                    │
└──────────────┬───────────────────────────────┬──────────────┘
               │                               │
               ▼                               ▼
    [ Meta Cloud Models ]        [ Local Models (Llama 3) ]
```

---

## 4. Hands-On Study Roadmap

1. **Llama Stack Concepts:**
   * Read Meta's official Llama Stack docs and the tool-calling specification.
2. **Tool Implementation (Tool Calling):**
   * Study how to declare function schemas in JSON so Meta models know exactly when to trigger a terminal test run.
3. **Hybrid Fallback (Cloud ➔ Local):**
   * Prepare the environment so that if cloud API latency spikes during the hackathon, you can switch FlutterGuard to a local endpoint under the same call contract.
