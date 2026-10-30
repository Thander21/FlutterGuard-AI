# Trilha de Execução: Meta Global AI Developer Hackathon (Muse Series)

> **Nota:** Este documento contém o planejamento, textos de submissão e o mapeamento dos modelos proprietários da **Meta** para o Hackathon Global de US$ 1M. Caso o projeto siga via trilha independente (Claude Code / Gemini), utilize o documento `LOCAL_AGENTS_TRACK.md`.

---

## 1. Informações do Hackathon
* **Evento:** Meta Global AI Developer Hackathon
* **Datas:** 26 de Outubro a 04 de Novembro de 2026 (Submissão até 04/Nov às 21:00 ET)
* **Premiação:** US$ 1.000.000 em dinheiro (Duas trilhas: Indie Developer e Startup)
* **Critérios de Corte:** 50% Ideia do Projeto (Clareza, Viabilidade e Fit) + 50% Habilidade Técnica Comprovada (limite de 20.000 inscrições avaliadas em fluxo contínuo).

---

## 2. Textos Oficiais para a Inscrição (Prontos para Submissão)

### Project Title
`FlutterGuard AI: Autonomous Closed-Loop & Visual Quality Harness for Flutter`

### Project Theme
`Push the Frontier (Software & Machine Intelligence)`

### Question 1: Project Idea (Clear, Feasible & Novel)
```text
The Problem:
AI-assisted software generation is broken for reactive UI frameworks like Flutter. LLMs consistently generate fragile code filled with critical regressions: leaked state lifecycles, business logic polluted inside build() trees, excessive widget rebuilds, and silent visual clipping (RenderFlex overflowed) that standard static linters cannot catch. Current AI tools act complacently—they write code and assume it works without deterministic verification.

The Solution:
FlutterGuard AI is an autonomous, reactive, and blocking quality harness that turns code generation into a closed-loop engineering pipeline specifically designed for Flutter/Dart. It enforces human-grade architectural discipline and multimodal visual verification before any line of code is committed.

How We Leverage Meta’s Models in an Integrated Pipeline:
1. Specification & Contract Engine (Meta Muse Spark):
   Translates user requirements into strict domain contracts, sealed state-machine definitions, and failing TDD/BDD unit & widget tests (RED stage) before implementation begins.

2. Iterative Autonomous Coding Agent (Meta Muse Code):
   Implements the minimal Dart code strictly constrained to satisfy the generated contracts and state boundaries.

3. Reactive AST & Execution Gate (Deterministic Local Loop):
   A blocking engine monitors Dart AST via analyzer tools to reject anti-patterns (e.g., inline controllers, missing unmount checks) and runs flutter test. If execution fails, structured error telemetry feeds directly back into Muse Code for self-correction.

4. Multimodal Visual Segmentation Gate (SAM 3.1 & Meta Muse Image):
   The breakthrough differentiator: headless widget test rendering captures UI snapshots across constrained screen resolutions (e.g., 800x600, mobile, tablet). SAM 3.1 segments UI components and bounding boxes, while Muse Image audits layout balance, detecting pixel clipping, margin collisions, and RenderFlex anomalies invisible to code compilers.

Feasibility & 10-Day Scope:
The core architecture operates as a lightweight CLI orchestrator. In 10 days, we will ship a working prototype featuring the Red/Green autonomous feedback loop with Dart AST validation and the SAM 3.1 visual segmentation gate on core Flutter widgets.
```

### Question 2: Technical Skills & Background
```text
What I Built & Current Stack:
I am developing an offline-first enterprise ERP and POS system using Flutter, Dart, Riverpod for reactive state management, and Drift/SQLite for local persistence. To accelerate feature delivery, I integrated autonomous AI coding agents (Claude, GPT, local LLMs) into my daily development workflow to assist with architecture, logic generation, and refactoring across a large-scale codebase.

The Real Challenge & Techniques Used:
While LLMs are fast at writing syntax, ensuring their generated Flutter code actually holds up in production has been a massive technical bottleneck. I constantly face recurring AI failure modes:
- Agents leaking state outside widget lifecycles or placing expensive controller instantiations inside build() methods.
- Breaking asynchronous safety and context across multi-tenant boundaries.
- Generating code that compiles without static errors, but silently breaks UI layouts (RenderFlex overflowed) or produces fake, passing tests that don't cover edge cases.

How I’ve Handled It (The Need for a Unified Framework):
To prevent AI-generated code from destabilizing the app, I had to repeatedly engineer bespoke, fragmented "mini-tools" and defensive scripts:
- Custom AST & Analysis Scripts: Wrote automated checks over Dart AST to intercept illegal layer imports and detect misplaced state logic.
- TDD Enforcement Harnesses: Built local scripts requiring failing RED tests before accepting AI implementations, forcing the model into an iterative loop.
- Defensive Rollback Hooks: Created shell/CLI validation gates that automatically revert agent changes whenever local tests or static rules fail.

The Takeaway:
This experience gave me deep hands-on expertise in Dart internals, Flutter testing harnesses, and the limits of modern LLMs. It proved that building fragmented, one-off scripts for every new AI bug is unsustainable—and directly inspired my hackathon project to unify these validations into an autonomous, closed-loop visual and architectural harness.
```

---

## 3. Mapeamento de Papéis dos Modelos da Meta

| Modelo da Meta | Papel no FlutterGuard AI | Responsabilidade Específica |
| :--- | :--- | :--- |
| **Meta Muse Spark** | Arquiteto de Especificação (SDD Engine) | Decompõe o requisito em contratos, interfaces abstratas e testes unitários/widget tests na fase **RED**. |
| **Meta Muse Code** | Engenheiro Executor de Código | Escreve a implementação mínima em Dart para satisfazer os testes. Aplica correções a partir de receitas canônicas. |
| **SAM 3.1 (Segment Anything)** | Segmentador de UI Headless | Analisa o screenshot de teste renderizado headless, detectando as caixas de colisão de cada componente na tela. |
| **Meta Muse Image** | Inspetor de Design e Integridade | Compara a segmentação do SAM 3.1 contra o contrato de layout para validar espaçamentos, cortes de texto e `RenderFlex`. |

---

## 4. Cronograma de Execução (Sprint de 10 Dias)

* **Dia 1-2:** Setup do CLI em Python/Dart e integração com as APIs da Meta (Muse Spark e Muse Code).
* **Dia 3-4:** Implementação da AST Engine com o pacote `analyzer` do Dart SDK para detecção de anti-patterns de estado e camadas.
* **Dia 5-6:** Integração do loop TDD (Red/Green) com execução de `flutter test` e injeção de receitas canônicas (*Just-in-Time*).
* **Dia 7-8:** Pipeline visual headless com exportação de frame do `WidgetTester` e segmentação via **SAM 3.1**.
* **Dia 9:** Testes integrados ponta a ponta e gravação do vídeo de demonstração (*side-by-side demo*).
* **Dia 10:** Submissão formal do projeto e documentação final.
