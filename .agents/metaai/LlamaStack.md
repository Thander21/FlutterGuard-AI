# 05. Llama Stack
### Padronização de Agentes, Tool Calling, Memória e Orquestração

---

## 1. O que é o Llama Stack?
O **Llama Stack** é o conjunto oficial de especificações e APIs padronizadas da Meta para o ecossistema de Inteligência Artificial generativa. Ele resolve o problema da fragmentação de código de IA fornecendo uma interface unificada para:
* **Inferência de Modelos:** Abstração agnóstica para rodar modelos Llama/Muse localmente ou via provedores em nuvem.
* **Tool Calling (Execução de Ferramentas):** Padronização de chamadas de funções determinísticas.
* **Memória & RAG:** Gerenciamento de vetores e recuperação de contexto.
* **Segurança & Guardrails:** Camada nativa com Llama Guard para filtrar alucinações e respostas inseguras.

---

## 2. Papel Específico no FlutterGuard-AI
No FlutterGuard-AI, o Llama Stack atua como o **Barramento Central de Conectividade Agêntica**:
1. **Padronização das Ferramentas do Harness:** Em vez de escrever integrações proprietárias ad-hoc, as ferramentas do FlutterGuard (ex: `run_flutter_test`, `analyze_dart_ast`, `capture_widget_screenshot`) são expostas como ferramentas formais no padrão Llama Stack Tool Calling.
2. **Integração Agnóstica de Provedores:** Permite que o FlutterGuard rode tanto com as APIs em nuvem fornecidas pela Meta durante o Hackathon, quanto com instâncias locais do Llama 3 rodando via Ollama ou vLLM no ambiente de desenvolvimento local.
3. **Guardrails de Segurança (Llama Guard):** Impede que o modelo gere código vulnerável com injeção de dados inseguros ou manipulação inadequada de credenciais de clientes no Flutter.

---

## 3. Arquitetura do Llama Stack no FlutterGuard-AI

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTERGUARD CLI (ORQUESTRADOR)          │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                LLAMA STACK CLIENT / RUNTIME                 │
│  ├── Tool Calling: run_flutter_test(), check_ast()          │
│  ├── Memory: Histórico de falhas e receitas canônicas       │
│  └── Safety: Llama Guard                                    │
└──────────────┬───────────────────────────────┬──────────────┘
               │                               │
               ▼                               ▼
    [ Modelos em Nuvem Meta ]        [ Modelos Locais (Llama 3) ]
```

---

## 4. Roteiro Prático de Estudos

1. **Conceitos do Llama Stack:**
   * Leia a documentação oficial da Meta sobre o Llama Stack e a especificação de tool calling.
2. **Implementação de Ferramentas (Tool Calling):**
   * Estude como declarar schemas de funções em JSON para que os modelos da Meta saibam exatamente quando acionar a execução de um teste no terminal.
3. **Fallback Híbrido (Nuvem ➔ Local):**
   * Prepare o ambiente para caso a latência da API de nuvem esteja alta durante o hackathon, você possa chavear a execução do FlutterGuard para um endpoint local com o mesmo contrato de chamada.

