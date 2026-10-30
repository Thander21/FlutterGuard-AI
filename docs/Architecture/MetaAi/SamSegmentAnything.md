# 03. SAM 3.1 (Segment Anything Model)
### Segmentação Geométrica de Telas, Bounding Boxes e Detecção de Colisões

---

## 1. O que é o SAM (Segment Anything)?
O **SAM (Segment Anything Model)** é o modelo fundacional de visão computacional da Meta que estabeleceu o estado da arte mundial em segmentação de imagens. Ele é capaz de segmentar qualquer objeto, fronteira visual ou região contígua com precisão de contorno de pixel a partir de prompts visuais (pontos, caixas delimitadoras) ou em modo de segmentação automática completa (*everything mode*), sem necessidade de treinamento específico para a classe do objeto.

---

## 2. Papel Específico no FlutterGuard-AI
O SAM é a peça-chave do **Auditor Visual Multimodal do FlutterGuard-AI**:
1. **O Problema Resolvido:** Testes tradicionais do Flutter (`flutter test`) validam a árvore de widgets em código, mas **são cegos para a geometria renderizada**. Uma tela pode passar com 100% de sucesso nos testes de lógica enquanto um botão flutuante está cobrindo o botão de finalizar compra, ou um card está empurrando um texto para fora da tela.
2. **Execução Headless:** Durante a suíte de testes de widgets, o Flutter renderiza a tela em memória e gera um screenshot PNG em alta fidelidade.
3. **Segmentação Automática:** O screenshot é enviado para o SAM 3.1, que extrai as coordenadas espaciais (`x, y, width, height`) e as máscaras de contorno de cada componente gráfico desenhado.
4. **Cálculo de Colisão e Oclusão:** O FlutterGuard compara as caixas delimitadoras (*bounding boxes*):
   * Se `Box(A)` intercepta `Box(B)` sem que haja um widget `Stack` intencional na spec, um **erro de colisão de layout** é disparado.

---

## 3. Fluxo de Trabalho e Integração Técnica

```
[ WidgetTester ]
      │  (renderiza headless a 800x600)
      ▼
[ screenshot.png ]
      │
      ▼
[ API SAM 3.1: Segment Everything ]
      │
      ▼
[ JSON de Máscaras & Bounding Boxes ]
   { "id": 1, "label": "button", "bbox": [120, 450, 200, 48] },
   { "id": 2, "label": "card",   "bbox": [100, 400, 300, 150] }
      │
      ▼
[ Validador Geométrico do FlutterGuard ]
      │
      ├──> Aprovado: Layout limpo sem sobreposição
      └──> Reprovado: Colisão detectada! Aciona Gate Bloqueante
```

---

## 4. Roteiro Prático de Estudos

1. **Captura de Tela em Testes Flutter:**
   * Estude como usar `WidgetTester` com `tester.binding.takeScreenshot('screenshot_test.png')` ou o pacote `golden_toolkit`.
2. **API do SAM:**
   * Explore a documentação do SAM da Meta e como invocar o modelo passando uma imagem e recebendo o array de máscaras e coordenadas.
3. **Algoritmos Simples de Colisão de Retângulos (AABB):**
   * Estude a fórmula básica de colisão de caixas orientadas aos eixos (*Axis-Aligned Bounding Box*) para comparar as saídas do SAM diretamente no código do harness.

