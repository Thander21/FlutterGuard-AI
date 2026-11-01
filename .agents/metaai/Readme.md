# Meta AI Stack: Guia de Modelos & Frameworks
### Mapeamento Tecnológico e Diretrizes de Integração para o FlutterGuard-AI

Este diretório reúne a documentação técnica aprofundada de cada modelo, ferramenta e framework de Inteligência Artificial da **Meta** selecionados para a arquitetura do **FlutterGuard-AI** no Hackathon Global da Meta.

---

## 🏛️ Visão Geral da Arquitetura Integrada

O **FlutterGuard-AI** opera sob uma esteira de ciclo fechado (*closed-loop agentic harness*) onde cada modelo da Meta assume uma responsabilidade técnica cirúrgica, eliminando alucinações e garantindo que nenhum código de UI ou lógica seja aprovado sem verificação determinística e visual.

```
                              ┌──────────────────────────────────┐
                              │     USUÁRIO / REQUISITO DO APP   │
                              └────────────────┬─────────────────┘
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ 1. META MUSE SPARK (MuseSpark.md)                                                           │
│    * Arquiteto SDD & Engenheiro de Contratos                                                │
│    * Gera especificações formais, classes seladas e testes TDD [RED]                        │
└──────────────────────────────────────────────┬──────────────────────────────────────────────┘
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ 2. META MUSE CODE / LLAMA 3.1 (MuseCode.md)                                                 │
│    * Engenheiro Executor de Código em Dart                                                  │
│    * Implementação mínima para transformar testes em [GREEN]                                │
│    * Correção de anti-patterns da AST através de receitas canônicas                         │
└──────────────────────────────────────────────┬──────────────────────────────────────────────┘
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ 3. SAM 3.1 & META MUSE IMAGE / VISION (SamSegmentAnything.md & MuseImageVision.md)          │
│    * SAM 3.1: Segmenta botões, caixas e componentes no screenshot renderizado headless      │
│    * Muse Image / Vision: Audita se há 'RenderFlex overflowed', quebras de texto e margens   │
└──────────────────────────────────────────────┬──────────────────────────────────────────────┘
                                               │
                                               ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ 4. LLAMA STACK (LlamaStack.md)                                                              │
│    * Barramento padronizado da Meta para agentes, tool calling e memória                    │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 📚 Índice dos Documentos de Estudo

1. **[01. Meta Muse Spark](MuseSpark.md):** Especificação Dirigida por Contratos (SDD), raciocínio arquitetural e geração do estágio RED do TDD.
2. **[02. Meta Muse Code](MuseCode.md):** Sintaxe avançada de Dart 3, implementação mínima e autocura assistida por análise de AST.
3. **[03. SAM 3.1 (Segment Anything)](SamSegmentAnything.md):** Segmentação de componentes de interface gráfica, detecção de caixas delimitadoras (*bounding boxes*) e colisões de layout.
4. **[04. Meta Muse Image & Vision](MuseImageVision.md):** Auditoria multimodal de telas, detecção de *RenderFlex overflowed* e validação estética de widgets.
5. **[05. Llama Stack](LlamaStack.md):** Protocolo unificado de orquestração de agentes, chamadas de ferramentas e integração cliente/servidor.

---

## 🎯 Roteiro Rápido de Preparação (Pré-Hackathon)

* [ ] Compreender o formato de prompt estruturado em JSON para o **Muse Spark**.
* [ ] Testar scripts locais com o analisador de AST do Dart (`analyzer` package) para municiar o **Muse Code**.
* [ ] Praticar o envio de imagens via API para o **SAM** e extração de máscaras de segmentação.
* [ ] Configurar testes headless no Flutter que salvam prints de tela em PNG via `WidgetTester`.

