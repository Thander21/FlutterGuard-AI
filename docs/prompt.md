TAREFA: avaliação externa do FlutterGuard-AI (validação do MVP)
sobre UM projeto Dart/Flutter qualquer, SEM instalar nada no projeto
avaliado e SEM sujá-lo. Você vai rodar a análise de fora, num
checkout isolado da ferramenta, e devolver um relatório completo.

CONVENÇÕES: `<FG>` = checkout isolado do FlutterGuard-AI (TEMP);
`<ALVO>` = caminho do projeto avaliado (raiz ou `lib/`);
`<OUT>` = pasta do relatório (TEMP, fora do alvo).
PowerShell no Windows; em macOS/Linux adapte os caminhos.

ISOLAMENTO (escolha UMA opção; nada é instalado no `<ALVO>`):

  Opção A — você JÁ tem um clone do FlutterGuard-AI:
    git worktree add --detach <FG> 7695b0801bd94b73aa12b4893f0edcc17c26b4df
    cd <FG>; dart pub get

  Opção B — você NÃO tem o repo (começando do zero):
    git clone https://github.com/Thander21/FlutterGuard-AI.git <FG>
    cd <FG>
    git checkout 7695b0801bd94b73aa12b4893f0edcc17c26b4df
    dart pub get

  Prove o não-poluimento: rode `git status --short` no `<ALVO>`
  ANTES e DEPOIS de tudo — deve ser idêntico (o `check` é
  somente-leitura; é proibido rodar `init`, criar
  `flutterguard.yaml` ou instalar hooks no alvo).

0. AMBIENTE (anote tudo): `dart --version`; `flutter --version`
   (só presença/ausência, NÃO instale); commit do FG
   (`git rev-parse HEAD` em `<FG>`); commit do alvo; denominador:
   (Get-ChildItem -Recurse -Filter *.dart "<ALVO>").Count

1. RODADA PRINCIPAL (a partir de `<FG>`):
     Measure-Command { dart run bin/flutterguard.dart check "<ALVO>" --json > <OUT>\eval.json }
     dart run bin/flutterguard.dart check "<ALVO>" --by-gate > <OUT>\eval-gates.txt
   Anote exit codes (0 limpo-ou-avisos, 1 erros, 2 uso) e tempos.

2. TABELAS: manchete (arquivos lidos sem erro/N, erros de parse
   FG-SYN-017, FMT no Windows, achados em gerados, tempo, total,
   duplicatas (file,line,rule) — devem ser 0) + por regra
   (rule_id, achados, arquivos, severidades).

3. AMOSTRAGEM TP/FP (o coração do relatório): para CADA regra com
   achados, confira no código — regra com ≤10 achados = conferir
   todos, senão amostra ≥6 espalhada por arquivos. Cada amostra:
   arquivo:linha + TP ou FP + causa em 1 frase. Classes novas de
   FP e qualquer crash/erro de parse: sempre reportados, mesmo
   que unitários. Se uma regra não tem testemunha no projeto
   (zero achados), escreva "sem testemunha neste corpus".

4. JULGAMENTO POR REGRA: para cada regra julgada, marque
   CONFIÁVEL (só TPs ou FPs raros e explicáveis), RUIDOSA
   (FPs frequentes — diga o padrão) ou BLOQUEADORA (quebra a
   confiança na ferramenta), com a precisão observada na amostra
   (ex.: 5/6 TP).

5. DEFAULTS: as regras silenciosas-sem-config (FG-BAN-018,
   FG-LOG-019, FG-I18N-021, FG-ORP-023, FG-LYR-024, FG-TST-033)
   DEVEM estar ausentes sem `flutterguard.yaml` — se alguma
   disparar, é achado da avaliação (bug de default).

6. DEMO DE ADOÇÃO (baseline em `<OUT>`, nunca no alvo):
     dart run bin/flutterguard.dart check "<ALVO>" --baseline <OUT>\baseline.json --update-baseline
     dart run bin/flutterguard.dart check "<ALVO>" --baseline <OUT>\baseline.json
     dart run bin/flutterguard.dart check "<ALVO>" --diff --diff-base origin/main
   Esperado: 1º exit 0 com nota de delta; 2º verde; --diff
   escopado (alvo sem git → exit 2 com causa = bloqueado-com-causa).

7. OPCIONAL (se der tempo): `check --json --jobs 4` com conjunto
   (file,line,rule_id) idêntico à rodada principal; extras
   --analyze/--dep-audit/--license-audit registrados à parte,
   nunca misturados nos números principais.

8. RELATÓRIO (MD + os arquivos de `<OUT>`): ambiente, tabelas do
   passo 2, amostras TP/FP do passo 3, julgamentos do passo 4,
   resultado do passo 6. Feche com o VEREDITO MVP em 5 respostas
   curtas + recomendação:
   a) algum crash ou erro de parse em arquivo válido?
   b) cobertura de leitura (% arquivos sem erro)?
   c) precisão por regra (das amostras)?
   d) tempo aceitável para o tamanho do projeto?
   e) baseline+diff funcionam para adoção em legado?
   Recomendação de UMA linha (APROVAR / APROVAR-COM-RESSALVAS /
   NÃO-APROVAR) + top 3 bloqueadores + yaml seletivo sugerido
   (quais regras ligar primeiro neste perfil de projeto).

9. LIMPEZA (depois de emitir o relatório): Opção A:
   `git worktree remove --force <FG>` (+ `git worktree prune` no
   clone-mãe); Opção B: apague a pasta `<FG>`. Mantenha SÓ o
   relatório + `<OUT>`. Re-confira `git status` do alvo idêntico
   ao passo 0.

FORA DE ESCOPO: Tier-2 visual, qualquer fix no alvo, instalação
como MCP/plugin (esse é o passo DEPOIS da aprovação do MVP).
DEVOLVA: o relatório MD + eval.json + eval-gates.txt.
