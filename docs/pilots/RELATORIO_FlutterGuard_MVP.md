# Avaliação externa do FlutterGuard-AI: validação do MVP

**Data:** 07/11/2026 · **Alvo:** ERP PDV D+ (`lib/`) · **Modo:** somente leitura, de fora do alvo

## 0. Ambiente

| Item | Valor |
|---|---|
| Dart | 3.13.7 (stable, 22/10/2026), windows_x64 |
| Flutter | presente: 3.47.9 stable (não usado pelo `check`) |
| SO | Windows 11 Pro, PowerShell 7 |
| Commit do FG | `bc46a7bc40ba133d5b84acbcf89becf16896556e` ("docs: sync rule/skill counts with the 33-rule registry") |
| Isolamento | **Opção A**: worktree destacada a partir do clone local do autor. O commit **não está no GitHub** (HEAD remoto = `3f2bf85`; `fetch` do SHA dá "not our ref"), então a Opção B não reproduz este commit. |
| Commit do alvo | `a6e17772673d82e6919bb4a898edbca7401d52f0` (main) |
| Denominador | **697** arquivos `.dart` em `lib/` |

## 1. Rodada principal

| Execução | Exit | Tempo |
|---|---|---|
| `check lib --json` | 1 (há erros) | 39,8 s |
| `check lib --by-gate` | 1 | 36,6 s |
| `check lib --json --jobs 4` | 1 | 28 s |

`--by-gate`: 33 gates (13 FAIL, 1 WARN, 19 PASS). O FMT-016 é o mais lento (10,6 s) e o ARCH-003 vem depois (1,4 s).

## 2. Tabelas

### Manchete

| Métrica | Valor |
|---|---|
| Arquivos lidos sem erro | **697/697 (100%)**: `errors: []` no JSON |
| Erros de parse (FG-SYN-017) | 0 |
| FMT no Windows (FG-FMT-016) | roda, 0 achados |
| Achados em arquivos gerados | 0 |
| Total | **2.353** (516 erros, 1.837 avisos) em 222 arquivos |
| Duplicatas (file, line, rule) | **0** |
| Silenciosas sem config (BAN-018, LOG-019, I18N-021, ORP-023, LYR-024, TST-033) | **todas ausentes** ✔ |

### Por regra

| rule_id | Achados | Arquivos | Severidade |
|---|---:|---:|---|
| FG-MET-007 | 1.826 | 132 | warning |
| FG-ASYNC-002 | 169 | 38 | error |
| FG-TOK-020 | 111 | 3 | error |
| FG-ENC-022 | 109 | 66 | error |
| FG-LAY-004 | 80 | 41 | error |
| FG-LINT-009 | 34 | 21 | 23 error / 11 warning |
| FG-LIFE-001 | 14 | 11 | error |
| FG-ARCH-003 | 5 | 5 | error |
| FG-RIV-001 | 2 | 2 | error |
| FG-BUILD-014 | 1 | 1 | error |
| FG-CC-025 | 1 | 1 | error |
| FG-KEY-001r | 1 | 1 | error |

Regras sem achados, ou seja, **sem testemunha neste corpus**: ST-005, CTX-006, WID-008, BLOC-001, ST-001, IMP-015, FMT-016, SYN-017, RIV-026, ARB-027, PII-028, ENV-029, ASSET-030, VER-031, DOC-032.

## 3. Amostragem TP/FP

Caminhos relativos a `lib/`.

### FG-ARCH-003: todos os 5 (3/5 TP)
- `modules/registry/ui/widgets/cbenef_search_widget.dart:10`: **TP**. A UI importa `drift` e consulta o banco direto.
- `modules/registry/ui/widgets/cclasstrib_search_widget.dart:9`: **TP**. Mesmo padrão.
- `modules/identity/ui/users/user_form_page.dart:26`: **TP**. Usa `sb.Supabase.instance.client` na UI.
- `modules/company/ui/company_form_page.dart:27`: **FP**. Importa só para `PostgrestException` num `catch`, sem acesso a dado.
- `modules/identity/ui/login/web_login_page.dart:32`: **FP**. Importa só para `on AuthException`.

### FG-RIV-001: todos os 2 (0/2 TP)
- `modules/company/ui/pos_terminal/pdv_terminal_page_smartform.dart:140`: **FP**. O `ref.watch` está no `child: Text(...)` do `TextButton`, em tempo de build. Só o `onPressed` vizinho é callback, e ele já usa `ref.read`.
- `verticals/food_service/ui/tables/widgets/printer_health_badge.dart:32`: **FP**. `Consumer(builder:)` dentro do `builder` de `showDialog`. O `ref` é do próprio `Consumer`, então o `watch` está correto (classe já vista no 2º piloto).

### FG-BUILD-014: 1 (1/1 TP)
- `modules/dashboard/ui/dashboard_page.dart:89`: **TP**. `FutureBuilder(future: Future.wait([...]))` recria o future a cada rebuild. A mensagem sugere "ou um FutureBuilder", mas a chamada já está dentro de um: o texto da dica merece revisão.

### FG-CC-025: 1 (1/1 TP)
- `modules/fiscal/ui/certificate/digital_certificate_page_smartform.dart:465`: **TP**. A complexidade 82 é real. O projeto marca a função com `// ignore: cyclomatic_complexity` e o FG não lê esse marcador (não é a sintaxe dele), o que é esperado.

### FG-KEY-001r: 1 (0/1 TP)
- `modules/fiscal/ui/sequence_report_page.dart:278`: **FP**. `_SequenceCard` é `StatelessWidget` numa lista paginada sem reordenação, sem estado para casar errado.

### FG-ASYNC-002: amostra de 12 em 12 arquivos (**0/12 TP**)
- `apps/desktop/main.dart:160`: **FP**. Não há `await` antes da linha; o `await` só aparece num comentário.
- `modules/company/ui/printers/printer_page.dart:70`: **FP**. `setState` dentro de `if (mounted) { ... }`.
- `modules/fiscal/ui/certificate/digital_certificate_page_smartform.dart:186`: **FP**. `context` no `builder` do próprio `await showDialog(...)`, antes do gap.
- `modules/identity/ui/login/web_login_page.dart:122`: **FP**. `session != null && mounted` na mesma condição, sem `await` antes.
- `modules/notifications/ui/notification_settings_page.dart:109`: **FP**. `builder` de `showDialog`, como acima.
- `modules/registry/ui/customer_list_page.dart:40`: **FP**. `setState` na 1ª linha do método, antes de qualquer `await`.
- `modules/reseller/ui/reseller_page_smartform.dart:128`: **FP**. Protegido por `if (!context.mounted) return;` na linha 125.
- `shared/form/smart_form.dart:353`: **FP**. `setState` antes do `await`.
- `modules/company/ui/setup/desktop_setup_page.dart:149`: **FP**. Tem `if (!mounted) return;` depois do `await`; o `context` está em `showDialog(context:)`.
- `verticals/counter/ui/pages/pdv_page.dart:289`: **FP**. `if (!mounted) return;` logo antes.
- `platform/update/update_service.dart:243`: **FP**. `context != null && context.mounted` na mesma condição.
- `verticals/waiter/ui/pages/waiter_cart_page.dart:44`: **FP**. Não há `await` antes.

Classes de FP: (a) `context` dentro do argumento ou `builder` do próprio `await`; (b) uso antes do 1º `await`; (c) guarda `if (!mounted) return;` ou `&& context.mounted` não reconhecida; (d) corpo de `if (mounted) {}`. Uma triagem automática dos 169 achou 97 com `mounted` depois do último `await` e 23 sem `await` antes. Os 49 restantes, amostrados (4), também são FP.

### FG-TOK-020: censo dos 111 (3/111 no total; 1–3 TP fora do tema)
- `themes/color_schemes.dart:17`, um de **108** achados no arquivo: **FP**. É o próprio arquivo de tema. A regra vem ligada por padrão com `except` vazio (`theme_token_guard.dart`, `defaults: const {}`).
- `apps/garcom/main.dart:37`: **TP pela regra**. `seedColor` literal com `// ignore: design_tokens` e justificativa do projeto.
- `apps/desktop/shell/app_shell_page.dart:420`: **TP**. `Color(0x00000000)` deveria ser `Colors.transparent` ou um token.

### FG-ENC-022: censo dos 109 por regex de mojibake (**4/109 TP**)
- `modules/company/data/terminal_model.dart:80` e `:82`: **TP**. `Ãšltimo` é o mojibake real de "Último".
- `modules/identity/emergency_auth_service.dart:38`: **TP**. `PÃšBLICOS`.
- `shared/form/form_section_config.dart:40`: **TP**. `Ã\x8dcone`, o mojibake de "Ícone".
- `apps/desktop/boot/boot_resolver_io.dart:123` (`HIDRATAÇÃO`): **FP**. É maiúscula legítima do português.
- `kernel/text/string_utils.dart:14` (tabela `ÀÁÂÃÄ…`): **FP**. É uma tabela de acentos intencional.
- `modules/fiscal/domain/ibs_cbs_item_mapper.dart:51` (`NÃO`), `modules/registry/data/product_data_source.dart:121` (`SINCRONIZAÇÃO`), `platform/sync/powersync_database_service.dart:143` (`PERMISSÃO`): **FP**, o mesmo caso.

A causa está na spec, não no código. O TS-22 trata U+00C3 (Ã) e U+00C2 (Â) como marcadores sozinhos e afirma que "texto acentuado legítimo nunca dispara". Isso vale para minúsculas, mas em português "Ã" maiúsculo é comum ("NÃO", "-ÇÃO"). O detector precisa do par (Ã/Â seguido de um caractere C1 ou Latin-1 de continuação), não do código isolado.

### FG-LAY-004: amostra de 7 em 7 arquivos (2/7 TP)
- `apps/desktop/workspaces/open_pdv_page.dart:143`: **TP**. Texto l10n longo no título de um `AlertDialog`, ao lado de um ícone.
- `modules/sales/ui/sale_history/sale_history_page.dart:160`: **TP plausível**. Rótulo dinâmico (data mais rótulo) sem limite.
- `modules/dev_admin/ui/catalog_theme_page_smartform.dart:241`: **FP**. Rótulo curto ("Adicionar") depois de um botão.
- `modules/fiscal/ui/sequence_report_page.dart:420`: **FP**. "Página x de y" entre setas.
- `verticals/counter/ui/widgets/pdv_action_buttons.dart:180`: **FP**. Rótulo curto de atalho.
- `verticals/counter/ui/widgets/pdv_total_bar.dart:58`: **FP**. Rótulo fixo em `spaceBetween`.
- `verticals/food_service/ui/checkout/widgets/item_split_panel.dart:86`: **FP**. O irmão já é `Expanded` com ellipsis; este Text é o lado fixo, que é o padrão correto.

### FG-LINT-009: censo das suppressions e amostra de catch
- Catch vazio `{}`, 13 erros, amostra de 3 (`platform/audit/audit_service.dart:101`, `platform/database/connection/connection_io.dart:47`, `platform/network/local_hub/discovery/lan_discovery_scanner_io.dart:196`): **3/3 TP**.
- `// ignore:` sem justificativa, 10 erros: **3/10 TP** (`modules/identity/auth_provider.dart:84`, `modules/licensing/license_validator_service.dart:207`, `shared/form/field_builders/form_lookup_ports.dart:40`). Os outros 7 (`pdv_terminal_page_smartform.dart:45` e `:49`, `catalog_theme_page_smartform.dart:49–61`) são **FP de formato**: a justificativa está na mesma linha, mas como `, justificativa: …` ou ` - motivo`, e o FG só aceita `// rationale`.
- Catch só com comentário, 11 avisos, amostra de 3 (`modules/fiscal/engine/6_soap_client/fiscal_tls_diagnostic.dart:91`, `sefaz_soap_client_io.dart:222`, `modules/identity/data/local_company_context_service.dart:119`): **questão de política**. O `empty_catches` do próprio Dart aceita o comentário; o FG rebaixa para aviso, o que é razoável.

### FG-LIFE-001: censo dos 14 (2/14 TP)
- `modules/identity/ui/support_mode_selection_modal.dart:35` e `:36`: **TP**. Dois `TextEditingController` sem `dispose()`; o vazamento já tinha sido visto no 2º piloto e segue lá.
- `modules/registry/ui/widgets/cbenef_search_widget.dart:40` e `cclasstrib_search_widget.dart:60`: **FP**. O controller pertence ao `Autocomplete` (`fieldViewBuilder`) e não deve ser descartado.
- `platform/boot/window/window_helper_io.dart:24`: **FP**. Wrapper estático de `addListener`, sem ciclo de vida próprio.
- `platform/logger/hybrid_log_sink.dart:179`: **FP**. Liberado em `destroy()`, o ciclo de vida do `LogOutput`.
- `platform/network/local_hub/discovery/lan_discovery_scanner_io.dart:41` e `:42`: **FP**. `dispose()` chama `stopScanning()`, que cancela.
- `platform/update/update_service.dart:51` e `:52`: **FP**. Liberados em `stopPeriodicCheck()`.
- `verticals/food_service/printer_health_monitor.dart:37`: **FP**. `ref.onDispose(() { stop(); })`.
- `verticals/waiter/data/waiter_hub_client.dart:43`: **FP**. `dispose()` chama `disconnectWebSocket()`, que cancela.
- `verticals/waiter/data/waiter_repository.dart:32`: **FP**. `dispose()` chama `_stopBackgroundSync()`.
- `verticals/waiter/ui/controllers/waiter_tables_controller.dart:87`: **FP**. Cancelado num closure de `ref.onDispose`.

**Classe nova de FP:** a regra não segue a liberação feita por um método auxiliar chamado no `dispose`/`onDispose`/`destroy`. Ela também não reconhece outros métodos de ciclo de vida (`destroy`, `stop*`).

### FG-MET-007: amostra de 5 em 5 arquivos (medição 5/5 correta)
- `apps/desktop/settings/general_page.dart:85`: **TP métrico**. Profundidade 6 confere (Scaffold, ListView, Card, Column, ListTile, Text).
- `shared/widgets/dialogs/double_confirmation_dialog.dart:105`: **TP métrico**.
- `modules/fiscal/domain/fiscal_emission_request.dart:53`: **TP métrico, valor baixo**. Construtor com 35 parâmetros nomeados num value object imutável.
- `modules/registry/domain/complement_group.dart:37` (11 parâmetros) e `verticals/food_service/domain/table_session.dart:16` (10): **TP métrico, valor baixo**. Entidades `const` com parâmetros nomeados são idiomáticas no Dart.

O ruído vem do formato: **um achado por linha** acima do orçamento (1.681 de profundidade, 72 linhas com 2 mensagens fundidas) e um orçamento baixo (5 níveis, 7 parâmetros). Profundidades: 6 = 695, 7 = 492, 8 = 335, ≥9 = 304.

## 4. Julgamento por regra

| Regra | Precisão na amostra | Julgamento | Padrão |
|---|---|---|---|
| FG-ASYNC-002 | 0/12 | **BLOQUEADORA** | 169 erros quase todos falsos; guardas `mounted` e o `context` dentro do próprio `await` não reconhecidos |
| FG-ENC-022 | 4/109 (censo) | **BLOQUEADORA** em corpus PT-BR | Ã e Â maiúsculos legítimos tratados como marcador (erro na spec TS-22); os 4 TPs são valiosos |
| FG-TOK-020 | 3/111 (censo) | RUIDOSA sem yaml | ligada por padrão sem `except`, o arquivo de tema dispara; com `except: [lib/themes/**]` vira CONFIÁVEL |
| FG-LIFE-001 | 2/14 (censo) | RUIDOSA | liberação via método auxiliar ou `onDispose` não seguida; controller do Autocomplete |
| FG-LAY-004 | 2/7 | RUIDOSA | Text curto ou fixo ao lado de um irmão flexível |
| FG-RIV-001 | 0/2 | RUIDOSA | `child:` de botão e `Consumer.builder` em diálogo vistos como callback |
| FG-MET-007 | 5/5 na medição | RUIDOSA (aviso) | um achado por linha; parâmetros de entidade imutável |
| FG-LINT-009 | erros 16/23 | CONFIÁVEL com ressalva | catch vazio é sinal limpo; justificativa só no formato `// rationale` |
| FG-ARCH-003 | 3/5 | CONFIÁVEL | FPs explicáveis: import só para tipo de exceção |
| FG-BUILD-014 | 1/1 | CONFIÁVEL (n=1) | dica da mensagem imprecisa |
| FG-CC-025 | 1/1 | CONFIÁVEL (n=1) | — |
| FG-KEY-001r | 0/1 | RUIDOSA (n=1, inconclusiva) | item Stateless em lista sem reordenação |

## 5. Defaults

As 6 regras silenciosas sem config (BAN-018, LOG-019, I18N-021, ORP-023, LYR-024, TST-033) deram PASS com 0 achados. **Não há bug de default.** O único problema de default é de outra natureza: o TOK-020 vem ligado sem `except` padrão.

## 6. Demo de adoção (baseline em `<OUT>`)

| Passo | Exit | Tempo | Resultado |
|---|---|---|---|
| `--baseline <OUT>\baseline.json --update-baseline` | 0 | 39 s | "Baseline written…: 222 files, 2353 findings (516 errors, 1837 warnings)" ✔ |
| `--baseline <OUT>\baseline.json` | 0 | 43 s | "0 violation(s)" ✔ verde |
| `--diff --diff-base origin/main` | 0 | 14 s | 0 violações. A working tree não tinha `.dart` alterado, então está correto. |
| Extra: `--diff --diff-base HEAD~3` | 1 | — | 30 achados, **só** em arquivos tocados pelo rzero30. O escopo é **por arquivo**, não por linha. |
| Extra: `--diff` em pasta sem git | 2 | — | "git rev-parse --show-toplevel failed (not a git repo)". Bloqueia e diz a causa ✔ |

Ressalvas do baseline:
1. As chaves são **caminhos absolutos** (`W:/_Projetos/...`). O baseline não é portátil entre máquinas, checkouts ou o CI. Recomendo caminho relativo à raiz do projeto.
2. O formato é uma **contagem por (arquivo, regra)**. É robusto a deslocamento de linhas, mas um achado novo que substitua outro corrigido no mesmo arquivo passa despercebido. Para MVP, é aceitável.
3. O `--diff` é por arquivo. Em arquivos grandes legados (`digital_certificate_page_smartform.dart`), tocar uma linha traz todo o passivo do arquivo. Combinar `--diff` com `--baseline` resolve.

## 7. Opcional

- `--jobs 4`: o conjunto (file, line, rule_id) é **idêntico** ao da rodada principal (2.353 = 2.353, diferença 0), em 28 s contra 40 s (−30%).
- `--analyze` (à parte): passou sem issues, +16 s. Coerente com o `flutter analyze --fatal-infos` limpo do ERP.
- `--dep-audit` e `--license-audit`: **não rodados**. Eles disparam `dart pub outdated` no alvo, que pode gravar no `.dart_tool`, e isso violaria o não-poluimento. Além disso, `lib/` não tem `pubspec.yaml`.

## 8. Não-poluimento

- **Antes:** ` M .agents/rules/qualitytests.md`, HEAD `a6e17772`.
- **Depois:** limpo, HEAD `a6e17772`. A diferença **não veio do FG**. Outra sessão de IA que trabalha em paralelo na worktree `.claude/worktrees/rzero31` regravou `qualitytests.md` e o `.git/index` às 13:44:42; os arquivos dessa worktree seguiam mudando até 13:53. Uma varredura por data de escrita mostra **nenhuma escrita em `lib/`** durante as rodadas e nenhum `flutterguard.yaml`, hook ou baseline no alvo. Todos os artefatos ficaram em `<OUT>`.

## 9. Veredito MVP

- **a) Crash ou erro de parse em arquivo válido?** Não. 0 crashes, 0 FG-SYN-017, `errors: []`.
- **b) Cobertura de leitura?** 697/697 (100%), sem achados em gerados.
- **c) Precisão por regra?** Alta em ARCH-003 (3/5), BUILD-014, CC-025 e no catch vazio do LINT-009. Baixa em LAY-004 (2/7), LIFE-001 (2/14) e RIV-001 (0/2). **Inaceitável** em ASYNC-002 (0/12) e ENC-022 em PT-BR (4/109). Essas duas regras somam 54% dos erros (278 de 516); com os 108 do arquivo de tema no TOK-020, chega a 75% (386 de 516).
- **d) Tempo aceitável?** Sim. 40 s sequencial e 28 s com `--jobs 4` para 697 arquivos; o diff leva 14 s.
- **e) Baseline e diff funcionam para adoção em legado?** Sim. O 1º passo dá exit 0, o 2º fica verde e o diff escopa e bloqueia com causa. A ressalva é o caminho absoluto no baseline.

**Recomendação: APROVAR-COM-RESSALVAS.** O motor (leitura, desempenho, baseline, diff, `--jobs`) está pronto para MVP, mas não com as regras padrão: só com um yaml seletivo.

**Top 3 bloqueadores:**
1. **FG-ASYNC-002:** reconhecer `if (!mounted) return;`, `&& context.mounted`, o corpo de `if (mounted) {}`, o uso antes do 1º `await` e o `context` dentro do próprio `await f(context:…)` ou do `builder` dele.
2. **FG-ENC-022:** exigir a sequência de mojibake (Ã ou Â mais um caractere de continuação U+0080–U+00BF ou o equivalente CP1252) em vez do código isolado. Corrigir também a frase do TS-22 sobre "texto acentuado legítimo".
3. **Baseline com caminho absoluto** e **TOK-020 ligado sem `except` padrão.** Proponho caminhos relativos e um `except` padrão para `lib/**/theme*/**`, ou pelo menos um aviso quando nenhum `except` estiver configurado.

**yaml seletivo sugerido para este perfil** (ERP Flutter, Riverpod, PT-BR, legado grande). O esboço abaixo descreve a intenção; confira as chaves exatas no modelo do `init`:

```yaml
# Fase 1: só os sinais limpos, com baseline e --diff no CI
rules:
  FG-ARCH-003: error      # data layer fora da UI (3/5 TP)
  FG-BUILD-014: error     # future criado no build
  FG-CC-025: error        # complexidade > 80
  FG-LINT-009: error      # catch vazio; aceitar o formato ", justificativa:" do projeto
  FG-TOK-020: error
  FG-SYN-017: error
  FG-FMT-016: error
  # ASYNC-002, ENC-022, LAY-004, LIFE-001, RIV-001, KEY-001r, MET-007: desligadas até a correção
theme_tokens:
  except: ["lib/themes/**"]
```

O ENC-022 volta depois da correção. Os 4 mojibakes reais que ele achou (`terminal_model.dart:80/82`, `emergency_auth_service.dart:38`, `form_section_config.dart:40`) valem uma correção no ERP fora desta avaliação.

## Arquivos em `<OUT>`

`eval.json`, `eval-gates.txt`, `eval-jobs4.json`, `baseline.json`, `step6-1-update.txt`, `step6-2-baseline.txt`, `step6-3-diff.txt`, `step6-4-diff-head3.txt`, `step6-5-diff-nogit.txt`, `extra-analyze.txt`.
