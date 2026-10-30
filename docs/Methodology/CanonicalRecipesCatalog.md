# Catálogo de Receitas Canônicas (Just-in-Time Pattern Catalog)

Este catálogo contém os padrões de correção que o **FlutterGuard AI** injeta cirurgicamente no prompt do agente de IA no momento exato em que uma violação é detectada pela AST ou pelos testes.

---

## 1. Padrões de Gerenciamento e Ciclo de Vida de Estado

### Regra `FG-ST-001`: Instanciação de Controladores no `build()`
* **Causa Raiz:** Instanciar controladores (`TextEditingController`, `ScrollController`, `AnimationController`) dentro do método `build()` faz com que um novo objeto seja criado a cada frame, vazando memória e perdendo o estado do cursor/scroll.
* **Proibido (Before):**
  ```dart
  // ERRADO: Cria uma nova instância a cada rebuild da tela
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    return TextField(controller: controller);
  }
  ```
* **Canônico (After - Opção A: ConsumerStatefulWidget):**
  ```dart
  // CORRETO: Controlado no ciclo de vida do State com descarte explícito
  class SearchInput extends ConsumerStatefulWidget {
    const SearchInput({super.key});
    @override
    ConsumerState<SearchInput> createState() => _SearchInputState();
  }

  class _SearchInputState extends ConsumerState<SearchInput> {
    late final TextEditingController _controller;

    @override
    void initState() {
      super.initState();
      _controller = TextEditingController();
    }

    @override
    void dispose() {
      _controller.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return TextField(controller: _controller);
    }
  }
  ```

---

## 2. Padrões de Concorrência e Integridade Assíncrona

### Regra `FG-ASYNC-002`: Uso de `BuildContext` após `await`
* **Causa Raiz:** Se o usuário navegar para fora da tela enquanto uma requisição assíncrona está em andamento, o `BuildContext` fica desmontado. Acessar `Navigator` ou `ScaffoldMessenger` sobre um contexto órfão lança exceção em tempo de execução.
* **Proibido (Before):**
  ```dart
  // ERRADO: Usa o context diretamente após operação assíncrona
  Future<void> submitOrder(BuildContext context, WidgetRef ref) async {
    await ref.read(orderServiceProvider).process();
    Navigator.of(context).pop(); // Crash se o widget foi desmontado durante o await!
  }
  ```
* **Canônico (After):**
  ```dart
  // CORRETO: Valida se o contexto continua montado antes de interagir com a UI
  Future<void> submitOrder(BuildContext context, WidgetRef ref) async {
    await ref.read(orderServiceProvider).process();
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }
  ```

---

## 3. Padrões de Isolamento Arquitetural (Clean Boundaries)

### Regra `FG-ARCH-003`: Chamada Direta de Persistência na UI
* **Causa Raiz:** Widgets de visualização não devem conhecer detalhes de banco de dados (`Drift`, `SQLite`) ou clientes HTTP (`Supabase`, `dio`). Isso impede testes unitários e acopla a interface.
* **Proibido (Before):**
  ```dart
  // ERRADO: Widget importando banco de dados diretamente
  ElevatedButton(
    onPressed: () async {
      final db = AppDatabase();
      await db.into(db.products).insert(Companion(...));
    },
    child: const Text('Salvar'),
  )
  ```
* **Canônico (After):**
  ```dart
  // CORRETO: A UI delega para um Notifier ou Provider desacoplado
  ElevatedButton(
    onPressed: () {
      ref.read(productFormNotifierProvider.notifier).saveProduct();
    },
    child: const Text('Salvar'),
  )
  ```

---

## 4. Padrões de Prevenção de Quebras de Layout (RenderFlex & Constraints)

### Regra `FG-LAY-004`: Lista com Altura Ilimitada dentro de Coluna
* **Causa Raiz:** Colocar um `ListView` diretamente como filho de uma `Column` gera o erro clássico: `Vertical viewport was given unbounded height`, pois a coluna não impõe restrição de altura vertical.
* **Proibido (Before):**
  ```dart
  // ERRADO: ListView sem restrição de altura dentro de Column
  Column(
    children: [
      const HeaderWidget(),
      ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) => Text('Item $index'),
      ),
    ],
  )
  ```
* **Canônico (After - Opção com Expanded):**
  ```dart
  // CORRETO: ListView recebe o espaço restante da Column de forma explícita
  Column(
    children: [
      const HeaderWidget(),
      Expanded(
        child: ListView.builder(
          itemCount: 10,
          itemBuilder: (context, index) => Text('Item $index'),
        ),
      ),
    ],
  )
  ```

---

## 5. Padrões de Imutabilidade de Estado

### Regra `FG-ST-005`: Mutação Direta de Estado em Riverpod / Bloc
* **Causa Raiz:** Modificar uma lista in-place (`state.items.add(item)`) preserva a mesma referência de memória do objeto, fazendo com que o Riverpod/Bloc não dispare o rebuild dos widgets que estão escutando.
* **Proibido (Before):**
  ```dart
  // ERRADO: Mutação direta de lista in-place
  void addItem(Item item) {
    state.items.add(item); // O Riverpod não detecta a mudança de referência!
    state = state;
  }
  ```
* **Canônico (After):**
  ```dart
  // CORRETO: Cria uma nova lista e uma nova instância de estado via copyWith
  void addItem(Item item) {
    state = state.copyWith(
      items: [...state.items, item],
    );
  }
  ```
