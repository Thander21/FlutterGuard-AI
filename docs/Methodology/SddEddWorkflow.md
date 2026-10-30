# Fluxo Operacional Integrado SDD + EDD: OpenSpec AST & Eval-Driven Development
### Guia de Engenharia Determinística, Orientada a Benchmarks, Invariantes de AST e Skills Agênticas para o FlutterGuard-AI

> **Objetivo:** Estabelecer uma esteira de engenharia rigorosa e reproduzível que substitui cerimônias ágeis subjetivas por **Spec-Driven Development (SDD via OpenSpec adaptado para AST)**, **Test-Driven Development (TDD via Dart Analyzer)**, **Eval-Driven Development (EDD via Pares Golden de Benchmark)** e **Quality Gates Bloqueantes** integrados à **Llama Stack** e orquestrados por **Agent Skills**.

---

## 1. Por que SDD + EDD em vez de User Stories?

O **FlutterGuard-AI** é um harness de qualidade para compiladores, AST e testes headless. Ele lida com integridade estrutural de software e detecção de anti-padrões, não com personas de negócios.

| Paradigma Antigo (User Stories / BDD de Tela) | Novo Paradigma (OpenSpec + EDD Benchmark) | Vantagem no FlutterGuard-AI |
| :--- | :--- | :--- |
| Persona fictícia ("Como usuário quero...") | **Invariante Formal de Compilador / AST** | Ataca a causa-raiz estrutural do código Dart. |
| Critério de aceite em prosa subjetiva | **Contrato OpenSpec (YAML + nós da AST)** | Validação computacional sem ambiguidades. |
| BDD de interface ("Dado que clico...") | **Pares Golden de Benchmark (`.bad` / `.good`)** | Teste empírico real contra bugs clássicos de IA. |
| Cerimônias e reuniões simuladas | **Ciclo de Avaliação Contínuo (*Eval Loop*)** | Máxima velocidade e foco em código para o Hackathon. |
| Aprovação subjetiva de produto | **Grader Determinístico (*Pass/Fail*)** | 100% reproduzível e auditável pelos jurados da Meta. |

---

## 2. A Tríade de Engenharia do Fluxo

O desenvolvimento de cada regra de proteção e auto-recuperação do FlutterGuard-AI segue 3 pilares técnicos interdependentes:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. OPENSPEC CONTRACT (docs/specs/TS-NN-slug.md)                            │
│    - Metadados formais em YAML (Schema OpenSpec-AST)                        │
│    - Contrato inviolável da AST (Ex: nós MethodInvocation, ClassDeclaration) │
│    - Invariante formal (Ex: "Todo AnimationController deve ter .dispose()") │
│    - Receita Canônica de Autocura (Before/After em Diff Unificado)          │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 2. GOLDEN EVAL VECTORS (benchmark/vectors/TC-NN_slug.{bad,good}.dart)        │
│    - Vetor Negativo (.bad.dart): código Dart com o bug real (score = 0%)     │
│    - Vetor Positivo (.good.dart): código canônico que NÃO pode ter falsos    │
│      positivos (score = 100%)                                               │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 3. AST VISITOR, LLAMA AUTOCURA & DETERMINISTIC GRADER                       │
│    - TDD em memória (< 50ms): Teste unitário do RecursiveAstVisitor         │
│    - Llama Stack / Meta Muse aplica o patch da Receita Canônica             │
│    - Grader: executa dart analyze + flutter test em sandbox                 │
│    - Gravação da prova em evidence.jsonl (Status: Fail-Closed)              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Padrão OpenSpec para AST (Template de Especificação)

Todas as regras técnicas residem em `docs/specs/TS-NN-slug.md` e seguem o padrão **OpenSpec estendido para Invariantes de AST**:

```markdown
---
spec_version: "openspec-1.0"
id: "FG-BLOC-001"
title: "Guarda obrigatória de isClosed em emissões assíncronas de Cubit/Bloc"
status: "approved"
severity: "error"
ast_nodes:
  - "MethodInvocation[name='emit']"
  - "AwaitExpression"
invariant: "Todo 'emit' precedido por 'await' dentro de uma subclasse de BlocBase DEVE possuir a guarda 'if (!isClosed) return;' imediatamente antes da chamada."
golden_vectors:
  failing: "benchmark/vectors/TC-01_bloc.bad.dart"
  passing: "benchmark/vectors/TC-01_bloc.good.dart"
auto_heal_strategy: "insert_before_invocation"
---

# 1. Diagnóstico do Anti-Padrão
Emissões de estado após o descarte do Cubit disparam `StateError` silencioso em produção quando a tela é fechada enquanto a requisição HTTP ainda está em trânsito.

# 2. Receita Canônica de Autocura (Before / After)
```diff
- await repository.saveData();
- emit(SuccessState());
+ await repository.saveData();
+ if (!isClosed) return;
+ emit(SuccessState());
```

# 3. Casos de Borda e Não-Conformidade
- Blocos `try/catch/finally` contendo `await` dentro do bloco `try`.
- Métodos auxiliares privados invocados de dentro do handler.
```

---

## 4. O Ciclo de Desenvolvimento (Inner Loop de 5 Passos)

Para cada nova regra de guarda implementada no FlutterGuard-AI:

```
[1. OpenSpec RFC] ➔ [2. Pares Golden (.bad / .good)] ➔ [3. TDD no AST Visitor]
                                                               │
                                                               ▼
[5. Grader & evidence.jsonl] ◄── [4. Autocura via Llama Stack] ┘
```

1. **Definição da Spec (`docs/specs/`):**
   * Criar a RFC técnica com o schema OpenSpec.
   * Identificar quais nós do `package:analyzer/dart/ast/ast.dart` serão interceptados.
2. **Criação do Par Golden no Benchmark (`benchmark/vectors/`):**
   * `TC-NN.bad.dart`: Código Dart funcional porém violando o invariante.
   * `TC-NN.good.dart`: Código idêntico após aplicação manual da receita canônica.
3. **TDD do AstVisitor (`packages/flutterguard_core/test/`):**
   * Escrever o teste unitário:
     - Deve acusar violação no `.bad.dart`.
     - NÃO deve acusar violação no `.good.dart` (Zero Falsos Positivos).
   * Implementar o `RecursiveAstVisitor` no analisador até os testes ficarem verdes em < 50ms.
4. **Disparo da Autocura com a Llama Stack:**
   * O harness fornece ao modelo (Meta Muse Code / Llama 3) o código violador + a receita canônica.
   * O modelo gera o patch em diff unificado e aplica no arquivo.
5. **Execução do Grader Determinístico & Telemetria:**
   * O harness executa `dart analyze` e a suíte de testes.
   * Grava os metadados e hashes em `evidence.jsonl`. Se falhar, reverte imediatamente (*Fail-Closed*).

---

## 5. Operacionalização por Skills Agênticas (`.agents/skills/`)

Em vez de instruções manuais e propensas a esquecimento, o fluxo é orquestrado por **Agent Skills especializadas**:

```
.agents/skills/
├── flutterguard-spec/      # Skill: Gera e valida o contrato OpenSpec-AST (*spec)
├── flutterguard-vector/    # Skill: Cria pares Golden .bad e .good no benchmark (*vector)
├── flutterguard-visitor/   # Skill: TDD do Visitor no Dart Analyzer (*visitor)
└── flutterguard-grader/    # Skill: Executa Grader e telemetria evidence.jsonl (*grade)
```

| Papel / Skill | Comando no Chat | Responsabilidade Técnica |
| :--- | :--- | :--- |
| **Guardião SDD** | `*spec [nome-da-regra]` | Redige a especificação OpenSpec e valida completude dos campos obrigatórios. |
| **Guardião EDD** | `*vector [TS-NN]` | Gera os arquivos `.bad.dart` e `.good.dart` com casos de borda reais. |
| **Motor Dart TDD** | `*visitor [TS-NN]` | Cria o teste unitário e implementa o `RecursiveAstVisitor` em Dart. |
| **Runner Grader** | `*grade [TS-NN]` | Executa o loop de autocura com Llama Stack e valida evidência em `evidence.jsonl`. |

---

## 6. Stack Tecnológica de Aceleração

Para garantir desenvolvimento ágil e sem dependências pesadas:

* **TDD & AST em Memória:** `package:test` + `package:analyzer` (executa análise sintática em < 50ms sem build_runner).
* **Mocks Type-Safe:** `package:mocktail` (zero geração de código).
* **CLI e Ferramental:** `package:args` para comandos UNIX (`flutterguard analyze`, `flutterguard init`).
* **Servidor MCP Nativo:** `package:json_rpc_2` + `stream_channel` (conecta o harness ao Antigravity, Cursor e Claude Code via stdio).
* **IA & Autocura:** Protocolo **Llama Stack** e modelos Meta AI (Meta Muse Spark, Meta Muse Code e SAM 3.1 para auditoria visual).

---

## 7. Comandos MCP do Servidor `flutterguard`

Quando conectado à IDE via MCP, o agente utiliza ferramentas dedicadas:

| Momento do Fluxo | Ferramenta MCP Acionada | Efeito / Ação |
| :--- | :--- | :--- |
| **Após alterar código Dart** | `flutterguard.analyze_ast` | Captura violações sintáticas e invariantes contratuais. |
| **Em caso de violação** | `flutterguard.get_canonical_recipe` | Recupera a receita Before/After sem alucinação. |
| **Em widgets de tela/layout** | `flutterguard.verify_viewport` | Estressa a UI em modo headless com teclado aberto (320px). |
| **Após criar/alterar testes** | `flutterguard.run_mutation_check` | Sabota operadores lógicos (`>`, `==`, `true`) para expor mocks complacentes. |
| **Auditar Telemetria** | `flutterguard.get_telemetry` | Emite logs estruturados de `evidence.jsonl` com hashes determinísticos. |
