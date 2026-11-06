# FlutterGuard-AI — segundo piloto no ERP PDV D+

Data: 05/11/2026. Versão testada: `fb61306` (origin/main), com os itens P0 a P3 do
SYS-CAL-002 dados como concluídos. Base de comparação: `e07b523`, o primeiro piloto.

Método: o mesmo do primeiro piloto. Foi rodado o comando abaixo, a partir de um clone
limpo, contra o `lib/` do ERP: 694 arquivos, Dart 3.13.7, Windows x64, sem
`flutterguard.yaml`, sem `init` e sem nenhuma alteração no ERP. Cada regra teve
achados conferidos um a um no código.

```
dart run bin/flutterguard.dart check "<ERP>/lib" --json
```

Este relatório tem três partes:

1. o que melhorou em relação às críticas do primeiro piloto;
2. as críticas novas, que só apareceram porque agora a ferramenta lê o projeto inteiro;
3. as validações genéricas que o campodeforca tem e o FlutterGuard não tem.

---

## 0. Números das duas rodadas

| | `e07b523` (1º piloto) | `fb61306` (2º piloto) |
|---|---|---|
| Arquivos lidos sem erro | 254 / 694 | **694 / 694** |
| Erros de parse (`FG-SYN-017`) | 2.587 | **0** |
| `FG-FMT-016` no Windows | quebrava (linha de comando longa) | **roda** (lotes de 50) |
| Achados em arquivos gerados | 103 | **0** |
| Tempo | 21 s (abortado no FMT) | 31,6 s |
| Achados totais | 2.836 | 2.355 |
| Achados com sinal real (amostra) | ~0 | **poucos, mas existem** (ver §2) |

Os achados por regra no 2º piloto:

| Regra | Achados | Arquivos |
|---|---|---|
| `FG-MET-007` (aviso) | 1.913 | 146 |
| `FG-ASYNC-002` | 209 | 41 |
| `FG-CTX-006` | 71 | 18 |
| `FG-LINT-009` | 64 | 46 |
| `FG-KEY-001r` | 35 | 18 |
| `FG-LIFE-001` | 34 | 26 |
| `FG-RIV-001` | 19 | 11 |
| `FG-BUILD-014` | 5 | 3 |
| `FG-ARCH-003` | 5 | 5 |

Há ainda 76 achados duplicados, com mesmo arquivo, linha e regra. Exemplo:
`unawaited(Future.microtask(...))` gera dois `FG-BUILD-014` na mesma linha.

---

## 1. As críticas anteriores melhoraram?

| # | Crítica do 1º piloto | Situação | Prova |
|---|---|---|---|
| 1 | O analyzer 6 não lia os construtores primários (63% do `lib/`) | **Resolvida** | 0 erros de parse; `analyzer ^14.0.0` |
| 2 | `FG-FMT-016` quebrava no Windows | **Resolvida** | Rodou nos 694 arquivos, sem nenhum achado (o ERP está formatado) |
| 3 | Ruído em arquivos gerados | **Resolvida** | 0 achados em `*.g.dart` e `generated/` |
| 4 | `FG-RIV-001` apontava os builders de provider | **Parcial** | Os 92 achados caíram para 19, mas os 3 que conferi ainda são falsos positivos (§1.1) |
| 5 | `FG-LIFE-001` ignorava o `ref.onDispose` | **Parcial** | O `pdv_provider.dart:90` foi corrigido. O `boot_resolver_io.dart:47`, citado no critério de aceite do P1-2, **continua apontado** (§1.2) |
| 6 | `FG-BUILD-014` olhava o `Notifier.build` | **Parcial** | Funciona para quem herda direto de `Notifier`. O ERP herda de uma base intermediária (`BootResolverImpl extends BootResolver`), e o caso do piloto continua apontado. É o falso positivo conhecido que o TS-14 aceitou, e é justamente o caso real (§1.3) |
| 7 | `FG-ASYNC-002` confundia o rótulo `context:` | **Resolvida no caso citado, piorou no geral** | O rótulo não aparece mais, mas a regra foi de 5 para 209 achados, quase todos falsos positivos (§2.1) |
| 8 | `FG-LINT-009` proibia todo `// ignore:` | **Parcial: a gramática não bate com o ERP** | O ERP justifica na linha **de cima**; a ferramenta só aceita o comentário no fim da **mesma** linha. 28 dos 39 ignores apontados têm justificativa na linha de cima (§1.4) |
| 9 | O `init` conflitava com a governança | **Resolvida** | `--no-hook`, `--hook-command`, `--agents` opcional, e o `--mcp` fica de fora no ERP. Não testei executando: li o código e a SYS-CLI-001b |
| 10 | O mutation runner só rodava `dart test` | **Resolvida no papel** | Detecta `flutter_test` e permite trocar o comando de teste. Não testei de ponta a ponta no ERP. Ainda é o próximo passo de maior valor |
| 11 | Sobreposição com lints tipados | **Tabela publicada, com um erro** | O README manda desligar o `FG-ARCH-003` em quem tem validador de camadas. No ERP, ele achou violações que o `layer_direction_audit` não pega (§2.4). Manter a regra |

### 1.1 `FG-RIV-001`: os 19 que sobraram

Os três padrões que conferi são idiomas normais do Riverpod:

- `FutureProvider.autoDispose.family<…>((ref, x) { ref.watch(...) })`, em `company_page.dart:47`. Os modificadores `.autoDispose` e `.autoDispose.family` não entram no conjunto de fábricas, que só reconhece a fábrica pura e `X.family`.
- `FutureProvider.autoDispose<…>((ref) { ref.watch(...) })`, em `category_repository.dart:47`. Mesma causa.
- `Consumer(builder: (context, ref, _) => …ref.watch(...))`, em `pdv_page.dart:1177`. O `builder` do `Consumer`, assim como o do `ConsumerWidget`/`HookConsumer`, **é um build**, não um callback de evento.

**Correção:** tratar qualquer cadeia `Fábrica(.autoDispose|.family)*` como fábrica, e tratar `Consumer.builder` como escopo de build.

### 1.2 `FG-LIFE-001`: o caso do piloto continua falhando

```dart
ref
  ..onDispose(() => _warmUpSyncSubscription?.close())
```

Há duas lacunas aqui:

- o `onDispose` chamado em **cascata** (`ref..onDispose`) não é reconhecido, porque a ferramenta exige o `ref` puro como alvo;
- o `.close()` de `ProviderSubscription` talvez não conte como liberação. Confirmar no vetor de teste.

**Correção:** aceitar a cascata a partir de `ref` e incluir `close` entre os métodos que liberam o recurso.

### 1.3 `FG-BUILD-014` e a base intermediária

Usar uma lista de exclusão foi a decisão certa. Mas o caso real do ERP é uma subclasse
indireta, e com a análise só de parse esse caso não se resolve. Proposta: além de
`Notifier`/`AsyncNotifier`, excluir o `build()` cujo **tipo de retorno não é `Widget`**.
O `BootState build()` resolve sem precisar de tipo resolvido, porque o nome do tipo está
escrito na declaração.

### 1.4 `FG-LINT-009`: onde fica a justificativa

A convenção do ERP é esta:

```dart
// A tipagem de families é complexa e varia entre versões do Riverpod.
// ignore: specify_nonobvious_property_types
final companiesProvider = ...
```

**Correção:** aceitar como justificada a linha `// ignore:` precedida de um comentário
`//` que não seja doc e que não seja outro ignore, além da forma no fim da mesma linha.
O próprio SYS-CAL-002 já previa isso ("if the ERP's convention uses another separator,
the re-pilot will surface it").

---

## 2. Críticas novas (antes estavam escondidas pelo parse)

### 2.1 `FG-ASYNC-002`: 209 achados, praticamente todos falsos positivos — **grave**

O ERP compila com `use_build_context_synchronously: error`, que é um lint tipado. Então
qualquer achado da regra é falso positivo ou é um ponto cego do lint. Na amostra,
**6 de 6 eram falsos positivos**, por três causas:

- **Variável local ou propriedade chamada `context` que não é `BuildContext`.** Exemplos:
  `final context = await _fiscalContextService.getContext(...)`, um `FiscalContext`, em
  `emission_readiness_service.dart:64`; `tlsContext.context`, um `SecurityContext`, em
  `sefaz_soap_client_io.dart:70`. São 55 achados em arquivos de `data/`, `engine/` e
  `service`, que não têm widget nenhum. O arquivo campeão é o
  `nfce_sale_emission_service.dart`, com 31.
- **Proteção em bloco não reconhecida.** `if (mounted) { setState(...) }` em
  `printer_page.dart:70`, e `if (context.mounted) { …context… }` em
  `open_pdv_page.dart:115`. O TS-06 diz que aceita bloco protegido, mas na prática não
  aceita, pelo menos dentro de `try` e de closures.
- **Sombreamento por nome:** a regra assume que o identificador `context` é sempre o
  `BuildContext`.

**Correção mínima:** só considerar `context` quando ele é parâmetro de `build` ou getter
de `State`, ou seja, quando o arquivo declara uma classe Widget/State e o identificador
não foi redeclarado no escopo (`final context =`, parâmetro com outro tipo). Também
reconhecer o `if (mounted)` / `if (context.mounted)` envolvendo o uso. Até lá, a tabela
do README deveria dizer "desligue se usa `use_build_context_synchronously`", e não só
"pode desligar".

### 2.2 `FG-MET-007`: 1.913 avisos cobrem todo o resto

- Profundidade: 1.827 achados. Um teto de 5 níveis não cabe numa tela Flutter comum
  (`Scaffold → Padding → Column → Card → Row → Text` já passa disso).
- Parâmetros: 86 achados, a maioria em **modelos de dados** com construtor primário.
  Exemplo: `const new({required this.tenancyId, …})` em `company_model.dart`, com 29
  campos. A isenção para classes de dados não reconhece o construtor primário,
  provavelmente pela mudança de AST do P0-1.

**Correção:** isentar o construtor primário com formais `this.` e calibrar a
profundidade em dados de campo (o SYS-CAL-001 prevê isso). Na saída padrão, separar
aviso de erro, ou deixar o aviso desligado por padrão.

### 2.3 `FG-KEY-001r`: barulho com sinal fraco

- Aponta objetos que **não são widgets do Flutter**: `pw.Padding`/`EdgeInsets` do
  pacote `pdf` (`danfe_printer_service.dart:439`) e `_getNomeCfop`, que devolve
  `String` (`nfce_daily_cfop_chart.dart:367`).
- Exige key em `.map()` e `itemBuilder` de listas estáticas e não reordenáveis. A
  documentação do Flutter não pede isso; key só importa quando a lista reordena ou
  guarda estado. Deveria ser obrigatório só em `ReorderableListView` e em itens com
  estado (`StatefulWidget` ou que tenham controller).
- Sugestão: ignorar chamadas com prefixo de outro pacote (`pw.`) e métodos `_get*`,
  ou só valer quando o nome começa com maiúscula e o import vem do Flutter.

### 2.4 `FG-ARCH-003`: **tem sinal real**, manter a regra

- `cbenef_search_widget.dart:151` faz `db.select(db.cbenefRegras)` **dentro do widget**,
  e o `cclasstrib_search_widget.dart` segue o mesmo padrão. É uma violação real de
  camada (a ordem é Repository → Provider → UI) que o `layer_direction_audit` do ERP
  não pega, porque o `drift` é um pacote e não uma camada.
- `company_form_page.dart` e mais duas telas importam `supabase_flutter` para pegar o
  `PostgrestException`. É um cheiro de arquitetura mais fraco, mas legítimo.
- A tabela do README precisa mudar: ARCH-003 e validador de camadas **se complementam**.

### 2.5 `FG-LIFE-001`: sinal real misturado com dois tipos de falso positivo

- **Verdadeiro positivo:** `support_mode_selection_modal.dart:35`. Um
  `TextEditingController` criado no `State` e **sem `dispose()` nenhum** no arquivo.
  É vazamento real.
- **Falso positivo 1, posse:** um controller **recebido pelo construtor** de um
  `StatelessWidget` (`cnpj_input_step.dart:30`, `whatsapp_phone_field.dart:27`) não
  pertence ao widget. Só deveria ser apontado o campo que a própria classe instancia
  (com inicializador ou atribuição `= TextEditingController()`).
- **Falso positivo 2, classe que não é State:** serviços e workers liberam no `stop()`
  ou no `close()` (`fiscal_sync_worker.dart:113`, `hybrid_log_sink.dart:265`). Fora de
  `State`/`Notifier`, aceitar `close`, `stop`, `cancel` e `dispose` como método de
  liberação.

### 2.6 `FG-CTX-006`: choca com padrões legítimos

- Tipo de campo `Widget Function(BuildContext, …)` (`pdv_workspace_page.dart:44`) é uma
  **assinatura de builder**, não guarda contexto nenhum. Não deveria contar como
  "BuildContext must not be stored".
- Serviços de UI que recebem `BuildContext` como **parâmetro de método**
  (`NotificationService.showSuccess(context, …)` e os `*FieldBuilder.build(config,
  context)`) usam o mesmo fluxo explícito que a regra já aceita em funções de topo.
  Proposta: proibir só **campo** e **global** do tipo `BuildContext`. O parâmetro de
  método passa.

### 2.7 `FG-LINT-009` (catch vazio): falta separar severidades

Dos 25 achados, 13 são `catch (_) {}` totalmente vazios. Esses são sinal real, por
exemplo os três do `connection_io.dart` que o 1º piloto previu. Os outros 12 têm só um
comentário explicando, como `// Falha silenciosa na recuperação`. O lint
`empty_catches` aceita o catch com comentário. Proposta: catch vazio sem nada é erro;
catch só com comentário é aviso.

### 2.8 Saída e adoção

- **Não há baseline nem catraca.** Com 2.355 achados num legado, o único jeito de adotar
  hoje é desligar regras. O campodeforca resolve isso com uma contagem por arquivo
  contra uma baseline que só desce (CatchAllGuard, TestDoubles) e com uma allowlist
  versionada (`layer_allowlist.json`). Sem isso, a ferramenta não entra em projeto
  legado nenhum.
- **Não há modo só do diff.** O `check` só tem `--json` e `--include-generated`. O
  campodeforca roda a complexidade só no delta (merge-base com `origin/main`) e testes
  só dos arquivos alterados. Para o hook de pre-commit e o loop do agente, a análise do
  diff é o que importa.
- **Duplicatas:** 76 achados repetem arquivo, linha e regra. Deduplicar ou juntar as
  mensagens.

---

## 3. O que o campodeforca tem e o FlutterGuard não tem (só o que serve a qualquer projeto Flutter)

Ficam de fora o SDD e tudo que é do domínio do ERP: fiscal, tenancy, RLS, PowerSync,
Supabase, SmartForm e os hooks de IA.

### 3.1 Prioridade alta: barato, genérico e determinístico

| Gate do campodeforca | O que faz | Equivalente no FG | Sugestão |
|---|---|---|---|
| `CatchAllGuard` + baseline | Contagem de catch genérico sem tratamento, por arquivo, contra uma baseline que só desce | Só o catch vazio (LINT-009) | Baseline genérica para **todas** as regras (§2.8) |
| `Imports` (`layer_direction_audit`) | Direção de camadas configurável com allowlist | Só ARCH-003 (denylist fixa de pacotes) | Grafo de camadas configurável no `flutterguard.yaml` (`apps → … → kernel`) |
| `Complexity` (delta) | Complexidade ciclomática: aviso acima de 20 no diff, falha acima de 80 em tudo | MET-007 mede profundidade e parâmetros, não complexidade | Regra de complexidade ciclomática com modo diff (o CRAP já tem metade disso) |
| `PrintLogger` | Proíbe `print`/`debugPrint` fora do logger | Nenhum (`avoid_print` só pega `print`) | Regra com o logger configurável |
| `BannedAPIs` / `BannedUIAPIs` | Lista de APIs proibidas com exceções por arquivo (ex.: `SnackBar` fora do serviço de notificação) | Nenhum | Regra "banned symbols" configurável. É o mecanismo genérico mais pedido |
| `HardcodedColors` / `DesignTokens` | Sem `Color(0x…)`, raio ou espaçamento fixo fora do tema | Nenhum | Regra de tokens configurável (onde fica o tema e quais construtores são proibidos) |
| `i18n` | `Text('literal')` na UI sem l10n | Nenhum | Regra de string fixa em widget |
| `ArbMetadata` | Placeholder do `.arb` com `@key` | Nenhum | Checagem de l10n do Flutter |
| `LayoutPatterns` | `Text` direto num `Row` sem `Expanded`/`Flexible` (RenderFlex) | LAY-004 cobre só listas sem limite | Ampliar o LAY-004 para o "Defensive Text Pattern" |
| `Encoding` | UTF-8 válido e detecção de mojibake | Nenhum | Barato, essencial no Windows e em PT-BR |
| `OrphanGenFiles` | `.g.dart`/`.freezed.dart`/`.mocks.dart` sem o arquivo de origem | Nenhum | Agora que o FG ignora gerados, essa regra é o complemento natural |
| `ProviderNaming` | Provider termina em `Provider` | Nenhum | Regra simples de Riverpod |

### 3.2 Prioridade média: projeto e pacote

| Gate | O que faz | Sugestão |
|---|---|---|
| `flutter analyze --fatal-infos` | Analyzer completo, com tipos | O FG não roda o analyzer, e o SYN-017 só pega erro de sintaxe. Oferecer um passo `analyze` opcional ao `check` para ter um gate único |
| `TestPresence` | Arquivo de lógica novo em `lib/` exige teste | Regra de diff: arquivo novo sem `_test.dart` correspondente |
| `TestDoubles` | Double de fronteira só em `test/utils/`; mock que não cresce | Opcional, é opinativo |
| `SerialTags` | Teste serial só por `@Tags(['serial'])` no topo | Opcional |
| Testes só do que mudou (`select_changed_tests`) | Escolhe os testes afetados pelo diff | Junto com o modo diff, deixa o mutation runner viável em CI |
| `Assets` | Assets declarados no `pubspec.yaml` existem e vice-versa | Genérico e barato |
| `VersionFormat` | Formato da versão do `pubspec.yaml` | Barato |
| `DepAudit` | `pub outdated --json` com sinais de vulnerabilidade, versão descontinuada e incompatível | Genérico |
| `LicenseGuard` | Licença real de cada dependência (pub cache) contra uma lista de incompatíveis | Genérico; importa para software comercial |
| `DocLinks` | Links locais de Markdown quebrados | Genérico (o próprio repo do FG tem muitos docs) |
| `EnvKeys` / `EnvParity` | Paridade das chaves do `.env.example` com os `.env*` | Genérico, desde que nunca leia valores |
| `PiiLogging` | PII (documento, e-mail, senha) em log sem máscara | Genérico se os padrões forem configuráveis |
| `AsyncSafety` | Escrita no Drift sempre aguardada | Genérico para quem usa Drift (`unawaited_futures` cobre parte) |
| Auto-fix (`invoke_fix`) | encoding, `dart fix`, `dart format` e cabeçalhos antes de validar | O `heal` do FG só conserta as regras próprias; incluir `dart fix --apply` e `dart format` como passo 0 |

### 3.3 Recursos do motor que fazem falta (não são regras)

- **Execução paralela com relatório por gate** (PASS/WARN/FAIL e tempo). O FG roda as
  regras, mas não separa aviso de erro na saída padrão.
- **Ledger de evidência por execução** (o `evidence.jsonl` do campodeforca grava cada
  gate). O FG grava só no `grade`, não no `check`.
- **Soft gate com exit 2 (WARN)**, que não bloqueia, contra exit 1 (FAIL). Hoje o
  `check` só tem 0 ou 1.

---

## 4. Ordem recomendada para o FlutterGuard

1. **`FG-ASYNC-002`** (§2.1): escopo do `context` e proteção em bloco. É a regra que
   mais derruba a confiança na ferramenta.
2. **Baseline e modo diff** (§2.8). Sem isso não há adoção em legado.
3. Resto das correções parciais (§1.1 a §1.4) e falsos positivos de LIFE e CTX
   (§2.5 e §2.6).
4. `FG-MET-007` desligado por padrão ou calibrado; KEY só para reordenável ou com estado.
5. Gates genéricos de §3.1, nesta ordem: banned symbols, print/logger, tokens/cores,
   i18n, encoding, órfãos de gerados e camadas configuráveis.
6. Mutation runner de ponta a ponta numa regra fiscal do ERP (Backlog 113). Continua
   sendo o maior ganho isolado e ainda não foi testado em campo.

## 5. Veredito para o ERP agora

Melhorou muito: lê o projeto todo e não quebra mais no Windows. Mas ainda não vale
ligar como gate. A adoção seletiva pelo `flutterguard.yaml` v2 ficaria assim:

- **ligar só** `FG-ARCH-003` e `FG-ST-001`/`FG-ST-005`;
- `FG-LIFE-001` só **como aviso**;
- o resto desligado até as correções de §4.1 a §4.3.

O ganho imediato: 1 vazamento real, 2 widgets consultando o Drift direto e 13 catch
totalmente vazios.
