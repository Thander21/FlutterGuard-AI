# Campo de Força: A Engine de Bloqueio Fail-Closed

> **Nota de escopo (v0):** `validate-light`, `validate` e `commit-check`
> são portões de processo ainda sem executor; os portões executáveis hoje
> são `grade` e `check` (`bin/flutterguard.dart`).

O conceito do **Campo de Força** é derivado diretamente da experiência acumulada no ERP PDV D+, onde a automação por IA exige uma esteira de portões que opera com **tolerância zero** para inconsistências.

---

## 1. O Que É o Campo de Força?

O Campo de Força é a barreira física que se interpõe entre a geração de código pela IA e o sistema de arquivos/controle de versão (Git). Ele garante que nenhum arquivo seja persistido ou commitado se houver qualquer desvio de qualidade.

### Os Três Princípios Invioláveis:
1. **Falha Fechada (*Fail-Closed*):** Na dúvida, ausência de resposta ou erro de execução, o portão bloqueia a operação imediatamente.
2. **Rollback Técnico Obrigatório:** Se um gate quebrar após uma edição do agente, a alteração causadora deve ser desfeita (revertida para o snapshot anterior). **Nunca suprima o erro** ou adicione `// ignore:` para passar de fase.
3. **Sem Commits Automáticos:** A IA nunca commita diretamente sem a validação do harness e a aprovação humana.

---

## 2. Níveis de Portões (Gates de Execução)

O framework divide as validações em quatro portões progressivos de custo e profundidade:

```
┌─────────────────────────────────────────────────────────────┐
│ 1. GATE LIGHT (`validate-light`)                            │
│    - Duração: ~1 a 3 segundos                               │
│    - Verifica: Imports ilegais, formatação, sintaxe básica, │
│      regras de AST imediatas.                               │
└──────────────────────────────┬──────────────────────────────┘
                               │ (Passou)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. GATE TEST (`test`)                                       │
│    - Duração: ~5 a 15 segundos                              │
│    - Executa: Testes unitários do arquivo alterado.         │
│    - Exige: 100% de sucesso sem warnings.                   │
└──────────────────────────────┬──────────────────────────────┘
                               │ (Passou)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. GATE COMPLETO (`validate`)                               │
│    - Duração: ~30 a 60 segundos                             │
│    - Executa: `dart analyze --fatal-infos` em todo o módulo,│
│      testes de regressão cruzada, integridade de contratos. │
└──────────────────────────────┬──────────────────────────────┘
                               │ (Passou)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. COMMIT CHECK (`commit-check`)                            │
│    - Duração: ~2 segundos                                   │
│    - Verifica: Presença de evidência em `evidence.jsonl`,   │
│      ausência de arquivos temporários, diff limpo.          │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Protocolo de Auto-Recuperação (Self-Healing)

Quando um gate falha durante o trabalho do agente:

1. **Captura do Erro Estruturado:** O Campo de Força extrai a linha exata, o código do erro e o contexto do analisador.
2. **Snapshot de Segurança:** O estado atual do código antes do erro fica salvo em uma área de staging temporária.
3. **Despacho da Receita Canônica:** A IA recebe a notificação da falha e a receita de correção.
4. **Tentativas de Correção (Cap de 3 Iterações):** O agente tem até 3 tentativas para fazer o código passar no gate.
   * **Heurística "Attack the Premise" (Inspirada no `ub-mode` de Uncle Bob):** Se 2 tentativas consecutivas falharem no mesmo gate compartilhando a mesma premissa técnica, a escrita é pausada. O agente é instruído a resumir a premissa em uma frase, identificar a contradição arquitetural e redefinir a solução por primeiros princípios antes de editar código novamente.
5. **Rollback Automático:** Se após 3 tentativas o código continuar quebrando, o Campo de Força descarta todas as alterações daquela iteração e restaura o snapshot limpo anterior, emitindo um relatório de diagnóstico da falha para intervenção humana.
