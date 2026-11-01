# 04. Meta Muse Image & Vision
### Multimodal Visual Audit, RenderFlex Overflow Detection, and Aesthetic Integrity

---

## 1. What Are Meta Muse Image / Llama Vision?
**Meta Muse Image** (and multimodal vision models such as Llama 3.2 Vision) combine large-language-model semantics with deep-neural-network visual perception. They can "look" at an image and reason about content, colors, legibility, aesthetic integrity, and graphic-layout anomalies.

---

## 2. Specific Role in FlutterGuard-AI
While **SAM 3.1** handles exact box geometry, **Meta Muse Image / Vision** handles **semantic screen diagnosis**:

1. **Unequivocal `RenderFlex overflowed` Detection:**
   * The number-one nightmare of Flutter developers is the infamous yellow-and-black striped band showing that a `Row` or `Column` exceeded the viewport pixel bounds.
   * Muse Image analyzes the screenshot and instantly spots the visual overflow pattern, even when the test log missed the silent error.
2. **Silent Text Truncation:**
   * Checks whether buttons or titles were cut unreadably (e.g. `"Checkout..."` or hidden price values).
3. **Contrast and Accessibility:**
   * Judges whether the AI-generated color combination (e.g. light-gray text on white) violates minimum contrast and human-legibility standards.

---

## 3. Visual Diagnosis Prompt Format

### Visual Audit Prompt (Multimodal):
```json
{
  "role": "user",
  "content": [
    {
      "type": "text",
      "text": "You are the FlutterGuard-AI UI Visual Auditor. Analyze this Flutter-rendered screenshot and reply strictly in JSON:\n1. has_renderflex_overflow (boolean): Is there any yellow/black overflow band or visibly broken element?\n2. truncated_text (boolean): Is any essential text cut off?\n3. visual_verdict (PASS/FAIL): Is the layout acceptable for production?\n4. diagnostic (string): Short explanation of the anomaly if FAIL."
    },
    {
      "type": "image_url",
      "image_url": {
        "url": "data:image/png;base64,{image_as_base64}"
      }
    }
  ]
}
```

### Typical Blocking Response (*Fail-Closed*):
```json
{
  "has_renderflex_overflow": true,
  "truncated_text": false,
  "visual_verdict": "FAIL",
  "diagnostic": "Flutter warning band detected at the bottom-right corner: RenderFlex overflowed by 32 pixels on the bottom in Column."
}
```

---

## 4. Hands-On Study Roadmap

1. **Multi-Resolution Testing:**
   * Practice running Flutter widget tests across virtual screen sizes (e.g. 360x640 for small phones, 800x1280 for tablets) to force visual overflows to surface.
2. **Image-to-Base64 Conversion:**
   * Learn to load the PNG file produced by the test and encode it as a Base64 string for the Meta multimodal API.
3. **Automated Binary-Criterion Evaluation:**
   * Practice writing prompt instructions that avoid vague answers like *"the design looks reasonable"* and force a strict **PASS** or **FAIL** verdict.
