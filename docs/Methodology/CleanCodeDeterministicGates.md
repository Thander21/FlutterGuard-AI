# Gates Determinísticos de Clean Code & Análise do Ecossistema ub-mode
### Incorporando a Filosofia de Robert C. Martin (Uncle Bob), Métricas Matemáticas (CRAP, Dryer, Mutator) e o Protocolo "Attack the Premise" ao FlutterGuard-AI

> **Resumo Executivo:**  
> A indústria de software vive uma encruzilhada: agentes de inteligência artificial produzem código com alta velocidade sintática, mas com profunda fragilidade arquitetural e complacência em testes (*vibes-based engineering*).  
> Robert C. Martin ("Uncle Bob"), autor de *Clean Code* e cocriador do Manifesto Ágil, lançou o framework conceitual **[ub-mode](https://github.com/unclebob/ub-mode)**, sustentado por ferramentas determinísticas de auditoria matemática ([crapper](https://github.com/unclebob/crapper), [dryer](https://github.com/unclebob/dryer), [mutator](https://github.com/unclebob/mutator)).  
> Este documento analisa formalmente o `ub-mode`, demonstra a convergência com o **FlutterGuard-AI**, especifica a integração dessas métricas no nosso motor nativo de AST em Dart e lista referências teóricas e empíricas para pesquisas aprofundadas.

---

## 1. Análise do Ecossistema `ub-mode` (Robert C. Martin)

O repositório `unclebob/ub-mode` foi projetado como uma **Agent Skill universal** (`SKILL.md`) que substitui a complacência do LLM por rigor de engenharia de software clássica (XP, TDD e Clean Architecture).

O fluxo do `ub-mode` é dividido em três ordens imperativas:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. FIRST MAKE IT WORK                                                       │
│    • Laziness Protocol: Uma decisão em um único lugar; menor edição viável. │
│    • Foundational Thinking: Modelagem de dados antes de escrever lógica.    │
│    • Strict TDD: Teste que falha (RED) antes da linha de código funcional.   │
│    • Attack the Premise: Reavaliação imediata quando 2 correções falham.    │
│    • Domain Modeling: Estruturar dados tornando estados ilegais impossíveis.│
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 2. THEN MAKE IT RIGHT (GATES DETERMINÍSTICOS MATEMÁTICOS)                   │
│    • Fix Root Causes: Proibição de mascarar erros ou guards artificiais.    │
│    • Test Behavior: Testar contratos e comportamento, nunca implementação.  │
│    • crapper: Bloqueio matemático onde CRAP >= 10 (Complexidade vs Cobertura│
│    • dryer: Eliminação de duplicação estrutural de código (similaridade >= 0.8│
│    • mutator: Testes de mutação — cobrir descobertos e matar mutantes.      │
│    • Refactoring: Provar que o comportamento não mudou via testes estáveis. │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 3. PRACTICE (DISCIPLINA OPERACIONAL)                                        │
│    • Guard Context Window: Manter o thread do LLM enxuto; resumir deltas.   │
│    • Small Ordered Commits: Commits atômicos documentando motivo e prova.   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### O Arsenal de Ferramentas Complementares do Uncle Bob

1. **[unclebob/crapper](https://github.com/unclebob/crapper):**  
   Implementação universal da métrica **CRAP (Change Risk Anti-Patterns)**. Analisa a Complexidade Ciclomática ($CC$) e a Cobertura de Testes ($cov$) por função. Qualquer função com $\text{CRAP} \ge 10$ é considerada de alto risco de manutenção e quebra o pipeline.
2. **[unclebob/dryer](https://github.com/unclebob/dryer):**  
   Auditor de duplicação estrutural que examina o grafo sintático (AST). Trechos com similaridade $\ge 0.8$ geram violação imediata, forçando abstração ou unificação.
3. **[unclebob/mutator](https://github.com/unclebob/mutator):**  
   Motor de testes de mutação. Altera operadores aritméticos, relacionais e lógicos. Se a suíte de testes continuar passando com o código deliberadamente quebrado, o teste é classificado como "fraudulento" ou frágil.
4. **[unclebob/uml-viewer](https://github.com/unclebob/uml-viewer):**  
   Visualizador em tempo real da arquitetura do sistema, direções de dependência, acoplamento e distribuição de calor de complexidade e mutação.

---

## 2. Convergência e Validação Teórica para o FlutterGuard-AI

A existência e as premissas do `ub-mode` trazem **validação externa de primeiro nível** para o FlutterGuard-AI:

1. **A mesma dor diagnosticada:** O Uncle Bob reconhece que agentes de IA são propensos a remendos locais e testes complacentes se não forem contidos por rédeas determinísticas.
2. **Rejeição ao "Vibes-Based Coding":** Avaliações de código por outro LLM sofrem de contaminação e complacência mútua. A avaliação **deve** ser feita por ferramentas matemáticas e estáticas compiladas (zero tokens, 100% determinísticas).
3. **Fail-Closed Estrito:** Nenhum erro pode ser silenciado (`// ignore:`, `catch (e) {}` vazio ou supressão de warnings).

---

## 3. Especificação Técnica: Adaptando os Gates para Dart e Flutter

O `ub-mode` original foca em linguagens de backend tradicionais (Java, Clojure, Go, Rust, Python, TS). O **FlutterGuard-AI** adota e estende essas métricas especificamente para o ciclo de vida e reatividade do **Flutter / Dart**.

### 🔹 Gate A: Métrica CRAP no Dart AST Engine (`flutterguard crap`)

A métrica CRAP avalia o perigo de uma unidade de código através da fórmula:

$$\text{CRAP}(m) = CC(m)^2 \times (1 - \text{cov}(m))^3 + CC(m)$$

Onde:
* $CC(m)$ é a **Complexidade Ciclomática** do método $m$.
* $\text{cov}(m)$ é a fração da função exercitada por testes automatizados ($0.0 \le \text{cov} \le 1.0$).

#### Como calculamos o $CC$ em Dart/Flutter (via `package:analyzer`):
No Dart, a complexidade não está apenas em estruturas de controle clássicas, mas especialmente na **árvore de widgets declarativa**:

| Nó da AST do Dart | Impacto na Complexidade ($CC$) |
| :--- | :---: |
| `IfStatement`, `ForStatement`, `WhileStatement`, `DoStatement` | $+1$ por instrução |
| `SwitchCase`, `SwitchPatternCase` | $+1$ por cláusula |
| `CatchClause` | $+1$ por bloco |
| Operadores lógicos de curto-circuito (`&&`, `\|\|`, `??`) | $+1$ por operador |
| `ConditionalExpression` (Operador Ternário `a ? b : c`) | $+1$ por ternário |
| **Widget Aninhado com Decisão de Estado no `build()`** | $+1$ por bifurcação na UI |

#### Regra Bloqueante do FlutterGuard:
```
IF CRAP(m) >= 10.0:
    FAIL-CLOSED: Bloqueia commit.
    DIAGNÓSTICO: "Método ou Widget '$name' possui CRAP = $score (CC=$cc, Cobertura=$cov%)."
    DIRETRIZ DE AUTOCURA: 
      1. Extrair sub-widgets em métodos independentes ou StatelessWidget (reduzindo CC);
      2. Adicionar testes de unidade/widget exercitando as bifurcações ausentes (aumentando cov).
```

### 🔹 Gate B: Detector de Duplicação Estrutural em Widgets (`flutterguard dryer`)

A IA frequentemente clona árvores de widgets inteiras (ex: múltiplos `Card`, `Container` ou blocos de formulário quase idênticos) em vez de criar componentes reutilizáveis.

* **Algoritmo de Hash Estrutural de AST:**
  1. O FlutterGuard percorre a AST descartando identificadores e literais arbitrários, retendo a estrutura morfológica (`Container > Column > [Text, SizedBox, ElevatedButton]`).
  2. Gera assinaturas de subárvores e calcula a distância estrutural via índice de similaridade de Jaccard/Tree-Edit.
  3. Se a similaridade for $\ge 0.8$ em nós com mais de 15 linhas, o gate **rejeita a edição**.
* **Receita Canônica:** Força a extração de um `StatelessWidget` parametrizado.

### 🔹 Gate C: Protocolo Heurístico "Attack the Premise" no Auto-Healing

Quando o agente do FlutterGuard entra no loop de autocura contra um gate quebrado (máximo de 3 turnos):

```
Turno 1: IA tenta conserto A -> Gate falha.
Turno 2: IA tenta conserto B (que compartilha da premissa de A) -> Gate falha.
```

Em vez de permitir uma terceira tentativa aleatória, o motor ativa o protocolo **Attack the Premise**:
1. **Pausa de Edição:** O harness suspende a escrita no sistema de arquivos.
2. **Injeção de Reflexão Forçada no Prompt:**
   > *"Suas duas últimas tentativas falharam o mesmo gate de validação compartilhando uma mesma premissa arquitetural.  
   > 1. Escreva essa premissa assumida em exatamente uma frase.  
   > 2. Identifique qual ator ou restrição de estado invalida essa premissa.  
   > 3. Remova a premissa e reprojete a solução a partir de primeiros princípios antes de gerar código."*
3. **Prevenção de Loops de Alucinação:** Elimina a clássica oscilação da IA entre duas soluções igualmente falhas.

---

## 4. Onde o FlutterGuard-AI vai além do `ub-mode`

O `ub-mode` foi concebido para fluxos puramente textuais e algorítmicos. O **FlutterGuard-AI** é a evolução dessa mentalidade para a **computação moderna de interfaces gráficas e agentes multimodais**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ESPAÇO DE ATUAÇÃO                                 │
├──────────────────────────────────────┬──────────────────────────────────────┤
│ ub-mode (Uncle Bob)                  │ FlutterGuard-AI                      │
├──────────────────────────────────────┼──────────────────────────────────────┤
│ • Lógica algorítmica & backend       │ • Lógica de negócio em Dart          │
│ • Complexidade Ciclomática (CRAP)    │ • CRAP adaptado para Widget Trees    │
│ • Duplicação de código (Dryer)       │ • Duplicação de Widgets e Builders   │
│ • Mutation Testing textual           │ • Mutation Testing de Lógica + Caos  │
│ ❌ Cego para Renderização de Telas   │ ✅ Two-Tier Visual Gate (RenderFlex) │
│ ❌ Cego para Geometria e Layout      │ ✅ SAM 3.1 (Tap Target < 48dp, Boxes)│
│ ❌ Cego para Rebuilds de UI          │ ✅ Rebuild Budget Harness (Profiling)│
│ ❌ Cego para Viewports Móveis        │ ✅ Matrix Viewport Stressor          │
│ ❌ Cego para Ciclo de Vida Flutter   │ ✅ Async Gap & Memory Leak Inspector │
└──────────────────────────────────────┴──────────────────────────────────────┘
```

---

## 5. Governança para Agentes: Seção Canônica para `AGENTS.md`

Ao executar `flutterguard init --mcp`, o harness escreve as diretrizes operacionais de Clean Code no `AGENTS.md` do repositório alvo:

```markdown
### 🛡️ FlutterGuard Deterministic Quality Rules (ub-mode Clean Code Protocol)

1. **First Make it Work (SDD & TDD):**
   - Nunca altere a implementação sem antes ter um teste unitário que falha pelo motivo esperado.
   - Faça a menor alteração estritamente necessária para o teste passar.
   - Modele os estados da tela via `sealed class` no Dart 3, tornando estados inconsistentes impossíveis de compilar.

2. **Then Make it Right (Deterministic Gates):**
   - **CRAP Gate (< 10):** Mantenha o CRAP Score abaixo de 10. Se uma função ou widget tiver alta complexidade ciclomática, extraia sub-widgets ou escreva testes para cobrir cada ramo.
   - **Dryer Gate:** Não duplique subárvores de widgets. Se a estrutura se repete em mais de 80%, crie um componente reutilizável.
   - **Root Cause Only:** Proibido adicionar `// ignore:`, `try/catch` vazios ou `mounted` checks sem tratar a retenção real da closure.
   - **Attack the Premise:** Se duas tentativas de conserto falharem o mesmo teste, pare. Redefina a premissa arquitetural a partir de primeiros princípios.

3. **Practice:**
   - Valide localmente usando `flutterguard validate` antes de submeter alterações.
   - Mantenha commits pequenos, atômicos e justificados.
```

---

## 6. Referências & Leituras Recomendadas para Pesquisa Aprofundada

### 📚 Repositórios Oficiais do Ecossistema Clean Code & Agentes
* **[unclebob/ub-mode](https://github.com/unclebob/ub-mode):** Repositório oficial do agente skill por Robert C. Martin.
* **[unclebob/crapper](https://github.com/unclebob/crapper):** Calculador do índice CRAP multiplataforma (Clojure, Java, Go, TypeScript, Rust, Python).
* **[unclebob/dryer](https://github.com/unclebob/dryer):** Detector determinístico de duplicação sintática.
* **[unclebob/mutator](https://github.com/unclebob/mutator):** Framework de testes de mutação para validação de suítes de teste.
* **[unclebob/uml-viewer](https://github.com/unclebob/uml-viewer):** Renderizador interativo de diagramas de componentes, CRAP scores e análise de dependências.
* **[poteto/pstack](https://github.com/poteto):** Inspiração original mencionada por Uncle Bob sobre regras rígidas de execução para agentes.

### 📄 Artigos & Papers Acadêmicos Fundamentais
1. **The CRAP Metric (Change Risk Anti-Patterns):**
   - *Autores:* Alberto Savoia & Bob Evans (Google / Agitar Software, 2007).
   - *Tese:* Artigo seminal que formalizou a combinação matemática entre complexidade ciclomática de McCabe e cobertura de testes para determinar probabilidade de defeitos.
   - *Link:* [CRAP4J Specification & Background](http://www.crap4j.org/)
2. **A Structured Metric for Program Complexity:**
   - *Autor:* Thomas J. McCabe (IEEE Transactions on Software Engineering, 1976).
   - *Tese:* O artigo fundador da Complexidade Ciclomática através de grafos de fluxo de controle (CFG).
3. **Clone Detection Using Abstract Syntax Trees:**
   - *Autores:* Ira D. Baxter, Andrew Yahin, et al. (IEEE International Conference on Software Maintenance, 1998).
   - *Tese:* Base matemática e algorítmica utilizada por ferramentas modernas de detecção de duplicação como o `dryer`.
4. **Mutation Analysis for Evaluating Test Suites:**
   - *Autores:* J. H. Andrews, L. C. Briand, Y. Labiche (IEEE Transactions on Software Engineering, 2005).
   - *Tese:* Demonstra empiricamente que testes de mutação são significativamente superiores à cobertura tradicional de linhas para expor falhas reais.

### 📖 Livros de Referência de Arquitetura e Engenharia
* **Clean Code: A Handbook of Agile Software Craftsmanship** — Robert C. Martin (Prentice Hall).
* **Clean Architecture: A Craftsman's Guide to Software Structure and Design** — Robert C. Martin (Prentice Hall).
* **Test Driven Development: By Example** — Kent Beck (Addison-Wesley).
* **Working Effectively with Legacy Code** — Michael Feathers (Prentice Hall).

