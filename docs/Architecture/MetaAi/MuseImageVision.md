# 04. Meta Muse Image & Vision
### Auditoria Visual Multimodal, Detecção de RenderFlex Overflowed e Integridade Estética

---

## 1. O que é o Meta Muse Image / Llama Vision?
O **Meta Muse Image** (e os modelos multimodais de visão como o Llama 3.2 Vision) combinam a capacidade semântica de grandes modelos de linguagem com a percepção visual de redes neurais profundas. Eles conseguem "olhar" para uma imagem e raciocinar sobre conteúdo, cores, legibilidade, integridade estética e anomalias de diagramação gráfica.

---

## 2. Papel Específico no FlutterGuard-AI
Enquanto o **SAM 3.1** atua na geometria exata das caixas (*bounding boxes*), o **Meta Muse Image / Vision** atua no **diagnóstico semântico da tela**:

1. **Detecção Inequívoca de `RenderFlex overflowed`:**
   * O pesadelo número 1 de desenvolvedores Flutter é a famosa faixa amarela e preta listrada na tela indicando que um `Row` ou `Column` excedeu os limites de pixels da viewport.
   * O Muse Image analisa a captura de tela e detecta instantaneamente o padrão de overflow visual, mesmo quando o log do teste falhou em registrar o erro silencioso.
2. **Corte Silencioso de Textos (*Text Truncation*):**
   * Avalia se botões ou títulos foram cortados de forma ilegível (ex: `"Finalizar Comp..."` ou valores de preço escondidos).
3. **Contraste e Acessibilidade:**
   * Avalia se a combinação de cores gerada pela IA (ex: texto cinza claro sobre fundo branco) viola padrões mínimos de contraste e legibilidade humana.

---

## 3. Formato de Prompt e Diagnóstico Visual

### Prompt de Auditoria Visual (Multimodal):
```json
{
  "role": "user",
  "content": [
    {
      "type": "text",
      "text": "Você é o Auditor Visual de UI do FlutterGuard-AI. Analise esta captura de tela renderizada pelo Flutter e responda estritamente no formato JSON:\n1. has_renderflex_overflow (boolean): Há alguma faixa de overflow amarela/preta ou elemento visivelmente quebrado?\n2. truncated_text (boolean): Há textos essenciais cortados?\n3. visual_verdict (PASS/FAIL): O layout é aceitável para produção?\n4. diagnostic (string): Explicação curta da anomalia encontrada se FAIL."
    },
    {
      "type": "image_url",
      "image_url": {
        "url": "data:image/png;base64,{imagem_em_base64}"
      }
    }
  ]
}
```

### Resposta Típica de Bloqueio (*Fail-Closed*):
```json
{
  "has_renderflex_overflow": true,
  "truncated_text": false,
  "visual_verdict": "FAIL",
  "diagnostic": "Detectada faixa de aviso do Flutter no canto inferior direito: RenderFlex overflowed by 32 pixels on the bottom in Column."
}
```

---

## 4. Roteiro Prático de Estudos

1. **Testes de Resolução Múltipla:**
   * Pratique como rodar testes de widget no Flutter variando as dimensões virtuais da tela (ex: 360x640 para smartphones pequenos, 800x1280 para tablets) para forçar o surgimento de overflows visuais.
2. **Conversão de Imagem para Base64:**
   * Entenda como carregar o arquivo PNG gerado pelo teste e codificá-lo em string Base64 para envio na API multimodal da Meta.
3. **Avaliação Automatizada com Critério Binário:**
   * Pratique desenhar instruções de prompt que evitem respostas vagas como *"o design parece razoável"* e forcem um veredito estrito de **PASS** ou **FAIL**.

