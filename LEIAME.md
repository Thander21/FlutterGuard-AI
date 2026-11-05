# FlutterGuard AI

### Autonomous Reactive & Blocking Quality Harness for Flutter / Dart

> **Transformando IA de geradora complacente de código em engenheiro de software sênior determinístico através de Spec-Driven Development (SDD), Análise Reativa de AST, Verificação Visual Multimodal e Gates Bloqueantes.**

> **Escopo:** 17 regras AST implementadas (16 bloqueantes + `FG-MET-007`
> consultiva) com comandos CLI `grade` + `check` + `init` + `sandbox`,
> hook pre-commit, dispatcher de autocura, mutation runner, Tier-1
> viewport runner (com fallback AST Tier-1-lite), pipeline de
> cobertura/CRAP, detector de duplicação estrutural e servidor MCP
> (5 ferramentas tipadas, `init --mcp`, 5 chat-skills). O visual
> gate Tier-2 está **[ADIADO]** — endpoints não verificados,
> Tier-1 vigente (ver `specs/system/SYS-VIEW-002-tier2-visual.md`).
> `specs/` é normativo; `docs/` registra direção e intenção.

---

## 🎯 O Que é o Projeto?

O **FlutterGuard AI** é um framework e orquestrador autônomo (_closed-loop agentic harness_) desenvolvido especificamente para o ecossistema **Flutter/Dart**. Ele resolve o maior gargalo atual do desenvolvimento com IA: a geração de código frágil, poluição de ciclo de vida de widgets, descolamento de estado (_state anti-patterns_), falhas silenciosas de concorrência e quebras visuais (`RenderFlex overflowed`) que linters tradicionais não conseguem detectar.

O projeto funciona como uma barreira física e pedagógica (_fail-closed_): nenhum código gerado por IA é aprovado sem antes passar por um contrato estrito de especificação, validação estática de AST, testes com telemetria determinística e inspeção visual automatizada.

---

## 🧠 Arquitetura 100% Meta AI Core + Governança Universal em Tempo de Execução

O **FlutterGuard AI** possui seu motor central e inteligência alimentados 100% pelo ecossistema de modelos e frameworks da **Meta AI**, atuando simultaneamente como um harness de governança para qualquer agente cliente:

1. **[Arquitetura do Sistema & Stack Meta AI](docs/_origem/Architecture.md)**
   - **Meta Muse Spark:** Arquiteto SDD que decompõe requisitos em contratos e testes que falham (RED).
   - **Meta Muse Code / Llama 3:** Agente de implementação mínima e autocura em Dart guiada por AST.
   - **SAM 3.1 & Meta Muse Image:** Auditoria visual multimodal, segmentação de caixas delimitadoras e detecção de `RenderFlex overflowed`.
   - **Llama Stack:** Barramento unificado para orquestração, tool calling e memória de contexto.
   - **Dart SDK Core:** Motor local determinístico de inspeção de AST em microssegundos (zero-token).

2. **[Governança e Rastreamento de Agentes Clientes via MCP](docs/_origem/ClientAgentsTracking.md)**
   - Uma vez instalado em qualquer projeto Flutter (`flutterguard init --mcp`), o FlutterGuard atua como um **Harness de Qualidade e Barreira Física** em tempo de execução para os agentes que o desenvolvedor já utiliza: **Claude Code, Gemini CLI, Cursor, Antigravity ou modelos locais**.
   - As IAs clientes são obrigadas a respeitar os contratos e gates de validação antes de qualquer commit no repositório.

---

## ⚡ Instalação Rápida & Setup (Padrão Nativo via Git)

Instale e ative o FlutterGuard globalmente na sua máquina diretamente do GitHub com **um único comando nativo do Dart SDK** (sem necessidade de clonar o repositório manualmente):

### O que funciona hoje (a partir de um checkout do repo)

```bash
dart pub get
dart test
dart run bin/flutterguard.dart grade
dart run bin/flutterguard.dart check <path> [--json]
```

### Instalação global

```bash
# 1. Instalação global oficial direto do GitHub (Dart SDK).
# Caminho primário (SDKs com `dart install`):
dart install 'flutterguard_ai@{git: {url: https://github.com/Thander21/FlutterGuard-AI.git}}'
# Fallback para SDKs antigos:
dart pub global activate --source git https://github.com/Thander21/FlutterGuard-AI.git

# 2. Inicialização com Servidor MCP e Git Hook no seu projeto Flutter
cd caminho/para/seu_projeto_flutter
flutterguard init --mcp
```

> O `dart pub global` instala os exes no `bin/` do pub cache
> (`%LOCALAPPDATA%\Pub\Cache\bin` no Windows, `~/.pub-cache/bin` nos
> demais) — adicione-o ao PATH ou os comandos `flutterguard` /
> `flutterguard_mcp`, os hooks do plugin e a entrada do servidor MCP
> não resolvem. O `init --mcp` avisa quando o exe do servidor falta.

### Plugin one-install (Claude Code)

Pré-requisito: a instalação global acima (o plugin chama os exes
`flutterguard` / `flutterguard_mcp` — nunca os embute).

```bash
# Canal 1: marketplace GitHub (recomendado, sem clone).
claude plugin marketplace add Thander21/FlutterGuard-AI
claude plugin install flutterguard@flutterguard

# Canal 2: pasta local (clone uma vez, depois aponte para ela).
git clone https://github.com/Thander21/FlutterGuard-AI.git
claude plugin marketplace add ./FlutterGuard-AI
claude plugin install flutterguard@flutterguard
```

Uma instalação conecta três coisas: o servidor MCP `flutterguard` (as
mesmas 5 ferramentas, auto-registrado), a skill de loop diário `fg-use`
e os hooks do loop do agente. Antes de uma edição Dart/Flutter o hook
verifica se o CLI está no PATH (ausente → a edição é bloqueada com o
comando de instalação); depois da edição ele roda `check` naquele
arquivo (violações → findings + ponteiros de receita voltam ao agente,
que deve corrigi-los). O git pre-commit hook do `init` continua
aplicando no commit. A versão do plugin acompanha a do pacote
(`plugin.json` espelha o `pubspec.yaml`). Escopo honesto: os hooks só
enxergam chamadas `Edit`/`Write` — escritas via shell passam batido.
Eles são um tripwire, não a barreira: a barreira é o pre-commit hook
do `init`.

### O que acontece automaticamente nos bastidores:

1. **Servidor MCP Nativo:** o binário stdio `flutterguard_mcp` (JSON-RPC 2.0) com 5 ferramentas tipadas, pronto para IDEs e agentes (Cursor, Claude Code, Gemini CLI, Antigravity).
2. **Auto-Configuração:** `init --mcp` escreve `mcp_config.json` (mais `.cursor/mcp.json` quando `.cursor/` existe) e imprime o snippet de cliente global para instalação manual.
3. **Contrato de Governança:** o mandato do agente é impresso por padrão; `init --agents` o escreve no `AGENTS.md`.
4. **Git Pre-Commit Hook:** instalado pelo `init`; roda `check` e bloqueia commits com violações.

### Ferramentas MCP e uso pelo agente

`init --mcp` registra o servidor stdio `flutterguard_mcp`. O Cursor é
configurado automaticamente (`.cursor/mcp.json`). Matriz por cliente (contrato completo:
`specs/system/SYS-MCP-002-client-packaging.md`):

| Cliente | Caminho | Notas |
|---|---|---|
| Claude Code | plugin (one-install acima) | Servidor MCP + skill `fg-use` + hooks |
| Cursor | `flutterguard init --mcp` | `.cursor/mcp.json` escrito automaticamente |
| Gemini CLI / Antigravity | snippet impresso pelo `init --mcp` | mesclar na config MCP do cliente |
| Muse | `muse skills install <checkout>/.agents/skills/fg-use --scope user` | skill de loop diário; ferramentas MCP via snippet |

O formato do snippet (o plugin auto-registra o mesmo):

```json
{
  "mcpServers": {
    "flutterguard": {
      "command": "flutterguard_mcp"
    }
  }
}
```

As 5 ferramentas tipadas (contrato completo: `specs/system/SYS-MCP-001-mcp-server.md`):

| Ferramenta | Argumentos | Propósito |
|---|---|---|
| `analyze_ast` | `path` | Roda as 17 regras AST num arquivo ou diretório. `FAILED` = violação capturada. |
| `get_canonical_recipe` | `rule_id` | Retorna a receita de correção Before/After (spec §2). Aplique em um turno. |
| `verify_viewport` | `path` | Vocabulário Tier-1-lite de layout. Degradado: `PASS` nunca afirma tela limpa. |
| `run_mutation_check` | `source_file`, `test_file` | Julga um teste contra mutantes. `passed=false` = teste complacente. |
| `get_telemetry` | `rule_id?`, `status?`, `limit?` | Lê as linhas mais novas do `evidence.jsonl`. Consulta, nunca gate. |

Loop do agente: `analyze_ast` → `get_canonical_recipe(rule_id)` → patch →
rode `analyze_ast` até `PASSED`. Verifique a instalação conectando um
cliente: um servidor saudável responde `initialize` com
`serverInfo flutterguard/0.1.0`.

**Nota de escopo:** mutação, coverage/CRAP e duplicação existem como
API Dart + testes + MCP parcial (`run_mutation_check`, `verify_viewport`
lite); o `heal` entra na superfície de terminal
(`check`/`grade`/`init`/`sandbox`/`heal`) como wrapper fino do
`HealDispatcher` (só regras fast-path).

**Setup oficial:** instale uma vez globalmente, depois
`flutterguard init --mcp` em cada projeto. As ferramentas MCP governam o
loop do agente (aconselham + verificam); o hook pre-commit aplica o gate
— bloqueia commits com erros sem depender do agente. Conduza o loop
diário com a skill `fg-use` — empacotada no plugin, ou avulsa via
`muse skills install <checkout>/.agents/skills/fg-use --scope user`
(adicione `--force` para sobrescrever uma cópia antiga).

---

## 📚 Mapa da Documentação

- 📖 **[Visão Geral e Problema](docs/_origem/ProjectOverview.md):** Diagnóstico de mercado, dores reais e proposta de valor.
- 🏆 **[Blueprint Executivo de Submissão](docs/_rulesHackathon/HackathonSubmissionBlueprint.md):** Pitch oficial, Enterprise Bug Benchmark, One-Command CLI e roteiro do vídeo de 2 minutos.
- 🚀 **[Inovações Disruptivas & Engenharia Fora da Caixa](docs/_origem/DisruptiveInnovations.md):** Rebuild Budget, Mutation Testing, Matrix Viewport e as falhas invisíveis da IA.
- 🏛️ **[Arquitetura do Sistema (100% Meta AI)](docs/_origem/Architecture.md):** Fluxo reativo, AST Engine, loops de feedback e injeção cirúrgica de contexto.
- 🔬 **[Algoritmos de Verificação Formal (AST Prover)](docs/_origem/FormalVerificationAlgorithms.md):** Métodos formais, Typestate DFA, Cassowary Constraints, Program Slicing e Análise Causal para Flutter.
- 🤖 **[Dossiê da Stack Meta AI](.agents/metaai/Readme.md):** Guia técnico de estudo e integração com Muse Spark, Muse Code, SAM 3.1, Muse Image e Llama Stack.
- 🔌 **[Governança de Agentes Clientes em Execução](docs/_origem/ClientAgentsTracking.md):** Rastreamento de Claude Code, Cursor, Gemini CLI e Antigravity via MCP.
- 🛡️ **[Campo de Força & Gates](docs/_origem/ForceFieldHarness.md):** Princípios da esteira determinística e bloqueio _fail-closed_.
- 📐 **[Gates Determinísticos & Validação Clean Code (ub-mode)](docs/_origem/CleanCodeDeterministicGates.md):** Adaptação do framework de Robert C. Martin (Uncle Bob), CRAP Score (< 10), detector de duplicação e quebra de alucinação.
- 🔄 **[Metodologia SDD + TDD + EDD + XP](docs/_origem/SpecDrivenDevelopment.md):** O ciclo de vida determinístico que elimina alucinações e testes complacentes.
- ⚙️ **[Fluxo Operacional SDD + EDD](docs/_origem/SddEddWorkflow.md):** Metodologia de engenharia determinística com OpenSpec AST, Eval Benchmarks e Llama Stack.
- 💡 **[Catálogo de Receitas Canônicas](docs/_origem/CanonicalRecipesCatalog.md):** Biblioteca de padrões de correção (_Before/After_) para auto-recuperação da IA.
- 🔗 **[Ponte de Referência ERP PDV D+](docs/_origem/ReferencePdvDMais.md):** Mapeamento e consulta das regras reais testadas em produção no PDV D+.
- 🎯 **[Trilha do Hackathon Meta](docs/_rulesHackathon/MetaHackathonTrack.md):** Planejamento e textos oficiais de submissão do evento.
- 📢 **[Divulgação & Build in Public](docs/_rulesHackathon/SelfPromotion/SelfPromotion.md):** Diretrizes de compliance da Meta e calendário de posts no LinkedIn.

_Nota: os três links de hackathon acima são histórico do evento, não requisitos do projeto._

---

## ⚡ Pilares Fundamentais

1. **Reativo:** Monitora a AST e as mutações de código no instante em que ocorrem.
2. **Bloqueante (_Fail-Closed_):** Código não aprovado em 100% dos gates é sumariamente revertido.
3. **Didático / Pedagógico:** Não apenas aponta o erro, mas injeta a receita canônica (_Just-in-Time Canonical Recipe_) para a IA corrigir em 1 turno.
4. **Multimodal:** Não confia apenas em texto e compiladores; inspeciona a tela renderizada contra quebras de layout.
