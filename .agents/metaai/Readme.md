# Meta AI Stack: Models & Frameworks Guide
### Technology Mapping and Integration Guidelines for FlutterGuard-AI

This directory gathers in-depth technical documentation for each **Meta** AI model, tool, and framework selected for the **FlutterGuard-AI** architecture in the Meta Global Hackathon.

---

## 🏛️ Integrated Architecture Overview

**FlutterGuard-AI** runs as a closed-loop agentic harness where each Meta model owns a surgical technical responsibility, eliminating hallucinations and guaranteeing that no UI code or logic ships without deterministic and visual verification.

```
                              ┌──────────────────────────────────┐
                              │     USER / APP REQUIREMENT       │
                              └────────────────┬─────────────────┘
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ 1. META MUSE SPARK (MuseSpark.md)                                                           │
│    * SDD Architect & Contract Engineer                                                      │
│    * Generates formal specs, sealed classes, and TDD [RED] tests                             │
└──────────────────────────────────────────────┬──────────────────────────────────────────────┘
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ 2. META MUSE CODE / LLAMA 3.1 (MuseCode.md)                                                 │
│    * Dart Code Implementation Engineer                                                      │
│    * Minimal implementation to turn tests [GREEN]                                           │
│    * Fixes AST anti-patterns via canonical recipes                                          │
└──────────────────────────────────────────────┬──────────────────────────────────────────────┘
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ 3. SAM 3.1 & META MUSE IMAGE / VISION (SamSegmentAnything.md & MuseImageVision.md)          │
│    * SAM 3.1: Segments buttons, boxes, and components in the headless-rendered screenshot   │
│    * Muse Image / Vision: Audits 'RenderFlex overflowed', text breaks, and margins          │
└──────────────────────────────────────────────┬──────────────────────────────────────────────┘
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ 4. LLAMA STACK (LlamaStack.md)                                                              │
│    * Meta's standardized bus for agents, tool calling, and memory                           │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 📚 Study Documents Index

1. **[01. Meta Muse Spark](MuseSpark.md):** Contract-driven specification (SDD), architectural reasoning, and TDD RED-stage generation.
2. **[02. Meta Muse Code](MuseCode.md):** Advanced Dart 3 syntax, minimal implementation, and AST-assisted self-healing.
3. **[03. SAM 3.1 (Segment Anything)](SamSegmentAnything.md):** GUI component segmentation, bounding boxes, and layout collision detection.
4. **[04. Meta Muse Image & Vision](MuseImageVision.md):** Multimodal screen audit, `RenderFlex overflowed` detection, and widget aesthetic validation.
5. **[05. Llama Stack](LlamaStack.md):** Unified agent orchestration protocol, tool calling, and client/server integration.

---

## 🎯 Quick Prep Roadmap (Pre-Hackathon)

* [ ] Understand the structured JSON prompt format for **Muse Spark**.
* [ ] Test local scripts with the Dart AST analyzer (`analyzer` package) to feed **Muse Code**.
* [ ] Practice sending images via API to **SAM** and extracting segmentation masks.
* [ ] Set up headless Flutter tests that save screenshots as PNG via `WidgetTester`.
