# 03. SAM 3.1 (Segment Anything Model)
### Screen Geometric Segmentation, Bounding Boxes, and Collision Detection

---

## 1. What Is SAM (Segment Anything)?
**SAM (Segment Anything Model)** is Meta's foundational computer-vision model that set the world state of the art in image segmentation. It can segment any object, visual boundary, or contiguous region with pixel-outline precision from visual prompts (points, bounding boxes) or in full automatic (*everything*) mode, with no class-specific training.

---

## 2. Specific Role in FlutterGuard-AI
SAM is the key piece of the **FlutterGuard-AI Multimodal Visual Auditor**:
1. **Problem Solved:** Traditional Flutter tests (`flutter test`) validate the widget tree in code but **are blind to rendered geometry**. A screen can pass 100% of logic tests while a floating button covers the checkout button, or a card pushes text off-screen.
2. **Headless Execution:** During the widget test suite, Flutter renders the screen in memory and produces a high-fidelity PNG screenshot.
3. **Automatic Segmentation:** The screenshot goes to SAM 3.1, which extracts spatial coordinates (`x, y, width, height`) and outline masks for each drawn graphic component.
4. **Collision and Occlusion Math:** FlutterGuard compares bounding boxes:
   * If `Box(A)` intersects `Box(B)` without an intentional `Stack` widget in the spec, a **layout collision error** fires.

---

## 3. Workflow and Technical Integration

```
[ WidgetTester ]
      │  (renders headless at 800x600)
      ▼
[ screenshot.png ]
      │
      ▼
[ SAM 3.1 API: Segment Everything ]
      │
      ▼
[ Masks & Bounding Boxes JSON ]
   { "id": 1, "label": "button", "bbox": [120, 450, 200, 48] },
   { "id": 2, "label": "card",   "bbox": [100, 400, 300, 150] }
      │
      ▼
[ FlutterGuard Geometric Validator ]
      │
      ├──> Approved: clean layout, no overlap
      └──> Rejected: collision detected! Blocking gate fires
```

---

## 4. Hands-On Study Roadmap

1. **Screenshotting in Flutter Tests:**
   * Study `WidgetTester` with `tester.binding.takeScreenshot('screenshot_test.png')` or the `golden_toolkit` package.
2. **SAM API:**
   * Explore Meta's SAM docs and how to invoke the model with an image and receive the masks-and-coordinates array.
3. **Simple Rectangle Collision Algorithms (AABB):**
   * Study the basic axis-aligned bounding box collision formula to compare SAM outputs directly in harness code.
