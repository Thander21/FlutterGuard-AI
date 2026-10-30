# Verificação Formal e Algoritmos Determinísticos de Escopo para Flutter / Dart
### Especificação dos Métodos Formais, Análise Estática Avançada e Autômatos de Controle do FlutterGuard Core Engine

> **Objetivo:** Estabelecer a fundamentação teórica e a especificação algorítmica dos 5 verificadores estáticos formais integrados ao **FlutterGuard Core Engine**.  
> Enquanto linters tradicionais operam por casamento de padrões sintáticos simples (regex/AST raso), esses algoritmos utilizam **Métodos Formais, Autômatos Finitos (DFA), Aritmética de Intervalos e Grafos de Fluxo de Controle (CFG)** para provar deterministicamente a ausência de classes inteiras de bugs e vulnerabilidades em código Flutter/Dart, com **custo zero de tokens e execução em milissegundos**.

---

## 🏛️ Matriz Geral dos Algoritmos Formais

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                      FLUTTERGUARD STATIC PROVER ENGINE                                  │
├────────────────────────────────┬───────────────────────────┬────────────────────────────┤
│ Algoritmo                      │ Base Teórica / Paper      │ Alvo de Erro no Flutter    │
├────────────────────────────────┼───────────────────────────┼────────────────────────────┤
│ 1. Typestate DFA Checker       │ Strom & Yemini (1986)     │ Async Gaps & Memory Leaks  │
│ 2. Symbolic Constraint Solver  │ Badros & Borning (2001)   │ RenderFlex & Box Collapse  │
│ 3. Build Purity & Slice Engine │ Mark Weiser (1984)        │ Rebuild Explosion & Impure │
│ 4. Happens-Before Race Prover  │ Leslie Lamport (1978)     │ Stale Async & Double-Tap   │
│ 5. Abstract State Lattice      │ Patrick Cousot (1977)     │ Boolean Soup / State Bugs  │
└────────────────────────────────┴───────────────────────────┴────────────────────────────┘
```

---

## 1. Algoritmo: Typestate Analysis & Liveness no CFG (Control Flow Graph)

* **Código da Regra:** `FG-FORMAL-001`
* **Base Teórica:** *Typestate: A Programming Language Concept for Enhancing Software Reliability* — Robert E. Strom & Shaula Yemini (IEEE Transactions on Software Engineering, 1986) / *Bodden et al.* (Clara Framework, 2010).

### 1.1. O Problema
No Flutter, objetos de recursos (`AnimationController`, `TextEditingController`, `StreamSubscription`, `FocusNode`) e referências contextuais (`BuildContext`) possuem restrições estritas de ciclo de vida.  
Linters tradicionais falham em detectar se um `BuildContext` é utilizado após um ponto assíncrono onde o widget pode ter sido desmontado (*async gap*), ou se um controlador alocado é garantidamente liberado em todos os caminhos de saída da rota.

### 1.2. Especificação Algorítmica

Modelamos o ciclo de vida do recurso como um Autômato Finito Determinístico (DFA) $\mathcal{M} = (Q, \Sigma, \delta, q_0, F)$:

```
           init()                    mount() / resume()
[UNALLOCATED] ───► [ALLOCATED] ─────────────────► [ACTIVE]
                       │                            │
                       │ dispose() / cancel()       │ dispose() / cancel()
                       ▼                            ▼
                   [DISPOSED] ─────────────────► [DEAD]
```

1. **Construção do CFG:** Para cada método que manipula o recurso, o FlutterGuard gera o Grafo de Fluxo de Controle (CFG) intraprocedural direcionado $\mathcal{G} = (V, E)$, onde cada nó $v \in V$ representa uma instrução (Statement) ou ponto de bifurcação (`if`, `switch`, `try/catch`, `await`).
2. **Propagação de Typestate:**  
   Calcula-se o estado do recurso na entrada e saída de cada bloco básico:
   $$\text{State}_{\text{in}}(v) = \bigsqcap_{p \in \text{Pred}(v)} \text{State}_{\text{out}}(p)$$
   Onde $\sqcap$ é o operador de encontro de semirreticulado (meet operator). Se um nó predecessor puder deixar o recurso em `DEAD` e outro em `ACTIVE`, o estado de entrada é marcado como $\bot$ (potencialmente inválido).
3. **Verificação de Async Gap (`BuildContext`):**  
   - Ao encontrar uma `AwaitExpression`, o estado do `BuildContext` associado transita imediatamente de $\text{VALID} \to \text{SUSPECT}$.
   - Se o nó seguinte for uma invocação consumindo `context` (ex: `Navigator.of(context)`, `context.read()`) **sem** que haja um nó de guarda dominante `IfStatement` com predicado `!mounted` ou `!isClosed` que retorne, o analisador acusa violação formal.
4. **Liveness Check de Descarte:**  
   $$\forall r \in \text{AllocatedResources}, \quad \forall \text{ExitPath} \in \text{CFG}(\text{dispose}), \quad \text{State}_{\text{final}}(r) = \text{DEAD}$$
   Se existir qualquer caminho no método `dispose()` que saia sem invocar `r.dispose()` ou `r.cancel()`, o commit é bloqueado por **Vazamento de Recurso Determinístico**.

---

## 2. Algoritmo: Propagação Simbólica de Restrições de Layout (*Symbolic Box Constraint Propagation*)

* **Código da Regra:** `FG-FORMAL-002`
* **Base Teórica:** *The Cassowary Linear Arithmetic Constraint Solving Algorithm* — Greg J. Badros & Alan Borning (ACM TOCHI, 2001) / *Interval Arithmetic* (R. E. Moore, 1966).

### 2.1. O Problema
No motor de renderização do Flutter, o layout é governado por uma única regra inviolável: *"Constraints go down. Sizes go up. Parent sets position."*  
A IA rotineiramente gera combinações proibidas, como colocar um `ListView` (com altura intrínseca infinita) dentro de uma `Column` (que passa restrição máxima de altura $h_{max} = \infty$) sem envelopá-lo em um `Expanded` ou `SizedBox`. Isso provoca o clássico erro fatal de tempo de execução:
`Vertical viewport was given unbounded height`.

### 2.2. Especificação Algorítmica

O FlutterGuard analisa a árvore declarativa de construtores de Widgets na AST via um **Resolvedor de Restrições por Aritmética de Intervalos**:

Cada nó de widget $W$ recebe um vetor de restrições de entrada:
$$\mathcal{C}_{in}(W) = \langle [w_{\min}, w_{\max}], [h_{\min}, h_{\max}] \rangle$$

Regras de transferência de restrições para nós canônicos:

| Widget Pai | Restrição Repassada aos Filhos |
| :--- | :--- |
| `Scaffold.body` | $\langle [0, \text{screenWidth}], [0, \text{screenHeight}] \rangle$ |
| `Column` (Eixo Vertical) | $h_{\min} = 0, \quad h_{\max} = \infty$ |
| `Row` (Eixo Horizontal) | $w_{\min} = 0, \quad w_{\max} = \infty$ |
| `Expanded` / `Flexible` | Converte restrição infinita do eixo principal em restrição finita proporcional ($\text{Tight / Loose}$). |
| `ListView` / `GridView` | Exige obrigatoriamente $h_{\max} < \infty$ no eixo de rolagem (a menos que `shrinkWrap: true`). |

#### Teorema do Colapso de Layout Não Delimitado:
Seja $W_{child}$ um nó filho na AST de $W_{parent}$:
$$\text{IsFlexContainer}(W_{parent}) \land W_{parent}.\text{Axis} = \text{Vertical} \implies h_{\max}(W_{child}) = \infty$$
$$\text{IsScrollable}(W_{child}) \land W_{child}.\text{shrinkWrap} \ne \text{true} \implies \text{RequiresBounded}(h_{\max}) = \text{true}$$

$$\text{Se } h_{\max}(W_{child}) = \infty \land \text{RequiresBounded}(h_{\max}) = \text{true} \implies \textbf{UNBOUNDED\_LAYOUT\_COLLAPSE}$$

* **Ação do Gate:** O analisador bloqueia a alteração em **0 tokens e ~1ms**, antes mesmo da suíte headless ou visual ser executada, e injeta a receita canônica: *"Envolva o ListView em um Expanded() ou adicione shrinkWrap: true"*.

---

## 3. Algoritmo: Program Slicing para Pureza de `build()` e Escopo Reativo

* **Código da Regra:** `FG-FORMAL-003`
* **Base Teórica:** *Program Slicing* — Mark Weiser (IEEE Transactions on Software Engineering, 1984) / *Dynamic Slicing* (Agrawal & Horgan, 1990).

### 3.1. O Problema
No Flutter, o método `build(BuildContext context)` pode ser chamado até 60 ou 120 vezes por segundo durante animações ou gestos.  
A IA rotineiramente introduz efeitos colaterais impuros dentro do `build()`, como:
- Alocação de novos controladores (`final controller = TextEditingController();`).
- Abertura de sockets ou chamadas a APIs assíncronas.
- Posicionamento de `ref.watch()` na raiz de árvores complexas, forçando a reconstrução de dezenas de widgets estáticos que não usam aquele estado.

### 3.2. Especificação Algorítmica

1. **Fatia de Pureza Estática (Build Purity Slice):**
   Isola-se o corpo do método `build()`. O algoritmo inspeciona todas as instruções geradoras de fluxo de dados. Define-se a impureza se o nó contiver:
   $$\text{ImpureNode} \iff \text{HasSideEffect}(\text{node}) \lor \text{IsLifecycleAllocation}(\text{node}) \lor \text{IsAsyncCall}(\text{node})$$
   - Se qualquer invocação pertencer ao conjunto de classes de ciclo de vida (`ChangeNotifier`, `Controller`, `FocusNode`) e não for decorada como `const`, o gate bloqueia o código por **"Impureza Crítica em Método Idempotente"**.

2. **Fatiamento de Dependência Reativa (Reactivity Dependency Slicing):**
   Para cada ponto de escuta de estado reativo $S$ (`ref.watch(provider)`, `context.watch<T>()`):
   - Computa-se a **Fatia Direcionada para Frente (*Forward Slice*)** $\mathcal{S}_F(S)$: o subconjunto de nós da árvore de widgets que efetivamente leem valores derivados de $S$.
   - Calcula-se a Taxa de Rebuild do Escopo:
     $$\text{RebuildWasteIndex} = 1 - \frac{|\mathcal{S}_F(S)|}{|\text{TotalNodes}(\text{Subtree})|}$$
   - **Regra Bloqueante:** Se $\text{RebuildWasteIndex} > 0.80$ (ou seja, mais de 80% dos widgets da subárvore são reconstruídos à toa sem consumir o estado), o gate bloqueia o código e orienta: *"Mova o ponto de escuta para um Consumer dedicado ou extraia os widgets irmãos para const StatelessWidget"*.

---

## 4. Algoritmo: Análise *Happens-Before* para Concorrência Assíncrona e Race Conditions

* **Código da Regra:** `FG-FORMAL-004`
* **Base Teórica:** *Time, Clocks, and the Ordering of Events in a Distributed System* — Leslie Lamport (Communications of the ACM, 1978) / *Effective Static Race Detection for Java* (Naik, Aiken et al., PLDI 2006).

### 4.1. O Problema
Em aplicações Flutter conectadas a APIs ou microserviços (como o PDV D+), múltiplos eventos disparados pelo usuário em rápida sucessão criam **condições de corrida assíncronas (*Stale Async Responses*)**:
- O usuário pesquisa por `"café"`, gerando a requisição $R_1$.
- Imediatamente digita `"café expresso"`, gerando $R_2$.
- $R_2$ responde em 200ms (mostrando itens corretos).
- $R_1$ sofre lentidão de rede e responde em 1.5s, sobrescrevendo a tela com dados defasados.

### 4.2. Especificação Algorítmica

Modelamos a execução de manipuladores assíncronos (`async event handlers`) através da relação causal estrita de Lamport $\prec$ (*happens-before*):

Sejam dois disparos de evento $e_1, e_2$ tais que $e_1 \prec_{\text{dispatch}} e_2$:
A garantia de consistência de estado final exige que o estado refletido na UI obedeça:
$$\text{State}_{\text{final}} = f(e_2) \iff \text{Commit}(e_1) \prec_{\text{state}} \text{Commit}(e_2)$$

O FlutterGuard inspeciona os blocos `async` em classes gerenciadoras de estado (`Bloc`, `Cubit`, `Notifier`, `ViewModel`):
1. **Identificação de Mutações de Estado Assíncronas:** Localiza chamadas `.emit(...)` ou atribuições `state = ...` precedidas por pelo menos uma `AwaitExpression`.
2. **Grafo de Causalidade:** O verificador busca no caminho de execução uma das seguintes garantias de causalidade:
   - **Transformador de Concorrência Estrutural:** Registro do evento com política `restartable()` (cancela a execução anterior) ou `droppable()` (ignora o novo disparo enquanto o anterior estiver ativo).
   - **Token de Sequência Monotônica:** Existência de uma variável inteira atômica (`currentRequestId++`) verificada antes da mutação de estado:
     ```dart
     final requestId = ++_latestRequestId;
     final data = await api.search(query);
     if (requestId != _latestRequestId) return; // Happens-before guarantee
     ```
   - **Objeto Cancelável:** Uso de `CancelableOperation` ou `CancellationToken`.
3. **Bloqueio:** Se nenhuma das 3 garantias for detectada no caminho assíncrono, o gate rejeita a alteração por **Vulnerabilidade Crítica a Resposta Assíncrona Obsoleta (Stale Race Condition)**.

---

## 5. Algoritmo: Abstract Interpretation & Álgebra de Tipos para Máquinas de Estado

* **Código da Regra:** `FG-FORMAL-005`
* **Base Teórica:** *Abstract Interpretation: A Unified Lattice Model for Static Analysis of Programs* — Patrick Cousot & Radhia Cousot (POPL, 1977) / *Robin Milner* (Álgebra de Tipos Soma).

### 5.1. O Problema: A "Sopa de Booleanos"
Agentes de IA frequentemente modelam o estado de uma tela ou requisição através de múltiplos booleanos soltos e campos anuláveis independentes:
```dart
// ANTI-PATTERN: Espaço de estados explosivo e estados impossíveis
bool isLoading = false;
bool hasError = false;
String? errorMessage;
User? user;
```
Esse formato gera $2^2 \times \text{dom}(String) \times \text{dom}(User)$ estados possíveis no reticulado, incluindo **estados contraditórios impossíveis** (ex: `isLoading = true` E `hasError = true` simultaneamente).

### 5.2. Especificação Algorítmica

O FlutterGuard aplica o conceito de **Reticulado Abstrato de Tipos Soma (Sum-Type Lattice Model)**:

```
                  [State (sealed)]
                   /     |      \
                  /      |       \
          [Loading]  [Success]  [Error]
```

1. **Varredura de Campos de Estado:** O AST Visitor computa a densidade de booleanos mutáveis associados a fluxos assíncronos. Se detectar $\ge 2$ booleanos ortogonais coordenando estados de interface, o código viola a regra formal de invariante.
2. **Exigência de Hierarquia Selada (`sealed class`):**
   O estado DEVE ser modelado como uma família de tipos algébricos fechados:
   ```dart
   sealed class ScreenState {}
   class ScreenLoading extends ScreenState {}
   class ScreenSuccess extends ScreenState { final User user; ScreenSuccess(this.user); }
   class ScreenError extends ScreenState { final String message; ScreenError(this.message); }
   ```
3. **Verificação de Exaustividade Sem Coringas (Zero Default Wildcard):**
   Na camada de apresentação (Widgets), o FlutterGuard audita o consumo do estado:
   - Exige que o estado seja consumido através de uma **Switch Expression ou Switch Statement com Pattern Matching**.
   - Proíbe estritamente a cláusula descartável padrão (`case _:` ou `default:`).
   - **Garantia Formal:** O compilador do Dart e a árvore do Flutter provam matematicamente que todo estado novo adicionado na arquitetura obrigará o tratamento explícito na interface gráfica, erradicando telas brancas e crashes silenciosos.

---

## ⚡ Integração no Pipeline do Campo de Força (Force Field Harness)

Os 5 algoritmos formais são distribuídos de acordo com o custo computacional nos portões de execução:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. GATE LIGHT (`validate-light` - ~1s)                                      │
│    • FG-FORMAL-003: Pureza do método build()                                │
│    • FG-FORMAL-005: Álgebra de Estados e eliminação de Sopa de Booleanos    │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2. GATE COMPLETO (`validate` - ~5s a 15s)                                   │
│    • FG-FORMAL-001: Typestate Analysis & CFG Liveness (Async gaps & dispose)│
│    • FG-FORMAL-002: Symbolic Box Constraint Solver (RenderFlex prevention)  │
│    • FG-FORMAL-004: Happens-Before Concurrency & Stale Race Prover          │
└─────────────────────────────────────────────────────────────────────────────┘
```

> **Garantia de Eficiência:** Todos os 5 analisadores operam através do `package:analyzer` do Dart SDK, compartilhando a mesma passagem de resolução da AST em memória, resultando em um acréscimo inferior a **40 milissegundos** no tempo total de checagem.

