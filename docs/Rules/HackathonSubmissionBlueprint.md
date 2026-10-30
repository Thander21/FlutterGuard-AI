# Blueprint Executivo de Submissão: Meta Global Hackathon
### FlutterGuard-AI: Autonomous Reactive & Blocking Quality Harness for Flutter

> **Documento Oficial de Alinhamento:** Este blueprint consolida a estratégia de posicionamento, as respostas prontas para o formulário de submissão da Meta, a suíte de benchmark corporativa, a arquitetura do CLI e o roteiro segundo a segundo do vídeo de demonstração (*The 2-Minute Golden Pitch*).

---

## 🎯 1. Posicionamento Estratégico & Onlyness Statement

### O ZAG de Mercado (Diferenciação Radical)
* **O que 99% dos competidores fazem:** Criam mais um gerador de código com prompt para criar telas em 1 clique (gerando código frágil, não testado e com quebras de layout).
* **O que o FlutterGuard-AI faz:** Atua como um **campo de força determinístico (*fail-closed*)** que bloqueia alucinações, vazamentos de memória e quebras visuais antes de qualquer commit.

> **Declaração de Exclusividade (*Onlyness Statement*):**  
> O **FlutterGuard-AI** é a **ÚNICA** esteira autônoma de engenharia para Flutter que combina **Análise Reativa de AST em Dart, Injeção de Caos (Mutation Testing) e Segmentação Visual com SAM 3.1** para transformar IA complacente em um engenheiro de software sênior determinístico.

---

## 📝 2. Textos Prontos para o Formulário de Submissão da Meta

### Project Title
```text
FlutterGuard AI: Autonomous Reactive & Visual Quality Harness for Flutter
```

### Elevator Pitch (150 caracteres)
```text
Autonomous closed-loop engineering harness for Flutter that uses Meta AI (Muse & SAM 3.1) and Dart AST to block fragile code, leaks, and UI overflows.
```

### Problem Statement (O Problema Real)
```text
Generative AI writes syntactically valid code in seconds, but for reactive UI frameworks like Flutter, it produces silent catastrophes in production:
1. State & Lifecycle Leaks: Instantiating controllers inside build() methods, orphaned listeners, and async gaps that crash when context unmounts.
2. Complacent Synthetic Tests: Generating fake unit tests with tautological mocks that always return green while business logic remains broken.
3. Silent Visual Clipping: Linters only read text. They are completely blind to layout disasters like 'RenderFlex overflowed' when a virtual keyboard opens or when an elderly user enables high accessibility text scaling.
```

### The Solution & Meta AI Integration (A Solução Integrada)
```text
FlutterGuard AI transforms passive code generation into a blocking, fail-closed engineering pipeline:
1. Meta Muse Spark (SDD Architect): Decomposes requirements into sealed-state contracts and failing RED unit tests before implementation starts.
2. Meta Muse Code (Engine Worker): Writes minimal Dart code to pass tests and applies self-healing refactoring via canonical AST patterns.
3. SAM 3.1 & Meta Muse Image (Multimodal Visual Gate): Headless tests render widget screenshots under adversarial conditions (virtual keyboard up, small viewports). SAM 3.1 segments UI bounding boxes to detect collisions and touch-target violations (<48dp), while Muse Image catches RenderFlex overflows.
4. FlutterGuard Dart Core (Deterministic Local Engine): Runs zero-token, microsecond AST rules, mutation testing (chaos injection against fake mocks), and frame rebuild profiling.
```

---

## 🧪 3. Inovação A: The Enterprise Bug Benchmark (`flutterguard_benchmark`)

Para provar aos jurados que a solução não é teórica, o repositório inclui a suíte **`flutterguard_benchmark`**, contendo os **10 Piores Bugs Reais de Flutter** inspirados em sistemas de missão crítica (como o ERP/PDV D+):

| # | Cenário do Bug Corporativo | Falha Típica da IA Comum | Detecção & Solução FlutterGuard-AI |
| :-: | :--- | :--- | :--- |
| **01** | **PDV Barcode Scanner Stream** | Abre listener no `initState` e esquece de fechar; eventos duplicam a cada navegação. | **Core Dart Engine:** Detecta `StreamSubscription` sem cancelamento no `dispose()`. |
| **02** | **Lista Dinâmica de Preços** | Exclui linha sem `ValueKey`; o Flutter transfere o preço do produto 1 para o produto 2. | **AST Engine:** Exige `ValueKey(id)` em coleções mutáveis de StatefulWidget. |
| **03** | **Teclado Virtual em Checkout** | Formulário quebra com faixa zebrada de `RenderFlex` quando o teclado abre. | **SAM 3.1 + Muse Image:** Matrix Viewport detecta colisão de altura e injeta `SingleChildScrollView`. |
| **04** | **Stale Search Query Race** | Usuário busca "A" depois "ABC"; "A" responde depois e sobrescreve dados na tela. | **Muse Code:** Bloqueia chamadas assíncronas sem token de cancelamento de requisição. |
| **05** | **Rebuild Flood em Catálogo** | `ref.watch` no topo causa 60 rebuilds por frame ao tocar em um botão. | **Rebuild Budget Harness:** Mede rebuild de `Element` em teste headless e barra degradação de FPS. |
| **06** | **Mock Complacente / Teste Falso** | Teste unitário gerado pela IA sempre passa porque mocka a si mesmo. | **Mutation Testing (Caos):** Inverte lógica na AST; se o teste não quebrar, o commit é barrado. |
| **07** | **Main Isolate Freeze (Jank)** | Parsing de JSON de 5MB rodando na thread de UI congela o app por 1 segundo. | **Core Engine:** Audita processamento síncrono e força delegação para `Isolate.run()`. |
| **08** | **Tap Target Inacessível** | Ícone de fechar com 14x14 pixels impossível de acertar em touchscreens. | **SAM 3.1:** Mede a área física do componente e exige no mínimo 48x48 dp. |
| **09** | **Memory Leak por Retained Closures** | Closure anônima passada para EventBus retém `this` e causa OOM silencioso. | **Core Engine:** Exige desregistro formal e uso de referências fracas. |
| **10** | **God-Widget Acoplado** | Arquivo único de 400 linhas misturando HTTP, regras de desconto e UI. | **Semantic Ratio Metric:** Rejeita arquivos de visualização com mais de 15% de regras de negócio. |

---

## ⚡ 4. Inovação B: Instalação & Uso sem Fricção (One-Command CLI)

Qualquer desenvolvedor Flutter do mundo pode instalar e proteger seu projeto em **menos de 30 segundos**:

```bash
# Opção 1: Instalação nativa via Git (Dart SDK)
dart pub global activate --source git https://github.com/SEU-USER/flutterguard-ai.git

# Opção 2: Inicialização com registro automático de MCP
flutterguard init --mcp
```

> **Para instalação em 1 linha (PowerShell):**  
> `irm https://raw.githubusercontent.com/SEU-USER/flutterguard-ai/main/install.ps1 | iex`

### O que o comando `flutterguard init` faz automaticamente:
1. **Cria a pasta local `.flutterguard/`:** Armazena scripts de verificação, cache de receitas canônicas e telemetria.
2. **Instala o Git Hook (`.git/hooks/pre-commit`):** Executa o harness automaticamente a cada commit, bloqueando violações de AST, vazamentos e quebras de layout.
3. **Injeta Instruções no Agente de IA do Projeto (`AGENTS.md` / `CLAUDE.md` / `GEMINI.md`):** O instalador detecta qual arquivo de instrução existe no projeto e adiciona a regra de guarda para que a IA local sempre execute a verificação antes de concluir tarefas:
   ```markdown
   <!-- FLUTTERGUARD HARNESS MANDATE -->
   Antes de sugerir ou comitar alterações em arquivos Dart/Flutter, execute:
   `flutterguard check --json` e assegure status 'PASSED'.
   Em caso de falha, consulte a receita canônica indicada no campo 'recipe'.
   ```
4. **Modo CLI com `--json` Nativo:** Todos os comandos de auditoria suportam saída estruturada em JSON, permitindo que qualquer assistente de código moderno consuma os resultados sem overhead.

---

## 🎬 5. Inovação C: O "Golden Pitch Script" (Vídeo Demo de 120 Segundos)

Este é o roteiro cinematográfico para o vídeo de submissão do Hackathon da Meta:

```
[00:00 - 00:25] O GANCHO: O TERROR EM PRODUÇÃO
* Visual: Tela de um terminal de vendas (POS) ou celular em uso real.
* Ação: O usuário digita no campo de cupom, o teclado abre e a tela explode em faixas amarelas
  e pretas de "RenderFlex overflowed by 230 pixels".
* Narração: "IAs modernas geram código em segundos. Mas para frameworks reativos como Flutter,
  elas geram código frágil, quebras de layout silenciosas e testes fraudulentos que nenhum linter comum pega."

[00:25 - 00:50] A APRESENTAÇÃO: FLUTTERGUARD AI
* Visual: Terminal executando `flutterguard run --spec feature_checkout.md`.
* Ação: Mostra o Meta Muse Spark em ação decompondo a feature em máquinas de estado (sealed class)
  e gerando o arquivo de teste `checkout_test.dart` no estágio RED (falhando).
* Narração: "Apresentamos o FlutterGuard AI: a primeira esteira autônoma e bloqueante que transforma IA
  em engenheiro sênior através de Spec-Driven Development e verificação multimodal da Meta."

[00:50 - 01:25] O FATOR 'UAU': AUDITORIA VISUAL COM SAM 3.1
* Visual: O terminal executa o teste headless do Flutter. Uma janela renderiza a tela com o teclado aberto.
* Ação: O SAM 3.1 entra em ação desenhando caixas delimitadoras coloridas sobre cada componente.
  O FlutterGuard detecta a sobreposição do botão com o teclado.
* Efeito na Tela: ALERTA VERMELHO: "FAIL-CLOSED: Layout Collision Detected by SAM 3.1".
* Narração: "Compiladores leem texto, mas o SAM 3.1 enxerga a geometria. Em segundos, nossa esteira
  detecta que o botão foi ocluído pelo teclado e bloqueia o commit imediatamente."

[01:25 - 01:50] A AUTOCURA & A EVIDÊNCIA MATERIAL
* Visual: O Meta Muse Code recebe a receita canônica do catálogo e reescreve o container com `SingleChildScrollView`.
* Ação: O teste roda novamente. O SAM 3.1 valida a nova geometria. A tela fica VERDE.
* Terminal: Gravação da linha de telemetria no arquivo `evidence.jsonl`.
* Narração: "Com injeção cirúrgica de receitas canônicas, o Meta Muse Code autocorrige o layout em um turno.
  Sem achismos: cada aprovação gera evidência material com hash determinístico."

[01:50 - 02:00] O ENCERRAMENTO
* Visual: Logo do FlutterGuard AI + Badges do Meta Muse, SAM 3.1 e Dart SDK.
* Narração: "FlutterGuard AI: Porque código de missão crítica não aceita alucinações.
  Totalmente open-source e construído para o ecossistema Meta AI."
```

---

## 📊 6. Critérios de Avaliação da Meta & Mapeamento de Pontuação

| Critério Oficial da Meta (Peso) | Como o FlutterGuard-AI Atende com Nota Máxima |
| :--- | :--- |
| **Ideia & Inovação (50%)** | Cria uma nova categoria (*Autonomous Blocking Quality Harness*). Aborda o gargalo número 1 da indústria (confiabilidade do código gerado por IA) com verificação visual inédita via SAM 3.1. |
| **Habilidade Técnica (50%)** | Uso profundo de múltiplos modelos da Meta (Muse Spark, Muse Code, SAM 3.1, Llama Stack) integrados com compilação de AST em Dart, headless rendering e mutation testing. |
| **Completude & Execução** | CLI instalável via `dart pub`, suíte de benchmark corporativa com 10 bugs reais e evidência material auditável (`evidence.jsonl`). |

