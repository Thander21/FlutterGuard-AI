# Referência & Ponte com o Projeto ERP PDV D+

> **Caminho Base do Projeto Referência:**  
> `c:\_Projetos\ERP PDV D+\`

Este documento mapeia os artefatos, regras e esteiras em produção no **ERP PDV D+** que serviram de comprovação empírica e base de conhecimento para a concepção do **FlutterGuard AI**. Caso o agente ou desenvolvedor precise consultar implementações reais, consulte os arquivos abaixo.

---

## 1. Mapeamento de Arquivos de Governança e Regras

| Conceito no FlutterGuard AI | Arquivo de Origem no ERP PDV D+ | O que consultar |
| :--- | :--- | :--- |
| **Engine Bloqueante & Validações** | `c:\_Projetos\ERP PDV D+\campodeforca\campodeforca.ps1` | A esteira em PowerShell que executa gates determinísticos (`validate-light`, `commit-check`, `test`, `validate`). |
| **Metodologia SDD & Portões** | `c:\_Projetos\ERP PDV D+\.agents\rules\specdriven.md` | O ciclo de vida de mudanças (`Draft` → `Approved` → `In-Implementation`), TDD estrito e registro em `evidence.jsonl`. |
| **Anti-Complacência ("Verify Pass")** | `c:\_Projetos\ERP PDV D+\.agents\rules\aireview.md` | Regras que proíbem a IA de alucinar ou emitir pareceres confirmatórios sem prova de execução em testes ou schemas. |
| **Integridade de Estado & Concorrência** | `c:\_Projetos\ERP PDV D+\.agents\rules\stateasync.md` | Padrões de uso de Riverpod, máquinas de estado com sealed classes, guards assíncronos e prevenção de vazamento de memória. |
| **Prevenção de Quebras de Layout** | `c:\_Projetos\ERP PDV D+\.agents\rules\uilayout.md` | Regras de ouro para prevenção de `RenderFlex overflowed` e testes em resoluções adversárias (1024×768 e 800×600). |
| **Isolamento de Camadas (Clean)** | `c:\_Projetos\ERP PDV D+\.agents\rules\corearchitecture.md` | Separação estrita entre `lib/core/` (sem UI), `lib/shared/` (widgets agnósticos) e `lib/modules/` (verticais de negócio). |
| **Tenancy e Segurança de Dados** | `c:\_Projetos\ERP PDV D+\.agents\rules\tenancysecurity.md` | Padrão de injeção lazy de contexto, prevenção de vazamento entre tenants e falha fechada (*fail-closed*). |

---

## 2. Como Utilizar essa Referência no Futuro

Quando estiver implementando as regras do AST Analyzer ou as Receitas Canônicas no FlutterGuard AI:
1. **Consulte os exemplos reais do PDV D+:** Os erros mais comuns cometidos por agentes ao longo de meses de desenvolvimento no PDV D+ já estão catalogados nas regras acima.
2. **Reaproveite a lógica de Rollback:** A regra de que *"se quebrar após a alteração, reverta a alteração causadora e nunca suprima o erro"* veio diretamente do `campodeforca.md`.
3. **Mantenha o isolamento:** O FlutterGuard AI deve ser um projeto autocontido; ele **lê e consulta** os padrões do PDV D+, mas não depende de código proprietário de regras fiscais ou de hardware.
