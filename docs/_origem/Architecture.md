# Arquitetura do Sistema: FlutterGuard AI
### Engenharia Pragmática, Determinística e Multimodal para o Hackathon Meta

> **Nota de escopo (v0):** somente §2.2 (regras `FG-BLOC-001`, `FG-RIV-001` e
> `FG-ST-001`, via comandos `grade` e `check`) está implementado. MCP (§3),
> caos (§2.3), visual (§2.4), autocura (§2.5), playground (§6) e instalação
> (§7) estão **[PLANEJADO]**. `docs/` registra intenção; `specs/` é normativo.
> `grade` avalia este repo (dev-loop local); `check` é o gate portátil.

## 1. Visão Arquitetural

O **FlutterGuard AI** é projetado como uma esteira autônoma e reativa em pacote único (*Single Package*), combinando a velocidade de execução do compilador Dart local com o poder de raciocínio e visão multimodal dos modelos de IA da Meta:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   FLUTTERGUARD AGENTIC HARNESS                         │
│                                                                        │
│  1. TECH SPEC & RFC PHASE (Contrato de Invariantes & AST)              │
│     Invariantes de Nó, Estados Exaustivos e Vetor de Teste RED         │
│                                                                        │
│  2. DETERMINISTIC AST & STATE GATE (Dart Analyzer & Rules)             │
│     Inspeção estática: Ciclo de vida, Bloc/Cubit e Riverpod            │
│                                                                        │
│  3. MUTATION CHAOS GATE (Sabotagem de 3 Operadores contra Mocks Falsos)│
│     Inversão cirúrgica de operadores (>, ==, booleans) no sandbox      │
│                                                                        │
│  4. TWO-TIER VISUAL GATE (Nativo Local + Meta AI Multimodal)           │
│     Tier 1: Interceptação nativa de RenderFlex / Geometria (0 tokens)  │
│     Tier 2: Auditoria Visual via SAM 3.1 e Muse Image no Benchmark     │
│                                                                        │
│  5. FEEDBACK & AUTO-HEALING LOOP (Just-in-Time Canonical Recipes)      │
│     Injeção cirúrgica de receita Before/After + Rollback via Git       │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Subsistemas Detalhados

### 2.1. Spec-Driven Development Engine (Tech Specs & Invariantes)
* **Objetivo:** Impedir que o modelo de IA comece escrevendo a tela ou o código final sem contrato formal.
* **Mecanismo:** 
  1. A IA decompõe a demanda em **Contratos de Dados** (Entities/DTOs imutáveis) e **Máquinas de Estado** (`sealed class` exaustivas no Dart 3).
  2. É gerada uma suíte de testes unitários que falham intencionalmente (**Fase RED**).
  3. A esteira grava o estado inicial no log de telemetria `evidence.jsonl`.

### 2.2. AST & State Management Governance (Dart Analyzer Harness)
* **Objetivo:** Auditar a árvore de sintaxe abstrata (AST) do Dart localmente em microssegundos (zero tokens).
* **Mecanismo:**
  * Uso do pacote oficial `analyzer` do Dart SDK para inspecionar nós sintáticos.
  * **Motor de Verificação Formal (`FG-FORMAL-001` a `005`):** Integração de Métodos Formais determinísticos (Typestate DFA, Propagação Simbólica de Restrições de Caixa, Program Slicing de `build()`, Análise Happens-Before para Concorrência e Abstract State Lattices). *Para a formulação matemática e algoritmos completos, consulte:* [Formal Verification Algorithms](FormalVerificationAlgorithms.md).
  * **Regras Fundamentais de Ciclo de Vida:**
    * Bloqueio de instanciação de controllers (`AnimationController`, `TextEditingController`) dentro do método `build()` (`FG-ST-001`, implementada).
    * Exigência de cancelamento de `StreamSubscription` no método `dispose()`.
    * Interceptação de gaps assíncronos (`BuildContext` usado após `await` sem `if (!mounted) return;`).
  * **Regras para os Dois Maiores Gerenciadores de Estado do Mercado:**
    * **Bloc / Cubit (`FG-BLOC-001`):** Detecta chamadas a `.emit()` após operações assíncronas (`await`) sem a checagem de guarda `if (isClosed) return;` (prevenindo o fatídico `StateError: Cannot emit new states after calling close`).
    * **Riverpod (`FG-RIV-001`):** Detecta o uso indevido de `ref.watch()` dentro de callbacks de eventos (`onPressed`, `onTap`, funções anônimas), forçando a substituição pelo correto `ref.read()`.

### 2.3. Mutation Chaos Gate (Injeção de Caos em 3 Operadores)
* **Objetivo:** Identificar testes fraudulentos com mocks complacentes gerados por IA que sempre passam mesmo com o código quebrado.
* **Mecanismo Pragmático de 10 Dias:**
  * Em vez de uma engine de compilação complexa, um *Source Rewriter* cirúrgico substitui em sandbox:
    1. Operadores relacionais: `>` por `<`, `>=` por `<=`.
    2. Operadores de igualdade: `==` por `!=`.
    3. Literais booleanos: `true` por `false`.
  * Se o teste da IA continuar passando com o código mutado, o gate entra em **Fail-Closed** e rejeita o commit por teste fraudulento.

### 2.4. Two-Tier Visual Gate (Triagem em 2 Níveis)
* **Objetivo:** Eliminar o gargalo de latência e consumo de tokens sem abrir mão da validação visual.
* **Mecanismo:**
  * **Tier 1 (Nativo, Local, 0 tokens, ~2ms):** O `WidgetTester` monta a tela em modo headless sob restrições extremas (Matrix Viewport com teclado aberto e telas compactas). O harness escuta `FlutterError.onError` nativo do framework. Se houver `RenderFlex overflowed` ou colisão de limites no `RenderBox`, o gate falha imediatamente.
  * **Tier 2 (Multimodal Meta AI sob demanda):** No benchmark oficial e em testes de regressão de tela, o screenshot renderizado é enviado para o **SAM 3.1** (segmentação de caixas delimitadoras e tap target < 48dp) e para o **Meta Muse Image** (contraste, corte de texto e anotação visual de erro).

### 2.5. Resiliência, Autocura e Rollback Fail-Closed
* **Objetivo:** Garantir convergência rápida da IA sem congelamentos de processo ou contaminação de código.
* **Mecanismo:**
  * **Circuit Breaker com Timeout Nativo:** Toda execução do Dart `Process.run()` possui timeout estrito (`timeout: Duration(seconds: 8)`). Se houver loop infinito no build, o processo é encerrado de forma limpa.
  * **Injeção de Receitas Canônicas:** A falha mapeia o erro para o catálogo (*Before/After*) e despacha para o **Meta Muse Code / Llama 3**.
  * **Rollback Atômico via Git:** Se após 3 tentativas de autocura o código não atingir 100% de aprovação, o harness descarta as alterações da iteração e restaura o snapshot limpo (via `git restore`), mantendo o repositório limpo. (Orçamento unificado com `ForceFieldHarness.md` §3: 3 tentativas + snapshot + Attack-the-Premise.)

---

## 3. Modelo de Instalação e Servidor MCP Nativo (Model Context Protocol) [PLANEJADO]

Qualquer projeto Flutter pode ser integrado ao FlutterGuard em menos de 1 minuto:

O **FlutterGuard AI** expõe nativamente um **Servidor MCP via stdio (JSON-RPC 2.0)**, permitindo que agentes de IA modernos (Claude Code, Gemini CLI, Cursor, Antigravity) executem as validações como ferramentas tipadas de primeira classe, sem recorrer a comandos de shell soltos:

```bash
# Instalação e auto-configuração do MCP no projeto
dart pub global activate flutterguard_ai
flutterguard init --mcp
```

### 3.1. O que o comando `flutterguard init --mcp` faz automaticamente:
1. **Compila e registra o binário do MCP Server (`bin/flutterguard_mcp.dart`).**
2. **Auto-Registro nas IDEs e Clientes MCP Detectados:**
   * Se detectar `.cursor/` ➔ Escreve/atualiza `.cursor/mcp.json`.
   * Se detectar `.gemini/` ou Antigravity ➔ Registra em `mcp_config.json`.
   * Se detectar Claude Code ➔ Configura o bloco em `claude_desktop_config.json`.
   ```json
   {
     "mcpServers": {
       "flutterguard": {
         "command": "flutterguard_mcp"
       }
     }
   }
   ```
3. **Cria a pasta local `.flutterguard/` (opt-in, só com flag explícita):** Com scripts de suporte, cache de receitas e telemetria determinística.
4. **Instala o Git Pre-Commit Hook (`.git/hooks/pre-commit`):** Barreira física fail-closed que impede commits defeituosos.
5. **Propõe o Contrato Mandatório do Agente (`AGENTS.md` / `CLAUDE.md` / `GEMINI.md`, opt-in):** Imprime o bloco abaixo para colar; escreve no arquivo só com flag explícita:
   ```markdown
   <!-- FLUTTERGUARD MCP HARNESS CONTRACT -->
   ## 🛡️ Diretrizes de Engenharia FlutterGuard (MCP Mandatório)
   Você tem acesso ao servidor MCP `flutterguard`. Para qualquer alteração em arquivos Dart/Flutter, siga estritamente este ciclo:
   1. **Validação Estática:** Após salvar código em `lib/`, execute `flutterguard.analyze_ast`. NUNCA ignore avisos de Lifecycle, Bloc ou Riverpod.
   2. **Autocura:** Se a AST falhar, chame `flutterguard.get_canonical_recipe` com o código da regra e aplique a correção imediatamente.
   3. **Estresse de Viewport:** Em widgets de tela, execute `flutterguard.verify_viewport` para garantir que o teclado aberto não causa RenderFlex overflow.
   4. **Anti-Fraude de Testes:** Execute `flutterguard.run_mutation_check`. Testes complacentes com mocks falsos serão rejeitados.
   5. **Critério de Aceite:** Nenhuma tarefa é considerada concluída sem que as ferramentas do MCP retornem status 'PASSED'.
   ```

   > **Orçamento de poluição:** o `init` nunca escreve arquivos rastreados no projeto por padrão — só o hook em `.git/` e a config MCP no IDE; `.flutterguard/` (item 3) e a escrita no arquivo do agente (item 5) exigem flag explícita.

### 3.2. As 4 Ferramentas Tipadas do Servidor MCP

| Ferramenta MCP | Argumentos | Resposta / Ação |
| :--- | :--- | :--- |
| `analyze_ast` | `file_path: string` | Valida nós de AST em microssegundos: Lifecycle, Bloc (`FG-BLOC-001`) e Riverpod (`FG-RIV-001`). |
| `verify_viewport` | `test_file: string` | Executa teste headless sob Matrix Viewport (teclado aberto de 320px e resoluções compactas). |
| `run_mutation_check` | `test_file: string` | Aplica mutação cirúrgica nos 3 operadores (`>`, `==`, `true`) para expor testes fraudulentos. |
| `get_canonical_recipe`| `rule_id: string` | Retorna o template Before/After da receita canônica para autocura imediata em 1 turno. |

---

## 4. Estrutura de Pacote Único (*Single Package Layout*)

Para garantir máxima velocidade de desenvolvimento e zero conflitos de links no Windows durante os 10 dias:

```
flutterguard_ai/
├── bin/
│   ├── flutterguard.dart         # CLI v0 (grade, check)
│   └── flutterguard_mcp.dart     # [PLANEJADO] Servidor MCP stdio (JSON-RPC 2.0)
├── lib/
│   ├── src/
│   │   ├── ast/                  # Regras v0 (Bloc, Riverpod)
│   │   ├── cli/                  # Registro de regras + núcleo do check
│   │   ├── mcp/                  # [PLANEJADO] Protocolo JSON-RPC e registro das tools
│   │   ├── chaos/                # [PLANEJADO] Mutation Chaos Injector (3 operadores)
│   │   ├── testing/              # [PLANEJADO] Headless Runner, Viewport Stressor, Rebuild Budget
│   │   ├── visual/               # [PLANEJADO] Tier 1 RenderBox check + Tier 2 SAM/Muse Image client
│   │   └── meta_ai/              # [PLANEJADO] Conector Llama Stack & APIs da Meta
├── benchmark/
│   ├── vectors/                  # Pares golden .bad/.good por regra (v0)
│   ├── cases/                    # [PLANEJADO] Os 10 códigos corporativos reais com falhas
│   └── run_benchmark.dart        # [PLANEJADO] Script de execução e pontuação comparativa
├── test/                         # Suíte de testes do próprio FlutterGuard
├── flutterguard.yaml             # [PLANEJADO] Arquivo de configuração (opcional / zero-config)
└── pubspec.yaml                  # 1 único arquivo de dependências limpo
```

---

## 5. Modelo de Telemetria Auditável (`evidence.jsonl`)

Cada ciclo executado pelo framework registra um evento atômico estruturado:

```json
{
  "timestamp": "2026-10-21T12:00:00Z",
  "phase": "DETERMINISTIC_GATE",
  "rule_id": "FG-BLOC-001",
  "file": "lib/features/cart/presentation/cart_cubit.dart",
  "status": "FAILED",
  "error_message": "emit() called after async gap without isClosed check",
  "recipe_injected": "RECIPE_SAFE_BLOC_EMIT",
  "iteration": 1,
  "action": "AUTO_HEALING_DISPATCHED"
}
```

---

## 6. O Playground Efêmero de Testes (`test_fixtures/`) [PLANEJADO]

Para garantir velocidade nos 10 dias sem colocar código corporativo em risco, o desenvolvimento diário **NÃO roda diretamente no PDV D+**. O repositório contém um playground isolado com **reset atômico em milissegundos**:

```
test_fixtures/
├── templates/                     # 🔒 Templates imutáveis com falhas reais
│   ├── 01_riverpod_watch_leak.dart.template
│   ├── 02_bloc_emit_after_close.dart.template
│   ├── 03_renderflex_keyboard_overflow.dart.template
│   └── 04_animation_controller_leak.dart.template
│
└── sandbox/                       # 💥 Área volátil onde o harness e o agente atuam
    └── (arquivos copiados para teste e autocura)
```

### Comandos de Gestão do Playground:
* `flutterguard sandbox load`: Popula a sandbox copiando os templates com falhas.
* `flutterguard sandbox reset`: Descarta qualquer mutação e restaura os templates originais em menos de 500ms.
* `flutterguard sandbox check`: Executa a suíte completa de gates na sandbox.

---

## 7. Distribuição & Instalação via GitHub [PLANEJADO]

O FlutterGuard-AI oferece três formas de instalação sem atrito:

### Opção A: Nativa do Dart SDK via Git (Recomendada)
Instala o binário diretamente do GitHub globalmente na máquina sem clonar repositório:
```bash
dart pub global activate --source git https://github.com/SEU-USER/flutterguard-ai.git
flutterguard init --mcp
```

### Opção B: Script One-Liner (curl / irm)
Ideal para desenvolvedores que desejam inicializar em 1 comando no terminal:
* **Windows (PowerShell):**
  ```powershell
  irm https://raw.githubusercontent.com/SEU-USER/flutterguard-ai/main/install.ps1 | iex
  ```
* **Linux / macOS (Bash):**
  ```bash
  curl -fsSL https://raw.githubusercontent.com/SEU-USER/flutterguard-ai/main/install.sh | bash
  ```

### Opção C: Clonagem para Desenvolvimento & Jurados
Para quem deseja inspecionar o código-fonte e rodar os gates localmente:
```bash
git clone https://github.com/SEU-USER/flutterguard-ai.git
cd flutterguard-ai
dart pub get
dart test
dart run bin/flutterguard.dart grade
```

