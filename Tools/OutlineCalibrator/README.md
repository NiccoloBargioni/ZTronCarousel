# Outline Calibrator

Electron tool for placing a `PlaceableOutlineDescriptor` outline on top of its image and reading back the
normalized bounding box (`outlineBoundingBox`) to store.

```sh
npm install
npm start
```

- **Image…** (⌘O): `.heic` (decoded with macOS `sips`), `.png`, `.jpg`. **Outline…** (⇧⌘O): `.svg`. Files can also be dropped on the window.
- Loading an image also loads `<image name>.svg` if one exists anywhere under the image's directory (exact name; the
  shallowest match wins, then alphabetical; hidden folders, `node_modules`, `DerivedData` and `Pods` are skipped). An
  `.svg` dropped together with the image takes precedence.
- Drag inside the box to move it, drag its thumbs to resize (⇧ keeps aspect, ⌥ resizes from the center). Arrow keys nudge by one screen pixel (⇧ ×10, ⌥ resizes).
- The paste area accepts Swift as written in code, e.g. `boundingBox: .init(x: 1939.0 / 3840.0, y: 1715.0 / 2160.0, …)`,
  a `CGRect(…)`, or four plain numbers. Fractions are evaluated as-is and their denominators become the current size
  (3840 × 2160 here). Plain numbers in 0…1 are read as normalized, larger ones as pixels of the current size.
  Pasting replaces whatever was in the field and strips each line's indentation.
- The current size is the one from the last pasted fractions or the last loaded image (its 16:9 frame when the image
  isn't 16:9). **Pixels** shows the box fields in pixels of that size, and all output uses it as the denominators.
- Every change is appended to the log at the bottom (and printed to the terminal) as
  `boundingBox: .init(x: … / …, y: …, width: …, height: …)   // image W × H · reason`. **Copy** puts the same thing,
  one argument per line, on the clipboard.

## Rendering fidelity

The outline is drawn the way `ZTronSVGView` draws it through SwiftSVG, not the way a browser would draw the SVG
(`renderer/swiftsvg.js`):

- The box is normalized against a 16:9 fit of the page, anchored at the image's top-left corner (`ZTronImagePage`).
- `resizeToFit` aspect-fits the union of the paths' `CGPath.boundingBox` (control points included, transforms and
  `viewBox` ignored) into the box, and only scales: a bounding box that doesn't start at (0, 0) is drawn offset.
- `viewBox` offsets by +(minX, minY) and never scales; transform lists compose first-to-last; no arc support.
- Line width is 7.5 (37 when the box diagonal is under 0.07) in SVG units, shrinking toward 5 while zoomed in.

The path lexer, points lexer and transform parser were checked against SwiftSVG's own sources compiled with
CoreGraphics. Problems SwiftSVG would have with a file (crashes, never-finishing parses, unsupported elements) are
listed under **Notes**.
