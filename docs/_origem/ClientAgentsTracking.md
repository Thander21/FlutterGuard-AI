# Rastreamento e Governança de Agentes Clientes: Gemini / Claude Code / Cursor / Antigravity

> **Objetivo:** Este documento define como o **FlutterGuard AI** (cujo core é impulsionado pela stack da Meta AI) atua em tempo de execução dentro de qualquer projeto Flutter, rastreando, auditando e governando agentes de IA locais (Claude Code, Gemini CLI, Cursor, Antigravity ou modelos locais) via servidor MCP nativo e hooks de commit.

---

## 1. Mapeamento de Modelos & Ferramentas Locais

Ao executar fora das APIs fechadas da Meta, o harness pode ser alimentado por provedores líderes de mercado:

| Papel no Harness | Ferramenta / Modelo Recomendado | Como Executa |
| :--- | :--- | :--- |
| **Arquiteto SDD & Contratos** | **Claude 3.5 Sonnet / Gemini Pro** | Gera especificações, contratos de domínio, sealed classes e testes unitários RED. |
| **Implementação e Auto-Fix** | **Claude Code / Gemini CLI / Antigravity** | Agentes locais com acesso a terminal e ferramentas de manipulação de arquivo. |
| **Auditoria Visual Alternativa** | **Gemini Flash / Vision / OpenCV** | Recebe os frames PNG renderizados pelos testes headless de widget e calcula as sobreposições de layout. |
| **Juiz Determinístico** | **Dart SDK Analyzer + flutter_test** | Roda 100% localmente no terminal sem custo de tokens. |

---

## 2. Arquitetura do CLI Local (`flutterguard` ou `fg`)

O núcleo do projeto é um executável de linha de comando (CLI em Dart ou Python) que intercepta as chamadas do desenvolvedor ou da IDE:

```powershell
# Exemplo de comando do desenvolvedor
fg run "Adicionar carrinho de compras com desconto percentual e persistência offline"
```

### Ciclo de Execução Local:

1. **Gate 0 (Spec Generator):**
   * O agente gera `spec.md` contendo entidades, invariantes de estado e contratos de interface.
   * Cria o teste de unidade `cart_test.dart` com asserções que falham (**RED**).
2. **Gate 1 (Worker Loop):**
   * O agente implementa o código mínimo em `lib/`.
3. **Gate 2 (AST & Static Guardian):**
   * O CLI executa o analisador customizado de AST em Dart:
     ```powershell
     dart run bin/ast_guardian.dart --target lib/
     ```
   * Se houver violação (ex.: controller no build), o CLI bloqueia e injeta a receita canônica direto no prompt do agente.
4. **Gate 3 (Test Runner):**
   * Executa `flutter test --concurrency=1`.
   * Se quebrar, o erro estruturado é retornado para a próxima iteração.
5. **Gate 4 (Visual Inspector Headless):**
   * Executa teste de widget com renderização headless gerando imagem PNG em `build/test_snapshots/`.
   * Modelo multimodal avalia layout e bounds.
6. **Gate 5 (Commit Guard):**
   * Se e somente se todos os gates passarem (GREEN), o CLI grava a evidência em `evidence.jsonl` e libera o commit.

---

## 3. Vantagens da Trilha Independente

* **Independência de Plataforma:** Funciona com qualquer IDE (VS Code, Antigravity, Android Studio) e qualquer agente de terminal (Claude Code, Aider, Gemini CLI).
* **Custo Quase Zero:** A maior parte das validações (AST, testes locais, linters) roda localmente no hardware da máquina do desenvolvedor sem gastar chamadas de API.
* **Privacidade de Código:** Empresas podem rodar o validador com modelos locais via Ollama (Llama 3.3 / Qwen Coder) sem enviar dados para a nuvem.
