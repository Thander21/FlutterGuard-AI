# Metodologia Integrada: SDD + TDD + EDD + XP + Closed-Loop

A metodologia do **FlutterGuard AI** combina o que há de mais rigoroso na engenharia de software tradicional com a velocidade dos modelos de IA, eliminando a complacência e a perda de contexto.

---

## 1. Os Quatro Pilares Metodológicos

### 1.1. SDD (Spec-Driven Development)
* **Princípio:** Nenhuma linha de código de produto pode ser escrita sem uma especificação prévia aprovada.
* **Na Prática:** O modelo começa gerando um documento de especificação (`spec.md` ou `change.md`) definindo:
  1. O que o sistema deve fazer (Requisitos e Casos Limite).
  2. Contratos de Entidade e Dados (Interfaces imutáveis).
  3. Estados possíveis do sistema (Máquina de estados modelada via `sealed class`).
* **Portão de Aprovação:** A IA não pode autoaprovar a especificação. Existe uma validação de coerência lógica antes da fase de código.

### 1.2. TDD Estrito (Test-Driven Development - Ciclo Red / Green)
* **Fase RED:** Antes de tocar na pasta `lib/` (código de produção), o agente é obrigado a criar o arquivo de teste com asserções que falham intencionalmente porque a feature ainda não existe.
* **Fase GREEN:** O agente implementa exclusivamente o código mínimo necessário para fazer os testes passarem.
* **Fase REFACTOR:** O agente limpa o código, elimina duplicações e aplica boas práticas sem quebrar a suíte verde.

### 1.3. EDD (Eval-Driven Development & Invariant Testing)
* **Princípio:** Em vez de histórias subjetivas de tela, cada regra é modelada como uma **invariante de compilador e um vetor de benchmark**:
  * `Dado` um Cubit com operações assíncronas (`await`).
  * `Quando` uma nova emissão de estado for disparada (`emit`).
  * `Então` a AST deve garantir a presença estrita da guarda `if (!isClosed) return;`.
* **Benefício:** Elimina a burocracia de personas e foca diretamente na eliminação de causas-raiz de falhas de runtime e memória.

### 1.4. XP (Extreme Programming - Práticas Ágeis de Engenharia)
* **Continuous Feedback:** O agente roda verificações locais em ciclos ultracurtos (segundos, não horas).
* **Refatoração Contínua & Código Limpo:** Cada ciclo de adição de feature exige uma passada de simplificação e remoção de boilerplate.
* **Simplicidade Extrema:** A IA é instruída a nunca criar abstrações prematuras ou antecipar requisitos que não constam na especificação.

---

## 2. O Loop Fechado Autônomo (*Closed-Loop Agentic Cycle*)

O fluxo de execução do agente opera sob um ciclo de retroalimentação contínuo:

```
[ Requisito ]
      │
      ▼
[ 1. SDD: Gera Spec + Casos BDD ]
      │
      ▼
[ 2. TDD RED: Cria testes que falham ] ◄────────────────┐
      │                                                │
      ▼                                                │
[ 3. IMPLEMENTATION: Escreve código em Dart ]          │
      │                                                │ (Se quebrar lógica)
      ▼                                                │
[ 4. DETERMINISTIC TEST RUN: flutter test ] ───────────┤
      │ (Passou?)                                      │
      ▼                                                │
[ 5. AST & STATIC GATE: dart analyze ] ────────────────┤ (Se violar regras)
      │ (Passou?)                                      │
      ▼                                                │
[ 6. MULTIMODAL VISUAL GATE: WidgetTester + Visão ] ───┘ (Se quebrar layout)
      │ (Passou?)
      ▼
[ 7. GREEN STATE & COMMIT APPROVAL ]
      │
      ▼
[ Gravação em evidence.jsonl ]
```

---

## 3. Rastreabilidade Determinística: `evidence.jsonl`

O maior problema de agentes de IA é que eles frequentemente afirmam que "tudo foi testado e está funcionando" sem terem executado nada.

O FlutterGuard AI exige **evidência material**. Para cada ciclo, o orquestrador gera entradas em `evidence.jsonl`:

```json
{"timestamp": "2026-10-14T20:40:00Z", "stage": "RED", "test_file": "test/cart_test.dart", "result": "FAILED", "failures_count": 2}
{"timestamp": "2026-10-14T20:41:30Z", "stage": "GREEN", "test_file": "test/cart_test.dart", "result": "PASSED", "failures_count": 0}
{"timestamp": "2026-10-14T20:42:00Z", "stage": "AST_ANALYSIS", "fatal_infos": 0, "status": "APPROVED"}
```

Sem essas evidências geradas pelo executável local, a esteira entra em **Fail-Closed** e recusa a entrega.
