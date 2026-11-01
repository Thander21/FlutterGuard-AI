# 02. Meta Muse Code
### Engenheiro Executor de Código, Análise de AST e Loop de Autocura

---

## 1. O que é o Meta Muse Code?
O **Meta Muse Code** (junto à família Code Llama e variantes de código do Llama 3) é o modelo da Meta especialista em **gramática formal de linguagens de programação, raciocínio sintático e refatoração de código**. Ele possui uma taxa mínima de boilerplate, alta compreensão de tipos estáticos e capacidade de absorver contextos de erro de compiladores para realizar cirurgias precisas no código fonte.

---

## 2. Papel Específico no FlutterGuard-AI
No FlutterGuard-AI, o Muse Code atua na **Fase 2: Implementação e Autocura**:
1. **Passagem do Teste para GREEN:** Lê o contrato e os testes que estão falhando gerados pelo Muse Spark e escreve a implementação estritamente necessária em `lib/` para fazer a suíte passar.
2. **Respeito aos Guardrails Arquiteturais:** É instruído a seguir rigorosamente a separação de camadas (ex: Presentation, Domain, Data) sem introduzir acoplamentos proibidos.
3. **Autocura via Receitas Canônicas (*Self-Healing Loop*):**
   * Se o motor local de análise de AST (`dart analyze` ou AST Visitor em Dart) identificar uma violação (ex: criar um `ScrollController` dentro do método `build()` sem dar `dispose()`), o FlutterGuard-AI injeta o trecho de código acompanhado da receita canônica do catálogo (`docs/methodology/CANONICAL_RECIPES_CATALOG.md`).
   * O Muse Code recebe o padrão *Before / After* e refatora o código em um único turno de inferência.

---

## 3. Formato de Entrada e Saída (I/O)

### Payload de Autocura (Prompt de Refatoração AST):
```text
[SISTEMA]: Você é o Engenheiro Executor do FlutterGuard-AI.
[ERRO DE AST DETECTADO]: O widget 'ProductListWidget' instancia 'ScrollController' dentro do método build(). Isso causa vazamento de memória e perda de estado durante o rebuild.
[RECEITA CANÔNICA DE CORREÇÃO]:
  - Migre o widget para StatefulWidget (ou use um Hook / Controller em camada externa).
  - Inicialize o controller no initState().
  - Chame controller.dispose() obrigatoriamente no dispose().
[CÓDIGO ATUAL]:
{codigo_com_falha}
[TAREFA]: Retorne apenas a classe corrigida em Dart respeitando 100% da receita canônica.
```

---

## 4. Roteiro Prático de Estudos

1. **Uso do Pacote `analyzer` do Dart SDK:**
   * Entenda como navegar pela AST (`CompilationUnit`, `ClassDeclaration`, `MethodDeclaration`, `AstVisitor`).
   * Isso permitirá ao FlutterGuard extrair o nó exato com falha e enviar um contexto microscópico para o Muse Code, economizando tokens e evitando alucinações.
2. **Ciclo de Feedback Red/Green:**
   * Treine o comando local `flutter test --reporter json` para capturar a mensagem de falha em formato legível por máquina e alimentá-la no modelo.
3. **Estudo do Catálogo de Receitas Canônicas:**
   * Revise o arquivo [CANONICAL_RECIPES_CATALOG.md](../docs/methodology/CANONICAL_RECIPES_CATALOG.md) do projeto para mapear os 10 principais anti-patterns do Flutter que o modelo precisará corrigir.

